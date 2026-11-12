# Publications

Chaque version publiée est tracée dans le résumé de l'exécution du workflow « Publier » (onglet Actions) : numéro de version Roblox et commit.

## Publier une version
1. Ouvrir une PR vers `main` : le check `verifier` doit être vert.
2. Fusionner la PR. Le workflow « Publier » se lance seul : contrôles, construction, puis publication sur l'expérience de test.
3. Essayer la version sur l'expérience de test (Roblox).
4. Pour la production : onglet Actions, ouvrir l'exécution, « Review deployments », cocher `production`, « Approve and deploy ». Sans approbation, rien ne part en production.
5. Lire le numéro de version dans le résumé de l'exécution. Pour revenir en arrière, rétablir une version précédente dans Creator Hub (Versions) ou republier un commit antérieur.

## Réglages à faire soi-même (une fois)
- [ ] Créer la branche `main` sur GitHub depuis `agents/premier-jalon`, et la mettre en branche par défaut.
- [ ] Créer une 2e expérience **privée** « Obby Rennes (test) » et y publier une première fois le jeu depuis Studio.
- [ ] Relever l'**Universe ID** et le **Place ID** des deux expériences (Creator Hub, ⋯, Copier) et les reporter dans `.claude/roblox.json`.
- [ ] Créer la clé Open Cloud (create.roblox.com, Open Cloud, API Keys), droit `universe-places` en écriture sur les deux expériences, et la mettre dans les secrets GitHub du dépôt sous le nom `ROBLOX_API_KEY`.
- [ ] Créer l'environnement GitHub `production` (Settings, Environments) avec soi-même comme *Required reviewer*.
- [ ] Protéger `main` (Settings, Branches) : PR obligatoire, check `verifier` obligatoire.

## Historique
Voir les exécutions du workflow « Publier » ; ajouter ici les retours en arrière et incidents notables.
