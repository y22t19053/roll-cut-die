# 幽灵回放规格（GHOST REPLAY SPEC）

状态：**已实现并在真机验证过致死判定；活动数量上限与性能预算未验证**。
对应决策：`RCD_DECISION_LOG.md` D-007 / D-008 / D-011 / D-020。
代码：`scripts/ghost/ghost_recorder.gd`（采样）、`scripts/ghost/ghost_track.gd`（存储与插值）、`scripts/ghost/ghost_actor.gd`（回放与碰撞）、`scripts/core/game_session.gd`（持有 ghosts）。

---

## 1 · 一个「幽灵」到底是什么

一个幽灵 = 一条**按真实物理时间戳记录的位置/朝向轨道**，重放时由 `ghost_actor.gd` 按自己的 playhead 采样、把胶囊体摆到当时的位置，并靠一个 `Danger` Area3D 与当前玩家发生碰撞。

它不是 AI，不感知玩家，不做任何决策。它的危险来自「过去的你在那个时刻确实在那里」。

## 2 · 采样

| 项 | 值 | 位置 |
|---|---|---|
| 采样率 | **10 Hz**，固定在物理时间网格上，与帧率无关 | `ghost_recorder.gd:11 HZ := 10.0` |
| 首帧 | `start()` 把累加器预置为 `1/HZ`，所以第一帧就采一个样本 | `ghost_recorder.gd:47` |
| 采样内容 | 世界坐标、`facing`、`cam_yaw`、`cam_roll`、flag 位 | `ghost_recorder.gd:_emit()` |
| flag | `FLAG_ALIVE = 1`、`FLAG_INTERACT = 2` | `ghost_track.gd:20-21` |
| 时间戳 | 第 k 个网格 tick 记为 `k / HZ`，**与轨道是否保留该帧无关**；`elapsed()` 返回累计物理时间 | `ghost_recorder.gd` `_ticks` |
| 交互标记 | `recorder.mark(FLAG_INTERACT)` 在**当前物理时刻**追加一条新样本；仅当最新样本与当前同一厘秒时才把 flag 并进它。永不改写更早的样本 | `ghost_recorder.gd` `mark()` |
| 续录 | `recorder.resume_from(t, take_id)`：保留 `t` 之前的样本（通往锚点的路），网格从 `t` 之后继续。CUT 回到 MARK 时使用 | `ghost_recorder.gd` / `ghost_track.gd` `head_until()` |

选 10 Hz 而不是 60 Hz 的理由：幽灵的定位精度需求来自碰撞判定（`DANGER_RADIUS 0.34` + 玩家半径 0.32 ≈ 0.66 m 的安全距离），玩家 3.2 m/s 时 10 Hz 相邻样本间隔 0.32 m，插值后误差远小于判定半径；60 Hz 会把存档体积放大 6 倍。

## 3 · 存储格式

分通道量化成整数数组，不是逐帧字典：

| 通道 | 量化 | 常量 |
|---|---|---|
| 时间 | ×100（1/100 s） | `TIME_SCALE 100.0` |
| 位置 | ×1000（mm） | `POS_SCALE 1000.0` |
| 角度 | ×100（1/100 度） | `ANG_SCALE 100.0` |

`to_dict()` 输出 `{v, n, times, px, py, pz, facing, cam_yaw, cam_roll, flags, take_id}`，全部是 `PackedInt32Array` / `PackedByteArray`。`from_dict()` **必须**校验每个通道长度都等于 `n`（2026-11-19 修过一次：旧实现只查 `px`/`pz`，声明 `n=5` 而各通道只有 1 个元素也能载入，读到越界数据）。`flags` 不足时补 `FLAG_ALIVE`。

体积实测：60 s 轨道序列化后 **13,062 B（217.7 B/s）**。也就是说一小时的历史约 780 KB —— 存档体积不构成限制，**限制在同时活动的幽灵数量**。

## 4 · 回放与插值

- `sample_at(t)` 在相邻两样本之间按 `alpha` 线性插值位置与朝向（角度走最短弧）。
- 持有最后一帧时返回 `finished = t >= duration()`；`ghost_actor.gd` 用这个位退休（`spent = true`），退休后 `Danger` 关闭、不再参与碰撞。
- **退休是必须的**：终点通常在报告区/出生区，不退休等于每次回家都被上一轮的自己撞死（D-008）。
- `max_deviation(other)` 用于测试断言的「两次重放插值一致」。

