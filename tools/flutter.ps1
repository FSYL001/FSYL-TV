param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

# Dev-only wrapper: the restricted harness environment denies Dart writes to
# %APPDATA%, so point Flutter's config/cache dirs into the workspace.
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

& (Join-Path $root 'tools\.cache\flutter\bin\flutter.bat') @FlutterArgs
exit $LASTEXITCODE
