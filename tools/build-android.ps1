# Elevated Android build for FSYL TV.
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

$sdkRoot = Join-Path $root 'tools\.cache\android-sdk'
$jdkRoot = Join-Path $root 'tools\.cache\jdk\jdk-17.0.14+7'
$env:JAVA_HOME = $jdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:PATH = "$jdkRoot\bin;$sdkRoot\platform-tools;$sdkRoot\cmdline-tools\latest\bin;$env:PATH"

$logDir = Join-Path $root 'build'
New-Item -ItemType Directory -Force $logDir | Out-Null
Set-Location (Join-Path $root 'app')

# Set config
& (Join-Path $root 'tools\.cache\flutter\bin\flutter.bat') config --android-sdk "$sdkRoot" --jdk-dir "$jdkRoot"

Write-Output "Starting flutter build apk..."
& (Join-Path $root 'tools\.cache\flutter\bin\flutter.bat') build apk --release --no-pub *> (Join-Path $logDir 'android-build.log')
$code = $LASTEXITCODE
Write-Output "ANDROID_BUILD_EXIT=$code" | Tee-Object -FilePath (Join-Path $logDir 'android-build-exit.txt')
exit $code
