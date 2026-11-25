# RCD_LOCAL_WORKFLOW_INVENTORY — 本地生产工具、素材库与工作流总账

> 审计与核验日期：2026-11-25  
> 关联文档：`docs/WORKFLOW_GUIDE.md` · `docs/MODEL_ROUTING_POLICY.md` · `visual/ART_DIRECTION.md` · `visual/DEAI_PLAN.md`  
> **使用铁律**：先盘点复用本机成熟管线与本地资产，再改造扩展，最后才考虑新增依赖；严禁在任何文档或仓库提交中写入 API Key / Bearer Token。

---

## 1. DSH 主控环境与插件运行态

| 组件 | 实查位置 / 配置 | 当前状态 | 备注与约束 |
|---|---|---|---|
| **DeepSeek Harness (DSH)** | `C:\Users\11ee11\AppData\Local\Programs\DeepSeek Harness\resources\app.asar\dsh\` · Web GUI `http://127.0.0.1:57744` | **正常运行** | 文件策略 `danger-full-access`（`approval: never`），严禁传 `sandbox_permissions` 触发自动拒绝 |
| **主控模型** | `yagemini / gemini-4-carbon`（High） | **在线主控** | 负责全局架构、设计裁决、Codex 调度、代码验收与持久目标推进 |
| **`tool-godot-bridge`** | `godotPath: C:\Users\11ee11\Desktop\工具\程序\Godot_v4.3-stable\godot.exe` | **已就绪** | **唯一合法 Godot 启动通道**（非沙箱子进程服务）；严禁通过 `pwsh/bash` 直接跑 `godot --headless`（会因 `user://` 写入拦截导致 Signal 11 崩溃） |
| **Godot 编辑器外部实例** | 本机活跃 Godot 进程（如编辑器/外部预览实例） | **运行中（受保护）** | **严禁 `Stop-Process` / `taskkill` 强杀**；`godot_run_project` 会自动接管同端口实例（`external: true`）或指定空闲端口独立拉起 |
| **Mnemon 记忆系统** | Runtime Memory (`USER.md` / `MEMORY.md`) + Mnemon Documents (`36638903`, `1d506e29`, `c87e8407`) | **正常运行** | 已恢复 Ghost 出生秒杀公平性审计、ORBIT 30°/s 基线与 550→646 断言演进档案 |
| **Hindsight 页面服务** | `127.0.0.1:9077` | **离线（需留意）** | `connect ECONNREFUSED 127.0.0.1:9077`；历史考据改走 Git、Mnemon Documents 与仓内 `docs/` |
| **`ui-task-board` / `experimental-inspector`** | DSH 桌面 Profile 插件 | **降级/异常** | `ui-task-board` 因 `ledger-v2.lock` 锁占用未就绪；`experimental-inspector` 报 `globalThis.fetch` 异常；任务跟踪优先走仓内路线图与会话持久 Goal |

---

## 2. 模型路由与三路 Codex 执行端能力

