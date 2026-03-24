#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Uninstall Script
# Backs up all user data, then removes the stack
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Paths ──
JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
JINN_CLI_DIR="${JINN_CLI_DIR:-$HOME/dev/jinn-cli}"
MEM0_HOME="${MEM0_HOME:-$HOME/.mem0}"
MEMVIZ_DIR="${MEMVIZ_DIR:-$HOME/.openclaw/workspace/memviz}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/jinn-backup-$(date +%Y%m%d-%H%M%S)}"

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
section() { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}"; }
step()    { echo -e "  ${CYAN}->  ${NC}$1"; }

echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Jinn Stack — Uninstall          ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}This will remove the Jinn stack from your system.${NC}"
echo "User data will be backed up to: $BACKUP_ROOT"
echo ""
read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# ═══════════════════════════════════════════════════════════════
# STEP 1 — Stop services
# ═══════════════════════════════════════════════════════════════
section "Stopping services"

if [ -f "$JINN_HOME/stop.sh" ]; then
  bash "$JINN_HOME/stop.sh" 2>/dev/null || true
  info "Services stopped"
else
  # Manual kill by PID files
  for pidfile in "$JINN_HOME/tmp/"*.pid; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile")
    kill "$pid" 2>/dev/null || true
    rm -f "$pidfile"
  done
  info "Processes cleaned up"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2 — Backup user data
# ═══════════════════════════════════════════════════════════════
section "Backing up user data"

mkdir -p "$BACKUP_ROOT"

# --- Jinn user data ---
JINN_BACKUP="$BACKUP_ROOT/jinn"
mkdir -p "$JINN_BACKUP"

for item in config.yaml org knowledge cron sessions CLAUDE.md AGENTS.md instances.json; do
  src="$JINN_HOME/$item"
  if [ -e "$src" ]; then
    cp -r "$src" "$JINN_BACKUP/"
    step "Backed up $item"
  fi
done

# Custom skills (user-created, not from scaffold)
if [ -d "$JINN_HOME/skills" ]; then
  mkdir -p "$JINN_BACKUP/skills"
  cp -r "$JINN_HOME/skills/"* "$JINN_BACKUP/skills/" 2>/dev/null || true
  step "Backed up skills/"
fi

info "Jinn data backed up"

# --- Mem0 data ---
MEM0_BACKUP="$BACKUP_ROOT/mem0"
mkdir -p "$MEM0_BACKUP"

for item in config.json memory.db; do
  src="$MEM0_HOME/$item"
  if [ -f "$src" ]; then
    cp "$src" "$MEM0_BACKUP/"
    step "Backed up mem0/$item"
  fi
done

# MCP memory DB
if [ "$(uname)" = "Darwin" ]; then
  MCP_DB="$HOME/Library/Application Support/mcp-memory/sqlite_vec.db"
else
  MCP_DB="$HOME/.local/share/mcp-memory/sqlite_vec.db"
fi
if [ -f "$MCP_DB" ]; then
  cp "$MCP_DB" "$MEM0_BACKUP/sqlite_vec.db"
  step "Backed up MCP memory DB"
fi

info "Mem0 data backed up"

# --- Summary ---
BACKUP_SIZE=$(du -sh "$BACKUP_ROOT" | cut -f1)
info "Total backup: $BACKUP_SIZE at $BACKUP_ROOT"

# ═══════════════════════════════════════════════════════════════
# STEP 3 — Remove components
# ═══════════════════════════════════════════════════════════════
section "Removing components"

echo ""
echo "The following directories will be removed:"
echo "  - $JINN_HOME (Jinn config & data)"
echo "  - $JINN_CLI_DIR (Jinn source code)"
echo "  - $MEM0_HOME (Mem0 venv & data)"
echo "  - $MEMVIZ_DIR (MemViz)"
echo ""
read -rp "Confirm removal? [y/N] " confirm2
if [[ ! "$confirm2" =~ ^[Yy]$ ]]; then
  echo "Removal cancelled. Backup remains at $BACKUP_ROOT"
  exit 0
fi

# Remove skill symlinks
step "Removing skill symlinks..."
for skills_root in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  if [ -d "$skills_root" ]; then
    for link in "$skills_root"/*/; do
      [ -L "${link%/}" ] && target=$(readlink "${link%/}") && [[ "$target" == "$JINN_HOME"* ]] && rm -f "${link%/}"
    done
  fi
done
info "Symlinks removed"

# Remove Jinn home
step "Removing $JINN_HOME..."
rm -rf "$JINN_HOME"
info "Jinn home removed"

# Remove Jinn source
step "Removing $JINN_CLI_DIR..."
rm -rf "$JINN_CLI_DIR"
info "Jinn source removed"

# Remove Mem0
step "Removing $MEM0_HOME..."
rm -rf "$MEM0_HOME"
info "Mem0 removed"

# Remove MemViz
step "Removing $MEMVIZ_DIR..."
rm -rf "$MEMVIZ_DIR"
info "MemViz removed"

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}  Uninstall complete.${NC}"
echo ""
echo "  Your data is safe at:"
echo "    $BACKUP_ROOT"
echo ""
echo "  To restore later, copy the backup files back:"
echo "    cp -r $BACKUP_ROOT/jinn/config.yaml ~/.jinn/"
echo "    cp -r $BACKUP_ROOT/jinn/org ~/.jinn/"
echo "    cp -r $BACKUP_ROOT/jinn/knowledge ~/.jinn/"
echo "    cp -r $BACKUP_ROOT/jinn/sessions ~/.jinn/"
echo "    cp $BACKUP_ROOT/mem0/config.json ~/.mem0/"
echo "    cp $BACKUP_ROOT/mem0/memory.db ~/.mem0/"
echo ""
