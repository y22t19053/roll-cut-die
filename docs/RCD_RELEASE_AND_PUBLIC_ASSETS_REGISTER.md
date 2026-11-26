# RCD_RELEASE_AND_PUBLIC_ASSETS_REGISTER — 公开成果、参赛记录与本地构建总账

> 建立与核验日期：2026-11-25  
> 关联历史材料：`docs/JAM_SUBMISSIONS.md` · `docs/PLATFORM_AND_JAM_PLAN.md` · `docs/ITCH_PAGE.md`  
> **最高安全红线**：
> 1. 严禁未经创作者明确批准擅自执行 `butler push`、`toy update`、修改 itch.io 页面状态或提交/撤回任何比赛作品。
> 2. 严禁覆盖或删除任何带有历史提交印记的唯一构建包（尤其是 `RCD-ORBIT30.exe` 等里程碑产物）。

---

## 1. 外部平台、公开仓库与赛事提交总表（含 2026-11-25 实时探活）

| 名称 | 类型 | 本地对应位置 / 物料 | 对应提交锚点 | 是否公开 | 外部链接 | 当前状态（实时核验） | 是否需更新 | 原版本保留策略 |
|---|---|---|---|---|---|---|---|---|
| **GitHub 公开镜像仓** | Git 源码仓库 | `default-workspace\roll-cut-die` | `a6a7b66`（本次构建的源码锚点，2026-11-26 已推至 `origin/master`） | **已公开** | <https://github.com/y22t19053/roll-cut-die> | **LIVE（HTTP 200）**；`Releases` 列表为空（`0` 个 GitHub Release） | 脏树未清理前禁止盲推 | 保留全部提交历史，严禁 `force push` |
| **itch.io 项目主页**（ID `5420775`） | 独立游戏商店页 + Web/Win 双包 | `builds/RCD-s10-a6a7b66-windows.zip` · `builds/RCD-s10-a6a7b66-web.zip` | `a6a7b66` 导出（upload `20831851` / `20831850`） | **已公开发布（非 Draft）** | <https://y22t19053.itch.io/roll-cut-die> | **LIVE PUBLIC**；2026-11-26 换成语言修复版，公开下载与内嵌指向新包；托管 Web 实测启动 | 评审期内保持线上稳定，未经批准不覆盖 | 旧 s8 上传已隐藏、未删除；本地历史包保留 |
| **Mauspi Lab Jam #2 · ONE MORE TRY!** | 赛事投稿 | `docs/JAM_SUBMISSIONS.md` · itch `5420775` | `2026-11-22` 投稿快照 | **已公开参赛** | <https://itch.io/jam/mauspi-lab-jam-2/rate/5420775> | **LIVE（HTTP 200）**；截止 `2026-12-14`；规则明确欢迎既有原型与披露后的 AI 辅助 | 否（评审期求稳） | 锁定参赛关联包 |
| **Places That Shouldn't Exist** | 赛事投稿（Liminal × Non-Euclidean） | `builds/roll-cut-die-windows.zip` | `2026-11-22` 投稿快照 | **已公开参赛** | <https://itch.io/jam/places-that-shouldnt-exist/rate/5420775> | **LIVE（HTTP 200）**；截止 `2026-12-03`；严格遵守规则 03 上传 Windows 可执行压缩包 | 否（评审期求稳） | 保留 Windows zip |
| **Tiny Loop Jam 2026** | 赛事投稿 | itch `5420775` | `2026-11-22` 投稿快照 | **已公开参赛** | <https://itch.io/jam/tiny-loop-jam-2026/rate/5420775> | **LIVE（HTTP 200）**；截止 `2026-11-29`（最近到期赛事） | 否（严禁在截止前改动破坏包体） | 锁定参赛关联包 |
| **GitHub Game Off 2026**（主题 `SHIFT`） | 赛事投稿 | itch `5420775` + GitHub 公开仓 | `2026-11-22` 投稿快照 | **已提交参赛** | <https://itch.io/jam/game-off-2026/rate/5420775> | 文档登记已于 `2026-11-22` 提交（注：误写 slug `github-game-off-2026` 返 404，真实路径 `game-off-2026/rate/5420775` 本机瞬时探测超时 `UNVERIFIED`）；截止 `2026-12-01` / `12-02 05:37 SGT` | 否 | 保持 GitHub 仓库公网可读 |
| **Bilibili TOY 网页端投递**（ID `58061569920000`） | 国内 H5 互动小游戏平台 | `builds/web/`（65.49 MB） · `visual/toy_poster.png` (1200×900) · `visual/toy_icon.png` (512×512) | `2026-11-22`–`11-23` 提交 | 已提交平台后台 | `https://www.bilibili.com/toy/roll-cut-die/index.html`（后台条目 `58061569920000`） | **已提交审核/上线链路**；注：`D-072` 剥离 `McpInteractionServer` 后的重出干净包是否已完成二次 `toy update` 属 `UNVERIFIED`；主工作区另有未提交的 `toy_bridge.gd` 每日积分排行榜扩展 | 待创作者确认是否推送含排行榜与干净 Autoload 的新版 | 保留 `builds/toy-index.*` 与 `visual/toy_*` |
| **Finish Your Game Jam 2026** | 历史评估赛事 | `docs/PLATFORM_AND_JAM_PLAN.md` | — | 未参赛（系统拒收） | — | **已明确排除**：提交页面硬性拦截 `"This jam only accepts projects that disclose no generative AI was used."` | 不再尝试 | — |
| **PROCJAM / MFG Gambler's Jam / CrazyGames** | 外部渠道评估 | `docs/PLATFORM_AND_JAM_PLAN.md` | — | 未提交 | — | PROCJAM 与 MFG 均禁止生成式 AI；CrazyGames 首屏上限 `≤ 50 MB`（当前 Web 包约 `62.75–64.79 MB`，需裁剪 `index.side.wasm` `37.91 MB` 后方可申报） | 远期包体瘦身后评估 CrazyGames | — |

