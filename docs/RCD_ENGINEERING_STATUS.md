# RCD_ENGINEERING_STATUS — 工程与测试实测状态报告

> 审计日期：2026-11-25（基于工作区与无头引擎实测）  
> 关联历史档案：`docs/PROJECT_STATUS.md`（2026-11-22 快照） · `docs/WORKFLOW_GUIDE.md`

---

## 1. 仓库拓扑与版本基线

| 维度 | 实查结果 |
|---|---|
| 主工程工作区路径 | `C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die` |
| 历史桌面目录 | `C:\Users\11ee11\Desktop\ROLL CUT DIE`（目录存在，内容为空 `0` 项，非 Git 仓库） |
| 远端仓库 | `origin` → `https://github.com/y22t19053/roll-cut-die.git`（HTTP 200 公开可读） |
| 当前检出分支 | `master`（与 `origin/master` 对齐） |
| 当前 `HEAD` 提交 | `04aa58563bd23638c652f743cfb010dc1730f9e2` — `"Put the dev autoload back where Godot put it"` |
| 提交规模与 Tag | `master` 共 `228` 次提交（全分支共 `232` 次，首提交 `c3de553` 于 `2026-11-19 22:06:26 +0800`）；Git Tag：`无（0 个）` |
| 活跃超前分支 | `free-blocking-sets` @ `28a8e6b`（位于 `.agents/worktrees/free-blocking-sets`，工作树干净，**超前 `master` 4 个提交**：`0444d62`, `1dce63a`, `c8b659c`, `28a8e6b`） |
| 已合入/平齐分支 | `backlot-return-window-qa` (`2d17187`), `english-ui-proof` (`d16e816`), `fable-window-qa` (`e149ef9`), `relay-input-proof` (`a930509`) — 均超前 `master` `0` 个提交 |
| 关联 Git Worktree 总数 | 共 `21` 个（主工作区 `1` + `.agents/worktrees/*` `5` + `default-workspace/rcd-*-qa-*` `6` + `AppData/Local/Temp/rcd-*` `9`） |

---

## 2. 主工作区未提交脏改动取证（Dirty Working Tree）

当前 `master` 工作区存在 **9 个已跟踪修改文件 + 7 个未跟踪文件**，混杂了两条互不相干的开发流，**严禁在拆分清理前直接从此工作树打包发布**：

### 2.1 流 A：Bilibili TOY 每日挑战计分与排行榜桥接（相对自洽）
- 已修改：`scripts/relay/relay_rules.gd`（`SCORE_*` / `DAY_OFFSET` 常量）、`scripts/relay/relay_run.gd`（`_send_score` 上报）、`scripts/relay/cutting_desk.gd`、`scripts/ui/title_screen.gd`（`ToyBridge` 排行榜展示）、`tests/run_all.gd`（挂载 `toy_score`）、`tools/patch_web_shell.py`、`tools/strip_dev_autoload.py`、`project.godot`（CRLF 行尾差异）。
- 未跟踪：`scripts/relay/toy_bridge.gd`、`tests/test_toy_score.gd`。

### 2.2 流 B：`free-blocking` 实验功能溢出残留（含 P0 入口分叉 Bug）
- 已修改：`scripts/player/player.gd`（`vertical_walk` 逻辑）、`scripts/ui/title_screen.gd:437`（**P0 风险点**：`_on_new_game()` 被改为跳转未跟踪场景 `"res://scenes/relay/blocking.tscn"`）。
- 未跟踪：`scenes/relay/blocking.tscn`、`scripts/relay/blocking_music.gd`、`scripts/relay/blocking_run.gd`（`8,133 B`，与 `free-blocking-sets` 分支上的 `7,833 B` 存在本地漂移）、`scripts/relay/blocking_stage.gd`（`8,298 B` vs 分支 `8,226 B`）、`scripts/relay/h_gantry.gd`（`8,564 B`，仅存在于脏主工作区，分支尚未收录）。

---

## 3. 已实现工程模块全景

