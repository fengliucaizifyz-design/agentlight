# Codex adapter

Maps Codex lifecycle hooks to AgentLight states by POSTing to the local hub
(`http://localhost:9527/state`) with `source: "codex"`.

This adapter was verified on macOS with Codex CLI/TUI v0.135.0-alpha.1. Codex hooks are
enabled by default in this version; the old `codex_hooks` feature flag is deprecated. See
the [Codex Hooks docs](https://developers.openai.com/codex/hooks).

Codex Desktop uses an app-server process for normal desktop chat sessions. As of the
version tested here, the public hooks docs describe CLI/TUI hook loading and trust review,
but do not explicitly guarantee that every Codex Desktop app-server conversation executes
the same `~/.codex/config.toml` hooks. Treat Desktop support as something to verify on the
target machine after install.

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

First verify the hook script directly:

```bash
~/.codex/hooks/agentlight-state.sh working
curl -s http://localhost:9527/state
```

The response should include:

```json
{"state":"working","source":"codex"}
```

Then verify Codex CLI/TUI hooks by running a tool from a fresh Codex session. During work,
the hub should include `working`; after the turn stops it should return to:

```json
{"state":"idle","source":"codex"}
```

The helper also writes a tiny debug log:

```bash
tail -f ~/.codex/hooks/agentlight.log
```

## Codex Desktop note

If the direct script test works and `codex exec` or the Codex TUI triggers log entries, but
ordinary Codex Desktop chats do not add entries to `~/.codex/hooks/agentlight.log`, the
Desktop app-server path is not executing this hook configuration on that machine.

Things to try:

1. Fully quit Codex Desktop and restart it. If a persistent `codex app-server` process
   remains, quit or restart that process too, then reopen Codex.
2. Open a Codex TUI session once and trust hooks with `/hooks` or the startup prompt.
3. Start a brand-new Desktop chat and run a tool. Watch
   `~/.codex/hooks/agentlight.log`.

If Desktop still does not trigger the hook, do not keep reinstalling this adapter. The next
stable approach should be a separate Desktop/app-server adapter that listens to app-server
events such as `turn/started`, `turn/completed`, `item/*`, and `error`, then POSTs the same
AgentLight states to the hub.
