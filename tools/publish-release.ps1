# Publish a FSYL TV GitHub release consumed by the in-app updater.
# Usage: powershell -ExecutionPolicy Bypass -File tools/publish-release.ps1 -Version 1.0.1
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [switch]$SkipBuild,
    [switch]$SkipPackage
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = $Version.TrimStart('v', 'V')
$tag = "v$version"

$appVersionFile = Join-Path $root 'app\lib\shell\app_version.dart'
$current = (Select-String -Path $appVersionFile -Pattern "current = '([^']+)'").Matches[0].Groups[1].Value
if ($current -ne $version) {
    throw "AppVersion.current is $current, but release version is $version. Update app/lib/shell/app_version.dart first."
}

Push-Location $root
try {
    $dirty = git status --porcelain
    if ($dirty) {
        throw "Working tree is dirty. Commit all changes before publishing:`n$dirty"
    }
    if (-not (Test-Path 'origin')) {
        git remote add origin 'https://github.com/FSYL001/FSYL-TV.git'
    }
    git tag $tag
    git push origin main
    git push origin $tag
} finally {
    Pop-Location
}

if (-not $SkipPackage) {
    $packageArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $root 'tools\package.ps1')
    )
    if ($SkipBuild) { $packageArgs += '-SkipBuild' }
    & powershell.exe @packageArgs
    if ($LASTEXITCODE -ne 0) { throw 'package.ps1 failed' }
}

$assets = @(
    'dist\FSYLTV-windows-portable.zip',
    'dist\FSYLTV-windows-setup.zip'
) | ForEach-Object { Join-Path $root $_ }
foreach ($asset in $assets) {
    if (-not (Test-Path $asset)) { throw "missing release asset: $asset" }
}

Push-Location $root
try {
    $ghArgs = @(
        'release', 'create', $tag
    ) + $assets + @(
        '--repo', 'FSYL001/FSYL-TV',
        '--title', "FSYL TV $version",
        '--notes', "FSYL TV $version release. Windows portable and setup builds."
    )
    & gh @ghArgs
} finally {
    Pop-Location
}
Write-Output "RELEASED=$tag"
