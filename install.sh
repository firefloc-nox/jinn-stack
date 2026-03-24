#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Full Installation Script
# Installs: Jinn Gateway, Mem0, MCP Memory Service, MemViz
# Targets: macOS (arm64/x64) and Linux (x64)
# Idempotent: safe to re-run at any time
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Paths (configurable via env) ──
JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
JINN_CLI_DIR="${JINN_CLI_DIR:-$HOME/dev/jinn-cli}"
MEM0_HOME="${MEM0_HOME:-$HOME/.mem0}"
MEM0_VENV="${MEM0_HOME}/venv"
MEMVIZ_DIR="${MEMVIZ_DIR:-$HOME/.openclaw/workspace/memviz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ──
info()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!!]${NC} $1"; }
err()     { echo -e "${RED}[err]${NC} $1"; }
fatal()   { err "$1"; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}"; }
step()    { echo -e "  ${CYAN}->  ${NC}$1"; }

# ── Banner ──
echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Jinn Stack — Installer          ║"
echo "  ║  Gateway + Mem0 + MCP Memory + MemViz ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ═══════════════════════════════════════════════════════════════
# STEP 0 — Prerequisites
# ═══════════════════════════════════════════════════════════════
section "Checking prerequisites"

check_cmd() {
  if command -v "$1" &>/dev/null; then
    info "$1 found: $(command -v "$1")"
    return 0
  else
    err "$1 not found"
    return 1
  fi
}

check_version() {
  local cmd="$1" min="$2" actual="$3"
  local sorted
  sorted=$(printf '%s\n%s' "$min" "$actual" | sort -V | head -1)
  if [ "$sorted" = "$min" ]; then
    info "$cmd $actual (>= $min)"
    return 0
  else
    err "$cmd $actual is below minimum $min"
    return 1
  fi
}

PREREQS_OK=true

# Git
check_cmd git || PREREQS_OK=false

# Node >= 20
if check_cmd node; then
  NODE_VER=$(node -v | sed 's/^v//')
  check_version "node" "20.0.0" "$NODE_VER" || PREREQS_OK=false
else
  PREREQS_OK=false
fi

# pnpm
check_cmd pnpm || PREREQS_OK=false

# Python >= 3.11
if check_cmd python3; then
  PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
  check_version "python3" "3.11.0" "$PY_VER" || PREREQS_OK=false
else
  PREREQS_OK=false
fi

# npm (for MemViz)
check_cmd npm || PREREQS_OK=false

if [ "$PREREQS_OK" = false ]; then
  fatal "Missing prerequisites. Install them and re-run."
fi

# ═══════════════════════════════════════════════════════════════
# STEP 1 — Create directories
# ═══════════════════════════════════════════════════════════════
section "Creating directory structure"

for dir in \
  "$JINN_HOME" \
  "$JINN_HOME/org" \
  "$JINN_HOME/knowledge" \
  "$JINN_HOME/sessions" \
  "$JINN_HOME/logs" \
  "$JINN_HOME/logs/archive" \
  "$JINN_HOME/tmp" \
  "$JINN_HOME/data" \
  "$JINN_HOME/com" \
  "$JINN_HOME/models" \
  "$JINN_HOME/cron" \
  "$JINN_HOME/cron/runs" \
  "$JINN_HOME/plugins" \
  "$JINN_HOME/docs" \
  "$JINN_HOME/skills" \
  "$JINN_HOME/scripts" \
  "$JINN_HOME/remote" \
  "$JINN_HOME/remote/skills" \
  "$MEM0_HOME" \
; do
  mkdir -p "$dir"
done
info "Directory structure created"

# ═══════════════════════════════════════════════════════════════
# STEP 2 — Clone & build Jinn Gateway
# ═══════════════════════════════════════════════════════════════
section "Jinn Gateway"

