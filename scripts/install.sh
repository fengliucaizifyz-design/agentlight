#!/bin/bash
set -e

# install.sh — Convenience installer for AgentLight.
#
# 1. Gets the macOS menu-bar hub: builds from source if swiftc is available,
#    otherwise downloads the prebuilt, signed hub from the latest release.
# 2. Launches it.
# 3. The hub is agent-agnostic. Pass an optional adapter name to also wire up
#    that agent; with no name, it prints the per-agent commands instead.
#
# Usage:
#   ./scripts/install.sh                # hub only; prints adapter options
#   ./scripts/install.sh claude-code    # hub + Claude Code adapter
#   ./scripts/install.sh codex          # hub + Codex adapter
#   ./scripts/install.sh openclaw       # hub + OpenClaw adapter
#
# From a git clone:
#   git clone https://github.com/fengliucaizifyz-design/agentlight.git
#   cd agentlight && ./scripts/install.sh
#
# No compiler? Use the prebuilt path directly: ./scripts/install-release.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

# Optional agent adapter to wire up. The hub supports all agents equally; we
# never install one silently. Validate before doing any work.
ADAPTER="${1:-}"
case "$ADAPTER" in
    ""|claude-code|codex|openclaw) ;;
    *) warn "Unknown adapter '$ADAPTER' (expected: claude-code | codex | openclaw)"; exit 1 ;;
esac

# 1. Get the hub. Prefer a source build; fall back to the prebuilt release when
#    swiftc isn't installed (no Xcode Command Line Tools required).
if ! command -v swiftc >/dev/null 2>&1; then
    warn "swiftc not found — using the prebuilt, signed hub from the latest release."
    exec "$REPO_DIR/scripts/install-release.sh" "$@"
fi
# Stop any running hub (a login LaunchAgent or a previously-opened copy) before
# building, so we don't build over a busy binary and so the rebuilt hub actually
# replaces the old process instead of `open` just re-foregrounding the old one.
launchctl bootout "gui/$(id -u)/ai.agentlight.hub" 2>/dev/null || true
killall AgentLight 2>/dev/null || true

info "Building the hub…"
( cd "$REPO_DIR/hub" && ./build.sh )

# 2. Launch it
info "Launching the menu-bar hub…"
open "$REPO_DIR/hub/AgentLight.app"

# 3. Optionally wire up the requested agent adapter (the hub is agent-agnostic).
if [ -n "$ADAPTER" ]; then
    info "Installing the $ADAPTER adapter…"   # (the claude-code adapter needs jq)
    "$REPO_DIR/adapters/$ADAPTER/install.sh"
fi

echo ""
info "✅ Done."
info "Look for the light in your macOS menu bar."
if [ -z "$ADAPTER" ]; then
    echo ""
    info "Now connect YOUR agent — the hub works with all of them. Pick one:"
    echo "    ./adapters/claude-code/install.sh   # Claude Code  → then open a new session"
    echo "    ./adapters/openclaw/install.sh      # OpenClaw     → then: openclaw gateway restart"
    echo "    ./adapters/codex/install.sh         # Codex        → then trust hooks in Codex"
    info "Or re-run this with the agent name: ./scripts/install.sh <claude-code|codex|openclaw>"
fi
info "Optional: set a WLED light's IP from the menu to mirror colors to a physical light."
