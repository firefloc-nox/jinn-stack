#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Stop all services
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
PID_DIR="${JINN_HOME}/tmp"

# ── Ports ──
GATEWAY_PORT="${GATEWAY_PORT:-7778}"
MCP_MEMORY_PORT="${MCP_MEMORY_PORT:-8200}"
MEMVIZ_BACKEND_PORT="${MEMVIZ_BACKEND_PORT:-3001}"
MEMVIZ_FRONTEND_PORT="${MEMVIZ_FRONTEND_PORT:-8888}"
STACK_PORTS=("$GATEWAY_PORT" "$MCP_MEMORY_PORT" "$MEMVIZ_BACKEND_PORT" "$MEMVIZ_FRONTEND_PORT")

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }

# ── Get PIDs listening on a port (cross-platform) ──
get_port_pids() {
  local port="$1"
  if command -v lsof &>/dev/null; then
    lsof -ti :"$port" -sTCP:LISTEN 2>/dev/null || true
  elif command -v ss &>/dev/null; then
    ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' || true
  fi
}

stop_service() {
  local name="$1" pidfile="$2"

  if [ ! -f "$pidfile" ]; then
    return 0
  fi

  local pid
  pid=$(cat "$pidfile")

  if kill -0 "$pid" 2>/dev/null; then
    # Graceful shutdown first
    kill "$pid" 2>/dev/null
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do
      sleep 1
      waited=$((waited + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
      warn "$name (PID $pid) force-killed"
    else
      info "$name (PID $pid) stopped"
    fi
  fi

  rm -f "$pidfile"
}

echo -e "${BOLD}Stopping Jinn Stack...${NC}"
echo ""

# Phase 1: Stop by PID files (graceful)
stop_service "Jinn Gateway"   "$PID_DIR/gateway.pid"
stop_service "MCP Memory"     "$PID_DIR/mcp-memory.pid"
stop_service "MemViz Server"  "$PID_DIR/memviz-server.pid"
stop_service "MemViz Client"  "$PID_DIR/memviz-client.pid"

# Phase 2: Kill by pattern (catches child processes)
for pattern in jimmy mcp.memory mcp-memory-service memviz supergateway; do
  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  for pid in $pids; do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null || true
  done
done

# Phase 3: Kill anything still on our ports (graceful then force)
for port in "${STACK_PORTS[@]}"; do
  for pid in $(get_port_pids "$port"); do
    warn "Killing process $pid on port $port"
    kill "$pid" 2>/dev/null || true
  done
done

sleep 1

# Phase 4: Force-kill stragglers on ports
for port in "${STACK_PORTS[@]}"; do
  for pid in $(get_port_pids "$port"); do
    warn "Force-killing process $pid on port $port"
    kill -9 "$pid" 2>/dev/null || true
  done
done

# Clean stale PID files
for pidfile in "$PID_DIR"/*.pid; do
  [ -f "$pidfile" ] || continue
  pid=$(cat "$pidfile")
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$pidfile"
  fi
done

echo ""
echo -e "${GREEN}${BOLD}All services stopped.${NC}"
echo ""