## 5 · 碰撞

| 项 | 值 |
|---|---|
| 幽灵判定半径 | `DANGER_RADIUS 0.34` |
| 幽灵体积 | `BODY_RADIUS 0.32` / `BODY_HEIGHT 1.7` |
| 玩家半径 | 0.32 |
| 安全距离（路线证明用） | **0.66 m**（`GHOST_CLEAR`） |
| 碰撞层 | 幽灵 `Area3D` 监听玩家物理层（layer 2 / mask 2 体系） |

死亡源：`main._on_ghost_caught(take_id)` → `takes.die("take_%02d")` → HUD 显示 `DIED TO TAKE 01`。真机实测 7 帧内从接触到 `DIED`。

## 6 · 预热（WARMUP）与它带来的边界

`ghost_actor.gd` 的 `Danger` 在 `playhead >= WARMUP(2.0 s)` 之前 `monitoring = false`，透明度在预热期从 0 升到 `ARMED_ALPHA 0.62`。

副作用（真机撞到两次）：**轨道短于 2 s 的幽灵永远不会 arm，玩家穿过不死**。这条边界写进了 D-020，两种合法处理方式（明确提示「TOO SHORT TO HAUNT」或让 WARMUP 随轨道长度自适应）尚未裁决。

## 7 · 采样与存储的两个已知坑

1. **`start()` 必须清空旧轨道**。2026-11-19 的真 bug：`start()` 只重置计数器不清 `track`，而它可以在没有 `setup()` 的情况下被调用；第二次开拍时时间戳从 0 重新开始、旧样本还在，`add_sample()` 全部按「乱序」拒绝，最后存下来的是**空幽灵**。修法：`start()` 新建 `GhostTrack` 并把 `_take_id` 带过去。`tests/test_ghost.gd` 有五条断言守着（`start clears the previous track` 等）。
2. **静止段的存储规则（2026-11-20 改）**。旧实现把「同一姿态 + 无新 flag」的样本直接丢弃，而 recorder 用「已接受样本数 / HZ」当时间戳 —— 于是站着不动时**时钟停走**：录 10 s（4 s 静止 + 2 s 行走 + 4 s 静止）只得到 2.1 s 的轨道，幽灵瞬移（`tests/probe_replay_clock.gd`）。现规则：
   - 时间戳取物理网格 tick（`k / HZ`），不再取样本数；
   - 静止段存**首帧 + 最新帧**两条样本：若最后两条样本与新帧姿态相同且 flag 相同，只把最后一条的时间戳推到当前时刻。时长因此等于真实时长，插值跨越静止段时姿态不变，长时间静止仍只花两条样本；
   - 带 `FLAG_INTERACT` 的样本永不被拉伸，它之后的下一帧必定另起一条；
   - 比较姿态时连 `cam_roll` 一起比。
   `tests/test_ghost.gd` 的 standstills / recorder clock 两段守着这些规则。

## 8 · 计数与上限

- `GameSession.ghosts` 是 `[{take, track}]` 数组，`ghost_count()` 返回长度；TAKE 02 有 1 个、TAKE 03 有 2 个，依次累积。
- 设计圣经默认「同屏活动幽灵 2 个」，**代码里没有上限**，也没有性能测试。要看的是：幽灵数量 × 每帧插值成本，以及最重要的 —— 空间可读性（3 条轨迹同时在路上跑，玩家还能不能读懂哪里安全）。
- 幽灵编号（TAKE 01/02/03）与周目编号脱钩（D-011）。

## 9 · 已验证 / 未验证

已验证（真机，非 headless）：
- 6.5 s 实录 → 66 样本 → 重放位置与录制一致；
- 预热后 `Danger.monitoring == true`；
- 玩家进入幽灵位置 → 7 帧内 `DIED`，`death_source == "take_01"`；
- 退休后不再杀人（路线证明里 TAKE 03 回家穿过 TAKE 01 的终点不死亡）；
- 序列化体积 217.7 B/s。

未验证：
- 同屏 3+ 幽灵的帧率与可读性；
- 长时间（>10 min）轨道的内存与存档大小；
- 回放位置与录制位置的最大误差（`max_deviation` 有实现，但没有跑过真实录制轨道）；
- 掉帧 / 暂停 / 切换模式时 playhead 是否与物理时间同口径。
