# Tour exigeante : effets de capacités, obstacles, pièges, difficulté maximale

Statut : validée
Date : 2026-11-18

## Besoin
Après l'essai en jeu : le dash et le double saut ne servent à rien, parce que toutes les plateformes se franchissent d'un saut simple, et ils n'ont **aucun effet visible**. La tour doit devenir une vraie épreuve qui exige les trois capacités en permanence, peuplée d'obstacles et de pièges, et chaque capacité doit se voir et se sentir.

## Périmètre
- Dedans :
  - **effets visuels et sonores du dash et du double saut**, faits par le code, avec des emplacements prêts pour de vraies animations plus tard ; la vrille devient visible par les autres joueurs ;
  - **refonte complète de la tour** : même hauteur (258 studs), difficulté maximale partout, **aucun palier** ;
  - **six familles d'obstacles** dans la tour : pièges de mur, plateformes mobiles, barres tournantes, plateformes qui s'effondrent, pancartes qui basculent (pendules), rayons laser ;
  - **durcissement des passages du tuto situés après chaque déblocage** (le début reste accessible aux nouveaux) ;
  - **suppression du système de paliers** : tag, téléportation, menu, remote.
- Hors périmètre : la boutique (jalon suivant, elle ira **au pied de l'ascension** puisqu'il n'y a plus de paliers), les vraies animations Roblox (à créer et envoyer par l'utilisateur), de nouvelles capacités.

