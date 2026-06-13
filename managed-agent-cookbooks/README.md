# Managed-agent templates for Chinese financial services

> ⚠️ **opencode 适配说明**
>
> 本目录是原项目（Claude Managed Agent）的 **设计参考文件**。YAML 格式、`model: claude-opus-4-7`、`POST /v1/agents` API、`from_plugin` 等均为 **Claude 生态概念**，无法直接在 opencode 中加载。
>
> **opencode 可加载的等效 agent 在 [`../agents/`](../agents/) 目录**（TOML 格式）。
>
> | Claude Managed Agent | opencode 等效 |
> |---|---|
> | `agent.yaml` + `model: claude-opus-4-7` | `agents/<name>.toml`（opencode 不内嵌模型配置） |
> | `subagents/*.yaml` | 合并到 agent 的 `developer_instructions` 中 |
> | `ANTHROPIC_API_KEY` | opencode 使用各自模型提供商的 API key（`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 等） |
> | `POST /v1/agents` + `deploy-managed-agent.sh` | 不适用；agent TOML 放至 `CODEX_HOME/agents/` 即可用 |
> | `from_plugin` / `callable_agents` | `skill()` 加载方式 + agent 路由替换 |
>
> 以下内容保留原样，供理解 agent 设计思路、安全隔离策略、handoff 编排参考。

Every agent in this directory ships **two ways from one source**: as a Cowork plugin your analysts install today, and as a Claude Managed Agent template your platform team deploys behind your own workflow engine. **Same agent, same skills — pick your surface.** Each directory below is a deploy manifest that references the canonical system prompt and skills from the matching plugin, so there is one source of truth.

Run `../scripts/deploy-managed-agent.sh <slug>` to upload skills, create leaf workers, and `POST /v1/agents` with the resolved config. Each template ships with [`steering-examples.json`](./china-pitch-agent/steering-examples.json) and a per-agent README covering its security tier and handoffs.

All agents use **iFind** (Tier-1 付费) and **AkShare** (Tier-2 免费备选) for A-share market data (financial statements, prices, filings, industry classification), and **china-news-mcp** for Chinese-language news and announcements. See the [china-finance vertical plugin](../vertical-plugins/china-finance) for the full skill and connector catalog.

| Agent | Cowork tile | CMA steering event | Leaf workers |
|---|---|---|---|
| [`china-pitch-agent`](./china-pitch-agent/) | End-to-end pitch for A-share targets — comps, DCF, LBO, football field, branded deck | `Build pitch book: <target> / <acquirer>, thesis: <text>` | researcher · modeler · **deck-writer** |
| [`china-market-researcher`](./china-market-researcher/) | A-share sector or theme → industry overview, competitive landscape, peer comps, ideas shortlist | `Primer: <sector or theme>, angle: <text>` | sector-reader · comps-spreader · **note-writer** |
| [`china-earnings-reviewer`](./china-earnings-reviewer/) | A-share earnings call + filings → model update → note draft | `Process earnings: <ticker> <period>` | data-reader · model-updater · **note-writer** |
| [`china-model-builder`](./china-model-builder/) | DCF, LBO, 3-statement, and comps models for Chinese equities | `Build <dcf\|lbo\|3-stmt> for <ticker>, assumptions: {...}` | data-puller · **builder** · auditor |

**Bold** leaf = the only worker with `Write`.

## Manifest vs API

The `agent.yaml` files use the real `POST /v1/agents` field names with a few conveniences the deploy script resolves:

| Manifest convention | Resolves to |
|---|---|
| `system: {file: ../../agent-plugins/<slug>/agents/<slug>.md, append: "..."}` | `system: "<inlined contents + append>"` |
| `system: {text: "..."}` | `system: "<text>"` |
| `skills: [{from_plugin: ../../agent-plugins/<slug>}]` | uploads every `skills/*` under that dir → `[{type: custom, skill_id: ...}, ...]` |
| `skills: [{path: ../../...}]` | `skills: [{type: custom, skill_id: <uploaded-id>}]` |
| `callable_agents: [{manifest: ./subagents/x.yaml}]` | `callable_agents: [{type: agent, id: <created-id>, version: latest}]` |

> **Research preview:** `callable_agents` (multi-agent delegation) supports **one delegation level**. An orchestrator can call workers; workers cannot call further subagents.

## Cross-agent handoffs

Named agents never call each other directly. When one agent needs another, it emits a `handoff_request` in its output; [`../scripts/orchestrate.py`](../scripts/orchestrate.py) (or your Temporal/Airflow/Guidewire event bus) routes it as a new steering event to the target session. The reference script hard-allowlists targets and schema-validates payloads — see its header comment for the threat model.
