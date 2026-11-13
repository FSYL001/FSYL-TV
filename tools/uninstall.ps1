# FSYL TV uninstaller (per-user).
# Removes the program and asks whether to keep %LOCALAPPDATA%\FSYLTV\data.
$ErrorActionPreference = 'Stop'

$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$root = Join-Path $localAppData 'FSYLTV'
$appDir = Join-Path $root 'app'
$dataDir = Join-Path $root 'data'

Write-Host 'FSYL TV uninstaller'
Get-Process -Name fsyl_tv, kazumi -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1

$removeData = Read-Host '同时删除观看记录、收藏与账号数据？(y/N)'
if ($removeData -match '^[yY]') {
    if (Test-Path $dataDir) { Remove-Item $dataDir -Recurse -Force }
    Write-Host 'data removed.'
} else {
    Write-Host 'data kept at' $dataDir
}

if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }

$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'FSYL TV.lnk'
$desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FSYL TV.lnk'
Remove-Item $startMenu, $desktop -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FSYLTV' `
    -Recurse -Force -ErrorAction SilentlyContinue

Write-Host 'FSYL TV removed.'
