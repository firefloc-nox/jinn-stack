# Jinn Remote Kit

> **Repo** : `https://github.com/firefloc-nox/jinn-v3.git` — branche `custom-v3`

Kit d'intégration pour connecter Claude Code (VSCode) sur une machine distante à l'infrastructure Jinn via Tailscale.

## Contenu

```
remote/
├── README.md            ← Ce fichier
├── setup.sh             ← Script d'installation automatique
├── mcp.json             ← Template config MCP (mémoire vectorielle)
├── CLAUDE.md            ← Instructions projet pour Claude Code
└── skills/
    ├── jinn-remote/     ← Skill: API gateway, délégation, org
    │   └── SKILL.md
    └── jinn-memory/     ← Skill: mémoire vectorielle partagée
        └── SKILL.md
```

## Installation rapide

Sur la machine distante :

```bash
# Option A: Cloner le repo
git clone -b custom-v3 https://github.com/firefloc-nox/jinn-v3.git /tmp/jinn
bash /tmp/jinn/remote/setup.sh

# Option B: Copier le kit depuis le serveur gateway
scp -r GATEWAY_HOSTNAME:~/.jinn/remote/ /tmp/jinn-remote/
bash /tmp/jinn-remote/setup.sh

# Optionnel: configurer un projet spécifique
bash /tmp/jinn-remote/setup.sh --project ~/path/to/project
```

## Ce qui est installé

| Composant | Destination | Effet |
|-----------|-------------|-------|
| MCP config | `~/.claude/.mcp.json` | Connexion à la mémoire vectorielle partagée |
| Skill jinn-remote | `~/.claude/skills/jinn-remote/` | API gateway, délégation aux employés |
| Skill jinn-memory | `~/.claude/skills/jinn-memory/` | Conventions mémoire partagée |
| CLAUDE.md | `<projet>/CLAUDE.md` | Contexte Jinn pour Claude Code |

## Prérequis

- **Tailscale** connecté au même tailnet que le serveur gateway
- **Claude Code** installé (CLI ou VSCode extension)
- **Gateway** allumé avec le gateway Jinn actif

## Services exposés via Tailnet

| Service | URL | Port local |
|---------|-----|------------|
| Gateway API | `JINN_GATEWAY_URL` | 7778 |
| Mémoire MCP | `JINN_MEMORY_URL` | 8200 |
