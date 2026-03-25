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
    # Parse robustly: extract pid= values regardless of ss version/locale
    ss -tlnp "sport = :$port" 2>/dev/null \
      | awk 'NR>1 && index($0,"pid=") {
          n = split($0, parts, "pid=")
          for (i=2; i<=n; i++) {
            pid = parts[i]; gsub(/[^0-9].*/, "", pid)
            if (pid ~ /^[0-9]+$/) print pid
          }
        }' || true
  elif command -v fuser &>/dev/null; then
    fuser "${port}/tcp" 2>/dev/null | tr ' ' '\n' | grep -v '^$' || true
  fi
}

# ── Kill a process and all its descendants ──
kill_tree() {
  local pid="$1" sig="${2:-TERM}"
  # Skip self and parent
  [ "$pid" = "$$" ] && return 0
  [ "$pid" = "$PPID" ] && return 0
  # Find children first (depth-first)
  # pgrep -P absent on macOS < 13 — fallback to POSIX ps
  local children
  children=$(pgrep -P "$pid" 2>/dev/null \
    || ps -eo pid=,ppid= 2>/dev/null | awk -v p="$pid" '$2==p{print $1}' \
    || true)
  for child in $children; do
    kill_tree "$child" "$sig"
  done
  kill -"$sig" "$pid" 2>/dev/null || true
}

stop_service() {
  local name="$1" pidfile="$2"

  if [ ! -f "$pidfile" ]; then
    return 0
  fi

  local pid
  pid=$(cat "$pidfile")

  if kill -0 "$pid" 2>/dev/null; then
    # Kill the entire process tree gracefully
    kill_tree "$pid" TERM
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do
      sleep 1
      waited=$((waited + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
      kill_tree "$pid" 9
      warn "$name (PID $pid) force-killed"
    else
      info "$name (PID $pid) stopped"
    fi
  fi

  rm -f "$pidfile"
}

echo -e "${BOLD}Stopping Jinn Stack...${NC}"
echo ""

# Phase 1: Stop by PID files — kill entire process trees
stop_service "Jinn Gateway"   "$PID_DIR/gateway.pid"
stop_service "MCP Memory"     "$PID_DIR/mcp-memory.pid"
stop_service "MemViz Server"  "$PID_DIR/memviz-server.pid"
stop_service "MemViz Client"  "$PID_DIR/memviz-client.pid"

# Phase 2: Kill by specific patterns (catches orphaned children)
# Patterns are specific to avoid matching unrelated processes
for pattern in "jimmy.js start" "mcp-memory-service" "mcp_memory_service" "supergateway.*port" "memviz.*server" "memviz.*vite"; do
  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  for pid in $pids; do
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    kill_tree "$pid" TERM
  done
done

sleep 1

# Phase 3: Force-kill anything still on our ports
for port in "${STACK_PORTS[@]}"; do
  for pid in $(get_port_pids "$port"); do
    warn "Force-killing process $pid on port $port"
    kill_tree "$pid" 9
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
