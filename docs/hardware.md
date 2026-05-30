# Physical Light Guide (WLED)

AgentLight drives a real light over your LAN using [WLED](https://kno.wled.ge/) — a free,
open-source firmware that runs on cheap ESP32/ESP8266 boards and exposes a simple local
HTTP/JSON API. No cloud, no account, no soldering required if you buy a ready-made unit.

## Why WLED

The hub controls the light by sending one HTTP request per state change:

```
POST http://<WLED_IP>/json/state
{"on": true, "bri": 160, "seg": [{"col": [[R, G, B]]}]}
```

That's the whole integration. Any WLED device on the same network works — no per-device
protocol, no vendor lock-in. Smart bulbs (Mi/Tuya/etc.) are intentionally *not* used: their
APIs vary, often require the cloud, and can be locked down by the vendor.

## What to buy

The cheapest reliable path is an **ESP32/ESP8266 + WS2812B/SK6812 RGB light, flashed with
WLED**. On Taobao/AliExpress, search **“WLED 灯” / “WLED ESP32 ambient light”** — many
sellers ship units **pre-flashed**, so setup is just Wi-Fi onboarding.

Requirements checklist when buying:

- Controller: **ESP32 or ESP8266**, **2.4 GHz Wi-Fi**.
- LEDs: WS2812B or SK6812 addressable RGB (a few LEDs or a ring — anything that changes
  color as a whole is fine).
- Firmware: **WLED (latest stable), JSON API enabled** (it is by default).
- Onboarding: WLED's built-in Wi-Fi AP setup (connect to its hotspot, enter your Wi-Fi).
- Power: USB Type-C with cable.
- Optional: a frosted diffuser for a softer glow.

Typical cost: about ¥30–100.

## Setup

1. Power the light. Connect your phone to its Wi-Fi hotspot and join it to your 2.4 GHz
   network (WLED's standard onboarding).
2. Find its LAN IP (your router's client list, or the WLED app). Confirm you can open
   `http://<IP>/` in a browser and see the WLED control page.
3. In the AgentLight menu bar, choose **“Set Physical Light (WLED) IP…”** and enter the IP.

State changes now mirror to the light. If the light is off or unreachable, the hub silently
skips it — the menu-bar light is unaffected.

## Colors

| State | RGB |
|---|---|
| `idle`    | (0, 200, 0)    |
| `working` | (255, 180, 0)  |
| `confirm` | (0, 120, 255)  |
| `error`   | (255, 0, 0)    |
| `offline` | off            |

## Roadmap

- Brightness "breathing" for `working` / `confirm` / `error` (pulse effect on the light).
- Bluetooth (BLE) light support as an alternative to Wi-Fi.
