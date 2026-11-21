# B3.2｜玩家能否用自己剪掉的路线做下一次决定？

**取舍：先验证「这是我刚才走过的路」，不做会帮忙踩机关的分身。** 前者只读已有采样；后者需要定义触发、同步、选择上限，还会混淆成功幽灵的致命碰撞。依据是已有四作[视角研究](B3_PERSPECTIVE.md)和[教学／时间研究](B3_TEACHING_TIME.md)，没有重搜、也不把原作经验当成 RCD 玩家证据。

| 案例事实（原文） | 对本次选择的含义（推论） | 不移植 |
|---|---|---|
| [Viewfinder：导演谈从纸到空间](https://80.lv/articles/postmortem-developing-viewfinder-a-surreal-perception-bending-puzzle-game) | 用刚才亲手走的折返或停点让人核对来源；程序预画的最短路不能证明这一点。 | 实时切割几何、照片改造现实。 |
| [Superliminal：第三关反复变奏立方体](https://www.3839.com/zixun/950/8895950.htm) | 同一位置剪两次，但两次走不同方向；能认出被替换的是哪一条，比看过第一次特效更有力。 | 强制透视缩放；不靠奇观证明理解。 |
| [Portal：04 室能过关仍可能没学会](https://theportalwiki.com/w/index.php?title=Portal_developer_commentary#Test_Chamber_04) | 问「线来自哪次，横穿它会怎样」，而非只记有没有走到目标。 | 封掉所有旁路、强制唯一解。 |
| [Outer Wilds：同一地点随时间改变](https://blog.playstation.com/2019/10/08/outer-wilds-launches-on-ps4-october-15/) | 一条线只能回答「走过哪里」，不能回答「何时安全」。若需时序，另用成功幽灵的实录时钟验证。 | 大循环倒计时；不把空间轨迹画成安全时刻表。 |

## 隔离灰盒：可玩与不可外推的部分

用 Godot 单独运行 [outtake_echo 场景](../../tools/outtake_echo.tscn)（编辑器 F6，不改主场景）。白点是人，金环是 MARK，三个空方框只是地标。WASD 走，M 打点，绕两个地标后 C 返回金环；蓝线只画刚剪掉的 MARK→CUT。换一条路再 C，第一条线被替换。H 可隐藏／显现；立刻连剪不会保留上一条。没有路线自动生成、幽灵演员、碰撞、读写正式存档或经济结算。

[脚本](../../tools/outtake_echo.gd)把移动的 Node3D 交给正式 [GhostRecorder](../../scripts/ghost/ghost_recorder.gd) 按物理时钟采样；CUT 先收尾，从返回的 GhostTrack 按锚点时间筛选真实样本，投影 x/z 后再 `resume_from`。路线不是另录的鼠标点，更不是从关卡解倒推。这里只读本次剪下的轨迹，不声称能从旧版 Outtake 摘要恢复整条路。俯视台特意去掉 ORBIT30、NPC、致命幽灵、镜头和时间读数；它能证实数据通路，不能证明正式场景易读。

**机械验收**：`godot_run_headless` 指定项目根目录，`scene=tools/outtake_echo.tscn, quit_after=60` 正常退出；再以 `script=tools/outtake_echo_test.gd` 运行[反例脚本](../../tools/outtake_echo_test.gd)，Godot 4.3 输出 `OUTTAKE_SUFFIX_REPLACE_NONCOLLIDING_EMPTY: true`。它比较真实输入产生的首尾坐标、回到 MARK、第二条不含旧路、空剪清除、无 3D 碰撞体。不是真人试玩或 EXE 验收。

**下一道准入（提案，未跑）**：让新人先自由走两条不同路线并各剪一次；不讲蓝线含义，请其指出哪条路留下、能否穿过，并挑一个刚才没经过的地标。交错 H 开／关顺序，用不同地标复测，记录首选、理由及实际经过的位置，不只记到达。图例只标人和锚点，不解释线的来源；主持人也不补充，不把按键教学当作理解。能指出来源、实际横穿且能用它作下一步选择，才值得移入**另一个隔离** ORBIT30 交口，与真实危险幽灵并列辨认；并非准入正式图。

**反例与处置**：若玩家把蓝线当未来导航、怕碰线、或只在读到图例后作答，暂停移植；若两种显隐都凭地标就能完成，保留更便宜的无辅助版本。若需要判断让行先后，本实验缺时间信息，不能靠加亮线条补救。未验证涂装教学、正式地图难度、时间协作或 Final Cut 的效果。
