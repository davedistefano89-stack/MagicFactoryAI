#!/usr/bin/env bash
# =============================================================================
# Magic Colors · tools/ci/no_settings_from_prefs_in_test.sh
# =============================================================================
#
# CI gate. Fails the build if any file under `magic_colors/test/` references
# either of these two patterns:
#
#   • SettingsState.fromPrefs(...)
#   • SharedPreferences.setMockInitialValues(...)
#
# Why these are forbidden in tests:
#   Both touch the isolate-wide `SharedPreferences.getInstance()` singleton,
#   which earlier tests in `flutter test --concurrency=1` can pre-cache
#   with stale mock values. The resulting pollution silently flips
#   `reduceMotion=false` and keeps [OutlinePulse]'s `AnimationController..repeat()`
#   alive forever, hanging the suite at the 10-min hard timeout.
#
# The approved way to construct a SettingsState in a test is:
#     settings = SettingsState.forTest(reduceMotion: true);
#
# Usage:
#   bash tools/ci/no_settings_from_prefs_in_test.sh
#
# Contract: this script uses bash-only syntax (`[[ ]]`, BASH_SOURCE,
# `realpath`). Invoke it via `bash …` explicitly. A bare `sh …` invocation
# WILL NOT WORK — that is a deliberate CI fence to keep the script's
# surface area on Linux CI runners (which ship bash by default) explicit.
#
# Exit codes:
#   0  — no forbidden patterns found (CI green)
#   1  — forbidden patterns found (CI red, printed offenders)
#   2  — environment error (script not in repo, missing `grep`, …)
# =============================================================================

set -euo pipefail

# ── Self-locate the project root via realpath (GNU coreutils) ───────────
# realpath is on every system that ships bash (Linux, macOS, Git for
# Windows). Symlinks are resolved to the canonical repo path so the
# toolchain works even when the script is invoked through a $PATH
# symlink (e.g. installed into /usr/local/bin/).
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
# …/tools/ci/no_settings_from_prefs_in_test.sh → …/tools → … (project root)
PROJECT_ROOT="${SCRIPT_DIR%/tools/ci}"
PROJECT_ROOT="${PROJECT_ROOT%/tools}"

if [[ ! -d "${PROJECT_ROOT}/magic_colors/test" ]]; then
  echo "ERROR: cannot find magic_colors/test/." >&2
  echo "  Resolved PROJECT_ROOT = '${PROJECT_ROOT}'." >&2
  echo "  Was the script symlinked into a directory outside the repo?" >&2
  exit 2
fi

TEST_DIR="${PROJECT_ROOT}/magic_colors/test"

# ── Forbidden patterns ────────────────────────────────────────────────────
# Patterns are matched with `grep -F` (fixed-string, no regex). A
# future `fromPrefs_v2` or `fromPrefsBackup` reusing the polluted
# symbol is BLOCKED by design — substring match is the intent, since
# any future reuse of the fromPrefs singleton would re-introduce the
# same hang. Do NOT add regex patterns here; the gate is intentionally
# cheap and unambiguous.
FORBIDDEN_PATTERNS=(
  'SettingsState.fromPrefs'
  'SharedPreferences.setMockInitialValues'
)

# ── Verify grep supports everything we use (CI boxes are weird sometimes) ─
if ! command -v grep >/dev/null 2>&1; then
  echo "ERROR: grep is required but not found on PATH." >&2
  exit 2
fi

# ── Scan ──────────────────────────────────────────────────────────────────
# Use grep -c (per-file count) + awk -F: sum instead of pipelining through
# `wc -l`: the `-F:` split + `$NF` reads the trailing count regardless
# of whether grep emits a bare number (single-file) or `file:count`
# (multi-file), both of which GNU grep -c can produce. `|| true` after
# the awk handles `set -o pipefail` exit-1 from grep on zero matches.
exit_code=0
total_offenders=0
report_lines=()

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  pattern_count=$(grep -rFc \
    --include='*.dart' \
    --exclude-dir='.git' \
    --exclude-dir='build' \
    --exclude-dir='.dart_tool' \
    "${pattern}" \
    "${TEST_DIR}" \
    | awk -F: '{s += $NF} END {print s + 0}' \
    || true)

  if [[ "${pattern_count}" -gt 0 ]]; then
    offender_lines=$(grep -nrF \
      --include='*.dart' \
      --exclude-dir='.git' \
      --exclude-dir='build' \
      --exclude-dir='.dart_tool' \
      "${pattern}" \
      "${TEST_DIR}" || true)
    total_offenders=$((total_offenders + pattern_count))
    report_lines+=("  ✗ Forbidden pattern '${pattern}' found in test/ (${pattern_count} hit(s)):")
    while IFS= read -r line; do
      report_lines+=("      ${line}")
    done <<< "${offender_lines}"
    exit_code=1
  fi
done

# ── Report ────────────────────────────────────────────────────────────────
if [[ "${exit_code}" -eq 0 ]]; then
  echo "OK  no_settings_from_prefs_in_test.sh"
  echo "    scanned ${TEST_DIR}"
  echo "    ${#FORBIDDEN_PATTERNS[@]} forbidden pattern(s), 0 offenders"
  exit 0
fi

{
  echo
  echo "FAIL no_settings_from_prefs_in_test.sh"
  echo "  ${total_offenders} offender line(s) across ${TEST_DIR}"
  for report_line in "${report_lines[@]}"; do
    echo "${report_line}"
  done
  cat <<'EOF'

  Fix: replace every call with the bypass-Singleton factory

      settings = SettingsState.forTest(reduceMotion: true);

  See the doc comment on SettingsState.forTest in
      magic_colors/lib/core/state/settings_state.dart
  for why the redirect-to-SharedPreferences path flakes under
  --concurrency=1.

EOF
} >&2

exit 1
