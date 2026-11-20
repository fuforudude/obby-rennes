-- Source unique du parcours figé (checkpoints 0 à 15) : ce que plusieurs générateurs doivent voir au même endroit.
-- Lue par outils/monde/Parcours.luau (dalles, arches), Evenements.luau (panneaux d'anecdotes) et Ascension.luau
-- (accrochage à Sup de Vinci), par l'intermédiaire de la bibliothèque commune (biblio.parcours, outils/monde/biblio.luau) ;
-- outils/monde/verifier-contrats.luau vérifie qu'il y a exactement NB_ETAPES + 1 checkpoints, numérotés dans l'ordre, et
-- compare les noms aux zones de src/partage/Etapes.luau. Données pures : aucun constructeur Roblox ici.
--
-- Un checkpoint (le n-ième de la liste porte le numéro n - 1 ; le dernier est l'arrivée, en or) :
-- - `x`, `dessus`, `z` : centre de la dalle, hauteur de sa face supérieure ; `taille` : côté de la dalle (carrée) ;
-- - `interieur` : nom flottant au-dessus de la dalle au lieu d'une arche (checkpoint dans un bâtiment) ;
-- - `nomArche` : le nom de la zone écrit sur la carte (fronton de l'arche ou nom flottant, précédé du numéro) ;
-- - `zone` : la clé de sa couleur dans biblio.accents (liseré du panneau d'anecdote) ;
-- - `panneau` : où se plante son panneau d'anecdote (Evenements.luau). Soit à côté de la dalle : décalé de `dx` en X,
--   du côté `cote` en Z (-1 : Z négatif), tourné vers le centre de la dalle (`droit` : parallèle au côté de la dalle),
--   avec un pied qui descend jusqu'à `pied` (nil : le sol de la ville) ; soit `mural` : centre { x, y, z } et
--   direction { dx, dz } vers laquelle il regarde, sans pied.
local checkpoints = {
	{
		numero = 0,
		x = -5,
		dessus = 40,
		z = 0,
		taille = 14,
		nomArche = "La coloc à Villejean",
		zone = "coloc",
		panneau = { cote = -1, dx = 4.5 },
	},
	{
		numero = 1,
		x = 54,
		dessus = 10,
		z = 0,
		taille = 12,
		nomArche = "Fac bloquée",
		zone = "fac",
		panneau = { cote = 1, dx = 4.5 },
	},
	{
		numero = 2,
		x = 119,
		dessus = 31,
		z = 0,
		taille = 8,
		interieur = true,
		nomArche = "L'amphi bloqué",
		zone = "fac",
		panneau = { cote = -1, dx = -3, pied = 22 },
	},
	{
		numero = 3,
		x = 202,
		dessus = 34,
		z = 0,
		taille = 12,
		nomArche = "Le viaduc de la ligne b",
		zone = "metro",
		panneau = { cote = -1, dx = 3 },
	},
	{
		numero = 4,
		x = 243,
		dessus = 14,
		z = 0,
		taille = 12,
		nomArche = "La station",
		zone = "metro",
		panneau = { cote = -1, dx = 4.5 },
	},
	{
		numero = 5,
		x = 298,
		dessus = 19,
		z = 0,
		taille = 12,
		nomArche = "Place de la République",
		zone = "cortege",
		panneau = { cote = -1, dx = -4.5 },
	},
	{
		numero = 6,
		x = 342,
		dessus = 19,
		z = 0,
		taille = 12,
		nomArche = "Le cortège",
		zone = "cortege",
		panneau = { cote = -1, dx = 4.5 },
	},
	{
		numero = 7,
		x = 374,
		dessus = 24,
		z = 0,
		taille = 8,
		interieur = true,
		nomArche = "Barricades de poubelles",
		zone = "tour",
		panneau = { cote = 1, dx = 0 },
	},
	{
		numero = 8,
		x = 404.5, -- dans la tour (centre 395), au pied du balcon
		dessus = 66,
		z = 0,
		taille = 6,
		interieur = true,
		nomArche = "La tour",
		zone = "tour",
		panneau = { cote = 1, dx = -2.5, pied = 63, droit = true },
	},
	{
		numero = 9,
		x = 488,
		dessus = 28,
		z = 0,
		taille = 12,
		nomArche = "Rue de la Soif",
		zone = "soif",
		panneau = { cote = -1, dx = -4.5 },
	},
	{
		numero = 10,
		x = 559,
		dessus = 10,
		z = 0,
		taille = 12,
		nomArche = "Le dernier bar avant le partiel",
		zone = "soif",
		panneau = { cote = -1, dx = 4.5 },
	},
	{
		numero = 11,
		x = 611,
		dessus = 5,
		z = 0,
		taille = 12,
		nomArche = "La Vilaine",
		zone = "vilaine",
		panneau = { cote = -1, dx = 4.5, pied = 2 },
	},
	{
		numero = 12,
		x = 647,
		dessus = 17,
		z = 0,
		taille = 12,
		nomArche = "Les quais",
		zone = "vilaine",
		panneau = { cote = -1, dx = 4.5, pied = 2 },
	},
	{
		numero = 13,
		x = 715,
		dessus = 42,
		z = 0,
		taille = 8,
		nomArche = "Sur le toit du Parlement",
		zone = "parlement",
		panneau = { cote = -1, dx = 4.5, pied = 40.6 },
	},
	{
		numero = 14,
		x = 810,
		dessus = 18,
		z = 0,
		taille = 12,
		nomArche = "Le Thabor",
		zone = "thabor",
		panneau = { cote = -1, dx = 4.5, pied = 12 },
	},
	{
		numero = 15,
		x = 834, -- la salle de partiel, en mezzanine (dalle 828..840 × 2..14)
		dessus = 42,
		z = 8,
		taille = 12,
		interieur = true,
		nomArche = "Sup de Vinci · salle de partiel",
		zone = "vinci",
		panneau = { mural = { x = 826.3, y = 46.5, z = 8, dx = 1, dz = 0 } }, -- au mur ouest, face à la salle
	},
}

-- Sup de Vinci, le bâtiment de l'arrivée : murs de x1 à x2 et de z1 à z2, toit dont le dessus est à `toit`, et la
-- verrière ouverte dans ce toit (au-dessus de la salle de partiel) par où l'on sort vers l'ascension, qui tourne
-- autour du centre du bâtiment.
local supDeVinci = {
	x1 = 825,
	x2 = 865,
	z1 = -16,
	z2 = 16,
	toit = 56,
	verriere = { x1 = 832, x2 = 844, z1 = 2, z2 = 14 },
}

return {
	checkpoints = checkpoints,
	supDeVinci = supDeVinci,
}
