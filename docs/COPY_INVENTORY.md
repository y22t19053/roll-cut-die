# 玩家可见文案全清单

> 用途：作者自己重写文案用。**只列不改**——这份文件是索引，不是改稿。
> 采集时间 2026-11-22，来源是当前代码（`scripts/relay/*.gd`、`scripts/ui/*.gd`）。
> 每条都标了「在哪出现 / 什么时候出现 / 现有的中英文」。
> 改完之后告诉我，我按这份表逐条替换（`_w("中","英")` 两列一起换，占位符 `%d %02X %.1f` 不动）。

规则（换文案时唯一要守的）：**占位符原样保留**（`%d` `%02d` `%06X` `%.1f`），`\n` 表示换行，棋盘格一样的固定词（MARK / CUT / TAKE / SET / ACT）可以选择保留或全改成中文。

---

## 1 · 标题页

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| T1 | 标题 | ROLL / CUT DIE（三行大字） | 同 |
| T2 | 副标题 | WASD 或方向键移动 · 走到亮起的线 | Move with WASD or the arrow keys · Go to the lit line |
| T3 | 一句话前提（两行） | 你在补拍一条镜头。棚里的人不会为你停下来。\nC 剪回 · M 落点 · 空格 确认 | You are reshooting a take. The crew will not stop for you.\nC to splice · M to mark · SPACE to confirm |
| T4 | 动效提示 | 画面运动可能引起不适，开始前可在此减弱动态效果。 | — |
| T5 | 动效开关 | 减弱动态效果：开 / 关 | — |
| T6 | 动效设置链接 | 动效设置… | Motion settings… |
| T7 | 开始按钮下的说明 | 新手 · 四节十二棚 · 一局 6–9 分钟 | Novice · four acts, twelve sets · 6–9 min a run |
| T8 | 难度名 | 新手 / 专家 / 大师 | Novice / Expert / Master |
| T9 | 难度解锁后缀 | · 新手通关解锁 / · 专家通关解锁 | · clear Novice / · clear Expert |
| T10 | 难度 tooltip | 通关当前难度以解锁下一档 | Clear a difficulty to unlock the next one |
| T11 | 继续按钮 | 继续这一卷 | CONTINUE |
| T12 | 继续按钮下的位置 | 棚 %02d / %d　第 %d 节 | SET %02d / %d　ACT %d |
| T13 | 局外记录 | 已跑 %d 卷 · 最远 %d / %d 棚 | %d runs · best set %d / %d |
| T14 | 每日种子 | 每日种子 %06X | DAILY SEED %06X |
| T15 | 菜单 | 设置 / 制作名单 / 退出游戏 | Settings / Credits / Quit |
| T16 | 开始失败提示 | 无法开始新游戏，详见 user://rcd/runtime.log。 | — |
| T17 | 页脚提示 | 鼠标或方向键 + 回车 · F2 切换语言 | — |
| T18 | 制作名单 | 出品与制作 / MacGuffin Works / 游戏引擎 · Godot Engine / 字体 · Noto Sans CJK SC / © 2014–2021 Adobe · SIL OFL 1.1 | A GAME BY / ENGINE · Godot Engine / TYPE · Noto Sans CJK SC |
| T19 | 名单里的返回 | 返回标题 | Back to title |

---

## 2 · 开局场记板（一局只出现一次）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| B1 | 大字 | ROLL. | 同 |
| B2 | 角标 | 第 %02d 条 | TAKE %02d |
| B3 | 副行（两行前提） | 你是来补拍的。原来那条，废了。\n棚子每晚换搭，站进镜头的只有几个。 | You are here to reshoot. The take before this was ruined.\nThe set is rebuilt every night, and only a few will stand in it. |
| B4 | 板面字段 | SCENE — / TAKE %02d / ROLL 01 | 同 |

---

## 3 · 新手教学（第 1 节前两棚，每句只出现一次）

