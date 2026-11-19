# 窗口实测 · 自然 TAKE 01→02→03（88eb514）

Godot 4.3，Windows，本地窗口。独立工作树与独立 user:// 存档。工程端口 9101；探针仅注入移动动作和 R/3/SPACE 键的按下及释放，并读取状态。未传送、未调用提交/重拍函数、未手建或注入轨道。此证据来自运行中的源码工程，不代表 Windows 导出包已完成同样操作。

1. TAKE 01：出生点 (2,16.6)，W 65 个物理帧、松开 14 帧、S 46 帧、松开 14 帧，站到 (2,15.64)。R 开报告，3 选 REFRAME，SPACE 进入下一 Take。真实 history：take 1 / complete / reframe_held。TAKE 02 开始时 1 个幽灵。
2. TAKE 02：出生后有等待；D 50 帧到 (4.554,16.6)，反向后 W 进入报告区 (1.947,15.379)。同样通过 R/3/SPACE 提交。TAKE 03 现场读取 take_index=3、ghost_count=2、ghost_nodes.size=2、phase=ROLLING。两条轨道 duration 分别 2.4 s、2.7 s。
3. TAKE 03：玩家留在出生点，后续现场读取 DIED / death_source=take_02、HUD DIED TO TAKE 02，玩家位置 (2,16.6)。死亡截图：shots/12_natural_take03.png。

限制与发现：第二轮等待期间首轮短轨道可以播完，本次不能证明人在活动幽灵前主动闪避。空证物 REFRAME 即可收工，会绕开 B/C 关卡。更重要的是，第二次提交时 history.at=644.016 s，但轨道只有 2.7 s，长时间站定很可能没有进入回放时钟；需针对起步前等待、路中停步、终点停步做与真实物理时钟对照的回归，修正前不能声称忠实重放。真人手感与导出包录屏仍待测。