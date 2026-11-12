# Publications

Chaque version publiée est tracée dans le résumé de l'exécution du workflow « Publier » (onglet Actions) : numéro de version Roblox et commit.

## Publier une version
1. Ouvrir une PR vers `main` : le check `verifier` doit être vert.
2. Fusionner la PR. Le workflow « Publier » se lance seul : contrôles, construction, puis publication sur l'expérience de test.
3. Essayer la version sur l'expérience de test (Roblox).
4. Pour la production : onglet Actions, ouvrir l'exécution, « Review deployments », cocher `production`, « Approve and deploy ». Sans approbation, rien ne part en production. **N'approuver que l'exécution la plus récente** : une ancienne exécution en attente publierait une version dépassée.
5. Lire le numéro de version dans le résumé de l'exécution. Pour revenir en arrière, rétablir une version précédente dans Creator Hub (Versions), ou republier une ancienne version : *Re-run all jobs* sur l'ancienne exécution de « Publier ».

## Réglages à faire soi-même (une fois, dans cet ordre)
- [ ] 1. Créer la branche `main` sur GitHub depuis `agents/premier-jalon`, et la mettre en branche par défaut.
- [ ] 2. Créer une 2e expérience **privée** « Obby Rennes (test) », y publier une première fois le jeu depuis Studio, et relever l'**Universe ID** et le **Place ID** des deux expériences (Creator Hub, ⋯, Copier).
- [ ] 3. Créer les environnements GitHub `test` et `production` (Settings, Environments). Pour chacun : *Deployment branches* = `main` seulement. Pour `production` : s'ajouter soi-même en *Required reviewer*.
- [ ] 4. Créer **deux clés Open Cloud** (create.roblox.com, Open Cloud, API Keys), une par expérience, avec le droit `universe-places` en écriture sur cette seule expérience. *Accepted IP Addresses* : `0.0.0.0/0` (les machines GitHub changent d'adresse). Noter la date d'expiration de chaque clé pour la renouveler à temps.
- [ ] 5. Ranger chaque clé dans les secrets **de son environnement** (Settings, Environments, `test` ou `production`, Environment secrets) sous le nom `ROBLOX_API_KEY`. Jamais dans les secrets du dépôt.
- [ ] 6. Reporter les identifiants (relevés à l'étape 2) dans `.claude/roblox.json`.
- [ ] 7. Protéger `main` (Settings, Branches) : PR obligatoire, check `verifier` obligatoire.
- [ ] 8. Conseillé : Settings, Actions, General : exiger l'approbation des workflows pour les contributeurs extérieurs.

## Historique
Voir les exécutions du workflow « Publier » ; ajouter ici les retours en arrière et incidents notables.