| # | 触发时机 | 现有中文 | 现有英文 |
|---|---|---|---|
| L1 | 开局 0.8 秒后 | 走到亮起来的那条线。 | Walk to the line that is lit. |
| L2 | 第一次回头 | 过了。回头，走到另一头那条线。 | Across. Now turn around for the line at the far end. |
| L3 | 自己的录像真的走到 3 m 内之后 | 刚才走过去的是你上一趟的录像。撞上就死。 | That one that just walked past was your last take. Touch it and you are done. |
| L4 | 第二次回头时 | 按 C 看一眼自己留下的落点。看片不要钱。 | C shows where your own takes stopped. Looking is free. |
| L5 | 第三条录像开始时 | M 在这里留一个落点。失手会自动回到最近的落点。 | M leaves a mark here. A collision returns you to the last one. |
| L6 | 道具盘第一次打开 | 先拿一件东西，再选下一棚。 | Take one thing, then pick the next set. |
| L7 | 门卡第一次打开 | 这三张是下一棚。按 1 / 2 / 3 或点一下。 | Three sets for the next one. Press 1 / 2 / 3 or click. |
| L8 | 第一次关门 | 这一条是你刚才留下的。它会迎面回来。 | That is your last take. It comes back the other way. |

---

## 4 · 甲板上的通告（每棚一张，按第几节取不同句子）

| # | 第几节 | 现有中文 | 现有英文 |
|---|---|---|---|
| N1 | 第 1 节 | 通告：今天补第一条。上一条被剪了，剪的人没留名。 | Call sheet: one take to reshoot today. The last one was cut, and nobody signed it. |
| N2 | 第 2 节 | 地上那圈胶带是昨天的走位。标得比你准。 | The tape on the deck is where they stood yesterday. They stood it better. |
| N3 | 第 3 节 | 灯不够了。场务说再拍两条就收，他没说拍不拍得完。 | Not enough light left. The gaffer says two more takes, and does not say two more of what. |
| N4 | 第 4 节 | 门那头是交货口。过线，这一卷就不是你的了。 | Past that door is the delivery bay. Cross the line and this reel is somebody else's. |

**通告背面（第二行）：这一族怎么走**（每族一句，跟着上面的通告一起出现）

| # | 族 | 现有中文 | 现有英文 |
|---|---|---|---|
| N5 | i 空棚 | 这一条是空的。中间那块台，绕过去。 | This one is bare. The slab in the middle: go round it. |
| N6 | l 木箱 | 口岸宽，巷子窄。别贴着箱子走。 | Wide mouth, narrow lane. Do not hug the crates. |
| N7 | o 环 | 环在里头。人走外侧。 | The ring is inside. Walk the outside of it. |
| N8 | h 吊轨 | 两条长巷。中间不通。 | Two long lanes. Nothing crosses the middle. |
| N9 | s 风道 | 两个弯。光带先往侧道拐。 | Two bends. The line turns into the side lane first. |

---

## 5 · 换场单（每两棚一次）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| A1 | 抬头 | 换场单 / 签哪一张？ | NEW CALL / Sign one |
| A2 | 卡片抬头 | CALL SHEET / 0%d | 同 |
| A3 | 契约一 | 赶一条 / 下一节每棚 3 趟 / 现在扣 1 MARK / −1 MARK | RUSH / next act: 3 legs a set / costs 1 MARK now / −1 MARK |
| A4 | 契约二 | 多留一条 / 下一节每棚 5 趟 / 现在给 1 CUT / +1 CUT | OVERTIME / next act: 5 legs a set / pays 1 CUT now / +1 CUT |
| A5 | 契约三 | 不许宽限 / 下一节没有 0.75 秒宽限 / 接片作废，给 2 MARK / +2 MARK | BLACKOUT / next act: no 0.75 s grace / no splice, +2 MARK now / +2 MARK |
| A6 | 底部提示 | 第 %d 节。签一张。 | Act %d. Sign one. |
| A7 | 点选提示 | 点选，或按 1 / 2 / 3 | Click your pick, or press 1 / 2 / 3 |

---

## 6 · 道具盘（每两棚一次）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| I1 | 抬头 | 道具盘 / 带走一件 | SUPPLY TRAY / Take one |
| I2 | 保险接片 | 保险接片 / 下次撞上旧条里的人，/ 免死，原地续拍 1.5 秒。 | Safety splice / Hit a past take? / Keep rolling 1.5 s. |
| I3 | 补打点 | 补打点 / 多一次手动打点。/ 按 M 留下自己的落点。 | Spare MARK / One extra MARK. / Press M to mark. |
| I4 | 补剪 | 补剪 / 多一次主动剪辑。/ 选好落点，确认才花。 | Spare CUT / One extra CUT. / Spend on confirm. |

---

