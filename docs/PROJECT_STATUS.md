# RCD 项目状态（PROJECT STATUS）

## 0 · 当前主线是 relay（2026-11-22 复核，优先于下文 campaign 记录）

新游戏的唯一入口是标题页的「新游戏」，进 `scenes/relay/run.tscn`。下文的案件、两名 NPC、四件证物、三周目、Final Cut 属于旧 campaign 线，代码仍在、但正式流程里没有入口，不要据此判断当前可玩内容。

- 自动套件：`godot --headless --path . --script tests/run_all.gd` → **457 assertions, ALL PASS**（含 relay 49 条）。
- relay 现有能力：一局六棚三节（每两棚一次换场单：赶一条 3 趟／多留一条 5 趟／不许宽限）；棚型 S/H/U/L/N/X 与五种机械条件（净场/空棚/快车/双推轨/窄喉）；每个棚之间三扇门，门带趟数（3/4/5）与补给代价；最后一棚有冲线门，过线先摇 `CUT!` 板再进结算页；死亡的复位免判；第一次剪回免费；镜头按键横倾（F3 可关）；种子、每日种子与场记单；**中途存档**（每条收条与每次选门后写 `user://rcd/relay_run.json`，标题页「继续这一卷」）；局外记录（`user://rcd/relay_meta.cfg`：已跑卷数 / 最远棚数 / 死亡数）；M 的静帧锚点、C 的选点预览、场记板 ROLL/CUT/DIE；三态音乐床（平静/紧张/停机）与贴图（deck/flat 的 multiply mask）、震屏、闪白、暗角、雾。
- 仍未做：三种事件节点（换灯/临时加推轨/旧我援手）；一句话前提与声音字幕（开场板只写了 ROLL./这一卷是你的）；棚型字母正面接近时的可读性；真人可读性与难度曲线未验证；Final Cut 不存在；没有局外解锁项（只有每日种子与记录）。
- 已知缺陷：站着不动的录段即使在免判窗口外仍会在原地致命（免判只解决「复位就死」）；`.png`/`.wav` 若未经编辑器导入，运行时会走「盘上直接读」的回退路径（已验证可用）。

最新核对（campaign 记录）：**2026-11-21；Windows 试玩基线 `6bab995`，开发验收至 `ecd51e6`**。研究场景没有打进既有 EXE；重新计算的 SHA256 为 `A56F2D1622D7D31DE74D4923ADE5AA85B80B114B4C75C3346E0D2A49F1E165BC`。第 2–7 节保留早期记录。

西侧首测：按[主持卡](history/B3_MODERATOR_CARD.md)准备独立数据目录。真人首曝样本为 0；合成采集通过，真实跨应用失焦封存未验。不能从机器走位推断标线有教学效果。2026-11-21 合并回归：`python -m unittest discover -s tests -p "test_*.py"` 共 30 项通过，覆盖首测副本与配置指纹、目录冲突拒绝、前台观察器、采集结果分析与发行版预检，不含真人或 EXE 操作。四部作品的研究分别见[视角研究](research/B3_PERSPECTIVE.md)与[教学和时间研究](research/B3_TEACHING_TIME.md)。

交口：见[固定端点的时机对照](history/B3_JUNCTION_PACKET.md)。在[换端探针](../tests/probe_junction_reverse.gd)中，TAKE 02 从北端直返死于 TAKE 01；消耗一次重拍后仍从北端出发，面对同一条成功轨道，走西侧可到南端提交。两次成功后，危险幽灵恰为 TAKE 01 和 TAKE 03，各从自己的录制端出发（`61b4fed`）。这时 CUT 到 START 仍是南端出生、北端提交，两条历史和剩余 4 次重拍均保留（`0664a7a`）。只有成功会换端。这是隔离灰盒的机械验收；下一项真人观察是不给路线提示时，玩家能否先辨认新报告端，再预判相遇。

开发版与发行版的差异：`0144aed` 全套 Godot 回归 397/397。MARK 预览使用打点时的角色、NPC、危险幽灵及证物状态；确认或取消前不移动实时碰撞体。出生点窗口复拍可辨认 `RECEIPT`；F2 在同一机位依次显示英／中／英，节点值为 `RECEIPT → 回执 → RECEIPT`。中文第二字的截图识别有简繁歧义，不当作新手可读性结论。窗口证据：[打点前后](../builds/RCD-receipt-label-449b5c9.png)、[语言切换](../builds/RCD-locale-roundtrip-0144aed.png)。既有 `6bab995` EXE 不含以上修复；独立发行版的连续操作证据仍缺。执行旧版本测试前须隔离 user://：`7070355` 以前的存档测试会清理默认存档，勿直接在正式存档下运行。

