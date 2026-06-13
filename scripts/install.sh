#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# opencode-for-financial-services-cn — Installer
# ============================================================
# This script installs the MCP server dependencies and optionally
# links skills and agents for opencode.
#
# Usage:
#   ./scripts/install.sh                # Install all MCP deps
#   ./scripts/install.sh --link-skills  # Also link skills into ~/.agents/skills/
#   ./scripts/install.sh --link-agents  # Also link agents into CODEX_HOME/agents/
# ============================================================

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo " opencode-for-financial-services-cn"
echo " Installing MCP server dependencies..."
echo "========================================"

install_mcp_deps() {
  local dir="$1"
  local name="$2"
  echo ""
  echo "--- $name ---"
  if [ -f "$dir/requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip install -r "$dir/requirements.txt" -q
    echo "  OK"
  else
    echo "  No dependencies needed"
  fi
}

# Install MCP server dependencies
install_mcp_deps "$REPO_DIR/mcp-servers/akshare-mcp"    "AkShare MCP (免费)"
install_mcp_deps "$REPO_DIR/mcp-servers/china-news-mcp"  "China News MCP (免费)"
install_mcp_deps "$REPO_DIR/mcp-servers/ifind-mcp"       "iFind MCP (付费)"
install_mcp_deps "$REPO_DIR/mcp-servers/wind-mcp"        "Wind MCP (付费)"

echo ""
echo "========================================"
echo " MCP dependencies installed!"
echo "========================================"
echo ""
echo "Quick start — run a free MCP server:"
echo "  python3 $REPO_DIR/mcp-servers/akshare-mcp/server.py"
echo ""
echo "Or run with SSE transport:"
echo "  python3 $REPO_DIR/mcp-servers/akshare-mcp/server.py --transport sse --port 8000"
echo ""

# --- Link skills into opencode ---
if [ "${1:-}" = "--link-skills" ] || [ "${2:-}" = "--link-skills" ]; then
  echo "--- Linking skills into ~/.agents/skills/ ---"
  mkdir -p "$HOME/.agents/skills"
  for skilldir in "$REPO_DIR/skills/"*/; do
    skillname="$(basename "$skilldir")"
    target="$HOME/.agents/skills/$skillname"
    if [ ! -L "$target" ] && [ ! -d "$target" ]; then
      ln -s "$skilldir" "$target"
      echo "  Linked $skillname"
    else
      echo "  SKIP $skillname (already exists)"
    fi
  done
  echo "  Done."
fi

# --- Link agents into CODEX_HOME ---
if [ "${1:-}" = "--link-agents" ] || [ "${2:-}" = "--link-agents" ]; then
  CODEX_HOME="${CODEX_HOME:-$HOME/.local/share/opencode}"
  echo "--- Linking agents into $CODEX_HOME/agents/ ---"
  mkdir -p "$CODEX_HOME/agents"
  for agentfile in "$REPO_DIR/agents/"*.toml; do
    agentname="$(basename "$agentfile")"
    cp "$agentfile" "$CODEX_HOME/agents/$agentname"
    echo "  Installed $agentname"
  done
  echo "  Done."
fi

echo ""
echo "All set! See README.md for usage details."
