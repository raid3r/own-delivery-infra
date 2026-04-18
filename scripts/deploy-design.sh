#!/usr/bin/env bash
# Deploy own-delivery-design (Storybook) from GitHub.
# Usage: ./deploy-design.sh [--branch main] [--skip-pull]

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

REPO_DIR="${WORKSPACE_DIR}/own-delivery-design"

if [[ "$SKIP_PULL" == false ]]; then
    if [[ -d "$REPO_DIR/.git" ]]; then
        log "Pulling ${BRANCH} in ${REPO_DIR}..."
        git -C "$REPO_DIR" fetch origin
        git -C "$REPO_DIR" checkout "$BRANCH"
        git -C "$REPO_DIR" pull origin "$BRANCH"
    else
        die "Design repo not found at ${REPO_DIR}. Clone it first:\n  git clone https://github.com/${GITHUB_ORG}/${DESIGN_REPO} ${REPO_DIR}"
    fi
fi

log "Building Storybook image..."
docker build \
    -t "own-delivery-design:latest" \
    -t "own-delivery-design:$(git -C "$REPO_DIR" rev-parse --short HEAD)" \
    "$REPO_DIR"

log "Restarting design container..."
docker compose -f "${INFRA_DIR}/docker/docker-compose.yml" up -d --no-deps design

log "Design deployed successfully."
