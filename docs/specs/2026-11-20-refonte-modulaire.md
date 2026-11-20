# Refonte modulaire : ajouter des étages, des pièges et des cartes sans casser le reste

Statut : brouillon
Date : 2026-11-20

## Besoin
Le jeu va grandir longtemps : nouvelles tranches de la tour, nouveaux pièges, nouvelles cartes après Sup de Vinci, boutique. Aujourd'hui un ajout touche des fichiers imprévisibles, plusieurs oublis ne sont détectés par rien, et la publication part sans la moitié des contrôles. Le but : qu'un ajout courant touche peu de fichiers, toujours les mêmes, et qu'un oubli fasse échouer un contrôle avant la mise en ligne.

## Constats qui motivent la refonte
- La CI ne lance que `verifier-sauts` (`.github/workflows/verifier.yml:52`). `verifier-ascension`, `verifier-evenements` et les cartes cassées `casser-*` ne tournent nulle part en automatique ; `publier.yml` régénère la carte et la publie sans aucun contrôle de carte.
- Rien ne prouve que les `.rbxm` commités sont ceux que les générateurs produisent.
- Hypothèses cachées dans les contrôles : `15` écrit en dur (`verifier-evenements.luau:627,666`, `verifier-ascension.luau:392`), motif de dossier de zone `^%d_` limité à 10 zones (3 endroits), `NB_TRANCHES` recopié (`verifier-ascension.luau:768`), ensemble des checkpoints jamais vérifié égal à 0..`NB_ETAPES`, tag inconnu jamais signalé.
- Pièges sans registre : côté serveur (`src/serveur/Obstacles.luau:165-243,474-504`, dont `oublierSiVide` qui fige un nouveau piège s'il est oublié), côté générateur (chaîne `if famille ==` sans `else` dans `outils/monde/Ascension.luau:1766-1780` : une famille inconnue ne pose rien, en silence) et côté contrôle.
- Coordonnées des checkpoints recopiées entre `outils/monde/Parcours.luau:1452-2393` et `outils/monde/Evenements.luau:1369-1386` ; la tour accrochée à Sup de Vinci par des littéraux (`Ascension.luau:62,2070-2089`) ; outils de construction, palettes et bloc `TEXTE_PUR` recopiés en trois exemplaires ; noms de zone déjà divergents avec `src/partage/Etapes.luau` (n°10, n°15).
- Constantes de saut recopiées hors de `Reglages` (`verifier-sauts.luau:32-37`, `verifier-ascension.luau:84-89`, `Ascension.luau:1105`).
- `Regles.migrer` ne lit jamais `version` : aucune remise à zéro ciblée n'est possible.
- Ordre de démarrage des services porteur d'un couplage silencieux (`init.server.luau:25-27` : un abonné à `Donnees.surChargement` doit démarrer avant `Donnees`).

## Périmètre
- Dedans :
  - tous les contrôles en CI et avant publication, une empreinte de carte, une commande locale « tout vérifier » ;
  - contrôles sans hypothèses cachées ;
  - registre des pièges côté serveur, côté générateur de la tour et côté contrôle ;
  - bibliothèque de construction commune aux générateurs et source unique des checkpoints ;
  - sauvegardes versionnées et classements de la tour versionnés (mécanisme seulement, aucune remise à zéro déclenchée maintenant) ;
  - démarrage des services sans couplage d'ordre, nettoyage du code mort repéré ;
  - registre des cartes pour ajouter une carte après Sup de Vinci.
- Hors périmètre :
  - aucune nouvelle carte, tranche ou piège : seulement la structure qui les rendra simples ;
  - découpage du parcours en modules de zone et coordonnées relatives (inutile : le parcours est figé) ;
  - registre des capacités côté interface (ajout rare, les nouvelles capacités se débloqueront hors du parcours) ;
  - table « produit → traitement » de la boutique (au début du jalon boutique) ;
  - aucun changement visible pour les joueurs.

## Critères d'acceptation
- [ ] Une PR qui casse `verifier-ascension` ou `verifier-evenements` est rouge en CI.
- [ ] Chaque carte cassée `casser-*` est lancée en CI, et la CI échoue si l'une d'elles **passe** les contrôles.
- [ ] Le job `construire` de `publier.yml` lance tous les contrôles de carte avant de publier ; un contrôle rouge empêche la publication de test comme de production.
- [ ] La CI échoue si `lune run outils/monde/generer.luau` modifie un fichier de `monde/` commité.
- [ ] Une commande locale unique lance format, lint, types, tests Lune, génération et tous les contrôles de carte, et sort en erreur au premier échec.
- [ ] Un script d'empreinte produit, pour chaque `.rbxm`, une liste triée (chemin, classe, position et taille arrondies, tags, attributs). Pour chaque incrément de refonte du monde, l'empreinte avant/après est identique ; toute différence voulue est écrite dans le message de commit.
- [ ] Une carte trafiquée sans le checkpoint n°7 fait échouer un contrôle. Une carte avec un dossier de zone `10_Test` est vue par les contrôles. Une carte portant un tag de piège inconnu fait échouer un contrôle.
- [ ] Aucun contrôle ne contient plus le nombre d'étapes, de tranches ou une constante de saut en dur : tout se lit dans `src/partage/Reglages.luau` ou se déduit de la carte.
- [ ] Ajouter un type de piège côté serveur se fait en créant un module dans `src/serveur/Obstacles/` et sa règle pure dans `src/partage/Pieges.luau` avec ses tests ; aucune autre liste du serveur n'est à modifier. Un piège qui suit l'horloge continue de bouger quand toutes les autres familles sont absentes de la carte.
- [ ] Dans `outils/monde/Ascension.luau`, une famille d'obstacle inconnue dans `segments` fait échouer la génération ; `NB_TRANCHES` se déduit de `segments` ; la couleur d'une tranche est dans son entrée.
- [ ] Les outils de construction, palettes et `TEXTE_PUR` existent en un seul exemplaire, fourni aux générateurs par `generer.luau`.
- [ ] Les positions des checkpoints et de leurs panneaux viennent d'une seule table lue par `Parcours`, `Evenements` et `Ascension` ; les noms de zone affichés sur la carte et dans `src/partage/Etapes.luau` sont identiques (un contrôle le vérifie).
- [ ] Ajouter une carte après Sup de Vinci se fait par un nouveau générateur et une entrée dans un registre de cartes lu par `generer.luau` et les contrôles.
- [ ] `Regles.migrer` lit `version` et sait appliquer une migration par version ; un test migre une sauvegarde v1 réelle sans perte de champ.
- [ ] Les noms des classements de la tour et les records de tour du profil dépendent d'une version de tour dans `Reglages` : changer cette version fait repartir classements et records de tour à vide, sans toucher au parcours ni à l'aura. Un test le vérifie sur la règle pure. La version initiale garde les noms actuels (`HauteurAscension_v1`, `TempsAscension_v1`).
- [ ] Un service abonné à `Donnees.surChargement` reçoit aussi les joueurs déjà chargés, quel que soit l'ordre de démarrage ; `init.server.luau` démarre les services depuis une liste.
- [ ] Le jeu se joue comme avant : parcours, checkpoints, réapparition, capacités, tour, classements, mode vol (QA en jeu).

## Décisions
| Question | Options envisagées | Choix | Raison |
|---|---|---|---|
| Où va le nouveau contenu | Insérer dans le parcours / Tour + cartes après Sup de Vinci | Tour + cartes après | Le parcours (checkpoints 0 à 15) est figé : aucun joueur ne recule, pas de découpage du parcours. |
| Coller un générateur dans Studio | Garder les copies / Assembleur / Bibliothèque commune | Bibliothèque commune | On génère par la commande, l'aperçu passe par Rojo ; le code commun n'existe qu'une fois. |
| Records quand la tour change | Remise à zéro / Garder / Saisons | Remise à zéro | Un classement juste pour les nouveaux joueurs ; les anciens records restent stockés, plus affichés. |
| Où se débloque une nouvelle capacité | Hors du parcours / Dans le parcours avec rattrapage | Hors du parcours | Pas de migration, aucun joueur bloqué. |
| Nom de la zone n°10 (carte et HUD divergents) | « Le dernier bar avant le partiel » / « Rue de la Soif » | « Le dernier bar avant le partiel » | Distingue le n°10 du n°9, déjà nommé « Rue de la Soif ». On corrige `Etapes.luau`. |
| Nom de la zone n°15 | « Sup de Vinci · salle de partiel » / « Sup de Vinci » | « Sup de Vinci · salle de partiel » | Dit où l'on arrive. On corrige `Etapes.luau`. |

Conventions appliquées (pas des décisions) : règles pures dans `src/partage/` testées sous Lune, carte en code, chaque contrôle prouvé capable d'échouer, serveur qui fait autorité, aucune donnée sauvegardée renommée sans migration.

## Tâches
Vague 1, en parallèle (fichiers disjoints) :
1. **World — filet de sécurité.** Script d'empreinte de carte ; commande locale « tout vérifier » ; tous les contrôles et les `casser-*` en CI et dans `publier.yml` (job `construire`) ; contrôle « carte commitée = carte générée » ; contrôles sans hypothèses (nombre d'étapes, tranches, motif `^%d+_`, ensemble des checkpoints, tag inconnu, constantes de saut lues dans `Reglages`) ; `CLAUDE.md` corrigé (contenu de `roblox verifier`, `PanneauAnecdote` en `Titre`/`Corps`). Mesurer la durée des `casser-*` en CI. Durée estimée : 2 h
2. **Gameplay — serveur et données.** `src/serveur/Obstacles/` en registre (un module par famille, un seul ensemble « suivent l'horloge ») ; `Donnees.surChargement` qui rejoue les joueurs chargés et `init.server.luau` en liste ; `Regles.migrer` par version ; version de tour pour classements et records de tour ; nettoyage (`Pieges.cycleEffondrable` utilisé ou supprimé, délais de `Fragile` dans `Reglages`, constante partagée `EnAscension`, commentaires sur les paliers supprimés). Durée estimée : 2 h 30

Vague 2, World, après fusion de la tâche 1 (pour s'appuyer sur l'empreinte) :
3. **World — tour en registre.** Poseurs par famille avec échec sur famille inconnue, `NB_TRANCHES = #segments`, couleur dans `segments`, simulation de `verifier-ascension` par registre, sans nouveau tirage aléatoire. Empreinte identique. Durée estimée : 1 h 30
4. **World — bibliothèque commune et source unique.** Bibliothèque injectée par `generer.luau` ; table unique des checkpoints et panneaux ; `Ascension` qui lit Sup de Vinci au lieu des littéraux ; noms de zone alignés sur `Etapes.luau` ; registre des cartes. Empreinte identique sauf noms de zone alignés. Durée estimée : 2 h 30

Puis : revue (`socle:reviewer`) et QA en jeu (`roblox:qa`) sur la branche d'intégration, publication sur la place de test.

Durée estimée du jalon : 7 h 30 (vague 1 : 2 h 30 ; vague 2 : 4 h ; revue, QA et livraison : 1 h)

## Impacts
- Données / migrations : `version` du profil désormais lue ; aucune donnée existante modifiée ; noms de classements inchangés à la livraison.
- API : aucun remote ajouté ni modifié.
- Écrans : aucun.

## Questions ouvertes
- Durée des `casser-*` en CI : si elle dépasse quelques minutes, les lancer seulement dans `publier.yml` plutôt qu'à chaque PR (à trancher avec la mesure).