**移动中的 MARK 与暂停（仅开发版）**：MARK 保存相机驱动状态，重拍板放行时才继续积分；ORBIT 恢复后一帧的 yaw 对照误差从 0.450° 降至 0.000°，SNAP 的中途转向也有连续 30 帧的对照。见[相机探针](../tests/probe_orbit_mark_continuity.gd)及[完整 MARK/CUT 操作](../tests/probe_mark_cut.gd)。普通 ESC 暂停冻结世界，C 在暂停中无效。西侧采集在暂停期间不写操作或位置，但主持人仍能用 F10 结束输入记录；独立录像另行停止。见[采集合成测试](../tests/probe_trial_recorder.gd)。这些结果不替代 Windows 现场切窗或真人首曝证据。

工程根：`C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die`
版本控制：本地 Git，基线 `c3de553`（2026-11-19 22:0x，现有原型入库）

写这份文件的规矩：说「能跑」要能给出可复现的命令与输出行；说「没有」要能给出空结果；做不到就写「未验证」。

## 1 · 一句话状态

可玩切片保持 ORBIT 30°/s 默认、F5/F6/F7 三模式对照；创作者已认可当前试玩的镜头与操作感，正式方案尚未锁定。单文件 Windows Release 已在干净目录启动，未重打旧包。当前自动套件 363 条全过，三模式探针通过。真实窗口完成 TAKE 01 → 绕开仍在活动的实录幽灵并完成 TAKE 02 → TAKE 03；详见 [连续 Take 验收](history/NATURAL_LOOP_6bab995.md)。

目前瓶颈是关卡训练：零证物 REFRAME 可以跳过 B/C 区。[转角实验](history/CORNER_LAB.md)和[证物路线 A/B](history/CORNER_EVIDENCE_TRIAL.md)已通过机器验证；下一步是不给路线提示的真人首测。正式地图、捷径与 ORBIT30 参数保持原样。CUT 已有 MARK、可操作锚点预览和证物回退；独立 EXE 连续操作、真人难度曲线、跨分支库存与终局仍待验收或开发。

## 2 · 一次命令能复现的证据

```
godot --headless --path . --script tests/run_all.gd     # → RCD TESTS: ALL PASS — 286 assertions in 2.1 s
godot --headless --path . --script tools/check_plan.gd  # → PLAN CLEAR (0 problems)
```

| 模块 | 断言 | 本轮实测数字 |
|---|---|---|
| camera | 78/78 | 收敛到死区边缘：160° → 2.73 s、90° → 2.15 s、20° → 1.48 s；300 帧内零次越过玩家；roll 12° → ≤1° 用 0.33 s |
| ghost | 26/26 | 60 s 轨迹 JSON 后 13 062 B（217.7 B/s）；同帧无新事件被丢弃，有新 flag 的交互保留自己的时间戳 |
| npc | 21/21 | director 周长 10.40 m / 1.05 m·s⁻¹ → 9.90 s 一圈；stagehand 36.80 m / 1.35 → 27.26 s；一圈漂移 0.0000 m |
| map | 24/24 | 12 段墙、10 件家具、4 件证物；每件证物 0.55 m 内有合法站位；报告区在房内 |
| case | 50/50 | 三立场七判词；重复追问不推进计数（堵掉绕过检视门的漏洞） |
| take | 36/36 | ROLLING / REPORTING / DIED / CUT / RETAKE 迁移 |
| save | 17/17 | 坏档被拒（reason=corrupt）、未来版本被拒、写入失败不吞旧档 |
| routes | 18/18 | TAKE 01 25.5 s / 62.9 m / NPC 3.80 m；TAKE 02 24.8 s / 61.1 m / NPC 3.49 m / **幽灵 0.89 m**；TAKE 03 39.2 s / 73.4 m / NPC 1.34 m / **幽灵 1.10 m** |
| scene | 16/16 | 主场景 headless 装配：`room built 24x18`、`main ready: 2 npcs, 4 evidence, ghosts 0`、246 帧后开场冻结解除 |