## 7 · 门卡（每一棚）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| D1 | 抬头 | 剪辑台 / 接哪一段？ | CUTTING DESK / Choose the next strip |
| D2 | 棚型行 | 棚型 %s（I / L / O / H / S） | SET %s |
| D3 | 布景行 | 布景：%s | CREW: %s |
| D4 | 代价行 | 代价：%s | COST: %s |
| D5 | 转过来行 | 转过来：%s | TURNED: %s |
| D6 | 布景标签 | 净场 / 快车 · 推轨更快 / 双推轨 · 两台车 / 窄喉 · 口子更窄 / 空棚 · 没有车 | CLEAN / FAST · quicker dolly / TWIN · two dollies / THROAT · narrower mouth / EMPTY · no dolly |
| D7 | 事件标签 | 带灯 / 多一台车 / 旧我示范 / 有传送带 / 有人在跑 / 地上有胶带 / 有绿幕 / 搭了二层 / 有替身 / 有威亚 | lamped / extra dolly / ghost walks it / on a belt / a runner / taped off / keyed / catwalk / stand-in / on a wire |
| D8 | 代价 | %d 趟 · 无补给 / %d 趟 · +1 MARK / %d 趟 · +1 CUT / %d 趟 · 接片 | %d legs · none / +1 MARK / +1 CUT / · splice |
| D9 | 印章 | 无补给 / +1 MARK / +1 CUT / 接片 | NO SUPPLY / SPLICE |
| D10 | 转过来的答案 | 转过来也一样 / 转过来换一角 / 转过来换半边 / 转过来换两条道 / 转过来换两道弯 | turns to the same set / the corner moves / the other side of the ring / the two lanes swap / both bends swap |

---

## 8 · 场上的声音式提示（底部一条，3–5 秒）

| # | 触发 | 现有中文 | 现有英文 |
|---|---|---|---|
| M1 | 抢下天光 | 这一棚抢下天光。多给你一枚打点。 | You beat the light. One spare MARK. |
| M2 | 第一次剪回 | 第一次剪回不收钱。 | The first splice is free. |
| M3 | 剪接台第一次 | ↑ ↓ 选一段，空格才花 CUT。看片不要钱。 | ↑ ↓ to pick a strip. Looking is free; SPACE spends the CUT. |
| M4 | 打点成功 | 已标记；失手会自动回到这里。 | Marked. A collision returns you here. |
| M5 | 打点用完 | 标记已用完。 | No MARKs left. |
| M6 | 接片生效 | 接片续拍 | SPLICED |
| M7 | 被威亚吊起来 | 剧组把你吊过去了。 | The crew flies you across. |
| M8 | F3 | 镜头横倾：开 / 关 | LENS TILT: ON / OFF |
| M9 | 第一次死亡（板抬起后） | 这一条废了。你被送回上一个落点，别的什么都不扣。 | This take is wasted. You go back to the last mark, and nothing else is spent. |
| M10 | 冲线 | 冲线。这一卷是你的。 | Across the line. This reel is yours. |
| M11 | 第二节 | 第二场。场务开始记账了。 | Act two. The floor starts keeping score. |
| M12 | 第三节 | 第三场。这一条要交片。 | Act three. This take has to print. |

---

## 9 · 死因字幕（死亡板下方，一行）

| # | 死因 | 现有中文 | 现有英文 |
|---|---|---|---|
| X1 | 推轨 | 推轨没有看见你。 | The dolly did not see you. |
| X2 | 场务 | 你撞上了场务。他手里还拿着通告。 | You hit the runner. He was holding the call sheet. |
| X3 | 穿帮胶带 | 你踩进了画面。这条废了。 | You stepped into the shot. This take is gone. |
| X4 | 幽灵 | 你撞上了第 %02d 条的你。 | You hit your take %02d. |

**剧组事件怎么进的场（每棚一次，紧跟事件）**：现在的实现把这一句写成了「说明」，作者大概会想换成「人话」：

| # | 事件 | 现有中文 |
|---|---|---|
| E1 | 带灯 | 剧组换了灯：灯现在挂在推轨上。 |
| E2 | 多一台车 | 临时加了一条推轨。 |
| E3 | 旧我示范 | 这一次，上一次的你不碰人，它只是先走一遍。 |
| E4 | 传送带 | 甲板上铺了一条传送带。它听棚的，不听你的镜头。 |
| E5 | 有人在跑 | 场务在跑。他不会为你停。 |
| E6 | 地上有胶带 | 地上贴了胶带。站进去，这一条就废了。 |
| E7 | 有替身 | 剧组留了一个替身站在那条轨道上。推轨会先撞他，停一拍。 |
| E8 | 有绿幕 | 绿幕那一块不在画面里。站上去，谁都碰不到你。 |
| E9 | 搭了二层 | 这一棚搭了二层。车从下面过。 |
| E10 | 有威亚 | 甲板上画了一块。站上去，剧组把你吊到那一头。 |