if [ -d "$JINN_CLI_DIR/.git" ]; then
  step "Repo already cloned at $JINN_CLI_DIR — pulling latest"
  git -C "$JINN_CLI_DIR" fetch origin custom-v2
  git -C "$JINN_CLI_DIR" checkout custom-v2
  git -C "$JINN_CLI_DIR" pull origin custom-v2
else
  step "Cloning jinn (branch custom-v2)..."
  mkdir -p "$(dirname "$JINN_CLI_DIR")"
  git clone -b custom-v2 https://github.com/firefloc-nox/jinn.git "$JINN_CLI_DIR"
fi
info "Jinn repo ready at $JINN_CLI_DIR"

step "Installing dependencies (pnpm)..."
(cd "$JINN_CLI_DIR" && pnpm install --frozen-lockfile 2>/dev/null || pnpm install)
info "Dependencies installed"

step "Building (pnpm turbo build)..."
(cd "$JINN_CLI_DIR" && pnpm turbo build)
info "Jinn Gateway built"

# ═══════════════════════════════════════════════════════════════
# STEP 3 — Setup Mem0 + MCP Memory Service
# ═══════════════════════════════════════════════════════════════
section "Mem0 & MCP Memory Service"

if [ -d "$MEM0_VENV" ]; then
  step "Venv already exists at $MEM0_VENV — upgrading packages"
else
  step "Creating Python venv..."
  python3 -m venv "$MEM0_VENV"
  info "Venv created"
fi

step "Installing mem0ai + mcp-memory-service..."
"$MEM0_VENV/bin/pip" install --upgrade pip -q
"$MEM0_VENV/bin/pip" install --upgrade mem0ai mcp-memory-service -q
info "Mem0 packages installed"

# Generate config
if [ ! -f "$MEM0_HOME/config.json" ]; then
  step "Generating config.json template..."
  sed "s|MEM0_DB_PATH|$MEM0_HOME/memory.db|g" \
    "$SCRIPT_DIR/templates/config.mem0.json" > "$MEM0_HOME/config.json"
  info "Config written to $MEM0_HOME/config.json"
  warn "Edit $MEM0_HOME/config.json to set your OPENAI_API_KEY"
else
  info "Config already exists — skipping"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4 — Clone MemViz
# ═══════════════════════════════════════════════════════════════
section "MemViz"

if [ -d "$MEMVIZ_DIR/.git" ]; then
  step "Repo already cloned at $MEMVIZ_DIR — pulling latest"
  git -C "$MEMVIZ_DIR" pull
else
  step "Cloning memviz..."
  mkdir -p "$(dirname "$MEMVIZ_DIR")"
  git clone https://github.com/pfillion42/memviz "$MEMVIZ_DIR"
fi
info "MemViz repo ready"

step "Installing dependencies (npm)..."
(cd "$MEMVIZ_DIR" && npm install)
info "MemViz dependencies installed"

# ═══════════════════════════════════════════════════════════════
# STEP 5 — Scaffold ~/.jinn/
# ═══════════════════════════════════════════════════════════════
section "Scaffolding $JINN_HOME"

# Docs — always overwrite (reference docs)
step "Installing docs..."
cp -r "$SCRIPT_DIR/scaffold/docs/"*.md "$JINN_HOME/docs/"
info "8 docs installed"

# Skills — copy if not present (don't overwrite user customizations)
step "Installing skills..."
SKILLS_INSTALLED=0
for skill_dir in "$SCRIPT_DIR/scaffold/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$JINN_HOME/skills/$skill_name"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
    cp "$skill_dir"SKILL.md "$target/SKILL.md"
    SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
  fi
done
info "$SKILLS_INSTALLED new skills installed (existing preserved)"

# Scripts
step "Installing scripts..."
cp "$SCRIPT_DIR/scaffold/scripts/"*.sh "$JINN_HOME/scripts/"
chmod +x "$JINN_HOME/scripts/"*.sh
info "Scripts installed"

# Plugins
step "Installing plugins..."
cp "$SCRIPT_DIR/templates/mem0-bridge.js" "$JINN_HOME/plugins/mem0-bridge.js"
info "mem0-bridge.js installed"

