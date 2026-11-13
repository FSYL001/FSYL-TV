# Elevated Windows build for FSYL TV.
# Flutter needs SeCreateSymbolicLinkPrivilege for plugin symlinks; this script is
# launched with Start-Process -Verb RunAs. It redirects Flutter's home/temp into
# the workspace because the harness denies Dart writes to the real %APPDATA%.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$homeDir = Join-Path $root 'tools\.cache\home'
$tempDir = Join-Path $root 'tools\.cache\temp'
New-Item -ItemType Directory -Force `
    (Join-Path $homeDir 'AppData\Roaming'), `
    (Join-Path $homeDir 'AppData\Local'), `
    (Join-Path $homeDir '.config'), `
    $tempDir | Out-Null

$env:APPDATA = Join-Path $homeDir 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeDir 'AppData\Local'
$env:HOME = $homeDir
$env:USERPROFILE = $homeDir
$env:TEMP = $tempDir
$env:TMP = $tempDir
$env:PUB_CACHE = Join-Path $root 'tools\.cache\pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

$logDir = Join-Path $root 'build'
New-Item -ItemType Directory -Force $logDir | Out-Null
# MSVC C2026 workaround for the pinned ech_http package (local pub cache only).
& node (Join-Path $root 'tools\patch-ech-http.js') *>> (Join-Path $logDir 'flutter-build.log')
Set-Location (Join-Path $root 'app')
& (Join-Path $root 'tools\.cache\flutter\bin\flutter.bat') build windows --release --no-pub *> (Join-Path $logDir 'flutter-build.log')
$code = $LASTEXITCODE
Write-Output "FLUTTER_BUILD_EXIT=$code" | Tee-Object -FilePath (Join-Path $logDir 'flutter-build-exit.txt')
exit $code
