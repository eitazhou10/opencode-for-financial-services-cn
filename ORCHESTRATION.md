# OpenCode 多 Agent 编排

本仓库内置 **4 个 A 股金融专用 agent**。与 Claude Managed Agents（需要外部 Python 事件循环——已删除的 `scripts/orchestrate.py`）不同，**OpenCode 通过 Sisyphus 和 `task()` API 原生支持多 agent 编排**。

无需外部事件循环，无需 API key，无需轮询。

## Agents

| Agent | 角色 | 技能 |
|-------|------|------|
| `china-market-researcher` | 行业/主题研究、竞争格局、估值对比 | `china-market-data`, `china-comps`, `china-sector-overview`, `china-competitive-analysis`, `china-idea-generation`, `china-catalyst-calendar` |
| `china-earnings-reviewer` | 财报后处理、差异分析、模型更新 | `china-market-data`, `china-comps`, `china-earnings-analysis`, `china-earnings-preview`, `china-model-update` |
| `china-model-builder` | DCF、LBO、三表模型、估值 Excel 建模 | `china-market-data`, `china-comps`, `china-dcf`, `china-3-statement-model`, `china-lbo-model`, `china-model-update`, `china-audit-xls` |
| `china-pitch-agent` | 估值、路演材料、交易材料 | `china-market-data`, `china-comps`, `china-dcf`, `china-3-statement-model`, `china-lbo-model`, `china-strip-profile`, `china-competitive-analysis`, `china-sector-overview`, `china-earnings-analysis`, `china-thesis-tracker`, `china-idea-generation`, `china-merger-model`, `china-teaser`, `china-cim-builder`, `china-process-letter`, `china-deal-tracker`, `china-audit-xls` |

## 编排模式

在 Claude Managed Agents 中，编排需要一段 Python 脚本（`orchestrate.py`），其流程为：

1. 启动编排器 agent 会话
2. 轮询输出文本中的 `handoff_request` JSON 片段
3. 调用 `POST /v1/agents/:id/steer` 将工作路由给子 agent

在 OpenCode 中，编排器（Sisyphus）直接使用 `task()` 调度任务：

```
┌──────────────────────────────────────────────────────────┐
│                    Sisyphus（你）                          │
│  决定：需要做什么、分发给哪个 agent                         │
├──────────────────────────────────────────────────────────┤
│                          │                               │
│   ┌──────────────────────┼──────────────────────┐       │
│   ▼                      ▼                      ▼       │
│ china-market-      china-earnings-        china-pitch-  │
│ researcher         reviewer               agent         │
│（后台）             （后台）                （后台）       │
│   ▲                      ▲                      ▲       │
│   └──────────────────────┼──────────────────────┘       │
│                          │                               │
│              通过 background_output(task_id="bg_...")     │
│              收集结果                                     │
└──────────────────────────────────────────────────────────┘
```

## 使用方法

### 1. 安装

```bash
# 安装 MCP 依赖（AkShare、iFind、Wind、中国新闻）
./scripts/install.sh

# 链接 skill 和 agent 配置供 opencode 使用
./scripts/install.sh --link-skills --link-agents
```

### 2. 启动 MCP 服务器

```bash
# 免费版（仅 AkShare）
python3 mcp-servers/akshare-mcp/server.py &

# 添加付费数据源（如有 API key）
python3 mcp-servers/ifind-mcp/server.py &   # 同花顺 iFind
python3 mcp-servers/wind-mcp/server.py &     # 万得 Wind
```

### 3. 通过 Sisyphus 编排

在 OpenCode 会话中，Sisyphus 使用 `task()` API 分发 agent 任务：

