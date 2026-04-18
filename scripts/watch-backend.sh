#!/usr/bin/env bash
# Watch backend source files and auto-rebuild on any change.
# Ctrl+C to stop.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_cmd docker
require_cmd dotnet
require_env

PROJECT="${WORKSPACE_DIR}/own-delivery-backend/src/OwnDeliveryApiP33/OwnDeliveryApiP33.csproj"
[[ -f "$PROJECT" ]] || die "Project not found: $PROJECT"

# ── Ensure DB is running ──────────────────────────────────────────────────────
DB_STATUS=$(docker inspect own-delivery-db --format '{{.State.Status}}' 2>/dev/null || echo "missing")
if [[ "$DB_STATUS" != "running" ]]; then
    log "Starting SQL Server..."
    docker compose --env-file "${INFRA_DIR}/.env" \
        -f "${INFRA_DIR}/docker/docker-compose.yml" up -d db

    log "Waiting for SQL Server to be healthy..."
    ELAPSED=0
    until docker inspect own-delivery-db --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; do
        sleep 2; ELAPSED=$((ELAPSED+2))
        [[ $ELAPSED -ge 60 ]] && die "SQL Server not healthy after 60s"
    done
    log "SQL Server is healthy."
fi

# ── Watch & rebuild ───────────────────────────────────────────────────────────
log "Watching for changes... Swagger → http://localhost:5134/swagger"
log "Press Ctrl+C to stop."
echo ""

export ASPNETCORE_ENVIRONMENT=Development
exec dotnet watch run --project "$PROJECT"
