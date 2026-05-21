# Wonder MVP - Win host installer (CN-friendly)
# Run from PowerShell as Administrator:
#   irm http://8.155.166.119/install-win.ps1 | iex

$ErrorActionPreference = 'Continue'
$INSTALL_DIR    = 'C:\wonder'
$ZIP_URL        = 'http://8.155.166.119/wonder-backend.zip'
$NPM_REGISTRY   = 'https://registry.npmmirror.com'  # taobao mirror, CN-fast

function Step($msg) { Write-Host ''; Write-Host "==> $msg" -ForegroundColor Cyan }
function Refresh-Path { $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User') }
function Has($cmd) { return [bool] (Get-Command $cmd -ErrorAction SilentlyContinue) }
function Winget($id) {
  Write-Host "    installing $id ..." -ForegroundColor Gray
  winget install -e --id $id --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
}

# ====== 1. Tools ======
Step 'Installing dependencies via winget'
if (-not (Has node))         { Winget 'OpenJS.NodeJS.LTS' }
if (-not (Has caddy))        { Winget 'CaddyServer.Caddy' }
if (-not (Has cloudflared))  { Winget 'Cloudflare.cloudflared' }
Refresh-Path

foreach ($t in 'node','npm','caddy','cloudflared') {
  if (Has $t) { Write-Host "    ✓ $t" -ForegroundColor Green }
  else { Write-Host "    ✗ $t MISSING — reopen PowerShell as admin and rerun" -ForegroundColor Red; exit 1 }
}

# ====== 2. Code (zip from CN ECS, no git needed) ======
Step "Downloading wonder-backend.zip from $ZIP_URL"
$tmpZip = "$env:TEMP\wonder-backend-$(Get-Random).zip"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $ZIP_URL -OutFile $tmpZip -UseBasicParsing
$sz = (Get-Item $tmpZip).Length / 1MB
Write-Host ("    ✓ {0:N2} MB" -f $sz) -ForegroundColor Green

Step "Extracting to $INSTALL_DIR"
if (Test-Path $INSTALL_DIR) {
  # Preserve data/ and .env
  $preserveData = Join-Path $INSTALL_DIR 'data'
  $preserveEnv  = Join-Path $INSTALL_DIR 'app\.env'
  $tmpData = "$env:TEMP\wonder-data-$(Get-Random)"
  $tmpEnv  = "$env:TEMP\wonder-env-$(Get-Random)"
  if (Test-Path $preserveData) { Move-Item $preserveData $tmpData }
  if (Test-Path $preserveEnv)  { Copy-Item $preserveEnv $tmpEnv }
  Remove-Item $INSTALL_DIR -Recurse -Force
  Expand-Archive -Path $tmpZip -DestinationPath $INSTALL_DIR -Force
  if (Test-Path $tmpData) { Move-Item $tmpData (Join-Path $INSTALL_DIR 'data') }
  if (Test-Path $tmpEnv)  { Copy-Item $tmpEnv (Join-Path $INSTALL_DIR 'app\.env') }
} else {
  Expand-Archive -Path $tmpZip -DestinationPath $INSTALL_DIR -Force
}
Remove-Item $tmpZip -Force

# ====== 3. npm deps via taobao mirror ======
Step 'Installing Node deps (taobao mirror, CN-fast)'
Push-Location (Join-Path $INSTALL_DIR 'app')
npm config set registry $NPM_REGISTRY 2>&1 | Out-Null
npm install --no-audit --no-fund 2>&1 | Select-Object -Last 6

Step 'Installing PM2 globally'
if (-not (Has pm2)) { npm install -g pm2 2>&1 | Select-Object -Last 3 }
Refresh-Path

# ====== 4. .env ======
Step 'Setting up .env'
$envFile = Join-Path $INSTALL_DIR 'app\.env'
if (-not (Test-Path $envFile)) {
  $pw = Read-Host "    Enter an admin login password"
  if (-not $pw) { $pw = 'wonder' + (Get-Random -Maximum 99999) }
  @"
PORT=3001
HOST=127.0.0.1
ADMIN_PASSWORD=$pw
"@ | Out-File -FilePath $envFile -Encoding ASCII
  Write-Host "    ✓ written ($envFile)" -ForegroundColor Green
} else {
  Write-Host "    .env already exists, leaving alone" -ForegroundColor Yellow
}

# ====== 5. SQLite init ======
Step 'Initializing SQLite db'
node src/scripts/init-db.js

# ====== 6. PM2 backend ======
Step 'Starting backend via PM2'
pm2 delete wonder-backend 2>&1 | Out-Null
pm2 start pm2.config.cjs
pm2 save 2>&1 | Out-Null
if (-not (Has pm2-startup)) {
  npm install -g pm2-windows-startup 2>&1 | Out-Null
  pm2-startup install 2>&1 | Out-Null
}
Pop-Location

# ====== 7. Caddy ======
Step 'Starting Caddy reverse proxy (:80)'
Push-Location $INSTALL_DIR
Get-Process caddy -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath caddy -ArgumentList 'run','--config','Caddyfile' -WindowStyle Hidden
Pop-Location
Start-Sleep -Seconds 2

# ====== 8. Firewall ======
Step 'Opening firewall TCP/80 (LAN reachable)'
if (-not (Get-NetFirewallRule -Name 'wonder-http' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'wonder-http' -DisplayName 'Wonder HTTP (Caddy)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 80 | Out-Null
}

# ====== 9. Smoke ======
Step 'Smoke test'
Start-Sleep -Seconds 2
try {
  $h = Invoke-RestMethod -Uri 'http://localhost/api/health' -TimeoutSec 5
  Write-Host "    ✓ /api/health → $($h | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
  Write-Host "    ✗ health check failed: $_" -ForegroundColor Red
}

Write-Host ''
Write-Host '====================================================' -ForegroundColor Green
Write-Host '  Backend running locally — open:' -ForegroundColor Green
Write-Host '    http://localhost/         (nav page)' -ForegroundColor White
Write-Host '    http://localhost/admin    (admin panel)' -ForegroundColor White
Write-Host '====================================================' -ForegroundColor Green
Write-Host ''
Write-Host '----- NEXT: expose to internet (Cloudflare Tunnel) -----' -ForegroundColor Yellow
Write-Host ''
Write-Host 'In this same PowerShell, run:' -ForegroundColor Yellow
Write-Host ''
Write-Host '  cloudflared tunnel --url http://localhost:80' -ForegroundColor White
Write-Host ''
Write-Host '  → prints a https://*.trycloudflare.com URL — share that.' -ForegroundColor Gray
Write-Host '  → keep window open; Ctrl-C to stop.' -ForegroundColor Gray
Write-Host '  → no Cloudflare login needed for trycloudflare.' -ForegroundColor Gray
Write-Host ''
