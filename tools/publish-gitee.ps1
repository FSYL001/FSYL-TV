# Mirror FSYL TV to Gitee and publish release assets.
# Requires a Gitee personal access token with projects/repos permission:
#   powershell -File tools/publish-gitee.ps1 -Token <token> -Version 1.0.4
param(
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Version = '',
    [string]$Owner = 'FSYL001',
    [string]$Repo = 'FSYL-TV'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Select-String -Path (Join-Path $root 'app\lib\shell\app_version.dart') `
        -Pattern "current = '([^']+)'").Matches[0].Groups[1].Value
}
$tag = "v$Version"
$api = 'https://gitee.com/api/v5'

Write-Output "Gitee mirror: $Owner/$Repo $tag"

Push-Location $root
try {
    $repoJson = & curl.exe -s -X GET "$api/repos/$Owner/$Repo?access_token=$Token"
    $repo = $repoJson | ConvertFrom-Json
    if ($repo.message -or -not $repo.full_name) {
        Write-Output 'Creating Gitee repository...'
        $created = & curl.exe -s -X POST "$api/user/repos" `
            --data-urlencode "access_token=$Token" `
            --data-urlencode "name=$Repo" `
            --data-urlencode "description=FSYL TV - Windows single-window anime and movie client" `
            --data-urlencode 'private=false' `
            --data-urlencode 'auto_init=false'
        if ($created -match '"message"') { throw "Gitee create repo failed: $created" }
    }

    $remoteUrl = "https://oauth2:$Token@gitee.com/$Owner/$Repo.git"
    git remote remove gitee 2>$null | Out-Null
    git remote add gitee $remoteUrl
    git push gitee main
    git push gitee $tag

    $releaseBody = @{
        access_token = $Token
        tag_name = $tag
        name = "FSYL TV $Version"
        body = "FSYL TV $Version. Windows portable ZIP and Setup.exe."
        target_commitish = 'main'
    }
    $release = (& curl.exe -s -X POST "$api/repos/$Owner/$Repo/releases" `
        --data-urlencode "access_token=$Token" `
        --data-urlencode "tag_name=$tag" `
        --data-urlencode "name=FSYL TV $Version" `
        --data-urlencode "body=FSYL TV $Version. Windows portable ZIP and Setup.exe." `
        --data-urlencode 'target_commitish=main') | ConvertFrom-Json
    if (-not $release.id) { throw "Gitee release create failed: $release" }

    foreach ($asset in @(
        'dist\FSYLTV-windows-portable.zip',
        'dist\FSYLTV-Setup.exe'
    )) {
        $path = Join-Path $root $asset
        if (-not (Test-Path $path)) { throw "missing asset: $path" }
        Write-Output "Uploading $asset ..."
        & curl.exe -s -X POST "$api/repos/$Owner/$Repo/releases/$($release.id)/attach_files" `
            -F "access_token=$Token" `
            -F "file=@$path"
    }
} finally {
    Pop-Location
}
Write-Output "GITEE_RELEASE=$tag"
