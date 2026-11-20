# 原版 EXE 连续 Take 验收（主持人卡）

当前：**新副本通过静态预检，尚未启动**。新回执 `%LOCALAPPDATA%/RCD-Research/release/4adfceea506c4da2abde6bcf00dd331d/receipt.json`。可运行 `python tools/prepare_release_trial.py` 从固定 SHA 的本地 EXE 准备新场次；不要复用失效场次。现场仍须按下文在启动前再次预检。

历史：**STOP（旧回执失效）**。2026-11-21 只读复检退出码 1：`production save changed since preparation; do not restore`。不能由指纹差异断定原因或恢复旧数据；禁止用本回执启动，也不修改它来消除差异。下次现场验收需用新的随机目录和准备回执记录届时基线，再独立通过预检。目标是证明交付给玩家的原始 `6bab995` 二进制可完成连续操作；不以工程窗口录像替代。单文件交付不变；旁置 override.cfg 只用于 QA 存档隔离，正式 EXE 无需这个文件。

准备回执：`%LOCALAPPDATA%/RCD-Research/release/d5220d26d62749f6852c0ae3eab8c9e1/receipt.json`。其 `directory` 内仅有 EXE 与隔离配置；校验源与副本 SHA256 均为 `A56F2D1622D7D31DE74D4923ADE5AA85B80B114B4C75C3346E0D2A49F1E165BC`。准备时 expected_user_dir 不存在。准备不证明运行时采纳配置。

启动前运行 `python -X utf8 tools/release_preflight.py <receipt.json 的绝对路径>`。返回 STOP 则不要启动；正式存档若有变化可能只是玩家后来游玩，不覆盖、不回滚。PREFLIGHT OK 只证明当前静态条件符合。

1. 本机主持人在 Explorer 打开回执目录，从 game 子目录双击副本。先不要操作。窗口显示后运行刚才同一条预检命令并加 `--after-boot`；这是日志与存档比对，不证明输入或通关。确认 expected_user_dir 中出现本次新运行日志、包含片场载入和 ORBIT；核对正式 `user://rcd/save.json` 仍与回执一致。路径或日志无法证明隔离则关闭、停止，不做报告或交互、不恢复未知存档。
2. OBS 仅采集游戏窗口，获同意后录制。以实际键盘完成 TAKE 01（至少移动数秒，确保轨道超过预热），R 提交合法报告，SPACE 开拍。TAKE 02 在前一条幽灵仍显影且危险时改道，完成报告、进入 TAKE 03。录像需看清危险环、两者位置、HUD Take/幽灵数量以及两次提交；幽灵先播完或被遮挡则记录为证据不足。不使用调试服务器、eval、传送或写入状态。
3. 正常退出并停止 OBS。保留原始时间码、收工原因、游戏日志及录像哈希；复核 EXE 哈希、正式存档和隔离目录中的成功记录。只有完整链与隔离都成立才报 PASS；前景/录像失败记录未验证。短路线仅验连续性，不证明难度或新手学习。

现有项目窗口对照：[引擎键盘链](NATURAL_LOOP_6bab995.md)。不将本次发布验收当作西侧 A/B 首曝数据。
