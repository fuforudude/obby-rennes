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
- [ ] **Difficulté maximale partout** : un contrôle automatique vérifie qu'aucun chemin du pied au sommet n'existe **sans le dash**, ni **sans le double saut**, ni **sans la course** (même méthode que la « porte sans effet » du tuto).
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
- **`PiegeMur`** sur un `Model` : attributs `Direction` (Vector3 unitaire, sens de sortie), `Distance` (studs), `DureeSortie` (s), `DureeRentree` (s), `Portee` (studs, rayon de déclenchement), `Poussee` (studs/s). Enfant `Pointe` (BasePart, la partie qui sort). Le serveur la fait sortir quand un joueur entre dans la portée, et applique l'impulsion au contact.
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

## Questions ouvertes
- Aucune.
