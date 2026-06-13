# China Pitch Agent — managed-agent cookbook

## Overview

Comps, precedents, DCF, LBO → branded pitch deck for A-share targets, end to end. Same source as the [`china-pitch-agent`](../../agent-plugins/china-pitch-agent) Cowork plugin — this directory is the Managed Agent cookbook for `POST /v1/agents`.

## opencode 适配

此 agent 的 opencode 可加载版本在 [`../../agents/china-pitch-agent.toml`](../../agents/china-pitch-agent.toml)。

opencode 中无需 `ANTHROPIC_API_KEY` 环境变量；MCP 服务器直接通过 `skill()` 加载：
- `skill(name="china-market-data")` 提供数据源
- `skill(name="china-pptx-author")` 提供 PPT 生成
- `skill(name="china-comps")`、`skill(name="china-dcf")` 等提供估值方法

## Steering events

See [`steering-examples.json`](./steering-examples.json).

## Security & handoffs

Task-decomposition split — less about untrusted inputs (data comes from iFind / AkShare MCP), more about parallelism and artifact isolation. Exactly one worker holds `Write`:

| Leaf | Tools | Connectors |
|---|---|---|
| `researcher` | `Read`, `Grep` | iFind / AkShare (read-only) |
| `modeler` | `Read`, `Bash` (sandboxed) | iFind / AkShare (read-only) |
| **`deck-writer`** (Write-holder) | `Read`, `Write`, `Edit` | None |

Artifacts land in `./out/pitch-<target>.pptx` and `./out/model.xlsx` via `pptx-author` / `xlsx-author`.

**Handoff:** to rebuild the model after a thesis change, the orchestrator emits a `handoff_request` for `china-model-builder`; `scripts/orchestrate.py` (or your workflow engine) routes it as a new steering event. See the script for the allowlist + payload-validation pattern.
