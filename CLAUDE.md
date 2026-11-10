# Obby Rennes : « Partiel maintenu »

Obby Roblox pour étudiants : traverser Rennes (fac bloquée, métro en grève, cortège, barricades de poubelles, rue de la Soif, Vilaine, Parlement, Thabor) pour arriver à l'heure au partiel à Sup de Vinci. Ton : satire du quotidien étudiant, sans prendre parti (pas de police, pas de slogan politique réel). Game design : `docs/game-design.md`.

## Jeu Roblox
- Code Luau dans `src/` (`serveur/`, `client/`, `partage/`), synchronisé dans Studio par Rojo (`rojo serve`). Studio n'est jamais la source du code : une modification faite dans Studio est perdue si elle n'est pas reportée dans `src/`.
- Cartes et décors dans `monde/` (fichiers .rbxm), générés par les scripts Lune de `outils/monde/` ; `outils/monde/monde.json` dit qui en est l'auteur. Une carte retouchée à la main dans Studio (« auteur » : « utilisateur ») n'est plus jamais régénérée.
- Tests TestEZ dans `tests/` (`*.spec.luau`), absents de la version publiée.
- `roblox verifier` (format, lint, construction), `roblox tests` (tests dans le cloud, place de test), `roblox publier test`. `roblox publier prod` seulement avec l'accord explicite de l'utilisateur.
- Places : `.claude/roblox.json`. Historique des publications : `docs/publications.md`.

## Repères du code
- Contrats carte ↔ serveur (tags et attributs posés par `outils/monde/Parcours.luau`) : `Checkpoint` + `Numero`, `Mortel`, `Fragile`, `Mobile` + `Deplacement`/`Duree`, `Tournant` + `Vitesse`, `TableauClassement`.
- Règles pures et testées : `src/partage/Regles.luau`. Étapes et anecdotes : `src/partage/Etapes.luau`. Réglages (dont l'identifiant du produit « Passer l'étape ») : `src/partage/Reglages.luau`.
- Données des joueurs : `src/serveur/Donnees.luau` (ProfileStore, ADR 0001). Classement : `src/serveur/Classement.luau`. Achats : `src/serveur/Boutique.luau`.
- Anecdotes sur Rennes : uniquement des faits vérifiables ; pas de logo officiel de Sup de Vinci sans accord de l'école.
