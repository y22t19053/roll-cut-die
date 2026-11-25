# RCD_ENGINEERING_STATUS — 工程与测试实测状态报告

> 审计日期：2026-11-25（基于工作区与无头引擎实测）  
> 关联历史档案：`docs/PROJECT_STATUS.md`（2026-11-22 快照） · `docs/WORKFLOW_GUIDE.md`

---

## 1. 版本基线与分支保全

2026-11-25 复核本地 `master` 日志，HEAD 为 `4f0f1ea`，主工作区 `git status --porcelain` 为空。每日计分与 TOY 桥接已随 `5d4c0e9` 纳入主线。Sprint 1 卫生修复见 `39183b8`、`f2d28b2`、`ecc261d`。

接管时的 WIP 快照 `b1eb404` 与 `free-blocking-sets@74faa23` 均保存了完整的 `scripts/relay/h_gantry.gd`。两个版本都是 8,564 字节，Git blob 同为 `84b8fc927bbdd7df5e9654dc390ec5bd02f015b5`。任务单所列 `archive/free-blocking-wip-20261125` 分支名在本地引用中未查到。

## 2. Sprint 3 / 4 交付工作树

| 执行端 | 分支 | 本轮职责 |
|---|---|---|
| A | `codex-a/sprint4-audio-and-deai` | 配乐、动作拟音、特效与片场环境表现 |
| B | `codex-b/sprint3-inrun-ui` | 局内设置、暂停、HUD、剪辑台与通告单 |
| C | `codex-c/sprint3-4-qa-and-docs` | 回归模块、测试注册及五份活动档案 |

## 3. 已实现工程模块全景

| 模块 | 入口场景 / 核心脚本 | 当前工程状态 |
|---|---|---|
| **主菜单与前端** | `scenes/front/title.tscn` · `scripts/ui/title_screen.gd` · `scripts/ui/night_stage_3d.gd` · `scripts/ui/ui_kit.gd` | Sprint 2 **COMPLETED & MERGED**。Brutalist Call Sheet 配合 NightStage3D 三重曝光夜棚；合并于 `89b6451`，修正与 Forward+ 截图见 `4f0f1ea` 的 `visual/preview/sprint2_*.png`（中英标题、中文设置及名单） |
| **`relay` 主线模式** | `scenes/relay/run.tscn` · `scripts/relay/relay_run.gd` · `relay_rules.gd` · `relay_rooms.gd` · `cutting_desk.gd` · `safety_splice.gd` · `relay_save.gd` | **当前正式交付主线**：包含 `I/L/O/H/S` 五类摄影棚几何、5×7 点阵布景、历史 Ghost 碰撞回放、MARK/CUT 预算与剪辑台、死亡触发 180° 翻景、天桥（`Y=1.2m`）、抢天光（Daylight Rush）暖光事件、中途存档（`user://rcd/relay_run.json`）与生涯元存档（`user://rcd/relay_meta.cfg`） |
| **`free-blocking` 实验线** | `scenes/relay/blocking.tscn` · `scripts/relay/blocking_run.gd` · `blocking_stage.gd` · `h_gantry.gd` | **独立实验分支**：手搭摄影棚 + 自由机位选择 + 放饭（Meal Break）+ 转场（Company Move），已在 `free-blocking-sets` 分支产出开发包 `builds/RCD-Free-Blocking-dev1.exe` |
| **`campaign` 早期案件线** | `scenes/main/main.tscn` · `scripts/take/` · `scripts/ghost/` · `docs/CASE_AND_ENDINGS.md` | **历史完整资产（保留未删）**：含 2 名 NPC、4 件物证、3 条 Take 与 3 种裁决结局，当前标题页无直接入口，单元测试仍在 `run_all.gd` 中持续守护 |
| **`studiolot` / `backlot`** | `scenes/studiolot/world.tscn` · `scenes/backlot/backlot.tscn` | **原型储备场景**：绿幕摄影棚与外景回环/传送门视觉验证场景，保留于仓库内 |
| **触控与多端适配** | `scripts/relay/touch_pad.gd` · `scripts/ui/settings_panel.gd` · `scripts/relay/relay_pause.gd` | 已按 `D-070` 实现 `"auto" / "on" / "off"` 三态触控板（PC 键鼠默认隐藏，触摸屏自动启用） |
| **开发桥接与自动化** | `autoload/mcp_interaction_server.gd` · `scripts/core/game_session.gd` · `tools/strip_dev_autoload.py` | 支持 `godot-bridge` 9090 端口实时交互与截图；出包时通过 `strip_dev_autoload.py` 自动剥离/恢复开发 Autoload |

