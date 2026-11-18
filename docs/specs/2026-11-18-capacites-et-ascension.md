# Capacités de déplacement et ascension après Sup de Vinci

Statut : en cours (relue deux fois, PR #6 ; essai en jeu sur l'expérience de test après fusion)
Date : 2026-11-18

## Besoin
Le parcours de Rennes devient le **tutoriel** : il apprend au joueur trois capacités, une par une. Arrivé à Sup de Vinci, il entre dans le vrai jeu : une **ascension non-stop** dans un empilement chaotique de bâtiments et d'objets qui flottent au-dessus de la ville. Tomber renvoie tout en bas, mais les **paliers** atteints restent acquis et on peut y revenir. Le jeu devient plus nerveux et plus vertical.

## Périmètre
- Dedans :
  - trois capacités : **course** (maintenir Maj), **double saut** avec saut périlleux, **dash avant** ;
  - leur **déblocage progressif dans le tuto**, chacune enseignée par un passage fait pour elle ;
  - l'**ascension** : bâtiments et objets flottants au-dessus de Sup de Vinci, 4 à 5 paliers ;
  - **téléportation** vers un palier déjà atteint ;
  - **aura par étage** qui augmente avec la hauteur, **classement de la hauteur**, **chrono de l'ascension** et son classement ;
  - surveillance serveur des déplacements ;
  - l'interface : capacités disponibles, hauteur, chrono, menu de téléportation.
- Hors périmètre (jalon suivant) : **la boutique des paliers** et les cosmétiques (queue, aura autour du personnage, skin, titre, familier). Les paliers sont construits avec l'emplacement de la boutique, vide pour l'instant.
- Hors périmètre aussi : vraie animation de saut périlleux (rotation par le code), sons sur mesure, refonte du tuto au-delà des trois passages d'apprentissage.

## Critères d'acceptation
### Capacités
- [ ] **Course** : en maintenant Maj (ou le bouton tactile), le joueur se déplace à environ 1,5 fois sa vitesse normale ; le champ de vision s'élargit légèrement ; aucune limite de durée, aucune barre d'endurance. Relâcher revient à la vitesse normale.
- [ ] **Double saut** : une fois en l'air, un second saut est possible ; le personnage fait un tour complet sur lui-même (rotation calculée par le code) ; il ne se recharge qu'au contact du sol.
- [ ] **Dash avant** : la touche marquée A (soit `KeyCode.Q` côté Roblox) propulse le joueur horizontalement dans la direction où il regarde, au sol comme en l'air ; une seule fois par envol, rechargé au contact du sol.
- [ ] Les trois capacités fonctionnent au clavier, à la manette et au tactile ; les boutons tactiles ne recouvrent ni le saut ni le joystick.
- [ ] Une capacité non débloquée ne fait rien et n'affiche aucun bouton.
### Déblocage dans le tuto
- [ ] Le joueur débloque la **course** au métro, le **double saut** à la tour, le **dash** à la Vilaine ; chaque déblocage est annoncé à l'écran et suivi d'un passage qui ne se franchit qu'avec cette capacité.
- [ ] Les déblocages sont **sauvegardés** : un joueur qui revient les garde.
- [ ] Le parcours du tuto reste franchissable de bout en bout (contrôle des sauts toujours vert).
### Ascension
- [ ] Depuis l'arrivée à Sup de Vinci, un départ d'ascension est accessible et clairement indiqué.
- [ ] L'ascension est un empilement de bâtiments et d'objets flottants, sans logique réaliste, qui monte sur au moins 250 studs et demande les trois capacités.
- [ ] **4 à 5 paliers**, tous les 60 studs environ. Atteindre un palier le débloque **définitivement**.
- [ ] Entre deux paliers, **aucun checkpoint** : tomber renvoie **au pied de l'ascension**.
- [ ] Depuis le pied de l'ascension et depuis tout palier, le joueur peut **se téléporter vers n'importe quel palier déjà débloqué**.
- [ ] Chaque étage franchi rapporte de l'aura, **d'autant plus que l'étage est haut**.
- [ ] La **hauteur maximale atteinte** est sauvegardée, affichée, et classée dans un tableau mondial.
- [ ] Le **chrono de l'ascension** part au pied de la tour et s'arrête au sommet ; le meilleur temps est classé. Une téléportation vers un palier rend la tentative non classée.
### Anti-triche
- [ ] Le serveur surveille la vitesse horizontale et verticale, et le nombre de sauts : un joueur qui monte plus vite que le maximum possible est ramené à sa dernière position valide, et sa tentative n'est pas classée.
- [ ] La téléportation ne fonctionne que vers un palier réellement débloqué, pas plus d'une fois toutes les 2 secondes.

## Décisions
Prises par l'utilisateur le 2026-11-18.
| Question | Options envisagées | Choix | Raison |
|---|---|---|---|
| Forme de l'ascension | Tour à étages thématiques ; tour générée infinie ; montée libre | **Bâtiments et objets qui flottent, sans logique imparable** (esprit Only Up) | Le but est de sauter, pas de raconter |
| Chute pendant l'ascension | Dernier palier ; tout en bas ; début de l'étage | **Tout en bas**, mais téléportation possible vers un palier débloqué | La tension reste entière, sans obliger à tout refaire |
| Paliers | Fréquence et rôle | **4 à 5, tous les ~60 studs**, acquis définitivement, avec l'emplacement d'une boutique | Respirations rares, et base du jalon suivant |
| Déblocage des capacités | Une par une dans le tuto ; toutes à l'arrivée ; toutes au début | **Une par une dans le tuto** | Le tuto garde son rôle, on apprend une chose à la fois |
| Récompenses de l'ascension | Aura par étage ; classement de hauteur ; chrono ; bonus au sommet ; boutiques | **Aura croissante par étage, classement de hauteur, chrono, boutiques aux paliers** | Plusieurs raisons de revenir |
| Découpage | Un jalon ; deux jalons | **Deux jalons** : capacités et ascension d'abord, boutique ensuite | Pouvoir régler le ressenti des sauts avant d'ajouter la boutique |
| Saut périlleux | Rotation par le code ; vraie animation envoyée ; code puis animation | **Rotation par le code** | Rien à envoyer, lisible tout de suite |
| Déplacements et triche | Client bouge, serveur surveille ; surveillance minimale | **Client bouge, serveur surveille** | Fluide sans délai réseau, et le classement reste honnête |
| Course | Maj sans limite ; Maj avec endurance ; automatique | **Maj, sans limite**, ~1,5× la vitesse, champ de vision élargi | Nerveux, jamais punitif, pas de barre en plus |
| Dash | Sol et air, 1 par envol ; sol seulement ; air avec recharge à temps | **Sol et air, une fois par envol**, rechargé au sol | Ouvre de vraies trajectoires avec le double saut |
| Double saut | Recharge au sol ; recharge aussi au mur | **Au sol seulement** | Règle attendue des joueurs, sauts lisibles |
| Touche du dash | Touche marquée A (`KeyCode.Q`) ; E ou clic droit | **Touche marquée A**, soit `KeyCode.Q` | Ce que l'utilisateur voulait physiquement, sans gêner ZQSD |
| Accès au pied de l'ascension (décision d'agent) | Verrière dans le toit de Sup de Vinci ; redescendre et ressortir par la porte | **Verrière dans le toit**, 3 ou 4 sauts depuis la mezzanine | On sort du partiel par le toit : bien plus fort après le climax du tuto |
| « Recommencer » refermait l'ascension (décision d'agent) | Champ `tutoFini` sauvegardé ; porte élargie sans champ ; ne rien changer | **Champ `tutoFini`** posé par `Parcours.terminer`, rempli par `migrer` pour les joueurs existants | Un bouton du tuto ne doit pas fermer le jeu principal ; `etape` est remis à 0 par conception |
| Aura après une téléportation (décision d'agent) | Rien du tout ; payer les étages au-dessus du palier d'arrivée | **Payer les étages au-dessus du palier d'arrivée** | Pas de ferme d'aura, mais grimper reste récompensé |
| Plafond de la surveillance trop large (revue) | Fenêtre glissante plus longue ; bonus de saut au décollage seulement ; ne classer la hauteur qu'au sol | **Fenêtre glissante de 2 à 3 s** | Resserre sans faux positif ; le bonus de saut cesse d'être recompté à chaque fenêtre |
| Ferme d'aura au sommet, 1,5× (revue) | Laisser ; un étage payé une fois par partie ; payer au palier | **Laisser** | Boucle répétitive et écart modéré ; à revoir sur les chiffres réels après la sortie |
| ButtonB partagé dash / fermeture du menu (revue) | Déplacer la fermeture du menu ; dash prioritaire | **Fermeture du menu sur un autre bouton** (Select), B reste le dash | Le dash sert en permanence |
| « Recommencer » pendant l'ascension (décision d'agent) | Renvoyer au tuto ; deux boutons séparés ; laisser tel quel | **Renvoyer au tuto** : ferme la tentative d'ascension et replace le joueur à la coloc | Cohérent avec le mot ; les paliers restent acquis |
| Attribut `Hauteur` des paliers (contrat ambigu) | Absolu ; au-dessus du pied | **`Hauteur` reste le Y absolu, `HauteurRelative` est la hauteur au-dessus du pied** ; l'interface et le serveur lisent `HauteurRelative` | La carte fournit déjà les deux ; c'est la hauteur gagnée qu'on montre au joueur |

