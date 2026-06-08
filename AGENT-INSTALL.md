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

## Setting up a plugged-in AgentLight **screen** (USB)?

If the user said something like *"读取并设置我刚插上的 USB 设备"* / "set up the AgentLight
screen I just plugged in", they have the **Pro Max screen** on USB. Do this, then you're done
(it covers the hub install too):

1. **Find the device.** It self-announces on a USB serial port. Easiest:
   ```bash
   git clone https://github.com/fengliucaizifyz-design/agentlight ~/agentlight 2>/dev/null || (cd ~/agentlight && git pull)
   python3 ~/agentlight/firmware/agentlight-screen/tools/agentlight-usb.py find
   # -> {"port":"/dev/cu.usbmodemXXXX","id":"..","wifi":"..","ip":"..","setup":".."}
   ```
   (Needs `pyserial`: `python3 -m pip install pyserial` if missing.) If it returns an error,
   tell the user to check the USB cable is a **data** cable and re-plug.

2. **Install the hub + your own adapter** — follow Step 1 then Step 2 below (build locally; no
   notarization needed since it's a local build).

3. **Get the user's Wi-Fi and provision the screen** (must be **2.4 GHz**; ESP32 has no 5 GHz):
   - Get the current Wi-Fi name and its password from the Mac (the password is in the
     Keychain — this pops a one-time "Allow" dialog the user approves, so they don't type it):
     ```bash
     SSID=$(ipconfig getsummary en0 | awk -F' SSID : ' '/ SSID :/{print $2; exit}')
     PASS=$(security find-generic-password -wa "$SSID")   # user clicks Allow
     ```
   - **Confirm with the user**: "Connect the screen to «$SSID»?" If they're on a 5 GHz-only
     network (or it fails), ask them for a 2.4 GHz SSID + password instead.
   - Send it to the device:
     ```bash
     python3 ~/agentlight/firmware/agentlight-screen/tools/agentlight-usb.py provision --ssid "$SSID" --pass "$PASS"
     # -> {"ok":true,"ip":".."}  (or {"ok":false,"error":".."})
     ```

4. **Done.** On `{"ok":true,...}` the screen shows "配置完成 / 可拔线随身使用". Tell the user:
   **they can unplug the USB now — it runs on battery over Wi-Fi**, and the hub auto-discovers
   it (mDNS). Confirm with a test: trigger a tool call and the screen should turn 🟡.

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

## Step 3 — (Optional) the physical light

Only if the user has a light. Two cases:

- **AgentLight screen (Pro Max):** nothing to type. Power it and onboard its WiFi (its
  on-screen guide walks the user through joining the `AgentLight-XXXX` hotspot from a phone,
  2.4 GHz). The hub **auto-discovers** it on the LAN (Bonjour `_agentlight._tcp`) — leave
  "Set Physical Light IP" **empty**; the menu shows `Light: <ip> (auto)` once found.
- **A generic WLED light:** in the menu choose **"Set Physical Light (WLED) IP…"** and enter
  its **LAN IP** (e.g. `192.168.1.42`). Do **not** enter `agentlight.local` — macOS times out
  resolving `.local` names in a URL, so the push would fail.

The hub then mirrors every color to the light. No light? Skip this — the menu-bar light works
on its own.

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