---

## 4. 已解决问题与验证依据

| 编号 | 状态 | 依据 |
|---|---|---|
| BUG-01 | RESOLVED / VERIFIED | `title_screen.gd` 共用 `RUN_SCENE = "res://scenes/relay/run.tscn"`；入口回归见 `tests/test_relay.gd`。 |
| BUG-02 | RESOLVED / VERIFIED | `relay_run.gd` 为同位出生的玩家与 Ghost 登记豁免，分离后恢复碰撞。中途相遇仍按原判定；`ecc261d` 补齐 `GhostActor.setup` 空轨迹保护与出生重叠回归。 |
| BUG-03 | RESOLVED / VERIFIED | `51db451` 隔离 west-trial autoload 夹具。本工作树执行 Python unittest discover，含 `test_west_trial_prepare.py` 的全套结果为 **31/31 OK**。 |
| BUG-04 | RESOLVED / VERIFIED（Sprint 1 验收） | Dummy 空 mesh 与退出时 ObjectDB 泄漏已修复；运行与测试拆卸见 `f2d28b2`、`51db451`。 |
| DRIFT-01 | RESOLVED / VERIFIED | `relay_run.gd` 定义 `MODULES = 12`、`ACTS = 4`、`SETS_PER_ACT = 3`，标题进度从 `RunScript.MODULES` 取值。 |

## 5. Sprint 3 / 4 交付记录

Sprint 3 将标题的纸张、印章与排版延伸至局内 HUD、暂停、设置、道具盘及手工通告单。`Mode.CUT` 的 Steenbeck 放大镜显示选择的 MARK / Take 与回退代价，中央走位区域保持可见。

Sprint 4 目标是 22,050 Hz D 小调推进型配乐、动作拟音与视觉反馈。`visual/DEAI_PLAN.md` #1–#6 分别覆盖场务回望、远端退场、纸面划改、道具偏摆、静置后淡入的 −34 dB 低语与后段灯闪。表现层沿用同一套可复现的碰撞、计时和资源规则。

C 分支注册 `inrun_ui_deai`，覆盖镜头与碰撞半径、双语设置与暂停恢复、剪辑台模式、五族布景在相同时间的碰撞位置和 WAV 格式。预览接口存在时还会触发放大镜重绘与关闭。模块已合入，Godot 4.3 全套回归结果见 §7。

## 6. 尚待独立验证

| 编号 | 状态 | 验证范围 | 待办 |
|---|---|---|---|
| **UNV-01** | `UNVERIFIED` | **外部真人盲测样本为 `0`**：复杂多 Ghost 走位、180° 翻景后的空间方向理解尚未经过真人独立试玩验证 | 需安排真人试玩与遥测回放 |
| **UNV-02** | `UNVERIFIED` | **真实窗口 Alt+Tab 焦点丢失配对测试**：按键粘连与音频挂起恢复尚未完成桌面真窗口配对验证 | 待交互模式实测 |
| **UNV-03** | `UNVERIFIED` | **移动真机浏览器触控实测**：`DisplayServer.is_touchscreen_available()` 在 Android Chrome / iOS Safari 的实际返回值与 520px 小屏字号可读性尚未真机核验（见 `D-070`） | `UNVERIFIED` |
| **UNV-04** | `UNVERIFIED` | **B 站 TOY 线上包是否已更新为剥离 `McpInteractionServer` 后的最新包**（见 `D-072` 末尾记录） | `UNVERIFIED`（未获创作者授权前不擅自 `toy update`） |

## 7. Sprint 5 · Active

本轮从 `master@c46ca46` 派生，Godot 4.3 基线为 815 条断言。世界与路线由 `codex-a-sprint5-world` 跟进，机关道具由 `codex-b-sprint5-props` 跟进，验收与档案由 `codex-c-sprint5-guard` 负责。

| C 工作树交付 | 状态 | 验收依据 |
|---|---|---|
| 统一验收脚本 | 已验证 | `tools/verify_all.py --json` 汇总 Python 31 项与 Godot 815 条断言，支持基线、超时和 CI 退出码。 |
| Dummy 空网格噪声 | 已验证 | 完整套件的 `mesh_get_surface_count` 从 2,412 次降至 0 次。测试入口在节点释放期间短暂持有网格引用。 |
| 活动档案同步 | 已完成 | 工程状态、路线图和多端协作规范已登记 Sprint 5 基线、工作树与验收方式。 |
