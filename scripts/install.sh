#!/bin/bash
# install.sh — Install AgentLight OpenClaw hook
#
# Usage:
#   # From a git clone:
#   ./scripts/install.sh
#
#   # One-liner (no clone needed):
#   curl -sSL https://raw.githubusercontent.com/tifosi/agentlight/main/scripts/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn()  { echo -e "${YELLOW}[agentlight]${NC} $1"; }
error() { echo -e "${RED}[agentlight]${NC} $1" >&2; }

# Detect if we're running from a git clone or via curl
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if [ -f "$SCRIPT_SOURCE" ] && [ -d "$(dirname "$SCRIPT_SOURCE")/.git" ]; then
    # Running from a git clone
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PKG_DIR="$(dirname "$SCRIPT_DIR")"
    MODE="clone"
else
    # Running via curl one-liner — clone to temp
    MODE="curl"
    PKG_DIR="/tmp/agentlight-install"
    SCRIPT_DIR="$PKG_DIR/scripts"
    info "Installing agentlight to /tmp/agentlight-install..."
    if [ -d "$PKG_DIR/.git" ]; then
        git -C "$PKG_DIR" pull -q origin main 2>/dev/null || true
    else
        git clone -q --depth 1 https://github.com/tifosi/agentlight.git "$PKG_DIR"
    fi
fi

HOOK_SRC="$PKG_DIR/openclaw/hooks/agentlight"
HOOK_DEST="$HOME/.openclaw/hooks/agentlight"

# Check prereqs
if ! command -v openclaw &>/dev/null; then
    error "openclaw CLI not found. Is OpenClaw installed?"
    exit 1
fi

if ! command -v agentlight &>/dev/null; then
    error "agentlight CLI not found. Install it first:"
    error "  go install github.com/tifosi/agentlight/cmd/agentlight@latest"
    exit 1
fi

if [ ! -d "$HOOK_SRC" ]; then
    error "Hook source not found: $HOOK_SRC"
    error "Make sure you're running this from the agentlight repo."
    exit 1
fi

info "Installing AgentLight hook for OpenClaw..."

# Copy hook files
mkdir -p "$HOOK_DEST"
cp "$HOOK_SRC/HOOK.md" "$HOOK_DEST/"
cp "$HOOK_SRC/handler.ts" "$HOOK_DEST/"
info "  Copied hook files to $HOOK_DEST"

# Copy demo files to workspace examples/
WORKSPACE_EXAMPLES="$HOME/.openclaw/workspace/examples"
mkdir -p "$WORKSPACE_EXAMPLES"
if [ -f "$PKG_DIR/examples/agentlight-state.json" ]; then
    cp "$PKG_DIR/examples/agentlight-state.json" "$WORKSPACE_EXAMPLES/"
    info "  Copied demo state file to $WORKSPACE_EXAMPLES"
fi
if [ -f "$PKG_DIR/examples/demo.html" ]; then
    cp "$PKG_DIR/examples/demo.html" "$WORKSPACE_EXAMPLES/"
    info "  Copied demo HTML to $WORKSPACE_EXAMPLES"
fi

# Enable hook
info "Enabling agentlight hook..."
openclaw hooks enable agentlight 2>/dev/null || warn "  Hook may already be enabled."

# Show status
info "Hook status:"
openclaw hooks check 2>/dev/null | sed 's/^/  /'

echo ""
info "✅ AgentLight hook installed!"
info ""
info "Restart the gateway to activate:"
info "  openclaw gateway restart"
info ""
info "Try the demo (no hardware needed):"
info "  cd ~/.openclaw/workspace && python3 -m http.server 8080"
info "  Then open http://localhost:8080/examples/demo.html"