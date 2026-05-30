---
name: openclaw-agentlight
description: Drive the AgentLight status light from OpenClaw internal hooks. Maps message, command, and gateway lifecycle events to states (idle/working/confirm/error/offline) and POSTs them to the local hub. Includes a browser demo page.
metadata:
  { "openclaw": { "events": ["message:received", "message:sent", "command:new", "command:reset", "command:stop", "gateway:startup", "gateway:shutdown"] } }
---

# openclaw-agentlight

Drive the [AgentLight](https://github.com/fengliucaizifyz-design/agentlight) status light
from OpenClaw's internal hook system. When OpenClaw processes a message or command, the
hook POSTs the matching state to the local AgentLight hub (`http://localhost:9527`), which
updates the macOS menu-bar light and any connected WLED light.

> Verified against OpenClaw 2026.5.12.

## What it does

| OpenClaw event | → State | Color |
|---|---|---|
| Message received | working | 🟡 Amber |
| Message sent | idle | 🟢 Green |
| `/new`, `/reset`, `/stop` | idle | 🟢 Green |
| Gateway startup | idle | 🟢 Green |

## Prerequisites

- The AgentLight hub running (`agentlight/hub/AgentLight.app`). No separate CLI needed.

## Installation

```bash
# 1. Copy hook files
mkdir -p ~/.openclaw/hooks/agentlight
cp adapters/openclaw/. ~/.openclaw/hooks/agentlight/ -r

# 2. Enable the hook
openclaw hooks enable agentlight

# 3. Restart the gateway
openclaw gateway restart
```

## Demo (no hardware needed)

With the hub running:

```bash
cd examples && python3 -m http.server 8099
open http://localhost:8099/demo.html
```

## Uninstall

```bash
openclaw hooks disable agentlight
rm -rf ~/.openclaw/hooks/agentlight
```
