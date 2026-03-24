#!/usr/bin/env bash
# Log rotation for Jinn — truncate logs exceeding a size threshold
# Usage: rotate-logs.sh [max_size_mb]
#   max_size_mb defaults to 5

set -euo pipefail

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
MAX_MB="${1:-5}"
MAX_BYTES=$((MAX_MB * 1024 * 1024))
ARCHIVE_DIR="$JINN_HOME/logs/archive"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$ARCHIVE_DIR"

rotated=0

for logfile in "$JINN_HOME"/logs/*.log; do
  [ -f "$logfile" ] || continue
  size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
  if [ "$size" -gt "$MAX_BYTES" ]; then
    basename=$(basename "$logfile")
    # Keep last 500 lines as context, archive the rest
    tail -500 "$logfile" > "$logfile.tmp"
    cp "$logfile" "$ARCHIVE_DIR/${basename%.log}-${TIMESTAMP}.log"
    mv "$logfile.tmp" "$logfile"
    rotated=$((rotated + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S') Rotated $basename (was $(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B"))"
  fi
done

# Clean archives older than 7 days
find "$ARCHIVE_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true

if [ "$rotated" -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') No logs exceeded ${MAX_MB}MB — nothing to rotate"
fi
