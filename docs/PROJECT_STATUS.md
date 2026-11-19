# RCD 项目状态（PROJECT STATUS）

日期：2026-11-14
快照时间：**14:06**（本文件所有清单都是这一刻的磁盘事实，不是计划）
工程根：`C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die`

写这份文件的规矩：写到「能跑」必须能指出日志行；写到「没有」必须能指出 `Test-Path` 的空结果。做不到就写「未验证」。`scripts/`、`tests/`、`docs/` 正在被其他工作流同时写入，本文件的数字只对上面那个时刻负责。

## 1 · 磁盘上有什么（逐条核过）

### 工程与数据
| 文件 | 行数 | 说明 |
|---|---|---|
| `project.godot` | 43 | `config/features=PackedStringArray("4.3", "Forward Plus")`；主场景 `res://scenes/main/main.tscn`；仅 `GameSession` 一个 autoload |
| `scenes/main/main.tscn` | 6 | 单节点 Node3D + `scripts/main.gd` |
| `data/studio_map.json` | 56 | 24×18 m；12 段墙；10 件家具；2 条 NPC 路线；4 件证物坐标；报告区 (2.2, 15.0) r=1.5 |
| `data/case.json` | 112 | 4 证物（inspect/seal/meaning 三段文本）、2 NPC 各 3 层台词、3 立场、7 判词 |

### 脚本：22 个 .gd，3 364 行
`scripts/core/`：`game_session`(123)、`logger`(71)、`loc`(42)、`input_setup`(49)
`scripts/camera/`：`camera_math`(116)、`camera_rig`(114)
`scripts/player/`：`player`(175)
`scripts/npc/`：`npc_patrol`(317)
`scripts/ghost/`：`ghost_track`(228)、`ghost_recorder`(88)、`ghost_actor`(144)
`scripts/case/`：`case_state`(232)、`evidence_prop`(111)
`scripts/take/`：`take_manager`(153)
`scripts/world/`：`room_spec`(173)、`room_builder`(133)
`scripts/ui/`：`slate_ui`(189)、`slate_board`(78)、`slate_audio`(31)、`hud`(124)
`scripts/save/`：`save_manager`(59)
`scripts/main.gd`：614（装配与输入路由，不含玩法规则）

### 测试：12 个 .gd，894 行（正在增长，逐分钟变化）
`harness`(57)、`geom`(79)、`smoke`(38)、`diag_logger`(11)、`test_camera`(94)、`test_case`(130)、`test_ghost`(82)、`test_map`(114)、`test_npc`(74)、`test_save`(72)、`test_scene`(71)、`test_take`(72)。
**没有 `run_all.gd`。** 测试用例在增加，但没有一条命令能全部跑起来。

### 文档
`SOURCE_MASTER_DIRECTIVE`(2 432)、`RCD_GAME_DESIGN_BIBLE`(882)、`CASE_AND_ENDINGS`(153)、`CUT_SLATE_DESIGN`(136)、`FINAL_CUT_DESIGN`(139)、`MAP_LAYOUT_DESIGN`(145)、`LOCALIZATION`(95)、`WORKFLOW_GUIDE`(157)、`TEST_PLAN`(88)、`RCD_DEVELOPMENT_ROADMAP`(117)、本文件。
**缺**：`RCD_TECHNICAL_SPEC.md`、`THREE_TAKE_ROUTE_DESIGN.md`。后者的缺失直接卡住 Phase 6 的验收。

## 2 · 能跑什么（有证据）

1. **主场景能在 headless 下启动。** 证据：`logs\godot.log` 首行 `Godot Engine v4.3.stable.official.77dcf97d8`；`rcd\runtime.log` 六行，含 `session ready, take 1` / `room built 24x18` / `main ready: 2 npcs, 4 evidence, ghosts 0`。
2. **房间按 `studio_map.json` 生成**：12 段墙、10 件家具、2 条巡逻路线、4 件证物，位置与数据文件逐项一致（证物 id 与 `case.json` 完全对应）。
3. **日志能落盘**：`%APPDATA%\Godot\app_userdata\roll cut die\rcd\runtime.log` 存在，格式为 `秒 tag 内容`。
4. **代码层已具备**：ROLL 的 yaw 死区/限速、roll 派生与限幅、pitch 固定；碰撞即死（NPC 与幽灵两条来源）；DIE/CUT/Retake 状态机；场记板四段序列与合成 CLACK；轨迹记录/回放数据结构；三立场与七判词纯函数；中英双语文本解析。

