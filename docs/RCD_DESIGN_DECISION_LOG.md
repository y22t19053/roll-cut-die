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
| **D-073 · 研发主控切换与三路 Codex 协作制**（本次接管） | Gemini 4 Carbon 担任唯一研发主控；Claude 退出固定研发编制；工程执行交由三路职责解耦、Git Worktree 物理隔离的 Codex CLI 执行端（A 核心机制 / B 界面美术 / C 测试与独立审查） | 消除多智能体在同一工作树并发改坏场景的冲突（接管时的脏 `master` 混杂两条流即为前车之鉴），建立可验证、可回滚的工业级流水线 | `docs/RCD_MULTI_AGENT_OPERATIONS.md` |
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

## 3. 接管时的争议记录（C-01、C-02 的结案见 §4）

### C-01 · 原地静止 Ghost 出生点连续碰撞死循环（Sprint 1 已结案）
- **争议焦点**：当玩家在某条成功/记录段起点几乎未发生位移，生成的静止 Ghost 会堵死出生点，触发高达 20 次连环出生暴毙（见 Mnemon 审计文档 `36638903`）。
- **候选方案对比**：
  - *方案 1（时间宽限窗）*：每次开拍/重拍前 `0.60–0.75s` 赋予当前玩家对历史 Ghost 的短暂穿透保护（视觉半透明闪烁提示）。优点：不丢弃任何历史记录；代价：极短距离起点博弈时有半秒无碰撞窗口。
  - *方案 2（最小位移门槛）*：总有效位移 `< 0.5m` 的轨迹降级为非实体胶片残影（不挂载物理碰撞层）。优点：彻底根除出生点静物堵门；代价：少了一条静态路障策略。
- **主控倾向**：优先在独立分支实测**「出生点半径 `0.6m` 内 + 开拍前 `0.65s` 双条件穿透保护」**，兼顾不丢历史 Take 与零出生暴毙。

### C-02 · 单局标准长度：`3 Acts × 2 Sets (6 景)` vs `4 Acts × 3 Sets (12 景)`
- **争议焦点**：`docs/RCD_MISSION_BRIEF.md` 与 `docs/PROJECT_STATUS.md` 定义单局目标为 `4 Acts × 3 Sets = 12 Sets`（6–9 分钟），但 `docs/design/RCD_ROOM_RELAY_STAGE_PLAN.md` 与 `relay_rules.gd` 实装参数已收敛为 `MODULES = 6`（`ACTS = 3, SETS_PER_ACT = 2`），以匹配创作者「短平快、高密度」的体感要求。
- **待裁决动作**：在冲刺 1 核对 `relay_rules.gd` 与 `blocking_run.gd` 实测单局时长，将文档口径与难度曲线正式统一，消除双轨描述。

### C-03 · `relay`（参数化点阵快切）与 `free-blocking`（手搭摄影棚自由选机位）的合流关系
- **争议焦点**：`master` 主线跑的是稳定成熟的 `scenes/relay/run.tscn`，而 `free-blocking-sets` 分支（`28a8e6b`）与接管时的脏工作区曾推进带 `Meal Break`、`Company Move` 和自由机位覆盖（Coverage）的 `blocking.tscn`。
- **主控裁决路线**：**双轨隔离推进，禁止硬切覆盖**——主菜单默认 `New Game` 先恢复指向经过 646 断言与线上赛事验证的 `run.tscn`；`free-blocking` 在独立分支打磨成熟后，作为可选「自由调度模式（Studio Blocking）」或下一大版本升级合入。

### C-04 · 地图翻景（Redress / Set Change）与非正交拼接后的 Ghost 坐标基准
- **争议焦点**：当场地发生 180° 翻转、局部重搭或未来引入 30°/45°/60°/120° 多出口拼接时，历史 Ghost 应当**锁死录制时的绝对世界坐标**（哪怕穿墙/悬空也要忠实重演当时的物理空间），还是**跟随片场局部坐标系一起旋转变换**？
- **当前原则**：基础规则优先保护**录制时的真实世界轨迹**；若特殊翻景机关需要局部坐标跟随，必须作为显式标记的特殊片场设备单独定义，严禁暗中篡改底层 Ghost 坐标系。

## 4. 2026-11-25 · Sprint 1–4 裁决

