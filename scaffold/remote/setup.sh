#!/usr/bin/env bash
# Jinn Remote Kit — Installation script
# Connects local Claude Code to the shared Jinn infrastructure via Tailnet
# Repo: https://github.com/firefloc-nox/jinn-v3.git (branch: custom-v3)
#
# Usage: bash setup.sh [--project /path/to/project]

set -euo pipefail

JINN_GATEWAY="${JINN_GATEWAY_URL:-JINN_GATEWAY_URL}"
JINN_MEMORY="${JINN_MEMORY_URL:-JINN_MEMORY_URL}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# --- Pre-checks ---
echo "=== Jinn Remote Kit — Installation ==="
echo ""

# Check Tailscale
if ! command -v tailscale &>/dev/null; then
  error "Tailscale n'est pas installé. Installe-le d'abord: https://tailscale.com/download"
fi

if ! tailscale status &>/dev/null; then
  error "Tailscale n'est pas connecté. Lance: tailscale up"
fi

# Check connectivity to gateway
echo "Vérification de la connectivité vers le gateway..."
if curl -sf --connect-timeout 5 "$JINN_GATEWAY/api/status" &>/dev/null; then
  info "Gateway Jinn accessible"
else
  warn "Gateway Jinn injoignable sur $JINN_GATEWAY — vérifie que le serveur est allumé"
fi

# --- Step 1: Install MCP config ---
echo ""
echo "--- Configuration MCP ---"
CLAUDE_DIR="$HOME/.claude"
MCP_FILE="$CLAUDE_DIR/.mcp.json"

mkdir -p "$CLAUDE_DIR"

if [ -f "$MCP_FILE" ]; then
  warn "$MCP_FILE existe déjà. Sauvegarde dans $MCP_FILE.bak"
  cp "$MCP_FILE" "$MCP_FILE.bak"
  # Merge jinn-memory into existing config
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$MCP_FILE') as f: config = json.load(f)
config.setdefault('mcpServers', {})['jinn-memory'] = {'type': 'streamable-http', 'url': '$JINN_MEMORY'}
with open('$MCP_FILE', 'w') as f: json.dump(config, f, indent=2)
print('Merged jinn-memory into existing config')
"
  else
    warn "python3 indisponible — écrasement du fichier"
    cp "$SCRIPT_DIR/mcp.json" "$MCP_FILE"
  fi
else
  cp "$SCRIPT_DIR/mcp.json" "$MCP_FILE"
fi
info "MCP config installée: $MCP_FILE"

# --- Step 2: Install skills ---
echo ""
echo "--- Skills ---"
SKILLS_DIR="$CLAUDE_DIR/skills"
mkdir -p "$SKILLS_DIR"

for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"
  if [ -L "$target" ] || [ -d "$target" ]; then
    warn "Skill $skill_name existe déjà — skip"
  else
    ln -s "$skill_dir" "$target"
    info "Skill installé: $skill_name → $target"
  fi
done

# --- Step 3: Project-level CLAUDE.md (optional) ---
PROJECT_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -n "$PROJECT_DIR" ]; then
  echo ""
  echo "--- Configuration projet ---"
  if [ -d "$PROJECT_DIR" ]; then
    DEST="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$DEST" ]; then
      warn "$DEST existe déjà — ajout des instructions Jinn à la fin"
      echo "" >> "$DEST"
      echo "# --- Jinn Remote Integration ---" >> "$DEST"
      cat "$SCRIPT_DIR/CLAUDE.md" >> "$DEST"
    else
      cp "$SCRIPT_DIR/CLAUDE.md" "$DEST"
    fi
    info "CLAUDE.md installé dans $PROJECT_DIR"
  else
    warn "Dossier $PROJECT_DIR introuvable — skip"
  fi
fi

# --- Done ---
echo ""
echo "=== Installation terminée ==="
echo ""
echo "Prochaines étapes:"
echo "  1. Relance Claude Code dans VSCode"
echo "  2. Vérifie le MCP: tape /mcp dans Claude Code"
echo "  3. Pour ajouter Jinn à un projet: bash setup.sh --project /chemin/vers/projet"
echo ""
echo "Services disponibles:"
echo "  - Mémoire partagée: $JINN_MEMORY"
echo "  - Gateway API:      $JINN_GATEWAY/api/"
echo ""
