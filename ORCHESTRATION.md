# Multi-Agent Orchestration with OpenCode

This repository ships 4 specialized A-share financial agents. Unlike Claude's Managed
Agents (which require an external Python event loop — the deleted `scripts/orchestrate.py`),
**OpenCode handles multi-agent orchestration natively** via Sisyphus and the `task()` API.

No external event loop, no API keys, no polling.

## Agents

| Agent | Role | Skills |
|-------|------|--------|
| `china-market-researcher` | Sector/thematic research, competitive landscape, comps spread | `china-market-data`, `china-comps`, `china-sector-overview`, `china-competitive-analysis`, `china-idea-generation`, `china-catalyst-calendar` |
| `china-earnings-reviewer` | Post-earnings processing, variance analysis, model update | `china-market-data`, `china-comps`, `china-earnings-analysis`, `china-earnings-preview`, `china-model-update` |
| `china-model-builder` | DCF, LBO, 3-statement, comps Excel models | `china-market-data`, `china-comps`, `china-dcf`, `china-3-statement-model`, `china-lbo-model`, `china-model-update`, `china-audit-xls` |
| `china-pitch-agent` | Valuation, pitch deck, deal materials | `china-market-data`, `china-comps`, `china-dcf`, `china-3-statement-model`, `china-lbo-model`, `china-strip-profile`, `china-competitive-analysis`, `china-sector-overview`, `china-earnings-analysis`, `china-thesis-tracker`, `china-idea-generation`, `china-merger-model`, `china-teaser`, `china-cim-builder`, `china-process-letter`, `china-deal-tracker`, `china-audit-xls` |

## Orchestration Pattern

In Claude's Managed Agents, orchestration required a Python script (`orchestrate.py`) that:

1. Ran a session with an orchestrator agent
2. Polled for `handoff_request` JSON blobs in the text output
3. Called `POST /v1/agents/:id/steer` to route work to sub-agents

In OpenCode, the orchestrator (Sisyphus) dispatches work directly using `task()`:

```
┌──────────────────────────────────────────────────────────┐
│                    Sisyphus (you)                        │
│  Decides: what needs doing, which agent to dispatch to  │
├──────────────────────────────────────────────────────────┤
│                          │                               │
│   ┌──────────────────────┼──────────────────────┐       │
│   ▼                      ▼                      ▼       │
│ china-market-      china-earnings-        china-pitch-  │
│ researcher         reviewer               agent         │
│ (background)       (background)           (background)  │
│   ▲                      ▲                      ▲       │
│   └──────────────────────┼──────────────────────┘       │
│                          │                               │
│              Collect results via                         │
│         background_output(task_id="bg_...")              │
└──────────────────────────────────────────────────────────┘
```

## Usage

### 1. Installation

```bash
# Install MCP dependencies (AkShare, iFind, Wind, China News)
./scripts/install.sh

# Link skills and agents for opencode
./scripts/install.sh --link-skills --link-agents
```

### 2. Start MCP Servers

```bash
# Free tier (AkShare only)
python3 mcp-servers/akshare-mcp/server.py &

# Add paid data sources (if you have API keys)
python3 mcp-servers/ifind-mcp/server.py &   # 同花顺 iFind
python3 mcp-servers/wind-mcp/server.py &     # 万得 Wind
```

### 3. Orchestrate via Sisyphus

Within an OpenCode session, Sisyphus dispatches agents using the `task()` API:

```python
# Example: Full workflow for an A-share stock
# Sisyphus evaluates the request and fans out parallel tasks

# Phase 1 — Research (parallel)
bg_research = task(
    subagent_type="china-market-researcher",
    run_in_background=True,
    prompt="""TASK: Research 600519.SH (贵州茅台) in the baijiu sector.
EXPECTED OUTCOME: Industry overview, competitive landscape, comps spread.
CONTEXT: Focus on 2026 outlook, policy environment (消费税改革), demand trends.
OUT OF SCOPE: Don't build financial models or pitch decks — those come later."""
)

# Phase 2 — Earnings Review (parallel)
bg_earnings = task(
    subagent_type="china-earnings-reviewer",
    run_in_background=True,
    prompt="""TASK: Review 600519.SH (贵州茅台) most recent quarterly earnings.
EXPECTED OUTCOME: Variance table (actual vs consensus vs prior), earnings note draft.
CONTEXT: Include revenue, gross margin, net income, EPS breakdown."""
)

# Wait for both to complete
research_results = background_output(task_id=bg_research)
earnings_results = background_output(task_id=bg_earnings)

# Phase 3 — Model & Pitch (sequential, depends on earlier results)
bg_model = task(
    subagent_type="china-model-builder",
    run_in_background=True,
    prompt=f"""TASK: Build a DCF model for 600519.SH.
INPUT: {research_results[:2000]}...
CONTEXT: Use China 10Y CGB as risk-free rate, 6-8% ERP, 25% tax rate.""",
)

bg_pitch = task(
    subagent_type="china-pitch-agent",
    run_in_background=True,
    prompt=f"""TASK: Create a pitch deck for 600519.SH.
INPUT: {research_results[:2000]}, {earnings_results[:2000]}...
CONTEXT: Situation overview, valuation summary, comps detail."""
)
```

### 4. Or use the agents interactively

```bash
opencode --agent china-market-researcher
# Then just ask: "Cover the semicon sector — map the A-shape players, spread comps, surface 3 ideas"
```

## Key Differences from Claude Managed Agents

| Aspect | Claude Managed Agents | OpenCode (this repo) |
|--------|----------------------|---------------------|
| **Orchestration** | External Python event loop (`orchestrate.py`) | Sisyphus `task()` dispatch, native |
| **Handoff mechanism** | JSON `handoff_request` blob in text → API `POST /v1/agents/steer` | `task(run_in_background=true)` → `background_output()` |
| **Agent config** | `agent.yaml` + `agents/*.md` | TOML files in `agents/` |
| **Skills packaging** | Duplicated across `agent-plugins/*/skills/` | Flat `skills/` directory, deduplicated |
| **API dependency** | `anthropic` SDK + `ANTHROPIC_API_KEY` | None (opencode handles it) |
| **Parallelism** | Sequential (one agent at a time) | Full parallel via `run_in_background=true` |

## Orchestration Patterns

### Fan-out (parallel independent tasks)

```python
bg1 = task(subagent_type="china-market-researcher", run_in_background=True, prompt="...")
bg2 = task(subagent_type="china-earnings-reviewer", run_in_background=True, prompt="...")
bg3 = task(subagent_type="china-model-builder",    run_in_background=True, prompt="...")
# All three run simultaneously
r1 = background_output(task_id=bg1)
r2 = background_output(task_id=bg2)
r3 = background_output(task_id=bg3)
```

### Pipeline (sequential dependent tasks)

```python
# Phase 1: Research → get results
bg = task(subagent_type="china-market-researcher", run_in_background=True, prompt="Research 000858.SZ")
research = background_output(task_id=bg)
# Phase 2: Pass results to next agent
bg = task(subagent_type="china-pitch-agent", run_in_background=True, prompt=f"Build deck using: {research}")
```

### Branch-and-merge

```python
bg_r = task(subagent_type="china-market-researcher", run_in_background=True, prompt="...")
bg_m = task(subagent_type="china-model-builder",     run_in_background=True, prompt="...")
# Wait for both, merge into pitch
r = background_output(task_id=bg_r)
m = background_output(task_id=bg_m)
task(subagent_type="china-pitch-agent", prompt=f"Merge research and model into deck:\n{r}\n{m}")
```
