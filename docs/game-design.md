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