# Remote kit
step "Installing remote kit..."
cp -r "$SCRIPT_DIR/scaffold/remote/"* "$JINN_HOME/remote/"
info "Remote kit installed"

# CLAUDE.md & AGENTS.md — only if missing
for mdfile in CLAUDE.md AGENTS.md; do
  if [ ! -f "$JINN_HOME/$mdfile" ]; then
    cp "$SCRIPT_DIR/scaffold/$mdfile" "$JINN_HOME/$mdfile"
    info "$mdfile installed"
  else
    info "$mdfile already exists — preserved"
  fi
done

# Config — only if missing
if [ ! -f "$JINN_HOME/config.yaml" ]; then
  step "Generating config.yaml template..."
  sed \
    -e "s|MEM0_VENV_PYTHON|$MEM0_VENV/bin/python3|g" \
    -e "s|MCP_MEMORY_DB_PATH|$(if [ "$(uname)" = "Darwin" ]; then echo "$HOME/Library/Application Support/mcp-memory/sqlite_vec.db"; else echo "$HOME/.local/share/mcp-memory/sqlite_vec.db"; fi)|g" \
    -e "s|OPERATOR_NAME|$(whoami)|g" \
    "$SCRIPT_DIR/templates/config.yaml" > "$JINN_HOME/config.yaml"
  info "config.yaml generated"
  warn "Edit $JINN_HOME/config.yaml to configure engines, connectors, and portal"
else
  info "config.yaml already exists — preserved"
fi

# Cron — only if missing
if [ ! -f "$JINN_HOME/cron/jobs.json" ]; then
  cp "$SCRIPT_DIR/templates/cron-jobs.json" "$JINN_HOME/cron/jobs.json"
  info "cron/jobs.json initialized (empty)"
else
  info "cron/jobs.json already exists — preserved"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 6 — Install start.sh / stop.sh
# ═══════════════════════════════════════════════════════════════
section "Service scripts"

cp "$SCRIPT_DIR/start.sh" "$JINN_HOME/start.sh"
cp "$SCRIPT_DIR/stop.sh" "$JINN_HOME/stop.sh"
chmod +x "$JINN_HOME/start.sh" "$JINN_HOME/stop.sh"
info "start.sh and stop.sh installed in $JINN_HOME/"

# ═══════════════════════════════════════════════════════════════
# STEP 7 — Symlinks for Claude Code / Agents
# ═══════════════════════════════════════════════════════════════
section "Engine skill symlinks"

# Claude Code skills
CLAUDE_SKILLS="$HOME/.claude/skills"
mkdir -p "$CLAUDE_SKILLS"
for skill_dir in "$JINN_HOME/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link="$CLAUDE_SKILLS/$skill_name"
  if [ ! -L "$link" ] && [ ! -d "$link" ]; then
    ln -s "$skill_dir" "$link"
  fi
done
info "Claude Code skill symlinks updated"

# Agents skills (.agents/skills/)
AGENTS_SKILLS="$HOME/.agents/skills"
mkdir -p "$AGENTS_SKILLS"
for skill_dir in "$JINN_HOME/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link="$AGENTS_SKILLS/$skill_name"
  if [ ! -L "$link" ] && [ ! -d "$link" ]; then
    ln -s "$skill_dir" "$link"
  fi
done
info "Agents skill symlinks updated"

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo ""
echo "  Installed components:"
echo "    Jinn Gateway   $JINN_CLI_DIR (branch: custom-v2)"
echo "    Mem0 + MCP     $MEM0_VENV"
echo "    MemViz         $MEMVIZ_DIR"
echo "    Config         $JINN_HOME/"
echo ""
echo "  Next steps:"
echo "    1. Edit $JINN_HOME/config.yaml (connectors, portal name)"
echo "    2. Edit $MEM0_HOME/config.json (API key)"
echo "    3. Start services: $JINN_HOME/start.sh"
echo "    4. Open http://localhost:7778 for the gateway"
echo ""
