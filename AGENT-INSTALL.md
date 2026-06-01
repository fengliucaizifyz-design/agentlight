# AgentLight — install guide (for the AI agent reading this)

**You are an AI coding agent** (Claude Code, Codex, OpenClaw, or similar) running on the
user's machine. The user wants you to set up **AgentLight** — a status light that reflects
your activity:

- a **macOS menu-bar light** (always — this is the core), and
- optionally a **physical WiFi light** (only if the user has one).

Architecture — everything reports to one tiny local hub, which fans out to the menu bar and
(optionally) the physical light:

```
your hooks ──curl──> http://localhost:9527/state ──> menu-bar light
                                                 └──> physical WiFi light (optional)
```

State → color: `idle` 🟢 · `working` 🟡 · `confirm` 🔵 · `error` 🔴 · `offline` ⚪️

Do the steps below **for your platform**. Requires **macOS**. Be concise with the user;
only stop to ask them when a step says so.

---

## Step 1 — Install & start the hub (all platforms)

The hub is a small menu-bar app (Swift, no third-party deps). Build it and set it to
auto-start (the auto-start step also makes the menu-bar light appear reliably):

```bash
# 1. Get the code
git clone https://github.com/fengliucaizifyz-design/agentlight ~/agentlight 2>/dev/null || \
  (cd ~/agentlight && git pull)

# 2a. PREFERRED — no compiler needed: download the prebuilt signed hub, then
#     auto-start it at login (also clears the download quarantine for you).
~/agentlight/scripts/install-release.sh

# 2b. OR build from source (only if you have swiftc / Xcode Command Line Tools):
# ~/agentlight/scripts/install-autostart.sh
```

- Prefer **2a** (the prebuilt path) — it needs no compiler. Use **2b** only when `swiftc`
  is already available.
- If you go the source route and `swiftc` is missing, either switch to **2a** or tell the
  user to run `xcode-select --install` (they must click "Install" in the dialog), then retry.
- The prebuilt hub is ad-hoc signed, not notarized; `install-release.sh` already clears the
  quarantine, so no Gatekeeper prompt should appear.
- Verify the hub is up: `curl -s http://localhost:9527/state` should return JSON.
- Tell the user they should now see a small dot in the menu bar (their menu bar may be busy;
  it's the colored dot near the right-side icons).

## Step 2 — Wire up YOUR hooks

Pick the block that matches **which agent you are**:

### You are Claude Code
```bash
~/agentlight/adapters/claude-code/install.sh        # merges hooks into ~/.claude/settings.json (needs jq)
```
Then tell the user: **hooks load at session start — open a new Claude Code session** to see
the light react.

### You are OpenClaw
```bash
~/agentlight/adapters/openclaw/install.sh           # installs + enables the hook
```
Then tell the user to run **`openclaw gateway restart`** (it briefly interrupts the gateway).
After that, sending a message to the agent drives the light.

### You are Codex
```bash
~/agentlight/adapters/codex/install.sh              # appends hooks to ~/.codex/config.toml
```
Then tell the user: **restart Codex or open a new Codex session**. If Codex shows
**"Hooks need review"**, choose **"Trust all and continue"**. Do **not** modify the existing
`notify` setting; it may already be used by computer-use or another integration.
Verify with `~/.codex/hooks/agentlight-state.sh working`, then
`curl -s http://localhost:9527/state` showing `"source":"codex"`. For Codex Desktop,
also watch `~/.codex/hooks/agentlight.log` during a normal Desktop chat. If CLI/TUI logs
hook events but Desktop does not, the Desktop app-server path is not executing these hooks
on that machine; document that as a Desktop/app-server limitation rather than reinstalling.

## Step 3 — (Optional) the physical WiFi light

Only if the user says they have the AgentLight WiFi light:

1. Make sure it's joined to the user's 2.4 GHz WiFi (one-time phone onboarding, like any
   smart light).
2. In the AgentLight menu-bar menu, choose **"Set Physical Light (WLED) IP…"** and enter
   **`agentlight.local`** (or its LAN IP).

The hub then mirrors every color to the physical light. If the user has no light, skip this —
the menu-bar light works on its own.

---

## Verify

Do something that uses a tool. The menu-bar dot (and the physical light, if set up) should
turn 🟡 while you work and return to 🟢 when idle. If a permission prompt appears it should
turn 🔵.

## Uninstall

```bash
~/agentlight/scripts/install-autostart.sh --uninstall   # stop auto-start
# Claude Code: remove the AgentLight hooks from ~/.claude/settings.json
# OpenClaw:   openclaw hooks disable agentlight
# Codex:      remove the AgentLight block from ~/.codex/config.toml and delete ~/.codex/hooks/agentlight-state.sh
```
