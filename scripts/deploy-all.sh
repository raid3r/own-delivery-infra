#!/usr/bin/env bash
# Deploy all services: DB → Backend → Design → Nginx.
# Usage: ./deploy-all.sh [--branch main] [--env prod|dev]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

BRANCH="main"
ENV="prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --env)    ENV="$2"; shift 2 ;;
        *) die "Unknown flag: $1" ;;
    esac
done

require_cmd docker
require_env

log "=== OwnDelivery full deploy (env=${ENV}, branch=${BRANCH}) ==="

COMPOSE_FILES="-f ${INFRA_DIR}/docker/docker-compose.yml"
if [[ "$ENV" == "prod" ]]; then
    COMPOSE_FILES+=" -f ${INFRA_DIR}/docker/docker-compose.prod.yml"
elif [[ "$ENV" == "dev" ]]; then
    COMPOSE_FILES+=" -f ${INFRA_DIR}/docker/docker-compose.dev.yml"
fi

# ── 1. Deploy backend ─────────────────────────────────────────────────────────
"${SCRIPT_DIR}/deploy-backend.sh" --branch "$BRANCH"

# ── 2. Deploy design ─────────────────────────────────────────────────────────
"${SCRIPT_DIR}/deploy-design.sh" --branch "$BRANCH"

# ── 3. Start all services ─────────────────────────────────────────────────────
log "Starting all services..."
# shellcheck disable=SC2086
docker compose $COMPOSE_FILES up -d

log "=== All services running ==="
docker compose $COMPOSE_FILES ps
