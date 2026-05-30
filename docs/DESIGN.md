# AgentLight 融合版 — 设计稿 (v0, 待评审)

> 本文是**实施前的设计草案**,供项目所有者评审。评审通过后再写代码。
> 面向开源发布的英文 README 会在最后阶段产出,本文为中文内部稿。

---

## 1. 背景与现状

`agentlight` 仓库目前的真实状态:**只有外壳,没有核心**。

| 已有 | 说明 |
|---|---|
| `README.md` / `scripts/install.sh` | 安装脚本,但全部指向 `github.com/tifosi/agentlight` |
| `openclaw/hooks/agentlight/handler.ts` | 把 OpenClaw 事件翻译成状态,然后调 `agentlight` CLI |
| `docs/hardware.md` / `docs/cross-platform.md` | 构想中的硬件 / 跨平台方案(均未实现) |
| `SKILL.md` / `HOOK.md` | ClawHub 技能 / hook 元数据 |

**已确认的问题(必须在融合版中修掉):**

1. **核心程序不存在。** `handler.ts` 调用的 `agentlight` CLI(真正点灯的程序)在 GitHub 上任何地方都找不到 —— `tifosi/agentlight` 仓库不存在。所以现在 `handler.ts` 跑起来只会静默失败。
2. **仓库地址错位。** README / install.sh / HOOK.md 里所有链接都指向 `tifosi/agentlight`,但仓库实际在 `fengliucaizifyz-design/agentlight`,一键安装命令会拉不到东西。
3. **硬编码路径。** `handler.ts` 里 demo 文件路径写死成 `/Users/tifosi/.openclaw/...`。
4. **物理灯是空头支票。** `docs/hardware.md` 描述了 USB HID / serial / ESP32 三种方案,但没有任何固件或驱动代码。

**结论:** 这不是"补漏洞",而是"在现有地基上重建"。好处是没有历史包袱,可以一次设计对。

---

## 2. 目标(来自项目所有者)

把 `agentlight`(OpenClaw + 物理灯思路)和 `claude-statuslight`(完善的 macOS 菜单栏灯思路)的优点融合成一个项目:

1. **统一灯色** —— 一套标准状态 → 颜色映射,三端共用。
2. **双输出** —— 同时驱动「菜单栏灯」和「物理灯」。
3. **三端通吃** —— 同时支持 **Claude Code / Codex / OpenClaw**。
4. **取长补短** —— 菜单栏 UI/音效/端口管理学 claude-statuslight;事件翻译思路学 agentlight;物理灯走 WiFi(WLED)。

> ⚠️ 版权:`claude-statuslight` 是第三方 MIT 项目,**不直接复制其代码**,只参考思路、自行重写。本仓库代码完全属于项目所有者。

---

## 3. 总体架构:中心枢纽 + 适配器

核心思想:**砍掉那个不存在的 `agentlight` CLI**,改为所有事件都 `POST` 到一个本地枢纽。枢纽是唯一的状态源,同时驱动所有输出。

```
   【输入适配器】              【中心枢纽 (一个 macOS 程序)】        【输出端】
                                                              ┌─→ 菜单栏灯 (NSStatusItem)
 Claude Code hooks ─┐                                         │
 Codex hooks       ─┼─→ POST http://localhost:9527/state ─→ 统一状态机 ─┼─→ WLED 物理灯 (局域网 HTTP)
 OpenClaw hooks    ─┘        {"state":"working", ...}        + 灯色映射  │
                                                              └─→ demo 网页 (调试用,可选)
```

- **输入端**只做一件事:把各自 agent 的生命周期事件,翻译成统一状态,发一个 HTTP 请求。
- **枢纽**维护当前状态、决定颜色、把颜色推给所有已启用的输出端。
- **输出端**互相独立:菜单栏灯永远在;物理灯插了/配了才生效;demo 网页仅调试。

这一设计同时解决了现状的问题 1(不再需要外部 CLI)和问题 4(物理灯成为枢纽的一个标准输出)。

---

## 4. 统一状态机 + 灯色表(规范)

合并两个项目的状态语义后,确定 **5 态**:

