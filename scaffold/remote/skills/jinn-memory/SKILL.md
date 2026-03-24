---
name: jinn-memory
description: Utiliser la mémoire vectorielle partagée Jinn — rechercher, stocker et gérer les souvenirs persistants accessibles par toute l'organisation.
---

# Jinn Memory — Mémoire vectorielle partagée

Tu as accès à la mémoire vectorielle partagée de l'organisation via le MCP `jinn-memory`.
Cette mémoire est hébergée sur `clawd` et accessible via le Tailnet.

## Outils MCP disponibles

Les outils suivants sont fournis par le serveur MCP `jinn-memory` :

| Outil | Description |
|-------|-------------|
| `memory_search` | Recherche sémantique dans la mémoire (query + top_k) |
| `memory_store` | Stocker un nouveau souvenir (content, metadata, tags) |
| `memory_delete` | Supprimer un souvenir par ID |
| `memory_update` | Mettre à jour un souvenir existant |
| `memory_list` | Lister les souvenirs (avec filtres optionnels) |
| `memory_stats` | Statistiques de la base mémoire |
| `memory_health` | Vérifier la santé du service |
| `memory_graph` | Visualiser les relations entre souvenirs |
| `memory_cleanup` | Nettoyer les souvenirs dupliqués ou obsolètes |
| `memory_quality` | Évaluer la qualité des souvenirs stockés |
| `memory_ingest` | Ingérer des fichiers dans la mémoire |

## Quand utiliser ce skill

### Rechercher du contexte
Avant de commencer un travail sur le projet Nexamon ou l'infrastructure Jinn, cherche dans la mémoire :
```
memory_search(query="architecture spp-ai 4 bricks", top_k=5)
```

### Stocker une décision ou un apprentissage
Après une décision importante, un debug réussi, ou un apprentissage :
```
memory_store(
  content="Le scaling des trainers utilise 7 bytecode mixins...",
  metadata={"type": "reference", "tags": ["nexamon", "scaling", "architecture"]}
)
```

### Conventions de tagging

| Tag | Usage |
|-----|-------|
| `nexamon` | Tout ce qui touche au projet Nexamon |
| `jinn` | Infrastructure Jinn, gateway, config |
| `spp-ai` | Le mod AI (4 bricks, NPC, Persona) |
| `discord` | Intégration Discord, bots |
| `architecture` | Décisions d'architecture |
| `decision` | Choix importants pris |
| `debug` | Solutions à des problèmes rencontrés |
| `core` | Faits fondamentaux, rarement changés |
| `session-summary` | Résumés de fin de session |

## Règles

1. **Écrire des souvenirs auto-suffisants** — un futur lecteur doit comprendre sans contexte
2. **Inclure le "pourquoi"** — pas juste le "quoi", mais la raison derrière
3. **Ne pas dupliquer** — chercher avant de stocker, mettre à jour si un souvenir similaire existe
4. **Taguer correctement** — utiliser les tags ci-dessus pour la cohérence
5. **Qualité > quantité** — un bon souvenir vaut mieux que dix médiocres
