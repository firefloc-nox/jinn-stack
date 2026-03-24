---
name: jinn-remote
description: Interagir avec l'infrastructure Jinn distante — déléguer aux employés, consulter les boards, gérer les crons, et communiquer via les connecteurs.
---

# Jinn Remote — Accès à l'infrastructure Jinn

Tu es connecté à l'infrastructure Jinn hébergée sur `clawd` via le Tailnet.
Le gateway Jinn est accessible à : `JINN_GATEWAY_URL`

## Quand utiliser ce skill

- Quand l'utilisateur veut déléguer une tâche à un employé Jinn (ex: "@coder", "@planner", "@investigateur")
- Quand il veut consulter l'état d'un board ou d'une session
- Quand il veut envoyer un message Discord via les connecteurs
- Quand il veut vérifier le status du gateway ou des crons

## API Gateway — Référence

Base URL: `JINN_GATEWAY_URL`

### Endpoints principaux

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/status` | GET | Status du gateway |
| `/api/org` | GET | Liste des départements et employés |
| `/api/org/employees/:name` | GET | Détails d'un employé |
| `/api/sessions` | GET | Liste des sessions |
| `/api/sessions/:id` | GET | Détail d'une session (avec messages) |
| `/api/sessions` | POST | Créer une session (déléguer une tâche) |
| `/api/sessions/:id/message` | POST | Envoyer un follow-up à une session existante |
| `/api/sessions/:id/children` | GET | Sessions enfants |
| `/api/cron` | GET | Liste des cron jobs |
| `/api/cron/:id/runs` | GET | Historique d'exécution d'un cron |
| `/api/connectors` | GET | Liste des connecteurs |
| `/api/connectors/:name/send` | POST | Envoyer un message via un connecteur |
| `/api/skills` | GET | Liste des skills disponibles |
| `/api/boards` | GET | Voir le board (Kanban) |

### Déléguer une tâche à un employé

```bash
curl -s -X POST JINN_GATEWAY_URL/api/sessions \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt": "Ta tâche ici...",
    "employee": "nom-employe",
    "effortLevel": "medium"
  }'
```

Niveaux d'effort : `low` (lookups), `medium` (routine), `high` (code/architecture)

### Envoyer un message de suivi

```bash
curl -s -X POST JINN_GATEWAY_URL/api/sessions/<session-id>/message \
  -H 'Content-Type: application/json' \
  -d '{"message": "Ton message de suivi..."}'
```

### Envoyer un message Discord

```bash
curl -s -X POST JINN_GATEWAY_URL/api/connectors/discord/send \
  -H 'Content-Type: application/json' \
  -d '{"channel": "CHANNEL_ID", "text": "Le message"}'
```

## Organisation — Employés disponibles

### Bug Hunt
- **bugmaster** (manager) — Chef de projet bug hunt Nexamon
- **bugcatcher** (senior) — Investigation de bugs
- **conduit** (senior) — Orchestration
- **qa-tester** (senior) — Test qualité in-game
- **warden** (senior) — Operations

### Discord
- **senex-discord** (manager) — Admin Discord Nexamon
- **vox** (senior) — Monitoring & voix Discord

### Infra
- **sysadmin** (manager) — Gardien sysadmin
- **nox-workspace** (senior) — Opérations système locales

### Nexamon Studio
- **planner** (director) — Architecte-planificateur
- **writer** (lead content) — Porte-parole
- **ideator** (lead design) — Créatrice de mécaniques
- **artist** (design) — Assets visuels
- **critic** (design) — Critique qualité
- **surveyor** (design) — Gardien du lore
- **ironcraft** (lead dev) — Implémentation code
- **coder** (dev) — Développeur backend
- **reviewer** (senior dev) — Validateur final
- **investigateur** (lead research) — Analyste système
- **pixelmon** (research) — Expert mécaniques Pokémon
- **scout** (research) — Sentinelle opérationnelle

### Staff
- **limitless** (senior) — Optimisation quotas et orchestration modèles

## Règles

1. **Toujours vérifier le status** avant de déléguer : `curl -s JINN_GATEWAY_URL/api/status`
2. **Ne pas polluer** — ne crée des sessions que si nécessaire
3. **Résultats** — les sessions sont asynchrones. Après création, note le session ID pour suivi
4. **Langue** — communique toujours en français avec les employés
5. **Effort level** — adapte le niveau d'effort à la complexité de la tâche
