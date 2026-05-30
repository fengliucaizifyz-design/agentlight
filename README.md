# AgentLight

**One status light for every AI coding agent.** AgentLight shows — at a glance, in your
macOS menu bar (and optionally on a real WiFi light) — what your agent is doing right now:
idle, working, waiting for your confirmation, or errored.

```
🟢 Idle  ·  🟡 Working  ·  🔵 Confirm  ·  🔴 Error  ·  ⚪️ Offline
```

Works with **Claude Code**, **Codex**, and **OpenClaw** — they all report into one small
local hub, so the color means the same thing no matter which agent you're running.

> **Status:** v1 ships the hub + menu-bar light + the **Claude Code** adapter (verified).
> Codex and OpenClaw adapters are included as experimental and being finished next.
> WLED physical-light output is built in and activates once you point it at a light.

## How it works

```
   Inputs (hooks)                Hub (one macOS app)              Outputs
 Claude Code ─┐
 Codex       ─┼─→ POST localhost:9527/state ─→ state machine ─┬─→ menu-bar light
 OpenClaw    ─┘        {"state":"working"}      + colors       ├─→ WLED light (LAN HTTP)
                                                               └─→ demo web page
```

Each agent's lifecycle hooks `POST` a state to a local HTTP server on `:9527`. The hub
renders it in the menu bar and, if you've set a WLED light's IP, pushes the matching color
to it over your LAN. No cloud, no account, no external CLI.

## State → color

| State | Color | Meaning | Example trigger |
|---|---|---|---|
| `idle`    | 🟢 Green  | Idle / ready / turn finished | session start, response done |
| `working` | 🟡 Amber  | Running / thinking / using a tool | prompt submitted, tool call |
| `confirm` | 🔵 Blue   | Waiting for your approval | permission prompt |
| `error`   | 🔴 Red    | Something failed | tool/command error |
| `offline` | ⚪️ Gray   | Process exited | session end, gateway shutdown |

## Install

### 1. Build & run the hub

```bash
git clone https://github.com/fengliucaizifyz-design/agentlight.git
cd agentlight/hub
./build.sh
open AgentLight.app
```

It lives in the menu bar (no Dock icon). Requires macOS + Xcode Command Line Tools
(`swiftc`). The built binary has zero third-party dependencies.

### 2. Connect Claude Code

```bash
cd agentlight/adapters/claude-code
./install.sh                 # merges hooks into ~/.claude/settings.json (needs jq)
# or target a project:  ./install.sh /path/to/project/.claude/settings.json
```

Start a Claude Code session — the menu-bar light now tracks it live.

### 3. (Optional) Connect a physical WiFi light

Buy any WiFi RGB light running [WLED](https://kno.wled.ge/) firmware (cheap, common).
In the AgentLight menu, choose **“Set Physical Light (WLED) IP…”** and enter its LAN IP.
That's it — colors mirror to the light. See [docs/hardware.md](docs/hardware.md) for what
to buy.

## Demo (no hardware needed)

With the hub running:

```bash
cd agentlight/examples
python3 -m http.server 8099
open http://localhost:8099/demo.html
```

A colored circle follows the live state — handy for testing your hooks.

## Manual control / health check

```bash
# set a state
curl -s -X POST http://localhost:9527/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"working","source":"claude-code","detail":"Running tests"}'

# read current state
curl -s http://localhost:9527/state
```

## Project structure

```
agentlight/
├── hub/                         # macOS menu-bar app: HTTP hub + state machine + WLED
│   ├── main.swift
│   ├── build.sh
│   └── AgentLight.app/
├── adapters/                    # one input adapter per agent
│   ├── claude-code/             # ✅ v1 — hooks snippet + installer
│   ├── codex/                   # 🔜 experimental
│   └── openclaw/                # 🔜 experimental — hook handler
├── examples/
│   └── demo.html                # browser demo (polls the hub)
├── docs/
│   ├── DESIGN.md                # architecture & decisions
│   ├── hardware.md              # WLED light: what to buy
│   └── cross-platform.md        # how the adapters map events → states
├── scripts/install.sh           # convenience installer (build hub + Claude Code)
├── SKILL.md                     # OpenClaw ClawHub skill descriptor
└── LICENSE                      # MIT-0
```

## HTTP API

`POST /state` — body: `{"state": "...", "source": "...", "detail": "..."}` (`state`
required, one of the five above; `source` one of `claude-code|codex|openclaw`; `detail`
optional tooltip text). `GET /state` — returns the current state as JSON (CORS-enabled,
used by the demo page).

## License

[MIT-0](LICENSE) — free to use, modify, and redistribute. No attribution required.
