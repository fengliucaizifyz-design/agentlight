#!/bin/bash
set -e

# Install the AgentLight OpenClaw adapter.
#
# Copies the hook into ~/.openclaw/hooks/agentlight/ and enables it. Each event
# POSTs the mapped state to the local AgentLight hub (http://localhost:9527).
#
# This does NOT restart the gateway (that would interrupt active sessions) —
# you restart it yourself when ready: `openclaw gateway restart`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DEST="$HOME/.openclaw/hooks/agentlight"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }
err()  { echo -e "${RED}[agentlight]${NC} $1" >&2; }

if ! command -v openclaw >/dev/null 2>&1; then
    err "openclaw CLI not found. Is OpenClaw installed?"
    exit 1
fi

info "Copying hook to $HOOK_DEST"
mkdir -p "$HOOK_DEST"
cp "$SCRIPT_DIR/HOOK.md" "$SCRIPT_DIR/handler.ts" "$HOOK_DEST/"

info "Enabling hook…"
openclaw hooks enable agentlight 2>/dev/null || warn "Could not auto-enable — check 'openclaw hooks list'."

echo ""
info "✅ Installed. To activate, restart the gateway when ready:"
info "    openclaw gateway restart"
info "Make sure the AgentLight hub app is running first."
