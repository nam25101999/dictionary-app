#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh - Smoke Test cho Dictionary App
# =============================================================================
# Script khởi chạy môi trường test riêng biệt (cổng khác môi trường chính),
# kiểm tra các endpoint quan trọng, sau đó dọn dẹp toàn bộ container test.
#
# Sử dụng:
#   ./scripts/smoke-test.sh [BACKEND_IMAGE] [FRONTEND_IMAGE]
#
# Ví dụ:
#   ./scripts/smoke-test.sh devops-nam-backend:latest devops-nam-frontend:latest
# =============================================================================

set -euo pipefail

# --- Configuration ---
SMOKE_PROJECT="dictsmoke"
SMOKE_BACKEND_PORT=9180
SMOKE_FRONTEND_PORT=9100
SMOKE_DB_PORT=9432
HEALTH_TIMEOUT=60
DEFINE_TIMEOUT=10

BACKEND_IMAGE="${1:-devops-nam-backend:latest}"
FRONTEND_IMAGE="${2:-devops-nam-frontend:latest}"
DB_IMAGE="postgres:16-alpine"

SMOKE_NETWORK="${SMOKE_PROJECT}_network"
DB_CONTAINER="${SMOKE_PROJECT}-db"
BACKEND_CONTAINER="${SMOKE_PROJECT}-backend"
FRONTEND_CONTAINER="${SMOKE_PROJECT}-frontend"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[SMOKE]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[SMOKE]${NC} $*"; }
log_error() { echo -e "${RED}[SMOKE]${NC} $*"; }

# --- Cleanup function (called by trap) ---
cleanup() {
    log_warn "Cleaning up smoke test containers and network..."
    docker rm -f "$FRONTEND_CONTAINER" "$BACKEND_CONTAINER" "$DB_CONTAINER" 2>/dev/null || true
    docker network rm "$SMOKE_NETWORK" 2>/dev/null || true
    log_info "Cleanup complete."
}

# Trap EXIT, INT, TERM signals to always cleanup
trap cleanup EXIT INT TERM

# --- Preflight checks ---
log_info "=== Dictionary App Smoke Test ==="
log_info "Backend image:  $BACKEND_IMAGE"
log_info "Frontend image: $FRONTEND_IMAGE"
log_info "Test ports:     Backend=$SMOKE_BACKEND_PORT, Frontend=$SMOKE_FRONTEND_PORT, DB=$SMOKE_DB_PORT"
echo ""

# Check Docker CLI availability
if ! command -v docker &>/dev/null; then
    log_error "Docker CLI not found. Please install Docker."
    exit 1
fi

if ! docker info &>/dev/null; then
    log_error "Docker Engine is not running."
    exit 1
fi

# --- Cleanup any leftover containers from previous runs ---
docker rm -f "$FRONTEND_CONTAINER" "$BACKEND_CONTAINER" "$DB_CONTAINER" 2>/dev/null || true
docker network rm "$SMOKE_NETWORK" 2>/dev/null || true

# --- Create isolated network ---
log_info "Creating isolated smoke test network: $SMOKE_NETWORK"
docker network create "$SMOKE_NETWORK"

# --- Start PostgreSQL ---
log_info "Starting PostgreSQL container: $DB_CONTAINER"
docker run -d \
    --name "$DB_CONTAINER" \
    --network "$SMOKE_NETWORK" \
    -e POSTGRES_DB=smoke_test_db \
    -e POSTGRES_USER=smoke_user \
    -e POSTGRES_PASSWORD=smoke_pass \
    "$DB_IMAGE"

# Wait for PostgreSQL to be ready
log_info "Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
    if docker exec "$DB_CONTAINER" pg_isready -U smoke_user -d smoke_test_db &>/dev/null; then
        log_info "PostgreSQL is ready (attempt $i)."
        break
    fi
    if [ "$i" -eq 30 ]; then
        log_error "PostgreSQL did not become ready in time."
        exit 1
    fi
    sleep 1
done

# --- Start Backend ---
log_info "Starting Backend container: $BACKEND_CONTAINER"
docker run -d \
    --name "$BACKEND_CONTAINER" \
    --network "$SMOKE_NETWORK" \
    --network-alias backend \
    -p "${SMOKE_BACKEND_PORT}:8080" \
    -e SERVER_PORT=8080 \
    -e SPRING_DATASOURCE_URL="jdbc:postgresql://${DB_CONTAINER}:5432/smoke_test_db" \
    -e SPRING_DATASOURCE_USERNAME=smoke_user \
    -e SPRING_DATASOURCE_PASSWORD=smoke_pass \
    "$BACKEND_IMAGE"