- **C-01、C-02 已结案**。仅同位出生的玩家与该 Ghost 暂时豁免，分开后再相遇仍会 NG。`ecc261d` 覆盖空轨迹与出生重叠。正式 Relay 为四幕、每幕三棚，显示进度读取 RunScript。
- **标题方向已交付**。`89b6451`、`4f0f1ea` 确立印刷通告单与三重曝光的 3D 夜棚；双语标题图见 `visual/preview/`。
- **Sprint 3 局内界面**。抽卡与结算沿用手工通告单。Steenbeck 放大镜在 `Mode.CUT` 标注回退点与耗费，给中央轨迹留出视野。
- **Sprint 4 视听**。22,050 Hz D 小调配乐推动行动节奏，动作由 Foley / FX 标识。静止超过两秒时淡入 −34 dB 剧组低语；DEAI #1–#6 限于表现层，碰撞、计时、库存与抽卡概率沿用主线。
- **交付边界**。三个工作树按文件分工；主控负责合并、Godot 回归和实机视听验收。

## 5. 2026-11-25 · Sprint 5 裁决

- **D-076 · Relay 终局由本局账本自裁**。案件报告只存在于 `scenes/main/main.tscn`，而当前可玩主线是 `scenes/relay/run.tscn`，它从不提交报告，因此 `verdict` 恒为空、`FinalReel.from_run()` 直接返回空字典、12.60 秒的最终剪辑在线上版本里永远播不出来。裁决：外部没给判词时由本局记录自裁——零死亡 `file_closed`（TRUTH），有死亡且用掉过至少一次 `CUT` `bury_registered`（COVER-UP），有死亡但一条没剪 `reframe_held`（FRAME-UP）。动画本身仍不重新判理，只认 `docs/FINAL_CUT_DESIGN.md` §5 的三种结局；`relay` 走独立的 `FinalReel.from_relay()`，不读案件台账，避免上一次案件会话残留的 `FINISHED` 状态改写本局成片。
- **验收口径**。`tools/verify_all.py` 是唯一门禁（Godot 断言 1,267 / Python 31 / 噪声预算 1）；`tests/test_inrun_ui_and_deai.gd::_run_wrap` 在真实 `run.tscn` 上验证「胜利 → 过场起播 → 12.60 秒后交还通告单」的接缝。
- **并行交付**。互联摄影棚（A）、片场机关（B）、H 灯架候选（`6fae059`）、最终剪辑（D）四路各自提交后由主控合并；冲突只落在 `relay_run.gd` 的 `_restart_actors()`、`run_all.gd` 的 mesh 保留钩子与常量/存档字典三处，全部按「A 的每棚区间 + B 的曝光开关 + D 的三键合一」裁决。

## 6. 2026-11-25 · Sprint 6 OUT OF FRAME

- **D-077 · 有预警、可化解的脱景与回剪**。按 IA-16 与 §2 红线，同一 leg 累计第 3 次 NG 后进入 WARN；每 leg 只触发一次，新 leg 重置。2.5 秒只计算正局可操作时间，教学、场记板、死亡冻结、强制剪辑台、暂停、吊索、选棚、通告单与 WRAP 不推进预警。红角脉冲、顶部同时显示中英文及一次性 65.4 Hz 低频声；过线立即取消，WARN 或 OUT 按 C 直接 CUT BACK 至最近 MARK，扣 1 CUT 并计入既有 CUT 账本，不能借用首次免费剪辑。
- **代价与恢复**。预警和脱景本身不改光量、MARK、CUT 或死亡计数；代价是本 leg 继续计时、额外回程距离，或主动支付一次 CUT。OUT 期间不执行棚内危险判定、不能把暗区钉成 MARK。无 CUT 不瞬移，显示 NO CUT LEFT — WALK BACK。回到当前棚合法范围后恢复原相机和声音，继续当前 leg。
- **回程几何与声音**。棚局部后墙 z=-2.94、x=1.0…2.2 开 1.2 米缺口，暗区落点固定为 (1.6, 0.05, -5.2)，增设暗色地板、门楣与地面标记；随棚旋转，六种棚型和两个朝向均以真实玩家碰撞体扫掠验证。OUT 使用独立固定镜头，保留棚轮廓与缺口，不跟随玩家平移。复用 relay_sound 合成播放链，将配乐退远并引入剧组环境声；按本棚历史 Take 的 0.65 米步距抽取节奏，在缺口位置循环播放脚步。没有移动历史时用剧组双拍指路，不伪造历史记录。
- **验证与接缝**。独立 out_of_frame.gd 暴露 advance/state/debug_state/note_ng/resolve/cut_back。relay_run.gd 仅加 23 行接线；relay_rooms.gd 增 17、删 2 行。无头测试通过 1,354 条断言（本模块 87 条）、Python 31 项、stderr_noise=1；窗口预览生成 WARN/OUT 两张实景图。听感和主控实机手感仍需合并端验收。

## 7. 2026-11-25 · Sprint 6 收尾（灯架进正篇、配乐分层、验收口径）

