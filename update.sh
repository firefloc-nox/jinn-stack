#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Update Script
# Pulls latest code, rebuilds, and refreshes scaffold files
# User data (org, knowledge, sessions, config, cron) is preserved
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Paths ──
JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
JINN_CLI_DIR="${JINN_CLI_DIR:-$JINN_HOME/src/jinn-cli}"
MEM0_HOME="${MEM0_HOME:-$JINN_HOME/src/mem0}"
MEM0_VENV="${MEM0_HOME}/venv"
MEMVIZ_DIR="${MEMVIZ_DIR:-$JINN_HOME/src/memviz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$JINN_HOME/backups/update-$(date +%Y%m%d-%H%M%S)"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!!]${NC} $1"; }
err()     { echo -e "${RED}[err]${NC} $1"; }
fatal()   { err "$1"; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}"; }
step()    { echo -e "  ${CYAN}->  ${NC}$1"; }

echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Jinn Stack — Update             ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ═══════════════════════════════════════════════════════════════
# STEP 0 — Pre-flight checks
# ═══════════════════════════════════════════════════════════════
section "Pre-flight checks"

[ -d "$JINN_HOME" ]    || fatal "$JINN_HOME not found — run install.sh first"
[ -d "$JINN_CLI_DIR" ] || fatal "$JINN_CLI_DIR not found — run install.sh first"

# Stop services if running
if [ -f "$JINN_HOME/stop.sh" ]; then
  step "Stopping services..."
  bash "$JINN_HOME/stop.sh" 2>/dev/null || true
  info "Services stopped"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 1 — Backup user data
# ═══════════════════════════════════════════════════════════════
section "Backing up user data"

mkdir -p "$BACKUP_DIR"

# Backup user-specific files that won't be touched
for item in config.yaml org knowledge cron/jobs.json sessions CLAUDE.md AGENTS.md; do
  src="$JINN_HOME/$item"
  if [ -e "$src" ]; then
    dest="$BACKUP_DIR/$item"
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
  fi
done

info "Backed up to $BACKUP_DIR"

# ═══════════════════════════════════════════════════════════════
# STEP 2 — Update Jinn Gateway
# ═══════════════════════════════════════════════════════════════
section "Updating Jinn Gateway"

step "Pulling latest from custom-v2..."
git -C "$JINN_CLI_DIR" fetch origin custom-v2
git -C "$JINN_CLI_DIR" checkout custom-v2
git -C "$JINN_CLI_DIR" pull origin custom-v2
info "Jinn repo updated"

step "Installing dependencies..."
(cd "$JINN_CLI_DIR" && pnpm install --frozen-lockfile 2>/dev/null || pnpm install)
info "Dependencies installed"

step "Building WebUI..."
(cd "$JINN_CLI_DIR" && pnpm --filter @jinn/web build)
step "Building Gateway..."
(cd "$JINN_CLI_DIR" && pnpm --filter jinn-cli build)
if [ ! -f "$JINN_CLI_DIR/packages/jimmy/dist/web/index.html" ]; then
  mkdir -p "$JINN_CLI_DIR/packages/jimmy/dist/web"
  cp -r "$JINN_CLI_DIR/packages/web/out/"* "$JINN_CLI_DIR/packages/jimmy/dist/web/"
fi
info "Jinn Gateway rebuilt"

# ═══════════════════════════════════════════════════════════════
# STEP 3 — Update Mem0 + MCP Memory Service
# ═══════════════════════════════════════════════════════════════
section "Updating Mem0 & MCP Memory Service"

if [ -d "$MEM0_VENV" ]; then
  step "Upgrading packages..."
  "$MEM0_VENV/bin/pip" install --upgrade mem0ai mcp-memory-service -q
  info "Mem0 packages upgraded"
else
  warn "Venv not found at $MEM0_VENV — skipping (run install.sh to set up)"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4 — Update MemViz
# ═══════════════════════════════════════════════════════════════
section "Updating MemViz"

