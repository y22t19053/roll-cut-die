# 四个 Jam 的合规判定与投稿文案

> 判定依据：四个 Jam 的规则页原文（2026-11-22 用 Tabbit 在浏览器里读的，页面原文摘录在每节第一行）。

## 判定结果

| Jam | 截止 | 规则里最要命的一句 | roll cut die 能不能投 |
|---|---|---|---|
| **Mauspi Lab Jam #2 · ONE MORE TRY!** | 12-14 | "This is not a traditional development sprint. **Existing games, new projects, demos, and prototypes are all welcome!**" | ✅ **能投**，主题也正好（"makes players want to try again"） |
| Tiny Loop Jam 2026 | 11-30 | "You can plan now; **make the game during the jam**" | ❌ 现成的 RCD 不行（11-19 就已在仓库里可玩） |
| GitHub Game Off 2026 | 12-02 | "build a game **during the month of November**" + 必须**公开 GitHub 仓库** | ❌ 两条都不满足（无远端仓库，游戏早于 11 月） |
| Places That Shouldn't Exist | 12-03 | "You have until December 2 … **to create and submit your game**" | ❌ 需要在这个窗口内做出来 |

**结论**：只有 Mauspi 是「把现成作品拿来参赛」的 Jam。另外三个都要求**在窗口内新做**——拿 RCD 去投会被判违规（同一个 itch 账号公开可见，风险是连坐整个账号）。

**合规的走法**（我的建议，不用你操心细节）：RCD 投 Mauspi + 正常上架 itch；另外三个要投就做一个**新的小而完整的东西**（一个循环、第一局 2–5 分钟），它同时满足 Tiny Loop 的「窗口内新做」、Places 的「空间不合理」（我们的棚子每晚重搭正好是 liminal）、Game Off 的「SHIFT」（镜头偏转就是 shift）+ 公开仓库。这件事我可以做，但要另起一个仓库与页面。

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