---

## 2. 重要外部评价与行业背书档案

### 2.1 Mauspi Lab. 官方正向反馈与入驻邀请（高价值品牌资产）
- **来源**：Mauspi Lab. 主办方及社区反馈记录
- **核心认可点**：
  1. **过去 Take 的物理化重返**：高度评价「上一条戏按原录制轨迹实体返回且绝不避让」的空间压迫感与独创性。
  2. **CUT 的时间编辑张力**：认可按下 `CUT` 回到先前 `MARK` 并抹去后续行动的资源决策体验。
  3. **自生成重试谜题与短局成瘾性**：每次重试都在改写场地交通，天然形成极具吸引力的 `One More Try` 循环。
- **合作机会**：主办方已明确邀请创作者在 `Mauspi.com` 建立开发者档案、分享机制实验，并欢迎 RCD 未来正式入驻。**该外部背书必须在后续商店文案、媒体资料包（Presskit）与参赛复盘中妥善保存。**

---

## 3. 本地构建产物总账（`roll-cut-die/builds/` 实测 SHA256 登记）

`builds/` 目录共保存有 `43` 份顶层 `.exe / .zip` 产物及 `builds/web/` 目录（共计约 100 个构建相关文件）。以下为关键基线、正式分发包与代表性里程碑包核验表：

