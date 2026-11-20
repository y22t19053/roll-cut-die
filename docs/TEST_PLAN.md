# RCD 测试计划（TEST PLAN）

口径：**只有能在磁盘上核到的证据才算通过。** 没有跑过的层写「未验证」，没写的层写「未实现」。本文件不描述「应该会通过」，只描述「跑什么、看什么算过」。

## 最新复验 · 2026-11-20

- `tests/run_all.gd`：基线 `6bab995`，Godot 4.3，363 条通过、退出 0。
- `tests/probe_roll_modes.gd`：修正持续输入的比较场景后，13 项通过；D 长按 4 s 时屏幕方向漂移 CHASE 77.5°、SNAP 6.7°、ORBIT 115.5°。不修改游戏参数。
- [连续 Take 录像验收](history/NATURAL_LOOP_6bab995.md)：窗口内实际键位驱动，TAKE 02 在 TAKE 01 实录幽灵仍有碰撞危险时绕开，进入 TAKE 03。零证物 REFRAME 路径不覆盖五区难度。
- Windows 单文件实测覆盖干净目录启动；导出 EXE 连续输入和真人三模式对照尚未验证。

以下 §0 为 2026-11-19 22:47 历史快照，§1 起为验收规范。

## 0 · 结论先行：本轮实际做到哪一层

跑一次全量：

```
godot --headless --path . --script tests/run_all.gd      # 约 2.1 s，退出码 0
```

实测输出末行：`RCD TESTS: ALL PASS — 286 assertions in 2.1 s`。

| 层 | 状态 | 证据（2026-11-19 22:47 实测） |
|---|---|---|
| L0 引擎能启动 | **已达成** | `>> scene` 加载主场景，日志 `room built 24x18`、`main ready: 2 npcs, 4 evidence, ghosts 0`、`released after 246 frames`；scene 16/16 |
| L1 纯函数 | **已达成** | `run_all.gd` 九个模块全绿：camera 78/78、ghost 26/26、npc 21/21、map 24/24、case 50/50、take 36/36、save 17/17、routes 18/18、scene 16/16 |
| L2 数据校验 | **已达成** | map 24/24：`RoomSpec.validate()` 零问题、证物 id 双向相等、报告区在房内、证物最近站位 0.55 m |
| L3 场景集成 | **部分达成** | scene 16/16 覆盖装配、开场冻结与解冻、take 1 零幽灵、相机绑定距离 1.0。**未覆盖**：headless 里真实按键驱动 DIE→CUT→RETAKE 的状态迁移（take 36/36 只测状态机本身） |
| L4 路线可行性 | **已达成（三张表）** | routes 18/18：TAKE 01 25.5 s / 62.9 m / 与 NPC 最近 3.80 m；TAKE 02 24.8 s / 61.1 m / NPC 3.49 m / **与 TAKE 01 幽灵最近 0.89 m**；TAKE 03 39.2 s / 73.4 m / NPC 1.34 m / **与两条幽灵最近 1.10 m**（阈值 GHOST_CLEAR 0.66、NPC_CLEAR 0.77） |
| L5 人工验收 | **未验证** | 没有 Editor 实跑记录，没有导出产物，没有他人试玩 |

一句话：**L0–L2、L4 有真实输出，L3 只有一半，L5 一次都没做。** 任何人不得把这句改写成「游戏可玩」。

配套工具与已知噪音：

- `tools/check_plan.gd`（几何静态检查，不看时间）：一次列出三张表所有阻断腿，输出 `PLAN CLEAR (0 problems)`。改航点先跑它，再跑 routes。
- `tests/only.gd` + `tests/only_module.txt`：只跑一个模块，带 60 s watchdog。调试某个模块时用它，不要反复跑全量。
- stderr 常驻噪音：`ERROR: Parameter "m" is null. at: mesh_get_surface_count`（headless dummy renderer）与 `WARNING: ObjectDB instances leaked at exit`。两者都不影响退出码。曾经还有一条 `ERROR: Parse JSON failed`，来自「坏存档必须被拒绝」这条测试自己写的非法 JSON；`save_manager.load_save()` 已改用 `JSON.new().parse()`，该类失败不再打引擎错误。


## 1 · 分层总表

| 层 | 目标 | 入口 | 通过判据 | 失败先看哪里 |
|---|---|---|---|---|
| L0 | 引擎能解析工程并启动主场景 | `tests/smoke.gd` | 打印 `SMOKE RESULT ok`，退出码 0 | `godot.log` 第一段错误；`project.godot` 的主场景路径 |
| L1 | 纯函数值正确 | `tests/test_*.gd` | 每个 `RESULT <module> n/n` 且 n==n，退出码 0 | `harness.gd` 的 `FAIL` 行；被 preload 的 math 脚本 |
| L2 | 数据文件结构与几何合法 | `room_spec.validate()` / case 结构测试 | 返回空数组；证物 id 与 studio_map 一一对应 | `data\studio_map.json`、`data\case.json` |
| L3 | 场景装配与状态机 | `tests/smoke.gd` 扩展 + 状态迁移测试 | 60 帧无 error；DIE/CUT/Retake 的 next-state 与记录符合设计表 | `scripts/main.gd` 的 phase 分支；`take_manager.gd` |
| L4 | 三周目路线真实可执行 | `tests/test_routes.gd` | 每个 SCENE 存在一条从出生到报告的时空路径，与 NPC/幽灵轨迹最小距离 > 阈值 | `data\studio_map.json` 的通道宽度、NPC 路线 |
| L5 | 人能玩 | Editor 实跑 / Windows 导出 | 新玩家 3 人通关；导出包在无编辑器机器上启动 | 导出 preset、字体、资源路径 |

