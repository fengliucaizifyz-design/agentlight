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
 * WiFi: provisioned via a phone (captive portal), never hard-coded. Credentials
 * are stored on-device; if they stop working (e.g. you moved to a new office),
 * the screen re-opens the setup hotspot automatically.
 *
 * Faces/animation are intentionally OUT OF SCOPE for now — solid colour aligns
 * with the project's existing state→colour model and is trivial to extend later.
 * ============================================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>     // tzapu/WiFiManager — captive-portal provisioning
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>     // v7
#include <TFT_eSPI.h>
#include "zh_assets.h"       // pre-rendered Chinese line bitmaps (gen by tools/)

// ---- config ----------------------------------------------------------------
static const char*    MDNS_HOST = "agentlight";  // -> http://agentlight.local
static const uint16_t HTTP_PORT = 80;

// ---- globals ---------------------------------------------------------------
TFT_eSPI  tft = TFT_eSPI();
WebServer server(HTTP_PORT);

// Last colour the hub asked for (kept so we can redraw / breathe later).
uint8_t curR = 0, curG = 0, curB = 0, curBri = 255;
bool    curOn = false;

// ---- helpers ---------------------------------------------------------------

// A per-device suffix from the MAC, e.g. "AgentLight-9CF5".
String apName() {
  uint16_t tail = (uint16_t)(ESP.getEfuseMac() & 0xFFFF);
  char buf[16];
  snprintf(buf, sizeof(buf), "AgentLight-%04X", tail);
  return String(buf);
}

uint16_t scaledColor(uint8_t r, uint8_t g, uint8_t b, uint8_t bri) {
  return tft.color565((uint16_t)r * bri / 255,
                      (uint16_t)g * bri / 255,
                      (uint16_t)b * bri / 255);
}

void paint(uint8_t r, uint8_t g, uint8_t b, uint8_t bri, bool on) {
  curR = r; curG = g; curB = b; curBri = bri; curOn = on;
  tft.fillScreen(on ? scaledColor(r, g, b, bri) : TFT_BLACK);
}

// Draw a pre-rendered Chinese line bitmap, horizontally centred, top at y.
void zhLine(const uint8_t* bmp, int w, int h, int y, uint16_t color) {
  tft.drawBitmap((240 - w) / 2, y, bmp, w, h, color);
}

// Setup-mode screen, shown whenever the captive portal is open.
// Chinese lines are bitmaps; the SSID stays ASCII (built-in font).
void drawSetupScreen() {
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("AgentLight", 120, 22, 4);             // ASCII title
  zhLine(zh_sub,   ZH_SUB_W,   ZH_SUB_H,   48, TFT_WHITE);   // 配网设置

  zhLine(zh_step1, ZH_STEP1_W, ZH_STEP1_H, 86, TFT_GREEN);   // 1. 连接下方热点
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.drawString(apName(), 120, 124, 4);                // AgentLight-XXXX (ASCII)

  zhLine(zh_step2, ZH_STEP2_W, ZH_STEP2_H, 150, TFT_WHITE);  // 2. 打开弹出页面
  zhLine(zh_step3, ZH_STEP3_W, ZH_STEP3_H, 182, TFT_WHITE);  // 3. 输入网络密码
}

// Connected-but-idle screen, until the hub pushes the first colour.
void drawWaitingScreen() {
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

void startPortalBlocking() {
  WiFiManager wm;
  wm.setAPCallback([](WiFiManager*) { drawSetupScreen(); });
  wm.setConfigPortalTimeout(0);            // stay open until configured
  wm.autoConnect(apName().c_str());        // blocks; opens portal if needed
}

void setup() {
  Serial.begin(115200);

  // Force the backlight on — TFT_eSPI does not always drive TFT_BL itself.
  // This board switches the backlight with a P-MOSFET, so it is ACTIVE-LOW.
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, TFT_BACKLIGHT_ON);   // = LOW on this board -> backlight on

  tft.init();
  tft.setRotation(0);   // TUNE: 0/1/2/3 if the image is rotated or mirrored
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.drawString("AgentLight", 120, 108, 4);
  tft.drawString("booting...", 120, 138, 2);

  startPortalBlocking();                   // -> Wi-Fi connected after this

  if (MDNS.begin(MDNS_HOST)) {
    MDNS.addService("http", "tcp", HTTP_PORT);
  }
  server.on("/json/state", HTTP_POST, handleSetState);
  server.on("/json/state", HTTP_GET,  handleGetState);
  server.on("/",           HTTP_GET,  handleRoot);
  server.begin();

  drawWaitingScreen();
}

void loop() {
  server.handleClient();

  // Mobile-office watchdog: if Wi-Fi is down for a while (moved location),
  // reopen the setup hotspot, then restart cleanly once reconfigured.
  static unsigned long downSince = 0;
  if (WiFi.status() != WL_CONNECTED) {
    if (downSince == 0) {
      downSince = millis();
    } else if (millis() - downSince > 30000) {
      startPortalBlocking();
      ESP.restart();
    }
  } else {
    downSince = 0;
  }
}
