/**
 * Jinn + Mem0 Bridge Plugin
 * Auto-stores agent responses and injects relevant memories
 * via the MCP Memory Service (mcp-memory-service)
 *
 * Config (env vars or jinn config.yaml → plugins.mem0Bridge):
 *   MEM0_MCP_URL  — MCP Memory Service HTTP endpoint (default: http://127.0.0.1:8200)
 */

const MEM0_MCP_URL = process.env.MEM0_MCP_URL || 'http://127.0.0.1:8200';

async function mpcCall(method, params) {
  try {
    const res = await fetch(`${MEM0_MCP_URL}/mcp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: method, arguments: params } }),
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return data?.result?.content?.[0]?.text ?? null;
  } catch {
    return null;
  }
}

async function isMemoryAvailable() {
  try {
    const res = await fetch(`${MEM0_MCP_URL}/mcp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }),
      signal: AbortSignal.timeout(3000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

module.exports = {
  name: 'mem0-bridge',
  version: '2.0.0',

  async onBeforeAgentRun(agentId, prompt) {
    const result = await mpcCall('memory_search', { query: prompt, limit: 5 });
    if (!result) return prompt;
    try {
      // Extract memory summaries
      const lines = result.split('\n').filter(l => l.startsWith('1.') || l.startsWith('2.') || l.startsWith('3.') || l.startsWith('4.') || l.startsWith('5.'));
      if (lines.length === 0) return prompt;
      return `[RELEVANT MEMORIES]\n${lines.join('\n')}\n\n[USER PROMPT]\n${prompt}`;
    } catch {
      return prompt;
    }
  },

  async onAgentResponse(agentId, response) {
    if (!response || response.length < 50) return;
    await mpcCall('memory_store', {
      content: `[${agentId}] ${response.substring(0, 500)}`,
      metadata: { source: 'jinn-auto', agent: agentId },
    });
  },

  isMemoryAvailable,
};