## Contrats entre agents
À respecter à la lettre : chaque agent code contre ces noms sans attendre les autres.

### Réglages (`src/partage/Reglages.luau`, ajouts)
`COURSE_FACTEUR` (1.5), `COURSE_FOV_BONUS` (10), `DASH_VITESSE`, `DASH_DUREE`, `SAUT_DOUBLE_FACTEUR`, `VRILLE_DUREE`, `ASCENSION_AURA_BASE`, `ASCENSION_AURA_PAR_ETAGE`, `PALIER_DELAI_TELEPORT` (2), `SURVEILLANCE_MARGE` (marge de tolérance de vitesse), `SURVEILLANCE_PERIODE`.

### Module pur `src/partage/Capacites.luau`
- `type Capacite = "course" | "doubleSaut" | "dash"` ;
- `estDebloquee(donnees, capacite) -> boolean` ;
- `vitesseMax(capacites, enCourse) -> number` : la vitesse horizontale maximale **possible** avec les capacités débloquées (sert au client et à la surveillance serveur) ;
- `monteeMax(capacites, duree) -> number` : la montée maximale possible en `duree` secondes (sauts, double saut, dash).
Testé.

### Module pur `src/partage/Ascension.luau`
- `auraEtage(numeroEtage, bareme) -> number` : croissante avec la hauteur ;
- `palierPour(hauteur, paliers) -> number` ;
- `estClassable(tentative) -> boolean` (aucune téléportation, aucune alerte de surveillance) ;
- `formaterHauteur(studs) -> string` (« 182 m », 1 stud ≈ 0,28 m : arrondi lisible).
Testé.