| 文件名 | 类型 | 精确大小（Bytes） | SHA256（前 16 位 / 完整核验） | 对应提交 / 阶段说明 | 是否公开上传 | 保留要求 |
|---|---|---|---|---|---|---|
| `roll-cut-die-windows.zip` | Windows 发行压缩包 | `50,535,827` | `726111c77dad0f75...` | 当前 itch.io / Places Jam Windows 主分发包（内含 `roll-cut-die.exe` + `README.md`） | **是（itch `5420775`）** | **永久保留，禁止无备份覆盖** |
| `roll-cut-die-web.zip` | WebAssembly 发行压缩包 | `30,000,731` | `bb28ebb7a6d7d4ff...` | 当前 itch.io 浏览器即点即玩包（`visual/*` 与 `McpInteractionServer` 剥离流程产物） | **是（itch `5420775`）** | **永久保留，禁止无备份覆盖** |
| `roll-cut-die.exe` | Windows 单文件可执行程序 | `105,424,080` | `9fad87cb0daab205...` | 与 `RCD-Final.exe` 字节级完全一致（SHA256 相同），对应 `1caec83` 后正式定版导出 | 随 zip 分发 | 保留；后续新版本应带版本号/短哈希另存 |
| `RCD-Final.exe` | Windows 单文件可执行程序 | `105,424,080` | `9fad87cb0daab205...` | `roll-cut-die.exe` 的同哈希母本镜像 | 本地留存 | 保留 |
| `RCD-Final-1caec83.exe` | Windows 里程碑构建 | `105,424,160` | `1ae7097845bda4d4...` | 提交 `1caec83` 定版快照 | 本地留存 | **必须保留原版本** |
| `RCD-ORBIT30.exe` | **早期核心历史基线 EXE** | `84,238,304`（约 80.3 MiB） | `A56F2D1622D7D31DE74D4923ADE5AA85B80B114B4C75C3346E0D2A49F1E165BC`（全长核验吻合） | 对应早期提交 **`6bab995`**（`2026-11-20 00:16:51 +0800`，ORBIT 30°/s 基线定型版）——**注意：此为早期历史锚点，绝非当前 HEAD 完整版** | 历史内测包 | **一级文物保护，严禁删除或覆盖** |
| `RCD-ORBIT30-playtest.zip` | 早期试玩压缩包 | `30,300,820` | `e203b89bd4652c75...` | `6bab995` 阶段配套试玩分发归档 | 历史内测包 | **一级文物保护，严禁删除** |
| `RCD-Free-Blocking-dev1.exe` | 实验分支构建 | `105,442,304` | `4eaf4f07481db22c...` | `free-blocking-sets` 分支（手搭摄影棚 + 放饭 + Company Move）首个可玩开发包 | 仅本地 | **必须保留**（对照实验基准） |
| `RCD-Touch-2930e2e.exe` | 触控适配验证包 | `108,306,720` | `b940a6ebbcb8277e...` | 提交 `2930e2e` 虚拟触控层里程碑 | 仅本地 | 保留 |
| `RCD-Clean-51fb0f7.exe` | 清理里程碑构建 | `108,297,792` | `06d7662972751457...` | 提交 `51fb0f7` 快照 | 仅本地 | 保留 |
| `RCD-Tutorial-1ee7817.exe` | 教学节奏里程碑构建 | `105,009,776` | `c9e71b67b2509281...` | 提交 `1ee7817`（`_sets()` 拆分与新手引导验证） | 仅本地 | 保留 |
| `RCD-Saved-Run-edc7ef0.exe` | 中途存档里程碑构建 | `102,116,160` | `acd9bf03d3cf394b...` | 提交 `edc7ef0`（`relay_run.json` 断点续拍验证） | 仅本地 | 保留 |
| `RCD-Studio-8535207.exe` / `RCD-Backlot-6200c0d.exe` | 绿幕棚与外景原型包 | `99,254,256` / `99,140,800` | `e87571c92b0c0a2b...` / `b4ed8d7ebe47f527...` | `studiolot`（`8535207`）与 `backlot`（`6200c0d`）独立阶段快照 | 仅本地 | **必须保留**（分阶段视觉与空间考古基准） |
| 其余 30 份带哈希/代号构建（`RCD-DEV-3.1*`, `RCD-Wager-*`, `RCD-Events-c980a50.exe` 等） | 演进过程构建群 | `98.7 MB – 107.5 MB` | 均已在审计日志固化前 16 位 SHA256 | 完整记录了 11-20 至 11-23 密集冲刺的每一步可运行形态 | 仅本地 | 磁盘空间充裕前一律原样保留，不得清空 `builds/` |
| `RCD-s5-015e467.exe` | **Sprint 5 定版 Windows 包** | `105,542,320` | `9d76f90b3d28d3b7...` | 提交 `015e467`（互联摄影棚 + 片场机关 + H 灯架 + 本局账本自裁的 Final Cut，1,267 条断言全过） | 待上传（itch 通道阻塞中） | 新版本，保留 |
| `RCD-s5-015e467-windows.zip` | Sprint 5 定版 Windows 压缩包 | `50,648,056` | `cd44837c30186281...` | 同上，内含单个自包含 exe | 待上传 | 保留 |
| `RCD-s5-015e467-web.zip` | Sprint 5 Web 包（旧口径） | `30,115,126` | `dcfbafe3fe6dda42...` | 提交 `015e467`，`extensions_support=true` 时导出（源目录 65.9 MB） | 未发布 | 保留作对照 |
| `RCD-s5d-c91e5ce-web.zip` | Sprint 5 Web 包（slim 口径） | `28,595,949` | `ef12c7586e45c207...` | 提交 `c91e5ce`，关闭 extensions support，源目录 57.2 MB | 未公开发布（TOY 线暂停） | 保留作对照 |
| `RCD-s6-514f149.exe` | **Sprint 6 定版 Windows 包** | `105,559,280` | `35703f9b7ed2eb7b...` | 提交 `514f149`（OUT OF FRAME + CUT BACK、灯架房间族、配乐分层，1,745 条断言全过） | 随 windows zip 分发 | 当前定版，保留 |
| `RCD-s6-514f149-windows.zip` | **Sprint 6 定版 Windows 压缩包** | `50,664,276` | `0ee7483e31af0299...` | 同上，内含单个自包含 exe | **是（itch upload `20815047`）** | 当前线上包，保留 |
| `RCD-s6-514f149-web.zip` | **Sprint 6 定版 Web 包** | `28,612,133` | `f0522a9b14763106...` | 同上，关闭 extensions support 后导出 | 曾上线（itch upload `20815050`，Sprint 7 换包时删除） | 当前线上可玩包，保留 |
| `RCD-s7-a76e4d2.exe` | **Sprint 7 定版 Windows 包** | `105,565,632` | `169226faf3402c3e755789e6a58dbef68a00591b669743a685b4dcbc4cece7ce` | 提交 `a76e4d2`（十六棚 212 m + 每幕长棚收尾、成片质量折算、档案 v2 与三结局分布、Final Cut，2,107 条断言 + 31 Python 全过） | 随 windows zip 分发 | 当前定版，保留 |
| `RCD-s7-a76e4d2-windows.zip` | **Sprint 7 定版 Windows 压缩包** | `50,670,017` | `55b0dc99cb34d9b607f0a184157c8551f8b5134f21cced5e9b51a131e945ae7d` | 同上，内含单个自包含 exe | 曾上线（itch upload `20815485`，Sprint 8 换包时删除） | 当前线上包，保留 |
| `RCD-s7-a76e4d2-web.zip` | **Sprint 7 定版 Web 包** | `28,618,107` | `b3c4b6274cf49d3adfa1ba34ed6e30fbd08a9e5ce552c22f000f4a5e6908f5f7` | 同上，关闭 extensions support 后导出 | 曾上线（itch upload `20815484`，Sprint 8 换包时删除） | 当前线上可玩包，保留 |
| `RCD-s8-aba4c01.exe` | **Sprint 8 定版 Windows 包** | `105,570,880` | `30a7211b07fe577d58bb715fbad2504296bbbfa0e53cae282adf88c438ce80b2` | 提交 `aba4c01`（Sprint 5–8 全部内容：互联摄影棚、片场机关、OUT OF FRAME、灯架房间族、Final Cut、成片质量、档案 v2、四类一次性教学、结算「下一把」、标题页进度；2,215 条断言 + 31 Python 全过） | 随 windows zip 分发 | 当前定版，保留 |
| `RCD-s8-aba4c01-windows.zip` | **Sprint 8 定版 Windows 压缩包** | `50,675,154` | `90b6b1fe7a5e3e64c5649e31e67c7a0785c07f7da8711db728bca888f5e6f3fb` | 同上，内含单个自包含 exe | 曾上线（itch upload `20815878`，语言修复版上线后隐藏） | 本地保留 |
| `RCD-s8-aba4c01-web.zip` | **Sprint 8 定版 Web 包** | `28,622,988` | `8d816b1643933c21f08760093c1c25faf09fc023bb92f201dc442b73192892ea` | 同上，关闭 extensions support 后导出 | 曾上线（itch upload `20815877`，语言修复版上线后隐藏） | 本地保留 |
| `RCD-s10-a6a7b66.exe` | 语言修复版 Windows 可执行程序 | `105,575,104` | `28728f496d48c75e48fbb5d3f6c48d3a45bd371d01e926183c05ea00546102e9` | `a6a7b66`，2,458 条 Godot 断言、31 项 Python 测试通过 | 随 Windows zip 分发 | 保留 |
| `RCD-s10-a6a7b66-windows.zip` | 语言修复版 Windows 下载包 | `50,679,041` | `1ad0a97057e72581e35a281c33c9975f051a7b6433aca918f6dfe0f3b23408c9` | 内含单个自包含 exe | itch `20831851` | 保留 |
| `RCD-s10-a6a7b66-web.zip` | 语言修复版 Web 内嵌包 | `28,626,673` | `f88270a67b38de35799079e96d1260fc48ae972ddc8e3a1fca9bfa4c22abdf5f` | 浏览器冒烟通过，无控制台错误或警告 | itch `20831850` | 保留 |

