#!/usr/bin/env bash
# ============================================================
# opencode-for-financial-services-cn — Comprehensive Test Suite
# ============================================================
# Tests: format, structure, imports, installation, integrity
# Usage:  bash scripts/test-all.sh [-v]
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
PASS=0
FAIL=0
SKIP=0

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERBOSE=false
[[ "${1:-}" == "-v" ]] && VERBOSE=true

pass()  { PASS=$((PASS+1)); echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { FAIL=$((FAIL+1)); echo -e "  ${RED}✖${NC} $1"; }
skip()  { SKIP=$((SKIP+1)); echo -e "  ${YELLOW}⊘${NC} $1"; }
header(){ echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }
detail(){ $VERBOSE && echo "       $1"; }

# Counters for composite tests
TOTAL_SKILL_FILES=58
TOTAL_AGENT_FILES=4
TOTAL_MCP_SERVERS=4

# ============================================================
header "1. Repository Structure"
# ============================================================

# 1a. Root files
echo "  1a. Root directory files..."
[[ -f "$REPO_DIR/LICENSE" ]]        && pass "LICENSE exists"        || fail "LICENSE missing"
[[ -f "$REPO_DIR/README.md" ]]      && pass "README.md exists"      || fail "README.md missing"
[[ -f "$REPO_DIR/.gitignore" ]]     && pass ".gitignore exists"     || fail ".gitignore missing"
[[ -f "$REPO_DIR/SKILLS-MANIFEST.json" ]] && pass "SKILLS-MANIFEST.json exists" || fail "SKILLS-MANIFEST.json missing"

# 1b. Directory structure
echo "  1b. Required directories..."
for d in skills agents mcp-servers scripts managed-agent-cookbooks; do
  [[ -d "$REPO_DIR/$d" ]] && pass "Directory $d/" || fail "Directory $d/ missing"
done

# 1c. File counts
echo "  1c. File counts..."
SKILL_COUNT=$(find "$REPO_DIR/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)
AGENT_COUNT=$(find "$REPO_DIR/agents" -name "*.toml" | wc -l)
MCP_COUNT=$(find "$REPO_DIR/mcp-servers" -mindepth 1 -maxdepth 1 -type d | wc -l)
COOKBOOK_COUNT=$(find "$REPO_DIR/managed-agent-cookbooks" -mindepth 1 -maxdepth 1 -type d | wc -l)

[[ "$SKILL_COUNT" -eq "$TOTAL_SKILL_FILES" ]] && pass "Skills: $SKILL_COUNT (expected $TOTAL_SKILL_FILES)" || fail "Skills: $SKILL_COUNT (expected $TOTAL_SKILL_FILES)"
[[ "$AGENT_COUNT" -eq "$TOTAL_AGENT_FILES" ]] && pass "Agents: $AGENT_COUNT (expected $TOTAL_AGENT_FILES)" || fail "Agents: $AGENT_COUNT (expected $TOTAL_AGENT_FILES)"
[[ "$MCP_COUNT" -eq "$TOTAL_MCP_SERVERS" ]]   && pass "MCP servers: $MCP_COUNT (expected $TOTAL_MCP_SERVERS)" || fail "MCP servers: $MCP_COUNT (expected $TOTAL_MCP_SERVERS)"
[[ "$COOKBOOK_COUNT" -eq 4 ]]                  && pass "Cookbooks: $COOKBOOK_COUNT (expected 4)" || fail "Cookbooks: $COOKBOOK_COUNT (expected 4)"

# ============================================================
header "2. SKILL.md Format Validation"
# ============================================================

echo "  2a. Frontmatter (name + description)..."
MISSING_NAME=0
MISSING_DESC=0
for skilldir in "$REPO_DIR/skills/"*/; do
  skillfile="$skilldir/SKILL.md"
  name=$(head -30 "$skillfile" | grep "^name:" | head -1 | sed 's/name:[[:space:]]*//')
  desc=$(head -30 "$skillfile" | grep "^description:" | head -1 | sed 's/description:[[:space:]]*//')
  [[ -z "$name" ]] && MISSING_NAME=$((MISSING_NAME+1)) && detail "MISSING name: $skillfile"
  [[ -z "$desc" ]] && MISSING_DESC=$((MISSING_DESC+1)) && detail "MISSING description: $skillfile"
done
[[ $MISSING_NAME -eq 0 ]] && pass "All $TOTAL_SKILL_FILES skills have 'name' frontmatter" || fail "$MISSING_NAME skills missing 'name'"
[[ $MISSING_DESC -eq 0 ]] && pass "All $TOTAL_SKILL_FILES skills have 'description' frontmatter" || fail "$MISSING_DESC skills missing 'description'"

echo "  2b. china- prefix convention..."
BAD_PREFIX=0
for skilldir in "$REPO_DIR/skills/"*/; do
  skillfile="$skilldir/SKILL.md"
  name=$(head -10 "$skillfile" | grep "^name:" | head -1 | sed 's/name:[[:space:]]*//')
  # wind-mcp has its own SKILL.md in mcp-servers/, not in skills/
  if [[ -n "$name" ]] && [[ "$name" != china-* ]]; then
    BAD_PREFIX=$((BAD_PREFIX+1))
    detail "Non-china- prefix: $name in $skillfile"
  fi
done
[[ "$BAD_PREFIX" -eq 0 ]] && pass "All skill names use china- prefix" || fail "$BAD_PREFIX skills do not start with china-"

echo "  2c. Required sections (Purpose, Data Sources, Workflow)..."
# Exceptions: alias skills, checklist skills, and reference skills use different templates
# dcf-model → alias for dcf (redirect wrapper)
# dd-checklist → checklist format (no workflow)
# kyc-doc-parse, kyc-rules → reference/document format
# pptx-author → generator format (uses ## Usage instead of ## Workflow)
EXEMPT_PURPOSE=""
EXEMPT_DATA="china-dcf-model|china-dd-checklist|china-pptx-author"
EXEMPT_WORKFLOW="china-dcf-model|china-dd-checklist|china-kyc-doc-parse|china-kyc-rules|china-pptx-author"
MISSING_PURPOSE=0
MISSING_DATA=0
MISSING_WORKFLOW=0
for skilldir in "$REPO_DIR/skills/"*/; do
  name=$(basename "$skilldir")
  skillfile="$skilldir/SKILL.md"
  content=$(cat "$skillfile")
  echo "$content" | grep -q "^## Purpose"         || MISSING_PURPOSE=$((MISSING_PURPOSE+1))
  echo "$content" | grep -qi "^## Data Source" || echo "$content" | grep -qi "^## Data Sources" || \
    { [[ "$name" =~ ^($EXEMPT_DATA)$ ]] || MISSING_DATA=$((MISSING_DATA+1)); }
  echo "$content" | grep -q "^## Workflow"         || \
    { [[ "$name" =~ ^($EXEMPT_WORKFLOW)$ ]] || MISSING_WORKFLOW=$((MISSING_WORKFLOW+1)); }
done
[[ "$MISSING_PURPOSE" -eq 0 ]]  && pass "All skills have ## Purpose"        || fail "$MISSING_PURPOSE missing ## Purpose"
[[ "$MISSING_DATA" -eq 0 ]]     && pass "All skills have ## Data Sources (exempt: $EXEMPT_DATA)"   || fail "$MISSING_DATA missing ## Data Sources"
[[ "$MISSING_WORKFLOW" -eq 0 ]] && pass "All skills have ## Workflow (exempt: $EXEMPT_WORKFLOW)"       || fail "$MISSING_WORKFLOW missing ## Workflow"

echo "  2d. Forbidden Western data patterns..."
FORBIDDEN="capiq|factset|Capital IQ|Bloomberg|EDGAR|Daloopa|Morningstar|Kensho"
VIOLATIONS=0
for skillfile in "$REPO_DIR/skills"/*/SKILL.md; do
  if grep -qiE "$FORBIDDEN" "$skillfile" 2>/dev/null; then
    VIOLATIONS=$((VIOLATIONS+1))
    detail "FOUND in $skillfile"
  fi
done
[[ "$VIOLATIONS" -eq 0 ]] && pass "No forbidden Western patterns in skills" || fail "$VIOLATIONS skills contain forbidden patterns"

# ============================================================
header "3. Agent TOML Format Validation"
# ============================================================

echo "  3a. Required fields..."
for agentfile in "$REPO_DIR/agents/"*.toml; do
  name=$(basename "$agentfile")
  grep -q '^name = ' "$agentfile"      && pass "$name: name field"      || fail "$name: missing name"
  grep -q '^description = ' "$agentfile" && pass "$name: description"  || fail "$name: missing description"
  grep -q 'developer_instructions' "$agentfile" && pass "$name: developer_instructions" || fail "$name: missing developer_instructions"
done

echo "  3b. Skill reference validity..."
for agentfile in "$REPO_DIR/agents/"*.toml; do
  name=$(basename "$agentfile")
  # Extract skill references from the Skills section
  skills_line=$(grep -A5 "^## Skills\|skills this agent uses" "$agentfile" | grep -Eo '`[a-z][a-z-]+`' | tr -d '`' || true)
  if [[ -z "$skills_line" ]]; then
    # Try to find skills in developer_instructions block
    skills_line=$(sed -n '/developer_instructions/,/^"""$/p' "$agentfile" | grep -oP '`china-[a-z][a-z-]+`' | tr -d '`' || true)
  fi
  if [[ -n "$skills_line" ]]; then
    for skill_ref in $skills_line; do
      if [[ -d "$REPO_DIR/skills/$skill_ref" ]]; then
        pass "$name references '$skill_ref' ✓"
      else
        fail "$name references '$skill_ref' but skill directory not found!"
      fi
    done
  fi
done

# ============================================================
header "4. MCP Server Verification"
# ============================================================

echo "  4a. Python syntax check..."
for mcp_dir in "$REPO_DIR/mcp-servers/"*/; do
  name=$(basename "$mcp_dir")
  server="$mcp_dir/server.py"
  if [[ -f "$server" ]]; then
    python3 -c "import py_compile; py_compile.compile('$server', doraise=True)" 2>/dev/null \
      && pass "$name: server.py syntax OK" \
      || fail "$name: server.py syntax error"
  else
    fail "$name: missing server.py"
  fi
done

echo "  4b. requirements.txt..."
for mcp_dir in "$REPO_DIR/mcp-servers/"*/; do
  name=$(basename "$mcp_dir")
  [[ -f "$mcp_dir/requirements.txt" ]] && pass "$name: requirements.txt exists" || fail "$name: missing requirements.txt"
done

echo "  4c. Python import check (available dependencies)..."
for mcp_name in akshare-mcp china-news-mcp wind-mcp ifind-mcp; do
  server="$REPO_DIR/mcp-servers/$mcp_name/server.py"
  if [[ -f "$server" ]]; then
    # Try importing the modules the server needs
    import_test=$(head -30 "$server" | grep "^import\|^from " | grep -v "^#" | head -5 || true)
    # Just check if basic deps are available
    deps_ok=true
    for pkg in mcp requests; do
      python3 -c "import $pkg" 2>/dev/null || { deps_ok=false; break; }
    done
    $deps_ok && pass "$mcp_name: core dependencies (mcp, requests) available" || fail "$mcp_name: core dependencies missing"
  fi
done

echo "  4d. Wind MCP reference files..."
for ref in error-codes.json fallback-alice.md indicators.md tool-contracts.md tool-manifest.json; do
  [[ -f "$REPO_DIR/mcp-servers/wind-mcp/references/$ref" ]] && pass "wind-mcp/references/$ref" || fail "wind-mcp/references/$ref missing"
done

# ============================================================
header "5. Installation Verification"
# ============================================================

echo "  5a. Skills installed in ~/.agents/skills/..."
INSTALLED_COUNT=0
for skilldir in "$REPO_DIR/skills/"*/; do
  name=$(basename "$skilldir")
  if [[ -L "$HOME/.agents/skills/$name" ]] || [[ -d "$HOME/.agents/skills/$name/SKILL.md" ]]; then
    INSTALLED_COUNT=$((INSTALLED_COUNT+1))
  fi
done
# Actually check through symlinks
INSTALLED_LINKS=$(find "$HOME/.agents/skills" -maxdepth 1 -type l -lname "*opencode-fin-cn*" | wc -l)
[[ "$INSTALLED_LINKS" -eq "$TOTAL_SKILL_FILES" ]] && pass "Skills installed: $INSTALLED_LINKS (expected $TOTAL_SKILL_FILES)" || fail "Skills installed: $INSTALLED_LINKS (expected $TOTAL_SKILL_FILES)"

echo "  5b. Agents deployed..."
AGENTS_DEPLOYED=$(find ~/.config/opencode/agents -name "*.toml" | wc -l)
[[ "$AGENTS_DEPLOYED" -eq "$TOTAL_AGENT_FILES" ]] && pass "Agents deployed: $AGENTS_DEPLOYED" || fail "Agents deployed: $AGENTS_DEPLOYED (expected $TOTAL_AGENT_FILES)"

echo "  5c. SKILLS-MANIFEST.json validity..."
python3 -c "
import json
with open('$REPO_DIR/SKILLS-MANIFEST.json') as f:
    data = json.load(f)
skills = data.get('skills', {})
assert len(skills) == $TOTAL_SKILL_FILES, f'Expected $TOTAL_SKILL_FILES skills in manifest, got {len(skills)}'
for name in skills:
    assert name.startswith('china-'), f'Non-china prefix: {name}'
    assert 'description' in skills[name], f'Missing description: {name}'
print(f'  ✓ Manifest valid: {len(skills)} skills')
" && pass "SKILLS-MANIFEST.json is valid" || fail "SKILLS-MANIFEST.json has issues"

# ============================================================
header "6. Script Verification"
# ============================================================

echo "  6a. Python syntax check for scripts..."
for script in check-china.py generate_a_share_ppt.py; do
  python3 -c "import py_compile; py_compile.compile('$REPO_DIR/scripts/$script', doraise=True)" 2>/dev/null \
    && pass "scripts/$script syntax OK" \
    || fail "scripts/$script syntax error"
done

echo "  6b. install.sh syntax check..."
bash -n "$REPO_DIR/scripts/install.sh" && pass "install.sh syntax OK" || fail "install.sh syntax error"

echo "  6c. check-china.py validation run..."
python3 "$REPO_DIR/scripts/check-china.py" 2>&1 | tail -5 | grep -q "All checks passed" \
  && pass "check-china.py: all checks passed" \
  || fail "check-china.py: some checks failed"

# ============================================================
header "7. Content Integrity"
# ============================================================

echo "  7a. No remaining mcp__ prefix in runtime files..."
# Check skills/ and agents/ for any mcp__ references
MCP_SKILLS=$(grep -rn "mcp__" "$REPO_DIR/skills" "$REPO_DIR/agents" --include="*.md" --include="*.toml" 2>/dev/null || true)
if [[ -z "$MCP_SKILLS" ]]; then
  pass "No mcp__ prefix in skills/ or agents/"
else
  fail "mcp__ prefix found: $MCP_SKILLS"
fi
# wind-mcp/SKILL.md should not have mcp__ prefix
if grep -q "mcp__" "$REPO_DIR/mcp-servers/wind-mcp/SKILL.md" 2>/dev/null; then
  fail "wind-mcp/SKILL.md: still has mcp__ prefix"
else
  pass "wind-mcp/SKILL.md: no mcp__ prefix"
fi

echo "  7b. No ANTHROPIC_API_KEY in runtime files..."
ANTHROPIC=$(grep -rn "ANTHROPIC_API_KEY" "$REPO_DIR/skills" "$REPO_DIR/agents" "$REPO_DIR/scripts" "$REPO_DIR/mcp-servers" --include="*.md" --include="*.toml" --include="*.py" 2>/dev/null | grep -v "managed-agent-cookbooks" || true)
[[ -z "$ANTHROPIC" ]] && pass "No ANTHROPIC_API_KEY in runtime files" || fail "ANTHROPIC_API_KEY found in runtime files"

echo "  7c. No Claude model references in runtime files..."
CLAUDE_MODEL=$(grep -rn "claude-opus\|claude-sonnet\|claude-haiku" "$REPO_DIR/skills" "$REPO_DIR/agents" "$REPO_DIR/scripts" "$REPO_DIR/mcp-servers" --include="*.md" --include="*.toml" --include="*.py" 2>/dev/null | grep -v "managed-agent-cookbooks" || true)
[[ -z "$CLAUDE_MODEL" ]] && pass "No Claude model references in runtime files" || fail "Claude model references found in runtime files"

echo "  7d. .gitignore covers unnecessary files..."
GITIGNORE="$REPO_DIR/.gitignore"
[[ -f "$GITIGNORE" ]] && pass ".gitignore exists" || fail ".gitignore missing"
for pat in ".venv/" "__pycache__/" "*.py[cod]"; do
  grep -Fq "$pat" "$GITIGNORE" 2>/dev/null && pass ".gitignore: $pat" || fail ".gitignore: missing $pat"
done

# ============================================================
header "8. Cookbook Content Annotation"
# ============================================================

echo "  8a. managed-agent-cookbooks banner present..."
grep -q "opencode 适配说明" "$REPO_DIR/managed-agent-cookbooks/README.md" \
  && pass "Cookbook README has opencode adaptation banner" \
  || fail "Cookbook README missing opencode banner"

echo "  8b. All cookbooks have opencode agent reference..."
for cookbook in china-pitch-agent china-market-researcher china-earnings-reviewer china-model-builder; do
  grep -q "opencode 可加载版本" "$REPO_DIR/managed-agent-cookbooks/$cookbook/README.md" \
    && pass "$cookbook: has opencode reference" \
    || fail "$cookbook: missing opencode reference"
done

echo "  8c. All cookbooks have steering-examples.json..."
for cookbook in china-pitch-agent china-market-researcher china-earnings-reviewer china-model-builder; do
  [[ -f "$REPO_DIR/managed-agent-cookbooks/$cookbook/steering-examples.json" ]] \
    && pass "$cookbook: steering-examples.json" \
    || fail "$cookbook: missing steering-examples.json"
done

# ============================================================
header "9. README Integrity"
# ============================================================

echo "  9a. Key sections present..."
for section in "快速开始" "Skills 一览" "Agents" "数据源架构" "与原版的关系" "License"; do
  grep -q "## $section" "$REPO_DIR/README.md" \
    && pass "README: ## $section" \
    || fail "README: missing ## $section"
done

echo "  9b. Project description mentions opencode adaptation..."
grep -q "opencode" "$REPO_DIR/README.md" && pass "README mentions opencode" || fail "README doesn't mention opencode"
grep -q "Apache 2.0" "$REPO_DIR/README.md" && pass "README mentions Apache 2.0" || fail "README doesn't mention license"

echo "  9c. MCP server tiers documented..."
grep -q "Tier-0\|Tier-1\|Tier-2\|Tier-3" "$REPO_DIR/README.md" \
  && pass "README documents data source tiers" \
  || fail "README missing data source tier documentation"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo -e "  ${GREEN}Passed: $PASS${NC}  ${RED}Failed: $FAIL${NC}  ${YELLOW}Skipped: $SKIP${NC}"
echo "=========================================="

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}Some tests failed. Review details above.${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
