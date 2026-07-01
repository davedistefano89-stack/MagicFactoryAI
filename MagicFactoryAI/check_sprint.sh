#!/usr/bin/env bash
# Sprint #12 - Dashboard PRO 3 - Verification Script (Bash)
# ---------------------------------------------------------------------
# Mirror of check_sprint.ps1 for Linux / macOS / WSL / Git Bash users.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-./check_sprint.sh}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f core/theme/colors.py ]]; then
    echo "FATAL: not in MagicFactoryAI root." >&2
    exit 1
fi

if ! command -v python >/dev/null 2>&1; then
    echo "FATAL: python not found on PATH." >&2
    exit 1
fi
echo "Python: $(command -v python)"
python --version

PASS_COUNT=0
FAIL_COUNT=0

run_step() {
    local name="$1"
    local fn="$2"
    echo
    echo "[${name}] ..."
    if "$fn"; then
        echo "  PASS - ${name}"
        PASS_COUNT=$((PASS_COUNT+1))
    else
        echo "  FAIL - ${name}"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

TMP1="$(mktemp -t check_sprint_import.XXXXXX.py)"
TMP2="$(mktemp -t check_sprint_ast.XXXXXX.py)"
trap 'rm -f "$TMP1" "$TMP2"' EXIT

step_filesize() {
    local f="$1"; local minsize="$2"
    if [[ ! -f "$f" ]]; then echo "missing: $f" >&2; return 1; fi
    local kb; kb="$(du -k "$f" | cut -f1)"
    if (( kb < minsize )); then
        echo "$f is ${kb} KB (< ${minsize})" >&2; return 1
    fi
    echo "    $f - ${kb} KB"
}

step_files_all() {
    step_filesize app/controllers/project_dashboard_controller.py 10 \
    && step_filesize ui/screens/project_dashboard_screen.py     10 \
    && step_filesize ui/widgets/charts.py                          5
}

step_compileall() {
    set +e
    python -m compileall . >"$TMP1.log" 2>&1
    local code=$?
    set -e
    if (( code != 0 )); then
        echo "compileall exited $code" >&2
        cat "$TMP1.log" >&2
        return 1
    fi
    if grep -E -i "SyntaxError|IndentationError|invalid syntax" "$TMP1.log" >/dev/null; then
        echo "compileall reported syntax errors:" >&2
        cat "$TMP1.log" >&2
        return 1
    fi
}

step_import_smoke() {
    cat >"$TMP1" <<'PYEOF'
import importlib, sys
sys.path.insert(0, ".")
for m in (
    "app.controllers.project_dashboard_controller",
    "ui.widgets.charts",
):
    importlib.import_module(m)
from app.controllers.project_dashboard_controller import (
    DashboardAnalytics, TimeFilter,
)
from ui.widgets.charts import (
    BarChart, DonutChart, Sparkline, AnimatedKpiTile, TimeFilterBar,
)
expected = sorted([
    "time_filter", "daily", "weekly", "monthly",
    "status_breakdown", "kpis",
])
actual = sorted(DashboardAnalytics.__dataclass_fields__)
if actual != expected:
    raise AssertionError("DashboardAnalytics fields: " + str(actual))
for t in (TimeFilter.TODAY, TimeFilter.WEEK, TimeFilter.MONTH, TimeFilter.ALL):
    if t.value not in ("today", "week", "month", "all"):
        raise AssertionError("unexpected TimeFilter value: " + repr(t))
print("import OK")
PYEOF
    python "$TMP1"
}

step_ast() {
    cat >"$TMP2" <<'PYEOF'
import ast
ast.parse(open("ui/screens/project_dashboard_screen.py", encoding="utf-8").read())
print("screen AST OK")
PYEOF
    python "$TMP2"
}

run_step "files: presence + size" step_files_all
run_step "python: compileall"      step_compileall
run_step "import: analytics + chart widgets" step_import_smoke
run_step "ast: dashboard screen parses" step_ast

echo
echo "================ Sprint #12 Self-Test ================"
echo "  Passed: $PASS_COUNT    Failed: $FAIL_COUNT"
echo "======================================================"

if (( FAIL_COUNT > 0 )); then exit 1; else exit 0; fi