## 3.1 平台状态变更（2026-11-25 起）

- **2026-11-26 语言修复版**：GitHub 已推送源码 `a6a7b66`。itch `5420775` 公开下载只列出 Windows upload `20831851`，内嵌指向 Web upload `20831850`；[托管 Web](https://html-classic.itch.zone/html/20831850/index.html) 启动至标题页（canvas `2188×1395`）。旧 s8 uploads `20815877` / `20815878` 已隐藏，未删除。B 站 TOY 按创作者指令保持暂停。

- **GitHub 公开镜像**：master 已从 `04aa585` 推进到 `aba4c01`（仓库共 300 个提交），含 Sprint 5 四路交付、Final Cut 接通、Sprint 6（OUT OF FRAME / 灯架房间族 / 配乐分层）、Sprint 7（十六棚 + 成片质量 + 档案 v2）与 Sprint 8（四类一次性教学 + 结算「下一把」+ 标题页进度）。
- **Bilibili TOY**：旧 `58061569920000` 已不可解析 —— `toy stats` 与 `toy update` 都返回 `307000 请求参数错误`，通知里有「大包体上传申请未通过」，判定旧 Toy 已被平台移除。新建 `59100293499904`（slug `roll-cut-die`，public，GAME）提交后处于 `status=auditing`；**创作者随后要求 B 站 TOY 暂停，不再维护也不发布新包**，后续所有发版只走 itch 与 GitHub。
- **itch `5420775`（2026-11-25 20:24 完成换包）**：butler OAuth 已由创作者授权（凭据 `C:\Users\11ee11\.config\itch\butler_creds`），但 `GET https://api.itch.io/wharf/channels?target=y22t19053/roll-cut-die` 返回 `{"channels": {}}` —— 该项目从未建立 butler 通道，旧包是网页上传的普通文件，因此改走 itch 后台网页换包：新上传 `RCD-s6-514f149-windows.zip`（upload `20815047`）与 `RCD-s6-514f149-web.zip`（upload `20815050`，`embed` 勾选），删除旧 `roll-cut-die-windows.zip`（`20741185`）与 `roll-cut-die-web.zip`（`20741186`），保存后公开页 PUBLISHED，embed iframe = `https://html-classic.itch.zone/html/20815050/index.html`，直连该 URL 实测 `title="roll cut die"`、canvas `2188x1395`、引擎就绪 —— itch 托管 Web 版确认可启动。
- **发布脚本**：`tools/make_release.py` 现在会在打包前 prune 掉停产的 `*.wasm` 兄弟文件（Godot 不会自动删旧产物，曾导致 39.7 MB 的 `index.side.wasm` 混进 zip 与 TOY 包）。Sprint 6 起 `--tag s6` 一条命令产出 exe + windows zip + web zip，并打印字节数与 SHA256。
- **itch `5420775` 第二次换包（2026-11-25 20:48，Sprint 7）**：同一套网页流程（上传 → 勾 `embed` → 删旧两条 → Save）。新上传 `RCD-s7-a76e4d2-windows.zip`（upload `20815485`）与 `RCD-s7-a76e4d2-web.zip`（upload `20815484`，`embed` 勾选）；删除 Sprint 6 的 `20815047` / `20815050`；保存后重载确认只剩两条 s7 包。公开页 `https://y22t19053.itch.io/roll-cut-die` 复核 `uploadIds=["20815485"]`、页面已不含 `RCD-s6` 字样；embed iframe `https://html-classic.itch.zone/html/20815484/index.html` 直连实测 canvas `2188x1395`、标题页已渲染 `ARCHIVE LV 0 / TRUTH 0 · COVER-UP 0 · FRAME-UP 0`（= Sprint 7 档案等级 UI 上线），截图存 `visual/preview/sprint7_itch_embed_boot.png`。
- **itch `5420775` 第三次换包（2026-11-25 21:10，Sprint 8）**：新上传 `RCD-s8-aba4c01-windows.zip`（upload `20815878`，`p_windows` 勾选）与 `RCD-s8-aba4c01-web.zip`（upload `20815877`，`embed` 勾选）；删除 Sprint 7 的 `20815485` / `20815484`；保存后重载确认只剩两条 s8 包、`hidden=false`。公开页复核 `uploadIds=["20815878"]`、正文已无 `RCD-s7`/`RCD-s6` 字样；embed 直连 `https://html-classic.itch.zone/html/20815877/index.html` 实测 canvas `2188x1395`、标题页显示 `EXPERT unlocks on clearing NOVICE (best 0/16)` 与 `Marks to next rank: 3`（= Sprint 8 进度文案上线），截图存 `visual/preview/sprint8_itch_embed_boot.png`。
  - 网页换包两个坑：①有未保存改动时 `page.goto` 会被 `beforeunload` 拦成 30 s 超时，脚本开头必须 `page.on("dialog", d => d.accept())`，并优先在**新标签页**里直接 `goto`；②删除文件用的 lightbox 里也有一个 `input[type=checkbox]`，若用 `locator(".lightbox input[type=checkbox]").first()` 会命中上传行的 `[hidden]` 开关 —— 本轮就把 Sprint 8 的 Windows 包勾成了「隐藏构建」，靠回读 `upload[20815878][hidden]` 才发现并改回 `false`。要按行取控件：`page.locator(".uploader").filter({has: page.locator("input[name^='upload[ID]']")})`。

---

## 4. 商店与平台视觉物料清册（`roll-cut-die/visual/`）

- `visual/cover.png` · `visual/cover_titled.png` · `visual/cover_titled_630.png`（itch.io 630×500 标准封面图，本地 RealVisXL V5 生成底图 + 标题合成，工具链位于 `tools/make_cover.py`）
- `visual/capsule_1920.png`（1920 宽横版宣传胶囊图）
- `visual/toy_poster.png`（1200×900 4:3 B站 TOY 封面，由 `tools/make_toy_poster.py` 生成）· `visual/toy_icon.png`（512×512 图标）
- `visual/preview/backlot-portals/before.png` & `after.png`（外景传送门前后对比实机截图）
- `builds/RCD-Five-title-82b6aba.png` 等阶段标题页截图（用于 UI 升级前后视觉对比验收）
