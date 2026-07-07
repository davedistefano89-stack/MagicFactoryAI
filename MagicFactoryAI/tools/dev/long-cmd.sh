#!/usr/bin/env bash
# =============================================================================
# Magic Factory · tools/dev/long-cmd.sh
# =============================================================================
#
# Wraps a long-running bash command and fires a Windows 10/11 toast
# notification on completion. Designed for Windows + Git Bash.
#
# Usage:
#   bash tools/dev/long-cmd.sh "Title" command [args...]
#
# Examples:
#   bash tools/dev/long-cmd.sh "Flutter test" \
#     bash -c 'cd magic_colors && flutter test --no-pub'
#   bash tools/dev/long-cmd.sh "Analyze" \
#     bash -c 'cd magic_colors && flutter analyze --no-pub'
#
# Anti-spam guard: only fires a toast when the wrapped command ran
# for >= LONG_CMD_MIN_SECONDS (= 5 by default). Override via env var:
#   LONG_CMD_MIN_SECONDS=0  bash tools/dev/long-cmd.sh "Ping" sleep 2
#   LONG_CMD_MIN_SECONDS=60 bash tools/dev/long-cmd.sh "Quiet" make
#
# Sound: silent by default to avoid notification choirs on test runs.
# Opt in to the default ding via:
#   LONG_CMD_TOAST_SOUND=1 bash tools/dev/long-cmd.sh "Build" make
#
# Exit codes:
#   0  = wrapper OK and command OK
#   >0 = the wrapped command's exit code (forwarded verbatim)
#
# Side effects: on completion (when above the threshold), fires a
# Windows toast via tools/dev/win_toast.ps1 (WinRT, no BurntToast).
# Toast plumbing errors are swallowed so they don't pollute exit
# codes; the wrapped command's exit code is what matters.
# =============================================================================

set -uo pipefail

MIN_SECONDS_DEFAULT="${LONG_CMD_MIN_SECONDS:-5}"

if [ $# -lt 2 ]; then
    echo '[long-cmd] usage: long-cmd.sh "Title" command [args...]' >&2
    echo '[long-cmd] (env LONG_CMD_MIN_SECONDS=N to override the 5 s threshold.)' >&2
    exit 64
fi

title="$1"
shift
cmd=("$@")

# Resolve this script's directory, then translate to a Windows path
# for the PowerShell -File argument. Git Bash always ships cygpath,
# so we hard-require it; without it we'd end up sending a Unix-style
# path that PowerShell can't open.
SCRIPT_DIR_UNIX="$(cd "$(dirname "$0")" && pwd)"
if ! command -v cygpath >/dev/null 2>&1; then
    echo '[long-cmd] cygpath not found. This wrapper requires Git Bash (or any shell with cygpath).' >&2
    exit 65
fi
WIN_PS1_PATH="$(cygpath -w "$SCRIPT_DIR_UNIX/win_toast.ps1")"

start_ts=$(date +%s)
"${cmd[@]}"
exit_code=$?
elapsed=$(( $(date +%s) - start_ts ))

# Anti-spam: trivial commands stay silent.
if [ "$elapsed" -lt "$MIN_SECONDS_DEFAULT" ]; then
    exit "$exit_code"
fi

status_subtitle='OK'
if [ "$exit_code" -ne 0 ]; then
    status_subtitle="FAIL exit=$exit_code"
fi

# Escape single quotes for PowerShell single-line arg parsing.
# `'` becomes `''` so something like  `it's done`  becomes  `it''s done`
# which PowerShell's CommandLineToArgvW decodes as  `it's done`.
# We use sed because bash's ${var//x/y} escapes are easy to get wrong
# and have version-dependent behavior across bash 3 vs 4 vs 5.
safe_title=$(printf '%s' "$title" | sed "s/'/''/g")
safe_status=$(printf '%s' "($elapsed s) $status_subtitle" | sed "s/'/''/g")

sound_arg=''
if [ "${LONG_CMD_TOAST_SOUND:-}" = "1" ]; then
    sound_arg='-Sound'
fi

# Fire toast via PowerShell. Swallow failures — the wrapper's job is to
# surface the wrapped command's exit code, NOT toast plumbing.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1_PATH" \
    -Title "$safe_title" \
    -Message "$safe_status" \
    $sound_arg \
    >/dev/null 2>&1 || true

exit "$exit_code"
