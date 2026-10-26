#!/usr/bin/env bash
# =============================================================================
# verify-deployment.sh - Post-deployment verification for Dictionary App
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[VERIFY]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[VERIFY]${NC} $*"; }
log_error() { echo -e "${RED}[VERIFY]${NC} $*"; }

BACKEND_PORT="${BACKEND_PORT:-8180}"
FRONTEND_PORT="${FRONTEND_PORT:-3100}"
MAX_WAIT=60

log_info "=== Post-Deployment Verification ==="
log_info "Backend port: $BACKEND_PORT"
log_info "Frontend port: $FRONTEND_PORT"

# --- 1. Check Docker containers ---
log_info "Checking Docker containers status..."
docker compose ps

# --- 2. Health check backend ---
log_info "Waiting for backend health endpoint (max ${MAX_WAIT}s)..."
HEALTH_OK=false
for i in $(seq 1 "$MAX_WAIT"); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${BACKEND_PORT}/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        HEALTH_OK=true
        log_info "Backend health check PASSED (attempt $i)"
        break
    fi
    sleep 1
done

if [ "$HEALTH_OK" != "true" ]; then
    log_error "Backend health check FAILED after ${MAX_WAIT}s"
    docker compose logs --tail 30 backend
    exit 1
fi

# --- 3. Verify API response ---
log_info "Verifying /api/health response body..."
HEALTH_BODY=$(curl -s "http://127.0.0.1:${BACKEND_PORT}/api/health")
if echo "$HEALTH_BODY" | grep -q '"success":true'; then
    log_info "  PASS: API returns success=true"
else
    log_error "  FAIL: Unexpected response: $HEALTH_BODY"
    exit 1
fi

# --- 4. Check frontend ---
log_info "Checking frontend availability..."
FE_OK=false
for i in $(seq 1 20); do
    HTTP_FE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${FRONTEND_PORT}" 2>/dev/null || echo "000")
    if [ "$HTTP_FE" = "200" ]; then
        FE_OK=true
        log_info "Frontend check PASSED (attempt $i)"
        break
    fi
    sleep 1
done

if [ "$FE_OK" != "true" ]; then
    log_error "Frontend check FAILED"
    docker compose logs --tail 20 frontend
    exit 1
fi

echo ""
log_info "============================================"
log_info "  DEPLOYMENT VERIFICATION PASSED"
log_info "============================================"
echo ""
exit 0
