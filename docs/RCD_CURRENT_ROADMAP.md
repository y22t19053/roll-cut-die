# RCD_CURRENT_ROADMAP — 当前研发阶段、冲刺路线与关键时间窗

> 更新日期：2026-11-25  
> 演进说明：本文件替代早期 `docs/RCD_DEVELOPMENT_ROADMAP.md`（2026-11-14 前 Git 时代草案），作为 Gemini 4 Carbon 主控接管后的现行滚动研发总纲。

---

## 1. 当前所处阶段定位

- **已完成**：**阶段 A（项目完整审计）· 阶段 B（本地生产能力审计）· 阶段 C（项目历史与成果恢复）· 阶段 D（三路 Codex 并发隔离验证）· 八大核心项目档案建档**。
- **当前主线**：Sprint 1–4 已合入。Sprint 5 已启动，基线为 `master@c46ca46`，Godot 回归门槛为 815 条断言。

---

## 2. 关键外部截止日期与线上包冻结红线

当前 `itch.io`（项目 ID `5420775`）正处于四场国际 Game Jam 公开评审期，**未经创作者明确指令，严禁覆盖线上构建或改动公开仓库破坏参赛链接**：

| 日期（Asia/Shanghai） | 外部事件 / 里程碑 | 研发约束与动作策略 |
|---|---|---|
| **2026-11-29** | **Tiny Loop Jam 2026** 截止/评审 | 最近到期赛事；线上 itch Windows/Web 包保持零破坏冻结 |
| **2026-12-01 / 12-02** | **GitHub Game Off 2026**（主题 `SHIFT`）截止 | 保持 `github.com/y22t19053/roll-cut-die` 公开可读，公开构建更新须由创作者批准 |
| **2026-12-03** | **Places That Shouldn't Exist** 截止 | 保持 itch Windows 可执行 zip 稳定可用 |
| **2026-12-14** | **Mauspi Lab Jam #2 · ONE MORE TRY!** 截止 | 已获主办方长评背书与 `Mauspi.com` 入驻邀请；评审期后可评估合并 UI 大改版做公开大版本更新 |
| **待创作者确认** | **Bilibili TOY（`58061569920000`）版本更新** | 本地已完成 `toy_bridge.gd` 每日排行榜与 `strip_dev_autoload.py` 剥离工具，待收口验收并获批准后决定是否 `toy update` |

---

## 3. 滚动冲刺计划（Rolling Sprints）

### Sprint 1 · Completed

新游戏、日挑与续档统一进入 Relay；同位出生豁免保护重拍，中途 Ghost 碰撞保持有效。west-trial 夹具与 Dummy / ObjectDB 清理已合入。主线固定四幕十二棚，Free-Blocking 增量已独立保全。

### Sprint 2 · Completed

`89b6451` 合入 Brutalist Call Sheet 标题与 NightStage3D 三重曝光舞台。`4f0f1ea` 修正双语数组类型，并收录中英文标题、设置和制作名单的实机截图。

### Sprint 3 · Merged

在暂停、设置、HUD、抽卡、放饭和结算间统一通告单排版。在 CUT 中以 Steenbeck 放大镜呈现回退点、Take 与预算，保留中央赛道视野。验收覆盖中英切换、焦点、手工通告单追加名次及关闭面板后的输入恢复。

### Sprint 4 · Merged

制作 22,050 Hz D 小调推进型配乐与动作 Foley / FX。按 `visual/DEAI_PLAN.md` #1–#6 实装场务注视、远端退场、纸面划改、道具偏摆、静置低语与后段灯闪。用五族房间回归验证重放和判定，再用实机试听与截图核验表现。

### Sprint 5 · Active

| 编号 | 目标 | 基线时状态 | 验收要点 |
|---|---|---|---|
| 1 | 互联摄影棚 | 已合入 `master`（`46cef17`、`b394cc1`） | 走回旧棚是合法状态：每棚一套半开 Take 区间，旧棚 Ghost 留在自己录制的棚里；V2 存档记录位置与朝向，V1 真实存档仍能载入。 |
| 2 | 新机关与片场道具 | 已合入 `master`（`ff813cc`、`d7832b7`） | 道具架 / 摇臂摄影机 / 备用胶卷 / 场记板曝光四类机关，双语预警 0.9 秒，判定可重复，Ghost 被拍到会变亮。 |
| 3 | OUT OF FRAME 与 CUT 脱困 | 已合入 `master`（Codex E `7fe4820`、`8afa423`） | 同一 leg 第 3 次 NG 触发 2.5 秒可操作预警；过线或付费 CUT BACK 回 MARK 化解。脱景不扣光量，固定外景镜头、片场远景音与历史脚步引回 1.2 米缺口；无 CUT 必须步行返回。见 D-077。主控实机复核：3 次 NG → WARN → OUT（`(1.6, 0.05, -5.2)`，CUT 存量不变）→ 台口可自由走到 `z=-8.65` → 走回取景框即恢复 IN；`cut_back()` 回 MARK `(0,0.05,0)` 且 CUT 3→2。 |
| 4 | Free-Blocking 整合 | 已合入候选（`6fae059`） | `scripts/relay/h_gantry.gd` 双层灯架作为几何件入主仓，垂直行走（`player.vertical_walk`）与桥上历史轨迹重放由 `tests/test_gantry.gd` 覆盖；尚未作为 Relay 房间类型接入。 |
| 5 | WRAP·Final Cut | 已合入 `master`（`6db7bb8`、`bbd19c3`） | 12.60 秒十拍过场，剪影碎片来自本局真实轨迹与废条；Relay 终局不再依赖案件报告，判词由本局账本自裁（D-076）。 |

