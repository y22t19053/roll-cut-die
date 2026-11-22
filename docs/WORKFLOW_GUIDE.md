# RCD 开发工作流（WORKFLOW GUIDE）

本文件写的是**这台机器上**怎么干活，不是通用教程。所有路径、命令、版本号都是本机实测值。
快照时间：2026-11-14 14:01。若磁盘与本文件冲突，以磁盘为准，并回来改这一行。

## 0 · 环境事实（已在本机核实）

| 项 | 值 | 核实方式 |
|---|---|---|
| 工程根 | `C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die` | 目录存在 |
| 引擎 | `C:\Users\11ee11\Desktop\工具\程序\Godot_v4.3-stable\godot.exe` | `Test-Path` = True |
| 引擎版本 | `4.3.stable.official.77dcf97d8` | `logs\godot.log` 第 1 行原文 |
| 导出模板 | `%APPDATA%\Godot\export_templates\4.3.stable` | `Test-Path` = True |
| 主场景 | `res://scenes/main/main.tscn` → `scripts/main.gd` | `project.godot` / `.tscn` |
| 工程特性串 | `config/features=PackedStringArray("4.3", "Forward Plus")` | `project.godot` 第 12 行 |
| user:// 目录 | `%APPDATA%\Godot\app_userdata\roll cut die` | 目录存在，内含 `rcd\` 与 `logs\` |

**引擎锁 4.3，不升级。** 理由：本机只有 4.3 stable；导出模板也只装了 4.3.stable。装 4.4+ 会让导出模板、`project.godot` 特性串、全部已跑通的日志对照一起作废。

## 1 · 唯一铁律：不要用 shell 跑 godot

本机的文件沙箱会拦截 Godot 启动时对 `user://`（即上面那个 AppData 目录）的写入。由 shell 派生的 Godot 进程会以 **signal 11 / 段错误** 终止，看起来像项目崩了，实际是启动通道不对。这不是可以绕过的权限问题，换写法也没用。

所以：

- 要跑游戏 → `godot_run_project`
- 要跑测试脚本 / 冒烟 → `godot_run_headless`
- 要导出 → `godot_export_project`
- 要静态改 `.tscn` / 资源 → `godot_headless_op`
- 要语法检查单个脚本 → `godot_validate_script`

下面的命令行只作为**对照阅读**，解释这些工具在底下执行了什么；直接粘贴到 pwsh 里执行会撞上上面那条。若某次 `godot_*` 工具返回 `diagnosis:"sandbox-crash"`，结论是通道问题，重跑工具，不要去查项目 bug。

## 2 · 日常循环

派发、接手或轮换前，从 [RCD 上下文规范](CONTEXT_ARCHITECTURE.md) 取对应层与预算口径，只加载当前任务包；完整历史通过索引按需追溯。

一次改动 = 一次冒烟，不要边改边跑。

1. 改代码或数据。
2. 冒烟：`godot_run_headless(project_path=<工程根>, scene="scenes/main/main.tscn", quit_after=30, timeout_ms=60000)`
   - 等价命令行：`godot.exe --headless --path <工程根> --quit-after 30`
3. 读日志（见 §3），确认三行 info 都在：`session ready` / `room built 24x18` / `main ready: 2 npcs, 4 evidence, ghosts N`。
4. 只有日志干净才进下一步；报错优先，噪音忽略（见 §3.3）。

跑测试脚本（当前的入口脚本是 `tests/smoke.gd`，会加载主场景、跑两帧、打印 `SMOKE RESULT ok`）：

```
godot_run_headless(project_path=<工程根>, script="tests/smoke.gd", timeout_ms=60000)
```

等价命令行：

```
"C:\Users\11ee11\Desktop\工具\程序\Godot_v4.3-stable\godot.exe" --headless --path "C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die" --script tests/smoke.gd
```

在工程根下可简写为 `--path .`。`--script` 目标必须 `extends SceneTree` 并自己 `quit()`，否则 headless 会一直跑直到超时被杀。

导出（**当前未验证**：磁盘上没有 `export_presets.cfg`，见 `PROJECT_STATUS.md`）：

```
godot_export_project(preset_name="Windows Desktop", output_path="build/rcd.exe", debug=false)
```

等价命令行：`godot.exe --headless --path <工程根> --export-release "Windows Desktop" build\rcd.exe`

### 2.1 出包前先摘掉开发用的 autoload（否则发行包每次启动都报错）

`godot-bridge` 每次起本地交互实例都会把 `McpInteractionServer="*res://autoload/mcp_interaction_server.gd"` 写回 `project.godot`，而 `export_presets.cfg` 的 `exclude_filter` 含 `autoload/*`。两者一起的后果是**发行包在启动时打一行 `Attempt to open script 'res://autoload/mcp_interaction_server.gd' … File not found`**（itch 与 B 站 TOY 的网页版都会在控制台里看到）。流程固定为：

```
python tools/strip_dev_autoload.py --strip    # 导出前
godot_export_project(...)                      # 导出（Web 之后还要 python tools/patch_web_shell.py builds/web/index.html）
python tools/strip_dev_autoload.py --restore   # 导出后（把声明还给本地交互测试）
```

`--check` 打印 `present` / `absent`。只删这一行，别的都别动——`project.godot` 是引擎自己会重写的文件，改多了 diff 就没法读了。

## 3 · 日志：两个文件，别搞混

## 3 · 日志：两个文件，别搞混

