---
name: agentlight
description: "Drive the AgentLight status light from OpenClaw events by POSTing state to the local hub (localhost:9527)"
metadata:
  { "openclaw": { "emoji": "💡", "events": ["message:received", "message:sent", "command:new", "command:reset", "command:stop", "gateway:startup", "gateway:shutdown"] } }
---

# AgentLight OpenClaw Hook

Drives the [AgentLight](https://github.com/fengliucaizifyz-design/agentlight) status light
based on OpenClaw agent events. The handler POSTs the mapped state to the local AgentLight
hub at `http://localhost:9527/state` — no external CLI or hardware required.

> Status: experimental. See [docs/DESIGN.md](../../docs/DESIGN.md).

## Event → State mapping

| OpenClaw event       | AgentLight state |
|----------------------|------------------|
| `message:received`   | `working`        |
| `message:sent`       | `idle`           |
| `command:new`        | `working`        |
| `command:reset`      | `idle`           |
| `command:stop`       | `idle`           |
| `gateway:startup`    | `idle`           |
| `gateway:shutdown`   | `offline`        |

OpenClaw has no "permission confirmation" event, so the `confirm` state is not triggered
from this adapter — that's expected.

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
