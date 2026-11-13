param([string]$PhoneAddress, [switch]$Install)
$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$savedAddress = Join-Path $PSScriptRoot '.dart_tool/phone-wifi-address.txt'
if (-not $PhoneAddress -and (Test-Path -LiteralPath $savedAddress)) {
    $PhoneAddress = [IO.File]::ReadAllText($savedAddress).Trim()
}
if ($PhoneAddress -notmatch '^\d{1,3}(\.\d{1,3}){3}:\d{1,5}$') {
    throw 'Pass -PhoneAddress with the phone Wi-Fi address and ADB port, such as 192.168.1.20:5555.'
}
& "$PSScriptRoot/start-services.ps1"
& $adb connect $PhoneAddress
if ((& $adb -s $PhoneAddress get-state) -ne 'device') {
    throw 'Phone is not authorized or reachable over Wi-Fi. Reconnect USB and enable adb tcpip 5555, or pair Wireless debugging again.'
}
foreach ($port in @(18080, 18081)) {
    & $adb -s $PhoneAddress reverse "tcp:$port" "tcp:$port"
    if ($LASTEXITCODE -ne 0) { throw "Wireless forwarding failed for port $port." }
}
[IO.File]::WriteAllText($savedAddress, $PhoneAddress)
if ($Install) {
    & $adb -s $PhoneAddress install -r "$PSScriptRoot/build/app/outputs/flutter-apk/app-release.apk"
    if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
}
& $adb -s $PhoneAddress shell am start -n com.example.smart_learning/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
Write-Host 'StudyMate is connected over Wi-Fi. USB can be disconnected. Keep the PC and phone on the same network.'
