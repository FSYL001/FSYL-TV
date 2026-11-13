# Enable Windows Developer Mode (symlink support required by Flutter plugins).
# Run elevated; used only for the development machine, not part of the app.
$ErrorActionPreference = 'Stop'
$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
New-ItemProperty -Path $path -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Output ('AllowDevelopmentWithoutDevLicense=' + (Get-ItemProperty -Path $path).AllowDevelopmentWithoutDevLicense)
