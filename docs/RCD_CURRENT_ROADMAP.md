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
| 1 | 互联摄影棚 | 已分支，待验收 | 出口与回程连通，玩家能辨认下一棚入口及过去 Take 的穿越路线。 |
| 2 | 新机关与片场道具 | 已分支，待验收 | 镜头设备、剧组道具与布景联动有可辨认的预警和可重复的判定。 |
| 3 | OUT OF FRAME 与 CUT 脱困 | 待验收 | 玩家能循声或脚步回棚，越界后能用 CUT 回到合法位置。 |
| 4 | Free-Blocking 整合 | 待验证候选 | 以 `h_gantry.gd` 为首个候选，核验垂直行走、历史轨迹及原有 Relay 入口。 |
| 5 | WRAP·Final Cut | 已分支，待验收 | 最终剪辑串联本局真实历史轨迹，玩家能认出各次 Take 对成片的贡献。 |

真人盲测、真窗口焦点、移动浏览器和外部线上包仍按工程状态表 UNV-01 至 UNV-04 跟踪。赛事和平台更新另行取得创作者授权。
