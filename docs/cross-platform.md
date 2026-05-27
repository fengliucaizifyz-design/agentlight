# Cross-Platform Support

This project focuses on OpenClaw. Here are notes on supporting other AI coding agents.

## Architecture

AgentLight has two layers:

```
Layer 1: Event Source    (OpenClaw hook, Claude Code hook, etc.)
    ↓
Layer 2: agentlight CLI (state → LED)
```

Any tool that can call `agentlight set <state>` can drive the LED. The event source is the only variable.

## Platform Comparison

| Platform | Event Source | Status |
|---|---|---|
| **OpenClaw** | Internal hook system | ✅ Native |
| **Claude Code** | `~/.claude/hooks/` | 🔜 Planned |
| **GitHub Copilot** | Workspace file events | 🔜 Planned |
| **Codex (OpenAI)** | No hook system | 🔜 Planned |

## OpenClaw (done)

The OpenClaw hook (`openclaw/hooks/agentlight/handler.ts`) listens to:
- `message:received`
- `message:sent`
- `command:new`
- `command:reset`
- `command:stop`
- `gateway:startup`
- `gateway:shutdown`

## Claude Code (planned)

Claude Code supports hooks in `~/.claude/hooks/<name>/`. The hook receives events via stdin. A Claude Code bridge would:
1. Listen for tool calls and status changes
2. Map them to `agentlight set <state>` calls

```bash
# Claude Code hook skeleton (when implemented)
#!/bin/bash
while read event; do
  type=$(echo "$event" | jq -r '.type')
  case "$type" in
    "tool_call") agentlight set thinking --source claude-code --session "$session" ;;
    "tool_result") agentlight set success --source claude-code --session "$session" ;;
  esac
done
```

## GitHub Copilot (planned)

Copilot doesn't have a hook system, but you can watch workspace file changes:

```bash
# File watcher approach (when implemented)
#!/bin/bash
fswatch -o . | while read; do
  agentlight set thinking --source copilot --session "$session"
  sleep 0.5
  agentlight set success --source copilot --session "$session"
done
```

## Contributing

If you want to implement a bridge for another platform, the pattern is:
1. Find how the platform exposes events (hooks, files, stdout, etc.)
2. Map those events to `agentlight set <state>` calls
3. Add installation docs for that platform