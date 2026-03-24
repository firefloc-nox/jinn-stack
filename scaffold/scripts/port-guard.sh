#!/usr/bin/env bash
# Port Guard — enforce strict static port ownership + crash loop detection
# Runs every 30s via launchd.

set -euo pipefail

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"

# --- TCP services (port-based check) ---
declare -A PORT_OWNER=(
  [7778]="com.jinn.gateway"
  [3001]="com.memviz.server"
  [8888]="com.memviz.client"
  [8200]="com.jinn.memory-mcp"
)

declare -A PORT_EXPECT=(
  [7778]="jinn|jimmy"
  [3001]="memviz/server|vite"
  [8888]="memviz/client|vite"
  [8200]="supergateway|mcp_memory"
)

declare -A PORT_NAME=(
  [7778]="Jinn Gateway"
  [3001]="Memviz Backend"
  [8888]="Memviz Frontend"
  [8200]="Memory MCP Bridge"
)

# --- stdio services (PID-based check only) ---
declare -A STDIO_SERVICES=(
  ["com.mem0.mcp-server"]="Mem0 MCP"
)

declare -A STDIO_EXPECT=(
  ["com.mem0.mcp-server"]="mcp_memory_service"
)

declare -A STDIO_STDERR=(
  ["com.mem0.mcp-server"]="${JINN_HOME:-$HOME/.jinn}/logs/mcp-server-error.log"
)

declare -A STDIO_STDOUT=(
  ["com.mem0.mcp-server"]="${JINN_HOME:-$HOME/.jinn}/logs/mcp-server.log"
)

# --- Logs for TCP services ---
declare -A LABEL_STDERR=(
  ["com.jinn.gateway"]="$JINN_HOME/logs/gateway-stderr.log"
  ["com.memviz.server"]="/tmp/memviz-backend-error.log"
  ["com.memviz.client"]="/tmp/memviz-frontend-error.log"
  ["com.jinn.memory-mcp"]="$JINN_HOME/logs/memory-mcp.err"
)

declare -A LABEL_STDOUT=(
  ["com.jinn.gateway"]="$JINN_HOME/logs/gateway-stdout.log"
  ["com.memviz.server"]="/tmp/memviz-backend.log"
  ["com.memviz.client"]="/tmp/memviz-frontend.log"
  ["com.jinn.memory-mcp"]="$JINN_HOME/logs/memory-mcp.log"
)

LOG="$JINN_HOME/logs/port-guard.log"
CRASH_DIR="$JINN_HOME/logs/crash-counts"
AUDIT_DIR="$JINN_HOME/logs/audits"
CRASH_THRESHOLD=5
CRASH_WINDOW=300
COOLDOWN=120

mkdir -p "$CRASH_DIR" "$AUDIT_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

now=$(date +%s)

record_crash() {
  local label="$1"
  local file="$CRASH_DIR/$label"
  echo "$now" >> "$file"
  if [ -f "$file" ]; then
    awk -v cutoff=$((now - CRASH_WINDOW)) '$1 >= cutoff' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
}

count_crashes() {
  local label="$1"
  local file="$CRASH_DIR/$label"
  if [ -f "$file" ]; then
    wc -l < "$file" | tr -d ' '
  else
    echo 0
  fi
}

is_in_cooldown() {
  local label="$1"
  local cooldown_file="$AUDIT_DIR/$label.cooldown"
  if [ -f "$cooldown_file" ]; then
    local last_audit
    last_audit=$(cat "$cooldown_file")
    if [ $((now - last_audit)) -lt $COOLDOWN ]; then
      return 0
    fi
  fi
  return 1
}

