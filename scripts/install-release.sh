#!/bin/bash
set -euo pipefail

# install-release.sh — Install AgentLight WITHOUT building from source.
#
# Downloads the prebuilt, ad-hoc-signed hub from the latest GitHub Release and
# installs it to run at login (LaunchAgent). The hub is agent-agnostic — pass an
# optional adapter name to also wire up that agent. No Xcode / swiftc required.
#
# Usage (from a clone):
#   ./scripts/install-release.sh                # hub only; prints adapter options
#   ./scripts/install-release.sh claude-code    # hub + Claude Code adapter
#   ./scripts/install-release.sh codex          # hub + Codex adapter
#   ./scripts/install-release.sh openclaw       # hub + OpenClaw adapter

REPO="fengliucaizifyz-design/agentlight"
ASSET="AgentLight-macos.zip"
URL="https://github.com/$REPO/releases/latest/download/$ASSET"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="$REPO_DIR/hub"
APP="$HUB/AgentLight.app"
BIN="$APP/Contents/MacOS/AgentLight"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

# Optional agent adapter to wire up. The hub itself supports all agents equally;
# we never install one silently. Validate before doing any work.
ADAPTER="${1:-}"
case "$ADAPTER" in
    ""|claude-code|codex|openclaw) ;;
    *) warn "Unknown adapter '$ADAPTER' (expected: claude-code | codex | openclaw)"; exit 1 ;;
esac

# 1. Download the prebuilt hub.
info "Downloading prebuilt hub from the latest release…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if ! curl -fsSL "$URL" -o "$TMP/$ASSET"; then
    warn "Download failed. No published release yet? Falling back to a source build:"
    warn "  ./scripts/install.sh"
    exit 1
fi

# 2. Install the app into hub/ (replacing any previous copy).
info "Installing the app…"
rm -rf "$APP"
mkdir -p "$HUB"
unzip -q -o "$TMP/$ASSET" -d "$HUB"
chmod +x "$BIN" 2>/dev/null || true
[ -x "$BIN" ] || { warn "Unpacked binary missing or not executable: $BIN"; exit 1; }

# 3. Hand off to the autostart installer. The binary already exists, so it skips
#    the swiftc build — it only ad-hoc re-signs, clears quarantine, and registers
#    the login LaunchAgent.
"$REPO_DIR/scripts/install-autostart.sh"

# 4. Optionally wire up the requested agent adapter (the hub is agent-agnostic).
if [ -n "$ADAPTER" ]; then
    info "Installing the $ADAPTER adapter…"   # (the claude-code adapter needs jq)
    "$REPO_DIR/adapters/$ADAPTER/install.sh"
fi

echo ""
info "✅ Done — prebuilt hub installed, no compiler needed."
info "Look for the colored dot in your menu bar."
if [ -z "$ADAPTER" ]; then
    echo ""
    info "Now connect YOUR agent — the hub works with all of them. Pick one:"
    echo "    ./adapters/claude-code/install.sh   # Claude Code  → then open a new session"
    echo "    ./adapters/openclaw/install.sh      # OpenClaw     → then: openclaw gateway restart"
    echo "    ./adapters/codex/install.sh         # Codex        → then trust hooks in Codex"
    info "Or re-run this with the agent name: ./scripts/install-release.sh <claude-code|codex|openclaw>"
fi
info "Optional: set a WLED light's IP from the menu to mirror colors to a physical light."
