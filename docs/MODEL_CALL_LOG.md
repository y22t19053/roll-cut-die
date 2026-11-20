# RCD 模型调用日志

记录真实调用。配置存在不算，必须有返回证据。禁止写入密钥、认证头、账号凭据。

| 任务 ID | 时间 | 通道 | 真实模型 ID | 类别 | 结果 | token | 延迟 | 结果摘要 | 后续处理 |
|---|---|---|---|---|---|---|---|---|---|
| RCD-M00 环境审计 | 2026-11-19 22:16 | DSH Ollama | `qwen3-4b-q4:latest` | 连通性 | 成功 | 24 out | 4.1 s | 返回 `<think>` 前缀思考文本，命中 num_predict 上限；70.7 tok/s | 本地通道可用，Tier C 采用 |
| RCD-M00 环境审计 | 2026-11-19 22:17 | XHYAPI HTTP | —（`/v1/models`） | 连通性 | 成功 | — | 0.7 s | 200，列出 13 个 Claude 模型 ID | 记录模型清单 |
| RCD-M00 环境审计 | 2026-11-19 22:18 | XHYAPI HTTP | `claude-opus-5-5` | 连通性 | 失败 403 | — | 0.8 s | `POST /v1/messages` → 403 已禁止 | 改走 CLI |
| RCD-M00 环境审计 | 2026-11-19 22:19 | XHYAPI HTTP | `claude-haiku-4-5-20251001` | 连通性 | 失败 403 | — | 0.6 s | 流式 POST 仍 403 | 中转只放行 CLI 指纹 |
| RCD-M00 环境审计 | 2026-11-19 22:20 | Claude CLI | `claude-haiku-4-5-20251001` | 连通性 | 成功（拒绝） | — | 2.1 s | 「模型可能不存在或无权访问」→ 鉴权通，分组不含 haiku | 记录额度限制 |
| RCD-M00 环境审计 | 2026-11-19 22:21 | Claude CLI | `claude-opus-5-5` | 连通性 | 超时 | — | >95 s | 无任何输出 | 标记 DEGRADED |
| RCD-M00 环境审计 | 2026-11-19 22:23 | Claude CLI | `claude-sonnet-5-5` | 连通性 | 超时 | — | >40 s | 无任何输出 | 标记 DEGRADED |
| RCD-M00 环境审计 | 2026-11-19 22:24 | XHYAPI HTTP | `claude-opus-5-5` / `claude-sonnet-5-5` | 连通性 | 失败 403 | — | 0.7/0.6 s | `/v1/chat/completions` 均 403 | 放弃直连方案 |
| RCD-M00 环境审计 | 2026-11-19 22:25 | Claude CLI | `claude-opus-4-5-20251101` | 连通性 | 成功（拒绝） | — | 2.1 s | 无权访问 | 分组模型受限 |
| RCD-M00 环境审计 | 2026-11-19 22:25 | Claude CLI | `claude-fable-5-1` | 连通性 | 超时 | — | >40 s | 无任何输出 | 标记 DEGRADED |
| RCD-M00 环境审计 | 2026-11-19 22:26 | DSH 路由 | `deepseek-account` | 连通性 | 成功 | — | — | `list_subagent_models` 只返回 deepseek-account；`amazon-bedrock` 返回 not allowed | 双高阶池暂缓 |

## 后续实绩与当前分工

| 任务 | 日期 | 实际模型与通道 | 结果与采纳 | CLI 成本 |
|---|---|---|---|---|
| RCD-ROLL-MODES | 2026-11-19 | `claude-opus-5-5` / Claude Code–XHYAPI | 三模式与死亡 HUD，采纳 `684483c` | USD 2.7525648 |
| RCD-ZONES | 2026-11-19 | `claude-opus-5-5` / Claude Code–XHYAPI | 关卡几何、ORBIT30、幽灵表现，采纳 `a18c90f` | USD 3.358603 |
| RCD-MARK-CUT | 2026-11-20 | `claude-opus-5-5` / Claude Code–XHYAPI | 回放时钟、MARK/CUT，采纳 `f2a0f62`；API 800.464 s，70 轮 | USD 4.209577 |
| RCD-A-VERIFY | 2026-11-20 | `ya/gpt-6.2-sol` / DSH 当前会话 | 输入录像、ROLL 探针修正、Corner Lock 基线；无新增 Claude/Gemini 调用 | 未提供 |

早期超时记录保留，Claude 的实际工程回执已覆盖早期可用性判断。上表是调用回执，不等于当前账户余额。Codex 登录、候选模型和费用门槛见 [路由策略](MODEL_ROUTING_POLICY.md)。
