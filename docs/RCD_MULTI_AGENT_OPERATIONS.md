# RCD_MULTI_AGENT_OPERATIONS — Gemini 主控与三路 Codex 协同作战规范

> 建立与实测日期：2026-11-25  
> 关联文档：`docs/WORKFLOW_GUIDE.md` · `docs/MODEL_ROUTING_POLICY.md` · `docs/RCD_CONSTITUTION.md`

---

## 1. 协同架构真相与角色矩阵

经阶段 B 与阶段 D 对本机 DSH 会话及 CLI 环境的实查确认：
- DSH 当前会话内 `list_agents` 仅运行根代理 `lead`（**Gemini 4 Carbon**），DSH 内置 `subagent` 工具当前仅暴露 `yagemini` 路由；同时按接管指令，**Claude 不再作为固定研发成员**。
- 本机已完整配置并接通基于 `@openai/codex` CLI 与 `xhyapi-codex`（`responses` 协议）的三路独立 Codex 执行端，可通过后台作业（`pwsh run_in_background`）在各自隔离的 Git Worktree 中真正并发运行。

| 节点代号 | 绑定模型 | 核心职责边界 | 默认独占文件域（Ownership） |
|---|---|---|---|
| **Lead 主控** | **Gemini 4 Carbon (High)** | 项目总研发协调、设计裁决、架构把关、任务拆解、Worktree 派发、视觉截图审美验收、代码合并与测试总门禁 | `docs/RCD_*.md`、`project.godot`（最终集成审定）、跨分支 `git merge / cherry-pick` |
| **Codex A** | `gpt-6-astra` | **Godot 核心工程与玩法机制**：相机运动（ROLL / ORBIT 30°/s）、Ghost 录制与确定性碰撞、MARK/CUT、`relay` 房间/翻景、`free-blocking` 机制隔离与打包脚本 | `scripts/player/`、`scripts/camera/`、`scripts/ghost/`、`scripts/take/`、`scripts/relay/`（非纯 UI 表现层）、`scenes/relay/`、`tools/strip_dev_autoload.py` |
| **Codex B** | `gpt-6.2-sol` | **UI 艺术指导落地与视听界面实现**：主菜单（`TitleScreen` + `NightStage` / 3D 实景舞台）、`UiKit` 主题体系、暂停、HUD、剪辑台/放饭、Company Move、NG 与 WRAP 界面、字体排版与着色器/本地素材整合 | `scripts/ui/`、`scenes/front/`、`assets/fonts/`、`visual/`、`shaders/`（新建时） |
| **Codex C** | `gpt-6.2-astra` | **自动化测试、工程审计与独立代码审查**：扩展 `tests/run_all.gd` 与 Python 测试套件、修复 `west_trial` 夹具、排查 `ObjectDB` 泄漏与 Dummy Mesh 空指针告警、对 Codex A/B 的提交做独立 Diff 审查 | `tests/`、`tools/release_preflight.py`、审查回执报告（只读审阅 A/B 的分支） |

---

## 2. 阶段 D 并行调度实测验证记录（2026-11-25）

