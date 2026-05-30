---
name: agentlight
description: "Drive the AgentLight status light from OpenClaw events by POSTing state to the local hub (localhost:9527)"
metadata:
  { "openclaw": { "emoji": "💡", "events": ["message", "command", "gateway"] } }
---

# AgentLight OpenClaw Hook

Drives the [AgentLight](https://github.com/fengliucaizifyz-design/agentlight) status light
based on OpenClaw agent events. The handler POSTs the mapped state to the local AgentLight
hub at `http://localhost:9527/state` — no external CLI or hardware required.

> Verified against OpenClaw 2026.5.12. See [docs/DESIGN.md](../../docs/DESIGN.md).

## Install

```bash
adapters/openclaw/install.sh      # copies the hook + enables it
openclaw gateway restart          # activate (you run this when ready)
```

## Event → State mapping

| OpenClaw event       | AgentLight state |
|----------------------|------------------|
| `message:received`   | `working`        |
| `message:sent`       | `idle`           |
| `command:new`        | `idle`           |
| `command:reset`      | `idle`           |
| `command:stop`       | `idle`           |
| `gateway:startup`    | `idle`           |

Notes (verified against OpenClaw 2026.5.12):
- There is no `gateway:shutdown` event, so `offline` is not emitted from OpenClaw.
- OpenClaw has no "permission confirmation" event, so `confirm` is not triggered here.

## Configuration

The hub endpoint defaults to `http://localhost:9527/state`. Override it with the
`AGENTLIGHT_HUB` environment variable if the hub runs elsewhere:

```json
{
  "hooks": {
    "internal": {
      "entries": {
        "agentlight": {
          "enabled": true,
          "env": { "AGENTLIGHT_HUB": "http://localhost:9527/state" }
        }
      }
    }
  }
}
```

## Requirements

- The AgentLight hub must be running (`agentlight/hub/AgentLight.app`).
