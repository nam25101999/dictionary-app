<#
.SYNOPSIS
    Rollback Dictionary App to a previous image tag using PowerShell on Windows.
.DESCRIPTION
    Verifies that the target images exist in GHCR or locally,
    re-deploys via docker-compose.prod.yml with specified IMAGE_TAG,
    and runs a health check to guarantee zero-downtime successful deployment.
.PARAMETER ImageTag
    The target image tag / Git commit SHA to rollback to.
.EXAMPLE
    .\scripts\rollback.ps1 -ImageTag "v1.0.0"
    .\scripts\rollback.ps1 -ImageTag "abc1234"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host "[ROLLBACK] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[ROLLBACK] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[ROLLBACK] $msg" -ForegroundColor Red }
function Write-Step($msg)  { Write-Host "[ROLLBACK] $msg" -ForegroundColor Cyan }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Load .env if present
$EnvFile = Join-Path $ProjectRoot ".env"
if (Test-Path $EnvFile) {
    Write-Info "Loading .env configuration..."
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v)
            }
        }
    }
}

$Registry = if ($env:IMAGE_REGISTRY) { $env:IMAGE_REGISTRY } else { "ghcr.io" }
$Owner = $env:IMAGE_OWNER

if (-not $Owner) {
    Write-Err "IMAGE_OWNER is not set in environment or .env file."
    Write-Err "Please set IMAGE_OWNER in .env (e.g., IMAGE_OWNER=your-github-username)."
    exit 1
}

$BackendImage = "${Registry}/${Owner}/dictionary-backend:${ImageTag}"
$FrontendImage = "${Registry}/${Owner}/dictionary-frontend:${ImageTag}"

Write-Host ""
Write-Info "=========================================================="
Write-Info "  STARTING ROLLBACK TO TAG: $ImageTag"
Write-Info "=========================================================="
Write-Info "Backend Image:  $BackendImage"
Write-Info "Frontend Image: $FrontendImage"
Write-Host ""

# Step 1: Record current images
Write-Step "Step 1: Inspecting current running containers..."
$currBackend = docker inspect --format='{{.Config.Image}}' dictionary-backend 2>$null
$currFrontend = docker inspect --format='{{.Config.Image}}' dictionary-frontend 2>$null
Write-Info "Current backend:  $currBackend"
Write-Info "Current frontend: $currFrontend"

# Step 2: Pull target rollback images
Write-Step "Step 2: Pulling target rollback images..."
try {
    Write-Info "Pulling backend: $BackendImage"
    docker pull $BackendImage
    if ($LASTEXITCODE -ne 0) { throw "Failed to pull backend image." }

    Write-Info "Pulling frontend: $FrontendImage"
    docker pull $FrontendImage
    if ($LASTEXITCODE -ne 0) { throw "Failed to pull frontend image." }
} catch {
    Write-Err "Rollback image pull failed: $_"
    Write-Err "Make sure the tag '$ImageTag' exists in registry ${Registry}/${Owner}."
    exit 1
}

# Step 3: Redeploy with docker-compose.prod.yml
Write-Step "Step 3: Deploying rollback images with docker-compose..."
$env:IMAGE_TAG = $ImageTag
Push-Location $ProjectRoot
try {
    docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    if ($LASTEXITCODE -ne 0) { throw "Docker compose up returned error code $LASTEXITCODE" }
} finally {
    Pop-Location
}

# Step 4: Health check verification
Write-Step "Step 4: Verifying health check on deployed containers..."
$backendPort = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { "8180" }
$healthUrl = "http://127.0.0.1:${backendPort}/api/health"
$healthPassed = $false

Write-Info "Waiting for $healthUrl (max 60 seconds)..."
for ($i = 1; $i -le 60; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3 -ErrorAction Stop
        if ($resp.success -eq $true) {
            $healthPassed = $true
            Write-Info "Health check PASSED at attempt $i (Status: $($resp.data.status), Database: $($resp.data.database))"
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $healthPassed) {
    Write-Err "Health check failed after rollback deployment!"
    Write-Warn "Consider troubleshooting container logs with: docker logs dictionary-backend"
    exit 1
}

Write-Host ""
Write-Info "=========================================================="
Write-Info "  ROLLBACK TO $ImageTag COMPLETED SUCCESSFULLY!"
Write-Info "=========================================================="
Write-Host ""
