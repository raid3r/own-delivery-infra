#!/usr/bin/env bash
# Stop local backend development environment.
#
# What it does:
#   - Stops the SQL Server Docker container
#   - Optionally removes the container and volume (--clean)
#
# Usage:
#   ./scripts/dev-backend-stop.sh           # stop DB container, keep data
#   ./scripts/dev-backend-stop.sh --clean   # stop + remove container + delete volume (wipes DB)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CLEAN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean) CLEAN=true; shift ;;
        *) die "Unknown flag: $1. Usage: $0 [--clean]" ;;
    esac
done

require_cmd docker
require_env

COMPOSE="docker compose --env-file ${INFRA_DIR}/.env -f ${INFRA_DIR}/docker/docker-compose.yml"

# dotnet run/watch занимает foreground — скрипт тільки зупиняє БД.
# Сам процес dotnet зупиняється через Ctrl+C у терміналі де він запущений.

if [[ "$CLEAN" == true ]]; then
    log "Stopping and removing DB container + volume (all data will be lost)..."
    $COMPOSE stop db
    $COMPOSE rm -f db
    docker volume rm docker_mssql_data 2>/dev/null && log "Volume removed." || log "Volume not found (already removed?)."
else
    log "Stopping SQL Server container (data preserved)..."
    $COMPOSE stop db
    log "Done. Data is safe in Docker volume 'docker_mssql_data'."
    log "To also delete data: $0 --clean"
fi
