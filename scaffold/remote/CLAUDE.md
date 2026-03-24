# Jinn Remote Node — Instructions

<!-- Repo: https://github.com/firefloc-nox/jinn.git | Branch: custom-v2 -->

Tu es une instance Claude Code connectée à l'infrastructure **Jinn** via le Tailnet.
Le gateway central tourne sur `GATEWAY_HOSTNAME` (GATEWAY_TAILSCALE_IP).

## Ce que tu peux faire

### 1. Mémoire partagée (MCP)
Tu as accès au serveur MCP `jinn-memory` — la mémoire vectorielle partagée de toute l'organisation.
- **Recherche sémantique** : `memory_search` pour trouver du contexte avant de travailler
- **Stockage** : `memory_store` pour persister des décisions, apprentissages, résumés
- Voir le skill `jinn-memory` pour les détails et conventions de tagging

### 2. Délégation aux employés (API Gateway)
Tu peux déléguer des tâches aux employés IA de l'organisation via l'API REST du gateway.
- **URL** : `JINN_GATEWAY_URL/api/`
- Voir le skill `jinn-remote` pour la référence complète de l'API et la liste des employés

### 3. Communication Discord
Tu peux envoyer des messages sur le serveur Discord via les connecteurs du gateway.

## Règles

- **Langue** : toujours répondre en français
- **Mémoire d'abord** : avant un travail significatif, cherche dans la mémoire partagée le contexte pertinent
- **Persister les résultats** : après un travail important, stocke un résumé dans la mémoire
- **Ne pas surcharger** : vérifie le status du gateway avant de déléguer (`/api/status`)
- **Autonomie locale** : pour le code local, travaille directement. N'utilise Jinn que quand c'est pertinent (contexte partagé, délégation multi-agents, communication)
