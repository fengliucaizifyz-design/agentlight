# Hardware Build Guide

This doc explains how to build a physical AgentLight LED unit.

## Overview

```
agentlight CLI  ←  OpenClaw hook
      │
      │ USB (HID)
      ▼
  Arduino/ESP32
      │
      │ GPIO
      ▼
  RGB LED or WS2812 strip
```

## Hardware Options

### Option A: Arduino Leonardo (simplest)

**Parts:**
- Arduino Leonardo (or Pro Micro)
- 3× LEDs: red, green, blue (or 1× RGB LED common cathode)
- 3× 220Ω resistors
- Breadboard + wires

**Wiring:**
```
Arduino Pin 2 → 220Ω → Red LED → GND
Arduino Pin 3 → 220Ω → Green LED → GND
Arduino Pin 4 → 220Ω → Blue LED → GND
```

**Firmware:** Use AgentLight's Arduino HID firmware. Flash it via Arduino IDE.

### Option B: ESP32 (WiFi)

**Parts:**
- ESP32 DevKit
- WS2812B RGB LED strip (e.g., 3 LEDs)
- 5V power supply

**Why ESP32:** No USB cable needed — the hook sends commands over WiFi.

### Option C: USB + Python (lightweight)

If you have a USB-to-serial adapter:

```bash
pip install agentlight[hardware]
agentlight serve --device /dev/ttyUSB0
```

This runs a background server that listens for agentlight commands and drives LEDs over serial.

## AgentLight CLI Modes

| Mode | Flag | Description |
|---|---|---|
| Demo | `--demo` | Writes state to JSON file |
| USB | (default, no flag) | Sends to hardware via USB HID |
| Serial | `--serial /dev/ttyX` | Sends over serial port |

## Customization

### Custom LED states

Edit `openclaw/hooks/agentlight/handler.ts` to map events differently:

```typescript
const STATE_MAP: Record<string, string> = {
  "message:received": "thinking",
  "message:sent":     "success",
  "command:new":      "running",  // changed from "thinking"
  "command:reset":    "idle",
  "command:stop":     "idle",
  "gateway:startup":  "idle",
  "gateway:shutdown": "idle",
};
```

Rebuild: just copy the updated `handler.ts` to `~/.openclaw/hooks/agentlight/`.

### Custom animations

The AgentLight firmware supports custom animation sequences. See the firmware source for details.