| 通道 / 角色 | 调用方式 | 可用模型（实测） | 成本 / 定位 |
|---|---|---|---|
| **Gemini 主控（Lead）** | DSH 当前主会话 | `gemini-4-carbon` | 总研发协调、架构审查、UI 艺术指导裁决、合并门禁 |
| **Codex CLI 三路执行端** | 本机 `@openai/codex` CLI（`C:\Users\11ee11\.codex\config.toml` + `default-workspace\xhyapi-codex\` 桥接 `responses` 协议） | `gpt-6-astra`（Codex A）· `gpt-6.2-sol`（Codex B）· `gpt-6.2-astra`（Codex C） | 通过独立 Git Worktree / 隔离目录并发运行 `codex exec`，已在阶段 D 实测跑通三端并发与无冲突归并 |
| **DSH 内置扩展路由** | `cordis.patch.yml` 已挂载 Provider | `ya`（含 `gpt-image-1 / 1.5 / 2` 等图像与文本路由）、`mumu`（`deepseek-v4.1-flash-1017`）、`yagemini` | 按需辅助生成或子任务巡检（本次不再将 Claude 作为固定研发成员） |
| **本地离线推理（零成本）** | 本机 `ollama` CLI | `qwen3-8b-q4`、`qwen3-4b-q4:latest`（实测 ~70.7 tok/s） | 本地批处理文本校验、日志筛查 |

---

## 3. 核心生产工具链清册（引擎、3D、图像、音视频、发布）

| 类别 | 工具名称 | 本机精确路径 | 状态与直接复用场景 |
|---|---|---|---|
| **游戏引擎** | Godot Engine v4.3-stable | `C:\Users\11ee11\Desktop\工具\程序\Godot_v4.3-stable\godot.exe` | 经 `godot_*` 工具链驱动运行、无头测试（`tests/run_all.gd`）、场景操作与 Win/Web 导出 |
| **3D 建模与渲染** | Blender 5.2.1 (x64) | `C:\Users\11ee11\Tools\blender-5.2.1-windows-x64\` | 制作片场灯具、摄影机轨道、物理场记板、立体道具与烘焙贴图 |
| **本地生图引擎** | ComfyUI Windows Portable + SDXL 管线 | `C:\Users\11ee11\Tools\comfyui\ComfyUI_windows_portable\` · `D:\ComfyModels\` · `C:\AI\` | 已配齐 Checkpoints（含 RealVisXL V5）、ControlNet、IPAdapter、CLIP Vision、AnimateDiff，支持零外部费用的原创材质、海报底图与片场概念图生成 |
| **图像处理脚本** | Python (Pillow / NumPy / 抠图与纹理合成) | `C:\Users\11ee11\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` · `C:\Users\11ee11\miniconda3\python.exe` · `C:\AI\remove_bg.py` | 仓内已有 `tools/make_cover.py`、`tools/make_toy_poster.py`、`tools/make_textures.py`、`tools/make_textures_sdxl.py`、`tools/make_props_sdxl.py`（注：PATH 上无 ImageMagick `magick`，统一复用 Python Pillow/OpenCV 管线） |
| **音视频合成与转码** | FFmpeg / FFprobe 8.1.1 + 程序化音频脚本 | 系统 PATH `ffmpeg` / `ffprobe` · `roll-cut-die/tools/make_audio.py` | 录屏转码、预告片剪辑、WAV 环境底噪与片场拟音（Foley / Slate Clack）程序化生成 |
| **压缩与可执行文件工具** | 7-Zip (`7zr.exe`) · `rcedit` | `C:\Users\11ee11\Tools\7zr.exe` · `C:\Users\11ee11\Tools\rcedit\` | 发行包归档、Windows EXE 图标与版本元数据注入 |
| **平台发布 CLI** | itch.io `butler` · Bilibili `toy` CLI | `C:\Users\11ee11\Tools\butler\butler.exe`（注：未加入全局 PATH，须用绝对路径调用） · `C:\Users\11ee11\AppData\Local\Programs\toy\toy.EXE` | 配合 `tools/release_preflight.py`、`tools/strip_dev_autoload.py`、`tools/patch_web_shell.py` 完成洁净打包（**未经创作者明确批准严禁执行外部上传**） |

---

## 4. 本地资产与盘符资源仓库盘点

### 4.1 `roll-cut-die` 仓内既有资产（UI 升级第一优先级复用源）
- **字体**：`assets/fonts/RCD-Noto.otf`（含 `OFL.txt` 开源授权，中英文全覆盖；可搭配引擎 FontVariation 字重/字距控制或引入 `D:\Assets\fonts\` / `C:\Users\11ee11\Tools\fonts-in\` 经开源授权核验的标题/等宽工业字体）。
- **片场 3D 与材质贴图**：`assets/studiolot/green_stage/`（绿幕摄影棚资产）、`assets/textures/`（`deck.png`, `deck_ai.png`, `flat.png`, `metal.png`, `wall.png`）、`scenes/studiolot/`、`scenes/backlot/`、`scenes/relay/`（`run.tscn` 与五类 `I/L/O/H/S` 棚体几何、天桥、轨道）。
- **既有片场 UI 组件与音效**：`scripts/ui/slate_board.gd`（程序化场记板）、`scripts/ui/slate_audio.gd`、`scripts/ui/foley.gd`、`scripts/ui/mark_beacon.gd`、`scripts/ui/night_stage_music.gd`、`assets/audio/`（`bed_calm.wav`, `bed_tense.wav`, `bed_halt.wav` 及其 dry 版本 + `studiolot` 音效）。
- **既有视觉成品与实机截图**：`visual/`（`cover*.png`, `capsule_1920.png`, `toy_poster.png`, `toy_icon.png`, `preview/backlot-portals/`）与 `shots/`（30 项实机镜头、机位模式与死亡反馈截图）。

### 4.2 本机 `D:\` 与 `C:\` 创作者资产库
- `D:\Assets\`：含 `ambientcg`（PBR 材质）、`fonts`（本地字体库）、`hdri`（环境光贴图）、`icons`、`kenney`、`models`、`blender-addons`、`godot-addons`。
- `D:\AI_RESOURCE_HUB\` & `D:\AI_STACK\` & `D:\CREATOR_FOUNDRY\`：统一整理的模型索引、ComfyUI 工作流、测试过的高可用视觉/音视频资产与项目模板。
- `D:\MacGuffin_Backups\` & `D:\PROJECTS\`：含 `MACGUFFIN_TRAILER_R13_7`、`TheOfficialCut_MegaJam` 及历史备份包（**只读参考，严禁修改或覆盖**）。
- `C:\Users\11ee11\Tools\`：含 `textures`、`voices`、`fonts-in`、`godot_tpl`。

---

## 5. 需要修复或加固的本地工作流项

1. **Git Worktree 积压治理**：当前仓库挂有 `21` 个关联 worktree（含 `Temp/rcd-*` 9 个临时验证树与 `.agents/worktrees/*` 嵌套树），后续需在核对无唯一未合入代码后归档清理失效 worktree 引用，防止分支锁冲突。
2. **主工作区脏树拆分**：需先用独立分支保存 `free-blocking` 溢出改动与 `toy_bridge` 排行榜改动，恢复 `master` 干净可重现状态。
3. **Python 旧试玩测试脚本过时**：`tools/west_trial_operator.py` 硬编码了早期 `campaign` 时代 `project.godot` 配置断言，导致 `tests/test_west_trial_prepare.py` 报 2 个 Error，需由 Codex C 更新或按历史测试分层标记。
4. **PowerShell 内联 Python 引号剥离规避**：Windows PowerShell 5.1 下 `python -c "..."` 会剥离内部双引号，自动化命令一律采用 `@' ... '@ | & $py -` 标准输入管道写法。
