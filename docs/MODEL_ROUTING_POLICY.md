# RCD 模型路由策略与实测状态

最后实测：2026-11-19 22:16–22:26（Asia/Shanghai）
状态分级：VERIFIED（真实调用成功）／CONFIGURED（配置存在未验证）／DEGRADED（能连、不能用）／UNAVAILABLE（不存在或未授权）

## 0. 结论先行

当前真正能承担 RCD 生产的只有两条通道：

1. **deepseek-account / deepseek-flash**（reasoningEffort=max）：本会话即运行于此，OAuth 登录，无需密钥。
2. **本地 Ollama**：qwen3-4b-q4 实测 4.1 s、70.7 tok/s。

任务书要求作为双高阶池的 Gemini 与 Claude：

- **Gemini：UNAVAILABLE。** DSH 里没有 Gemini provider，`gemini` 命令不存在，环境变量里没有任何 GEMINI/GOOGLE 凭据。这是「没接上」，不是「不稳定」。
- **Claude：DEGRADED。** Claude Code CLI 2.1.328 已安装，XHYAPI 中转鉴权通路已验证（`GET /v1/models` 返回 13 个模型，含 claude-opus-5-5）；但所有可用大模型的补全请求 40–95 s 无响应，haiku-4-5 与 opus-4-5 直接返回「模型不存在或无权访问」，直连 HTTP 一律 403。

因此**双高阶模型池目前无法在 DSH 内建立**。在两个通道真正可用之前，高阶设计与攻坚落在 deepseek-flash 上，用「独立子 agent + 结论交叉比对」弥补同源缺陷，并把结果标记为待高阶复核。

## 1. 实测状态矩阵

| 通道 | 入口 | 真实模型 ID | 状态 | 证据 |
|---|---|---|---|---|
| DeepSeek Account | DSH 内置 OAuth | `deepseek-flash` | VERIFIED | 本会话运行于该模型，工具调用正常 |
| Ollama（本地） | `http://127.0.0.1:11434` | `qwen3-4b-q4`、`qwen3-8b-q4`、`qwen2.5:0.5b`、`bge-m3`、`moondream` | VERIFIED | `POST /api/generate` 4.1 s 返回，24 tok，70.7 tok/s |
| Claude（XHYAPI） | Claude Code CLI 2.1.328 + `https://cn.xhyapi.com` | `/v1/models` 列出的 13 项 | DEGRADED | 见 §3 探针记录 |
| Gemini | — | — | UNAVAILABLE | 无 CLI、无 provider、无环境变量 |
| Kimi（Tabbit） | Tabbit skill（浏览器） | 未验证 | UNVERIFIED | 无 `tabbit` 命令；只能走浏览器，未做真实调用 |
| Ling-2.6（52duck） | `cordis.patch.yml` 的 `ant-ling` | `Ling-2.6-1T` 等 | UNAVAILABLE | 补丁处于 STAGED 未生效；`ANT_LING_API_KEY` 不在环境变量 |
| amazon-bedrock | `https://api.anytoken.work/v1` | `anthropic.claude-opus-5-5` 等 | UNAVAILABLE | `list_subagent_models(amazon-bedrock)` → `LLM provider "amazon-bedrock" is not allowed for this Session` |

## 2. 为什么这些模型进不了 DSH 路由

- DSH 的模型可见集合由 `list_subagent_models` 决定，当前只返回 `deepseek-account`。
- `C:\Users\11ee11\.dsh\profiles\desktop\cordis.patch.yml` 里确实写了 `ollama-local`、`amazon-bedrock`、`ant-ling`、`anthropic` 四个 provider，但文件第 1 行自注「STAGED — 尚未生效，等 Qwen3-8B 下载并 ollama create 成功后由 apply-dsh-patch.ps1 应用」，而 Qwen3-8B 其实早已在 Ollama 里（3 周前）。补丁停在半途。
- 各 provider 的 `apiKeyEnv`（`OLLAMA_API_KEY`、`AMAZON_BEDROCK_API_KEY`、`ANT_LING_API_KEY`、`ANTHROPIC_API_KEY`）在进程环境中都不存在（只探测名字，未读取任何值）。
- 结论：让 Claude/Gemini 进入路由需要 ①profile 补丁生效 ②provider 密钥注入 ③会话授权。三者都属于 DSH 全局配置，超出「项目级路由调整」授权，本轮未改动。

## 3. Claude 探针记录（原始证据）

