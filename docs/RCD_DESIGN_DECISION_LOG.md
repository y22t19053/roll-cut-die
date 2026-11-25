# RCD_DESIGN_DECISION_LOG — 设计决策总表与争议裁决录

> 建立日期：2026-11-25  
> 原始逐条历史全集（严禁覆盖或删减）：`docs/RCD_DECISION_LOG.md`（共 1,028 行，完整保留 `D-001` 至 `D-072` 实测数据与作者原话）  
> 本档案定位：对 `D-001`–`D-072` 及接管期新裁决（`D-073`–`D-075`）按**「已确定基线 · 已否决方案 · 未决争议」**进行结构化总览，供主控与三路 Codex 执行前快速检索。

---

## 1. 已确定核心决策（CONFIRMED BASELINES）

| 决策锚点 | 决策结论 | 决策原因（Load-Bearing Rationale） | 代码 / 提交验证锚点 |
|---|---|---|---|
| **UE → Godot 重建**（圣经 §18 D1） | 旧 Unreal 原型冻结归档，仅继承五条空间与镜头经验，代码与资产零迁移 | 摆脱重资产包袱，用 Godot 4.3 极速迭代确定性 Ghost 物理与 Web/Windows 双端分发 | 首提交 `c3de553`（2026-11-19） |
| **ORBIT 30°/s 镜头基线**（`6bab995` / Mission Brief） | 角色移动耦合摄像机 `ORBIT 30°/s` 角速度与 `LEAN_CARVE = 0.30` 侧倾雕刻感 | 构成 `ROLL` 的核心空间方向张力；若改成普通俯视角角色加震屏，RCD 的方向预判核心即告瓦解 | `scripts/camera/` · `builds/RCD-ORBIT30.exe` |
| **移动 MARK 速度恢复时机**（`7844510`） | 从带初速度的 `MARK` 执行 `CUT` 重拍时，必须等场记板（Slate）释放瞬间才恢复角色移动速度 | 避免打板动画期间角色偷跑失控；保证物理确定性（理论滑行 `0.171111m`，实测 `0.171112m`） | 提交 `7844510` · `tests/run_all.gd` (`mark` 22/22) |
| **Ghost 物理碰撞隔离** | 过去成功 Take 生成的 Ghost 与当前玩家发生刚体/胶囊碰撞，但 Ghost 彼此穿透不互撞、不改全局开关 | 防止多条历史 Ghost 互相卡死导致后续时间轴雪崩失真，确保玩家可通过观察预测每条 Ghost 精确到帧的落点 | `scripts/ghost/` · `tests/` (`ghost` 47/47) |
| **分级资源与死亡规则**（Stage Plan） | 难度梯度由 MARK/CUT 配额与死亡惩罚定义：Novice（`6/3`，死亡免费自动退回）、Expert（`6/3`，死亡强制进剪辑台消耗 CUT）、Master（`3/2`） | 让新玩家先学会观察 Ghost，再在高难度下把 MARK/CUT 变成真正的片场预算博弈 | `scripts/relay/relay_rules.gd` · `cutting_desk.gd` |
| **16:9 统一取景与横屏锁定**（`D-069`） | 桌面与移动端统一固定逻辑画布 `1600×900`（`53°–55°` FOV / `12m` 视距） | 「给手机换一套镜头等于给手机换一套规则」——视野半径本身就是玩家预判 Ghost 与轨道车的玩法标尺 | `project.godot` · `scripts/relay/touch_pad.gd` |
| **虚拟触控板默认 `"auto"`**（`D-070`） | `touch_pad` 设置支持 `"auto" / "on" / "off"`，默认 `"auto"`（PC 键鼠完全隐藏，触摸屏自动显示），局内 ESC 与标题设置面板双向同步 | 解决 PC 玩家屏幕上出现冗余虚拟摇杆破坏画面沉浸感的问题，同时保留触屏笔记本/特殊机型的手动开关逃生门 | `scripts/relay/touch_pad.gd` · `tests/` (`touch_pad` 53/53) |
| **商店视觉物料剥离运行包**（`D-071`） | 导出预设 `exclude_filter` 排除 `visual/*` | 封面、胶囊图与 TOY 海报并非运行时资源；剔除后 `index.pck` 从 `23.08 MB` 降至 `20.33 MB`，零风险瘦身 | `export_presets.cfg` |
| **开发桥接 Autoload 出包剥离流程**（`D-072`） | 仓库保留 `McpInteractionServer`，正式导出前后强制夹跑 `tools/strip_dev_autoload.py --strip` 与 `--restore` | `godot-bridge` 每次交互运行会自动写回该 Autoload；直接从仓库删行会导致下次测试后静默回归 Web 端 `File not found` 报错 | `tools/strip_dev_autoload.py` · `docs/WORKFLOW_GUIDE.md` |
| **片场标准术语锁定** | 固化 `TAKE` / `NG` / `CUT` / `MARK` / `MEAL BREAK` / `COMPANY MOVE` / `LOCAL MOVE` / `SET CHANGE (REDRESS)` / `WRAP` / `MAGIC HOUR` / `OUT OF FRAME` | 让系统反馈与片场叙事合一；严禁把 `Company Move` 拼错成 `Compound Move`，严禁把 `Magic Hour` 泛化为整个游戏代称 | `docs/RCD_MASTER_PROJECT_CONTEXT.md` §4 |
| **D-073 · 研发主控切换与三路 Codex 协作制**（本次接管） | Gemini 4 Carbon 担任唯一研发主控；Claude 退出固定研发编制；工程执行交由三路职责解耦、Git Worktree 物理隔离的 Codex CLI 执行端（A 核心机制 / B 界面美术 / C 测试与独立审查） | 消除多智能体在同一工作树并发改坏场景的冲突（当前脏 `master` 混杂两条流即为前车之鉴），建立可验证、可回滚的工业级流水线 | `docs/RCD_MULTI_AGENT_OPERATIONS.md` |
| **D-074 · 脏主工作区止血原则**（本次接管） | 在未将脏 `master` 的「TOY 计分桥接」与「Free-Blocking 残留（含 `title_screen.gd:437` 分叉）」拆入独立干净分支前，禁止从 `master` 导出覆盖任何构建 | 保护线上已参赛版本与本地唯一构建基线，杜绝新开局与续档进入不同场景的致命割裂 | `docs/RCD_ENGINEERING_STATUS.md` §2 |
| **D-075 · 主菜单去原型化与片场物质化 UI 方向**（本次接管） | 主菜单升级拒绝赛博霓虹、毛玻璃卡片和单张 AI 死图底板；确立以**片场通告单（Call Sheet）、场记板（Clapperboard）、遮光旗与实景摄影棚深度**为核心的 Godot 原生可交互界面 | 让玩家从打开标题页第一秒就进入「片场重拍」的物质语境，同时完整保留全部 10 项既有交互功能与键鼠/双语无障碍体验 | `docs/RCD_CURRENT_ROADMAP.md` · Stage E 计划 |

