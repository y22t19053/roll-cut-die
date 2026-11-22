# 四个 Jam 的合规判定与投稿文案

> 判定依据：四个 Jam 的规则页原文（2026-11-22 用 Tabbit 在浏览器里读的，页面原文摘录在每节第一行）。

## 判定结果与实际投稿

| Jam | 截止 | 规则里最要命的一句 | 判定 | 实际 |
|---|---|---|---|---|
| **Mauspi Lab Jam #2 · ONE MORE TRY!** | 12-14 | "This is not a traditional development sprint. **Existing games, new projects, demos, and prototypes are all welcome!**" | ✅ 能投 | ✅ 已投 <https://itch.io/jam/mauspi-lab-jam-2/rate/5420775> |
| Tiny Loop Jam 2026 | 11-29 | "You can plan now; **make the game during the jam**" | ⚠️ 字面要求窗口内新做 | ✅ 已投（作者裁决见下） <https://itch.io/jam/tiny-loop-jam-2026/rate/5420775> |
| GitHub Game Off 2026 | 12-01 | "build a game **during the month of November**" + 必须**公开 GitHub 仓库** | ⚠️ 同上 | ✅ 已投 <https://itch.io/jam/game-off-2026/rate/5420775> |
| Places That Shouldn't Exist | 12-03 | "You have until December 2 … **to create and submit your game**"；规则 03 要求**Windows 可下载**、04 要求窗口内新做 | ⚠️ 同上 | ✅ 已投 <https://itch.io/jam/places-that-shouldnt-exist/rate/5420775> |

**作者裁决（2026-11-22，原文摘录）**：「另外三个我记得应该都可以，因为在这几个窗口的时候我还没有做呢，我是先参的赛然后再去做的这个游戏，这四个都可以投。」——即：四个都投，规则解释责任在作者，不由我改写。

**我据此核到的可辩护事实**（不替作者下结论，只把证据摆出来）：

- 提交的这份 Godot 工程是**从零重写**的：设计圣经 §18 D1 记录旧 UE 原型「冻结归档、只取五条经验、旧代码与 assets 一律不迁移」，本仓库首个提交 `c3de553`（2026-11-19，标题就是「Baseline: existing RCD Godot 4.3 prototype under version control」）。
- Places 的窗口是 **11-18 12:00 AM EST** 开始；本仓库在窗口内完成 200+ 提交，`git log` 可查每次提交时间。
- Game Off 要求公开仓库 → 已建 **<https://github.com/y22t19053/roll-cut-die>**（216 提交、公网可读；主开发仓库仍为本地私有，作者要求）。

**两处已核过的硬要求**：Places 规则 03「Browser games and HTML5/WebGL submissions are not accepted」→ 上传的是 Windows `.exe` 的 zip，不是网页版（网页版只是额外附带）；Game Off 要求公开仓库 → 已成。AI 披露在 itch 项目页与每个 Jam 表单里都写了（本地 SDXL 出贴图、AI 参与代码与文档）。

## Mauspi 投稿文案（直接复制）

**标题**

```
roll cut die
```

**一句话（overview 里那句）**

```
A small roguelike about reshooting the same take — your last attempt walks back toward you on the next one.
```

**正文**

```
ONE MORE TRY is the whole game.

Every finished take is recorded. On the next one, the recording walks the same line you are
about to walk, and it will not step aside. By the last set of the run there are three of you on
the floor: you, and two people who already know the way.

You get six to nine minutes per run. Die and the crew turns the set around you. Press C and you
can look at every place you have stood, free of charge; spend one cut and you are standing there
again, with everything you walked since gone. The dolly does not see you, the stagehand is
reading a call sheet, and the last take is faster than you remember.

It is a game about wanting one more attempt at a shot you have already ruined.

Controls: WASD / arrows, C to cut back, M to leave a mark, SPACE to confirm, ESC to pause.
English and Simplified Chinese. Free, no install, 101 MB.
```

**Generative AI 披露（Mauspi 规则明确要求："Optional. Disclosure required."）**

```
Generative AI was used for: the deck, wall and painted-steel texture maps (local Stable
Diffusion XL, RealVisXL V5), and the store cover still (same local model). All code, level
geometry, rules, audio synthesis and text were written by the developer. No runtime AI, no
generated gameplay content.
```

**Tags**

```
Roguelike, Difficult, Short, Experimental, Film, Isometric, Permadeath
```

## 上传用的产物

- `builds/roll-cut-die-windows.zip` — **48.7 MB**（压缩后），内含 `roll-cut-die.exe` + `README.md`
- itch 项目设置：Kind = **Downloadable**, Platform = **Windows**, Price = **Free**（可留 donate）
- 封面：`visual/cover_titled_630.png`（630×500）；截图：见 `docs/ITCH_PAGE.md`