### 2.1 · 真机运行证据（2026-11-19 22:5x，窗口模式，RTX 4060 Laptop，165 fps）

第一次在真实窗口里跑起来（`godot_run_project` + `godot_command`），用 `eval` 直接读运行时状态。这组数字证明 headless 里的 ROLL 数学在真实游戏循环里同样成立：

| 操作 | 实测 |
|---|---|
| 按住 D（世界 +X） | `facing = -90°`；镜头 yaw 从 0 追到 **-82°** 后停住，`w = 0` —— 停在**死区边缘 8°**，正是设计值 |
| 按住 A（世界 -X） | `facing = +90°`；yaw 稳定在 **+82°**，`w = 0`，roll = 0 |
| 从 +90° 瞬间切到 D | 90 帧采样：`w` 单调加速到 **-120°/s 饱和**，`roll` 升到 **+12° 饱和**，yaw 一路滞后于 facing（第一帧 yaw 81.9 / facing 54，第 68 帧 yaw 49 / facing -89.5） |
| 松开按键 | `w` 保持 -120°/s 直到追平，roll 在 0.35 s 内回 0 |

也就是说：**死区 8°、限速 120°/s、roll 上限 12°、roll 回正 0.35 s 四项在真机上逐项对上**，静止时 `w` 精确归零。这是 D-001/D-003 从「数学自洽」升级为「运行可验证」的一步。

真机运行同时暴露了两个 headless 永远看不到的问题（已修，见 §3.1）：

1. **相机会甩到房间外，看到纯黑的虚空**。12 m 距离/55° 俯角在 24×18 m 的房间里必然把镜头带到墙外，而场景没有舞台地板，于是画面上出现一大块「世界破了个洞」的黑色。
2. **主光角度太低**。58° 仰角的平行光把每面墙投成一条长而全黑的平行四边形，读起来像地上有坑，而且把门的开口糊掉。

修法（`scripts/main.gd::_build_world`）：加 72×60 m 舞台地板（深灰、无光泽）、主光抬到 72° 仰角并配 `light_angular_distance=1.2` 的软阴影、加 `ambient_light_energy 0.95` 抬高暗部、阴影最大距离收到 34 m。截图对比见 `shots/02_d12_p55.png`（修前）与 `shots/06_lit_d12.png`（修后，未被 git 跟踪，属本地取证）。

对应决策：`RCD_DECISION_LOG.md` D-016。

### 2.2 · 历史幽灵闭环实测（2026-11-19 23:0x，同一个运行中的窗口）

这是 m00001 第 23 节第⑦项要求的「一次完整历史循环」的第一段，用 `eval` 在真实进程里跑完，不是 headless 数字：

| 步骤 | 实测结果 |
|---|---|
| 在走廊 `(3.2, 13.0)` 真按 WASD 走了 6.5 s | `GhostRecorder` 采到 **66 个样本 / 10 Hz**，起点 `(3.20, 13.00)`，终点 `(3.20, 14.22)` |
| `GameSession.add_ghost(track)` | `ghost_count()` 变成 1，节点 `Ghost_01` 生成 |
| 幽灵预热 | `Danger` Area3D 在 `playhead >= 2.0 s`（`WARMUP`）才 `monitoring = true`；之前 `monitoring` 与 `monitorable` 都是 false，玩家可以穿过尚未显影的自己 |
| 把玩家传进幽灵当前位置 | **6 帧后死亡**：`takes.state_name() == "DIED"`、`death_source == "take_01"`、`main.phase == 1` |

结论：**「过去的自己」已经成为当前玩家的真实碰撞危险，而且死亡源正确指向 TAKE 01** —— 这句话现在有运行证据。

同一次运行暴露的三个真问题：
1. `ghost_recorder.start()` 不清空旧轨道 → 第二次开拍时时间戳从 0 重新开始、旧样本还在，`add_sample` 全部按乱序拒绝，于是存下来的是空幽灵。已修，并补了 5 条测试（291 assertions）。
2. 轨道比 `WARMUP`（2 s）短的幽灵永远不会 arm —— 录 2.0 s 时 `monitoring` 始终 false。这是设计边界，需要写进 GHOST_REPLAY_SPEC：太短的 Take 不应生成会伤人的幽灵。
3. 死亡瞬间 HUD 仍显示 `TAKE 01 · 0 GHOSTS · ROLLING`，与 `DIED` 状态自相矛盾；幽灵在画面上是一坨半透明灰块，读不出「这是第几周目的自己」。表现层待修。

