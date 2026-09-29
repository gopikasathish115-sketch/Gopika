$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    & ".\setup.ps1"
}
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
}

$envText = Get-Content ".env" -Raw
if ($envText -match "OPENAI_API_KEY\s*=\s*PASTE_YOUR_OPENAI_API_KEY_HERE") {
    Write-Host ""
    Write-Host "WARNING: OPENAI_API_KEY is still a placeholder." -ForegroundColor Yellow
    Write-Host "Edit .env, add your own API key, and run .un.ps1 again." -ForegroundColor Yellow
    exit 1
}

$backendCommand = @"
Set-Location '$PSScriptRoot'
& '.\.venv\Scripts\python.exe' -m uvicorn app.main:app --app-dir '.ackend' --host 127.0.0.1 --port 8000 --reload
"@

$frontendCommand = @"
Set-Location '$PSScriptRootrontend'
npm run dev
"@

Write-Host ""
Write-Host "Starting PocketSmart AI..." -ForegroundColor Cyan
Write-Host "Backend : http://127.0.0.1:8000" -ForegroundColor Green
Write-Host "Docs    : http://127.0.0.1:8000/docs" -ForegroundColor Green
Write-Host "Frontend: http://localhost:5173" -ForegroundColor Green
Write-Host ""

Start-Process powershell.exe -ArgumentList @("-NoExit","-ExecutionPolicy","Bypass","-Command",$backendCommand)
Start-Sleep -Seconds 2
Start-Process powershell.exe -ArgumentList @("-NoExit","-ExecutionPolicy","Bypass","-Command",$frontendCommand)
Start-Sleep -Seconds 3

try { Start-Process "http://localhost:5173" } catch {
    Write-Host "Open http://localhost:5173 manually." -ForegroundColor Yellow
}

Write-Host "Both servers are running in separate PowerShell windows." -ForegroundColor Green
Write-Host "Close those windows to stop them."