- **D-078 · 灯架是房间族，不是新游戏模式**。`scripts/relay/gantry_room.gd` 把 `h_gantry.gd` 的几何包成 `kind = "gantry"` 的房间（26 m 甲板、2.5 m 桥面、双侧斜梯），由 `relay_rooms.plan()` 固定排在第 7 个门位；`relay_rooms.room_at()` 从「`x / 9` 取整」改成按 `_starts` 起点表倒查，因为这一族比其它族长 17 m。灯架棚内 `player.vertical_walk = true`（换棚即切），甲板有真实碰撞、桥面留下可重放 Ghost 轨迹、读档带回 `y`；棚内不做整体转棚（`_rotate_stage` 跳过），因为高架路线与地面门是固定朝向。原五族房间的判定、外观和 9 m 接缝全部不变。
- **D-079 · 灯架棚的布景在 26 m 尺度上重写，不套用 `_dress()`**。`_dress()` 的所有坐标按 9 m 棚写死（涂装带、场记纸、道具位置），直接套到 26 m 会把东西全堆在西端。新增 `_dress_gantry()` 按棚长布置：两条灯架、箱堆、胶片罐、盘好的电缆、过门旁的场记纸、一条 7.4 m 的涂装带，全部落在 `|z| > 4.4` 或首尾 4 m 之外，绝不进桥面与斜梯的行走范围。灯架族颜色单独取 `GANTRY_INK`，**不进 `SET_INKS`**——那个字典是随机门池的房间来源，混进去会被当成普通 9 m 棚发出来（`tests/test_room_families.gd` 也因此仍然成立）。
- **D-080 · `is_on_floor()` 不是 Relay 的落地不变量**。Relay 在普通棚里每帧把 `player.global_position.y` 向 `floor_height + 0.05` 插值（`vertical_walk = false` 时不跑重力），所以静止玩家的 `is_on_floor()` 恒为 `false`；只有灯架棚（`vertical_walk = true`）才真的站在碰撞体上。Codex C 的 `tests/test_no_softlock.gd` 曾断言「回到地面」，它在 C 分支上从未执行过（`out_of_frame.gd` 不存在时整段跳过），合并 E 后第一次跑就红。裁决：把断言换成真实不变量——回到本棚甲板高度（±0.30）、在棚接缝内、控制权归还、脱景期间 hit 计数为 0。
- **D-081 · 配乐分层走纯函数 + 单一消费点**。`relay_sound._mix_targets(act, danger, final_sprint, ducked, ending, still_seconds, reduce_motion, cue_duck_db, out_of_frame)` 只算 dB 目标和心跳倍率，`_update_mix(delta)` 是唯一消费者；五态（起步/推进/危险/冲线/收工）各有可断言的数值。合并 E 时把出画的鸭子从旧 `_process` 手写混音搬进 `_mix_targets` 的 `out_of_frame` 参数（整体 −18 dB、片场人声抬到 −26 dB），保留「出画时听觉接管」的原意。**D 端没有真机试听**，听感仍待创作者实测。
- **Sprint 6 收尾口径**。`tools/verify_all.py` 全过：1,745 条 Godot 断言 + 31 项 Python，噪声预算 1；实机复核（真窗口 `scenes/relay/run.tscn`，2558×1598）覆盖出画三态、CUT BACK、灯架棚重力行走与两层空间。


## 8. 2026-11-25 · Sprint 7 裁决（长局、成片质量、档案、验收）

