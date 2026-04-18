#!/usr/bin/env bash
# First-time environment setup.
# Run once before any other script.

set -euo pipefail
INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

EXAMPLE="${INFRA_DIR}/.env.example"
TARGET="${INFRA_DIR}/.env"

if [[ -f "$TARGET" ]]; then
    log ".env already exists — skipping copy"
else
    cp "$EXAMPLE" "$TARGET"
    log "Created .env from .env.example"
    log "⚠  Edit ${TARGET} and set real secrets before deploying!"
fi

# Verify required tools
for cmd in docker git; do
    if command -v "$cmd" &>/dev/null; then
        log "✓ $cmd found: $(command -v "$cmd")"
    else
        echo "[WARN] $cmd not found — please install it"
    fi
done

log "Setup complete."