| 统一状态 | 颜色 | 动效 | 含义 | 菜单栏文字(示例) |
|---|---|---|---|---|
| `idle`    | 🟢 绿 | 常亮 | 空闲 / 就绪 / 本轮结束 | `Claude 🟢 Idle` |
| `working` | 🟡 黄 | 脉冲 | 正在执行 / 思考 / 调用工具 | `Codex 🟡 Working` |
| `confirm` | 🔵 蓝 | 脉冲 | 等待你确认权限 | `Claude 🔵 Confirm` |
| `error`   | 🔴 红 | 脉冲 | 出错 | `OpenClaw 🔴 Error` |
| `offline` | ⚪️ 灰 | 灭 | 进程退出 / 网关关闭 | `Claude ⚪️ Offline` |

设计决策(已定稿):
- **菜单栏显示具体是哪个 agent。** 格式为 `<Agent> <emoji> <State>`,agent 名取自 `source` 字段:`claude-code`→`Claude`、`codex`→`Codex`、`openclaw`→`OpenClaw`。
- **UI 文字用英文。** 状态词:`Idle / Working / Confirm / Error / Offline`(后续可微调,易改)。对外 README 同样英文。
- **「成功」不单列。** agentlight 原本有 `success`(绿),本设计中任务完成直接回 `idle`(也是绿),少一个态更清爽。
- **RGB 值**(给 WLED 用):idle=`(0,200,0)`、working=`(255,180,0)`、confirm=`(0,120,255)`、error=`(255,0,0)`、offline=`(0,0,0)/灭`。脉冲在枢纽端做亮度呼吸。

---

## 5. 枢纽 HTTP 接口契约(`localhost:9527`)

所有输入适配器只需要会发这一个请求:

```
POST http://localhost:9527/state
Content-Type: application/json

{
  "state":   "working",          // 必填: idle|working|confirm|error|offline
  "source":  "claude-code",      // 选填: 哪个 agent (claude-code|codex|openclaw)
  "session": "dealism-ads",      // 选填: 会话标识,多会话时用于区分
  "detail":  "Running pytest"    // 选填: 鼠标悬停菜单栏时显示的说明
}
```

- 端口沿用 claude-statuslight 的 `9527`(已被那套验证可用)。
- 枢纽另开 `GET /state` 返回当前状态(给 demo 网页 / 调试用)。
- 多会话策略(v2 再细化):默认"最紧急态优先"——只要有任一会话在 `confirm`,灯就显示 `confirm`;否则按 working > error > idle > offline 的优先级聚合。v1 单会话不涉及。

---

## 6. 技术选型

| 部件 | 语言 | 理由 |
|---|---|---|
| **枢纽 + 菜单栏灯** | **Swift**(单文件,类似 claude-statuslight) | 菜单栏本就是 macOS 原生能力;编译成单二进制、零第三方依赖;内置 HTTP server(Network 框架)+ HTTP 客户端(URLSession,用来打 WLED)都是标准库,WLED 只是一个 POST |
| **OpenClaw 适配器** | **TypeScript**(沿用 `handler.ts`) | OpenClaw 运行时直接加载 .ts;**只改内部**——从「调 CLI」改成「POST 到 :9527」,顺手修掉硬编码路径 |
| **Claude Code / Codex 适配器** | **配置 + 极简 shell/curl** | 两者都用 hooks 机制,直接 `curl` 打 :9527,不需要独立程序 |

> 跨平台余地:因为输入/枢纽是 HTTP 解耦的,将来 Linux 用户可以只写一个"无菜单栏、只驱动 WLED"的枢纽,复用同一套适配器和接口契约。v1 先做 macOS。

---

## 7. 目标目录结构(重建后)

