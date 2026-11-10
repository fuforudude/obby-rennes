# Obby Rennes : « Partiel maintenu »

## Le concept
Un obby (parcours d'obstacles Roblox) pour les étudiants rennais. Rennes 2 est bloquée, le métro est en grève, les poubelles s'entassent en barricades… mais ton partiel à **Sup de Vinci**, lui, est maintenu. Traverse Rennes de ta coloc à Villejean jusqu'à la salle de partiel.

Ton : **satire du quotidien étudiant**, sans prendre parti. Pas de police, pas de lacrymo, pas de slogan politique réel : les banderoles parlent de pauses café, de prises électriques et de partiels à 8 h. Ce choix évite que Roblox classe le jeu 17+ ou le retire.

## La boucle de jeu
1. Le joueur apparaît dans sa coloc ; le chrono part.
2. Il saute d'obstacle en obstacle ; chaque checkpoint touché est sauvegardé et affiche une anecdote sur Rennes.
3. Il tombe ou touche un obstacle mortel : il réapparaît au dernier checkpoint.
4. Une étape trop dure : il peut la passer contre quelques Robux.
5. À l'arrivée : son temps, son record, et le classement mondial des 10 meilleurs temps.
6. Il revient pour battre son temps (bouton « Recommencer »).

## L'aura, la mécanique centrale
- Chaque checkpoint rapporte **100 × la série**, la série étant le nombre de checkpoints enchaînés sans tomber (multiplicateur plafonné à ×10).
- **Une chute** remet la série à zéro et coûte 50 d'aura (jamais en dessous de 0).
- **L'arrivée** rapporte 1 000, plus **5 000** pour un parcours entier sans tomber, sans étape payée et sans reprise.
- Une étape passée en Robux ne rapporte rien et casse la série : **pas d'aura achetée**.
- L'aura est **cumulée et sauvegardée** : on revient pour en gagner plus. Elle est comptée par le serveur (le client ne fait qu'afficher).
- **Classement mondial « Plus grosse aura »** (panneaux au départ et à l'arrivée) et colonne **Aura** dans la liste des joueurs.
- Ordre de grandeur : un parcours parfait vaut 100 × (1+2+…+10) + 100 × 10 × 5 + 6 000 = 16 500 d'aura. Les valeurs sont dans `src/partage/Reglages.luau`.

## Les références
Tout le parcours est truffé de références, à trois endroits :
- **Les textes** : à chaque checkpoint, une anecdote vraie sur Rennes et une vanne (brain rot, sarcasme étudiant) ; une vanne à chaque chute (« Skill issue. », « Le jus de poubelle t'a ratio. »…).
- **La ville** : hôtel de ville et son horloge bloquée sur 8:00, portes Mordelaises, Champs Libres, cathédrale Saint-Pierre, tours Les Horizons, Roazhon Park derrière le départ, bus STAR « EN GRÈVE », nuage de crachin au-dessus de la Vilaine.
- **Les affiches** au bord du chemin : studio 9 m² à 690 €, Moodle en maintenance, eduroam déconnecté, Parcoursup en attente, RU sans frites, Transmusicales complètes, galette-saucisse à 5 €…
- **Deux mascottes brain rot maison** (personnages originaux) : **Galettino Saucissino** (galette-saucisse géante à lunettes, près du cortège) et **Kouign Amannini** (kouign-amann couronné, au bord de la Vilaine).

## Les 15 étapes
| Étape | Zone | Ce qu'on y fait |
|---|---|---|
| 0 | La coloc à Villejean | Départ, chrono lancé |
| 1-2 | Fac bloquée | Tables, chaises empilées, piles de copies qui s'effondrent |
| 3-4 | Métro en grève | Sauter de rame en rame, une rame qui bouge quand même, l'escalator à l'arrêt |
| 5-6 | Cortège place de la République | Banderoles qui bougent, pancartes, le camion sono qui te porte |
| 7-8 | Barricades de poubelles | Bacs et cartons au-dessus du jus de poubelle (mortel), grande barricade à escalader |
| 9-10 | Rue de la Soif | Sauts de toit en toit sur les maisons à colombages, enseigne de bar qui tourne |
| 11-12 | La Vilaine | Pontons, péniche qui dérive, bouées ; l'eau est mortelle |
| 13 | Parlement de Bretagne | Colonnes de plus en plus étroites |
| 14 | Le Thabor | Haies au-dessus de la pelouse interdite (mortelle) |
| 15 | Sup de Vinci | Arrivée en salle de partiel |

## Direction artistique
Reprise des règles de genre des obbys qui marchent, adaptées à Rennes (sans copier un jeu précis) :
- **Le chemin se lit d'un coup d'œil** : tout ce qui se marche est saturé et cerné de la couleur de sa zone ; le décor de fond est en teintes douces.
- **Une couleur par zone** (arche du checkpoint, contours) : on sait où on est et on voit qu'on avance.
- **Ce qui tue est toujours cerné de rouge vif** (jus de poubelle, Vilaine, pelouse interdite).
- **Checkpoints très visibles** : dalle lumineuse, grand numéro, arche néon avec le nom de la zone.
- **Rennes en fond** : rues, arbres, lampadaires, immeubles avec fenêtres, tours Les Horizons, cathédrale Saint-Pierre, drapeaux bretons, palais du Commerce, Parlement.
- **Éclairage doux d'après-midi** : ombres claires, couleurs légèrement relevées, halo discret sur le néon, brume qui détache le fond (`Lighting` dans `default.project.json`). Confettis à l'arrivée.

## Règles
- Un checkpoint ne compte que s'il est **le suivant** : on ne saute pas d'étapes en coupant.
- Le checkpoint atteint est **sauvegardé** : en revenant, on reprend là où on était.
- Le **classement** ne retient que les parcours faits d'une traite : sans étape passée et sans reprise d'une ancienne partie.
- **Passer l'étape** : produit développeur Robux (prix fixé dans le Creator Hub). Un parcours avec passage n'est pas classé.

## Ce qui est sauvegardé
Par joueur : étape atteinte, meilleur temps, achats déjà traités (pour ne jamais donner deux fois un passage). Classement : meilleur temps de chaque joueur (OrderedDataStore).

## Appareils
Ordinateur, mobile et tablette : interface en proportions, boutons assez grands pour le doigt.

## Prochains jalons possibles
Plus d'étapes (Champs Libres, Roazhon Park, marché des Lices), cosmétiques (galette-saucisse sur la tête), mode chrono par zone, badges.
