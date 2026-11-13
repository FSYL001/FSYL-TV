# FSYL TV installer (per-user, no admin required).
# Copies the payload to %LOCALAPPDATA%\FSYLTV\app and creates shortcuts.
# Existing data in %LOCALAPPDATA%\FSYLTV\data is never touched.
$ErrorActionPreference = 'Stop'

$source = $PSScriptRoot
if (Test-Path (Join-Path $PSScriptRoot 'payload')) {
    $source = Join-Path $PSScriptRoot 'payload'
}

$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$root = Join-Path $localAppData 'FSYLTV'
$appDir = Join-Path $root 'app'
$dataDir = Join-Path $root 'data'
$exe = Join-Path $appDir 'fsyl_tv.exe'

Write-Host 'FSYL TV installer'
Write-Host "  program: $appDir"
Write-Host "  data   : $dataDir (kept on upgrade)"
Write-Host ''

Get-Process -Name fsyl_tv, kazumi -ErrorAction SilentlyContinue |
    ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep -Seconds 2
Get-Process -Name fsyl_tv, kazumi -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Force $appDir | Out-Null
New-Item -ItemType Directory -Force $dataDir | Out-Null

Write-Host 'Copying program files...'
robocopy $source $appDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'FSYL TV.lnk'
$desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FSYL TV.lnk'
foreach ($shortcutPath in @($startMenu, $desktop)) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe
    $shortcut.WorkingDirectory = $appDir
    $shortcut.IconLocation = $exe
    $shortcut.Description = 'FSYL TV'
    $shortcut.Save()
}

# Per-user uninstall entry (no admin required).
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\FSYLTV'
New-Item -Path $uninstallKey -Force | Out-Null
Set-ItemProperty -Path $uninstallKey -Name DisplayName -Value 'FSYL TV'
Set-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value '1.0.0'
Set-ItemProperty -Path $uninstallKey -Name Publisher -Value 'FSYL TV contributors'
Set-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $appDir
Set-ItemProperty -Path $uninstallKey -Name UninstallString -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$appDir\uninstall.ps1`""

Write-Host ''
Write-Host 'Installed. Launch from Start Menu or Desktop (FSYL TV).'
Write-Host 'Run uninstall.ps1 to remove; you will be asked whether to keep records.'

# Refresh the shell icon cache so the new exe/shortcut icon is visible without
# requiring the user to sign out.
try { & ie4uinit.exe -show } catch {}