```
agentlight/
├── README.md                      # 重写: 多端状态灯, 修正所有 tifosi/ 链接
├── LICENSE                        # 保留 MIT-0
├── docs/
│   ├── DESIGN.md                  # 本文
│   ├── hardware.md                # 重写: 聚焦 WLED WiFi 灯(淘宝可买/可定制)
│   └── cross-platform.md          # 重写: 三端适配说明
├── hub/                           # 【新】中心枢纽 + 菜单栏灯 (Swift)
│   ├── main.swift                 # 枢纽: HTTP server + 状态机 + 菜单栏 + WLED 输出
│   ├── build.sh
│   └── AgentLight.app/            # 编译产物
├── adapters/                      # 【新】三端输入适配器
│   ├── claude-code/
│   │   ├── settings-hooks.json    # 贴进 .claude/settings.json 的 hooks 片段
│   │   └── install.sh
│   ├── codex/
│   │   ├── config-hooks.toml      # 贴进 ~/.codex/config.toml 的片段
│   │   └── install.sh
│   └── openclaw/                  # 从旧 openclaw/hooks/agentlight 迁移并改造
│       ├── HOOK.md
│       ├── handler.ts             # 改: POST 到 :9527, 去掉硬编码路径
│       └── install.sh
├── examples/
│   ├── demo.html                  # 保留: 调试用彩色圆圈
│   └── agentlight-state.json
└── scripts/
    └── install.sh                 # 重写: 引导用户选择要装哪个/哪些适配器
```

---

## 8. 三端事件 → 统一状态 映射

| 统一状态 | Claude Code hook | Codex hook | OpenClaw 事件 |
|---|---|---|---|
| `idle`    | `SessionStart` / `Stop` | `SessionStart` / `Stop` | `gateway:startup` / `command:reset` / `command:stop` |
| `working` | `PreToolUse` / `UserPromptSubmit` | `PreToolUse` / `UserPromptSubmit` | `message:received` / `command:new` |
| `confirm` | `Notification`(权限请求) | `PermissionRequest` | (OpenClaw 无对应,留空) |
| `error`   | (工具失败 / 退出码) | `PostToolUse`(失败) | (命令失败) |
| `offline` | `SessionEnd` | 会话结束 | `gateway:shutdown` |

注:
- **Codex** 需在 `~/.codex/config.toml` 开启 `[features] codex_hooks = true`。事件粒度与 Claude Code 基本对齐,实装时按所装版本核对确切事件名。
- **OpenClaw** 没有"权限确认"概念,`confirm` 态在该端不触发,属正常。

---

## 9. WLED 物理灯接入设计

- 物理灯选型:**ESP32/ESP8266 + WS2812B,刷 WLED 固件**(淘宝可买现成或定制,成本约 ¥30–100)。详见重写后的 `docs/hardware.md`。
- 枢纽驱动方式:状态变化时,除了刷新菜单栏,再向 WLED 的局域网接口发一个 HTTP 请求:

  ```
  POST http://<WLED_IP>/json/state
  {"on":true, "bri":160, "seg":[{"col":[[R,G,B]]}]}    // 颜色取自第 4 节灯色表
  ```

- 配置:枢纽菜单里加一项"设置物理灯 IP",写进本地配置文件;留空则只用菜单栏灯。
- 容错:WLED 请求失败(灯没开/不在网)时静默忽略,不影响菜单栏灯。

---

## 10. 分阶段实施计划

> 已确认:**v1 只接 Claude Code。**

| 阶段 | 内容 | 产出 |
|---|---|---|
| **v1**(先做) | 枢纽 + 菜单栏灯(Swift);接通 Claude Code 5 态;本机能看到灯随 Claude Code 变色 | `hub/`、`adapters/claude-code/`、能跑的 `.app` |
| **v2** | 加 Codex 适配器、改造 OpenClaw 适配器(POST 到枢纽);多会话聚合策略 | `adapters/codex/`、`adapters/openclaw/` |
| **v3** | WLED 物理灯输出(等灯到货 + IP);重写 `docs/hardware.md` | 枢纽 WLED 模块 |
| **收尾** | 重写 README(英文,修正所有链接)、`scripts/install.sh`、demo 页;推回 GitHub | 可对外发布的仓库 |

---

## 11. 已定稿决策(项目所有者确认)

1. **菜单栏文字**:✅ 显示具体是哪个 agent —— `<Agent> <emoji> <State>`(如 `Claude 🟡 Working`)。
2. **UI 语言**:✅ 英文(状态词 `Idle / Working / Confirm / Error / Offline`)。
3. **demo 网页**:✅ 保留,作为调试工具。
4. **推送策略**:✅ 设计稿不单独推,**定稿后跟 v1 代码一起推**到 GitHub。

> 本设计稿到此定稿。下一步:按第 10 节进入 **v1** —— 实现枢纽 + 菜单栏灯,接通 Claude Code 五态。
```