# Adapters: mapping agent events → states

AgentLight decouples *inputs* (agents) from *outputs* (menu bar, WLED) via the hub. Each
agent only needs to translate its lifecycle events into one of the five canonical states
and `POST` it to `http://localhost:9527/state`. Adding a new agent = writing one adapter.

```
agent events ──(translate)──► POST localhost:9527/state ──► hub ──► lights
```

## Status

| Agent | Mechanism | Status |
|---|---|---|
| **Claude Code** | hooks in `settings.json` → `curl` | ✅ verified |
| **OpenClaw** | internal hook handler (`handler.ts`) → `fetch` | ✅ verified |
| **Codex** | `[hooks]` or `notify` in `~/.codex/config.toml` → `curl` | 🔜 experimental (version-dependent) |

## Canonical states

`idle` · `working` · `confirm` · `error` · `offline` — see the README for colors.

## Claude Code (`adapters/claude-code/`)

Maps Claude Code hook events to states:

| Hook event | State |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit`, `PreToolUse` | working |
| `Notification` (permission) | confirm |
| `Stop` | idle |
| `SessionEnd` | offline |

Each hook is a `curl` POST. Install with `adapters/claude-code/install.sh` (merges the
snippet into a `settings.json`).

## Codex (`adapters/codex/`)

Codex's hook system (`[hooks]` in `~/.codex/config.toml`, enabled with
`[features] codex_hooks = true`) exposes events comparable to Claude Code:

| Hook event | State |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit`, `PreToolUse` | working |
| `PermissionRequest` | confirm |
| `PostToolUse` (failure) | error |
| `Stop` / session end | idle / offline |

Exact event names should be confirmed against your installed Codex version.

## OpenClaw (`adapters/openclaw/`)

An internal hook handler (`handler.ts`) that `fetch`es the hub. See
[adapters/openclaw/HOOK.md](../adapters/openclaw/HOOK.md) for the event mapping. OpenClaw
has no permission-confirmation event, so `confirm` is not triggered there.

## Writing a new adapter

1. Find how the platform exposes lifecycle events (hooks, config, files, stdout…).
2. Translate each event to a canonical state.
3. `POST {"state": "...", "source": "<agent>"}` to `http://localhost:9527/state`.