if [ -d "$MEMVIZ_DIR/.git" ]; then
  step "Pulling latest..."
  git -C "$MEMVIZ_DIR" pull
  (cd "$MEMVIZ_DIR/server" && npm install && npm run build)
  (cd "$MEMVIZ_DIR/client" && npm install && npx vite build)
  # Re-apply vite config patch for correct ports and proxy
  cat > "$MEMVIZ_DIR/client/vite.config.ts" << 'VITECONF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const BACKEND_PORT = process.env.MEMVIZ_BACKEND_PORT || '3001';
const FRONTEND_PORT = process.env.MEMVIZ_FRONTEND_PORT || '8888';
const proxyConfig = {
  '/api': {
    target: `http://127.0.0.1:${BACKEND_PORT}`,
    changeOrigin: true,
  },
};

export default defineConfig({
  plugins: [react()],
  server: {
    port: Number(FRONTEND_PORT),
    host: '0.0.0.0',
    proxy: proxyConfig,
  },
  preview: {
    port: Number(FRONTEND_PORT),
    host: '0.0.0.0',
    proxy: proxyConfig,
  },
  test: {
    globals: true,
    environment: 'jsdom',
  },
});
VITECONF
  # Rebuild client with patched config
  (cd "$MEMVIZ_DIR/client" && npm run build)
  info "MemViz updated"
else
  warn "MemViz not found at $MEMVIZ_DIR — skipping"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 5 — Refresh scaffold (non-user files only)
# ═══════════════════════════════════════════════════════════════
section "Refreshing scaffold files"

# Docs — always overwrite (reference docs)
step "Updating docs..."
cp -r "$SCRIPT_DIR/scaffold/docs/"*.md "$JINN_HOME/docs/"
info "Docs updated"

# Scripts — always overwrite (utility scripts)
step "Updating scripts..."
cp "$SCRIPT_DIR/scaffold/scripts/"*.sh "$JINN_HOME/scripts/"
chmod +x "$JINN_HOME/scripts/"*.sh
info "Scripts updated"

# Skills — add new ones, don't overwrite existing (user may have customized)
step "Checking for new skills..."
SKILLS_NEW=0
for skill_dir in "$SCRIPT_DIR/scaffold/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$JINN_HOME/skills/$skill_name"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
    cp "$skill_dir"SKILL.md "$target/SKILL.md"
    SKILLS_NEW=$((SKILLS_NEW + 1))
    info "New skill: $skill_name"
  fi
done
info "$SKILLS_NEW new skills added (existing preserved)"

# Plugins — overwrite (not user-customized)
step "Updating plugins..."
cp "$SCRIPT_DIR/templates/mem0-bridge.js" "$JINN_HOME/plugins/mem0-bridge.js"
info "Plugins updated"

# Remote kit — overwrite
step "Updating remote kit..."
cp -r "$SCRIPT_DIR/scaffold/remote/"* "$JINN_HOME/remote/"
info "Remote kit updated"

# Service scripts
cp "$SCRIPT_DIR/start.sh" "$JINN_HOME/start.sh"
cp "$SCRIPT_DIR/stop.sh" "$JINN_HOME/stop.sh"
chmod +x "$JINN_HOME/start.sh" "$JINN_HOME/stop.sh"
info "start.sh / stop.sh updated"

# Symlinks
step "Refreshing skill symlinks..."
for skills_root in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  mkdir -p "$skills_root"
  for skill_dir in "$JINN_HOME/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    link="$skills_root/$skill_name"
    if [ ! -L "$link" ] && [ ! -d "$link" ]; then
      ln -s "$skill_dir" "$link"
    fi
  done
done
info "Symlinks refreshed"

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}  Update complete!${NC}"
echo ""
echo "  Backup: $BACKUP_DIR"
echo ""
echo "  Preserved (not touched):"
echo "    config.yaml, org/, knowledge/, sessions/, cron/jobs.json"
echo "    CLAUDE.md, AGENTS.md"
echo ""
echo "  Updated:"
echo "    Jinn Gateway, Mem0, MCP Memory, MemViz"
echo "    docs/, scripts/, plugins/, remote/, start.sh, stop.sh"
echo ""
echo "  Restart: $JINN_HOME/start.sh"
echo ""
