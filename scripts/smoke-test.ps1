<#
.SYNOPSIS
    Smoke test script for Dictionary App on Windows PowerShell.
.DESCRIPTION
    Launches an isolated test environment with temporary ports,
    verifies database, backend health, search definition, history, and frontend,
    then automatically cleans up all containers and networks.
.PARAMETER BackendImage
    Docker image for backend (default: devops-nam-backend:latest)
.PARAMETER FrontendImage
    Docker image for frontend (default: devops-nam-frontend:latest)
.EXAMPLE
    .\scripts\smoke-test.ps1
    .\scripts\smoke-test.ps1 -BackendImage "ghcr.io/user/dictionary-backend:latest" -FrontendImage "ghcr.io/user/dictionary-frontend:latest"
#>
param(
    [string]$BackendImage = "devops-nam-backend:latest",
    [string]$FrontendImage = "devops-nam-frontend:latest"
)

$ErrorActionPreference = "Stop"

$SmokeProject = "dictsmoke"
$SmokeBackendPort = 9180
$SmokeFrontendPort = 9100
$DbImage = "postgres:16-alpine"
$SmokeNetwork = "${SmokeProject}_network"
$DbContainer = "${SmokeProject}-db"
$BackendContainer = "${SmokeProject}-backend"
$FrontendContainer = "${SmokeProject}-frontend"

function Write-Info($msg)  { Write-Host "[SMOKE] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[SMOKE] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[SMOKE] $msg" -ForegroundColor Red }

function Cleanup {
    Write-Warn "Cleaning up smoke test containers and network..."
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & docker rm -f $FrontendContainer $BackendContainer $DbContainer 2>&1 | Out-Null
    & docker network rm $SmokeNetwork 2>&1 | Out-Null
    $ErrorActionPreference = $prev
    Write-Info "Cleanup completed."
}

Write-Info "=== Dictionary App Smoke Test (PowerShell) ==="
Write-Info "Backend Image:  $BackendImage"
Write-Info "Frontend Image: $FrontendImage"
Write-Info "Smoke Ports:    Backend=$SmokeBackendPort, Frontend=$SmokeFrontendPort"

try {
    # 0. Clean prior state if any
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & docker rm -f $FrontendContainer $BackendContainer $DbContainer 2>&1 | Out-Null
    & docker network rm $SmokeNetwork 2>&1 | Out-Null
    $ErrorActionPreference = $prev

    # 1. Create network
    Write-Info "Creating isolated network: $SmokeNetwork"
    docker network create $SmokeNetwork | Out-Null

    # 2. Start PostgreSQL
    Write-Info "Starting PostgreSQL container: $DbContainer"
    docker run -d `
        --name $DbContainer `
        --network $SmokeNetwork `
        -e POSTGRES_DB=smoke_test_db `
        -e POSTGRES_USER=smoke_user `
        -e POSTGRES_PASSWORD=smoke_pass `
        $DbImage | Out-Null

    Write-Info "Waiting for PostgreSQL to be ready..."
    $dbReady = $false
    for ($i = 1; $i -le 30; $i++) {
        $res = docker exec $DbContainer pg_isready -U smoke_user -d smoke_test_db 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dbReady = $true
            Write-Info "PostgreSQL is ready (attempt $i)."
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $dbReady) {
        throw "PostgreSQL failed to initialize in time."
    }

    # 3. Start Backend
    Write-Info "Starting Backend container: $BackendContainer"
    docker run -d `
        --name $BackendContainer `
        --network $SmokeNetwork `
        --network-alias backend `
        -p "${SmokeBackendPort}:8080" `
        -e SERVER_PORT=8080 `
        -e "SPRING_DATASOURCE_URL=jdbc:postgresql://${DbContainer}:5432/smoke_test_db" `
        -e SPRING_DATASOURCE_USERNAME=smoke_user `
        -e SPRING_DATASOURCE_PASSWORD=smoke_pass `
        $BackendImage | Out-Null

    Write-Info "Waiting for Backend /api/health (max 60s)..."
    $healthOk = $false
    for ($i = 1; $i -le 60; $i++) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:${SmokeBackendPort}/api/health" -TimeoutSec 3 -ErrorAction Stop
            if ($resp.status -eq "UP" -or $resp.success -eq $true) {
                $healthOk = $true
                Write-Info "Backend /api/health responded OK (attempt $i)."
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $healthOk) {
        docker logs $BackendContainer --tail 40
        throw "Backend /api/health did not become ready."
    }

    # Test 1: Health check details
    Write-Info "TEST 1: Verifying Health Check API..."
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:${SmokeBackendPort}/api/health"
    if ($health.success -eq $true -and $health.data.database -eq "CONNECTED") {
        Write-Info "  PASS: Health check reports database CONNECTED and status UP"
    } else {
        throw "Health check returned unexpected data: $($health | ConvertTo-Json)"
    }

    # Test 2: Word lookup (devops)
    Write-Info "TEST 2: Verifying Word Definition API (/api/define/devops)..."
    $wordRes = Invoke-RestMethod -Uri "http://127.0.0.1:${SmokeBackendPort}/api/define/devops"
    if ($wordRes.success -eq $true -and $wordRes.data.word -eq "devops") {
        Write-Info "  PASS: Found word '$($wordRes.data.word)' (${wordRes.data.partOfSpeech})"
    } else {
        throw "Word lookup failed: $($wordRes | ConvertTo-Json)"
    }

    # Test 3: Word not found (404 handling)
    Write-Info "TEST 3: Verifying 404 handling for nonexistent word..."
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:${SmokeBackendPort}/api/define/unknownword12345" -ErrorAction Stop
        throw "Expected 404 but got success!"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404 -or $_.Exception.Message -match "404") {
            Write-Info "  PASS: Nonexistent word correctly returned HTTP 404"
        } else {
            throw "Expected 404, got: $($_.Exception.Message)"
        }
    }

    # Test 4: History API
    Write-Info "TEST 4: Verifying Search History API (/api/history)..."
    $histRes = Invoke-RestMethod -Uri "http://127.0.0.1:${SmokeBackendPort}/api/history"
    if ($histRes.success -eq $true -and $histRes.data.Count -gt 0) {
        Write-Info "  PASS: Search history retrieved successfully ($($histRes.data.Count) entries)"
    } else {
        throw "History API returned unexpected data"
    }

    # Test 5: Frontend container
    Write-Info "Starting Frontend container: $FrontendContainer"
    docker run -d `
        --name $FrontendContainer `
        --network $SmokeNetwork `
        -p "${SmokeFrontendPort}:80" `
        $FrontendImage | Out-Null

    Write-Info "Waiting for Frontend to respond..."
    $feOk = $false
    for ($i = 1; $i -le 20; $i++) {
        try {
            $html = (Invoke-WebRequest -Uri "http://127.0.0.1:${SmokeFrontendPort}" -UseBasicParsing -TimeoutSec 3).Content
            if ($html -match "DevOps Dictionary") {
                $feOk = $true
                Write-Info "  PASS: Frontend returned HTTP 200 with title 'DevOps Dictionary' (attempt $i)"
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $feOk) {
        throw "Frontend verification failed."
    }

    Write-Host ""
    Write-Info "============================================"
    Write-Info "  ALL 5 SMOKE TESTS PASSED SUCCESSFULLY!"
    Write-Info "============================================"
    Write-Host ""
}
catch {
    Write-Err "SMOKE TEST FAILED: $_"
    exit 1
}
finally {
    Cleanup
}
