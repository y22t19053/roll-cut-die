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
| 3 | OUT OF FRAME 与 CUT 脱困 | 部分合入（回程已通，越界仍待做） | 已能走回旧棚并看到过去的穿越路线；玩家走出取景框的越界判定与 `CUT BACK` 逃生尚未实装（依赖 `docs/RCD_DESIGN_DECISION_LOG.md` §2 的预警红线）。 |
| 4 | Free-Blocking 整合 | 已合入候选（`6fae059`） | `scripts/relay/h_gantry.gd` 双层灯架作为几何件入主仓，垂直行走（`player.vertical_walk`）与桥上历史轨迹重放由 `tests/test_gantry.gd` 覆盖；尚未作为 Relay 房间类型接入。 |
| 5 | WRAP·Final Cut | 已合入 `master`（`6db7bb8`、`bbd19c3`） | 12.60 秒十拍过场，剪影碎片来自本局真实轨迹与废条；Relay 终局不再依赖案件报告，判词由本局账本自裁（D-076）。 |

Sprint 5 门禁：`tools/verify_all.py` 为唯一验收，1,267 条 Godot 断言 + 31 项 Python 全过，`mesh_get_surface_count` 噪声预算 1。

### Sprint 6 · Active

基线 `master@33f6031`，门禁断言 1,267。主题：**把摄影棚从「连起来的一条走廊」变成「可以走出画外的片场」**——越界不再是墙，双层空间进正篇，声音按放映阶段分层。

| 编号 | 目标 | 归属 | 验收要点 |
|---|---|---|---|
| 1 | OUT OF FRAME 出画与 `CUT BACK` 脱困 | Codex A（`codex-a/sprint6-frame`） | 棚侧边不再是一撞即停的空气墙：可以走出取景框站在背光的台口，也能自己走回来；出画 0.9 秒后有双语前摇提示（沿用 §2 红线：先有清晰前摇，再有惩罚）；出画状态下按 CUT 必定回到最近的合法位（`CUT BACK`，消耗一次 CUT），任何路径都不产生软锁。 |
| 2 | 双层灯架成为 Relay 房间类型 | Codex B（`codex-b/sprint6-gantry`） | `h_gantry.gd` 的几何升级为 `relay_rooms.gd` 的房间族之一（新 kind），斜梯可走上桥面，桥上留下可重放的 Ghost 轨迹；原有五族房间的判定与外观不回归。 |
| 3 | 独立验收与档案同步 | Codex C（`codex-c/sprint6-guard`） | 新机制都有 headless 断言（出画判定、CUT BACK 回位、gantry 房间可走、桥上轨迹重放）；`tools/verify_all.py` 仍为唯一门禁；档案按实际改动同步。 |
| 4 | 局内配乐分层 | Codex D（`codex-d/sprint6-score`） | 只动 `scripts/relay/relay_sound.gd`：按 act / 危险度 / 收工三段推动配乐，让「推进」「危险」「冲线」听得出差别；不新增资源文件、不改 `relay_run.gd` 的调用面。 |

Sprint 6 门禁：`tools/verify_all.py --baseline 1267` 全过，噪声不超过预算 1；每个交付端附实机截图。


真人盲测、真窗口焦点、移动浏览器和外部线上包仍按工程状态表 UNV-01 至 UNV-04 跟踪。赛事和平台更新另行取得创作者授权。