第 4 条只证明「代码在」，不证明「玩过」。除第 1–3 条外，没有任何运行证据。

## 3 · 不能跑什么（阻塞当前阶段）

| 缺什么 | 后果 | 依据 |
|---|---|---|
| `export_presets.cfg` 与 `build/` | 从没导出过一次，Phase 0 的导出判据不成立 | ROADMAP §1 |
| `.git` | 没有历史、没有 diff、没有回滚 | WORKFLOW_GUIDE §6 |
| `scene_no` 与周目推进 | `take_index` 一直递增，没有 SCENE 01→02→03，也没有成功后进 Final Cut 的分支 | ROADMAP §5 |
| `FinalCutController` | 三个结局在数据里有文本，在游戏里没有演出 | ROADMAP §3 Phase 8 |
| `tests/test_routes.gd` | 「TAKE 03 存在可执行路线」无法判定，只能靠手玩 | TEST_PLAN L4 |
| `run_all.gd` | 十二个测试文件没有统一入口，等于没有回归 | TEST_PLAN §0 |
| 幽灵数量上限 | `GameSession.add_ghost()` 无上限；设计圣经写的是默认 2 | 圣经 §8.6 |
| 真实美术与音频 | 全部程序化灰盒 + 合成 CLACK | ROADMAP §6 |

## 4 · 未解决的冲突（按「已定 / 未定」分开）

### 已定（有实现与文档双重支撑）

1. **证据摆放以 `data/studio_map.json` 为唯一真相，已定稿。** 坐标：`clapboard`(12.4, 9.9)、`script_page`(4.1, 3.7)、`walkie`(19.6, 12.4)、`receipt`(2.2, 15.8)；报告区 (2.2, 15.0) r=1.5；出生点 (2.0, 16.6)。其他文档与这份坐标冲突时改文档，不改数据。
2. **询问次数跨 Take 保留。** `case_state.on_retake()` 只回滚 `seen`，不动 `asked`。理由：答过话的人不会忘记问题。副作用是重开不等于重置，玩家不能靠自杀刷掉已解锁的证词层级。
3. **非终局判词不消耗一局。** `main.gd` 的 `TERMINAL_VERDICTS = [file_closed, bury_registered, reframe_held]`；其余四种判词把报告退回，Take 继续，标记全保留。报告被退不是失败，是片场官僚。
4. **Godot 锁 4.3，不升级。** `project.godot` 的特性的串已从脚手架残留的 `"4.7"` 改为 `"4.3"`；导出模板为 `4.3.stable`。4.4+ API 一律不用。

### 未定（需要一次明确决策）

5. **`taken` 与 `sealed` 的等价关系。** 实现里第二次按 E 取走 = 跨 Take 永久保留，也就是封存；但设计圣经 §7.3 还要求「报告只能挂已封存证物」且封存必须发生在唯一证物柜。当前 `toggle_attach()` 只要求 `taken`，证物柜不存在。**现状口径：`taken ≡ sealed`。** 要么补证物柜与瓶颈路径，要么改圣经承认简化——不能两头都留着。
6. **幽灵编号与周目脱钩。** `TAKE` 是全局递增，没有 `SCENE`；`DIED TO TAKE 04` 的编号唯一性成立，但「三周目」在代码里还不存在。

## 5 · 下一步（按顺序，前一项不做完后一项无意义）

1. `git init` + 首个提交（现在每次改动都不可回滚）。
2. 补 `run_all.gd`，跑一次 L1，把结果写进 `TEST_PLAN.md` §0。
3. 补 `scene_no` 与周目推进：成功 → 下一 SCENE；SCENE 03 成功 → Final Cut 占位。
4. 写 `tests/test_routes.gd`，先只测 SCENE 01 单幽灵是否可过；能过再谈 SCENE 03。
5. 定冲突 5：补证物柜，或改圣经。两个动作都小，但必须选一个。