```
GET  https://cn.xhyapi.com/v1/models  -> 200
  claude-fable-5-1, claude-fable-5, claude-opus-4-5-20251101,
  claude-opus-4-6, claude-opus-4-7, claude-opus-4-8, claude-opus-5-5,
  claude-opus-5, claude-sonnet-5-5, claude-sonnet-5, claude-sonnet-4-6,
  claude-sonnet-4-5-20250929, claude-haiku-4-5-20251001, claude-haiku-5-5

POST /v1/messages        -> 403 已禁止（加 CLI UA / Bearer / stream 后仍 403）
POST /v1/chat/completions -> 403 已禁止
```

CLI `claude -p "..." --model <id>` 实测：

| 模型 | 结果 |
|---|---|
| `claude-haiku-4-5-20251001` | 2.1 s，「模型可能不存在或无权访问」 |
| `claude-opus-4-5-20251101` | 2.1 s，同上 |
| `claude-sonnet-5-5` | 40 s 无输出（TIMEOUT） |
| `claude-opus-5-5` | 95 s 无输出（TIMEOUT） |
| `claude-fable-5-1` | 40 s 无输出（TIMEOUT） |

判定：鉴权通、模型列表通、可用大模型补全不通。中转只放行 Claude Code 客户端指纹，不允许直连 API。

## 4. 路由策略（按实际可用性制定）

| 层 | 用途 | 当前承担者 | 备注 |
|---|---|---|---|
| Tier A 战略/攻坚 | 机制推演、架构、根因分析、关键设计审查 | deepseek-flash（reasoning=max），独立子 agent | Claude 恢复即并列；Gemini 恢复前不承诺 |
| Tier B 工程执行 | 明确接口下的实现、重构、测试编写 | deepseek-flash 子 agent | 核心文件单一写入者，禁止两个 agent 同改 |
| Tier C 本地批量 | 日志分类、命名、抽取、索引、初筛 | Ollama qwen3-4b / qwen3-8b | 只做低风险确定性任务，不做设计判断 |
| Tier D 交叉验证 | 同一问题的独立第二结论 | 两个互不看结论的子 agent，由主控比对分歧 | 保留双方原始输出，不做「求同」改写 |

纪律：

- 不为「用了多模型」而调用；每次调用有任务 ID、输入材料、预期产出、验收条件。
- 不把不可用通道写成可用；配置存在 ≠ 调用成功，调用成功 ≠ 设计有效。
- 高阶结论必须回写项目档案，不能只留在某个会话里。

## 5. 故障处理

对齐 m00403 五级流程与 m00411 熔断要求：

1. 判类型：认证失败／模型不存在／格式错误／超时／限流／服务不可用／返回质量不合格，不混为一谈。
2. 有限重试：首次记录错误，可恢复错误重试一次，仍失败即切通道；禁止同一错误连烧 token。
3. 熔断：同通道连续 2 次失败标记不可用，24 h 或下一任务节点再轻量探测一次。
4. 降级执行：不阻塞工程；临时结论标「待高阶复核」，不得自动升级为最终决策。
5. 恢复验收：低风险试调 + 确认真实模型 ID + 更新本文件状态矩阵。

切换时携带：任务 ID、已完成工作、文件状态、已确认结论、已试方案与失败原因、当前阻塞、下一步。

## 6. 调用日志规范

字段：任务 ID、时间、通道、真实模型 ID、任务类别、结果、token、延迟、结果摘要、后续处理。

禁止记录：API Key、完整认证头、账号凭据、个人信息。日志文件见 `docs/MODEL_CALL_LOG.md`。

## 7. 要让双高阶池真正成立，需要开发者做三件事

1. **profile 补丁生效**：把 `cordis.patch.yml` 从 STAGED 变 ACTIVE（可执行 `apply-dsh-patch.ps1`，需你确认后再动）。
2. **注入密钥**：按通道选择 `AMAZON_BEDROCK_API_KEY` / `ANT_LING_API_KEY` / `ANTHROPIC_API_KEY`；`OLLAMA_API_KEY` 可给占位值。
3. **会话授权**：让对应 provider 出现在 `list_subagent_models` 里。

Claude 另有一条独立问题：XHYAPI 分组「Claude 自营号池－不烧心」下 opus-5-5 / sonnet-5-5 补全超时，而 haiku/opus-4-5 报无权访问。CLI 与鉴权端没问题，需要在控制台确认分组额度与模型映射。

## 8. 本轮决定

- 双高阶池暂缓，不阻塞 RCD 开发。
- 工程与设计推进继续用 Tier A/B/C/D，所有高阶结论标注实际承担模型。
- 每次会话结束前刷新本文件的状态矩阵与 `docs/MODEL_CALL_LOG.md`。