| 模块 | 入口场景 / 核心脚本 | 当前工程状态 |
|---|---|---|
| **主菜单与前端** | `scenes/front/title.tscn` · `scripts/ui/title_screen.gd` · `scripts/ui/night_stage.gd` · `scripts/ui/ui_kit.gd` | 可运行；具备继续游戏、新游戏、难度选择、每日挑战、设置、制作名单、退出、F2/按钮中英切换、动晕提示；视觉仍处于原型平面几何体阶段 |
| **`relay` 主线模式** | `scenes/relay/run.tscn` · `scripts/relay/relay_run.gd` · `relay_rules.gd` · `relay_rooms.gd` · `cutting_desk.gd` · `safety_splice.gd` · `relay_save.gd` | **当前正式交付主线**：包含 `I/L/O/H/S` 五类摄影棚几何、5×7 点阵布景、历史 Ghost 碰撞回放、MARK/CUT 预算与剪辑台、死亡触发 180° 翻景、天桥（`Y=1.2m`）、抢天光（Daylight Rush）暖光事件、中途存档（`user://rcd/relay_run.json`）与生涯元存档（`user://rcd/relay_meta.cfg`） |
| **`free-blocking` 实验线** | `scenes/relay/blocking.tscn` · `scripts/relay/blocking_run.gd` · `blocking_stage.gd` · `h_gantry.gd` | **实验分支/脏树 WIP**：手搭摄影棚 + 自由机位选择 + 放饭（Meal Break）+ 转场（Company Move），已在 `free-blocking-sets` 分支产出开发包 `builds/RCD-Free-Blocking-dev1.exe` |
| **`campaign` 早期案件线** | `scenes/main/main.tscn` · `scripts/take/` · `scripts/ghost/` · `docs/CASE_AND_ENDINGS.md` | **历史完整资产（保留未删）**：含 2 名 NPC、4 件物证、3 条 Take 与 3 种裁决结局，当前标题页无直接入口，单元测试仍在 `run_all.gd` 中持续守护 |
| **`studiolot` / `backlot`** | `scenes/studiolot/world.tscn` · `scenes/backlot/backlot.tscn` | **原型储备场景**：绿幕摄影棚与外景回环/传送门视觉验证场景，保留于仓库内 |
| **触控与多端适配** | `scripts/relay/touch_pad.gd` · `scripts/ui/settings_panel.gd` · `scripts/relay/relay_pause.gd` | 已按 `D-070` 实现 `"auto" / "on" / "off"` 三态触控板（PC 键鼠默认隐藏，触摸屏自动启用） |
| **开发桥接与自动化** | `autoload/mcp_interaction_server.gd` · `scripts/core/game_session.gd` · `tools/strip_dev_autoload.py` | 支持 `godot-bridge` 9090 端口实时交互与截图；出包时通过 `strip_dev_autoload.py` 自动剥离/恢复开发 Autoload |

---

## 4. 自动化测试实测回执（2026-11-24 / 2026-11-25）

### 4.1 Godot Headless 全量测试套件（`tests/run_all.gd`）
- 执行通道：`godot_run_headless(project_path="...\\roll-cut-die", script="tests/run_all.gd")`（严守非沙箱通道，零 Signal 11 崩溃）
- 实测结论：**`RCD TESTS: ALL PASS — 646 assertions in 3.2 s`**（`exit_code = 0`；远超历史锚点记录的 `R5 86/86`）
- 15 个子套件断言明细：
  - `camera`: `91/91` · `ghost`: `47/47` · `npc`: `21/21` · `map`: `44/44` · `case`: `50/50`
  - `take`: `48/48` · `mark`: `22/22` · `relay`: `146/146` · `save`: `31/31` · `routes`: `18/18`
  - `scene`: `36/36` · `relay_death`: `10/10` · `relay_walk`: `6/6` · `touch_pad`: `53/53` · `toy_score`: `23/23`
- **引擎底层告警（需纳入工程治理）**：
  1. Headless Dummy 渲染器重复输出 `ERROR: Parameter "m" is null. at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)`（空网格材质/表面查询未加判空保护）。
  2. 进程退出时输出 `WARNING: ObjectDB instances leaked at exit (run with --verbose for details). at: cleanup (core/object/object.cpp:2284)`（测试动态创建的节点/资源存在未释放孤儿引用）。

