#!/usr/bin/env bash
# Expose MCP Memory Service as Streamable HTTP endpoint via supergateway
# Accessible via Tailscale serve for remote Claude Code instances

JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
MEM0_PYTHON="${MEM0_PYTHON:-$HOME/.mem0/venv/bin/python3}"
DB_PATH="${MCP_MEMORY_DB_PATH:-$HOME/Library/Application Support/mcp-memory/sqlite_vec.db}"
MEM0_PORT="${MEM0_PORT:-8200}"

exec npx -y supergateway \
  --stdio "${MEM0_PYTHON} -m mcp_memory_service.server --db \"${DB_PATH}\"" \
  --port "${MEM0_PORT}" \
  --outputTransport streamableHttp
