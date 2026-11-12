# Brief : miniature et icône d'Obby Rennes

## Usage
- `miniature` : miniature d'expérience Roblox, 1920x1080 (16:9), PNG < 2 Mo.
- `icone` : icône d'expérience Roblox, 512x512, lisible à 50 px.

## Style
Cartoon low-poly / formes géométriques simples, couleurs saturées, contrastes forts, ciel bleu d'après-midi, un seul point focal. Plateformes à contour néon (signature du jeu).

## Palette
Orange #FF8C3C, violet #A05AFF, rouge métro #EB323C, jaune #FFC81E, vert #78E628, rose #FF50BE, bleu #28BEFF, ciel #8CC8FF. Encre de contour #1E1646.

## Contenu
- Miniature : étudiant cubique (sac à dos, copie à la main) en plein saut entre deux plateformes, tour à spirale de balcons derrière lui, maisons à colombages, rame de métro rouge sur viaduc, barricade de poubelles vertes et jaunes, drapeau breton, banderole « NON AUX PARTIELS À 8H », badge « +1000 AURA ». Titre « OBBY RENNES » + bandeau « PARTIEL MAINTENU ».
- Icône : l'étudiant qui saute devant la tour en spirale, texte « OBBY RENNES » sur deux lignes.

## Interdits
Aucun logo (Sup de Vinci, Rennes 2, STAR, Stade Rennais, marque), aucun personnage existant ni mème, aucune mention de Robux, de prix ou de « gratuit », rien de trompeur sur le contenu.

## Fabrication et retouche
- Sources : `assets/miniatures/miniature.svg` et `icone.svg`, un groupe nommé (`id`) par partie. Éditables dans Inkscape, Figma, Illustrator ou un éditeur de texte.
- Les textes sont convertis en chemins (police Impact, de Monotype, utilisée comme dessin de lettres) : pour changer un mot, le redessiner ou régénérer.
- Exports : `miniature.png` (1920x1080), `icone.png` (512x512), à regénérer après toute retouche : `assets apercu assets/miniatures/miniature.svg assets/miniatures/miniature.png --largeur 1920` (idem `icone`, `--largeur 512`).
- `outils/assets/generer_miniatures.py` a produit la première version ; ne plus le relancer une fois les SVG retouchés.
