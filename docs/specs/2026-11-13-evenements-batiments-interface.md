# Événements dans les descentes, bâtiments rennais fidèles, textes et interface allégée

Statut : validée
Date : 2026-11-13

## Besoin
Après les premiers essais : les descentes sont trop simples, les bâtiments rennais ressemblent à des cubes, certaines vannes sonnent faux, et l'écran est trop chargé. Le joueur doit trouver des descentes animées par des « événements » qui ont l'air aléatoires mais suivent un rythme qu'on peut apprendre, reconnaître les vrais bâtiments de Rennes, et garder les yeux sur le parcours.

## Périmètre
- Dedans :
  - quatre événements, un par descente : objets qui tombent des balcons (coloc), rame qui passe (escalators du viaduc), drones de livraison (échafaudages de la tour), trafic de voitures, bus et trottinettes (descente vers la terrasse de la rue de la Soif) ;
  - les bâtiments rennais refaits d'après leur vraie forme : Parlement de Bretagne, maisons à colombages, Les Horizons et la tour du parcours, hôtel de ville et Opéra, portes Mordelaises, cathédrale Saint-Pierre, Champs Libres ;
  - les textes revus (vannes de checkpoint, messages de chute, affiches) ;
  - l'interface allégée et les anecdotes déplacées dans le décor.
- Hors périmètre : nouveaux checkpoints ou nouveau tracé (les plateformes où l'on marche gardent leurs coordonnées), sons sur mesure, Sup de Vinci (pas de référence fiable du bâtiment), monétisation.

## Critères d'acceptation
### Événements
- [ ] Chaque descente a son événement ; chacun suit un horaire fixe (période, décalage), identique pour tous les joueurs du serveur.
- [ ] Avant chaque passage ou chute, un préavis visible d'au moins 1 seconde : ombre au sol pour ce qui tombe, phares ou clignotant pour ce qui passe.
- [ ] Un joueur touché par un événement meurt et réapparaît au dernier checkpoint ; le serveur compte la chute (série d'aura remise à zéro, -50 d'aura).
- [ ] Il existe toujours une façon sûre de passer : en attendant le bon moment, chaque descente se franchit sans être touché (fenêtre d'au moins 2 secondes entre deux dangers sur chaque plateforme).
- [ ] Le mouvement est fluide côté joueur, et ce qu'il voit est ce qui le touche (animé chez lui, calé sur l'horloge du serveur).
### Obstacles (ajout de l'étudiant à la validation)
- [ ] Cinq à sept obstacles « balanciers » répartis sur tout le parcours, en va-et-vient régulier comme un marteau d'obby, mais adaptés au décor : par exemple battant de portique de validation au métro, pancarte géante balancée dans le cortège, porte battante de l'amphi, cloche de l'hôtel de ville, bôme de péniche sur la Vilaine, arroseur à bras ou branche au Thabor.
- [ ] Un obstacle pousse le joueur (comme la barre tournante et le ventilateur déjà en place) ; il ne tue pas.
- [ ] Chaque obstacle laisse une fenêtre de passage d'au moins 1,5 seconde par cycle et ne bouche jamais seul le chemin.
### Bâtiments
- [ ] Les bâtiments listés reprennent leurs traits reconnaissables, étudiés sur plans et photos (silhouette, toit, rythme des fenêtres, éléments marquants) : plus de simples blocs.
- [ ] Les plateformes du parcours ne bougent pas : `outils/monde/verifier-sauts.luau` reste vert (aucun checkpoint inatteignable, aucun mortel à portée d'un saut).
- [ ] Le jeu reste fluide sur mobile : au plus 4 000 pièces pour toute la carte, décor de fond « fantôme » (sans collision).
### Textes
- [ ] L'humour brain rot reste ; plus aucune phrase condescendante sur les étudiants du type « comme ta moyenne du S1 » ou « comme ton dossier Parcoursup ».
- [ ] Les anecdotes restent des faits vrais.
### Interface
- [ ] En course, seuls restent à l'écran : l'étape (ex. 7/15), le chrono, l'aura avec la série, le bouton Recommencer, tous compacts.
- [ ] Le record et la mention « non classé » n'apparaissent qu'à l'arrivée ; « Passer l'étape » est dans un petit menu en coin.
- [ ] Les anecdotes et vannes de checkpoint sont affichées sur un panneau du décor à côté de chaque checkpoint ; à l'écran, seul le nom de la zone apparaît 2 secondes.
- [ ] Le message de chute est petit et dure 1,5 seconde ; l'écran d'arrivée est conservé.

## Décisions
Prises par l'étudiant le 2026-11-13.
| Question | Options envisagées | Choix | Raison |
|---|---|---|---|
| Événements | Objets des balcons, rame, drones, trafic ; avion qui s'écrase (déconseillé : classification d'âge) | Les quatre, sans avion | Un événement par descente |
| Effet d'un événement | Pousse le joueur ; le tue | Le tue | Plus dur et plus lisible |
| Qui anime les événements | Chaque joueur, calé sur l'horloge du serveur ; le serveur | Chaque joueur, horloge du serveur | Fluide et juste même avec du lag ; un tricheur n'y gagne rien d'autre que ne pas mourir |
| Bâtiments à refaire | Parlement, colombages, Horizons et tour, autres repères | Tous | Sortir des cubes |
| Ton des textes | Sobre ; absurde ; minimum ; brain rot | Garder le brain rot, sans phrases condescendantes | Le public aime l'humour, pas la leçon |
| À l'écran en permanence | Étape, chrono, aura et série, Recommencer | Les quatre, compacts | Moins d'informations, l'essentiel |
| Anecdotes | Dans le décor ; bandeau court ; supprimer | Dans le décor | L'écran reste libre |
| Messages de chute et arrivée | Discrets ; tels quels ; retirer les chutes | Garder, en plus discret | L'arrivée est la récompense |
| Obstacles en plus des événements | Ajouter des balanciers façon marteau adaptés au décor | Oui | Demandé à la validation de la spec |
| Effet d'un obstacle (réglage par défaut du Game Director, à revoir après essai) | Pousse ; tue | Pousse | Cohérent avec la barre tournante et le ventilateur existants |

## Contrats entre agents
- **Tag `Evenement`** sur un `Model` (ou une `BasePart`) de danger, avec les attributs :
  - `Type` : `"Passage"` (va d'un point à un autre) ou `"Chute"` (tombe d'une hauteur) ;
  - `Periode` (s), `Decalage` (s) : l'horaire, `t` étant `workspace:GetServerTimeNow()` ;
  - `Preavis` (s) : durée du préavis avant le danger ;
  - `Passage` : `Depart` et `Arrivee` (Vector3, positions du pivot), `DureePassage` (s) ;
  - `Chute` : `Hauteur` (studs au-dessus de la position posée dans la carte), `DureeChute` (s).
  - Enfant facultatif nommé `Preavis` (BasePart, ombre au sol ou lumière) : le client le fait apparaître ou clignoter pendant le préavis.
  - Dans la carte, les pièces d'un événement sont ancrées, `CanCollide = false`, `CanTouch = false` (le serveur ne s'en sert pas) ; c'est le client qui les déplace et qui détecte le contact avec son personnage.