### Données du joueur (`src/partage/Regles.luau`, migration incluse)
Ajouts : `capacites: { [string]: boolean }`, `paliers: { number }`, `meilleureHauteur: number`, `meilleurTempsAscension: number`. `Regles.migrer` les remplit pour un joueur existant (aucune capacité, aucun palier, 0).

### Remotes (`src/partage/Remotes.luau`)
- serveur → client : `CapaciteDebloquee(capacite: string)`, `EtatAscension(etat)` avec `{ enAscension, hauteur, meilleureHauteur, paliers, debut, classable }` ;
- client → serveur : `DemanderTeleportPalier(numero: number)`.
`EtatCourse` garde sa forme et gagne `capacites`.

### Tags de la carte
- `DeblocageCapacite` + attribut `Capacite` (`"course"`, `"doubleSaut"` ou `"dash"`) : pièce à toucher qui débloque la capacité ;
- `PiedAscension` : la plateforme de départ de l'ascension (point de renvoi en cas de chute) ;
- `Palier` + attribut `Numero` (1 à 5) + attribut `Hauteur` : plateforme de palier ; un enfant `Boutique` (Model vide) marque l'emplacement de la boutique du jalon suivant ;
- `EtageAscension` + attribut `Numero` : pièce à toucher qui compte un étage franchi (pour l'aura) ;
- `SommetAscension` : l'arrivée.
- Le `Mortel` existant sous la ville sert de détecteur de chute pendant l'ascension.

### Classements (`src/serveur/Classement.luau`)
Deux nouveaux : `STORE_HAUTEUR` et `STORE_ASCENSION`, affichés sur les panneaux tagués `TableauHauteur` et `TableauAscension` (construits au pied de l'ascension).

## Tâches
Les cinq partent **en même temps** : elles ne touchent pas les mêmes fichiers et se parlent par les contrats ci-dessus.

1. **Gameplay A — les capacités** (`sonnet`) : `src/partage/Capacites.luau` + tests ; `src/client/Capacites.luau` (entrées clavier, manette et tactile, course, double saut avec vrille par le code, dash) ; `src/serveur/Capacites.luau` (déblocages par le tag `DeblocageCapacite`, sauvegarde, remote `CapaciteDebloquee`, surveillance des vitesses et retour à la dernière position valide). Durée estimée : 50 min.
2. **Gameplay B — l'ascension** (`opus`) : `src/partage/Ascension.luau` + tests ; `src/serveur/Ascension.luau` (paliers, étages, aura croissante, hauteur maximale, chrono, téléportation validée, chute vers le pied) ; champs de données et migration dans `Regles.luau` ; deux classements dans `Classement.luau`. Durée estimée : 50 min.
3. **World A — les déblocages dans le tuto** (`opus`) : dans `outils/monde/Parcours.luau`, trois passages d'apprentissage, chacun précédé de sa pièce `DeblocageCapacite` : course au métro (un écart trop long pour un saut debout), double saut à la tour (un vide infranchissable d'un seul saut), dash à la Vilaine (un écart horizontal large). Le parcours reste franchissable : `verifier-sauts` doit rester vert, en tenant compte des capacités débloquées à ce point du parcours. Durée estimée : 40 min.
4. **World B — la tour d'ascension** (`opus`) : nouveau générateur `outils/monde/Ascension.luau` → `monde/Ascension.rbxm` (entrée dans `monde.json`) : au-dessus de Sup de Vinci, un empilement chaotique de morceaux de bâtiments, panneaux, bus, grues, meubles, galettes géantes… qui flottent ; au moins 250 studs de haut ; 4 à 5 paliers tous les ~60 studs avec l'emplacement de boutique ; pied de l'ascension avec ses deux tableaux ; étages tagués. Durée estimée : 1 h 10.
5. **UI — l'interface de l'ascension** (`sonnet`) : dans `src/client/Interface/`, les icônes des capacités disponibles (et leur recharge), l'annonce d'un déblocage, la hauteur et le chrono pendant l'ascension, le menu de téléportation vers un palier, et le rappel « non classé » après une téléportation. Reste compact, dans l'esprit du HUD actuel. Durée estimée : 40 min.

Durée estimée du jalon : 2 h 30 (vague la plus longue 1 h 10, revue et vérifications 30 min, corrections 40 min).

## Vérification
`roblox verifier`, tests Lune, `verifier-sauts` (tuto **et** ascension, en tenant compte des capacités), `verifier-evenements`, nombre de pièces (≤ 5 000 pour toute la carte). **Aucun essai en jeu possible par les agents** (MCP de Studio coupé) : l'essai se fait sur l'expérience de test après fusion.

## Questions ouvertes
- Aucune.
