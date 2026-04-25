#!/usr/bin/env bash
# Deploy own-delivery-backend from GitHub.
# Usage: ./deploy-backend.sh [--branch main] [--skip-pull]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

BRANCH="main"
SKIP_PULL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --skip-pull) SKIP_PULL=true; shift ;;
        *) die "Unknown flag: $1" ;;
    esac
done

require_cmd docker
require_env

REPO_DIR="${WORKSPACE_DIR}/own-delivery-backend"

# ── 1. Pull latest code ───────────────────────────────────────────────────────
if [[ "$SKIP_PULL" == false ]]; then
    if [[ -d "$REPO_DIR/.git" ]]; then
        log "Pulling ${BRANCH} in ${REPO_DIR}..."
        git -C "$REPO_DIR" fetch origin
        git -C "$REPO_DIR" checkout "$BRANCH"
        git -C "$REPO_DIR" pull origin "$BRANCH"
    else
        die "Backend repo not found at ${REPO_DIR}. Clone it first:\n  git clone https://github.com/${GITHUB_ORG}/${BACKEND_REPO} ${REPO_DIR}"
    fi
fi

# ── 2. Build Docker images ────────────────────────────────────────────────────
GIT_SHA="$(git -C "$REPO_DIR" rev-parse --short HEAD)"

log "Building SDK (build) stage for migrations..."
docker build --target build \
    -t "own-delivery-backend:build" \
    "$REPO_DIR"

log "Building runtime image..."
docker build \
    -t "own-delivery-backend:latest" \
    -t "own-delivery-backend:${GIT_SHA}" \
    "$REPO_DIR"

# ── 3. Apply DB migrations ────────────────────────────────────────────────────
log "Waiting for DB to be healthy..."
docker compose --env-file "${INFRA_DIR}/.env" -f "${INFRA_DIR}/docker/docker-compose.yml" up -d db
timeout 60 bash -c 'until docker inspect own-delivery-db --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do sleep 2; done'

log "Running EF migrations..."
docker run --rm \
    --network docker_own-delivery-net \
    -e "ConnectionStrings__DefaultConnection=${ConnectionStrings__DefaultConnection}" \
    "own-delivery-backend:build" \
    dotnet ef database update --project OwnDeliveryApiP33/OwnDeliveryApiP33.csproj

# ── 4. Restart backend service ────────────────────────────────────────────────
log "Restarting backend container..."
docker compose -f "${INFRA_DIR}/docker/docker-compose.yml" up -d --no-deps backend

log "Backend deployed successfully."
