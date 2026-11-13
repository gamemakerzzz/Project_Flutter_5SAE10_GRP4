param(
    [string]$Device = 'emulator-5554',
    [string]$ApiBaseUrl = 'http://10.0.2.2:18080'
)

# Android plugin registration must finish even without Windows symlink support.
$previousWindows = $env:FLUTTER_WINDOWS
$previousLinux = $env:FLUTTER_LINUX
Push-Location $PSScriptRoot
try {
    & "$PSScriptRoot/start-services.ps1"
    $env:FLUTTER_WINDOWS = 'false'
    $env:FLUTTER_LINUX = 'false'
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency setup failed.' }
    flutter run --no-pub -d $Device "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter launch failed.' }
} finally {
    $env:FLUTTER_WINDOWS = $previousWindows
    $env:FLUTTER_LINUX = $previousLinux
    Pop-Location
}
