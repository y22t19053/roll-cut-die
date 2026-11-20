# 原版 EXE 连续 Take 验收（主持人卡）

状态：PREPARED_NOT_STARTED。目标是证明交付给玩家的原始 `6bab995` 二进制可完成连续操作；不以工程窗口录像替代。单文件交付不变；旁置 override.cfg 只用于 QA 存档隔离，正式 EXE 无需这个文件。

准备回执：`%LOCALAPPDATA%/RCD-Research/release/d5220d26d62749f6852c0ae3eab8c9e1/receipt.json`。其 `directory` 内仅有 EXE 与隔离配置；校验源与副本 SHA256 均为 `A56F2D1622D7D31DE74D4923ADE5AA85B80B114B4C75C3346E0D2A49F1E165BC`。准备时 expected_user_dir 不存在。准备不证明运行时采纳配置。

启动前运行 `python -X utf8 tools/release_preflight.py <receipt.json 的绝对路径>`。返回 STOP 则不要启动；正式存档若有变化可能只是玩家后来游玩，不覆盖、不回滚。PREFLIGHT OK 只证明当前静态条件符合。

1. 本机主持人在 Explorer 打开回执目录，从 game 子目录双击副本。先不要操作。确认 expected_user_dir 中出现本次新运行日志、包含片场载入和 ORBIT；核对正式 `user://rcd/save.json` 仍与回执一致。路径或日志无法证明隔离则关闭、停止，不做报告或交互、不恢复未知存档。
2. OBS 仅采集游戏窗口，获同意后录制。以实际键盘完成 TAKE 01（至少移动数秒，确保轨道超过预热），R 提交合法报告，SPACE 开拍。TAKE 02 在前一条幽灵仍显影且危险时改道，完成报告、进入 TAKE 03。录像需看清危险环、两者位置、HUD Take/幽灵数量以及两次提交；幽灵先播完或被遮挡则记录为证据不足。不使用调试服务器、eval、传送或写入状态。
3. 正常退出并停止 OBS。保留原始时间码、收工原因、游戏日志及录像哈希；复核 EXE 哈希、正式存档和隔离目录中的成功记录。只有完整链与隔离都成立才报 PASS；前景/录像失败记录未验证。短路线仅验连续性，不证明难度或新手学习。

现有项目窗口对照：[引擎键盘链](NATURAL_LOOP_6bab995.md)。不将本次发布验收当作西侧 A/B 首曝数据。
