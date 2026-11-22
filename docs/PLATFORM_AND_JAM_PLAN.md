# 平台与 Jam 可行性（2026-11-22 实查）

这份文件只记录**当场读到的原文与数字**，不是凭印象写的清单。所有结论都标了来源页面；没读到的写「待核」。

## 0 · 一句话结论

RCD 现在能挂 itch（已挂）与少数不禁止 AI 的平台；**近在眼前的三个大 Jam 全部明令禁止生成式 AI**（美术、音频、文字、代码），以我们目前在 itch 页上如实披露的 `AI generated: yes` 是投不进去的——我试投 Finish Your Game 时被服务端直接拦下，返回原文：`This jam only accepts projects that disclose no generative AI was used.`

## 1 · Jam 逐一实查

| Jam | 时间 | 规模 | 关键规则 | RCD 能不能投 |
|---|---|---|---|---|
| **Finish Your Game Jam 2026** `/jam/finishyourgamejam2026` | 11-14 12:00 → **12-01 15:59** | 434 人 / 46 投稿 | 明确欢迎继续做长期项目，可只交进度快照或 journal；`Games made with or featuring Generative AI (large language models, stable diffusion, AI image/art generators) will not be accepted.` | **不能**（被服务端硬拦） |
| **PROCJAM** `/jam/procjam` | **12-05 07:59 → 12-14 07:59** | 254 人 | 唯一规则「make something that makes something」；可用既有代码与美术、可提前开工、可联系主办补交；`The use of generative AI (ChatGPT, Claude, Midjourney, Copilot…) in entries is not permitted` | **不能** |
| **The MFG Gambler's Jam** `/jam/the-mfg-gamblers-jam` | **12-06 07:00 → 12-14 01:00** | 2101 人 | 必须在 jam 期间做、跑 web 或 Windows 免安装、`No generative AI for art, audio, writing, or code`、主题开赛视频公布＋老虎机抽第二主题、五维评分、Hack Club 给 13–18 岁实物奖 | **不能**（且要求赛中制作） |
| **Metroidvania Month #34** `/jam/metroidvania-month-34` | 还剩 23 天 | 1407 人 | 要求银河城特质 | 不符，不硬凑 |
| **LSDJAM 2026** `/jam/lsdjam-2026` | 还剩 3 个月 | 527 人 | 待核 | 待核 |
| **Month of Horror #3: Endless Ocean** `/jam/month-of-horror-3` | 还剩 28 天 | 472 人 | 海洋恐怖主题 | 主题不符 |
| **Ludum Dare** `ldjam.com` | LD60 已于 **2026-10-16** 结束，下一届 **LD61 2027-04** | — | 必须赛期从零做 | 不适用（除非另做新作） |
| **Godot Wild Jam** | 每月第二个周五开，约 9 天；当前周期不在 itch「招募中」列表 | — | Godot 专用（技术上最对口） | 待核 AI 条款后再判 |

已经投出的四个（都是允许 AI 或有条件允许的）：Tiny Loop、Mauspi Lab #2（明写只要求披露）、Places That Shouldn't Exist、GitHub Game Off 2026（要求公开仓库，已建）。

**教训**：投之前必须先读规则里的 AI 条款，不能只看主题和时间。itch 的 `AI generated` 披露字段会被 Jam 直接拿去卡人。

## 2 · 平台要求（实查）

