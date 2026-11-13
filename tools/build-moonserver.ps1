# FSYL TV: build MoonTV standalone sidecar into app\moon.
# Usage: powershell -ExecutionPolicy Bypass -File tools/build-moonserver.ps1 [-OutDir <dir>]
param(
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $root 'build\moon'
}
$OutDir = [System.IO.Path]::GetFullPath($OutDir)

$pnpm = Join-Path $root 'tools\.cache\pnpm-tool\node_modules\pnpm\bin\pnpm.cjs'
if (-not (Test-Path $pnpm)) {
    throw "pnpm not found at $pnpm. Run the environment setup first."
}

$env:PATH = (Join-Path $root 'tools\.cache\pnpm-tool\node_modules\.bin') + ';' + $env:PATH
$env:PNPM_HOME = Join-Path $root 'tools\.cache\pnpm-home'
$env:npm_config_cache = Join-Path $root 'tools\.cache\npm-cache'
$env:NEXT_TELEMETRY_DISABLED = '1'
$env:HUSKY = '0'
$env:CI = '1'
$env:NEXT_PUBLIC_SITE_NAME = 'FSYL TV'
$env:SITE_NAME = 'FSYL TV'

$moon = Join-Path $root 'moonserver'
Push-Location $moon
try {
    if (-not (Test-Path (Join-Path $moon 'node_modules'))) {
        Write-Output '=== pnpm install ==='
        node $pnpm install --config.node-linker=hoisted --ignore-scripts --frozen-lockfile --reporter=append-only
        if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed' }
    }

    Write-Output '=== pnpm build ==='
    node $pnpm build
    if ($LASTEXITCODE -ne 0) { throw 'pnpm build failed' }

    Write-Output '=== assemble standalone ==='
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $server = Join-Path $OutDir 'server'
    New-Item -ItemType Directory -Force $server | Out-Null

    # robocopy handles long paths and spaces; exit codes 0-7 are success.
    robocopy (Join-Path $moon '.next\standalone') $server /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy standalone failed: $LASTEXITCODE" }
    New-Item -ItemType Directory -Force (Join-Path $server '.next') | Out-Null
    robocopy (Join-Path $moon '.next\static') (Join-Path $server '.next\static') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy static failed: $LASTEXITCODE" }
    robocopy (Join-Path $moon 'public') (Join-Path $server 'public') /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy public failed: $LASTEXITCODE" }

    Move-Item (Join-Path $server 'server.js') (Join-Path $server 'next-server.js') -Force
    Copy-Item (Join-Path $root 'tools\moon\server-wrapper.js') (Join-Path $server 'server.js') -Force
    Copy-Item 'C:\Program Files\nodejs\node.exe' (Join-Path $OutDir 'node.exe') -Force

    Write-Output "MOON_DIR=$OutDir"
    Write-Output "server.js=$(Test-Path (Join-Path $server 'server.js'))"
    Write-Output "next-server.js=$(Test-Path (Join-Path $server 'next-server.js'))"
    Write-Output "node.exe=$(Test-Path (Join-Path $OutDir 'node.exe'))"
} finally {
    Pop-Location
}

# robocopy uses 0-7 as success codes; do not leak those as a script failure.
exit 0
