<#
.SYNOPSIS
    Post-deployment verification script for Dictionary App (Windows PowerShell).
.DESCRIPTION
    Verifies Docker containers are running, backend health check passes,
    and frontend is accessible.
.EXAMPLE
    .\scripts\verify-deployment.ps1
#>

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host "[VERIFY] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[VERIFY] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[VERIFY] $msg" -ForegroundColor Red }

$BackendPort = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { "8180" }
$FrontendPort = if ($env:FRONTEND_PORT) { $env:FRONTEND_PORT } else { "3100" }
$MaxWait = 60

Write-Info "=== Post-Deployment Verification ==="
Write-Info "Backend port:  $BackendPort"
Write-Info "Frontend port: $FrontendPort"

# 1. Check containers
Write-Info "Checking Docker containers..."
docker compose ps

# 2. Backend health check
Write-Info "Waiting for backend health endpoint (max ${MaxWait}s)..."
$healthPassed = $false
for ($i = 1; $i -le $MaxWait; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:${BackendPort}/api/health" -TimeoutSec 3 -ErrorAction Stop
        if ($resp.success -eq $true) {
            $healthPassed = $true
            Write-Info "Backend health PASSED (attempt $i) - Status: $($resp.data.status), DB: $($resp.data.database)"
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $healthPassed) {
    Write-Err "Backend health check FAILED after ${MaxWait}s"
    docker compose logs --tail 30 backend
    exit 1
}

# 3. Frontend check
Write-Info "Checking frontend availability..."
$feOk = $false
for ($i = 1; $i -le 20; $i++) {
    try {
        $html = (Invoke-WebRequest -Uri "http://127.0.0.1:${FrontendPort}" -UseBasicParsing -TimeoutSec 3).Content
        if ($html -match "DevOps Dictionary") {
            $feOk = $true
            Write-Info "Frontend check PASSED (attempt $i)"
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $feOk) {
    Write-Err "Frontend verification FAILED"
    docker compose logs --tail 20 frontend
    exit 1
}

Write-Host ""
Write-Info "============================================"
Write-Info "  DEPLOYMENT VERIFICATION PASSED"
Write-Info "============================================"
Write-Host ""
