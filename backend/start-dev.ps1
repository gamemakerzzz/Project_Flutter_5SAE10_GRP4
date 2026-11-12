$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$secretPath = Join-Path $PSScriptRoot 'data/jwt-secret.txt'
if (-not (Test-Path -LiteralPath $secretPath)) {
    New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot 'data') | Out-Null
    $secretBytes = New-Object byte[] 48
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    $generator.GetBytes($secretBytes)
    $generator.Dispose()
    [IO.File]::WriteAllText($secretPath, [Convert]::ToBase64String($secretBytes))
}
$env:JWT_SECRET = [IO.File]::ReadAllText($secretPath).Trim()
$env:BACKEND_ROOT = $PSScriptRoot
$env:HOST = '127.0.0.1'
if (-not $env:PORT) { $env:PORT = '8080' }
dart run bin/server.dart