为验证三路 Codex 执行端的真实并发可行性、目录隔离与结果归并，已在不触碰 `roll-cut-die` 游戏代码的前提下完成低风险沙盘验证：
- **隔离工作根**：`C:\Users\11ee11\AppData\Local\Temp\rcd-stage-d-verify\`（划分 `codex-a/`、`codex-b/`、`codex-c/` 独立子目录及 `merged/` 归并目录）。
- **并发回执（全部成功返回，零越界写入）**：
  - `codex-a\slot_a.json` → `{"worker":"codex-a","role":"godot-core","model":"gpt-6-astra","isolated":true}`
  - `codex-b\slot_b.json` → `{"worker":"codex-b","role":"ui-visual","model":"gpt-6.2-sol","isolated":true}`
  - `codex-c\slot_c.json` → `{"worker":"codex-c","role":"qa-audit-review","model":"gpt-6.2-astra","isolated":true}`
- **审查与归并验证**：Codex C 路径校验与主控归并写入 `merged\` 全部通过，证实三路 Codex 可稳定并行执行并在文件级隔离下无冲突合流。

---

## 3. 并行开发铁律与 Worktree 隔离协议

1. **严禁共享同一工作树并发改码**：
   - 任何允许修改工程代码的 Codex 任务，必须在独立的 Git Worktree（统一建于 `default-workspace/.rcd-worktrees/<slot>-<task-slug>` 或分支专属 worktree）上执行，分支命名遵循 `codex-a/<topic>`、`codex-b/<topic>`、`codex-c/<topic>`。
2. **严禁跨槽同时修改同一 `.tscn` 场景或同一核心 `.gd` 脚本**：
   - 若某项功能同时涉及 `relay_run.gd` 与 `title_screen.gd`，必须先定义清晰的信号/数据结构契约：由 Codex A 改 `relay_run.gd`，Codex B 改 `title_screen.gd`，主控在集成 worktree 联调。
3. **Godot 运行与测试统一收口**：
   - Codex CLI 子进程运行于常规命令行环境，**禁止让 Codex 子进程自己在 shell 内调用 `godot --headless`**（避免触发沙箱 Signal 11 或争抢端口 9090）。
   - Codex 负责代码编写、静态语法检查与 Python 脚本验证；**所有 Godot 无头测试（`godot_run_headless`）、场景操作（`godot_headless_op`）与实机交互截图（`godot_run_project` + `godot_screenshot`）一律由 Gemini 主控通过 `godot-bridge` 统一执行**。
4. **标准任务派发包（Task Packet）七要素**：
   每次派单必须明确：① 执行端与模型、② 任务目标、③ 输入文件（含精确路径）、④ 允许写入的输出文件白名单、⑤ 前置依赖关系、⑥ 客观验收标准、⑦ 是否允许合入正式工程。
5. **失败重试与暂停恢复机制**：
   - 单端 API 超时或瞬时 5xx：保留原 Worktree 已落盘进度，最多自动重试 2 次；若某模型通道持续不可用，主控立即将该 Worktree 切换至可用备用模型（如 `gpt-6-astra` ↔ `gpt-6.2-astra`）并记录于运行日志，绝不伪造并行回执。
   - 合并门禁：① `git diff` 无越界文件与密钥残留 → ② Codex C 独立代码审查通过 → ③ 主控执行 `godot_run_headless(script="tests/run_all.gd")` 全绿（`≥ 646 assertions`）+ UI 改动必过实机截图视觉审查 → ④ 合入目标分支。

## 4. 2026-11-25 · Sprint 3 / 4 文件分工

Sprint 1 出生点与测试卫生修复、Sprint 2 通告单与三重曝光标题已进入 `master@4f0f1ea`。本轮三个工作树均从该提交派生，具体文件归属优先于 §1 的默认目录分工。

| 工作树分支 | 独占交付 |
|---|---|
| `codex-a/sprint4-audio-and-deai` | 22,050 Hz 配乐、动作 Foley / FX、−34 dB 静置低语及片场环境表现；维持 Ghost 与房间判定。 |
| `codex-b/sprint3-inrun-ui` | 局内设置、暂停、HUD、手工通告单与 Steenbeck CUT 预览。 |
| `codex-c/sprint3-4-qa-and-docs` | `tests/test_inrun_ui_and_deai.gd`、`tests/run_all.gd` 及工程状态、路线图、设计决策、协作规范、项目总览五份档案。 |

同属 `scripts/relay/` 或 `scripts/ui/` 的任务仍按文件指定唯一写入方。C 使用预览方法存在性检查兼容合并顺序。Lead 集成后通过 godot-bridge 运行全套测试，检查退出日志，并以 Forward+ 实机核验视野及动效；试听与真人盲测另记回执。

## 5. Sprint 5 · 分支与验收

| 工作树 | 分支 | 交付方向 |
|---|---|---|
| `codex-a-sprint5-world` | `codex-a/sprint5-world` | 互联摄影棚与路线 |
| `codex-b-sprint5-props` | `codex-b/sprint5-props` | 机关与片场道具 |
| `codex-c-sprint5-guard` | `codex-c/sprint5-guard` | 验收脚本、Dummy 日志与活动档案 |
| `codex-d-sprint5-finalcut` | `codex-d/sprint5-finalcut` | WRAP·Final Cut |

分支基线为 `master@c46ca46`。Sprint 5 的本地回归与 CI 在纳入 C 脚本的工作树根目录执行：

```powershell
python tools/verify_all.py --json
```

主控读取退出码与 JSON。基线回执为 Python 31 项通过、Godot 815 条断言、`stderr_noise` 为 0。其他引擎诊断可从 stderr 查看。

## 6. Sprint 6 四路并行（B/D/E + 本端 C）

以下按本地分支提交记录区分已提交文件与派单范围。C 的基点为 `3fc36db`。

| 执行端 | 分支 | 文件与交付记录 |
|---|---|---|
| B | `codex-b/sprint6-gantry` | 负责 `scripts/relay/relay_rooms.gd` 中的 gantry 房间接入与对应回归。C 验收时分支引用仍在基点。 |
| D | `codex-d/sprint6-score` | 负责 `scripts/relay/relay_sound.gd` 的分层配乐。C 验收时分支引用仍在基点。 |
| E | `codex-e/sprint6-frame` | 提交 `7fe4820` 包含 `out_of_frame.gd`、`relay_run.gd`、`relay_rooms.gd`、`relay_sound.gd`、`loc.gd`，另有出画回归、测试注册、预览场景与截图、路线图及设计记录。 |
| C | `codex-c/sprint6-guard` | `tests/test_room_families.gd`、`tests/test_no_softlock.gd`、`tests/softlock_hit_probe.gd`、`tests/run_all.gd`、`tests/only.gd`、`tools/verify_branch.py`、`tools/verify_all.py`，以及路线图、工程状态与本档案。 |

集成裁决：主控按功能合并 B 的房间构建与 E 的门洞，保留 D 的分层配乐与 E 的出画音效。对 `tests/run_all.gd` 取各端新增模块的并集，路线图按编号保留各端回执。C 仅写第 3 行；本次未执行跨分支合并。集成后在候选树重跑完整门禁，核对条件用例已执行。

## 7. Sprint 7 分支与冲突面

| 分支 | 本轮负责范围 |
|---|---|
| `codex-g/sprint7-scale` | `relay_run.gd` 的规模常量、`relay_rooms.gd` 的灯架棚位与房间规划 |
| `codex-f/sprint7-craft` | `relay_run.gd` 的结算逻辑与新增的 `scripts/relay/craft.gd` |
| `codex-d/sprint7-archive` | `relay_rules.gd` 的档案逻辑与 `title_screen.gd` 的生涯展示 |
| `codex-c/sprint7-guard` | 仅 `tests/`、`tools/`、`docs/` 中的独立验收与交接档案 |

G 与 F 共用 `relay_run.gd`。主控集成时按常量区和结算区分别核对改动，并保留各支在测试入口注册的用例。
