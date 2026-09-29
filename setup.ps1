$ErrorActionPreference = "Stop"
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "        PocketSmart AI - Setup" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Set-Location $PSScriptRoot

if (Get-Command python -ErrorAction SilentlyContinue) {
    $python = "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $python = "py"
} else {
    throw "Python was not found. Install Python 3.11+ and run setup again."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js was not found. Install Node.js 20+ and run setup again."
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm was not found. Install Node.js 20+ and run setup again."
}

Write-Host "[1/4] Creating Python virtual environment..." -ForegroundColor Yellow
if (-not (Test-Path ".venv")) { & $python -m venv .venv }

Write-Host "[2/4] Installing backend dependencies..." -ForegroundColor Yellow
& ".\.venv\Scripts\python.exe" -m pip install --upgrade pip
& ".\.venv\Scripts\python.exe" -m pip install -r ".ackendequirements.txt"

Write-Host "[3/4] Installing frontend dependencies..." -ForegroundColor Yellow
Push-Location ".rontend"
npm install
Pop-Location

Write-Host "[4/4] Checking environment file..." -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env. Add your OpenAI API key before starting." -ForegroundColor Magenta
}

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "Run: .un.ps1" -ForegroundColor Cyan
