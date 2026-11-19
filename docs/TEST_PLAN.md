# RCD 测试计划（TEST PLAN）

口径：**只有能在磁盘上核到的证据才算通过。** 没有跑过的层写「未验证」，没写的层写「未实现」。本文件不描述「应该会通过」，只描述「跑什么、看什么算过」。

快照时间：2026-11-14 14:06。`tests/` 目录正在被另一条工作流扩展，清单以本行时间为准。

## 0 · 结论先行：本轮实际做到哪一层

| 层 | 状态 | 证据 |
|---|---|---|
| L0 引擎能启动 | **已达成（有日志证据）** | `logs\godot.log` 含 `main ready: 2 npcs, 4 evidence, ghosts 0`；`rcd\runtime.log` 含 `room built 24x18` |
| L1 纯函数 | **文件已存在，本轮未运行** | `tests/` 截至 14:06 共 12 个文件：`harness.gd`、`geom.gd`、`smoke.gd`、`diag_logger.gd`、`test_camera.gd`、`test_case.gd`、`test_ghost.gd`、`test_map.gd`、`test_npc.gd`、`test_save.gd`、`test_scene.gd`、`test_take.gd`；**没有 `run_all.gd`**，也没有任何一次运行记录 |
| L2 数据校验 | **未实现（只有校验函数，没有测试）** | `scripts/world/room_spec.gd` 的 `validate()` 存在，但没有测试调用它 |
| L3 场景集成 | **未实现** | 只有 `tests/smoke.gd` 能加载主场景两帧，不覆盖 DIE/CUT/Retake 状态迁移 |
| L4 路线可行性 | **未实现** | `tests/test_routes.gd` 不存在 |
| L5 人工验收 | **未验证（本轮未执行）** | 没有 Editor 实跑记录，没有导出产物，没有外网/他人试玩 |

一句话：**L0 有证据，L1 有文件没跑过，L2–L5 都没有。** 任何汇报不得把这句改写成「测试体系已建立」。

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

跑：`tests/test_routes.gd`，对 SCENE 01/02/03 的候选路径做时空采样：玩家路径按固定速度离散成 `t → (x,z)`，NPC 用 `npc_patrol.state_at(pts, spd, dwell, mode, t)`，幽灵用 `ghost_track.sample_at(t)`，逐点求最近距离。

判据：存在一条路径使全程最小距离 > 玩家胶囊半径 + NPC 半径之和；且 TAKE 03 在两条幽灵同时活动时仍存在这条路径。**这是本项目第一个硬验收**，不通过就不做美术。

失败先看：`data\studio_map.json` 的通道宽度（内圈净宽 1.1–1.4 m 是「靠时机过」，不是「靠身位过」）；再看 NPC 路线的相位是否把唯一通道锁死。

### L5 · 人工验收

跑：Editor 里实际玩一遍（会话内不执行此项，见本轮结论）；Windows 导出后在另一台没有 Godot 的机器上启动。

判据：三名新玩家能在 15–30 分钟内走完三周目并看到 Final Cut；导出包不依赖本机 AppData。

失败先看：导出 preset 的资源过滤（是否有 `.json` 被漏掉）；字体是否内置（缺字形会显示方块）。

## 3 · 不做什么

- 不引入 gdUnit4 / GUT / 任何第三方测试框架：现有 `tests/harness.gd` 只有 57 行，够用，且不增加授权与版本风险。
- 不做截图比对：灰盒阶段画面本来就要变，像素基线只会制造假失败。
- 不做 CI：没有远端仓库、没有 Git（见 `PROJECT_STATUS.md`），先有版本历史再谈自动化。
- 不用「跑通一次」代替回归：每个提交至少要过一次 L0；改到 `camera_math` / `ghost_track` / `case_state` 时必须过 L1。
