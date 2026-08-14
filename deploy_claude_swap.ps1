# deploy_claude_swap.ps1
# Deploys the HelixGemini -> HelixClaude swap for web_search_agent.py
# (and narrative_enricher.py if it changed too), with a timestamped
# backup of whatever was there before, then verifies the swap landed
# correctly before you restart.
#
# This script does NOT set your Vertex/Helix env vars — those already
# live correctly in your existing start_backend.ps1 / run_diagnosis.ps1.
# Add the one new line Stylus gives you for VERTEX_CLAUDE_PROJECT_LOCATION
# to those files yourself; this script only handles the file swap +
# restart + verification.

param(
    [string]$Backend = "C:\Users\ak54743\Downloads\OneDrive_2026-07-16\Rapid Portfolio Review - Copy\backend",
    [string]$Downloads = "C:\Users\ak54743\Downloads"
)

$ErrorActionPreference = "Stop"
$ts = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "=== Claude swap deploy ===" -ForegroundColor Cyan
Write-Host "Backend: $Backend"
Write-Host ""

# ---------------------------------------------------------------------
# 1. Confirm source files exist before touching anything
# ---------------------------------------------------------------------
$filesToDeploy = @("web_search_agent.py", "narrative_enricher.py")
$missing = @()
foreach ($f in $filesToDeploy) {
    $src = Join-Path $Downloads $f
    if (-not (Test-Path $src)) { $missing += $src }
}
if ($missing.Count -gt 0) {
    Write-Host "Missing source file(s) in $Downloads :" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "Save the artifact(s) from Stylus to $Downloads first, then re-run." -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------------------
# 2. Backup whatever is currently deployed, with a timestamp
# ---------------------------------------------------------------------
$backupDir = Join-Path $Backend "_pre_claude_swap_backup_$ts"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "Backing up current files to: $backupDir" -ForegroundColor Cyan

foreach ($f in $filesToDeploy) {
    $current = Join-Path $Backend $f
    if (Test-Path $current) {
        Copy-Item $current (Join-Path $backupDir $f) -Force
        Write-Host "  backed up: $f"
    } else {
        Write-Host "  (no existing $f to back up — first deploy)"
    }
}

# ---------------------------------------------------------------------
# 3. Deploy the new files
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Deploying new files..." -ForegroundColor Cyan
foreach ($f in $filesToDeploy) {
    Copy-Item (Join-Path $Downloads $f) (Join-Path $Backend $f) -Force
    Write-Host "  deployed: $f"
}

# ---------------------------------------------------------------------
# 4. Verify the swap actually landed — don't trust, check the file
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan

$wsa = Join-Path $Backend "web_search_agent.py"

$hasClaudeImport = Select-String -Path $wsa -Pattern "from helix_adk_adapter\.custom_anthropic_llm import HelixClaude" -Quiet
$hasRegistry      = Select-String -Path $wsa -Pattern "LLMRegistry\.register\(HelixClaude\)" -Quiet
$hasGeminiOnly    = Select-String -Path $wsa -Pattern 'model\s*=\s*HelixGemini' -Quiet

$ok = $true

if ($hasClaudeImport) {
    Write-Host "  [OK] HelixClaude import present" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] HelixClaude import NOT found — old file may still be deployed" -ForegroundColor Red
    $ok = $false
}

if ($hasRegistry) {
    Write-Host "  [OK] LLMRegistry.register(HelixClaude) present" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] LLMRegistry.register(HelixClaude) NOT found — model routing will silently stay on Gemini" -ForegroundColor Red
    $ok = $false
}

if ($hasGeminiOnly) {
    Write-Host "  [WARN] web_search_agent still references HelixGemini somewhere — check it's not still the active model=" -ForegroundColor Yellow
}

if (-not $ok) {
    Write-Host ""
    Write-Host "Verification failed. NOT restarting the backend." -ForegroundColor Red
    Write-Host "Old files were backed up to: $backupDir" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Verification passed." -ForegroundColor Green
Write-Host ""
Write-Host "REMINDER: add `$Env:VERTEX_CLAUDE_PROJECT_LOCATION = ""us-east5""" -ForegroundColor Yellow
Write-Host "to your env var block (start_backend.ps1 / this session) if you haven't already," -ForegroundColor Yellow
Write-Host "and confirm R2D2_MODEL matches what web_search_agent.py now reads." -ForegroundColor Yellow
Write-Host ""

# ---------------------------------------------------------------------
# 5. Stop any existing backend on port 8000, then restart
# ---------------------------------------------------------------------
Write-Host "Checking for an existing process on port 8000..." -ForegroundColor Cyan
$existing = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique

if ($existing) {
    foreach ($procId in $existing) {
        Write-Host "  stopping process $procId on port 8000"
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
} else {
    Write-Host "  nothing running on port 8000"
}

Write-Host ""
Write-Host "=== Ready to restart ===" -ForegroundColor Cyan
Write-Host "Run your normal start_backend.ps1 / run_diagnosis.ps1 now (with the env" -ForegroundColor White
Write-Host "vars set, including VERTEX_CLAUDE_PROJECT_LOCATION), then watch the terminal" -ForegroundColor White
Write-Host "log for the model line during a scan. You're looking for a line containing" -ForegroundColor White
Write-Host "'claude-sonnet' - NOT 'gemini-2.5-flash' - as ground truth that the swap is live." -ForegroundColor White