Sprint 5 门禁：`tools/verify_all.py` 为唯一验收，1,267 条 Godot 断言 + 31 项 Python 全过，`mesh_get_surface_count` 噪声预算 1。

### Sprint 6 · Active

基线 `master@33f6031`，门禁断言 1,267。主题：**把摄影棚从「连起来的一条走廊」变成「可以走出画外的片场」**——越界不再是墙，双层空间进正篇，声音按放映阶段分层。

| 编号 | 目标 | 归属 | 验收要点 |
|---|---|---|---|
| 1 | OUT OF FRAME 出画与 `CUT BACK` 脱困 | 已合入 `master`（Codex E `8afa423`） | 台口不再是一撞即停的空气墙：可以走出取景框站在背光的台口，也能自己走回来；同一 leg 第三次 NG 前有 2.5 秒双语前摇，过线或 CUT 可化解（沿用 §2 红线：先有清晰前摇，再有惩罚）；脱景时按 CUT 必回最近 MARK（消耗一次），无 CUT 只能步行返回，任何路径都不产生软锁。实机截图 `visual/preview/sprint6_live_{warn,out,return}.png`。 |
| 2 | 双层灯架成为 Relay 房间类型 | 已合入 `master`（Codex B `ef0b447`，本主控补布景 `9aa79ad` 之后） | `h_gantry.gd` 的几何升级为 `relay_rooms.gd` 的房间族之一（`gantry_room.gd` + `kind = "gantry"`，26 m 甲板，固定在第 7 个门位），斜梯可走上 2.5 m 桥面，桥上留下可重放 Ghost 轨迹、读档恢复高度；进棚即切重力行走（`player.vertical_walk`），原五族房间的判定与外观不回归。实机截图 `visual/preview/sprint6_live_gantry_{approach,bridge}.png`。 |
| 3 | 独立验收与档案同步 | 已合入 `master`（Codex C `d79e8e6`） | `tools/verify_branch.py` 可在任意支上复现门禁；十二棚接缝、棚外移动与出画恢复都进套件（`tests/test_no_softlock.gd` 把「回到甲板高度」当不变量——Relay 钉高度不跑重力，`is_on_floor()` 恒假，见 D-078）。修完共 1,745 条断言。 |
| 4 | 局内配乐分层 | 已合入 `master`（Codex D + 本主控合并裁决） | 只动 `scripts/relay/relay_sound.gd`：混音决策抽成纯函数 `_mix_targets(act, danger, final_sprint, ducked, ending, still_seconds, reduce_motion, cue_duck_db, out_of_frame)`，五态（起步/推进/危险/冲线/收工）各有可测的 dB 目标；不新增资源文件、不改 `relay_run.gd` 调用面。合并时把 E 的出画鸭子改写成 `out_of_frame` 参数（整体 −18 dB、片场人声抬到 −26 dB）。 |

Sprint 6 门禁：`tools/verify_all.py` 全过，**1,745 条 Godot 断言 + 31 项 Python**，`mesh_get_surface_count` 噪声预算 1，每个交付端附实机截图。


### Sprint 7 · Active

基线 `master@2b0b7c5`，门禁断言 1,745。主题：**让一局更长、让捡到的东西有去处**——创作者试玩的原话是「地图太小、流程太短且容易」「不明白为什么收集物品，归档缺少意义」。这一轮把 12 棚推到 16 棚并给每幕一个收尾长棚；把剩下的标记/喊卡折算成成片质量；把跨局档案从四个数字变成有等级的档案柜。

| 编号 | 目标 | 归属 | 验收要点 |
|---|---|---|---|
| 1 | 16 棚与每幕收尾长棚 | Codex G | `const MODULES := 16`、`const SETS_PER_ACT := 4`；每幕最后一棚（`main_index` 3/7/11/15）固定为 26 m 灯架棚（`GANTRY_SLOTS`），一局走过 4 个长棚；HUD `SET n/16`、结算与存档长度字段随之正确；旧 12 棚存档能读、不崩。 |
| 2 | 收集物折算成片质量 | Codex F | 新增纯函数模块 `scripts/relay/craft.gd`：`shoot(marks_left, cuts_left, deaths) -> Dictionary`（`bonus` / `tier` / 双语一行）；`_show_sheet` 的通告单上多一行「省下的标记与喊卡」，并计入 `score_info`；第一次捡到标记给一次「标记＝一条命」的提示。不新增按键、不改 `Rules` 预算。 |
| 3 | 归档有等级、结局有分布 | Codex D | `RelayRules` meta 升到 v2（向后兼容 v1）：累计 `marks_total` / `cuts_total` 与三结局计数 `truth` / `coverup` / `frameup`；新增纯函数 `archive_rank(total) -> int` 与 `merge_meta(raw) -> Dictionary`；标题页 CAREER 区显示档案等级与结局分布。 |
| 4 | 独立验收与档案同步 | Codex C | `tools/verify_branch.py` 覆盖新支；`tests/test_sprint7_guard.gd` 用防御式断言（模块缺失即跳过）钉住：16 棚、4 个灯架棚位、`craft.shoot` 与 `archive_rank` 的纯函数行为、长局不产生软锁；四份 living 文档同步。 |

