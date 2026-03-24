#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Start all services
# Services: Jinn Gateway, MCP Memory Service, MemViz
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Paths ──
JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
JINN_CLI_DIR="${JINN_CLI_DIR:-$JINN_HOME/src/jinn-cli}"
MEM0_HOME="${MEM0_HOME:-$JINN_HOME/src/mem0}"
MEM0_VENV="${MEM0_HOME}/venv"
MEMVIZ_DIR="${MEMVIZ_DIR:-$JINN_HOME/src/memviz}"
PID_DIR="${JINN_HOME}/tmp"
LOG_DIR="${JINN_HOME}/logs"

# ── Ports ──
GATEWAY_PORT="${GATEWAY_PORT:-7778}"
MCP_MEMORY_PORT="${MCP_MEMORY_PORT:-8200}"
MEMVIZ_BACKEND_PORT="${MEMVIZ_BACKEND_PORT:-3001}"
MEMVIZ_FRONTEND_PORT="${MEMVIZ_FRONTEND_PORT:-8888}"

# ── Colors ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
err()   { echo -e "${RED}[err]${NC} $1"; }

mkdir -p "$PID_DIR" "$LOG_DIR"

# ── Kill residual stack processes & free ports ──
echo -e "${BOLD}Cleaning up residual processes...${NC}"
STACK_PORTS=("$GATEWAY_PORT" "$MCP_MEMORY_PORT" "$MEMVIZ_BACKEND_PORT" "$MEMVIZ_FRONTEND_PORT")
STACK_PATTERNS=("jimmy" "mcp.memory" "mcp-memory-service" "memviz" "supergateway")

for port in "${STACK_PORTS[@]}"; do
  if command -v lsof &>/dev/null; then
    pids=$(lsof -ti :"$port" -sTCP:LISTEN 2>/dev/null || true)
  elif command -v ss &>/dev/null; then
    pids=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' || true)
  else
    pids=""
  fi
  for pid in $pids; do
    warn "Killing process $pid on port $port"
    kill "$pid" 2>/dev/null || true
  done
done

for pattern in "${STACK_PATTERNS[@]}"; do
  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  for pid in $pids; do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null || true
  done
done

sleep 1

# Force-kill stragglers
for port in "${STACK_PORTS[@]}"; do
  if command -v lsof &>/dev/null; then
    pids=$(lsof -ti :"$port" -sTCP:LISTEN 2>/dev/null || true)
    for pid in $pids; do
      kill -9 "$pid" 2>/dev/null || true
    done
  fi
done

# Clean stale PID files
for pidfile in "$PID_DIR"/*.pid; do
  [ -f "$pidfile" ] || continue
  pid=$(cat "$pidfile")
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$pidfile"
  fi
done

info "Ports cleared"

is_port_used() {
  if command -v lsof &>/dev/null; then
    lsof -ti :"$1" -sTCP:LISTEN &>/dev/null
  elif command -v ss &>/dev/null; then
    ss -tlnp | grep -q ":$1 "
  else
    # Fallback: try to bind the port
    (echo >/dev/tcp/127.0.0.1/"$1") 2>/dev/null
  fi
}

start_service() {
  local name="$1" port="$2" pidfile="$3" cmd="$4" logfile="$5"

  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    warn "$name already running (PID $(cat "$pidfile"))"
    return 0
  fi

  if is_port_used "$port"; then
    warn "$name: port $port already in use"
    return 1
  fi

  eval "$cmd" >> "$logfile" 2>&1 &
  local pid=$!
  echo "$pid" > "$pidfile"

  # Wait briefly and verify it started
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    info "$name started (PID $pid, port $port)"
  else
    err "$name failed to start — check $logfile"
    rm -f "$pidfile"
    return 1
  fi
}

echo -e "${BOLD}Starting Jinn Stack...${NC}"
echo ""

# 1. Jinn Gateway
start_service \
  "Jinn Gateway" \
  "$GATEWAY_PORT" \
  "$PID_DIR/gateway.pid" \
  "cd '$JINN_CLI_DIR' && node packages/jimmy/dist/bin/jimmy.js start" \
  "$LOG_DIR/gateway-stdout.log"

# 2. MCP Memory Service (via supergateway)
# Default DB path: macOS uses ~/Library/Application Support, Linux uses ~/.local/share
if [ "$(uname)" = "Darwin" ]; then
  _DEFAULT_MCP_DB="$HOME/Library/Application Support/mcp-memory/sqlite_vec.db"
else
  _DEFAULT_MCP_DB="$HOME/.local/share/mcp-memory/sqlite_vec.db"
fi
MCP_MEMORY_DB="${MCP_MEMORY_DB:-$_DEFAULT_MCP_DB}"
mkdir -p "$(dirname "$MCP_MEMORY_DB")"
start_service \
  "MCP Memory" \
  "$MCP_MEMORY_PORT" \
  "$PID_DIR/mcp-memory.pid" \
  "npx -y supergateway --stdio '${MEM0_VENV}/bin/python3 -m mcp_memory_service.server --db \"${MCP_MEMORY_DB}\"' --port $MCP_MEMORY_PORT --outputTransport streamableHttp" \
  "$LOG_DIR/memory-mcp.log"

# 3. MemViz Server (backend)
start_service \
  "MemViz Server" \
  "$MEMVIZ_BACKEND_PORT" \
  "$PID_DIR/memviz-server.pid" \
  "cd '$MEMVIZ_DIR/server' && npm run dev" \
  "$LOG_DIR/memviz-server.log"

# 4. MemViz Client (frontend)
start_service \
  "MemViz Client" \
  "$MEMVIZ_FRONTEND_PORT" \
  "$PID_DIR/memviz-client.pid" \
  "cd '$MEMVIZ_DIR/client' && npm run dev" \
  "$LOG_DIR/memviz-client.log"

echo ""
echo -e "${GREEN}${BOLD}All services started.${NC}"
echo ""
echo "  Gateway:     http://localhost:$GATEWAY_PORT"
echo "  MCP Memory:  http://localhost:$MCP_MEMORY_PORT"
echo "  MemViz:      http://localhost:$MEMVIZ_FRONTEND_PORT"
echo ""
echo "  Stop with: $JINN_HOME/stop.sh"
echo "  Logs in:   $LOG_DIR/"
echo ""