- **D-082 · 十六棚，每幕以长棚收尾**。`MODULES := 16`、`SETS_PER_ACT := 4`；每幕最后一棚（main_index 3/7/11/15，`GANTRY_SLOTS`）固定是 26 m 灯架棚，一局走过四个长棚，总长实测 212.0 m（12×9 + 4×26）。理由：创作者反馈「地图太小、流程太短」，而拉长必须靠已有素材——灯架棚是唯一现成的 26 m 房间，且它自带第二层高度，短局印象会被「爬上去」这一下改写。代价是节奏曲线要重排，所以同轮把 `hurry_for(done, total)` 抽成纯函数：每幕基准 1.0 / 1.05 / 1.11 / 1.17，末端两棚抬到 1.2–1.25。`hurry` 在 `relay_rooms.gd` 里是**除数**，数越大机关越快、越难，注释必须写明，否则下一个人会以为它在放宽。
- **D-083 · 剩下的标记与喊卡折成「成片质量」，但不改总分口径**。`scripts/relay/craft.gd::shoot(marks_left, cuts_left, deaths)` 给出 `bonus = min(marks,10)*10 + min(cuts,7)*15 + (deaths==0 ? 20)`，上限 100，档位 clean/steady/scrambled。它只出现在通告单与 `score_info["craft_bonus"]`，**不进入 `total`**：排行榜比的是一局走了多远、死了几次，不是仓库里剩多少，混进去会让「不敢用标记」成为最优解。通告单那一行必须单语言——`score_line(..., zh: bool)`，因为中英同排会把它撑成全页最宽的一行。
- **D-084 · 档案是唯一跨局资产，由本局账本结算**。meta 升 v2：新增 `marks_total` / `cuts_total` / `truth` / `coverup` / `frameup`，v1 文件读得出、新字段补零。接线在主控侧：`_settle_sheet` 调 `Rules.record_run_full(segments.size(), deaths, won, run_seed, marks_earned, cuts_used, verdict if won else "")`；`marks_earned` 是**本局捡到的总数**（五个拾取点累加、随存档存取），与通告单上「手上还剩」的 `mark_stock` 不是一回事。档案等级只在**升级那一刻**多印一行，否则每局都印一次就成了墙纸。实测一段：`runs 48→49`、`marks_total 0→5`、`cuts_total 0→1`、`coverup 0→1`、`verdict=bury_registered`。
- **D-085 · 测试不许写玩家的档案**。`tests/test_inrun_ui_and_deai.gd::_run_wrap` 会真的把一局打到结算，`record_run_full` 于是把测试局记进玩家职业生涯（本轮抓包：三次门禁给真实 meta 加了 2 局、2 胜、3 死、1 个 FRAME-UP）。修法：`RelayRules.recording_enabled` 静态开关 + `set_recording(on)` 函数（静态变量无法经 `preload` 句柄赋值，这是 Godot 4.3 的限制），`tests/run_all.gd` 与 `tests/only.gd` 在开跑前关掉、跑完复原，`record_daily` 只读不写也算关掉。被污染的真实 meta 已按污染前快照还原。
- **Sprint 7 收尾口径**。`tools/verify_all.py` 全过：**2,107 条 Godot 断言 + 31 项 Python**，噪声预算 1，`exit 0`；实机复核（真窗口，2558×1598）覆盖：通告单单语言成片质量行（`visual/preview/sprint7_live_answer_print.png`）、档案升级行、标题页档案等级与三结局分布（`sprint7_live_title_archive.png`）。清理待办：Godot 退出时仍有 `ObjectDB instances leaked at exit` 警告，计入下轮。

## 9. 2026-11-25 · Sprint 8 裁决（教学、下一把、进度、验收）

- **D-086 · 一次性教学必须排队，不能赌播报槽是空的**。`Phrasebook` 的四种教学每档只播一次，播完即写盘；而 Relay 进新棚会立刻播「你来到了棚 N」。两者抢同一个播报槽，谁后到谁留下——教学那一行常常只活了半帧就被盖掉，`mark()` 却已经写过，于是这位玩家这辈子都看不到那条解释。修法：`_queue_teach(kind)` 入队（按 kind 去重），`_physics_process` 在 `_notice_left <= 0.0` 时 `_teach(_teach_queue.pop_front())`，一次只放一条。实机验证：机关教学先播，4 秒后灯架教学接上（`visual/preview/sprint8_live_lesson.png`）。教训是通用的一条——**任何「一生只发生一次」的反馈都不能交给「有空再播」的通道**。
- **D-087 · 结算单的末行要给下一把的理由，标题页要说清解锁差多少**。输掉一局之后玩家最需要知道的不是这一局值多少分，而是差多远、下一档要不要继续磕：`next_move.line(...)` 统一出「差 M 棚 / 下一档已解锁 / 比上一把更干净」，`archive_next_gap(marks_total)` 把「下一级还差 N 枚」搬到标题页档案区。两者都是纯函数，标题页与通告单只做拼装，文案单语言（同 D-083）。
- **D-088 · 教学挂点选在「第一次真的发生」，不选在「第一次进这类棚」**。四个触发点分别是：本局第一次有机关落到玩家身上（props）、第一次踏进灯架棚（gantry）、第一次进 WARN（frame）、第一次播完终局剪辑（final）。灯架那条按「进棚」判是因为它的第二层从进门就看得见；其它三条都必须等到事情真的发生，否则玩家在还没遇到危险时就先读到答案。
- **Sprint 8 收尾口径**。`tools/verify_all.py` 全过：**2,215 条 Godot 断言 + 31 项 Python**，噪声预算 1，`exit 0`；实机复核（真窗口，2558×1598）覆盖教学队列（`sprint8_live_lesson.png`）与标题页进度文案（`visual/preview/sprint8_title_board.png`，Codex D 在隔离 `user://` 副本里拍，玩家真档未被写入）。
