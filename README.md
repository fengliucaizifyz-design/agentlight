# AgentLight

**One status light for every AI coding agent.** AgentLight shows — at a glance, in your
macOS menu bar (and optionally on a real WiFi light) — what your agent is doing right now:
idle, working, waiting for your confirmation, or errored.

```
🟢 Idle  ·  🟡 Working  ·  🔵 Confirm  ·  🔴 Error  ·  ⚪️ Offline
```

Works with **Claude Code**, **Codex**, and **OpenClaw** — they all report into one small
local hub, so the color means the same thing no matter which agent you're running.

> **Status:** the hub + menu-bar light + the **Claude Code** and **OpenClaw** adapters are
> verified. The Codex adapter is an experimental draft (depends on your Codex version).
> WLED physical-light output is built in and activates once you point it at a light.

## Easiest install: let your agent do it

You already have an AI coding agent — just tell it to install this. Paste into your agent:

> Read https://github.com/fengliucaizifyz-design/agentlight/blob/main/AGENT-INSTALL.md and follow it for your platform.

The agent reads [AGENT-INSTALL.md](AGENT-INSTALL.md) and sets everything up: builds & starts
the hub, wires its own hooks, and (if you have one) pairs the physical WiFi light. The
manual steps below are for doing it yourself.

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

The OpenClaw adapter posts to `127.0.0.1` with Node's `http` module so local hub updates
are not routed through `HTTP_PROXY` / undici proxy settings.

## State → color

| State | Color | Meaning | Example trigger |
|---|---|---|---|
| `idle`    | 🟢 Green  | Idle / ready / turn finished | session start, response done |
| `working` | 🟡 Amber  | Running / thinking / using a tool | prompt submitted, tool call |
| `confirm` | 🔵 Blue   | Waiting for your approval | permission prompt |
| `error`   | 🔴 Red    | Something failed | tool/command error |
| `offline` | ⚪️ Gray   | Process exited | session end, gateway shutdown |

## Install

### 1. Get & run the hub

**No compiler (prebuilt, recommended):** download the signed, agent-agnostic hub from the
latest [release](https://github.com/fengliucaizifyz-design/agentlight/releases/latest) and
install it to run at login — no Xcode needed:

```bash
git clone https://github.com/fengliucaizifyz-design/agentlight.git
cd agentlight
./scripts/install-release.sh                # hub only — prints the adapter commands
# or wire an agent in one go:  ./scripts/install-release.sh claude-code | codex | openclaw
```

**Build from source** (needs macOS + Xcode Command Line Tools / `swiftc`):

```bash
git clone https://github.com/fengliucaizifyz-design/agentlight.git
cd agentlight/hub
./build.sh
open AgentLight.app
```

Either way it lives in the menu bar (no Dock icon) and has zero third-party dependencies.

> The prebuilt app is **ad-hoc signed, not notarized** (this is a free OSS project with no
> Apple Developer ID). `install-release.sh` clears the download quarantine for you. If you
> ever launch it by hand, the first launch may need a right-click → **Open**, or:
> `xattr -dr com.apple.quarantine AgentLight.app`.

### 2. Connect your agent

The hub treats all agents equally — install the adapter for whichever one(s) you use:

```bash
# Claude Code
./adapters/claude-code/install.sh     # merges hooks into ~/.claude/settings.json (needs jq)
# → then open a new Claude Code session

# OpenClaw
./adapters/openclaw/install.sh        # installs + enables the hook
# → then: openclaw gateway restart

# Codex (experimental)
./adapters/codex/install.sh           # appends hooks to ~/.codex/config.toml
# → then restart Codex and choose "Trust all and continue" if prompted
```

The matching menu-bar light now tracks that agent live. (You can install more than one — the
color means the same thing across all of them.)

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
│   ├── claude-code/             # ✅ verified — hooks snippet + installer
│   ├── codex/                   # 🔜 experimental draft (version-dependent)
│   └── openclaw/                # ✅ verified — hook handler + installer
├── examples/
│   └── demo.html                # browser demo (polls the hub)
├── docs/
│   ├── DESIGN.md                # architecture & decisions
│   ├── hardware.md              # WLED light: what to buy
│   └── cross-platform.md        # how the adapters map events → states
├── scripts/
│   ├── install.sh               # installer: source build, else prebuilt fallback
│   ├── install-release.sh       # installer: prebuilt signed hub (no compiler)
│   ├── install-autostart.sh     # register the login LaunchAgent
│   └── package-release.sh       # maintainer: build universal + sign + zip
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