---

## 2. 已被否决或废弃的方案（REJECTED / SUPERSEDED）

| 被否决方案 | 否决原因 |
|---|---|
| **移动端竖屏专属拉远相机（16m 视距）**（`D-069` 否决） | 创作者明确拍板「肯定横屏玩」，且改动视距会破坏横屏 16:9 下经过精确调校的走廊视野与碰撞反应时间。 |
| **PC 端默认常驻显示虚拟触控摇杆**（`D-070` 修正） | 创作者实测反馈 PC 端看到虚拟按键极度难受；改为 `"auto"` 按硬件触摸能力自动显隐。 |
| **从仓库永久删除 `McpInteractionServer` 行**（`D-072` 否决） | 删除后每次用 `godot_run_project` 跑交互测试都会被插件重新注入，造成工作区永久脏污与人工遗忘回归；改用导出脚本夹层处理。 |
| **普通俯视角移动 + 纯视觉震屏替代 `ORBIT 30°/s`** | 会彻底摧毁 `ROLL` 机制中「身体朝向、镜头旋转与空间参照物动态咬合」的核心手感辨识度。 |
| **每次失败 Take 都永久生成致命 Ghost** | 会导致新手在同一咽喉点陷入越死越堵的恶性死锁；失败 Take 仅在受控的 `Outtakes`（如无害视觉回声 `tools/outtake_echo.tscn`，最多保留 1 条且可开关）或特定规则下审慎利用。 |
| **无预警的「摄影大叔踢人出局」纯惩罚机制** | 违反公平与可预测死因原则；若未来实装 `OUT OF FRAME`，必须具备清晰前摇预警，并提供声音/脚步返回路径或 `CUT BACK` 逃生手段。 |
| **将全部系统按钮强行替换为生僻电影黑话** | 过度包装会损害新玩家首局理解；术语必须服务于直觉认知（如 `New Game` / `Settings` 保持清晰可读，机制节点用 `TAKE / CUT / MARK / NG / WRAP`）。 |
| **直接投递禁用生成式 AI 的赛事（Finish Your Game 2026 / PROCJAM / MFG Gambler's Jam）** | 项目诚实披露使用了本地 SDXL（RealVisXL V5）生成地面/墙面/钢材贴图与商店封面，上述三个赛事规则明确拒绝含生成式 AI 作品，强投会导致违规下架。 |
| **沿用 2026-11-14 旧版 `Phase 0–10` 战役路线图作为当前主计划** | `docs/RCD_DEVELOPMENT_ROADMAP.md` 写于 Git 建仓前，面向旧侦探长线战役，已无法反映当前 `relay` 主线与四大赛事后的真实工程重点（原文件保留备查，由 `docs/RCD_CURRENT_ROADMAP.md` 接替）。 |

