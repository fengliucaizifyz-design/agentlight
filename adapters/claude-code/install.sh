#!/bin/bash
set -e

# Install the AgentLight Claude Code adapter by merging its hooks into a
# Claude Code settings.json. Each hook POSTs the agent state to the local
# AgentLight hub (http://localhost:9527).
#
# Usage:
#   ./install.sh                       # merge into ~/.claude/settings.json (global)
#   ./install.sh /path/to/.claude/settings.json   # merge into a specific file
#
# Requires `jq` for automatic merging. Without it, the snippet is printed so
# you can paste it manually.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNIPPET="$SCRIPT_DIR/settings-hooks.json"
TARGET="${1:-$HOME/.claude/settings.json}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

mkdir -p "$(dirname "$TARGET")"

if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — cannot merge automatically."
    warn "Paste the \"hooks\" block from this file into $TARGET:"
    echo "  $SNIPPET"
    exit 0
fi

if [ -f "$TARGET" ]; then
    BACKUP="$TARGET.agentlight.bak"
    cp "$TARGET" "$BACKUP"
    info "Backed up existing settings → $BACKUP"
    # Deep-merge: incoming hooks override same-named event arrays.
    jq -s '.[0] * .[1]' "$TARGET" "$SNIPPET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
else
    cp "$SNIPPET" "$TARGET"
fi

info "Installed Claude Code hooks → $TARGET"
info "Make sure the AgentLight hub is running, then start a Claude Code session."
