# Mode vol pour les testeurs

Statut : à valider — 2026-11-19

## Le besoin

Personne ne peut aujourd'hui atteindre un passage précis du jeu sans le jouer depuis le début. La tour fait 258 studs sans aucun checkpoint : vérifier un obstacle du dernier tiers demande une ascension complète et sans faute. Faire essayer un passage à quelqu'un est donc impossible, et chaque retour d'essai coûte une partie entière.

Un mode vol réservé à quelques identifiants règle ça : on se déplace librement dans les airs, on va voir l'obstacle, on revient.

## Ce que ça ne doit jamais devenir

Un jeu publié avec un mode vol est une cible de triche évidente. Deux règles non négociables, ce sont des conventions du projet et pas des choix :

- **Le serveur décide seul.** Le client demande, le serveur vérifie l'identifiant du joueur contre la liste et accorde ou refuse. Aucun client ne s'auto-déclare testeur. Un joueur hors liste qui envoie la demande en boucle est ignoré, exactement comme pour les autres remotes.
- **Le vol ne passe pas inaperçu.** La surveillance anti-triche compare les déplacements à ce que les capacités permettent (`src/partage/Capacites.luau`, fenêtre glissante). Voler la déclencherait à chaque seconde. Elle est donc suspendue pendant le vol, et la tentative bascule en non classable par le chemin qui existe déjà.

## Décisions de l'utilisateur

| Question | Choix | Conséquence |
|---|---|---|
| Qui peut voler | Une liste d'identifiants Roblox dans les réglages | Tu modifies la liste et tu republies pour ajouter un testeur. Personne d'autre ne vole, même en trichant. |
| Score d'une partie où l'on a volé | Non classable | Ni temps, ni hauteur, ni aura ne partent dans les classements tant que le joueur n'a pas recommencé depuis la coloc. |
| Activation | Une touche | Immédiat. Pas d'accès sur mobile sans clavier : assumé, les testeurs jouent sur ordinateur. |

Touche proposée : **F**. Libre aujourd'hui (Maj = course, Espace = saut et double saut, A = dash).

## Ce que ça fait, côté joueur

Un testeur appuie sur F. Son personnage cesse de tomber et se déplace dans la direction regardée avec les touches habituelles, monte et descend. Une mention discrète à l'écran rappelle que le vol est actif et que la partie n'est plus classée. Il réappuie sur F : il retombe normalement, là où il est.

Un joueur qui n'est pas sur la liste appuie sur F : rien ne se passe, aucun message, aucun indice que le mode existe.

## Critères d'acceptation

1. Un joueur dont l'identifiant est dans la liste appuie sur F : il vole, se déplace dans les trois dimensions, et une mention « vol » apparaît à l'écran.
2. Il réappuie sur F : il retombe et reprend le jeu normal, sans mourir de la chute si elle est courte.
3. Un joueur hors liste appuie sur F : il ne se passe rien. Même en envoyant directement le remote en boucle depuis un client modifié, il ne vole pas et le serveur ne plante pas.
4. Pendant le vol, la surveillance anti-triche ne ramène jamais le joueur en arrière et ne l'exclut pas.
5. Dès la première activation du vol, la course en cours et la tentative d'ascension en cours sont non classables : à l'arrivée, l'écran affiche « non classé », aucun record personnel n'est écrit et aucun classement mondial n'est mis à jour.
6. « Recommencer » depuis la coloc rend les parties à nouveau classables. La marque « a volé » ne vit qu'en mémoire du serveur et n'est pas sauvegardée : une déconnexion l'efface, mais le joueur qui revient avec une étape sauvegardée reprend sa partie, et une reprise n'est jamais classable. Seul « Recommencer » redonne donc une partie classable.
7. Un joueur qui vole jusqu'à un checkpoint le valide et sa progression est sauvegardée : c'est voulu, un testeur doit pouvoir repartir de là la fois suivante. Seuls les classements et les records sont protégés.
8. Le vol ne traverse pas les murs : le personnage reste solide.
9. Un testeur qui meurt ou se déconnecte en volant ne reste pas en vol à sa réapparition.

## Contrats entre les agents

**Gameplay fournit** :
- `Reglages.TESTEURS` : table `{ [number]: boolean }` d'identifiants Roblox, vide à la livraison, commentée pour dire comment en ajouter un.
- `Remotes.DemanderVol()` (client → serveur) : « je veux basculer le vol ». Le serveur vérifie la liste, le personnage vivant et une cadence minimale.
- `Remotes.EtatVol(actif: boolean)` (serveur → client) : la réponse qui fait foi. Le client n'active rien avant de l'avoir reçue.
- Une règle pure testable dans `src/partage/` pour « cet identifiant peut-il voler ? » et pour la bascule, afin que le cas « hors liste » soit couvert par un test.

**UI consomme** : `EtatVol` pour afficher la mention à l'écran, et rien d'autre. Aucune touche n'est lue par l'interface : la touche est gérée avec les autres entrées, dans `src/client/Capacites.luau`.

## Découpage

- **Gameplay** : réglages, remotes, règle pure et tests, autorisation serveur, suspension de la surveillance, bascule en non classable, entrée clavier et déplacement du personnage.
- **UI** : la mention à l'écran, cohérente avec le HUD existant, discrète comme l'utilisateur l'a demandé.

## Ce qui n'est pas fait

- Pas d'accès sur mobile ni à la manette.
- Pas de téléportation à un étage choisi : seulement le vol libre.
- Pas de liste modifiable en jeu : on change les réglages et on republie.
