# RCD_CURRENT_ROADMAP — 当前研发阶段、冲刺路线与关键时间窗

> 更新日期：2026-11-25  
> 演进说明：本文件替代早期 `docs/RCD_DEVELOPMENT_ROADMAP.md`（2026-11-14 前 Git 时代草案），作为 Gemini 4 Carbon 主控接管后的现行滚动研发总纲。

---

## 1. 当前所处阶段定位

- **已完成**：**阶段 A（项目完整审计）· 阶段 B（本地生产能力审计）· 阶段 C（项目历史与成果恢复）· 阶段 D（三路 Codex 并发隔离验证）· 八大核心项目档案建档**。
- **当前即将启动**：**冲刺 1（主工作区脏改动无损拆分 + P0 入口修复）** 与 **冲刺 2 / 阶段 E（RCD 独立游戏级主菜单视觉身份重构与 Godot 实机可交互落地）**。

---

## 2. 关键外部截止日期与线上包冻结红线

当前 `itch.io`（项目 ID `5420775`）正处于四场国际 Game Jam 公开评审期，**未经创作者明确指令，严禁覆盖线上构建或改动公开仓库破坏参赛链接**：

| 日期（Asia/Shanghai） | 外部事件 / 里程碑 | 研发约束与动作策略 |
|---|---|---|
| **2026-11-29** | **Tiny Loop Jam 2026** 截止/评审 | 最近到期赛事；线上 itch Windows/Web 包保持零破坏冻结 |
| **2026-12-01 / 12-02** | **GitHub Game Off 2026**（主题 `SHIFT`）截止 | 保持 `github.com/y22t19053/roll-cut-die` 公开可读，不在未清理脏树前向 `master` 盲推半成品 |
| **2026-12-03** | **Places That Shouldn't Exist** 截止 | 保持 itch Windows 可执行 zip 稳定可用 |
| **2026-12-14** | **Mauspi Lab Jam #2 · ONE MORE TRY!** 截止 | 已获主办方长评背书与 `Mauspi.com` 入驻邀请；评审期后可评估合并 UI 大改版做公开大版本更新 |
| **待创作者确认** | **Bilibili TOY（`58061569920000`）版本更新** | 本地已完成 `toy_bridge.gd` 每日排行榜与 `strip_dev_autoload.py` 剥离工具，待收口验收并获批准后决定是否 `toy update` |

---

## 3. 滚动冲刺计划（Rolling Sprints）

### Sprint 1 — 工程基线收口、脏树无损归档与核心卫生修复（最高优先阻断清理）
1. **无损拆分主工作区脏改动**：
   - 将流 B（`scenes/relay/blocking.tscn`、`blocking_*.gd`、`h_gantry.gd`、`player.gd` 的 `vertical_walk`）完整保全至 `free-blocking` 实验分支/worktree，绝不丢失 `h_gantry.gd`（`8,564 B`）等唯一增量代码。
   - 将流 A（`toy_bridge.gd`、`test_toy_score.gd`、每日积分与 Web Shell 补丁）整理至独立洁净特性分支并通过全量回归。
2. **修复 `BUG-01`（P0 主菜单入口分叉）**：恢复主线 `_on_new_game()` 指向正式 `res://scenes/relay/run.tscn`，若需保留 `free-blocking` 开发入口则显式隔离至实验模式或分支，消除「新游戏进 Blocking、续档/日挑进 Relay」的割裂。
3. **修复 `BUG-03` & `BUG-04`（测试与引擎卫生）**：修复 `tests/test_west_trial_prepare.py` 过时配置断言（`28/30` → `30/30`），定位并消除 Headless `mesh_get_surface_count` 空网格报错与退出时 `ObjectDB instances leaked` 告警。
4. **修复 `BUG-02`（P1 静止 Ghost 出生点秒杀循环）**：实装出生点安全宽限或极短零位移废片过滤，并补齐回归测试断言。

### Sprint 2（阶段 E 第一交付）— 主菜单独立游戏级 UI 艺术指导重构
1. **视觉研究与三套差异化方案验证**：
   - 方案 I：**《夜棚场记单 / Brutalist Call Sheet》**（受 *Control* 大字号几何无衬线权威排版 + *Papers, Please / Obra Dinn* 纸本印章档案启发，左印务通告单 + 右实时 3D 绿幕夜棚与三次曝光 Ghost 折返实景）。
   - 方案 II：**《剪辑台看片机 / Steenbeck Lightbox》**（受 *Inscryption / Signalis* 器物化界面启发，暗房看片台灯箱、胶片齿孔时间码标尺、物理拨杆切换难度与语言）。
   - 方案 III：**《高反差片场剪影 / Stark Soundstage Stencil》**（受 *Killer7 / INSIDE* 强构图剪影与极简戏剧张力启发，巨幅斜切字形投影与聚光灯舞台动线）。
2. **主控内部审查裁决与 Godot 实机可交互实现**：
   - 100% 保留并升级九大核心交互功能：继续这一卷（最近进度）、新游戏、难度选择（淘汰原生简陋 `OptionButton`，改为片场档位选择器）、生涯跑卷统计、每日挑战（含种子与排行榜名次）、减弱动态效果开关与设置、制作名单、退出、中英双语即时切换（F2 + 界面开关），完整支持纯键盘/手柄焦点链与鼠标操作。
   - 接入真实 3D 摄影棚景深舞台或高精度分层片场视差（含 `reduce_motion` 静态构图帧降级保障），彻底告别原型级平面几何色块。
   - 通过 `godot_run_project` + `godot_screenshot` 截取中英双语、有存档/无存档、减弱动效开/关等多状态实机画面验收。

### Sprint 3 — 全流程片场 UI 视觉语言贯通
将主菜单确立的视觉母题（字体层级、纸张/场记板材质、印章/胶带微偏角去 AI 味规范）逐步延伸至：
1. **暂停菜单（`pause_menu.gd`）与设置面板（`settings_panel.gd`）**
2. **拍摄中 HUD（`hud.gd`）与物理场记板（`slate_board.gd` / `cut_panel.gd`）**
3. **剪辑台 / 放饭（`cutting_desk.gd` / Meal Break）与转场（Company Move）**
4. **拍摄事故反馈（NG / TAKE FAILED）与收工结算单（`relay_score.gd` / WRAP）**

### Sprint 4 — 去 AI 味片场活人感（`visual/DEAI_PLAN.md`）与可理解性验证
- 落地 `DEAI_PLAN.md` 中高性价比表现层细节（场务 2.5m 转头注视、远端下班背影、通告单微倾角与手写划改线、静置远景低语层），不触碰已平衡的物理碰撞判定。
- 建立可复现的实机镜头巡检与新玩家首局可读性验证包。

---

## 4. 当前阻断与核心风险（Blockers & Guards）

- **阻断 1（即将于 Sprint 1 解除）**：主工作区 `master` 含 9 处修改 + 7 处未跟踪混杂文件，且 `title_screen.gd:437` 存在入口分叉 Bug；在完成分支剥离前禁止直接在主工作树叠加 UI 大改代码（UI 开发一律先走独立 `codex-b` Worktree）。
- **阻断 2（口径对齐）**：`6 棚（3 Acts × 2 Sets）` 与旧文档 `12 棚（4 Acts × 3 Sets）` 需在文档与 UI 文案中统一以当前 `relay` 实装常量（`RunScript.MODULES`）动态读取，杜绝硬编码数字失真。
- **合规护栏**：严禁未经批准触发外部平台发布、比赛提交、付费 API 消费或删除 `builds/` 下的唯一历史版本。
