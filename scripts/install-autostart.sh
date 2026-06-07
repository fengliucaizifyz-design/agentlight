#!/bin/bash
set -e

# install-autostart.sh — Run the AgentLight hub at login (and start it now)
# via a macOS LaunchAgent.
#
# Why a LaunchAgent: launchd starts the app in the user's GUI (Aqua) session,
# so the menu-bar light is visible — even when this script is run by an
# automated agent / sandboxed shell. It also means the light auto-starts on
# every login and you never have to launch it by hand.
#
# Usage:  ./scripts/install-autostart.sh
# Remove: ./scripts/install-autostart.sh --uninstall

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO_DIR/hub/AgentLight.app"
BIN="$APP/Contents/MacOS/AgentLight"
LABEL="ai.agentlight.hub"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
GUI="gui/$(id -u)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

if [ "$1" = "--uninstall" ]; then
    launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    info "Auto-start removed."
    exit 0
fi

# Stop any running hub BEFORE building, so the binary isn't busy. Building over a
# running executable can fail silently (the process holds the file), and stopping
# first is also what lets an update actually replace the old process.
launchctl bootout "$GUI/$LABEL" 2>/dev/null || true

# Build (or rebuild) the hub. Rebuild when main.swift is newer than the built
# binary — so `git pull` + re-run picks up the new code, not just when the binary
# is missing. When swiftc is unavailable we rely on a prebuilt binary already
# being in place (the install-release.sh path), so only fail if there's nothing
# to run at all.
if command -v swiftc >/dev/null 2>&1; then
    if [ ! -x "$BIN" ] || [ "$REPO_DIR/hub/main.swift" -nt "$BIN" ]; then
        info "Building the hub…"
        ( cd "$REPO_DIR/hub" && ./build.sh )
    fi
elif [ ! -x "$BIN" ]; then
    warn "No prebuilt hub found and swiftc is unavailable — cannot build."
    warn "Install Xcode Command Line Tools, or run ./scripts/install-release.sh"
    exit 1
fi

# Ad-hoc sign + clear quarantine so macOS launches it without a Gatekeeper block.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || warn "codesign skipped"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# Write the LaunchAgent.
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
PLISTEOF

# (Re)load into the GUI session so it starts now and at every login.
launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
launchctl bootstrap "$GUI" "$PLIST"

info "✅ AgentLight will auto-start at login (and just started now)."
info "   Look for the colored dot in your menu bar."
info "   To stop auto-start: ./scripts/install-autostart.sh --uninstall"