### 2.3 · 三套 ROLL 方案并存（2026-11-19 23:40，Claude Opus 5.5 实现）

同一套 Player/CameraRig 里现在有三套实质不同的规则，`F1` 循环、`F5`/`F6`/`F7` 直选，HUD 顶栏中央显示 `ROLL: <MODE>`：

| 模式 | 规则 | 实测（`tests/probe_roll_modes.gd`，60 Hz，两次运行逐字节一致） |
|---|---|---|
| 0 CHASE | 追朝向，8° 死区、≤120°/s | hold W 1 s 镜头**零变化**（yaw 0）；hold D 1 s 扫 79° 后锁死，hold 4 s 与 1 s 几乎相同 |
| 1 SNAP | 每次按新方向转一格 **90°**，之后不动 | hold D 1 s 转 90°，按住期间屏幕方位恒为 0；W/D 连切 4 次扫 270° |
| 2 ORBIT | 有方向输入就以 45°/s 绕玩家公转 | hold D 4 s yaw +174.8°、同一个键的屏幕含义漂移 **172.5°**、roll 常驻 -9.9° |

结论：只有 ORBIT 不收敛。CHASE 的「走一会儿就和普通游戏一样」被数据证实（`scr_drift` 只在转向后约 1 s 的过渡里出现）。三者的位移完全一致，差别全在画面如何动。详见 `docs/ROLL_SCHEME_STUDY.md`、`docs/ROLL_CAMERA_DESIGN.md` §8；裁决见 D-019。

同轮修好的表现层（真机验证）：死亡时 HUD 三行同时正确 `TAKE 01 · 1 GHOST · DIED — TAKE 01` / `ROLL: CHASE` / 居中 `DIED TO TAKE 01`，幽灵变成冷蓝实心体 + 头顶常显 `TAKE 01` + 地面危险环；接触后 **7 帧**进入 `DIED`，`death_source == "take_01"`。截图 `shots/10_mode_{0,1,2}.png`、`shots/11_died_presentation.png`。

## 3 · 本轮改了什么（都能用 `git diff c3de553` 复核）

1. **ROLL 按圣经重写**：`scripts/camera/camera_math.gd`（纯关系）+ 新文件 `scripts/camera/camera_chase.gd`（有状态积分器）+ `scripts/camera/camera_rig.gd`（有效 yaw = chase yaw + 鼠标 offset；roll 不参与任何判定）。
2. **移动改为世界轴锚定**：`scripts/player/player.gd` 删掉了相机相对的 `move_dir(ix, cam_yaw())`。原因见 `RCD_DECISION_LOG.md` D-002。
3. **测试入口从「跑不起来」修到全绿**：统一 `run(h, _tree = null)` 契约、`tests/run_all.gd` 加 100 s watchdog、`tests/only.gd` 加 60 s watchdog。此前一次超时会把 stdout 全丢掉，等于没有测试。
4. **修掉的三处真实逻辑缺陷**：`ghost_track.add_sample` 吞掉同帧交互的时间戳、`from_dict` 缺通道长度校验、`sample_at` 永不返回 `finished`；`npc_patrol.state_from_timeline` 在腿边界报旧腿号；`case_state.ask` 每次调用都推进计数（不检视连按四次即可解锁第三句）。
5. **路线数据整体重写**：`data/routes.json` 三张表按真实家具阴影重排，新增 `{ "wait": 秒 }` 步骤类型与「取物站位必须持续安全」的判定；`tools/check_plan.gd` 一次报出所有阻断腿。
6. **坏档解析不再打引擎错误**：`save_manager.load_save()` 改用 `JSON.new().parse()`。

## 4 · 不能跑什么（按影响排序）

