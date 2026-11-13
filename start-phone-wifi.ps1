param(
    [ipaddress]$PcAddress = '192.168.187.96',
    [ipaddress]$PhoneAddress = '192.168.187.208'
)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/start-services.ps1"
$bridge = Get-NetTCPConnection -State Listen -LocalAddress $PcAddress.IPAddressToString -LocalPort 18080,18081 -ErrorAction SilentlyContinue
if (@($bridge).Count -eq 2) {
    Write-Host "Wi-Fi listeners already running on $PcAddress."
    return
}
if ($bridge) { throw 'One Wi-Fi port is already in use. Check ports 18080 and 18081.' }
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
$process = Start-Process -FilePath $python -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
    -ArgumentList @('backend/wifi_bridge.py', $PcAddress.IPAddressToString, $PhoneAddress.IPAddressToString) `
    -RedirectStandardOutput "$PSScriptRoot/backend/wifi-bridge.log" `
    -RedirectStandardError "$PSScriptRoot/backend/wifi-bridge-error.log"
Start-Sleep -Seconds 1
if ($process.HasExited) { throw 'Wi-Fi relay failed. Check backend/wifi-bridge-error.log.' }
Write-Host "StudyMate Wi-Fi relay ready for $PhoneAddress."
