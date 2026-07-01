# Sprint #12 - Dashboard PRO 3 - Verification Script (Windows PowerShell)
# ---------------------------------------------------------------------
# Runs the lightweight self-tests for the Sprint #12 deliverables:
#   1. file-existence + sane size for the three touched/new files
#   2. python -m compileall . (no SyntaxError / IndentationError)
#   3. targeted import smoke test for the new analytics types + chart widgets
#   4. ast.parse() on the dashboard screen
#
# Usage (from the MagicFactoryAI project root):
#     powershell -ExecutionPolicy Bypass -File .\check_sprint.ps1
# Or simply  .\check_sprint.ps1  (the script self-bypasses ExecutionPolicy
# for the current process so pasted-and-prayed runs work).
# ---------------------------------------------------------------------

# Self-bypass ExecutionPolicy so beginners don't hit "running scripts is
# disabled" on first run. Scope=Process so it doesn't change global state.
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
} catch { }

# Re-anchor to the script's own directory so the user can run it from
# anywhere and the relative paths inside still resolve. Falls back to
# $PWD if $PSScriptRoot is unavailable.
$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = (Get-Location).Path }
Set-Location -LiteralPath $projectRoot -ErrorAction SilentlyContinue

# Sanity-check: refuse to run if we are not in the project root.
if (-not (Test-Path -LiteralPath 'core/theme/colors.py')) {
    Write-Host "FATAL: not in MagicFactoryAI root (run this script from the project folder)." -ForegroundColor Red
    exit 1
}

$ErrorActionPreference = "Stop"
$script:results = @()

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    Write-Host ""
    Write-Host "[$Name] ..." -ForegroundColor Cyan
    try {
        & $Block
        Write-Host "  PASS - $Name" -ForegroundColor Green
        $script:results += @{ Name = $Name; Status = "PASS" }
        return $true
    }
    catch {
        Write-Host "  FAIL - $Name" -ForegroundColor Red
        Write-Host ("    " + $_.Exception.Message) -ForegroundColor DarkYellow
        $script:results += @{ Name = $Name; Status = "FAIL"; Error = $_.Exception.Message }
        return $false
    }
}

# -- Locate Python ---------------------------------------------------------
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) {
    Write-Host "FATAL: python not found on PATH." -ForegroundColor Red
    exit 1
}
Write-Host "Python: $python" -ForegroundColor DarkGray
& python --version

# -- 1. File existence -----------------------------------------------------
Test-Step "files: presence + size" {
    $expected = @(
        @{ Path = "app/controllers/project_dashboard_controller.py"; MinKB = 10 },
        @{ Path = "ui/screens/project_dashboard_screen.py";            MinKB = 10 },
        @{ Path = "ui/widgets/charts.py";                              MinKB = 5  }
    )
    foreach ($f in $expected) {
        if (-not (Test-Path -LiteralPath $f.Path)) {
            throw "missing file: $($f.Path)"
        }
        $size = (Get-Item -LiteralPath $f.Path).Length / 1KB
        if ($size -lt $f.MinKB) {
            throw ("{0} is only {1:N1} KB (expected >= {2} KB)" -f $f.Path, $size, $f.MinKB)
        }
        Write-Host ("    {0} - {1:N1} KB" -f $f.Path, $size) -ForegroundColor DarkGray
    }
}

# -- 2. compileall ---------------------------------------------------------
Test-Step "python: compileall" {
    # NOTE: do NOT pipe through Out-String -> $LASTEXITCODE would then
    # reflect Out-String (always 0), masking real Python failures.
    $output = & python -m compileall . 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("compileall exited with code {0}`n{1}" -f $LASTEXITCODE, ($output -join "`n"))
    }
    $joined = ($output -join "`n")
    if ($joined -match "(?i)SyntaxError|IndentationError|invalid syntax") {
        throw ("compileall reported syntax errors:`n{0}" -f $joined)
    }
}

# -- 3. import smoke -------------------------------------------------------
Test-Step "import: analytics + chart widgets" {
    # NOTE: write the Python program to a temp file rather than passing
    # it via ``python -c`` — the latter breaks on Windows when the
    # script file uses CRLF line endings or when the embedded source
    # contains f-strings / double quotes that PowerShell mangled while
    # passing through the command line.
    $tmp = New-TemporaryFile
    @'
import importlib, sys
sys.path.insert(0, ".")
for m in (
    "app.controllers.project_dashboard_controller",
    "ui.widgets.charts",
):
    importlib.import_module(m)

from app.controllers.project_dashboard_controller import (
    DashboardAnalytics,
    TimeFilter,
)
from ui.widgets.charts import (
    BarChart,
    DonutChart,
    Sparkline,
    AnimatedKpiTile,
    TimeFilterBar,
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
'@ | Set-Content -Path $tmp -Encoding utf8

    try {
        & python $tmp.FullName
        $code = $LASTEXITCODE
    }
    finally {
        Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) { throw "import smoke test failed (exit $code)" }
}

# -- 4. screen AST parse ---------------------------------------------------
Test-Step "ast: dashboard screen parses" {
    $tmp = New-TemporaryFile
    @'
import ast
ast.parse(open("ui/screens/project_dashboard_screen.py", encoding="utf-8").read())
print("screen AST OK")
'@ | Set-Content -Path $tmp -Encoding utf8

    try {
        & python $tmp.FullName
        $code = $LASTEXITCODE
    }
    finally {
        Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) { throw "screen AST parse failed (exit $code)" }
}

# -- Summary ---------------------------------------------------------------
Write-Host ""
Write-Host "================ Sprint #12 Self-Test ================" -ForegroundColor Magenta
foreach ($r in $script:results) {
    $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host ("  {0,-7} {1}" -f $r.Status, $r.Name) -ForegroundColor $color
}
$failed = @($script:results | Where-Object { $_.Status -eq "FAIL" }).Count
$passed = @($script:results | Where-Object { $_.Status -eq "PASS" }).Count
Write-Host "------------------------------------------------------" -ForegroundColor Magenta
Write-Host ("  Passed: {0}    Failed: {1}" -f $passed, $failed) -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta

if ($failed -gt 0) { exit 1 } else { exit 0 }
