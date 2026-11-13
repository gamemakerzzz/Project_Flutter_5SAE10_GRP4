param([string]$Device)
$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw 'Android platform-tools were not found.' }
if (-not $Device) {
    $phones = @(& $adb devices | Where-Object { $_ -match '^\S+\s+device$' -and $_ -notmatch '^emulator-' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($phones.Count -ne 1) { throw 'Connect and authorize one phone, or pass -Device SERIAL.' }
    $Device = $phones[0]
}
& "$PSScriptRoot/start-services.ps1"
foreach ($port in @(18080, 18081)) {
    & $adb -s $Device reverse "tcp:$port" "tcp:$port"
    if ($LASTEXITCODE -ne 0) { throw "USB forwarding failed for port $port." }
}
$apk = Join-Path $PSScriptRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw 'Build the USB release APK first; see docs/local-development.md.' }
& $adb -s $Device install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'APK installation failed; existing app data has been preserved.' }
& $adb -s $Device shell am start -n com.example.smart_learning/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