Sprint 7 门禁：`tools/verify_all.py` 全过，断言数只增不减，`mesh_get_surface_count` 噪声预算 1，每个交付端附实机截图。

**收尾结果（2026-11-25 晚）**：四条全部合入 `master`，门禁 **2,107 条 Godot 断言 + 31 项 Python**、噪声 1、`exit 0`。
- #1 已合入 `3d05797` / merge `0c6568e`：`MODULES := 16`、`SETS_PER_ACT := 4`、`GANTRY_SLOTS := [3,7,11,15]`；实测总长 **212.0 m**（12×9 + 4×26），四个灯架棚双门与末端封口由 `tests/test_run_length.gd` 钉住。
- #2 已合入 `430d209`：`scripts/relay/craft.gd`；`Craft.shoot(3,2,0).bonus == 80`。主控补修：通告单那行原本中英同排，现在是单语言（`score_line(..., zh: bool)`），实测截图 `visual/preview/sprint7_live_answer_print.png`。
- #3 已合入 `e7ab2c1` / merge `092d872`：meta v2；主控补上真正的接线——`_settle_sheet` 调 `Rules.record_run_full(..., marks_earned, cuts_used, verdict)`，`marks_earned` 在五处拾取点累加并随存档存取；档案升级时通告单多一行「档案等级：X」。实机：`verdict=bury_registered`、meta `runs 48→49 / marks_total 0→5 / cuts_total 0→1 / coverup 0→1`；标题页显示「档案 · 第 1 级 场记板」「真相 0 / 掩盖 1 / 栽赃 2」。
- #4 已合入 `5e2576d` / merge `415a5ef`：`tests/test_sprint7_guard.gd` 53 条防御式断言（G/F/D 未合入时自动跳过）。


真人盲测、真窗口焦点、移动浏览器和外部线上包仍按工程状态表 UNV-01 至 UNV-04 跟踪。赛事和平台更新另行取得创作者授权。

### Sprint 8 · Active

基线 `master@34306c9`，门禁断言 2,107。主题：**把新动作教出去，把下一把的理由写出来**——序章只教了七种基本棚型，Sprint 5–7 加进来的四件事（片场机关、双层灯架、出画前摇、终局剪辑）玩家是冷启动撞上的；而输掉一局之后，结算单只说这一局值多少分，不说下一局该改什么。

| 编号 | 目标 | 归属 | 验收要点 |
|---|---|---|---|
| 1 | 四个新动作各教一次 | Codex H | 新增 `scripts/relay/phrasebook.gd`：四类一次性教学（首次遇到机关 / 首次进灯架棚 / 首次触发出画前摇 / 首次播完终局剪辑），每类只在该玩家档案里出现一次，跨局记忆存 `user://rcd/relay_lessons.cfg`；纯函数 `seen(kind, path)` / `mark(kind, path) -> bool` / `line(kind, zh) -> String` 供断言；不得与既有 `_hint` 键重复播报、不得叠两条通知。 |
| 2 | 结算单给「下一把」 | Codex F | 新增纯函数模块 `scripts/relay/next_move.gd`：`line(sets_done, modules, won, tier, highest_unlocked, zh) -> String`——输在第 N 棚说「差 M 棚」、赢下当前档说「下一档已解锁」、已在最高档说「比上一把更干净」；`_settle_sheet` 追加一行，`score_info` 加 `next_move` 键。 |
| 3 | 标题页把进度说清 | Codex D | 标题页难度区显示解锁条件与本人最远进度（「EXPERT 解锁：通关 NOVICE（你最远 N/16）」），档案区显示下一级还差多少枚标记（`archive_next_gap(marks_total) -> int`）；纯函数可断言，v1/v2 存档都能读。 |
| 4 | 独立验收与档案同步 | Codex C | `tools/verify_branch.py` 覆盖新支；`tests/test_sprint8_guard.gd` 防御式断言（模块缺失即跳过）钉住：一次性教学只播一次、`next_move.line` 的分支、`archive_next_gap` 的边界；四份 living 文档同步。 |

Sprint 8 门禁：`tools/verify_all.py` 全过，断言数只增不减，`mesh_get_surface_count` 噪声预算 1，每个交付端附实机截图。