### 4.2 Python 工具链单元测试（`tests/test_*.py`）
- 执行命令：`C:\Users\11ee11\miniconda3\python.exe -m unittest discover -s tests -p "test_*.py"`
- 实测结论：**运行 `30` 项测试，通过 `28` 项，报错 `2` 项（`errors = 2`）**
- 失败定位：`tests/test_west_trial_prepare.py:61` 调用 `tools/west_trial_operator.py:21` 抛出 `ValueError: Unexpected project configuration; trial not prepared.`——原因系 `project.godot` 主场景已从早期 `campaign` 试玩配置演进至 `res://scenes/front/title.tscn`，而旧准备脚本仍硬编码断言旧版 `project.godot` 指纹。

---

## 5. 已知 Bug、文档漂移与未验证风险清单

| 编号 | 等级 | 问题描述与代码定位 | 当前状态 |
|---|---|---|---|
| **BUG-01** | **P0 阻断** | **主菜单入口场景分叉**：脏工作区 `scripts/ui/title_screen.gd:437` 中 `_on_new_game()` 跳转至未跟踪的 `"res://scenes/relay/blocking.tscn"`，而 `_on_daily()`（`:508`）与 `_on_continue()`（`:526`）仍跳转 `"res://scenes/relay/run.tscn"`，导致新开局与续档/日挑进入两套完全不同的游戏规则 | 待冲刺 1 立即修复并隔离分支 |
| **BUG-02** | **P1 玩法公平** | **原地静止 Ghost 出生点秒杀循环**（Mnemon 审计 `36638903`）：若上一条 Take 玩家在出生点几乎未移动即结束，生成的静止 Ghost 会驻留在起点，导致后续 Take 连续 20 次在出生瞬间碰撞暴毙（候选方案：出生后 `0.6–0.75s` 碰撞宽限窗，或位移 `<0.5m` 的 Take 不实体化碰撞体） | 待设计裁决与修复 |
| **BUG-03** | **P2 工具测试** | `tests/test_west_trial_prepare.py:61` 因 `project.godot` 主线迁移报 `Unexpected project configuration`（2 errors） | 待 Codex C 更新测试夹具 |
| **BUG-04** | **P2 引擎卫生** | Headless 运行期 `mesh_get_surface_count` 空指针报错与退出时 `ObjectDB instances leaked` 内存/节点泄漏 | 待 Codex A/C `--verbose` 定位清理 |
| **DRIFT-01** | **P1 文档漂移** | 幕次/景数记载不一：`docs/RCD_MISSION_BRIEF.md` 与 `docs/PROJECT_STATUS.md` 写「4 Acts × 3 Sets = 12 Sets」，而 `docs/design/RCD_ROOM_RELAY_STAGE_PLAN.md` 与 `relay_rules.gd` 实装参数存在 `ACTS = 3, SETS_PER_ACT = 2 (MODULES = 6)` 收敛调整 | 待冲刺 1 统一核对并以实装为准对齐 |
| **UNV-01** | `UNVERIFIED` | **外部真人盲测样本为 `0`**：复杂多 Ghost 走位、180° 翻景后的空间方向理解尚未经过真人独立试玩验证 | 需安排真人试玩与遥测回放 |
| **UNV-02** | `UNVERIFIED` | **真实窗口 Alt+Tab 焦点丢失配对测试**：按键粘连与音频挂起恢复尚未完成桌面真窗口配对验证 | 待交互模式实测 |
| **UNV-03** | `UNVERIFIED` | **移动真机浏览器触控实测**：`DisplayServer.is_touchscreen_available()` 在 Android Chrome / iOS Safari 的实际返回值与 520px 小屏字号可读性尚未真机核验（见 `D-070`） | `UNVERIFIED` |
| **UNV-04** | `UNVERIFIED` | **B 站 TOY 线上包是否已更新为剥离 `McpInteractionServer` 后的最新包**（见 `D-072` 末尾记录） | `UNVERIFIED`（未获创作者授权前不擅自 `toy update`） |
