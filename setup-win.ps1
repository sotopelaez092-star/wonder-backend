# Wonder MVP - Win host bootstrap
# Run this on the Win box (PowerShell admin):
#   irm http://8.155.166.119/setup-win.ps1 | iex

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '==> Installing OpenSSH Server...' -ForegroundColor Cyan
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null

Write-Host '==> Starting sshd service...' -ForegroundColor Cyan
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

Write-Host '==> Adding firewall rule for port 22...' -ForegroundColor Cyan
if (-not (Get-NetFirewallRule -Name 'sshd-in' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'sshd-in' -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Write-Host '==> Installing pubkey for remote (Claude side)...' -ForegroundColor Cyan
$pubkey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKojgl6Sfa38e4WukHgqLOZhC254zTD+ODShnHky6aHn claude-wonder'

# Admin accounts use a shared authorized_keys file
$adminKeys = 'C:\ProgramData\ssh\administrators_authorized_keys'
$adminKeysDir = Split-Path $adminKeys
if (-not (Test-Path $adminKeysDir)) { New-Item -Type Directory -Path $adminKeysDir -Force | Out-Null }
$existing = if (Test-Path $adminKeys) { Get-Content $adminKeys -Raw } else { '' }
if ($existing -notmatch [regex]::Escape($pubkey.Split(' ')[1])) {
  Add-Content -Path $adminKeys -Value $pubkey -Encoding ASCII
}
# Required ACLs: only Administrators + SYSTEM can read
icacls $adminKeys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

# Also user-level key (in case account isn't admin)
$userKeysDir = Join-Path $env:USERPROFILE '.ssh'
$userKeys = Join-Path $userKeysDir 'authorized_keys'
if (-not (Test-Path $userKeysDir)) { New-Item -Type Directory -Path $userKeysDir -Force | Out-Null }
$ue = if (Test-Path $userKeys) { Get-Content $userKeys -Raw } else { '' }
if ($ue -notmatch [regex]::Escape($pubkey.Split(' ')[1])) {
  Add-Content -Path $userKeys -Value $pubkey -Encoding ASCII
}

Write-Host '==> Setting PowerShell as default SSH shell...' -ForegroundColor Cyan
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
  -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null

Write-Host '==> Restarting sshd...' -ForegroundColor Cyan
Restart-Service sshd

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host '  DONE!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host ''
Write-Host 'SSH ready. Your username for remote login:' -ForegroundColor Yellow
Write-Host "  $env:USERNAME" -ForegroundColor White
Write-Host ''
Write-Host 'LAN IP(s):' -ForegroundColor Yellow
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' } |
  ForEach-Object { Write-Host "  $($_.IPAddress)" -ForegroundColor White }
Write-Host ''
Write-Host 'You can close this window. Claude can now SSH in.' -ForegroundColor Green
