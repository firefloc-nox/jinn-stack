/**
 * Jinn + Mem0 Bridge Plugin
 * Auto-stores agent responses and injects relevant memories
 */

const fetch = require('node-fetch');

const MEM0_API = process.env.MEM0_API || 'http://127.0.0.1:8001';
const MEM0_DB = process.env.MEM0_DB || `${process.env.HOME}/.mem0/memory.db`;

module.exports = {
  name: 'mem0-bridge',
  version: '1.0.0',

  async onBeforeAgentRun(agentId, prompt) {
    try {
      const searchResponse = await fetch(
        `${MEM0_API}/search?q=${encodeURIComponent(prompt)}`,
        { timeout: 3000 }
      );
      if (!searchResponse.ok) return prompt;
      const memories = await searchResponse.json();
      if (!Array.isArray(memories) || memories.length === 0) return prompt;
      const context = memories.map(m => `- ${m.message || m.content}`).join('\n');
      return `[RELEVANT MEMORIES]\n${context}\n\n[USER PROMPT]\n${prompt}`;
    } catch (error) {
      console.log(`[mem0-bridge] Search error (non-fatal): ${error.message}`);
      return prompt;
    }
  },

  async onAgentResponse(agentId, response) {
    try {
      const storeResponse = await fetch(`${MEM0_API}/memory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        timeout: 3000,
        body: JSON.stringify({
          message: `[${agentId}] ${response.substring(0, 500)}`,
          user_id: agentId,
          tags: 'jinn-auto-stored'
        })
      });
      if (!storeResponse.ok) console.log(`[mem0-bridge] Store failed: ${storeResponse.status}`);
    } catch (error) {
      console.log(`[mem0-bridge] Store error (non-fatal): ${error.message}`);
    }
  },

  async onAgentError(agentId, error) {
    try {
      await fetch(`${MEM0_API}/memory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        timeout: 2000,
        body: JSON.stringify({
          message: `[ERROR] ${agentId}: ${error.message}`,
          user_id: 'jinn-errors',
          tags: 'error'
        })
      });
    } catch (e) {
      console.log(`[mem0-bridge] Error store failed: ${e.message}`);
    }
  }
};
