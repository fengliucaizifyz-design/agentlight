---
name: openclaw-agentlight
description: Drive AgentLight status LED from OpenClaw internal hooks. Maps message, command, and gateway lifecycle events to LED states (thinking/success/idle/error) with a browser demo page.
metadata:
  { "openclaw": { "requires": { "bins": ["agentlight"] }, "events": ["message:received", "message:sent", "command:new", "command:reset", "command:stop", "gateway:startup", "gateway:shutdown"] } }
---

# openclaw-agentlight

Drive an [AgentLight](https://github.com/tifosi/agentlight) status LED from OpenClaw's internal hook system. When OpenClaw processes a message, the LED changes color automatically. Includes a browser demo page so you can see the state without real hardware.

## What it does

| OpenClaw Event | → LED State | Color |
|---|---|---|
| Message received | thinking | 🔵 Blue (pulsing) |
| Message sent | success | 🟢 Green |
| `/new` command | thinking | 🔵 Blue |
| `/reset` or `/stop` | idle | ⚫ Gray |
| Gateway startup/shutdown | idle | ⚫ Gray |

## Prerequisites

- **AgentLight CLI** must be installed:
  ```bash
  agentlight --help   # confirm it works
  ```

## Installation (one command)

```bash
cd ~/.openclaw/workspace/openclaw-agentlight
./scripts/install-openclaw-hook.sh
```

Or manually:

```bash
# 1. Copy hook files
mkdir -p ~/.openclaw/hooks/agentlight
cp -r hooks/agentlight/. ~/.openclaw/hooks/agentlight/

# 2. Enable the hook
openclaw hooks enable agentlight

# 3. Restart gateway
openclaw gateway restart
```

## Demo mode (no hardware needed)

The hook runs in `--demo` mode by default — it writes state to a JSON file instead of sending to USB. To see the demo:

```bash
# Start a web server
cd ~/.openclaw/workspace
python3 -m http.server 8080

# Open in browser
open http://localhost:8080/examples/agentlight.html
```

The demo page shows a colored circle that updates in real-time as OpenClaw events fire.

## Manual state control

```bash
agentlight set thinking --source openclaw --session test --demo
agentlight set success  --source openclaw --session test --demo
agentlight reset        --demo
```

## Files

```
openclaw-agentlight/
├── SKILL.md                       ← You are here
├── README.md
├── examples/
│   └── agentlight-state.json      ← Demo state file (written by hook)
├── hooks/
│   └── agentlight/
│       ├── HOOK.md                ← Hook metadata
│       └── handler.ts            ← Event handler
└── scripts/
    └── install-openclaw-hook.sh  ← One-command installer
```

## Uninstall

```bash
openclaw hooks disable agentlight
rm -rf ~/.openclaw/hooks/agentlight
```