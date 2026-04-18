#!/usr/bin/env bash
# Deploy own-delivery-courier-app (React Native / Expo).
# This script builds the OTA update bundle via Expo EAS or a local export.
# Usage: ./deploy-courier-app.sh [--branch main] [--platform android|ios|all]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

BRANCH="main"
PLATFORM="all"
SKIP_PULL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch)   BRANCH="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        --skip-pull) SKIP_PULL=true; shift ;;
        *) die "Unknown flag: $1" ;;
    esac
done

require_cmd node
require_env

REPO_DIR="${WORKSPACE_DIR}/own-delivery-courier-app"

if [[ "$SKIP_PULL" == false ]]; then
    if [[ -d "$REPO_DIR/.git" ]]; then
        log "Pulling ${BRANCH} in ${REPO_DIR}..."
        git -C "$REPO_DIR" fetch origin
        git -C "$REPO_DIR" checkout "$BRANCH"
        git -C "$REPO_DIR" pull origin "$BRANCH"
    else
        die "Courier-app repo not found at ${REPO_DIR}. Clone it first:\n  git clone https://github.com/${GITHUB_ORG}/${COURIER_APP_REPO} ${REPO_DIR}"
    fi
fi

log "Installing dependencies..."
(cd "$REPO_DIR" && npm ci)

# ── EAS Build (if eas-cli is available) ──────────────────────────────────────
if command -v eas &>/dev/null; then
    log "Building with EAS for platform: ${PLATFORM}..."
    (cd "$REPO_DIR" && eas build --platform "$PLATFORM" --non-interactive)
else
    log "eas-cli not found — running local Expo export instead..."
    (cd "$REPO_DIR" && npx expo export --platform "$PLATFORM")
    log "Export complete: ${REPO_DIR}/dist/"
fi

log "Courier app deployed successfully."
