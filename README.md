# AgentLight for OpenClaw

Drive a physical or virtual status LED from [OpenClaw](https://openclaw.ai) agent events — no hardware needed for demos.

## 🌟 What it does

AgentLight makes your AI agent's "thinking" visible:

| Agent state | LED color | When |
|---|---|---|
| 🔵 **Thinking** | Blue (pulsing) | Message received, command running |
| 🟢 **Success** | Green (solid) | Message sent, command done |
| ⚫ **Idle** | Gray (off) | Gateway ready, reset, stop |
| 🔴 **Error** | Red (pulsing) | Command failed |

Works with any OpenClaw agent — main session, CTO, CPO, or any custom agent.

## ⚡ Quick Start

### One-line install:

```bash
curl -sSL https://raw.githubusercontent.com/tifosi/agentlight/main/scripts/install.sh | bash
```

Then restart the gateway:
```bash
openclaw gateway restart
```

That's it. OpenClaw will now call the `agentlight` CLI on every event.

## 📋 Prerequisites

### 1. AgentLight CLI

The hook calls the `agentlight` CLI. Install it first:

```bash
# Check if you have it
agentlight --help

# If not, install it (Go required):
go install github.com/tifosi/agentlight/cmd/agentlight@latest
```

### 2. OpenClaw gateway running

```bash
openclaw gateway status   # should show "running"
```

## 🔧 Installation (detailed)

### Option A: One-liner (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/tifosi/agentlight/main/scripts/install.sh | bash
```

### Option B: From git clone

```bash
git clone https://github.com/tifosi/agentlight.git
cd agentlight
./scripts/install.sh
```

### Option C: Manual

```bash
# 1. Copy hook files
mkdir -p ~/.openclaw/hooks/agentlight
cp -r openclaw/hooks/agentlight/* ~/.openclaw/hooks/agentlight/

# 2. Enable the hook
openclaw hooks enable agentlight

# 3. Restart gateway
openclaw gateway restart
```

## 🖥️ Demo Mode (no hardware needed)

The hook runs in **demo mode** by default — it writes state to a JSON file instead of sending to USB. No hardware required to see it work.

Start a local web server:
```bash
cd ~/.openclaw/workspace
python3 -m http.server 8080
```

Open in browser: [http://localhost:8080/examples/agentlight-state.json](http://localhost:8080/examples/agentlight-state.json)

Or open the full demo page:
```bash
open http://localhost:8080/examples/demo.html
```

You'll see a colored circle that pulses and changes in real-time as OpenClaw events fire.

## 💡 Manual State Control

```bash
agentlight set thinking --source openclaw --session my-task --demo
agentlight set success  --source openclaw --session my-task --demo
agentlight set error    --source openclaw --session my-task --demo
agentlight reset        --demo
```

## 🔌 Hardware Mode (real LED)

When AgentLight hardware is connected via USB, the hook automatically drives the physical LED — no config change needed.

```
agentlight set thinking   → blue LED
agentlight set success    → green LED
agentlight set idle       → off
agentlight set error      → red LED (pulsing)
```

See [docs/hardware.md](docs/hardware.md) for build instructions.

## 📁 Project Structure

```
agentlight/
├── README.md
├── SKILL.md                    ← ClawHub skill format
├── LICENSE                     ← MIT-0
├── openclaw/
│   └── hooks/
│       └── agentlight/
│           ├── HOOK.md          ← Hook metadata
│           └── handler.ts       ← Event handler
├── scripts/
│   └── install.sh              ← One-command installer
└── examples/
    ├── demo.html                ← Browser demo
    └── agentlight-state.json    ← Demo state file
```

## 🤖 Cross-Platform Support

This repo focuses on OpenClaw. For other AI coding agents:

| Platform | Status | Notes |
|---|---|---|
| **OpenClaw** | ✅ Native | Internal hook system |
| **Claude Code** | 🔜 Planned | File-watching bridge |
| **GitHub Copilot** | 🔜 Planned | Via workspace events |

See [docs/cross-platform.md](docs/cross-platform.md) for details.

## ❓ Uninstall

```bash
openclaw hooks disable agentlight
rm -rf ~/.openclaw/hooks/agentlight
openclaw gateway restart
```

## 📜 License

[MIT-0](LICENSE) — free to use, modify, and redistribute. No attribution required.

---

Built with 🏎️ by [Tifosi](https://github.com/tifosi) — [Report a bug](https://github.com/tifosi/agentlight/issues)