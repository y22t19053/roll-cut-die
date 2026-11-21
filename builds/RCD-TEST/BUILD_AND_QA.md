# BURST 3.1 构建与交接（仅操作者）

此处的说明和 manifest 不随参与者包分发。参与者仅获得分配到的一份中性命名 EXE，不得同时发两个版本、分组对照、暂存工程或 SHA 收据。构建工具从不启动 Godot，不修改主工程，不读写任何用户存档，也不会替换历史 `RCD-ORBIT30.exe`。

## 暂存、导出、校验

1. 使用 Python 3.11+ 在仓库根目录运行 `python tools/build_burst31.py stage --ref <完整冻结提交> --label <新标签>`。首个三包候选冻结在 `6528c850b7366b4c6d7783980c69b9b94c4a9209`，不读取工作树未提交修改。相同提交和标签得到相同暂存内容和实验数据目录；新标签会为两实验分配新的独立目录。正式开发目录 `ROLL CUT DIE/Dev-3.1` 则跨启动和标签持久化，与历史版数据隔离。
2. 对返回的三个 `{project_path, preset_name, output_path}` 分别使用 `godot_export_project`，`debug=false`，Godot 4.3 与对应 Win64 release 模板。输出只能是 `*-candidate.exe`。如果新暂存工程还没有导入字体/图标，先在 Godot 编辑器中打开暂存工程等待导入、关闭，不需启动场景；不要把 `.godot` 从主工程复制进去，不要让运行工具向暂存工程注入交互 autoload，不要通过脚本或 shell 启动引擎。
3. `python tools/build_burst31.py verify --label <标签>` 校验 PE 的嵌入 PCK、数据与配置字节以及三包边界。通过后，`python tools/build_burst31.py deliver-candidates --label <标签>` 在私有暂存区的 `delivery/` 生成一套中性最终命名的候选副本，并在暂存根生成 `candidate-manifest.json`。正式落位时另行运行 `python tools/build_burst31.py finalize --label <标签>`，生成 `final-manifest.json`；任一正式目标已存在则拒绝整套落位。首次 DEV 内部候选已占据共用路径时，使用 `deliver-candidates`，不要让脚本或人工覆盖旧文件。

候选/最终收据记录冻结提交、候选和交付路径、EXE SHA-256 及字节数、暂存 `project.godot` 和 preset SHA-256、PCK 文件表和实验嵌入配置 SHA-256。实验分析器的 `--config-sha256` 对应 manifest 中的 `config_sha256`（原始 `tools/trial_build_config.json` 字节）；不是 `project_godot_sha256`，也不是 EXE SHA。试验 header 的 `config` 应同时对上 `git_commit`、`exe_sha256`、`staged_project_sha256` 和 `project_config_sha256`。

## 实机证据（有这些证据才标通过）

- DEV：从 Explorer 双击候选 EXE；验证标题、设置和正常进入。退出重开确认新数据目录内的设置持久化且历史版存档未动。完成整轮 MARK / CUT / ROLL 和后续 ghost 游玩，不能以源工程测试或单纯可启动替代。
- 每个实验 EXE 首启均验证中英 consent；分别验证拒绝仍能玩且不产生 `west_trials` 数据、接受后 F8 才启采、退出/上限正常封存日志（完整 `trial.jsonl`，非 `trial.partial`）。记录只应出现在 `%APPDATA%/<manifest user_dir>/west_trials/<session>/trial.jsonl`；无常规 `rcd/save.json`、`rcd/runtime.log` 或 settings 写入。用等同于实际分发的 EXE 直接启动，不带命令行研究参数，不放 `override.cfg`。按包分别核对记录 header 条件和 SHA，并保留私下验收证据。看得见字形和能读取录像同样属于验收。
- 这些是工程与分发验证，不是外部参与者结果。不得把主动 QA、合成或拒绝采集的试玩计入研究试次。
