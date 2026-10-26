#!/usr/bin/env bash
# =============================================================================
# rollback.sh - Rollback Dictionary App về phiên bản Docker image cũ
# =============================================================================
# Script triển khai lại ứng dụng bằng một tag image cụ thể (thường là Git SHA),
# kiểm tra image tồn tại, deploy qua Docker Compose và xác minh sức khỏe.
#
# Sử dụng:
#   ./scripts/rollback.sh <IMAGE_TAG>
#
# Ví dụ:
#   ./scripts/rollback.sh abc1234
#
# Biến môi trường cần thiết (hoặc đặt trong file .env):
#   IMAGE_REGISTRY - Registry URL (mặc định: ghcr.io)
#   IMAGE_OWNER    - GitHub username/org (mặc định: đọc từ .env)
#
# LƯU Ý QUAN TRỌNG:
#   - Script KHÔNG xóa database volume (--volumes).
#   - Rollback image KHÔNG tự động đảo ngược thay đổi schema database.
#     Nếu phiên bản mới đã chạy Flyway migration tạo cột/bảng mới,
#     phiên bản cũ vẫn thấy schema mới. Các migration cần thiết kế
#     tương thích ngược (backward-compatible) hoặc cần có quy trình
#     phục hồi schema riêng.
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[ROLLBACK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[ROLLBACK]${NC} $*"; }
log_error() { echo -e "${RED}[ROLLBACK]${NC} $*"; }
log_step()  { echo -e "${CYAN}[ROLLBACK]${NC} $*"; }

# --- Validate input ---
if [ $# -lt 1 ] || [ -z "$1" ]; then
    log_error "Usage: $0 <IMAGE_TAG>"
    log_error "Example: $0 abc1234"
    exit 1
fi

ROLLBACK_TAG="$1"

# --- Determine project root (where docker-compose.yml lives) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Load .env if exists ---
if [ -f "$PROJECT_ROOT/.env" ]; then
    log_info "Loading environment from .env"
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.env"
    set +a
fi

IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io}"
IMAGE_OWNER="${IMAGE_OWNER:-}"

if [ -z "$IMAGE_OWNER" ]; then
    log_error "IMAGE_OWNER is not set. Configure it in .env or export it."
    log_error "Example: export IMAGE_OWNER=your-github-username"
    exit 1
fi

BACKEND_IMAGE="${IMAGE_REGISTRY}/${IMAGE_OWNER}/dictionary-backend:${ROLLBACK_TAG}"
FRONTEND_IMAGE="${IMAGE_REGISTRY}/${IMAGE_OWNER}/dictionary-frontend:${ROLLBACK_TAG}"

log_info "============================================"
log_info "  ROLLBACK TO TAG: $ROLLBACK_TAG"
log_info "============================================"
log_info "Backend image:  $BACKEND_IMAGE"
log_info "Frontend image: $FRONTEND_IMAGE"
echo ""

# --- Step 1: Record current running image tags ---
log_step "Step 1: Recording currently running image tags..."
CURRENT_BACKEND=$(docker inspect --format='{{.Config.Image}}' dictionary-backend 2>/dev/null || echo "unknown")
CURRENT_FRONTEND=$(docker inspect --format='{{.Config.Image}}' dictionary-frontend 2>/dev/null || echo "unknown")
log_info "  Current backend:  $CURRENT_BACKEND"
log_info "  Current frontend: $CURRENT_FRONTEND"
echo ""

# --- Step 2: Verify target images exist ---
log_step "Step 2: Verifying rollback images exist..."

pull_image() {
    local image="$1"
    local label="$2"
    log_info "  Pulling $label: $image"
    if ! docker pull "$image"; then
        log_error "  Failed to pull $label image: $image"
        log_error "  Ensure the tag '$ROLLBACK_TAG' exists in the registry."
        log_error "  Check: https://${IMAGE_REGISTRY}/${IMAGE_OWNER}"
        exit 1
    fi
    log_info "  OK: $label image pulled successfully."
}

pull_image "$BACKEND_IMAGE" "backend"
pull_image "$FRONTEND_IMAGE" "frontend"
echo ""

# --- Step 3: Deploy with Docker Compose ---
log_step "Step 3: Deploying rollback images via Docker Compose..."
log_warn "  Database volume will NOT be removed."

cd "$PROJECT_ROOT"

export IMAGE_TAG="$ROLLBACK_TAG"

docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build

log_info "  Containers recreated with tag: $ROLLBACK_TAG"
echo ""

# --- Step 4: Health check ---
log_step "Step 4: Verifying deployment health..."

BACKEND_PORT="${BACKEND_PORT:-8180}"
HEALTH_URL="http://127.0.0.1:${BACKEND_PORT}/api/health"
MAX_WAIT=30
HEALTHY=false

for i in $(seq 1 "$MAX_WAIT"); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        HEALTHY=true
        log_info "  Health check passed (attempt $i/$MAX_WAIT)."
        break
    fi
    sleep 1
done

if [ "$HEALTHY" != "true" ]; then
    log_error "  Health check FAILED after ${MAX_WAIT}s!"
    log_error "  Last HTTP code: $HTTP_CODE"
    log_warn "  Backend logs:"
    docker logs dictionary-backend --tail 30
    echo ""
    log_error "  Rollback deployment may have failed."
    log_warn "  To restore previous version, run:"
    log_warn "    Previous backend:  $CURRENT_BACKEND"
    log_warn "    Previous frontend: $CURRENT_FRONTEND"
    exit 1
fi

# --- Step 5: Quick API verification ---
log_step "Step 5: Quick API verification..."
DEFINE_BODY=$(curl -s --max-time 10 "http://127.0.0.1:${BACKEND_PORT}/api/define/computer" || echo "{}")
if echo "$DEFINE_BODY" | grep -q '"success":true'; then
    log_info "  /api/define/computer: PASS"
else
    log_warn "  /api/define/computer returned unexpected response (non-critical)."
fi

# --- Summary ---
echo ""
log_info "============================================"
log_info "  ROLLBACK SUCCESSFUL"
log_info "============================================"
log_info "  Deployed tag:       $ROLLBACK_TAG"
log_info "  Previous backend:   $CURRENT_BACKEND"
log_info "  Previous frontend:  $CURRENT_FRONTEND"
log_info ""
log_info "  To verify manually:"
log_info "    curl http://127.0.0.1:${BACKEND_PORT}/api/health"
log_info "    docker compose ps"
echo ""
exit 0
