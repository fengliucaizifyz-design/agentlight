/*
 * AgentLight — screen firmware (Pro Max output device)
 * ============================================================================
 * Turns an ESP32-S3 + ST7789 240x240 TFT into an AgentLight physical light.
 *
 * DEMO BEHAVIOUR (this version): the screen fills with a SOLID COLOUR that
 * mirrors the agent state, exactly like the WLED light in the "Pro" tier. To
 * keep the hub unchanged, the firmware emulates the small subset of the WLED
 * JSON API the hub already speaks:
 *
 *     POST http://agentlight.local/json/state
 *     {"on": true, "bri": 160, "seg": [{"col": [[R, G, B]]}]}
 *
 * So in the hub menu you just set "Physical Light (WLED) IP" = agentlight.local
 * and the screen tracks your agent — no hub code changes.
 *
 * WiFi: provisioned over USB serial by the user's AI agent during setup (the
 * agent writes the creds; see docs/promax-onboarding.md). Credentials persist
 * on-device, so it reconnects on its own afterwards — runs wireless on battery.
 * The device self-announces on serial so the agent can find it.
 *
 * Faces/animation are intentionally OUT OF SCOPE for now — solid colour aligns
 * with the project's existing state→colour model and is trivial to extend later.
 * ============================================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>     // v7
#include <TFT_eSPI.h>
#include "zh_assets.h"       // pre-rendered Chinese line bitmaps (gen by tools/)
#include "mascot_assets.h"   // RGB565 mascot sprites per state (gen by tools/)

// ---- config ----------------------------------------------------------------
static const char*    MDNS_HOST = "agentlight";  // -> http://agentlight.local
static const uint16_t HTTP_PORT = 80;
// Where the agent should read the setup procedure (self-describing; test phase —
// no signing/trust yet). Advertised in the serial banner.
static const char*    SETUP_URL = "https://github.com/fengliucaizifyz-design/agentlight";

// ---- globals ---------------------------------------------------------------
TFT_eSPI    tft = TFT_eSPI();
TFT_eSprite faceSpr = TFT_eSprite(&tft);   // off-screen buffer for flicker-free animation
bool        sprReady = false;
WebServer server(HTTP_PORT);

// Last colour the hub asked for (kept so we can redraw / breathe later).
uint8_t curR = 0, curG = 0, curB = 0, curBri = 255;
bool    curOn = false;

// Lifecycle / serial state.
bool          servicesStarted = false;   // mDNS + HTTP server started once
bool          wasConnected = false;      // edge-detect WiFi connect/drop
bool          justProvisioned = false;   // set by a serial wifi cmd -> show "done"
unsigned long lastBanner = 0;            // self-announce throttle
unsigned long bootMs = 0;                // boot time; hold setup screen briefly
String        serialLine;                // accumulates one serial command line

static const unsigned long SETUP_DWELL_MS = 5000;  // min time the setup screen shows at boot

// 4-hex device id from the MAC, e.g. "9CF5".
String deviceId() {
  char buf[8];
  snprintf(buf, sizeof(buf), "%04X", (uint16_t)(ESP.getEfuseMac() & 0xFFFF));
  return String(buf);
}

// ---- helpers ---------------------------------------------------------------

// A per-device suffix from the MAC, e.g. "AgentLight-9CF5".
String apName() {
  uint16_t tail = (uint16_t)(ESP.getEfuseMac() & 0xFFFF);
  char buf[16];
  snprintf(buf, sizeof(buf), "AgentLight-%04X", tail);
  return String(buf);
}

// ---- character eyes (the desktop companion's face) -------------------------
// The on-screen personality: state colour as the background + a pair of eyes
// expressing the state. We map the hub's colour back to a state, so no hub
// change / new protocol is needed for this demo.
enum { EX_NONE, EX_IDLE, EX_WORKING, EX_CONFIRM, EX_ERROR, EX_OFFLINE };  // anon -> int
int           curExpr = EX_NONE;
unsigned long lastFrame = 0;     // animation frame throttle

int mapColorToExpr(uint8_t r, uint8_t g, uint8_t b) {
  if (r == 0 && g == 0 && b == 0)      return EX_OFFLINE;
  if (g >= 150 && r <= 80)             return EX_IDLE;     // green
  if (b >= 150 && r <= 80)             return EX_CONFIRM;  // blue
  if (r >= 180 && g >= 100 && b <= 90) return EX_WORKING;  // amber
  if (r >= 150 && g <= 80 && b <= 80)  return EX_ERROR;    // red
  return EX_IDLE;
}

// Draw the mascot once, floating down by `bob` px. Uses the off-screen sprite
// (flicker-free) when available, else a direct draw.
void drawFaceFrame(int bob) {
  int e = curExpr;
  if (sprReady) {
    faceSpr.fillSprite(MASCOT_BG[e]);
    faceSpr.pushImage(0, bob, MASCOT_W, MASCOT_H, (uint16_t *)MASCOT_IMG[e], (uint16_t)MASCOT_KEY);
    faceSpr.pushSprite(0, 0);
  } else {
    tft.fillScreen(MASCOT_BG[e]);
    tft.pushImage(0, bob, MASCOT_W, MASCOT_H, (uint16_t *)MASCOT_IMG[e], (uint16_t)MASCOT_KEY);
  }
}

// Switch expression: pale state-colour bg + the mascot.
void setExpr(int e, uint16_t bg) {
  curExpr = e;
  if (e <= EX_NONE || e > EX_OFFLINE) { tft.fillScreen(TFT_BLACK); return; }
  drawFaceFrame(0);
}

// Per-frame gentle float (~±4px, ~4.4s period). Needs the sprite to be smooth;
// no-op without it or when a non-mascot screen is showing.
void animateFace() {
  if (!sprReady || curExpr <= EX_NONE || curExpr > EX_OFFLINE) return;
  if (millis() - lastFrame < 50) return;
  lastFrame = millis();
  int bob = (int)lroundf(4.0f + 4.0f * sinf(millis() / 700.0f));   // 0..8 px
  drawFaceFrame(bob);
}

void paint(uint8_t r, uint8_t g, uint8_t b, uint8_t bri, bool on) {
  curR = r; curG = g; curB = b; curBri = bri; curOn = on;
  int e = on ? mapColorToExpr(r, g, b) : EX_OFFLINE;
  if (e != curExpr) setExpr(e, 0);   // repaint only when the state changes
}

// Draw a pre-rendered Chinese line bitmap, horizontally centred, top at y.
void zhLine(const uint8_t* bmp, int w, int h, int y, uint16_t color) {
  tft.drawBitmap((240 - w) / 2, y, bmp, w, h, color);
}

// Setup-mode screen (shown until WiFi is provisioned): tells the user the one
// phrase to give their AI agent. Title/SSID are ASCII (built-in font); the
// Chinese lines are pre-rendered bitmaps.
void drawSetupScreen() {
  curExpr = EX_NONE;                                        // stop the mascot animation
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("AgentLight", 120, 18, 4);                // title
  zhLine(zh_tell, ZH_TELL_W, ZH_TELL_H,  50, TFT_WHITE);   // 跟你的 AI 助手说:
  zhLine(zh_p1,   ZH_P1_W,   ZH_P1_H,    90, TFT_YELLOW);  // 读取并设置
  zhLine(zh_p2,   ZH_P2_W,   ZH_P2_H,   120, TFT_YELLOW);  // 我刚插上的
  zhLine(zh_p3,   ZH_P3_W,   ZH_P3_H,   150, TFT_YELLOW);  // USB 设备
}

// Shown briefly after the agent provisions WiFi (then the hub takes over).
void drawDoneScreen() {
  curExpr = EX_NONE;
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  zhLine(zh_done,   ZH_DONE_W,   ZH_DONE_H,    78, TFT_GREEN);  // 配置完成
  zhLine(zh_unplug, ZH_UNPLUG_W, ZH_UNPLUG_H, 118, TFT_WHITE);  // 可拔线随身使用
  tft.setTextColor(TFT_DARKGREY, TFT_BLACK);
  tft.drawString(WiFi.localIP().toString(), 120, 152, 2);
}

// Shown while joining WiFi after the agent sends credentials.
void drawConnectingScreen(const char* ssid) {
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.drawString("Connecting...", 120, 110, 4);
  tft.setTextColor(TFT_DARKGREY, TFT_BLACK);
  tft.drawString(ssid, 120, 140, 2);
}

// Connected-but-idle screen, until the hub pushes the first colour.
void drawWaitingScreen() {
  curExpr = EX_NONE;
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(TFT_DARKGREY, TFT_BLACK);
  tft.drawString("AgentLight", 120, 80, 4);
  zhLine(zh_wait, ZH_WAIT_W, ZH_WAIT_H, 104, TFT_DARKGREY);  // 已连接 · 等待状态
  tft.drawString(String(MDNS_HOST) + ".local", 120, 150, 2);
  tft.drawString(WiFi.localIP().toString(), 120, 172, 2);
}

// ---- HTTP handlers ---------------------------------------------------------

// POST /json/state — WLED-compatible subset. Parses the colour and fills.
void handleSetState() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"empty body\"}");
    return;
  }
  JsonDocument doc;
  if (deserializeJson(doc, server.arg("plain"))) {
    server.send(400, "application/json", "{\"error\":\"bad json\"}");
    return;
  }
  bool    on  = doc["on"]  | true;
  uint8_t bri = doc["bri"] | 255;
  uint8_t r   = doc["seg"][0]["col"][0][0] | 0;
  uint8_t g   = doc["seg"][0]["col"][0][1] | 0;
  uint8_t b   = doc["seg"][0]["col"][0][2] | 0;

  paint(r, g, b, bri, on);
  server.send(200, "application/json", "{\"success\":true}");
}

// GET /json/state — minimal status (handy for sanity checks).
void handleGetState() {
  JsonDocument doc;
  doc["on"]  = curOn;
  doc["bri"] = curBri;
  JsonObject seg0 = doc["seg"].add<JsonObject>();
  JsonArray  col0 = seg0["col"].add<JsonArray>();
  col0.add(curR); col0.add(curG); col0.add(curB);
  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleRoot() {
  server.send(200, "text/html",
    "<h1>AgentLight screen</h1><p>POST /json/state to drive me.</p>");
}

// ---- lifecycle -------------------------------------------------------------

// Start mDNS + HTTP server once, after WiFi first connects.
void startServices() {
  if (servicesStarted) return;
  if (MDNS.begin(MDNS_HOST)) {
    MDNS.addService("http", "tcp", HTTP_PORT);
    // Custom service so the hub browses for AgentLight screens specifically.
    MDNS.addService("agentlight", "tcp", HTTP_PORT);
    MDNS.addServiceTxt("agentlight", "tcp", "id", deviceId());
  }
  server.on("/json/state", HTTP_POST, handleSetState);
  server.on("/json/state", HTTP_GET,  handleGetState);
  server.on("/",           HTTP_GET,  handleRoot);
  server.begin();
  servicesStarted = true;
}

// Self-announce on serial so the agent can find + identify this device among
// any other USB serial ports. One line, ~every 2s.
void emitBanner() {
  bool up = (WiFi.status() == WL_CONNECTED);
  Serial.printf("AGENTLIGHT id=%s proto=1 wifi=%s ip=%s setup=%s\n",
                deviceId().c_str(), up ? "connected" : "setup",
                up ? WiFi.localIP().toString().c_str() : "0.0.0.0", SETUP_URL);
}

// Handle one JSON command line from the agent (over USB serial).
//   {"cmd":"id"}                          -> {"id","proto","wifi","ip"}
//   {"cmd":"wifi","ssid":..,"pass":..}    -> {"ok":true,"ip":..} / {"ok":false,"error":..}
void processCommand(const String& line) {
  JsonDocument doc;
  if (deserializeJson(doc, line)) return;          // ignore non-JSON noise
  const char* cmd = doc["cmd"] | "";

  if (!strcmp(cmd, "id")) {
    Serial.printf("{\"id\":\"%s\",\"proto\":1,\"wifi\":\"%s\",\"ip\":\"%s\"}\n",
                  deviceId().c_str(),
                  WiFi.status() == WL_CONNECTED ? "connected" : "disconnected",
                  WiFi.localIP().toString().c_str());
    return;
  }

  if (!strcmp(cmd, "wifi")) {
    const char* ssid = doc["ssid"] | "";
    const char* pass = doc["pass"] | "";
    if (!*ssid) { Serial.println("{\"ok\":false,\"error\":\"no ssid\"}"); return; }
    drawConnectingScreen(ssid);
    WiFi.persistent(true);                 // save creds so it reconnects on its own
    WiFi.begin(ssid, pass);
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < 20000) delay(200);
    if (WiFi.status() == WL_CONNECTED) {
      justProvisioned = true;              // -> loop() shows the "done" screen
      Serial.printf("{\"ok\":true,\"ip\":\"%s\"}\n", WiFi.localIP().toString().c_str());
    } else {
      Serial.println("{\"ok\":false,\"error\":\"connect timeout\"}");
    }
    return;
  }
}

// Read serial byte-by-byte, dispatch on each complete line.
void handleSerial() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (serialLine.length()) { processCommand(serialLine); serialLine = ""; }
    } else if (serialLine.length() < 300) {
      serialLine += c;
    }
  }
}

void setup() {
  Serial.begin(115200);

  // Force the backlight on — TFT_eSPI does not always drive TFT_BL itself.
  // This board switches the backlight with a P-MOSFET, so it is ACTIVE-LOW.
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, TFT_BACKLIGHT_ON);   // = LOW on this board -> backlight on

  tft.init();
  tft.setRotation(0);   // TUNE: 0/1/2/3 if the image is rotated or mirrored
  sprReady = (faceSpr.createSprite(240, 240) != nullptr);  // flicker-free animation buffer
  drawSetupScreen();

  // Non-blocking: reconnect to stored creds (if any). loop() keeps running so
  // serial provisioning works even when there are no creds yet.
  WiFi.mode(WIFI_STA);
  WiFi.begin();
  bootMs = millis();
}

void loop() {
  handleSerial();

  if (millis() - lastBanner > 2000) { lastBanner = millis(); emitBanner(); }

  bool connected = (WiFi.status() == WL_CONNECTED);
  if (connected) startServices();            // start mDNS+HTTP asap (idempotent)

  // Hold the setup/welcome screen for a moment at cold boot so it's readable;
  // a fresh serial provision (justProvisioned) skips the wait and shows "done".
  bool dwellDone = justProvisioned || (millis() - bootMs >= SETUP_DWELL_MS);
  if (connected && !wasConnected && dwellDone) {
    wasConnected = true;
    if (justProvisioned) { justProvisioned = false; drawDoneScreen(); }
    else                 { drawWaitingScreen(); }
  } else if (!connected && wasConnected) {   // dropped
    wasConnected = false;
    curExpr = EX_NONE;                        // stop the face; show setup screen
    drawSetupScreen();
  }

  if (servicesStarted) server.handleClient();
  animateFace();                              // gentle float; no-op unless a face is active
}
