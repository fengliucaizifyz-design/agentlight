---
name: agentlight
description: "Drive AgentLight status LED via CLI based on OpenClaw events — demo mode writes to a JSON state file"
metadata:
  { "openclaw": { "emoji": "💡", "events": ["message:received", "message:sent", "command:new", "command:reset", "command:stop", "gateway:startup", "gateway:shutdown"], "requires": { "bins": ["agentlight"] } } }
---

# AgentLight Hook

Drives an [AgentLight](https://github.com/tifosi/agentlight) status LED based on OpenClaw agent events.

## Demo Mode

When `--demo` is used (or no real hardware is connected), state changes are written
to a JSON file instead of sent over USB. The demo file path is configurable via
the `demoFile` environment variable (defaults to `examples/agentlight-state.json`
in the workspace).

## Event → State Mapping

| OpenClaw Event        | AgentLight State |
|----------------------|------------------|
| `message:received`   | `thinking`       |
| `message:sent`       | `success`        |
| `command:new`        | `thinking`       |
| `command:reset`      | `idle`           |
| `command:stop`       | `idle`           |
| `gateway:startup`    | `idle`           |
| `gateway:shutdown`   | `idle`           |

## Configuration

```json
{
  "hooks": {
    "internal": {
      "entries": {
        "agentlight": {
          "enabled": true,
          "env": {
            "AGENTLIGHT_DEMO_FILE": "/path/to/agentlight-state.json"
          }
        }
      }
    }
  }
}
```

## Requirements

- `agentlight` CLI must be in PATH
- Demo mode: `--demo` flag used automatically when no hardware is connected