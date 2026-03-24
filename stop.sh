#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Stop all services
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
PID_DIR="${JINN_HOME}/tmp"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }

stop_service() {
  local name="$1" pidfile="$2"

  if [ ! -f "$pidfile" ]; then
    warn "$name: no PID file found — not running?"
    return 0
  fi

  local pid
  pid=$(cat "$pidfile")

  if kill -0 "$pid" 2>/dev/null; then
    # Graceful shutdown first
    kill "$pid" 2>/dev/null
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 10 ]; do
      sleep 1
      waited=$((waited + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
      warn "$name (PID $pid) force-killed after 10s"
    else
      info "$name (PID $pid) stopped gracefully"
    fi
  else
    info "$name (PID $pid) was not running"
  fi

  rm -f "$pidfile"
}

echo -e "${BOLD}Stopping Jinn Stack...${NC}"
echo ""

stop_service "Jinn Gateway"   "$PID_DIR/gateway.pid"
stop_service "MCP Memory"     "$PID_DIR/mcp-memory.pid"
stop_service "MemViz Server"  "$PID_DIR/memviz-server.pid"
stop_service "MemViz Client"  "$PID_DIR/memviz-client.pid"

echo ""
echo -e "${GREEN}${BOLD}All services stopped.${NC}"
echo ""
