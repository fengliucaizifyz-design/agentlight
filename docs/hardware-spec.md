# AgentLight Pro Max — hardware spec (for prototyping)

> Purpose: a clear, complete requirement to hand a supplier/ODM for a prototype batch
> (~15 units). Goal form: a small desktop box (like a "小智 AI" cube) with a front screen,
> battery-powered and portable, that shows the AI agent's state.

## Build model & firmware-protection (read first)

- Turnkey ODM: we give the functional spec; the supplier designs the PCB + power + enclosure.
- **Keep the MCU and screen unchanged so our firmware is reused:** **ESP32-S3** + **ST7789
  240×240 1.54" SPI**. If those change, firmware must be re-ported.
- **The supplier MUST deliver a schematic + GPIO pin map** (see Deliverables). We re-tune the
  firmware's pins from it (screen pins, backlight polarity, CS, buttons, battery ADC). This is
  mandatory — without it the firmware can't be adapted.

## Functional spec

### MCU
- **ESP32-S3** (WROOM / WROOM-1 module; **≥8 MB PSRAM preferred**). 2.4 GHz Wi-Fi + BLE.

### Screen
- **1.54" TFT, ST7789 driver, 240×240, 4-wire SPI.** Embedded in the front shell.

### Power / battery
- Internal **Li-Po**, **USB-C charging** with charge management + battery protection + boost to 3.3 V.
- **Runtime target: ≥12 h active (screen + Wi-Fi on); aim 20 h.** Supplier sizes the cell to
  balance runtime vs enclosure (expect ~1500–2500 mAh). Firmware adds power management (idle
  dim/sleep, Wi-Fi modem-sleep) to stretch it.
- **Battery level:** expose battery voltage on an ADC pin (so firmware can show charge). A
  charge-status pin is a plus.

### USB-C  ⚠️ critical
- **USB-C must carry DATA (D+/D- to the ESP32-S3 native USB), not charge-only.** Setup,
  flashing, and the agent's serial provisioning all depend on it. Same port also charges.

### Buttons — 3 momentary tactile, each to its own GPIO
- ① **Power** (on/off, soft-latch; firmware also uses it for sleep/wake the screen)
- ② **Confirm / 同意**
- ③ **Cancel / 不同意**
- Placement: reachable when handheld; power separate (e.g. one side), confirm/cancel together.
- *Function note:* the hardware just needs 3 buttons → 3 GPIOs (state the active level + any
  pull). The button **meanings** are firmware. The "confirm/cancel on-device approves the
  agent" idea needs device→hub→agent plumbing + agent support — validated in software later;
  it does not affect this hardware spec.

### Connectivity
- 2.4 GHz Wi-Fi via on-board (PCB) antenna; must work **inside the enclosure** (no metal shielding it).

### Enclosure (mechanical)
- Form: **small desktop box / cube**, screen embedded in the front face; like "小智 AI".
- Rear cover: snap-fit with hidden screws; **anti-slip feet** on the bottom; matte finish.
- Ports/buttons: USB-C on the bottom/back; the 3 buttons accessible on the case.
- Size: driven by the screen module (~31.5 × 33.7 mm; active area 27.7 × 27.7 mm) + the chosen
  battery — **keep it compact**; final dimensions per supplier.
- Prototype build: **3D printed (resin/SLA)** is fine for this batch.
- Color / logo / branding: TBD (placeholder for now).

## Deliverables from the supplier
1. Working sample units (qty below).
2. **Full schematic + GPIO pin map** — screen `SDA/SCL/DC/RES/CS` (or note CS tied low),
   backlight control pin **and its polarity / driver (MOSFET?)**, the 3 button GPIOs (+ active
   level / pull), battery-voltage ADC pin, charge-status pin (if any). Confirm USB is the
   ESP32-S3 **native** USB (USB-Serial/JTAG) for flashing.
3. BOM.

## Quantity & certification
- **~15 units** (small pilot batch — affects cost/lead time vs a 1–3 unit prototype).
- **No certification needed** (internal testing). For sale later: SRRC/3C (CN), FCC/CE (intl).

## Flagged / open
- **Runtime vs size:** 20 h continuous needs a big cell (bigger box); realistic ≥12 h with
  ~1500–2000 mAh + firmware power-saving. Balance with the supplier.
- **Confirm/Cancel "remote approve"** function: software feasibility per agent is TBD (e.g.
  whether Claude Code's permission prompt can be approved externally). Hardware unaffected.
- Brand name / color / logo: TBD.

---

## 供应商询价话术(中文,可直接发)

> 你好,我要打样一款**便携桌面小硬件**(类似「小智 AI」那种小方盒,正面一块小屏),用于显示 AI 助手的状态。需求如下,麻烦评估打样(约 **15 台**):
>
> - **主控**:ESP32-S3(WROOM/WROOM-1 模组,优先带 8MB PSRAM),**必须用 S3**(我有现成固件)。
> - **屏幕**:1.54 寸 TFT,**ST7789 驱动,240×240,SPI 接口**(沿用此规格),嵌入正面。
> - **供电**:内置**锂电池**,**USB-C 充电**(充电管理 + 电池保护 + 升压 3.3V);续航目标**≥12 小时(争取 20 小时)**屏+WiFi 工作,容量你按外壳/续航平衡(预计 1500–2500mAh)。请把**电池电压接到一个 ADC 脚**(便于显示电量),有充电状态脚更好。
> - ⚠️ **USB-C 必须带数据线**(D+/D- 接到 ESP32-S3 原生 USB),用于烧录和配置,**不能是只充电口**。
> - **3 个实体轻触按键**,各接一个独立 GPIO:① 电源(开关机,软锁)② 确认 ③ 取消;外壳上方便按到。
> - **无线**:2.4G WiFi(板载天线,装进外壳后能正常工作)。
> - **外壳**:小方盒,屏嵌正面,背盖卡扣+隐藏螺丝,底部防滑垫,磨砂;打样用 3D 打印(树脂)即可;尺寸按屏+电池定,尽量小巧;颜色/logo 待定。
> - **交付**:① 可用样机 ② **完整原理图 + GPIO 引脚对照表**(屏 SDA/SCL/DC/RES/CS、背光控制脚及高低电平/是否经 MOSFET、3 个按键脚、电池 ADC 脚、充电状态脚;确认 USB 为 S3 原生 USB)③ BOM。**引脚表对我适配固件是必须的。**
> - 数量约 **15 台**,暂不需要认证(内部测试)。
>
> 请评估可行性、报价和周期,谢谢!