| 平台 | 门槛（原文数字） | 我们的现状 | 结论 |
|---|---|---|---|
| **itch.io** | — | Windows zip 50 MB + Web zip 31 MB 已上线，4 张截图，页面两文件 | 已完成 |
| **CrazyGames**（`docs.crazygames.com/requirements/technical/`） | 总包 **≤250 MB**、文件数 **≤1500**、**首屏下载 ≤50 MB**（移动首页 ≤20 MB）、可选/必选 SDK、QA 审核、收益分成 | web 包 **64.79 MB**（`index.side.wasm` 37.91 + `index.pck` 22.37 + `index.js` 2.91 + `index.wasm` 1.55） | **首屏超限**，要先瘦身（音频换 ogg、贴图降尺寸、pck 压缩） |
| **Poki**（`developers.poki.com`） | 申请制，官方 playtest + 自研 QA + 收益分成，重心在移动/休闲 | 桌面 3D、键鼠 | 可申请，短期不适配移动就难拿量 |
| **Game Jolt** | 免费托管 Windows/HTML5，自带 Jam 生态（需注册账号） | 有现成 zip | **成本最低的下一步**，登录即可挂 |
| **Newgrounds** | HTML5 上传，需账号；当场被 `NG Guard` 人机验证拦住（未登录） | 有 web 包 | 要账号 + 过验证 |
| **GX.games**（Opera GX，`dev.gx.games`） | 开发者后台 + Jam 板块，支持 Godot web 导出 | 有 web 包 | 要账号，后台待核 |
| **B 站 TOY**（`bilibili.com/toy`） | 入口 `index.html` 解压后 ≤1 MB、包体走审核；`toy` CLI 上传；含自由绘制要加 `--watermark` | web 包 65.49 MB、`index.html` 2.7 KB | **已提交审核**（Toy id `58061569920000`，2026-11-22） |
| **Steam** | 每款 **$100** 上架费、需完整成品与商店页、审核 | 目前是 4 节 12 棚的一局 | 长期最值，不是「挂比赛」 |

## 2.5 · B 站 TOY 的实际做法（2026-11-22）

- 打包：`builds/web` 去掉 `*.import` 的 9 个文件 → `builds/toy-roll-cut-die/`；`index.html` 里全是相对路径，`GODOT_THREADS_ENABLED = false`，所以在 `/toy/<slug>/` 子路径下能跑。
- 封面图标**必须是 4:3 与正方形**，不是 itch 的 630×500：`tools/make_toy_poster.py` 把 16:9 的 `visual/cover.png` 裁成 4:3 再套字（`visual/toy_poster.png` 1200×900），另画 `visual/toy_icon.png` 512×512。
- `toy create <dir> ... ` 不带 `--yes` **只出预览、不提交**；预览页 `https://www.bilibili.com/toy/preview/author_XXXX/index.html` 在 iframe 里跑，判断它真的起来了要看 iframe 内 `#canvas` 的 width 从 300×150 变成真尺寸，而不是只看页面标题。
- 上传成功后 `toy mylist` 才会出现这条；提交审核后 `status: auditing`。
- **踩过的坑**：导出包里带着开发用的 `McpInteractionServer` autoload（`project.godot` 有声明、`exclude_filter` 又排除了 `autoload/*`），Toy 版控制台一进就报 `Attempt to open script 'res://autoload/mcp_interaction_server.gd' … File not found`。删掉那条声明后重导出，错误消失，只剩一条无害的 V-Sync warning。

## 3 · 三条可执行路线

1. **不碰 AI 的场合就别碰**（现在这条最诚实）：只投允许 AI 或只要求披露的地方（itch、Game Jolt、Game Off 同类），并把 `AI generated: yes` 一直留着。
2. **想进禁 AI 的 Jam / 想上更严的平台**：必须把 AI 参与的部分换掉——贴图（`assets/textures/deck_ai.png`/`wall.png`/`metal.png`）已有程序化回退 `_grain()`，可以改成纯程序化或手绘；代码这一层要做到「无 AI 参与」在事实上做不到，所以这条路要作者本人决定怎么定口径，不能用含糊话糊过去。
3. **纯平台扩张（与 Jam 无关）**：优先级 = Game Jolt（免费、今天能挂）→ CrazyGames（先瘦身到 ≤50 MB 首屏）→ Newgrounds（账号）→ GX.games（账号）→ Poki（要移动适配）→ Steam（等成品）。

## 4 · 待办

- [ ] Game Jolt 上架（需账号登录，一次点击的量）
- [ ] web 包瘦身：三态音床 wav → ogg、贴图降到 1024、开 pck 压缩，目标首屏 ≤50 MB
- [ ] CrazyGames 提交（瘦身完成后）
- [ ] 核 Godot Wild Jam 当届的 AI 条款与日期
- [ ] 若走路线 2：把三张 AI 贴图换成程序化/手绘，改 itch 披露文本