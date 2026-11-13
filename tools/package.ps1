# FSYL TV packaging: portable folder + installer bundle.
# Prerequisite: run after `git commit` (the GPL source archive is created from HEAD).
# The Flutter build itself must run elevated; this script can launch that for you.
param(
    [switch]$SkipBuild,
    [switch]$SkipSource
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$release = Join-Path $root 'app\build\windows\x64\runner\Release'
$dist = Join-Path $root 'dist'

function Assert-LastExit([string]$what) {
    if ($LASTEXITCODE -ge 1) { throw "$what failed: exit $LASTEXITCODE" }
}

if (-not $SkipBuild) {
    Write-Output '=== Flutter build (elevated) ==='
    $buildScript = Join-Path $root 'tools\elevated-build.ps1'
    $p = Start-Process powershell.exe -Verb RunAs -PassThru -Wait `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$buildScript`""
    $exitFile = Join-Path $root 'build\flutter-build-exit.txt'
    if (-not (Test-Path $exitFile) -or (Get-Content $exitFile -Raw).Trim() -ne 'FLUTTER_BUILD_EXIT=0') {
        throw 'Flutter build did not report success'
    }
}

if (-not (Test-Path (Join-Path $release 'kazumi.exe'))) {
    throw "Flutter release build not found: $release"
}

Write-Output '=== MoonTV sidecar ==='
& (Join-Path $root 'tools\build-moonserver.ps1') -OutDir (Join-Path $root 'build\moon')
if ($LASTEXITCODE -ne 0) { throw 'build-moonserver failed' }

Write-Output '=== Source archive (GPL-3.0) ==='
$sourceDir = Join-Path $root 'build\source'
if ($SkipSource) {
    New-Item -ItemType Directory -Force $sourceDir | Out-Null
} else {
    if (Test-Path $sourceDir) { Remove-Item $sourceDir -Recurse -Force }
    New-Item -ItemType Directory -Force $sourceDir | Out-Null
    $archive = Join-Path $sourceDir 'FSYLTV-source.zip'
    Push-Location $root
    try {
        git archive --format=zip --output="$archive" HEAD
        Assert-LastExit 'git archive'
    } finally {
        Pop-Location
    }
    Write-Output "source=$(Get-Item $archive | Select-Object -ExpandProperty Length) bytes"
}

$docs = @(
    'LICENSE', 'LICENSE-MOONTV-MIT', 'THIRD-PARTY-NOTICES.md', 'VENDOR.md',
    'SPEC.md', 'CHANGELOG.md', 'README.md', 'KNOWN-ISSUES.md', 'PROGRESS.md'
)

function Populate([string]$dest) {
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force $dest | Out-Null

    Write-Output "=== populate $dest ==="
    robocopy $release $dest /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy release failed: $LASTEXITCODE" }
    Move-Item (Join-Path $dest 'kazumi.exe') (Join-Path $dest 'fsyl_tv.exe') -Force

    $moonOut = Join-Path $dest 'moon'
    New-Item -ItemType Directory -Force $moonOut | Out-Null
    robocopy (Join-Path $root 'build\moon') $moonOut /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy moon failed: $LASTEXITCODE" }

    foreach ($doc in $docs) {
        $src = Join-Path $root $doc
        if (Test-Path $src) { Copy-Item $src (Join-Path $dest $doc) -Force }
    }
    if (Test-Path $sourceDir) {
        New-Item -ItemType Directory -Force (Join-Path $dest 'source') | Out-Null
        Copy-Item (Join-Path $sourceDir '*') (Join-Path $dest 'source') -Recurse -Force
    }
    Copy-Item (Join-Path $root 'tools\install.ps1') (Join-Path $dest 'install.ps1') -Force
    Copy-Item (Join-Path $root 'tools\uninstall.ps1') (Join-Path $dest 'uninstall.ps1') -Force
}

$portableParent = Join-Path $dist 'FSYLTV-Portable'
$portable = Join-Path $portableParent 'FSYLTV'
Populate $portable

$setupParent = Join-Path $dist 'FSYLTV-Setup'
$payload = Join-Path $setupParent 'payload'
Populate $payload
Copy-Item (Join-Path $root 'tools\install.ps1') (Join-Path $setupParent 'install.ps1') -Force
Copy-Item (Join-Path $root 'tools\uninstall.ps1') (Join-Path $setupParent 'uninstall.ps1') -Force

Write-Output '=== zip ==='
$portableZip = Join-Path $dist 'FSYLTV-windows-portable.zip'
$setupZip = Join-Path $dist 'FSYLTV-windows-setup.zip'
Remove-Item $portableZip, $setupZip -Force -ErrorAction SilentlyContinue
tar.exe -a -c -f $portableZip -C $portableParent 'FSYLTV'
Assert-LastExit 'portable zip'
tar.exe -a -c -f $setupZip -C $setupParent '.'
Assert-LastExit 'setup zip'

# Build a real installer EXE with the 7-Zip SFX module. The archive contains
# install.ps1 + payload; the SFX extracts to a temp dir and runs the script.
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$sfxModule = 'C:\Program Files\7-Zip\7z.sfx'
$setupExe = Join-Path $dist 'FSYLTV-Setup.exe'
if ((Test-Path $sevenZip) -and (Test-Path $sfxModule)) {
    Write-Output '=== installer exe ==='
    $stage = Join-Path $root 'build\sfx-stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    New-Item -ItemType Directory -Force $stage | Out-Null
    Copy-Item (Join-Path $root 'tools\install.ps1') (Join-Path $stage 'install.ps1') -Force
    Copy-Item (Join-Path $root 'tools\uninstall.ps1') (Join-Path $stage 'uninstall.ps1') -Force
    robocopy $payload (Join-Path $stage 'payload') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    $archive = Join-Path $root 'build\fsyl-sfx.7z'
    Remove-Item $archive -Force -ErrorAction SilentlyContinue
    Push-Location $stage
    try { & $sevenZip a -t7z -mx=5 $archive '*' | Out-Null } finally { Pop-Location }
    $config = Join-Path $root 'build\fsyl-sfx-config.txt'
    $configText = ";!@Install@!UTF-8!`r`nTitle=`"FSYL TV`"`r`nGUIMode=`"2`"`r`nRunProgram=`"powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1`"`r`nDelete=`"1`"`r`n;!@InstallEnd@!`r`n"
    [System.IO.File]::WriteAllText($config, $configText, (New-Object System.Text.UTF8Encoding($false)))
    Remove-Item $setupExe -Force -ErrorAction SilentlyContinue
    $out = [System.IO.File]::Create($setupExe)
    try {
        foreach ($part in @($sfxModule, $config, $archive)) {
            $input = [System.IO.File]::OpenRead($part)
            try { $input.CopyTo($out) } finally { $input.Close() }
        }
    } finally { $out.Close() }
    Write-Output "SETUP_EXE=$setupExe ($((Get-Item $setupExe).Length) bytes)"
} else {
    Write-Output 'WARN: 7-Zip SFX not found; installer EXE not built'
}

Get-Item $portableZip, $setupZip | Select-Object FullName, Length
Write-Output "PORTABLE=$portable"
Write-Output "SETUP=$setupParent"
