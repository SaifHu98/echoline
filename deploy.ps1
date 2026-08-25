# ECHO//LINE — Deployment Helper for Windows PowerShell 5.1+
# Run: cd D:\EcoUni\Echos && .\deploy.ps1

$GitHubUsername = "SaifHu98"
$RepoName = "echoline"
$CommitMessage = "ECHO//LINE v1.0.0 deployment"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ECHO//LINE - Deployment Helper" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check git is installed
$gitCheck = & git --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Git not installed. Install from https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "Git found: $gitCheck" -ForegroundColor Green

# Check we're in the right directory
if (-not (Test-Path -LiteralPath ".\game-server\package.json")) {
    Write-Host "ERROR: Please run from D:\EcoUni\Echos\" -ForegroundColor Red
    Write-Host "  cd D:\EcoUni\Echos" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1" -ForegroundColor Yellow
    exit 1
}

# Initialize git if not already
if (-not (Test-Path -LiteralPath ".\.git")) {
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    & git init 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# Configure git
Write-Host "Configuring git..." -ForegroundColor Yellow
& git config user.name "$GitHubUsername" 2>&1 | Out-Null
& git config user.email "$GitHubUsername@users.noreply.github.com" 2>&1 | Out-Null

# Add remote if not exists
$existingRemote = & git remote get-url origin 2>$null
if (-not $existingRemote) {
    $remoteUrl = "https://github.com/$GitHubUsername/$RepoName.git"
    Write-Host "Adding remote origin: $remoteUrl" -ForegroundColor Yellow
    & git remote add origin $remoteUrl 2>&1 | Out-Null
} else {
    Write-Host "Remote already configured: $existingRemote" -ForegroundColor Green
}

# Check git status
Write-Host ""
Write-Host "Files to be committed (first 20):" -ForegroundColor Yellow
& git status --short 2>&1 | Select-Object -First 20

# Stage and commit
Write-Host ""
Write-Host "Staging all files..." -ForegroundColor Yellow
& git add . 2>&1 | Out-Null

Write-Host "Committing..." -ForegroundColor Yellow
$commitOutput = & git commit -m "$CommitMessage" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Nothing new to commit" -ForegroundColor Yellow
}

# Rename branch to main if not already
$currentBranch = & git branch --show-current 2>&1
if ($currentBranch -ne "main") {
    & git branch -M main 2>&1 | Out-Null
}

# Push
Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
Write-Host "  (You may be prompted for credentials)" -ForegroundColor Gray
Write-Host ""

& git push -u origin main --force

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SUCCESS: Pushed to GitHub!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Visit: https://github.com/$GitHubUsername/$RepoName" -ForegroundColor White
    Write-Host "  2. Go to: https://dashboard.render.com" -ForegroundColor White
    Write-Host "  3. New + -> Blueprint -> Select echoline repo" -ForegroundColor White
    Write-Host "  4. Wait for build (~3 minutes)" -ForegroundColor White
    Write-Host ""
    Write-Host "See DEPLOYMENT.md for full guide." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  FAILED: Push did not succeed" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  - Wrong username/password" -ForegroundColor White
    Write-Host "  - 2FA enabled -> need Personal Access Token:" -ForegroundColor White
    Write-Host "    https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host "  - Or use: gh auth login (if GitHub CLI installed)" -ForegroundColor White
}