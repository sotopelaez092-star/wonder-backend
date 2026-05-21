# Wonder MVP - Win host installer
# Run from PowerShell as Administrator:
#   irm http://8.155.166.119/install-win.ps1 | iex

$ErrorActionPreference = 'Continue'
$REPO_URL = 'https://github.com/sotopelaez092-star/wonder-backend.git'
$INSTALL_DIR = 'C:\wonder'

function Step($msg) { Write-Host ''; Write-Host "==> $msg" -ForegroundColor Cyan }
function Refresh-Path { $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User') }
function Has($cmd) { return [bool] (Get-Command $cmd -ErrorAction SilentlyContinue) }
function Winget($id) {
  Write-Host "    installing $id ..." -ForegroundColor Gray
  winget install -e --id $id --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
}

Step 'Installing dependencies via winget'
if (-not (Has node))         { Winget 'OpenJS.NodeJS.LTS' }
if (-not (Has caddy))        { Winget 'CaddyServer.Caddy' }
if (-not (Has cloudflared))  { Winget 'Cloudflare.cloudflared' }
if (-not (Has git))          { Winget 'Git.Git' }
Refresh-Path

foreach ($t in 'node','npm','git','caddy','cloudflared') {
  if (Has $t) { Write-Host "    ✓ $t" -ForegroundColor Green } else { Write-Host "    ✗ $t MISSING — please reopen PowerShell as admin and rerun" -ForegroundColor Red; exit 1 }
}

Step "Cloning $REPO_URL → $INSTALL_DIR"
if (Test-Path $INSTALL_DIR) {
  Write-Host "    pulling latest..." -ForegroundColor Gray
  Push-Location $INSTALL_DIR; git pull --ff-only 2>&1 | Out-Null; Pop-Location
} else {
  git clone $REPO_URL $INSTALL_DIR 2>&1 | Out-Null
}

Step 'Installing Node deps'
Push-Location (Join-Path $INSTALL_DIR 'app')
npm install --no-audit --no-fund 2>&1 | Select-Object -Last 6

Step 'Installing PM2 globally'
if (-not (Has pm2)) { npm install -g pm2 2>&1 | Select-Object -Last 3 }
Refresh-Path

Step 'Creating .env'
$envFile = Join-Path $INSTALL_DIR 'app\.env'
if (-not (Test-Path $envFile)) {
  $pw = Read-Host "    Set admin login password (will be saved to $envFile)"
  if (-not $pw) { $pw = 'changeme-' + [System.Web.Security.Membership]::GeneratePassword(8,0) }
  @"
PORT=3001
HOST=127.0.0.1
ADMIN_PASSWORD=$pw
"@ | Out-File -FilePath $envFile -Encoding ASCII
  Write-Host "    ✓ written" -ForegroundColor Green
} else {
  Write-Host "    .env already exists, leaving alone" -ForegroundColor Yellow
}

Step 'Initializing SQLite'
node src/scripts/init-db.js

Step 'Starting backend via PM2'
pm2 delete wonder-backend 2>&1 | Out-Null
pm2 start pm2.config.cjs
pm2 save 2>&1 | Out-Null
# Install pm2 as Win service so it autostarts
if (-not (Has pm2-startup)) {
  npm install -g pm2-windows-startup 2>&1 | Out-Null
  pm2-startup install 2>&1 | Out-Null
}
Pop-Location

Step 'Starting Caddy as background process'
Push-Location $INSTALL_DIR
# Stop existing
Get-Process caddy -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath caddy -ArgumentList 'run','--config','Caddyfile' -WindowStyle Hidden
Pop-Location
Start-Sleep -Seconds 2

Step 'Opening firewall for :80 (so local LAN can reach)'
if (-not (Get-NetFirewallRule -Name 'wonder-http' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'wonder-http' -DisplayName 'Wonder HTTP (Caddy)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 80 | Out-Null
}

Step 'Smoke test on localhost'
Start-Sleep -Seconds 2
try {
  $h = Invoke-RestMethod -Uri 'http://localhost/api/health' -TimeoutSec 5
  Write-Host "    ✓ /api/health → $($h | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
  Write-Host "    ✗ health check failed: $_" -ForegroundColor Red
}

Write-Host ''
Write-Host '======================================================' -ForegroundColor Green
Write-Host '  Backend running locally — open http://localhost/ '   -ForegroundColor Green
Write-Host '  Admin panel:                http://localhost/admin'  -ForegroundColor Green
Write-Host '======================================================' -ForegroundColor Green
Write-Host ''
Write-Host '----- NEXT: expose to the internet via Cloudflare Tunnel -----' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Run these 3 commands in this same PowerShell window:' -ForegroundColor Yellow
Write-Host ''
Write-Host '  1) cloudflared tunnel login' -ForegroundColor White
Write-Host '     → opens browser, log in to Cloudflare (free account, no CC)' -ForegroundColor Gray
Write-Host ''
Write-Host '  2) cloudflared tunnel --url http://localhost:80' -ForegroundColor White
Write-Host '     → prints a random https://*.trycloudflare.com URL — share that.' -ForegroundColor Gray
Write-Host '     → keep window open; Ctrl-C to stop.' -ForegroundColor Gray
Write-Host ''
Write-Host '  3) For a persistent named tunnel (later, optional):' -ForegroundColor White
Write-Host '     cloudflared tunnel create wonder' -ForegroundColor Gray
Write-Host '     # follow on-screen instructions' -ForegroundColor Gray
Write-Host ''
