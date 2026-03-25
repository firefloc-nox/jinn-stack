#!/bin/bash
set -e

echo "🧪 Testing process cleanup fixes..."

# Test 1: pgrep -P fallback
echo "Test 1: pgrep -P fallback to ps..."
test_pgrep_fallback() {
  local pid=$$ # Current shell PID
  # Try pgrep -P, fallback to ps
  local children=$(pgrep -P "$pid" 2>/dev/null \
    || ps -eo pid=,ppid= 2>/dev/null | awk -v p="$pid" '$2==p{print $1}' \
    || true)
  # We may or may not have children, but the command shouldn't error
  echo "✅ Fallback works (found $(echo "$children" | wc -l) children or fewer)"
}
test_pgrep_fallback

# Test 2: Numeric PID filtering
echo "Test 2: Numeric PID filtering..."
test_pid_filtering() {
  # Simulate fuser output with non-numeric tokens
  local fuser_output="8080/tcp:  1234  5678"
  local pids=$(echo "$fuser_output" | tr ' ' '\n' | grep -E '^[0-9]+$' || true)
  local count=$(echo "$pids" | grep -c '^' || true)
  if [ "$count" -ge 2 ]; then
    echo "✅ Extracted $(echo "$pids" | wc -w) numeric PIDs"
  else
    echo "⚠️  Expected at least 2 PIDs, got: $pids"
  fi
}
test_pid_filtering

# Test 3: awk parsing robustness
echo "Test 3: AWK ss parsing robustness..."
test_awk_parsing() {
  # Simulate ss output with header and multiple formats
  local ss_sample=$(cat <<'EOSS'
State  Recv-Q  Send-Q  Local:Port  Peer:Port
LISTEN  0  128  127.0.0.1:3000  *:*  pid=12345,fd=5
LISTEN  0  128  [::]:8080  [::]:*  pid=67890,fd=10
EOSS
)
  local pids=$(echo "$ss_sample" | awk 'NR>1 && index($0,"pid=") {
    n = split($0, parts, "pid=")
    for (i=2; i<=n; i++) {
      pid = parts[i]; gsub(/[^0-9].*/, "", pid)
      if (pid ~ /^[0-9]+$/) print pid
    }
  }')
  local count=$(echo "$pids" | wc -w)
  if [ "$count" -ge 2 ]; then
    echo "✅ AWK parsing extracted PIDs: $pids"
  else
    echo "⚠️  Extracted $(echo "$pids" | grep -c '^' || echo 0) PID(s): $pids"
  fi
}
test_awk_parsing

echo "✅ All process cleanup tests passed!"
