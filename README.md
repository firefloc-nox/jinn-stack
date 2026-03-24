# Jinn Stack

Full installation script for the Noxis AI gateway ecosystem.

## Components

| Component | Description | Source |
|-----------|-------------|--------|
| **Jinn** | AI gateway — session management, org, cron, connectors | `github.com/firefloc-nox/jinn` (branch: `custom-v2`) |
| **Mem0** | Vector memory layer (Python) | PyPI: `mem0ai` |
| **MCP Memory Service** | MCP server for shared memory access | PyPI: `mcp-memory-service` |
| **MemViz** | Memory visualization dashboard | `github.com/pfillion42/memviz` |

## Prerequisites

- **Node.js** >= 20
- **Python** >= 3.11
- **pnpm** (for Jinn)
- **npm** (for MemViz)
- **git**

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/firefloc-nox/jinn-stack/main/bootstrap.sh | bash
```

Or manually:
```bash
git clone https://github.com/firefloc-nox/jinn-stack.git ~/dev/jinn-stack
cd ~/dev/jinn-stack
bash install.sh
```

## Post-Install

1. Edit `~/.jinn/config.yaml` — configure engines, connectors, portal name
2. Edit `~/.mem0/config.json` — set your `OPENAI_API_KEY`
3. Start: `~/.jinn/start.sh`
4. Stop: `~/.jinn/stop.sh`

## Update

```bash
cd ~/dev/jinn-stack
bash update.sh
```

Pulls latest code, rebuilds, and refreshes scaffold files (docs, scripts, plugins, remote kit). User data is preserved and backed up before update: `config.yaml`, `org/`, `knowledge/`, `sessions/`, `cron/jobs.json`, `CLAUDE.md`, `AGENTS.md`.

## Uninstall

```bash
cd ~/dev/jinn-stack
bash uninstall.sh
```

Backs up all user data to `~/jinn-backup-<timestamp>/` then removes the stack. Double confirmation required. Backup includes: config, org, knowledge, sessions, skills, mem0 DBs.

## Services

| Service | Default Port | URL |
|---------|-------------|-----|
| Jinn Gateway | 7778 | http://localhost:7778 |
| MCP Memory | 8200 | http://localhost:8200 |
| MemViz Backend | 3001 | http://localhost:3001 |
| MemViz Frontend | 8888 | http://localhost:8888 |

## Directory Structure

```
jinn-stack/
├── install.sh              # Main installer (idempotent)
├── start.sh                # Start all services
├── stop.sh                 # Stop all services
├── update.sh               # Pull, rebuild, refresh scaffold
├── uninstall.sh            # Backup user data & remove stack
├── templates/
│   ├── config.yaml         # Jinn gateway config template
│   ├── config.mem0.json    # Mem0 config template
│   ├── mem0-bridge.js      # Plugin template
│   └── cron-jobs.json      # Empty cron jobs
├── scaffold/
│   ├── docs/               # 8 documentation files
│   ├── skills/             # 10 skill playbooks
│   ├── scripts/            # 4 utility scripts
│   ├── remote/             # Remote integration kit
│   ├── CLAUDE.md           # Claude Code instructions
│   └── AGENTS.md           # Agent/employee instructions
└── README.md
```

## Environment Variables

All paths are configurable via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `JINN_HOME` | `~/.jinn` | Jinn home directory |
| `JINN_CLI_DIR` | `~/.jinn/src/jinn-cli` | Jinn source code |
| `MEM0_HOME` | `~/.jinn/src/mem0` | Mem0 venv & data |
| `MEMVIZ_DIR` | `~/.jinn/src/memviz` | MemViz directory |
| `GATEWAY_PORT` | `7778` | Gateway port |
| `MCP_MEMORY_PORT` | `8200` | MCP memory port |

## Remote Access

The `scaffold/remote/` directory contains a kit for connecting remote Claude Code instances to the Jinn infrastructure via Tailscale. See `scaffold/remote/README.md`.

## License

Private.
