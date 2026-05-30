#!/bin/bash
set -e

# Install the AgentLight Codex adapter.
#
# Copies the state helper into ~/.codex/hooks/ and appends verified Codex hook
# config to ~/.codex/config.toml. Existing Codex config is preserved, including
# any existing `notify = [...]` setting.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_HOME/config.toml"
HOOK_DIR="$CODEX_HOME/hooks"
HELPER="$HOOK_DIR/agentlight-state.sh"
MARKER_BEGIN="# >>> AgentLight Codex hooks >>>"
MARKER_END="# <<< AgentLight Codex hooks <<<"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[agentlight]${NC} $1"; }
warn() { echo -e "${YELLOW}[agentlight]${NC} $1"; }

mkdir -p "$HOOK_DIR"
cp "$SCRIPT_DIR/agentlight-state.sh" "$HELPER"
chmod +x "$HELPER"
info "Installed Codex helper -> $HELPER"

mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"

if grep -q "$MARKER_BEGIN" "$CONFIG"; then
  warn "AgentLight Codex hooks already exist in $CONFIG; leaving config unchanged."
else
  BACKUP="$CONFIG.agentlight.bak"
  cp "$CONFIG" "$BACKUP"
  {
    printf '\n%s\n' "$MARKER_BEGIN"
    cat "$SCRIPT_DIR/config-hooks.toml"
    printf '%s\n' "$MARKER_END"
  } >> "$CONFIG"
  info "Backed up Codex config -> $BACKUP"
  info "Appended Codex hooks -> $CONFIG"
fi

echo ""
info "Restart Codex or open a new Codex session."
info "If Codex shows 'Hooks need review', choose 'Trust all and continue'."
info "Verify after a tool call: curl -s http://localhost:9527/state"
