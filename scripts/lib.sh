#!/usr/bin/env bash
# Shared helpers — sourced by all deploy scripts.

set -euo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$(dirname "$INFRA_DIR")"
ENV_FILE="${INFRA_DIR}/.env"

# Use the real .NET SDK installed under ~/.dotnet (not the stub at /usr/bin/dotnet)
if [[ -d "${HOME}/.dotnet" ]]; then
    export DOTNET_ROOT="${HOME}/.dotnet"
    export PATH="${DOTNET_ROOT}:${PATH}"
fi

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[ERROR] $*" >&2; }
die()  { err "$*"; exit 1; }

require_env() {
    [[ -f "$ENV_FILE" ]] || die ".env not found — copy .env.example to .env and fill in values"
    # shellcheck source=/dev/null
    source "$ENV_FILE"
}

require_cmd() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}

docker_compose() {
    local compose_file="${INFRA_DIR}/docker/docker-compose.yml"
    local override="${1:-}"
    if [[ -n "$override" && -f "${INFRA_DIR}/docker/${override}" ]]; then
        docker compose -f "$compose_file" -f "${INFRA_DIR}/docker/${override}" "${@:2}"
    else
        docker compose -f "$compose_file" "${@}"
    fi
}
