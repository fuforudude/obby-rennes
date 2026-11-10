# 0001 : ProfileStore pour les données des joueurs

- Statut : accepté
- Date : 2026-11-10

## Contexte
Le jeu sauvegarde par joueur le checkpoint atteint, le meilleur temps et les achats Robux déjà traités. Perdre une progression ou donner deux fois un achat est le pire bug d'un jeu Roblox. Un joueur qui change de serveur ne doit jamais écraser une sauvegarde récente avec une ancienne.

## Décision
Utiliser **ProfileStore** (`lm-loleris/profilestore`, Wally, côté serveur) : verrou de session, sauvegardes automatiques et à la fermeture du serveur, données simulées dans Studio sans accès aux API. Tout passe par `src/serveur/Donnees.luau`. La forme des données est remise d'aplomb à chaque chargement par `Regles.migrer` (version de schéma `version = 1`).

Le classement mondial, lui, est une donnée partagée (pas par joueur) : il utilise directement un `OrderedDataStore`, dans `src/serveur/Classement.luau`.

## Conséquences
- Dépendance Wally à installer (`wally install`) ; le dossier `ServerPackages/` est branché sous ServerScriptService.
- Un achat Robux n'est confirmé qu'après `Donnees.sauvegarderMaintenant` ; les `PurchaseId` traités sont gardés dans les données (100 derniers).
