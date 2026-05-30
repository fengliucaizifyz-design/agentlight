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

## Alternative: `notify` (older / more widely available, but limited)

Older Codex builds (and some current ones) don't have the `[hooks]` system — they only
support a single `notify` program that fires on `turn-ended`:

```toml
notify = ["/path/to/agentlight-notify.sh", "turn-ended"]
```

Limitations:

- **Only fires at turn end** → you can really only signal `idle` (turn done). You don't
  get `working` / `confirm` / `error` from `notify` alone.
- **`notify` is a single slot.** If you already use it (e.g. a desktop notifier or a
  computer-use client), setting it here **overwrites** that. Don't clobber it — instead
  point `notify` at a small wrapper script that calls your existing program *and* POSTs to
  the hub:

  ```bash
  #!/bin/bash
  # agentlight-notify.sh
  "/path/to/your/existing/notifier" "$@"   # keep your current behavior
  curl -s -m 1 -o /dev/null -X POST http://localhost:9527/state \
    -H 'Content-Type: application/json' -d '{"state":"idle","source":"codex"}'
  ```

Prefer the `[hooks]` config above when your Codex version supports it — it gives the full
five states. Use `notify` only as a fallback.
