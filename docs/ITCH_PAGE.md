# itch.io 上架材料（roll cut die）

> 这一份是给 itch 页直接复制用的。英文在前（默认语言已改成英文），中文备注在后。
> 图片在 `visual/`，截图在下面「截图」一节列了出处。

---

## 标题 / Title

```
roll cut die
```

## 一句话 / Short tagline（itch 的 "tagline" 字段，最多 130 字符）

```
A small roguelike about reshooting the same take, where your last attempt comes back to walk the set in front of you.
```

## 短简介 / Short description（商店页顶部那段，3–4 句）

```
You are on a soundstage that gets rebuilt every night. Walk your take from one chalk line to
the other while a camera dolly sweeps the floor and one crew member keeps crossing where he
shouldn't. Finish the take and it is recorded. Walk it again and the recording walks back
toward you.

Four acts, twelve short sets. Die and the crew turns the set around you. Cut back and you
spend a cut to be somewhere else. Nothing you do is thrown away.
```

## 完整简介 / Full description

```
ROLL. CUT. DIE.

Three words, and that is the whole game.

ROLL is the camera. It does not sit behind you and watch: it swings when you move, banks
into your turns, and by the third act the light has gone warm and long because the day is
ending. You learn to read it, then you learn to use it.

CUT is getting out. Press C and you can look at every place you have stood this run, free of
charge. Spend one cut and you are standing there again — but everything you walked since is
gone.

DIE is the floor. The dolly does not see you. The stagehand is carrying a call sheet and his
mind is elsewhere. Your own last take walks the same line you are about to walk, and it will
not step aside for you.

THE SET REMEMBERS

Every finished take is recorded and played back on the next one. By the last set of the run
there are three of you on the floor: you, and two people who already know the way. The only
thing that carries between runs is how far you got.

THE CREW KEEPS WORKING

The green screen takes one square of floor out of the plate — stand there and nothing can
touch you, because you are not in the shot. Tape on the deck marks where yesterday's blocking
was, and stepping inside it ruins the take. A conveyor answers to the stage, not to your
camera, so when the crew turns the set around between deaths it carries you the other way.
Someone left a stand-in on the dolly track, and the dolly stops for him.

WHAT IT IS NOT

No dialogue trees. No cutscenes. No skill tree, no currency, no unlocks to grind. A run is
six to nine minutes and it ends with a call sheet that says how far you got.

Controls: WASD / arrows to move, C to cut back, M to leave a mark, SPACE to confirm, ESC to
pause. Gamepad-friendly menus. Full English and Simplified Chinese.
```

## 分类与标签 / Tags

```
Roguelike · Difficult · Short · Minimalist · Experimental · Film · Isometric ·
Permadeath · Procedural Generation · Soundtrack
```

Genre: **Action / Roguelike**（itch 主分类）；Secondary: **Puzzle**

## 系统需求 / System requirements

```
Windows 10 or 11, 64-bit
GPU: anything that runs Vulkan (integrated is fine)
RAM: 4 GB
Disk: 120 MB
```

## 按键 / Controls 表

| Key | 作用 |
|---|---|
| WASD / Arrows | 走位（镜头跟着歪） |
| C | 剪辑台：看自己留下的落点，花一枚 CUT 剪回去 |
| M | 在当前点留一个 MARK |
| SPACE / Enter | 确认 |
| ESC | 暂停（含减弱动态效果、语言、回主菜单） |
| F3 | 开关镜头横倾 |
| F2 | 切换中英 |

## 截图 / Screenshots（建议放 4 张，按这个顺序）

1. **标题页（英文）** — `C:/Users/11ee11/AppData/Local/Temp/rcd_verify/m27_title_en.png`
2. **带灯的棚** — `C:/Users/11ee11/AppData/Local/Temp/rcd_verify/event_relight3.png`
3. **换场单三选一** — `C:/Users/11ee11/AppData/Local/Temp/rcd_verify/m3_cards.png`（或最新的 `m6_doors_call3.png`）
4. **结算通告单** — `C:/Users/11ee11/AppData/Local/Temp/rcd_verify/m6_sheet_paper.png`

> 上架前请把这几张从 Temp 拷到 `visual/shots/` 再传，Temp 会被清。

## 封面 / Cover

- `visual/cover.png`：1024×576，无字片场静帧（AI 生成，已提交）
- `visual/cover_titled.png`：同一张图 + 标题排版（made by `tools/make_cover.py`）
- itch 的封面要求：**630×500**；若做 capsule 用 **1920×620**

## 价格与页脚 / Price

免费（free），可留 "donate" 按钮。评论区允许。

## 制作名单 / Credits（页脚用）

```
Made by MacGuffin Works
Engine: Godot 4.3
Type: Noto Sans CJK SC (SIL OFL 1.1)
Textures: RealVisXL V5 (local), composited by hand
Sound: composed and rendered in the project
```