# --- Wait for Backend Health ---
log_info "Waiting for backend health endpoint (max ${HEALTH_TIMEOUT}s)..."
BACKEND_URL="http://127.0.0.1:${SMOKE_BACKEND_PORT}"
HEALTH_OK=false
for i in $(seq 1 "$HEALTH_TIMEOUT"); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BACKEND_URL}/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        HEALTH_OK=true
        log_info "Backend /api/health returned HTTP 200 (attempt $i)."
        break
    fi
    sleep 1
done

if [ "$HEALTH_OK" != "true" ]; then
    log_error "Backend /api/health did NOT return 200 within ${HEALTH_TIMEOUT}s."
    log_error "Last HTTP code: $HTTP_CODE"
    log_warn "Backend logs:"
    docker logs "$BACKEND_CONTAINER" --tail 40
    exit 1
fi

# --- Test: GET /api/health response body ---
log_info "TEST 1: Verifying /api/health response body..."
HEALTH_BODY=$(curl -s "${BACKEND_URL}/api/health")
if echo "$HEALTH_BODY" | grep -q '"success":true'; then
    log_info "  PASS: /api/health returns success=true"
else
    log_error "  FAIL: /api/health unexpected body: $HEALTH_BODY"
    exit 1
fi

# --- Test: GET /api/define/computer ---
log_info "TEST 2: Verifying /api/define/computer..."
DEFINE_BODY=$(curl -s --max-time "$DEFINE_TIMEOUT" "${BACKEND_URL}/api/define/computer")
if echo "$DEFINE_BODY" | grep -q '"success":true'; then
    log_info "  PASS: /api/define/computer returns success=true"
else
    log_error "  FAIL: /api/define/computer unexpected body: $DEFINE_BODY"
    exit 1
fi

if echo "$DEFINE_BODY" | grep -q '"word":"computer"'; then
    log_info "  PASS: Response contains word=computer"
else
    log_error "  FAIL: Response missing word=computer: $DEFINE_BODY"
    exit 1
fi

# --- Test: GET /api/define/nonexistent (should return 404) ---
log_info "TEST 3: Verifying /api/define/nonexistentxyz returns 404..."
HTTP_404=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$DEFINE_TIMEOUT" "${BACKEND_URL}/api/define/nonexistentxyz")
if [ "$HTTP_404" = "404" ]; then
    log_info "  PASS: /api/define/nonexistentxyz returns HTTP 404"
else
    log_error "  FAIL: Expected HTTP 404, got $HTTP_404"
    exit 1
fi

# --- Test: GET /api/history (should include recent searches) ---
log_info "TEST 4: Verifying /api/history returns valid data..."
HISTORY_BODY=$(curl -s --max-time "$DEFINE_TIMEOUT" "${BACKEND_URL}/api/history")
if echo "$HISTORY_BODY" | grep -q '"success":true'; then
    log_info "  PASS: /api/history returns success=true"
else
    log_error "  FAIL: /api/history unexpected body: $HISTORY_BODY"
    exit 1
fi

# --- Start Frontend (optional deeper check) ---
log_info "Starting Frontend container: $FRONTEND_CONTAINER"
docker run -d \
    --name "$FRONTEND_CONTAINER" \
    --network "$SMOKE_NETWORK" \
    -p "${SMOKE_FRONTEND_PORT}:80" \
    "$FRONTEND_IMAGE"

log_info "Waiting for frontend to respond..."
FRONTEND_URL="http://127.0.0.1:${SMOKE_FRONTEND_PORT}"
FRONTEND_OK=false
for i in $(seq 1 15); do
    HTTP_FE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_FE" = "200" ]; then
        FRONTEND_OK=true
        log_info "  Frontend returned HTTP 200 (attempt $i)."
        break
    fi
    sleep 1
done

if [ "$FRONTEND_OK" != "true" ]; then
    log_error "  FAIL: Frontend did not return HTTP 200."
    exit 1
fi

log_info "TEST 5: Verifying frontend HTML contains expected title..."
FE_HTML=$(curl -s "$FRONTEND_URL")
if echo "$FE_HTML" | grep -q "DevOps Dictionary"; then
    log_info "  PASS: Frontend HTML contains 'DevOps Dictionary'"
else
    log_error "  FAIL: Frontend HTML does not contain expected title."
    exit 1
fi

# --- Summary ---
echo ""
log_info "============================================"
log_info "  ALL 5 SMOKE TESTS PASSED SUCCESSFULLY"
log_info "============================================"
echo ""
exit 0