run_audit() {
  local label="$1"
  local name="$2"
  local stderr_log="$3"
  local stdout_log="$4"
  local audit_file="$AUDIT_DIR/$label.audit"

  log "AUDIT — $name ($label) crash loop detected"

  {
    echo "=== AUDIT: $name ($label) — $(date) ==="
    echo ""
    echo "--- launchctl info ---"
    launchctl list "$label" 2>&1 || echo "(not loaded)"
    echo ""
    echo "--- Last 30 lines stderr ---"
    tail -30 "$stderr_log" 2>/dev/null || echo "(no stderr log)"
    echo ""
    echo "--- Last 30 lines stdout ---"
    tail -30 "$stdout_log" 2>/dev/null || echo "(no stdout log)"
    echo ""
    echo "--- Disk space ---"
    df -h / | tail -1
    echo ""
    echo "--- Memory ---"
    vm_stat 2>/dev/null | head -5
    echo ""
    echo "=== END AUDIT ==="
  } > "$audit_file" 2>&1

  log "Audit saved to $audit_file"

  echo "$now" > "$AUDIT_DIR/$label.cooldown"
  rm -f "$CRASH_DIR/$label"

  launchctl unload ~/Library/LaunchAgents/"$label".plist 2>/dev/null || true
  sleep 2
  launchctl load ~/Library/LaunchAgents/"$label".plist 2>/dev/null
  log "$name force-restarted after audit"
}

restart_service() {
  local label="$1"
  local name="$2"
  record_crash "$label"
  local crashes
  crashes=$(count_crashes "$label")

  if [ "$crashes" -ge "$CRASH_THRESHOLD" ]; then
    run_audit "$label" "$name" "$3" "$4"
  else
    log "$name down (crash $crashes/$CRASH_THRESHOLD) — restarting"
    launchctl unload ~/Library/LaunchAgents/"$label".plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/"$label".plist 2>/dev/null
  fi
}

# ============================================================
# TCP SERVICES — check by port
# ============================================================
for port in "${!PORT_OWNER[@]}"; do
  label="${PORT_OWNER[$port]}"
  expect="${PORT_EXPECT[$port]}"
  name="${PORT_NAME[$port]}"

  is_in_cooldown "$label" && continue

  pid=$(lsof -ti :"$port" -sTCP:LISTEN 2>/dev/null | head -1)

  if [ -z "$pid" ]; then
    running_pid=$(launchctl list "$label" 2>/dev/null | grep '"PID"' | awk '{print $3}' | tr -d ';')
    if [ -z "$running_pid" ]; then
      restart_service "$label" "$name" "${LABEL_STDERR[$label]}" "${LABEL_STDOUT[$label]}"
    fi
    continue
  fi

  cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "")

  if echo "$cmd" | grep -qE "$expect"; then
    rm -f "$CRASH_DIR/$label"
    continue
  fi

  # Foreign process — kill and reclaim
  proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
  log "Port $port hijacked by PID $pid ($proc_name) — killing and restarting $name"
  kill -9 "$pid" 2>/dev/null || true
  sleep 1
  launchctl unload ~/Library/LaunchAgents/"$label".plist 2>/dev/null || true
  launchctl load ~/Library/LaunchAgents/"$label".plist 2>/dev/null
  log "$name restarted on port $port"
done

# ============================================================
# STDIO SERVICES — check by launchd PID existence
# ============================================================
for label in "${!STDIO_SERVICES[@]}"; do
  name="${STDIO_SERVICES[$label]}"
  expect="${STDIO_EXPECT[$label]}"

  is_in_cooldown "$label" && continue

  running_pid=$(launchctl list "$label" 2>/dev/null | grep '"PID"' | awk '{print $3}' | tr -d ';')

  if [ -n "$running_pid" ]; then
    # Verify process is the right one
    cmd=$(ps -p "$running_pid" -o command= 2>/dev/null || echo "")
    if echo "$cmd" | grep -qE "$expect"; then
      rm -f "$CRASH_DIR/$label"
      continue
    fi
  fi

  # Service is down or wrong process
  restart_service "$label" "$name" "${STDIO_STDERR[$label]}" "${STDIO_STDOUT[$label]}"
done
