#!/usr/bin/env bash
# Jinn Stack — One-line bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/firefloc-nox/jinn-stack/main/bootstrap.sh | bash
#
# - Fresh install: clones repo, runs install.sh
# - Existing install: pulls latest, stops services, runs update.sh, restarts

set -euo pipefail

# Ensure CWD is valid — piped curl may inherit a deleted/nonexistent directory
cd "$HOME"

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
STACK_DIR="${JINN_STACK_DIR:-$JINN_HOME/src/jinn-stack}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Jinn Stack — Bootstrap          ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ── Detect existing installation ──
_EXISTING=false

if [ -d "$JINN_HOME/src/jinn-cli/.git" ] && [ -f "$JINN_HOME/config.yaml" ]; then
  _EXISTING=true
fi

if [ "$_EXISTING" = true ]; then
  echo -e "${GREEN}Existing Jinn Stack detected at $JINN_HOME${NC}"
  echo ""

  # Get current version
  _VERSION=$(grep 'version:' "$JINN_HOME/config.yaml" 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
  echo "  Current version: $_VERSION"
  echo ""

  # Pull latest jinn-stack scripts
  if [ -d "$STACK_DIR/.git" ]; then
    echo -e "${YELLOW}Pulling latest stack scripts...${NC}"
    git -C "$STACK_DIR" pull origin main --quiet
  else
    echo -e "${YELLOW}Cloning stack scripts...${NC}"
    mkdir -p "$(dirname "$STACK_DIR")"
    git clone --quiet https://github.com/firefloc-nox/jinn-stack.git "$STACK_DIR"
  fi

  # Stop running services gracefully
  if [ -f "$STACK_DIR/stop.sh" ]; then
    echo ""
    echo -e "${YELLOW}Stopping running services...${NC}"
    bash "$STACK_DIR/stop.sh" 2>/dev/null || true
  fi

  # Run update
  echo ""
  echo -e "${GREEN}Running update...${NC}"
  echo ""
  bash "$STACK_DIR/update.sh"

  # Restart services
  echo ""
  echo -e "${GREEN}Restarting services...${NC}"
  echo ""
  bash "$STACK_DIR/start.sh"

  echo ""
  echo -e "${GREEN}${BOLD}Update complete!${NC}"
  echo ""
  echo "  Open the Web UI:"
  echo ""
  echo "    http://localhost:${GATEWAY_PORT:-7778}"
  echo ""

else
  echo -e "${YELLOW}No existing installation found — fresh install${NC}"
  echo ""

  # Clone jinn-stack
  if [ -d "$STACK_DIR/.git" ]; then
    echo "Updating stack scripts at $STACK_DIR..."
    git -C "$STACK_DIR" pull origin main --quiet
  else
    echo "Cloning jinn-stack to $STACK_DIR..."
    mkdir -p "$(dirname "$STACK_DIR")"
    git clone --quiet https://github.com/firefloc-nox/jinn-stack.git "$STACK_DIR"
  fi

  echo ""
  echo "Running installer..."
  echo ""
  bash "$STACK_DIR/install.sh"
fi
