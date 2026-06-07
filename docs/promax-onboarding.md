# AgentLight Pro Max — onboarding & setup design

> Status: **agreed design baseline for the friends/family test phase.** Runtime is built;
> the "setup segment" below is the new work.

## Summary

Pro Max is a **wireless, battery-powered desk screen** that mirrors your AI agent's state
(working / waiting / error / idle). Setup is driven by the user's **own AI agent** over a
temporary USB connection; at runtime the screen is **wireless (WiFi)**.

For the user: **one short phrase + two clicks.** No app download, no QR, no captive portal,
no IP entry, no WiFi password typed.

## Product context

- Three tiers: **Lite** (menu-bar light only) · **Pro** (+ WLED light) · **Pro Max** (+ this screen).
- Audience: developers who already run **Claude Code / Codex / OpenClaw** (that's *why* they want it).
- Sold as: pre-flashed hardware; the user's agent installs the Mac-side hub.

## The key model: two channels

| Channel | When | Used for |
|---|---|---|
| **USB** | setup only (a few minutes) | agent ↔ device serial: read identity, write WiFi creds |
| **WiFi** | runtime (always) | hub auto-discovers the screen (mDNS) and pushes color over LAN |

Why USB is *not* used at runtime: Mac USB-C ports are scarce; the device is meant to be
**carried** (battery); a permanent cable clutters the desk. So USB is the "setup wand"; the
screen then runs untethered on WiFi.

## Locked user flow

```
① 开箱
   │ [user] plug screen into Mac via USB
② screen lights up (USB power), shows:
     已连接 ✓ / 跟你的 AI 助手说: 「读取并设置我刚插上的 USB 设备」 / (详见说明卡)
   │ [user] paste that one phrase into Claude Code / Codex / OpenClaw
③ agent auto-installs:
     • scans USB serial, identifies the device (self-announce banner)
     • builds + installs the hub locally; installs ITS OWN adapter
④ WiFi (near-zero input):
     • agent reads current Mac SSID; pulls its password from Keychain → [user] clicks "Allow"
     • "Connect screen to HomeNet?" → [user] clicks "Use this"  (5G/wrong → "Pick another")
     • agent writes creds to the device over serial → device joins WiFi
⑤ screen shows: ✓ 配置完成 / 已连上 HomeNet / 可插线,也可拔线随身用 🔋
   │ [user] unplug USB, power via power bank / battery
⑥ normal use (wireless): hub auto-discovers over WiFi → pushes color
     🟡 working  🔵 confirm  🔴 error  🟢 idle   — follows the agent, carry it within the WiFi
```

**User actions total:** 1 phrase typed + 2 clicks (Allow, Use-this) + plug/unplug.

## Trigger phrase (locked)

```
读取并设置我刚插上的 USB 设备
```

- Phrased as an **action** (read → configure) + a **clear location** (just-plugged USB) so a
  capable agent does the right thing without guessing.
- No brand name (TBD) and no URL — the **device self-describes** what to do.
- **On screen:** minimal reminder only (small display). **Quick-start card** carries the full
  phrase + which-agent + steps.

## Already built (runtime — done & verified)

- **Firmware:** TFT display, WiFiManager connect, mDNS `_agentlight._tcp`, HTTP `/json/state`
  (WLED-compatible subset), solid-color render. Pins for the test unit are in `platformio.ini`.
- **Hub:** state machine, menu-bar dot, proxy-bypassed WLED push, mDNS auto-discovery
  (generation-token, latched IP), Claude Code / OpenClaw / Codex adapters.

→ Once the device has WiFi creds, runtime "auto-discover + push color" already works.

## New work — the "setup segment"

### Slice 1 — firmware serial config protocol  *(do first; testable without the agent)*
- **Self-announce:** continuously print a banner on serial, e.g.
  `AGENTLIGHT id=<hex> proto=1` (may also carry a setup hint), so the agent can enumerate
  ports and confirm the right device even if other USB gear is attached.
- **Accept WiFi creds:** a line command (e.g. `WIFI <ssid> <pass>` or JSON) → save → connect →
  reply `OK <ip>` / `FAIL <reason>`.
- **Test:** drive the serial port from a script → device joins WiFi + shows up in mDNS.
  Proves USB provisioning independent of any agent. This is the keystone.

### Slice 2 — setup-mode screen states
- No creds → setup screen: the trigger phrase + "see card" (minimal).
- Provisioning → "正在连接…".
- Connected → "✓ 配置完成 / 可拔线随身用" → transition to normal display.
- Reuse the Chinese-bitmap text pipeline (`tools/gen_zh_assets.py`).

### Slice 3 — agent install procedure  *(upgrade `AGENT-INSTALL.md` / optional skill)*
On the trigger phrase, the agent:
1. **Find the device** — enumerate `/dev/cu.usb*`, read the self-announce banner, pick the AgentLight one.
2. **Install the hub locally** — clone + `swiftc` build (local build ⇒ no Apple notarization
   needed) — and install the agent's **own** adapter (it knows which agent it is).
3. **WiFi with near-zero typing** — get the current Mac SSID; read its password from Keychain
   (`security find-generic-password -wa <SSID>` → macOS "Allow" prompt); confirm
   "use this / pick another" (escape hatch for 5G-only or split 2.4/5 SSIDs).
4. **Provision** — write creds to the device over serial; wait for `OK <ip>`.
5. **Done** — tell the user they can unplug. The hub then auto-discovers over WiFi.
- **Test:** end-to-end on the current unit via Claude Code (plug → phrase → configured →
  unplug → power bank → screen follows).

### Slice 4 — polish
Error handling (wrong password, 5G-only, port not found), the "pick another WiFi" branch, copy.

## Boundaries / deferred

- **Security / trust** (prompt-injection, device-supplied addresses): **deferred** — test is
  friends/family only. Revisit before any commercial release (then: instructions come from a
  pinned official source; device supplies data only).
- **USB Mass Storage** ("device as a drive" for cleaner reads): deferred — serial suffices and
  is needed anyway for the WiFi *write*.
- **Battery + charging circuit:** product hardware TODO; test with a power bank / wall USB.
- **Cross-network ("anywhere"):** needs a cloud relay. Today the hub pushes over LAN, so
  "carry it" works **within the same WiFi** (e.g. a meeting room), not off-network.
- **Brand name / enclosure / expression art:** separate product workstreams (faces vs the
  current colour-only display; own shell since the Clawd Mochi shell is non-commercial).

## Open decision

How a brand-new user's agent learns the *procedure*: (a) the phrase/device points to an
official instructions URL, or (b) testers get a small Claude Code skill so the phrase stays
short. **Test phase:** the device self-describes (security deferred) — the banner carries the
setup hint, so the user's phrase needs neither a URL nor a pre-installed skill.
