# AgentLight — screen firmware (Pro Max)

Turns an **ESP32-S3 + ST7789 240×240 TFT** into an AgentLight physical light.

This is the **Pro Max** output device. Like the Pro tier's WLED light, it shows the
agent state as a **solid colour** — but on a screen, so it can later grow into faces /
animations. To avoid touching the hub, the firmware **emulates the small slice of the
WLED JSON API** the hub already speaks, so the screen drops straight into the existing
"Physical Light" pipeline.

```
Claude / Codex / OpenClaw ──hooks──▶ AgentLight hub (Mac) ──HTTP──▶ this screen
                                       (unchanged)        LAN       fills colour
```

| State | Colour (set by the hub) |
|---|---|
| idle | green |
| working | amber |
| confirm | blue |
| error | red |
| offline | off (black) |

## Pin map (ESP32-S3 GPIO ↔ screen)

These pins come from the **target box's own schematic** (a sealed "S3 weather" unit;
the screen is pre-wired inside). For a *different* board, read its schematic and update
`platformio.ini` — the firmware is otherwise hardware-agnostic.

| Screen signal | GPIO |
|---|---|
| LCD_SDA (MOSI) | **IO1** |
| LCD_SCL (SCK) | **IO18** |
| LCD_DC | **IO17** |
| LCD_RESET | **IO6** |
| LCD_BL (backlight) | **IO2** — **active-LOW** (P-MOSFET high-side switch) |
| LCD_CS | tied low inside the panel — **not used** (omit `TFT_CS`) |

> The SPI port is forced to **HSPI** (`-D USE_HSPI_PORT`): on this IDF the S3 default (FSPI)
> makes TFT_eSPI compute a null SPI register base and crash in `tft.init()`.

## Build & flash (PlatformIO)

The whole TFT_eSPI config lives in `platformio.ini` as build flags — no library files are
hand-edited.

```bash
cd firmware/agentlight-screen
pio run                 # compile
pio run -t upload       # flash (board on USB)
pio device monitor      # serial logs @115200
```

Arduino IDE alternative: open `agentlight-screen.ino`, install **TFT_eSPI**, **ArduinoJson**,
**WiFiManager**, select *ESP32S3 Dev Module*, and replicate the `build_flags` from
`platformio.ini` in `User_Setup.h`.

## First run — Wi-Fi setup

The screen shows on-device instructions (Chinese), guiding the user to:

1. **连接下方热点** — join the `AgentLight-XXXX` hotspot the device broadcasts
2. **打开弹出页面** — open the captive portal that pops up
3. **输入网络密码** — pick their Wi-Fi and enter the password

Credentials are stored on-device. Move to a new location and it can't connect? It reopens
the setup hotspot automatically — no re-flashing.

> If valid Wi-Fi credentials are already in flash (e.g. a repurposed device that was
> previously online), WiFiManager reuses them and **connects silently — no hotspot, no
> portal**. That's expected; just find its IP (above) and point the hub at it.

### On-screen Chinese text

TFT_eSPI's built-in fonts are ASCII-only, so the Chinese lines are pre-rendered to 1-bit
bitmaps in `zh_assets.h`. The SSID/IP stay ASCII (built-in font). To change the wording,
edit `tools/gen_zh_assets.py` and regenerate:

```bash
uvx --with pillow python3 tools/gen_zh_assets.py    # rewrites zh_assets.h
```

## Connect it to the hub

1. Find the screen's LAN IP (it advertises mDNS as `agentlight.local`; resolve it with
   `dns-sd -G v4 agentlight.local`).
2. In the AgentLight menu bar → **"Set Physical Light (WLED) IP…"** → enter that **IP**.

Now the screen colour follows your agent live.

```bash
# Manual sanity check (amber). Use the IP; add --noproxy if you run a local proxy:
curl --noproxy '*' -s -X POST http://<screen-ip>/json/state \
  -H 'Content-Type: application/json' \
  -d '{"on":true,"bri":200,"seg":[{"col":[[255,180,0]]}]}'
```

> **Use the IP, not `agentlight.local`, for now.** macOS's resolver (and URLSession) often
> times out on `.local` mDNS names, so the hub's pushes to `agentlight.local` fail
> intermittently. The raw IP is reliable. Making mDNS robust (or resolving it inside the hub)
> is a product-stage TODO.
>
> If you run a LAN proxy (Clash/Surge), the hub bypasses it for the light push — the WLED
> output uses a proxy-free `URLSession`. Plain `curl` needs `--noproxy '*'`.

## Tuning (first flash often needs one of these)

- **Colours inverted** (whites look black): remove `-D TFT_INVERSION_ON=1` from `platformio.ini`.
- **Mirrored / rotated**: change `tft.setRotation(0)` (try 0–3) in the `.ino`.
- **1–2 px edge offset / colour fringe**: 240×240 panels vary; adjust the ST7789 CGRAM offset.
- **Snow / garbage**: wiring doesn't match the pin map above.

## Roadmap (not in this demo)

- A proper AgentLight protocol carrying the **state name** (so the screen can show distinct
  faces, not just colours) alongside the WLED-compat endpoint.
- Brightness "breathing" for working/confirm/error.
- Own enclosure + own expression art + own branding for the sellable product
  (the Clawd Mochi shell is CC BY-NC-SA / non-commercial; its mascot is Anthropic's).
