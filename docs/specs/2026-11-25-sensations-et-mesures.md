# Sensations et mesures (lot 1 des améliorations continues)

Statut : brouillon
Date : 2026-11-25

## Besoin
Le jeu est muet : un saut, un checkpoint ou un record ne se sent pas. Et nous ne savons pas à quelle étape les joueurs abandonnent. Ce lot donne un retour sonore immédiat au joueur et des chiffres pour choisir les lots suivants.

## Périmètre
- Dedans : sons, musique par zone, bouton de coupure, mesures envoyées à Roblox.
- Hors périmètre : badges, objectifs, cosmétiques, jeu entre amis, manches de tour, réglages sauvegardés. Aucun changement de difficulté, de carte ou de sauvegarde.

## Critères d'acceptation
- [ ] Un joueur entend un son distinct quand il saute, fait un double saut, dashe, valide un checkpoint, meurt, débloque une capacité, arrive, et bat un record. À l'arrivée avec record, seul le son de record joue.
- [ ] Le son du checkpoint monte d'un ton à chaque checkpoint de la série, jusqu'à ×10, et redescend après une chute.
- [ ] Chaque zone du parcours et la tour ont une musique. Au changement de zone, l'une s'efface et l'autre monte en 1,5 s, sans coupure ni superposition durable. Réapparaître dans la même zone ne relance pas la musique.
- [ ] Un bouton à l'écran, d'au moins 44 px au doigt, coupe et remet la musique ; un second fait de même pour les effets. Ils ne cachent ni les capacités, ni le HUD, ni les commandes tactiles, sur téléphone comme sur ordinateur.
- [ ] Un son qui ne charge pas laisse le jeu fonctionner sans erreur répétée.
- [ ] Aucun son n'est déclenché par le serveur, et aucun son ne change le résultat d'une action.
- [ ] Sur la place publiée, le tableau de bord Roblox montre un entonnoir « première partie » : arrivée en jeu, puis chaque checkpoint 1 à 15, puis le pied et le sommet de la tour.
- [ ] Il montre aussi le nombre de morts par étape. Ces morts sont regroupées avant l'envoi : au plus un envoi par joueur et par étape, plus un à son départ.
- [ ] Le vol des testeurs n'envoie aucune mesure. Une erreur d'envoi ne gêne jamais le jeu. Aucun identifiant ni nom de joueur n'est ajouté aux mesures.

## Décisions
| Question | Options envisagées | Choix | Raison |
|---|---|---|---|
| Premier lot | Sensations + mesures / Raisons de revenir / À plusieurs / Tour renouvelée | Sensations + mesures | Choix de l'utilisateur. |
| Cadence | Oui à chaque lot / Enchaîner | Oui à chaque lot | Choix de l'utilisateur. |
| Source des sons | Creator Store de Roblox (audio du compte Roblox) / audio importé par l'utilisateur | À valider : Creator Store | Gratuit, pas de fichier à importer ni de droits à gérer. Aucun morceau sous marque ou d'artiste. |
| Musique au lancement | Activée, douce / coupée | À valider : activée à volume doux | Usage courant ; la coupure est à un doigt. |
| Choix son coupé | Pour la partie en cours / sauvegardé | À valider : partie en cours | Ne touche pas aux sauvegardes dans ce lot. |

## Tâches
1. **Gameplay** (45 min) : `src/partage/Sons.luau` (règles pures : musique d'une zone, ton du checkpoint selon la série, choix entre arrivée et record ; identifiants et volumes) ; `src/client/Sons.luau` (lecture, fondu, API `Sons.couperMusique(b)`, `Sons.couperEffets(b)`), branché sur les remotes existants `EtatCourse`, `Arrivee`, `CapaciteDebloquee`, `EtatAscension` ; `src/serveur/Mesures.luau` et règles pures de regroupement. Tests d'abord. Un identifiant de son non vérifié est signalé, jamais inventé.
2. **UI** (30 min, après l'API) : les deux boutons de coupure, états lisibles, téléphone et ordinateur.
3. Revue et QA en jeu. Les mesures ne partent que d'une place publiée : la QA les vérifie par les règles pures, et l'utilisateur les voit ensuite dans le tableau de bord.

Durée estimée du jalon : 2 h (contrôles, QA et livraison compris)

## Impacts
- Données / migrations : aucune.
- API : aucun nouveau remote prévu.
- Écrans : deux petits boutons.

## Questions ouvertes
- Les trois lignes « À valider » du tableau.
