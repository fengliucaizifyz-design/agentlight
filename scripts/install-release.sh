#!/bin/bash
set -euo pipefail

# install-release.sh — Install AgentLight WITHOUT building from source.
#
# Downloads the prebuilt, ad-hoc-signed hub from the latest GitHub Release,
# installs it to run at login (LaunchAgent), and wires up the Claude Code
# adapter. No Xcode Command Line Tools / swiftc required.
#
# Usage (from a clone):
#   ./scripts/install-release.sh

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

# 4. Install the Claude Code adapter (requires jq for auto-merge).
info "Installing the Claude Code adapter…"
"$REPO_DIR/adapters/claude-code/install.sh"

echo ""
info "✅ Done — prebuilt hub installed, no compiler needed."
info "Look for the colored dot in your menu bar, then start a Claude Code session."
info "Optional: set a WLED light's IP from the menu to mirror colors to a physical light."
