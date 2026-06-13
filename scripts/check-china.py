#!/usr/bin/env python3
"""Check script for opencode-for-financial-services-cn — validates structure, references, and drift.

Usage:
    python3 scripts/check-china.py

Checks:
1. All skills/ SKILL.md files have valid YAML frontmatter
2. All agents/*.toml have valid TOML structure
3. No cross-references to Western data providers
4. All MCP servers have server.py and requirements.txt
5. All managed-agent-cookbooks agent.yaml files have correct MCP references
"""

import json
import os
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
_ERROR_COUNT = 0

REQUIRED_SKILL_FRONTMATTER = {"name", "description"}
FORBIDDEN_PATTERNS = [
    r"capiq",
    r"factset",
    r"S&P",
    r"Capital IQ",
    r"Bloomberg",
    r"EDGAR",
    r"Daloopa",
    r"Morningstar",
    r"Kensho",
    r"kfinance",
]

MCP_SERVER_CONFIG = {
    "ifind-mcp":    {"config_required": True,  "config_key": "IFIND_AUTH_TOKEN", "mcp_name": "ifind"},
    "wind-mcp":     {"config_required": True,  "config_key": "WIND_API_KEY",     "mcp_name": "wind"},
    "akshare-mcp":  {"config_required": False, "config_key": None,               "mcp_name": "akshare"},
    "china-news-mcp": {"config_required": False, "config_key": None,             "mcp_name": "china-news"},
}

ALL_MCP_NAMES = {cfg["mcp_name"] for cfg in MCP_SERVER_CONFIG.values()}


def log_error(msg: str) -> None:
    global _ERROR_COUNT
    _ERROR_COUNT += 1
    print(f"  ✖  {msg}", file=sys.stderr)


def log_ok(msg: str) -> None:
    print(f"  ✓  {msg}")


def parse_frontmatter(text: str) -> dict:
    """Extract YAML frontmatter as a dict (minimal, no pyyaml dep)."""
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    result = {}
    for line in m.group(1).strip().split("\n"):
        if ":" in line:
            key, _, val = line.partition(":")
            result[key.strip()] = val.strip()
    return result


# ---------------------------------------------------------------------------
# 1. Skill checks (flat skills/ directory)
# ---------------------------------------------------------------------------

def check_skills() -> None:
    """Check all SKILL.md files in skills/ and flag missing/invalid frontmatter."""
    skill_dir = PROJECT_DIR / "skills"
    if not skill_dir.exists():
        log_error("Missing skills/ directory")
        return

    for entry in sorted(skill_dir.iterdir()):
        if not entry.is_dir():
            continue
        skill_file = entry / "SKILL.md"
        if not skill_file.exists():
            log_error(f"Missing SKILL.md in {entry}")
            continue

        text = skill_file.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)

        # Frontmatter checks
        for field in REQUIRED_SKILL_FRONTMATTER:
            if not fm.get(field):
                log_error(f"{skill_file}: missing frontmatter field '{field}'")
                continue

        # name must start with china-
        if fm.get("name") and not fm["name"].startswith("china-"):
            log_error(f"{skill_file}: name '{fm['name']}' should start with 'china-'")

        # Forbidden Western data patterns
        for pat in FORBIDDEN_PATTERNS:
            if re.search(pat, text, re.IGNORECASE):
                log_error(f"{skill_file}: contains forbidden pattern '{pat}'")

        log_ok(f"skill {entry.name}")


# ---------------------------------------------------------------------------
# 2. Agent TOML checks
# ---------------------------------------------------------------------------

def check_agents() -> None:
    """Check all agent TOML files in agents/."""
    agent_dir = PROJECT_DIR / "agents"
    if not agent_dir.exists():
        log_error("Missing agents/ directory")
        return

    for entry in sorted(agent_dir.glob("*.toml")):
        text = entry.read_text(encoding="utf-8")
        if 'name = "' not in text:
            log_error(f"{entry}: missing 'name' field")
            continue

        if 'description = "' not in text:
            log_error(f"{entry}: missing 'description' field")

        if 'developer_instructions' not in text:
            log_error(f"{entry}: missing 'developer_instructions' field")

        for pat in FORBIDDEN_PATTERNS:
            if re.search(pat, text, re.IGNORECASE):
                log_error(f"{entry}: contains forbidden pattern '{pat}'")

        log_ok(f"agent {entry.name}")


# ---------------------------------------------------------------------------
# 3. MCP server integrity checks
# ---------------------------------------------------------------------------

def check_mcp_servers() -> None:
    """Validate all MCP server directories have required files."""
    mcp_dir = PROJECT_DIR / "mcp-servers"
    if not mcp_dir.exists():
        log_error("Missing mcp-servers/ directory")
        return

    for server_name, config in MCP_SERVER_CONFIG.items():
        server_path = mcp_dir / server_name
        if not server_path.is_dir():
            log_error(f"MCP server {server_name}: directory missing")
            continue

        for required_file in ["server.py", "requirements.txt"]:
            if not (server_path / required_file).exists():
                log_error(f"MCP server {server_name}: missing {required_file}")

        if config["config_required"]:
            log_ok(f"MCP server {server_name} (requires {config['config_key']})")
        else:
            log_ok(f"MCP server {server_name} (no config needed)")


# ---------------------------------------------------------------------------
# 4. Cookbook MCP reference checks
# ---------------------------------------------------------------------------

def check_cookbooks() -> None:
    """Validate cookbook agent.yaml references reflect expected MCP usage."""
    cookbooks_dir = PROJECT_DIR / "managed-agent-cookbooks"
    if not cookbooks_dir.exists():
        log_error("Missing managed-agent-cookbooks/ directory")
        return

    for cb_entry in sorted(cookbooks_dir.iterdir()):
        if not cb_entry.is_dir():
            continue

        agent_yaml = cb_entry / "agent.yaml"
        if not agent_yaml.exists():
            log_error(f"cookbook {cb_entry.name}: missing agent.yaml")
            continue

        yaml_text = agent_yaml.read_text(encoding="utf-8")

        # Check that tier references are explicit
        has_ifind = "ifind" in yaml_text.lower()
        has_akshare = "akshare" in yaml_text.lower()
        has_wind = "wind" in yaml_text.lower()

        if has_wind and not has_ifind:
            log_error(f"cookbook {cb_entry.name}/agent.yaml: Wind referenced but iFind fallback missing")

        log_ok(f"cookbook {cb_entry.name}: {'+'.join(filter(None, ['Wind' if has_wind else '', 'iFind' if has_ifind else '', 'AkShare' if has_akshare else '']))}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    print("\n── China Plugin Validation (opencode edition) ──\n")

    # 1. Check skills
    print("[1/4] Skills")
    check_skills()

    # 2. Check agents
    print("\n[2/4] Agents")
    check_agents()

    # 3. Check MCP servers
    print("\n[3/4] MCP server integrity")
    check_mcp_servers()

    # 4. Check cookbooks
    print("\n[4/4] Cookbook MCP configuration (reference only)")
    check_cookbooks()

    # Summary
    if _ERROR_COUNT:
        print(f"\n── {_ERROR_COUNT} error(s) found ──\n", file=sys.stderr)
        return 1

    print("\n── All checks passed ──\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
