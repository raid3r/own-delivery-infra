#!/usr/bin/env bash
# Start backend for local development.
#
# What it does:
#   1. Starts SQL Server in Docker (if not already running)
#   2. Waits until DB is healthy
#   3. Creates appsettings.Development.json in the backend project (if absent)
#   4. Applies pending EF Core migrations
#   5. Runs `dotnet run` (hot-reload via dotnet watch is opt-in via --watch flag)
#
# Usage:
#   ./scripts/dev-backend-start.sh            # normal run
#   ./scripts/dev-backend-start.sh --watch    # with hot-reload (dotnet watch)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

WATCH=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch) WATCH=true; shift ;;
        *) die "Unknown flag: $1. Usage: $0 [--watch]" ;;
    esac
done

require_cmd docker
require_cmd dotnet
require_env

BACKEND_DIR="${WORKSPACE_DIR}/own-delivery-backend"
PROJECT_PATH="${BACKEND_DIR}/src/OwnDeliveryApiP33/OwnDeliveryApiP33.csproj"
DEV_SETTINGS="${BACKEND_DIR}/src/OwnDeliveryApiP33/appsettings.Development.json"

[[ -f "$PROJECT_PATH" ]] || die "Backend project not found at: ${PROJECT_PATH}"

# ── 1. Start DB container ─────────────────────────────────────────────────────
log "Starting SQL Server..."
docker compose --env-file "${INFRA_DIR}/.env" \
    -f "${INFRA_DIR}/docker/docker-compose.yml" \
    up -d db

# ── 2. Wait for DB to be healthy ──────────────────────────────────────────────
log "Waiting for SQL Server to be healthy..."
TIMEOUT=60
ELAPSED=0
until docker inspect own-delivery-db --format '{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    [[ $ELAPSED -ge $TIMEOUT ]] && die "SQL Server did not become healthy in ${TIMEOUT}s"
done
log "SQL Server is healthy."

# ── 3. Create appsettings.Development.json if missing ────────────────────────
if [[ ! -f "$DEV_SETTINGS" ]]; then
    log "Creating ${DEV_SETTINGS}..."
    cat > "$DEV_SETTINGS" << EOF
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;Database=OwnDelivery;User Id=sa;Password=${MSSQL_SA_PASSWORD};TrustServerCertificate=true;"
  },
  "Jwt": {
    "Key": "${Jwt__Key}",
    "Issuer": "OwnDeliveryApi",
    "Audience": "OwnDeliveryApi",
    "AccessTokenExpirationMinutes": 60,
    "RefreshTokenExpirationDays": 30
  }
}
EOF
    log "appsettings.Development.json created (not committed — safe)."
else
    log "appsettings.Development.json already exists — skipping."
fi

# ── 4. Apply EF migrations ────────────────────────────────────────────────────
if command -v dotnet-ef &>/dev/null || dotnet tool list -g | grep -q "dotnet-ef"; then
    log "Applying EF Core migrations..."
    dotnet ef database update --project "$PROJECT_PATH" \
        --connection "Server=localhost,1433;Database=OwnDelivery;User Id=sa;Password=${MSSQL_SA_PASSWORD};TrustServerCertificate=true;"
else
    log "dotnet-ef not found — skipping migrations. Install with: dotnet tool install -g dotnet-ef"
fi

# ── 5. Run backend ────────────────────────────────────────────────────────────
log "Starting backend (ASPNETCORE_ENVIRONMENT=Development)..."
log "Swagger: http://localhost:5134/swagger"
log ""

export ASPNETCORE_ENVIRONMENT=Development

if [[ "$WATCH" == true ]]; then
    log "Mode: dotnet watch (auto-reload on file changes)"
    exec dotnet watch run --project "$PROJECT_PATH"
else
    log "Mode: dotnet run (restart manually after changes)"
    exec dotnet run --project "$PROJECT_PATH"
fi