```python
# 示例：A 股标的完整工作流
# Sisyphus 评估请求后并发分发任务

# 阶段 1 — 研究（并行）
bg_research = task(
    subagent_type="china-market-researcher",
    run_in_background=True,
    prompt="""TASK: 研究 600519.SH（贵州茅台）在白酒行业中的表现。
EXPECTED OUTCOME: 行业概览、竞争格局、估值对比。
CONTEXT: 侧重 2026 年展望、政策环境（消费税改革）、需求趋势。
OUT OF SCOPE: 不要建财务模型或路演材料——这些后续再做。"""
)

# 阶段 2 — 财报审核（并行）
bg_earnings = task(
    subagent_type="china-earnings-reviewer",
    run_in_background=True,
    prompt="""TASK: 审核 600519.SH（贵州茅台）最新季度财报。
EXPECTED OUTCOME: 差异表（实际 vs 一致预期 vs 上期）、财报要点草稿。
CONTEXT: 涵盖收入、毛利率、净利润、EPS 拆解。"""
)

# 等待两个任务完成
research_results = background_output(task_id=bg_research)
earnings_results = background_output(task_id=bg_earnings)

# 阶段 3 — 模型与路演（串行，依赖前期结果）
bg_model = task(
    subagent_type="china-model-builder",
    run_in_background=True,
    prompt=f"""TASK: 为 600519.SH 建立 DCF 模型。
INPUT: {research_results[:2000]}...
CONTEXT: 以中国 10 年期国债收益率为无风险利率，ERP 6-8%，税率 25%。""",
)

bg_pitch = task(
    subagent_type="china-pitch-agent",
    run_in_background=True,
    prompt=f"""TASK: 为 600519.SH 制作路演材料。
INPUT: {research_results[:2000]}, {earnings_results[:2000]}...
CONTEXT: 公司概况、估值摘要、估值对比明细。"""
)
```

### 4. 或直接交互式使用 agent

```bash
opencode --agent china-market-researcher
# 然后直接问："覆盖半导体行业——梳理 A 股玩家、估值对比、挖掘 3 个投资思路"
```

## 与 Claude Managed Agents 的关键区别

| 维度 | Claude Managed Agents | OpenCode（本仓库） |
|--------|----------------------|---------------------|
| **编排** | 外部 Python 事件循环（`orchestrate.py`） | Sisyphus `task()` 原生分发 |
| **任务交接** | 文本内 JSON `handoff_request` 片段 → API `POST /v1/agents/steer` | `task(run_in_background=true)` → `background_output()` |
| **Agent 配置** | `agent.yaml` + `agents/*.md` | `agents/` 目录下的 TOML 文件 |
| **Skill 打包** | 跨 `agent-plugins/*/skills/` 重复复制 | 扁平 `skills/` 目录，去重 |
| **API 依赖** | `anthropic` SDK + `ANTHROPIC_API_KEY` | 无（opencode 内置处理） |
| **并行能力** | 串行（一次一个 agent） | 完全并行（`run_in_background=true`） |

## 编排模式

### 扇出（并行独立任务）

```python
bg1 = task(subagent_type="china-market-researcher", run_in_background=True, prompt="...")
bg2 = task(subagent_type="china-earnings-reviewer", run_in_background=True, prompt="...")
bg3 = task(subagent_type="china-model-builder",    run_in_background=True, prompt="...")
# 三个任务同时运行
r1 = background_output(task_id=bg1)
r2 = background_output(task_id=bg2)
r3 = background_output(task_id=bg3)
```

### 流水线（串行依赖任务）

```python
# 阶段 1：研究 → 拿到结果
bg = task(subagent_type="china-market-researcher", run_in_background=True, prompt="研究 000858.SZ")
research = background_output(task_id=bg)
# 阶段 2：将结果传给下一个 agent
bg = task(subagent_type="china-pitch-agent", run_in_background=True, prompt=f"根据以下研究材料制作路演材料：{research}")
```

### 分支合并

```python
bg_r = task(subagent_type="china-market-researcher", run_in_background=True, prompt="...")
bg_m = task(subagent_type="china-model-builder",     run_in_background=True, prompt="...")
# 等待两者完成，合并后交给路演 agent
r = background_output(task_id=bg_r)
m = background_output(task_id=bg_m)
task(subagent_type="china-pitch-agent", prompt=f"将研究和模型合并为路演材料：\n{r}\n{m}")
```
