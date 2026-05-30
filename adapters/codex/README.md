# Codex adapter (experimental)

Maps [Codex CLI](https://developers.openai.com/codex/) lifecycle hooks to AgentLight states
by POSTing to the local hub (`http://localhost:9527/state`).

> **Status: experimental / draft.** The hub + Claude Code adapter are the verified v1.
> Codex's hook system is newer; **confirm the exact event names and TOML schema against
> your installed Codex version** before relying on this. See
> [Codex Hooks docs](https://developers.openai.com/codex/hooks).

## Enable hooks in Codex

Codex hooks require a feature flag in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

## Event → state mapping

| Codex hook | State |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit`, `PreToolUse` | working |
| `PermissionRequest` | confirm |
| `PostToolUse` (on failure) | error |
| `Stop` / session end | idle / offline |

## Draft config

See [`config-hooks.toml`](config-hooks.toml) for a starting point. Each hook runs a `curl`
that POSTs the state. Merge the relevant blocks into `~/.codex/config.toml` and adjust the
event/command keys to match your Codex version.
