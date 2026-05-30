#!/bin/bash
set -e

# install.sh — Convenience installer for AgentLight.
#
# 1. Builds the macOS menu-bar hub (requires Xcode Command Line Tools / swiftc).
# 2. Launches it.
# 3. Installs the Claude Code adapter (requires jq for auto-merge).
#
# Usage:
#   ./scripts/install.sh
#
# From a git clone:
#   git clone https://github.com/fengliucaizifyz-design/agentlight.git
#   cd agentlight && ./scripts/install.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

# 1. Build the hub
if ! command -v swiftc >/dev/null 2>&1; then
    warn "swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi
info "Building the hub…"
( cd "$REPO_DIR/hub" && ./build.sh )

# 2. Launch it
info "Launching the menu-bar hub…"
open "$REPO_DIR/hub/AgentLight.app"

# 3. Install the Claude Code adapter
info "Installing the Claude Code adapter…"
"$REPO_DIR/adapters/claude-code/install.sh"

echo ""
info "✅ Done."
info "Look for the light in your macOS menu bar, then start a Claude Code session."
info "Optional: set a WLED light's IP from the menu to mirror colors to a physical light."
