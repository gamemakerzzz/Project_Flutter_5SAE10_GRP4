$ErrorActionPreference = 'Stop'
function Test-ServiceHealth([int]$Port) {
    try { return (Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 2).status -eq 'ok' }
    catch { return $false }
}
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Create .venv and install backend/requirements.txt first (see docs/local-development.md).'
}
if (-not (Test-ServiceHealth 18080)) {
    $previousPort = $env:PORT
    try {
        $env:PORT = '18080'
        Start-Process powershell -WindowStyle Hidden -WorkingDirectory "$PSScriptRoot/backend" `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSScriptRoot/backend/start-dev.ps1`"") `
            -RedirectStandardOutput "$PSScriptRoot/backend/auth-service.log" `
            -RedirectStandardError "$PSScriptRoot/backend/auth-service-error.log" | Out-Null
    } finally { $env:PORT = $previousPort }
}
if (-not (Test-ServiceHealth 18081)) {
    $previousPort = $env:PORT
    try {
        $env:PORT = '18081'
        Start-Process $python -WindowStyle Hidden -WorkingDirectory $PSScriptRoot `
            -ArgumentList @("`"$PSScriptRoot/backend/server.py`"") `
            -RedirectStandardOutput "$PSScriptRoot/backend/ai-service.log" `
            -RedirectStandardError "$PSScriptRoot/backend/ai-service-error.log" | Out-Null
    } finally { $env:PORT = $previousPort }
}
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    if ((Test-ServiceHealth 18080) -and (Test-ServiceHealth 18081)) {
        Write-Host 'Account API ready on 18080; learning AI ready on 18081.'
        return
    }
    Start-Sleep -Seconds 1
}
throw 'A local service failed to start. Check backend/*service*.log.'