---

## 3. 尚未解决的设计与工程争议（OPEN CONTROVERSIES & PENDING DECISIONS）

### C-01 · 原地静止 Ghost 出生点连续碰撞死循环（高优待决）
- **争议焦点**：当玩家在某条成功/记录段起点几乎未发生位移，生成的静止 Ghost 会堵死出生点，触发高达 20 次连环出生暴毙（见 Mnemon 审计文档 `36638903`）。
- **候选方案对比**：
  - *方案 1（时间宽限窗）*：每次开拍/重拍前 `0.60–0.75s` 赋予当前玩家对历史 Ghost 的短暂穿透保护（视觉半透明闪烁提示）。优点：不丢弃任何历史记录；代价：极短距离起点博弈时有半秒无碰撞窗口。
  - *方案 2（最小位移门槛）*：总有效位移 `< 0.5m` 的轨迹降级为非实体胶片残影（不挂载物理碰撞层）。优点：彻底根除出生点静物堵门；代价：少了一条静态路障策略。
- **主控倾向**：优先在独立分支实测**「出生点半径 `0.6m` 内 + 开拍前 `0.65s` 双条件穿透保护」**，兼顾不丢历史 Take 与零出生暴毙。

### C-02 · 单局标准长度：`3 Acts × 2 Sets (6 景)` vs `4 Acts × 3 Sets (12 景)`
- **争议焦点**：`docs/RCD_MISSION_BRIEF.md` 与 `docs/PROJECT_STATUS.md` 定义单局目标为 `4 Acts × 3 Sets = 12 Sets`（6–9 分钟），但 `docs/design/RCD_ROOM_RELAY_STAGE_PLAN.md` 与 `relay_rules.gd` 实装参数已收敛为 `MODULES = 6`（`ACTS = 3, SETS_PER_ACT = 2`），以匹配创作者「短平快、高密度」的体感要求。
- **待裁决动作**：在冲刺 1 核对 `relay_rules.gd` 与 `blocking_run.gd` 实测单局时长，将文档口径与难度曲线正式统一，消除双轨描述。

### C-03 · `relay`（参数化点阵快切）与 `free-blocking`（手搭摄影棚自由选机位）的合流关系
- **争议焦点**：`master` 主线跑的是稳定成熟的 `scenes/relay/run.tscn`，而 `free-blocking-sets` 分支（`28a8e6b`）与脏工作区正在推进带 `Meal Break`、`Company Move` 和自由机位覆盖（Coverage）的 `blocking.tscn`。
- **主控裁决路线**：**双轨隔离推进，禁止硬切覆盖**——主菜单默认 `New Game` 先恢复指向经过 646 断言与线上赛事验证的 `run.tscn`；`free-blocking` 在独立分支打磨成熟后，作为可选「自由调度模式（Studio Blocking）」或下一大版本升级合入。

### C-04 · 地图翻景（Redress / Set Change）与非正交拼接后的 Ghost 坐标基准
- **争议焦点**：当场地发生 180° 翻转、局部重搭或未来引入 30°/45°/60°/120° 多出口拼接时，历史 Ghost 应当**锁死录制时的绝对世界坐标**（哪怕穿墙/悬空也要忠实重演当时的物理空间），还是**跟随片场局部坐标系一起旋转变换**？
- **当前原则**：基础规则优先保护**录制时的真实世界轨迹**；若特殊翻景机关需要局部坐标跟随，必须作为显式标记的特殊片场设备单独定义，严禁暗中篡改底层 Ghost 坐标系。