## Critères d'acceptation
### Effets des capacités
- [ ] **Dash** : le corps se penche en avant, une traînée suit le personnage, des lignes de vitesse passent, le champ de vision s'élargit d'un coup puis revient, et un petit choc marque l'arrivée. L'effet est **visible par les autres joueurs**.
- [ ] **Double saut** : la vrille complète est **visible par les autres joueurs** (aujourd'hui elle est locale) ; une onde de choc part sous les pieds au déclenchement ; une traînée suit la rotation.
- [ ] **Course** : l'effet actuel (champ de vision) est complété par une légère traînée au sol.
- [ ] Le code prévoit des emplacements d'identifiants d'animation Roblox (`ANIMATION_DASH`, `ANIMATION_DOUBLE_SAUT`, vides pour l'instant) : s'ils sont remplis, l'animation remplace la rotation calculée, sans autre changement.
- [ ] Aucun effet ne coûte plus que quelques pièces temporaires, détruites à la fin ; rien ne fuit si le personnage meurt en plein dash.
### La tour
- [ ] Hauteur **258 studs**, **aucune pièce taguée `Palier`**, aucun checkpoint entre le pied et le sommet. Tomber renvoie au pied.
- [ ] **Difficulté maximale partout** : un contrôle automatique vérifie qu'aucun chemin du pied au sommet n'existe **sans le dash**, ni **sans le double saut**, ni **sans la course**, *dans le modèle prudent* (voir « Révision du 2026-11-19 » : c'est un critère de difficulté, pas une preuve de nécessité ; la nécessité est garantie par le tuto, qu'il faut avoir fini pour entrer dans la tour).
- [ ] Les limites restent tenables : aucun saut au-delà de 16 studs de vide ni 9 studs de montée, les deux liés.
- [ ] Les six familles d'obstacles sont présentes, réparties sur toute la hauteur, de plus en plus denses.
- [ ] Un contrôle vérifie que chaque obstacle laisse une **fenêtre de passage d'au moins 1,2 s** par cycle, et qu'aucun ne bloque seul le chemin.
### Obstacles et pièges
- [ ] **Pièges de mur** : une pointe ou une barre sort du mur quand le joueur approche, et le **pousse fort** (elle ne tue pas). Seul indice avant déclenchement : une fente et une trace d'usure dans le mur.
- [ ] **Rayons laser** : balayage régulier, rythme fixe et apprenable, **tuent au contact** (retour au pied).
- [ ] **Plateformes qui s'effondrent** : elles tombent 0,5 s après le premier contact et reviennent après quelques secondes.
- [ ] **Pancartes qui basculent** : grands pendules qui barrent le passage et poussent fort.
- [ ] **Plateformes mobiles** et **barres tournantes** : comme dans le tuto, mais plus rapides.
### Le tuto
- [ ] Les passages situés **après** chaque déblocage sont durcis pour exiger vraiment la capacité (écarts et montées proches des limites de la capacité concernée). Les étapes 0 à 2, avant le premier déblocage, ne changent pas.
- [ ] `verifier-sauts` reste vert, en tenant compte des capacités acquises à chaque point du parcours.
- [ ] **Aucun chemin n'existe jusqu'au dernier checkpoint sans la course, sans le dash ou sans le double saut, en physique réelle** (voir « Révision du 2026-11-19 »).

## Décisions
Prises par l'utilisateur le 2026-11-18.
| Question | Options envisagées | Choix | Raison |
|---|---|---|---|
| Animations | Effets par le code ; vraies animations à créer ; code puis animations | **Effets par le code maintenant, emplacements prêts pour de vraies animations ensuite** | Visible tout de suite, sans bloquer sur un travail d'animation |
| Où durcir | Tour surtout + tuto un peu ; tour seulement ; tout | **Tour surtout, tuto seulement après les déblocages** | Les nouveaux joueurs gardent un début accessible |
| Effet des pièges | Poussent fort ; tuent | **Poussent fort** | Récompense le réflexe (dash ou double saut de rattrapage) |
| Préavis des pièges | Indice discret ; préavis net ; rien | **Indice discret** (fente, usure) | C'est le principe du piège |
| Obstacles de la tour | — | **Les six** : pièges de mur, plateformes mobiles, barres tournantes, plateformes qui s'effondrent, pancartes qui basculent (pendules), rayons laser | Demande de l'utilisateur |
| Niveau d'exigence | Chaque tranche exige une capacité ; tout au maximum ; quelques sauts clés | **Tout au maximum** | La tour doit être une épreuve |
| Paliers | Les supprimer ; en mettre davantage | **Les supprimer, aucun palier** | Chute totale, tension maximale. Conséquence : la boutique ira au pied de l'ascension |
| Hauteur | 179 studs (50 m) ; garder 258 ; 50 studs | **Garder 258 studs** | Même hauteur, entièrement refaite |
| Lasers | Balayage régulier ; intermittents ; déclenchés au passage | **Balayage régulier**, tuent au contact | Rythme apprenable, cohérent avec les autres obstacles |

## Contrats entre agents
### Nouveaux tags de la carte
- **`PiegeMur`** sur un `Model` : attributs `Direction` (Vector3 unitaire, sens de sortie), `Distance` (studs), `DureeSortie` et `DureeRentree` (s, **durées des deux mouvements** : la pointe frappe pendant les deux), `Repos` (s, le temps rentré avant de pouvoir repartir — **c'est la fenêtre de passage**, 1,2 s au moins ; la carte le pose toujours, sinon `Reglages.PIEGE_REPOS` s'applique en silence), `Portee` (studs, rayon de déclenchement), `Poussee` (studs/s, facultatif : `PIEGE_POUSSEE` par défaut, raboté par le serveur à `PIEGE_POUSSEE_MAX` = 65 pour rester sous `DASH_VITESSE`). Enfant `Pointe` (BasePart, la partie qui sort). Le serveur la fait sortir quand un joueur entre dans la portée, et applique l'impulsion au contact.
- **`Laser`** sur une `BasePart` : attributs `Depart`, `Arrivee` (Vector3 absolus), `Periode`, `Decalage` (s). Balayage aller-retour régulier calé sur `workspace:GetServerTimeNow()`. **Mortel au contact.** Même principe d'horaire que `src/partage/Horaires.luau` (réutilise-le).
- **`Effondrable`** sur une `BasePart` : attributs `DelaiChute` (s, défaut 0,5) et `DelaiRetour` (s). Au premier contact, elle tombe puis revient.
- **`Balancier`** (existant) gagne l'attribut facultatif `Poussee` (multiplicateur de force, défaut 1) : les pancartes qui basculent l'utilisent.
- **Supprimés** : `Palier`, `TableauHauteur` et `TableauAscension` restent (les classements ne changent pas).
### Réglages (`src/partage/Reglages.luau`)
`PIEGE_POUSSEE`, `PIEGE_PORTEE`, `EFFONDRABLE_DELAI`, `EFFONDRABLE_RETOUR`, `DASH_TRAINEE_DUREE`, `VRILLE_ONDE_DUREE`, `ANIMATION_DASH` (""), `ANIMATION_DOUBLE_SAUT` ("").
### Remote
`EffetCapacite(joueur: Player, capacite: string)` serveur → **tous les clients** : permet de jouer l'effet (vrille, traînée, onde) sur le personnage d'un **autre** joueur. Le client qui déclenche l'effet le joue en local tout de suite et prévient le serveur par `SignalerEffet(capacite)`, validé en cadence comme `ToucheParEvenement`.
### Suppression du système de paliers
Le tag `Palier`, le remote `DemanderTeleportPalier`, `src/client/Interface/MenuPaliers.luau`, l'entrée « Paliers » du menu en coin et le champ `paliers` des données disparaissent. `Regles.migrer` doit continuer d'accepter d'anciennes données qui contiennent `paliers` **sans planter** (on l'ignore). L'aura n'a plus de seuil lié à un palier : tous les étages paient, sauf après une alerte de surveillance.

## Tâches
Les cinq partent en même temps.
1. **Gameplay A — effets des capacités** (`sonnet`) : `src/client/Capacites.luau` (traînée, lignes de vitesse, penché, onde de choc, choc d'arrivée), réplication par `EffetCapacite` / `SignalerEffet` (`src/partage/Remotes.luau`, `src/serveur/Capacites.luau`), emplacements d'animation. Durée estimée : 45 min.
2. **Gameplay B — nouveaux obstacles et retrait des paliers** (`opus`) : `src/serveur/Obstacles.luau` (`PiegeMur`, `Laser`, `Effondrable`, `Poussee` sur `Balancier`), règles pures et tests ; suppression du système de paliers côté serveur et données (`src/serveur/Ascension.luau`, `src/partage/Ascension.luau`, `src/partage/Regles.luau`, `src/partage/Remotes.luau`). Durée estimée : 50 min.
3. **World A — refonte de la tour** (`opus`) : `outils/monde/Ascension.luau`, 258 studs, aucun palier, difficulté maximale, les six familles d'obstacles réparties et de plus en plus denses ; `outils/monde/verifier-ascension.luau` : contrôle « aucun chemin sans dash / sans double saut / sans course » et « fenêtre de passage ≥ 1,2 s par obstacle ». Durée estimée : 1 h 15.
4. **World B — durcissement du tuto** (`opus`) : `outils/monde/Parcours.luau`, les passages après chaque déblocage portés près des limites de la capacité concernée ; étapes 0 à 2 inchangées ; `verifier-sauts` vert. Durée estimée : 30 min.
5. **UI — retrait du menu des paliers** (`sonnet`) : `src/client/Interface/` (suppression de `MenuPaliers.luau` et de l'entrée du menu, nettoyage de `Affichage.luau` et de ses tests, l'écran d'ascension ne montre plus de paliers). Durée estimée : 20 min.

Durée estimée du jalon : 2 h 45 (vague la plus longue 1 h 15, revue 30 min, corrections 1 h).

## Vérification
`roblox verifier`, tests Lune, `verifier-sauts`, `verifier-ascension` (nouveaux contrôles), `verifier-evenements`, carte ≤ 5 000 pièces. **Aucun essai en jeu possible par les agents** (MCP de Studio coupé) : l'essai se fait sur l'expérience de test après fusion.

## Risque assumé
Une tour de 258 studs en difficulté maximale, **sans aucun checkpoint**, avec six familles d'obstacles : très peu de joueurs la termineront. C'est le choix de l'utilisateur (esprit Only Up). À revoir après son essai, quand on connaîtra le temps réel d'une montée complète.

## Révision du 2026-11-19 : des portes vraiment infranchissables

Demande de l'utilisateur après relecture : les portes de capacité doivent être infranchissables **en jeu**, pas seulement dans le modèle de contrôle.

### Deux modèles, deux questions
| Modèle | Question à laquelle il répond | Où il vit |
|---|---|---|
| **Prudent** (montée 4,5 / vide 6,5 à l'arrêt, × 1,5 en courant, +8 au dash, 9 en double saut) | « ce saut est-il confortable ? » | `verifier-sauts.luau`, `verifier-ascension.luau`, `Ascension.luau`. **Inchangé** : la marge de sécurité est voulue. |
| **Physique réelle** (tout ce que le moteur permet) | « ce vide est-il infranchissable sans telle capacité ? » | `outils/monde/physique.luau`, utilisé **uniquement** pour la preuve de stricte nécessité. |

`physique.luau` ne recopie rien : il charge `src/partage/Capacites.luau` (donc `PHYSIQUE_DEFAUT` : JumpHeight 7,2, gravité 196,2, marche 16) et `src/partage/Reglages.luau` (`COURSE_FACTEUR`, `DASH_VITESSE`, `DASH_DUREE`, `SAUT_DOUBLE_FACTEUR`). Changer l'un de ces réglages change le verdict des contrôles au lieu de les laisser mentir.

Dérivation : v0 = √(2 g h) = 53,153 studs/s ; vol d'un saut simple à plat 2 v0/g = **0,5418 s** ; vol d'un double saut à plat **1,0836 s** (et non 0,9250 s : le second saut *impose* la vitesse v0 à n'importe quel moment du vol, donc on le déclenche en repassant par la hauteur d'arrivée et on colle deux arcs complets, au lieu de le déclencher au sommet) ; en général, pour se poser *m* studs plus haut, T = 2 (v0 + √(v0² − g m)) / g avec le double saut, (v0 + √(v0² − 2 g m)) / g sans. Portée = vitesse au sol × T, plus le gain d'un dash (`extensionDash`, 70 × 0,2 − v × 0,2). Deux studs de marge de bord sont **offerts au joueur** avant de déclarer un vide infranchissable.

### Plafonds réels, par jeu de capacités
| Capacités en main | Vide à plat | Vide en montant de 4 | Montée |
|---|---|---|---|
| aucune | 8,67 | 7,22 | 7,2 |
| course | 13,00 | 10,84 | 7,2 |
| double saut | 17,34 | 16,04 | 14,4 |
| dash | 19,47 | 18,02 | 7,2 |
| course + dash | 22,20 | 20,04 | 7,2 |
| course + double saut | 26,01 | 24,06 | 14,4 |
| double saut + dash | 28,14 | 26,84 | 14,4 |
| les trois | 35,21 | 33,26 | 14,4 |

Conséquence directe : **aucune porte de dash ne peut tenir après le déblocage du double saut** (26 studs de portée réelle contre 17,75 au plus dans le modèle de confort : la fenêtre est vide). L'ordre des déblocages devient **course (zone 2) → dash (zone 4) → double saut (zone 4)**.

### Ce qui change sur la carte
| Porte | Avant | Après | Pourquoi |
|---|---|---|---|
| Course : le parvis du métro | 8 studs à plat vers une banderole mobile | **inchangé en difficulté** (8 studs en montant de 1), mais la banderole d'arrivée est **tendue** (fixe) | le premier saut du jeu doit accueillir un débutant. Il se passe en marchant si on insiste (8,67 studs de portée réelle) et c'est assumé : il n'y a **pas de porte de course dédiée** ici. Fixe plutôt que mobile : le premier saut après un déblocage apprend la capacité, pas le minutage d'une cible qui bouge. |
| Course : le troisième saut du cortège (`3_Cortege/Banderole` → `Pancarte`) | 8 studs en montant de 2, pancarte de 2 × 2 | **9,5 studs en montant de 4,5**, pancarte élargie à 4 × 10 | c'est lui qui rend la course obligatoire. La course multiplie la portée par 1,5 exactement, comme le modèle prudent : la seule fenêtre possible est un saut qui monte au maximum (sans course 8,99 marge comprise, modèle prudent 9,75), large de 0,76 stud. Volontairement le saut le plus exigeant que le confort accepte ; en portée réelle il ne vaut que 72 % de ce qu'un joueur qui court sait faire. Placé en troisième et non en premier pour qu'on l'aborde en ayant déjà senti ce que la course change. |
| Dash | `6_LaVilaine/PontonDuDash`, 16 studs à plat, **après** le double saut | déplacé en `4_LaTour/TremplinDuDash`, **avant** le double saut : 16,5 studs en montant de 3, d'un seul bond au-dessus du jus de poubelle (les deux bacs du milieu disparaissent, deux bacs mortels les remplacent) | avec la course seule la portée réelle est de 13 (15 avec la marge) et le confort autorise 17,75 avec le dash : la fenêtre existe ici et nulle part après. Le saut de la Vilaine reste, il **exige** toujours le dash et c'est le seul saut qui exige encore la course une fois le dash en main. |
| Double saut (`4_LaTour/BalconDuDoubleSaut`) | balcons 10 et 11 à 53,5 (montée de 7) | **54,5 (montée de 8)** | un saut simple monte vraiment de 7,2 studs, pas de 4,5. Le balcon 11 montait aussi : à 53,5 il était à 7 studs du balcon 9, donc atteignable en diagonale. |
| Échafaudages de la tour (descente) | `CX+26/35/44/53` | **`CX+30/42/50/56`** (et les cinq drones avec eux) | effet de bord du dash débloqué plus tôt : à 11,5 studs du balcon du double saut, le deuxième échafaudage laissait contourner toute la fin de la spirale. Écartés, ils sont à 19,5 et 26,5 studs des balcons de montée. |
| Atrium de Sup de Vinci | volées de 7 studs (18 → 25 → 32 → 39) | **volées de 8 studs (18 → 26 → 34 → 42)** | avec la course et le dash, tout le reste du tuto se franchit en physique réelle : **c'est l'atrium qui rend le double saut strictement obligatoire** (le balcon de la tour reste le passage qui l'enseigne). |

### Le premier saut du jeu reste accueillant (décision de l'utilisateur, 2026-11-19)
Une première version posait la porte de la course **en sortant du métro**, premier saut après le premier déblocage. L'utilisateur l'a refusée : un débutant doit être accueilli, pas coincé. Le parvis du métro redevient donc un saut de 8 studs à plat en montant de 1 — au-delà du saut debout du modèle prudent (6,5), donc on prend naturellement de l'élan, mais franchissable en marchant (8,67 studs de portée réelle), et c'est assumé.

Il n'y a donc **pas de porte de course dédiée au déblocage**. La `DalleDeLaCourse` **enseigne** la course (dalle en travers du chemin, panneau, jalons lumineux) ; elle ne l'**impose** pas. L'obligation arrive deux sauts plus loin, sur le troisième saut du cortège, quand le joueur a déjà senti ce que la course change.

Pourquoi un verrou dédié reste nécessaire quelque part, et pourquoi la porte du dash n'y suffit pas : une fois le dash en main, un joueur qui ne court pas franchit déjà 19,47 studs à plat (21,47 avec la marge), alors que le modèle de confort n'accorde que 17,75 à un joueur qui court **et** dash. Aucun saut ne peut donc être à la fois infranchissable sans courir et tenable en courant **après** le déblocage du dash : la porte du dash (16,5 studs) se franchit sans la course. Le verrou de la course doit donc vivre avant la dalle du dash, et la seule géométrie possible y est un saut de 9,5 studs en montant de 4,5. C'est le troisième saut du cortège.

### Contrôles
- `verifier-sauts.luau` : nouvelle section « Portes strictement nécessaires (physique réelle) ». Pour chaque capacité, le parcours en largeur est rejoué en physique réelle en la refusant ; il doit rester au moins un checkpoint hors d'atteinte. Le critère est **global** (« aucun chemin ne mène au bout sans la capacité ») : il n'exige pas de saut dédié au déblocage et ne dit pas où est le verrou — la course est verrouillée par le cortège, le double saut par l'atrium de Sup de Vinci, loin de leurs dalles d'apprentissage. En cas d'échec, la route trouvée est affichée saut par saut.
- `verifier-ascension.luau` : nouvelle section « On n'entre dans la tour qu'en ayant fini le tuto ». Aucune plateforme du tuto, hors du haut de l'atrium, n'est à portée réelle d'une plateforme de l'ascension. Les portes `GATE_*` de la tour restent, mais **comme critère de difficulté** : un joueur réel y arrive forcément avec les trois capacités, c'est le tuto qui verrouille.
- `casser-parcours.luau` : une panne par capacité (`course`, `dash`, `double-saut`). Chacune ignore où est le verrou : elle rejoue le parcours en largeur sans la capacité, repère la frontière (les sauts qui mènent de ce qu'on atteint à ce qu'on n'atteint pas), la coupe en trois par deux marches, et recommence jusqu'au dernier checkpoint. `verifier-sauts` doit alors sortir en code 1 sur **cette** capacité.

## Questions ouvertes
- Aucune.
