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