## 2 · 逐层说明

### L0 · 引擎能启动

跑：`godot_run_headless(project_path=<工程根>, script="tests/smoke.gd", timeout_ms=60000)`；或快速版 `godot_run_headless(scene="scenes/main/main.tscn", quit_after=30)`。

判据：`SMOKE RESULT ok` + 退出码 0 + `runtime.log` 有三行 `info`。**不看 `mesh_get_surface_count` 噪音**（headless dummy renderer 的正常输出，见 `WORKFLOW_GUIDE.md` §3.3）。

失败先看：`project.godot` 的 `run/main_scene`；`scenes/main/main.tscn` 是否仍指向 `scripts/main.gd`；`godot.log` 里第一条真正的错误（不是噪音）。

### L1 · 纯函数

对象：`camera_math`（wrap/死区/角速度上限/roll 限幅/几何）、`ghost_track`（量化—反量化、插值、时长）、`npc_patrol.state_at`（给定秒数的位置）、`case_state.verdict`（纯函数：输入四个计数，输出判词 id）。

跑：逐个 `--script tests/test_<模块>.gd`；`RESULT` 行的分母必须是总数。等价命令行见 `WORKFLOW_GUIDE.md` §2。

判据：退出码 0，每个模块 `n/n` 相等。**不许把 NOTE 行当通过**——`harness.note()` 只用于记录测量值。

失败先看：`FAIL <module>: <case>  [got … want …]`；再看该模块是否有人改成「差不多就行」的容差（`eps` 被放大就是测试在说谎）。

### L2 · 数据校验

跑：一次 headless 里加载 `data/studio_map.json` 并调用 `RoomSpec.validate()`，断言返回为空；再断言 `studio_map.json` 的 4 个证物 id 与 `case.json` 的 `evidence[].id` 完全相等（双向差集为空）。

判据：零问题；id 集合严格相等；报告区圆心在房内且半径小于通道宽度。

失败先看：`map: ...` 前缀的 error（`main.gd` 会把每条问题打出来）；其次是坐标写成了 `[x, y]` 还是 `[x, z]`。

### L3 · 场景集成

跑：headless 加载主场景跑 60 帧；再驱动状态机做三件事——撞 NPC（DIED）、按 C（CUT）、在场记板结束后按 SPACE（RETAKE）——每步读 `GameSession.takes.state_name()`。

判据：`ROLLING → DIED → ROLLING`、`ROLLING → CUT → ROLLING`、以及 take_index 每次 +1；DIED 与 CUT 的 outtake 记录条数各 +1；success 才 `add_ghost`。判据直接抄 `take_manager.gd` 头注释的状态图，不另立标准。

失败先看：`main.gd` 的 `phase` 与 `TakeManager.state` 是否分叉（两份状态就是两份真相，这是本项目最容易犯的错）。

### L4 · 三周目路线可行性

跑：`godot --headless --path . --script tools/check_plan.gd`（只看几何，0.2 s，一次列出所有阻断腿），再跑 `tests/test_routes.gd`（连 NPC 与幽灵一起看）。

模型（`tests/test_routes.gd` 头注释即契约，改动两边必须同步）：玩家按 `speed` 匀速走直线，`auto` 步由搜索决定等到第几帧才动；NPC 用 `NpcPatrol.build_timeline` + `state_from_timeline` 的解析式时间线；幽灵用前一张表的真实采样轨迹，`t < GHOST_WARMUP(2.0 s)` 不伤害，**播完即退休**（与 `ghost_actor.gd` 一致）；取物需要整个 `act_time(0.7 s)` 内站位安全；`{ "wait": 秒 }` 是合法的「站住等」指令。

判据：每张表都能走完并集齐四件证物；全程 `min_npc ≥ 0.77`、`min_ghost ≥ 0.66`；三张表里 TAKE 03 必须在两条幽灵同时活动时仍存在这条路径。**这是本项目第一个硬验收**，不通过就不做美术。

失败先看：`data\studio_map.json` 的通道宽度（内圈净宽 1.1–1.4 m 是「靠时机过」，不是「靠身位过」）；再看 NPC 路线的相位是否把唯一通道锁死。

### L5 · 人工验收

跑：Editor 里实际玩一遍（会话内不执行此项，见本轮结论）；Windows 导出后在另一台没有 Godot 的机器上启动。

判据：三名新玩家能在 15–30 分钟内走完三周目并看到 Final Cut；导出包不依赖本机 AppData。

失败先看：导出 preset 的资源过滤（是否有 `.json` 被漏掉）；字体是否内置（缺字形会显示方块）。

## 3 · 不做什么

- 不引入 gdUnit4 / GUT / 任何第三方测试框架：现有 `tests/harness.gd` 只有 57 行，够用，且不增加授权与版本风险。
- 不做截图比对：灰盒阶段画面本来就要变，像素基线只会制造假失败。
- 不做 CI：仓库只有本地 Git（`c3de553` 起），没有远端。先有稳定的一键入口（`tests/run_all.gd`），再谈自动化。
- 不用「跑通一次」代替回归：每个提交至少要过一次 `run_all`；改到 `camera_math` / `ghost_track` / `case_state` / `routes.json` 时必须重跑对应模块并看 NOTE 里的实测数字。
