# opencode-for-financial-services-cn

🇨🇳 **58 个 A 股金融 Skills + 4 个 MCP 数据服务器 — 为 opencode 生态打造**

基于 [jwangkun/claude-for-financial-services-cn](https://github.com/jwangkun/claude-for-financial-services-cn) (Apache 2.0) 进行 opencode 适配改造。

> 原版是 Anthropic 官方 [claude-for-financial-services](https://github.com/anthropics/claude-for-financial-services) 的中国市场适配分支。
> 本项目将 Claude 插件格式改造为 opencode 兼容的 SKILL.md + TOML agent 格式，MCP 服务器保持不变。

---

## 项目结构

```
opencode-for-financial-services-cn/
├── mcp-servers/            # Python MCP 数据服务器
│   ├── akshare-mcp/        # AkShare 免费开源数据 (Tier-2, 无需密钥)
│   ├── china-news-mcp/     # 财经新闻/公告 (Tier-3, 无需密钥)
│   ├── ifind-mcp/          # 同花顺 iFind (Tier-1, 需付费 API)
│   └── wind-mcp/           # 万得 Wind (Tier-0, 需付费 API)
├── skills/                 # 58 个 opencode SKILL.md
│   ├── china-comps/        # 可比公司估值
│   ├── china-dcf/          # DCF 估值
│   ├── china-earnings-analysis/  # 业绩点评
│   └── ... (共计 58 个)
├── agents/                 # 4 个 opencode TOML agent
│   ├── china-pitch-agent.toml
│   ├── china-market-researcher.toml
│   ├── china-earnings-reviewer.toml
│   └── china-model-builder.toml
├── managed-agent-cookbooks/ # 原版 Claude Managed Agent YAML (参考设计)
│   ├── china-pitch-agent/
│   ├── china-market-researcher/
│   ├── china-earnings-reviewer/
│   └── china-model-builder/
├── scripts/                # 工具脚本
│   ├── install.sh          # 一键安装脚本
│   └── generate_a_share_ppt.py
├── SKILLS-MANIFEST.json    # Skills 注册清单
└── LICENSE                 # Apache 2.0
```

## 快速开始

### 1. 安装 MCP 服务器依赖

```bash
# 克隆本项目
git clone https://github.com/eitazhou10/opencode-for-financial-services-cn.git
cd opencode-for-financial-services-cn

# 安装所有 MCP 服务器的 Python 依赖
pip install -r mcp-servers/akshare-mcp/requirements.txt
pip install -r mcp-servers/china-news-mcp/requirements.txt
```

免费数据源无需密钥，可直接启动：

```bash
# 启动 AkShare MCP (A 股行情/财报/行业数据 — 无需 API 密钥，数据采集自公开财经网站)
python3 mcp-servers/akshare-mcp/server.py

# 启动财经新闻 MCP (财联社/东方财富/交易所公告)
python3 mcp-servers/china-news-mcp/server.py
```

### 2. 安装 Skills 到 opencode

```bash
# 自动链接所有 SKILL.md 到 ~/.agents/skills/
./scripts/install.sh --link-skills
```

然后在 opencode 中通过 `skill()` 工具加载，例如：

```markdown
skill(name="china-comps")
skill(name="china-dcf")
```

### 3. (可选) 安装 Agents

```bash
./scripts/install.sh --link-agents
```

### 4. 配置付费数据源 (可选)

如果需要 Wind 或 iFind 数据，设置环境变量：

```bash
# Wind (万得) — 最全面的 A 股金融数据
export WIND_API_KEY="ak_your-key-here"

# iFind (同花顺)
export IFIND_AUTH_TOKEN="your-jwe-token-here"
```

免费版 (AkShare + 财经新闻) 无需任何配置，开箱即用。

---

## Skills 一览

### china-finance (31 个) — A 股研究核心

| Skill | 说明 |
|---|---|
| `china-comps` | 可比公司估值 (PE/PB/PS) |
| `china-comps-analysis` | 深度可比分析 + 行业洞察 |
| `china-dcf` / `china-dcf-model` | DCF 估值（中债无风险利率） |
| `china-lbo-model` | 杠杆收购模型 |
| `china-3-statement-model` | 三表联动模型 |
| `china-earnings-analysis` | 季度/年度业绩点评 |
| `china-earnings-preview` | 财报前瞻 |
| `china-model-update` | 覆盖模型自动更新 |
| `china-sector-overview` | 行业研究综述 |
| `china-catalyst-calendar` | 事件驱动日历 |
| `china-idea-generation` | A 股选股和标的筛选 |
| `china-thesis-tracker` | 投资观点跟踪 |
| `china-morning-note` | 晨会纪要 |
| `china-initiating-coverage` | 首次覆盖报告 |
| `china-deck-refresh` | 刷新 PPT 图表和数据 |
| `china-ib-check-deck` | 路演材料 QC |
| `china-ppt-template-creator` | PPT 模板技能 |
| `china-pptx-author` | 生成 .pptx 文件 |
| `china-xlsx-author` | 生成 .xlsx 文件 |
| `china-audit-xls` | Excel 模型审计 |
| `china-clean-data-xls` | 表格数据清洗 |
| `china-market-data` | Wind + iFind + AkShare 数据查询 |
| `china-variance-commentary` | 差异分析注释 |
| `china-accrual-schedule` | 应计项目时间表 |
| `china-break-trace` | 差异根因追踪 |
| `china-gl-recon` | 总账对账 |
| `china-roll-forward` | 数据滚动更新 |
| `china-deal-screening` | 项目初步筛选 |
| `china-skill-creator` | 创建自定义技能 |
| `china-tax-loss-harvesting` | 税损收割 |

### investment-banking (10 个) — A 股投行

| Skill | 说明 |
|---|---|
| `china-pitch-deck` | 填充 Pitch Deck 模板 |
| `china-merger-model` | 并购模型 |
| `china-cim-builder` | CIM 信息备忘录 |
| `china-teaser` | 匿名交易概要页 |
| `china-buyer-list` | 战略/财务买方清单 |
| `china-datapack-builder` | 数据包构建 |
| `china-process-letter` | 竞标流程函 |
| `china-strip-profile` | 一页公司简介 |
| `china-deal-tracker` | 项目进度跟踪 |
| `china-competitive-analysis` | 竞争格局分析 |

### private-equity (9 个) — 私募股权

| Skill | 说明 |
|---|---|
| `china-dd-checklist` | 尽职调查清单 |
| `china-ic-memo` | 投委会 memo |
| `china-portfolio-monitoring` | 被投企业 KPI 跟踪 |
| `china-returns-analysis` | IRR/MOIC 回报分析 |
| `china-deal-sourcing` | 标的发现 |
| `china-unit-economics` | 单位经济模型 |
| `china-value-creation-plan` | 投后改善计划 |
| `china-ai-readiness` | AI 就绪度评估 |
| `china-dd-meeting-prep` | 管理层访谈准备 |

### wealth-management (5 个) — 财富管理

| Skill | 说明 |
|---|---|
| `china-client-report` | 客户报告 |
| `china-client-review` | 客户回顾 |
| `china-financial-plan` | 理财规划 |
| `china-investment-proposal` | 投资建议书 |
| `china-portfolio-rebalance` | 组合再平衡 |

### fund-admin (1 个) — 基金运营

| Skill | 说明 |
|---|---|
| `china-nav-tieout` | 净值核对 |

*(其余 5 个 fund-admin skill 与 china-finance 共享，包括 `china-accrual-schedule`、`china-break-trace`、`china-gl-recon`、`china-roll-forward`、`china-variance-commentary`)*

### operations (2 个) — 运营

| Skill | 说明 |
|---|---|
| `china-kyc-doc-parse` | KYC 文档解析 |
| `china-kyc-rules` | KYC 规则引擎 |

---

## Agents (端到端智能体)

| Agent | 一句话 |
|---|---|
| **china-pitch-agent** | 投行 Pitch — 从估值建模到路演 PPT 一条龙 |
| **china-market-researcher** | 行业研究 — 行业概览 → 竞争格局 → 标的池 |
| **china-earnings-reviewer** | 业绩点评 — 财报解读 → 模型更新 → 研报输出 |
| **china-model-builder** | 财务建模 — DCF / LBO / 三表，直接出 Excel |

Agent 文件为 TOML 格式，安装到 `CODEX_HOME/agents/` 目录后可在 opencode 中通过 agent 路由使用。

---

## 数据源架构

多级优先级策略：商业数据源优先，自动降级到免费数据源。

| 优先级 | 服务 | 费用 | 说明 |
|---|---|---|---|
| **Tier-0** | wind-mcp | 💰 付费 | 万得 Wind — 44 个工具，全市场最全面数据 |
| **Tier-1** | ifind-mcp | 💰 付费 | 同花顺 iFind — 31 个工具，精准 A 股数据 |
| **Tier-2** | akshare-mcp | 🆓 免费 | AkShare 开源 — 从公开财经网站实时采集数据（东方财富/同花顺/新浪财经等）。无需任何 API 密钥，开箱即用 |
| **Tier-3** | china-news-mcp | 🆓 免费 | 财经新闻（财联社/东方财富/交易所公告） |

免费数据源 (AkShare + 财经新闻) 无需注册，开箱即用。AkShare 不需要任何 API 密钥，数据采集自公开数据源，仅需网络可达即可工作。

---

## 与原版的关系

| 维度 | jwangkun/claude-for-financial-services-cn | 本项目 |
|---|---|---|
| 目标平台 | Claude Code / Claude Desktop | opencode |
| Skill 格式 | Claude 插件 (plugin.json + marketplace.json) | SKILL.md (opencode 原生) |
| Agent 格式 | agent.md | TOML |
| MCP 服务器 | 标准 Python FastMCP | 不变，直接可用 |
| Skills 数量 | 63 (含重复) | 58 (去重后唯一) |
| 许可 | Apache 2.0 | Apache 2.0 |

本项目是原版的 **opencode 平台适配分支**，数据层不变，内容层格式改造。

---

## License

[Apache License 2.0](LICENSE)

```
Copyright 2026 jwangkun (original claude-for-financial-services-cn)
Copyright 2026 eitazhou10 (opencode adaptation)

Based on jwangkun/claude-for-financial-services-cn (Apache 2.0)
https://github.com/jwangkun/claude-for-financial-services-cn

Original data by Wind (万得) + iFind (同花顺) + AkShare
```

---

为 A 股市场的金融从业者打造