| 文件 | 谁写 | 路径 |
|---|---|---|
| `runtime.log` | 我们的 `Logger`（`scripts/core/logger.gd`） | `%APPDATA%\Godot\app_userdata\roll cut die\rcd\runtime.log` |
| `godot.log` | 引擎自己 | `%APPDATA%\Godot\app_userdata\roll cut die\logs\godot.log` |

### 3.1 runtime.log 的格式

每行 `秒  tag  内容`，例如 `    0.230  info     main ready: 2 npcs, 4 evidence, ghosts 0`。tag 只有 `info` / `warn` / `error`。**先 print 再写文件**：控制台输出不依赖文件是否可写，所以文件坏了也不会变成哑巴。超过 2 MB 会轮转，只在开头写一行 `# rotated`。

### 3.2 读日志的正确姿势

用 `read` 工具直读绝对路径，或 `grep` 工具检索。不要用 `Get-Content -Raw`（见 §4）。

### 3.3 已知无害噪音

headless 模式（dummy renderer）下，每个网格会打印一次：

```
USER ERROR: Parameter "m" is null.
   at: mesh_get_surface_count (servers/rendering/dummy/storage/mesh_storage.h:120)
```

一个 40 网格的场景就是 40 组，`logs\godot.log` 会因此变得很长。**这是 dummy renderer 的正常行为，不是失败。** 判失败只看三样：`SMOKE`/`RESULT` 行、`runtime.log` 里的 `error` 行、退出码。

## 4 · 本机 pwsh 的两个中文坑

| 坑 | 现象 | 规避 |
|---|---|---|
| `Get-Content` 用 GBK 解码 UTF-8 文件 | 中文变乱码，行号算错，`-Pattern` 匹配不到 | 查行号用 `grep` / `Select-String`；读文件用 `read` 工具 |
| `Get-Content -Raw` → `Set-Content` 往返 | 文件被写成非法 UTF-8，Godot 读 JSON 直接解析失败 | 改文档用 editor 工具或 `edit`；需要脚本改就用 `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)` |

实际踩过的例子：`Get-Content` 报 819 行，字节级统计是 1050 行——差的不是行数，是解码。

## 5 · 数据与文档编辑纪律

- `data/*.json` 是**世界里唯一的数据源**，改它等于改关卡：`studio_map.json` 定墙、家具、NPC 路线、证物坐标、报告区；`case.json` 定证物文本、台词分层、三立场、七判词。
- 改坐标后必须重跑冒烟，看 `room built` 与 `main ready` 的物件数是否仍对；墙把人堵死不会报错，只会让人走不动。
- 文档改完用 `grep` 复查关键字（例：`grep("sealed", "docs/")`），不要凭印象说改了。
- 每个可见文本在数据里是 `{"zh":..., "en":...}` 对，代码只经 `Loc.t()` 取，见 `docs\LOCALIZATION.md`。

## 6 · Git 纪律

**现状：工程根没有 `.git`（已核实 `Test-Path .git` = False）。** 也就是说：没有历史、没有 diff、没有回滚。这是当前第一风险项，比任何未实现的玩法更严重。

初始化（由人执行，不要自动化；先确认 `.gitignore` 内容）：

```
git init
git add .gitignore
git add -A
git commit -m "phase0: godot 4.3 project boots main scene headless"
```

建议 `.gitignore`：

```
.godot/
build/
*.tmp
```

- 不提交 `.godot/`：导入缓存，几千个文件，会让每次 diff 变成噪音。
- 不提交 `build/`：导出产物可重建。
- 提交粒度 = 一次可跑通的状态。提交前必须有一次干净的冒烟日志。
- 提交信息写「做了什么 + 怎么验证的」，不写「update」。
- 混用脚本批量改文件后，先 `git status` 看波及范围，再 `git add -p` 挑块。

## 7 · cost 纪律

每次 interactive 运行都要起一个 Godot 进程并等它初始化。省钱的顺序是：

1. **先读后跑**：能用 `grep` / `read` 判断的问题不要跑游戏。
2. **攒批**：一轮里改完所有相关文件，跑一次；不要改一行跑一次。
3. **用 headless 不用 GUI**：headless 起停更快，日志一样；GUI 只在要看构图/手感时用。
4. **跑短**：冒烟用 `--quit-after 30`，不要留一个长跑的实例占着重启成本。
5. **看日志不看截图**：`runtime.log` 一行胜过一张截图；截图只在验证画面遮挡时用。
6. **单次定位**：怀疑哪个脚本语法错，用 `godot_validate_script` 单文件检查，不要为它跑整个工程。

## 8 · 排障表

| 现象 | 先看哪里 | 常见原因 |
|---|---|---|
| 工具返回 `diagnosis:"sandbox-crash"`，或程序 signal 11 | 启动通道 | 用了 shell 跑 godot。改用 `godot_*` 工具 |
| 没有 `runtime.log` | `Logger._ensure()`；`user://rcd` 是否可写 | 进程没跑起来，或被沙箱拦了写 |
| `main ready: ... ghosts 0` 之后什么也没有 | 正常 | 没有幽灵是初始状态；玩完一局才会有 |
| `main ready` 里 npcs/evidence 数不对 | `data\studio_map.json` | 条目被删或 id 重复 |
| `map: ...` 开头的一串 error | `room_spec.validate` 的返回 | 矩形越界、尺寸非法、出生点在图外 |
| JSON 解析失败 | 文件字节编码 | 被 `Set-Content` 写成非法 UTF-8（§4） |
| `godot.log` 里一堆 `mesh_get_surface_count` | 无需处理 | dummy renderer 噪音（§3.3） |
| 导出报缺模板 | `%APPDATA%\Godot\export_templates\4.3.stable` | 模板版本与引擎不一致，或没有 preset |
