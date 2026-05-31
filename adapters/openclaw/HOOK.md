---
name: agentlight
description: "Drive the AgentLight status light from OpenClaw events by POSTing state to the local hub (localhost:9527)"
metadata:
  { "openclaw": { "emoji": "💡", "events": ["message", "command", "gateway"] } }
---

# AgentLight OpenClaw Hook

Drives the [AgentLight](https://github.com/fengliucaizifyz-design/agentlight) status light
based on OpenClaw agent events. The handler POSTs the mapped state to the local AgentLight
hub at `http://127.0.0.1:9527/state` using Node's `http` module, so local requests are
not intercepted by `HTTP_PROXY` / undici proxy dispatchers. No external CLI or hardware
is required.

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
| `gateway:shutdown`   | `offline`        |
| `gateway:pre-restart` | `offline`        |

Notes (verified against OpenClaw 2026.5.12):
- `message:sent` maps to `error` when OpenClaw reports `context.success === false`;
  otherwise it maps to `idle`.
- OpenClaw has no "permission confirmation" event, so `confirm` is not triggered here.

## Configuration

The hub endpoint defaults to `http://127.0.0.1:9527/state`. Override it by setting
`AGENTLIGHT_HUB` in the OpenClaw gateway process environment before the hook is loaded.
OpenClaw hook entry `env` values are used for eligibility checks and should not be relied
on to inject runtime environment variables into this handler.

## Requirements

- The AgentLight hub must be running (`agentlight/hub/AgentLight.app`).