- **Tag `PanneauAnecdote`** + attribut `Numero` (0 à 15) sur une pièce du décor à côté de chaque checkpoint, avec un `SurfaceGui` contenant un `TextLabel` nommé `Texte` : le client y écrit l'anecdote et la vanne de `src/partage/Etapes.luau`.
- **Tag `Balancier`** sur une `BasePart` ancrée dans la carte (le bras ou la masse), avec les attributs `Pivot` (Vector3, point d'accroche dans le monde), `Axe` (Vector3 unitaire, axe de rotation), `Amplitude` (degrés, de part et d'autre de la position posée), `Periode` (s, aller-retour complet), `Decalage` (s). Le serveur (`src/serveur/Obstacles.luau`) la libère et la fait osciller par contraintes physiques (comme `Tournant`), pour qu'elle pousse les joueurs ; elle n'est pas mortelle.
- **Module pur `src/partage/Horaires.luau`** : `etat(t, periode, decalage, preavis, duree) -> ("attente" | "preavis" | "actif", progression 0..1)`, testé.

## Tâches
1. **Gameplay : les événements côté client et les textes** (sonnet).
   - `src/partage/Horaires.luau` + `tests/partage/Horaires.spec.luau` (tests d'abord) ;
   - `src/client/Evenements.luau` : trouve les `Evenement`, les anime chaque image selon l'horaire, gère le préavis, détecte le contact avec le personnage local et le fait mourir (la mort doit être vue par le serveur, qui compte la chute dans `Parcours.luau`) ;
   - textes : `src/partage/Etapes.luau` (vannes) et `src/partage/Vannes.luau` (messages de chute) revus selon le ton décidé ;
   - obstacles : le type `Balancier` dans `src/serveur/Obstacles.luau`.
   Durée estimée : 50 min.
2. **World A : les bâtiments rennais** (opus). Dans `outils/monde/Parcours.luau` : Parlement, maisons à colombages, tour du parcours et Les Horizons, hôtel de ville et Opéra, portes Mordelaises, cathédrale Saint-Pierre, Champs Libres, d'après plans et photos ; plateformes inchangées ; affiches revues selon le ton. Durée estimée : 1 h 30.
3. **World B : les événements dans la carte et les panneaux d'anecdotes** (opus). Nouveau générateur `outils/monde/Evenements.luau` → `monde/Evenements.rbxm` (entrée dans `outils/monde/monde.json`) : modèles des pots et du linge, de la rame, des drones, des voitures, bus et trottinettes, avec leurs trajets et horaires selon le contrat, réglés pour toujours laisser une fenêtre sûre ; les 5 à 7 obstacles `Balancier` adaptés au décor ; panneaux `PanneauAnecdote` à côté des 16 checkpoints. Durée estimée : 1 h 10.
4. **UI : interface allégée** (sonnet). `src/client/Interface/Hud.luau` : HUD compact (étape, chrono, aura et série, Recommencer), menu en coin avec « Passer l'étape », nom de zone 2 s, message de chute discret 1,5 s, écran d'arrivée avec record et « non classé », remplissage des `PanneauAnecdote`. Durée estimée : 35 min.

Les quatre tâches partent en même temps : elles ne touchent pas les mêmes fichiers et se parlent par les contrats ci-dessus.

Durée estimée du jalon : 2 h 30 (1 h 30 pour la plus longue tâche, puis revue et vérifications 30 min, corrections 30 min).

## Vérification
- `roblox verifier`, tests Lune (dont `Horaires`), `verifier-sauts` ; compte de pièces de toute la carte ; script de simulation des horaires : sur chaque descente, il existe une fenêtre sûre d'au moins 2 s.
- **Pas d'essai en jeu possible par les agents** tant que le MCP de Studio est coupé : l'essai se fait sur l'expérience de test après fusion (publication automatique par la CI).

## Questions ouvertes
- Aucune.