---

## 10 · 剪辑台（C 键，暂停世界时）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| C1 | 第一行 | 剪辑台　↑ ↓　%02d / %02d | CUT DESK ↑ ↓ %02d / %02d |
| C2 | 第二行 | %s · TAKE %02d · %.1fs（%s 是「MARK %d」或「起点」） | %s · TAKE %02d · %.1fs（START） |
| C3 | 代价行 | 剪回去：少 %.1f 秒走位 / ，本棚回到第 %d 趟 | SPLICE BACK: %.1f s of walking / , back to pass %d |
| C4 | 末行 | 空格：剪回　−1 CUT　·　C 退出（看片不要钱） | SPACE: splice −1 CUT · C to back out (looking is free) |

---

## 11 · 结算页（一局结束，PRINT 或 OUTTAKE）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| S1 | 抬头（赢） | CALL SHEET / PRINT | 同 |
| S2 | 抬头（输） | CALL SHEET / OUTTAKE | 同 |
| S3 | 赢的标题 | 全部接通 | ANSWER PRINT |
| S4 | 输的标题 | 这卷到头了 | END OF REEL |
| S5 | 输的第一句 | 最后一趟没走出来。 | The last take never made it out. |
| S6 | 输的第二句 | 场务把这条剪了。他说明天再来。 | The stagehand cut this one. He says come back tomorrow. |
| S7 | 破纪录时插一行 | 走得最远的一次。 | The furthest you have been. |
| S8 | 数据行 1 | 走完 %d / %d 棚　　废条 %d　　死亡 %d | SETS %d / %d　WASTED %d　DEATHS %d |
| S9 | 数据行 2 | 手上还剩　标记 %d　剪 %d | LEFT　MARKS %d　CUTS %d |
| S10 | 数据行 3 | 种子 %06X | SEED %06X |
| S11 | 末行 | 空格：再来一局　R：同种子重开 | SPACE: new run　R: same seed |
| S12 | 印章 | 当天收工 / 没用上 | WRAPPED / WASTED |

---

## 12 · 暂停页（ESC）

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| P1 | 标题 | 暂停 | PAUSED |
| P2 | 位置行 | 棚 %02d / %d　　过线 %d / %d | SET %02d / %d　LINE %d / %d |
| P3 | 种子行 | 种子 %06X　　死亡 %d | SEED %06X　DEATHS %d |
| P4 | 继续 | 继续这一条 | Back to the take |
| P5 | 界面大小 | 界面大小：%d%% | HUD SIZE: %d%% |
| P6 | 减弱动态 | 减弱动态效果：开 / 关 | REDUCE MOTION: ON / OFF |
| P7 | 语言 | 语言：中文 / LANGUAGE: English | 同 |
| P8 | 回标题 | 回到标题 | Back to the title |

---

## 13 · 常驻 HUD

| # | 位置 | 现有中文 | 现有英文 |
|---|---|---|---|
| H1 | 左上 | 棚 %02d/%02d | SET %02d/%02d |
| H2 | 左上第二段 | 过线 %d/%d | LINE %d/%d |
| H3 | 右上 | MARK %d　CUT %d（%s = 接片时补「接片」） | 同 |

---

## 换文案的注意事项（给我留的接口）

1. 所有条目都是 `_w("中文", "English")` 或 `word("中文", "English")` 形式，**两列一起换**。
2. 占位符必须原样：`%d` `%02d` `%06X` `%.1f`。带 `%` 的行是格式化串，别删占位符。
3. 长度上限：HUD 一行 ≤16 汉字；场记板字段 ≤8 字；门卡「布景/代价/转过来」三行的值 ≤18 汉字（超了会被 `_fit` 截成「…」）；提示条一条 ≤24 汉字，两行以内。
4. 想删掉某句话 → 直接标「删」，我把那一行整段去掉，不留空行。
5. 想加一句话 → 标在对应段落下面，我加进去并保证不覆盖相邻提示（同一时刻只显示一条）。