| 缺什么 | 后果 | 依据 |
|---|---|---|
| 真人试玩（尤其三种 ROLL 模式） | 所有数字都是 headless 数学 + 单次窗口截图，没有手感、晕动、学习曲线 | 总指令 §21「headless 通过不等于可玩」 |
| `scene_no` 与周目推进 | `take_index` 一直递增，没有 SCENE 01→02→03，成功后也没有进 Final Cut 的分支 | ROADMAP §5 |
| `FinalCutController` | 三个结局只有数据里的文本，游戏里没有演出 | ROADMAP §3 Phase 8 |
| 场记板/时间轴的场景预览 | CUT 界面还没有「当时当地画面」 | `CUT_SLATE_DESIGN.md` |
| 幽灵数量上限与性能 | `GameSession.add_ghost()` 无上限；圣经默认 2，同屏 3+ 的帧率与可读性未测 | `GHOST_REPLAY_SPEC.md` §8 |
| 真实美术与音频 | 全部程序化灰盒 + 合成 CLACK | ROADMAP §6 |
| Gemini 通道 | 没有任何可用凭据（CLI 未安装、无环境变量、中转只列 Claude 模型） | `MODEL_ROUTING_POLICY.md` |


## 5 · 已定的事实（有实现与文档双重支撑）

1. **证据摆放以 `data/studio_map.json` 为唯一真相。** `clapboard`(12.4, 9.85)、`script_page`(4.1, 3.7)、`walkie`(19.6, 12.4)、`receipt`(2.2, 15.8)；报告区 (2.2, 15.0) r=1.5；出生点 (2.0, 16.6)。
2. **房间净空只有 1.36 m 的门。** 24×18 m；墙 0.4 m 厚、玩家半径 0.32 m，四个门洞物理 2.0 m → 有效 1.36 m。办公室北/南门在 `x∈(11.32, 12.68)`，东/西门在 `y∈(8.32, 9.68)`。航点必须按这个膨胀后的几何写。
3. **询问次数跨 Take 保留，且只按「给过几个不同答案」计。** `case_state.on_retake()` 只回滚 `seen`；`_select_index()` 保证重复听到同一句不推进计数。
4. **非终局判词不消耗一局。** `TERMINAL_VERDICTS = [file_closed, bury_registered, reframe_held]`，其余判词退回报告、Take 继续。
5. **幽灵播完即退休。** 回放到位后不再站在终点继续杀人；路线证明与 `ghost_actor.gd` 必须同口径。
6. **Godot 锁 4.3，不升级。** 不用 4.4+ API。

## 6 · 未解决的冲突（需要一次明确决策）

1. **ORBIT 与圣经 §4.1 硬规则①冲突（新，最急）。** 三套 ROLL 方案已在同一份代码里并存（`F1` 循环 / `F5`–`F7` 直选）。CHASE 会收敛（按 W 镜头零变化）、SNAP 会停（按住时画面永久静止）、只有 ORBIT 不收敛（4 s 内同一个键的屏幕含义漂移 172.5°）。ORBIT 违反了「镜头必须追随朝向」这条硬规则。裁决见 `RCD_DECISION_LOG.md` D-019，数据见 `docs/ROLL_SCHEME_STUDY.md`。
2. **短幽灵不伤人（新）。** 轨道短于 `WARMUP 2.0 s` 的幽灵永远不会 arm（真机撞到两次）。要么明说「TOO SHORT TO HAUNT」，要么让 WARMUP 随轨道长度自适应。见 D-020。
3. **`taken ≡ sealed` 的简化。** 实现里第二次按 E 取走即跨 Take 永久保留=封存；但圣经 §7.3 还要求「报告只能挂已封存证物」且封存必须在唯一证物柜，而证物柜不存在。**现状口径：`taken ≡ sealed`。** 要么补证物柜，要么改圣经承认简化。
4. **幽灵编号与周目脱钩。** `TAKE` 全局递增，没有 `SCENE`；「三周目」在代码里仍不存在。
5. **世界轴 vs 角色轴**（圣经 V06）。已按硬规则选世界轴并给出实现证明，但仍需 PHASE 2 双版本盲测确认手感。

## 7 · 下一步（按顺序）

1. 玩家亲手在窗口里玩一次，分别在三种模式下走完一条路线，记录「哪一刻你按错了方向」——这是唯一能裁决 D-019 的证据。
2. 关卡几何落地（`docs/LEVEL_ZONES_ROLL.md` 的 B/C 区），让难度来自空间而不是数值。
3. 补 `scene_no` 与周目推进：成功 → 下一 SCENE；SCENE 03 成功 → Final Cut 占位。
4. 场记板 CUT 界面的「时间轴 + 当时当地预览」最小实现。
5. 定冲突 2（短幽灵）与冲突 3（证物柜）。

