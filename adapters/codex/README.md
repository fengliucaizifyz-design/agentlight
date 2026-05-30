# Codex adapter

Maps Codex lifecycle hooks to AgentLight states by POSTing to the local hub
(`http://localhost:9527/state`) with `source: "codex"`.

This adapter was verified on macOS with Codex v0.135.0-alpha.1. Codex hooks are enabled by
default in this version; the old `codex_hooks` feature flag is deprecated. See the
[Codex Hooks docs](https://developers.openai.com/codex/hooks).

## Install

```bash
~/agentlight/adapters/codex/install.sh
```

The installer:

- copies `agentlight-state.sh` to `~/.codex/hooks/agentlight-state.sh`
- appends the verified hook block from `config-hooks.toml` to `~/.codex/config.toml`
- preserves existing Codex settings, including any existing `notify = [...]`

After installing, restart Codex or open a new Codex session. If Codex shows **"Hooks need
review"**, choose **"Trust all and continue"**. In the Codex TUI you can also run `/hooks`
to review and trust hooks.

## Event → state mapping

| Codex hook | State |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit`, `PreToolUse` | working |
| `PermissionRequest` | confirm |
| `PostToolUse` | working |
| `Stop` | idle |

Important: in Codex, `Stop` means the current turn has stopped, not that the whole Codex app
has quit. Mapping `Stop` to `offline` makes the light turn gray after every answer. The
verified behavior is yellow while Codex works, then green when the turn is done.

## Manual install

If you do not want to run the installer, copy `agentlight-state.sh` to:

```bash
mkdir -p ~/.codex/hooks
cp ~/agentlight/adapters/codex/agentlight-state.sh ~/.codex/hooks/
chmod +x ~/.codex/hooks/agentlight-state.sh
```

Then append the contents of [`config-hooks.toml`](config-hooks.toml) to
`~/.codex/config.toml`.

Do not replace `~/.codex/config.toml`, and do not remove or overwrite an existing
`notify = [...]` entry. Codex `notify` is separate from hooks and may already be used by
other integrations such as computer-use.

## Verify

Use Codex to run a tool, then read the hub:

```bash
curl -s http://localhost:9527/state
```

During work it should include:

```json
{"state":"working","source":"codex"}
```

After the turn stops it should return to:

```json
{"state":"idle","source":"codex"}
```
