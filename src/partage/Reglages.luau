--!strict
-- Réglages du jeu, en lecture seule. Le client ne s'en sert que pour l'affichage.
local Reglages = {
	-- Dernier checkpoint (l'arrivée). Les checkpoints vont de 0 (départ) à NB_ETAPES.
	NB_ETAPES = 15,

	-- Produit développeur « Passer l'étape » : son identifiant se crée dans le Creator Hub
	-- (l'expérience > Monetization > Developer Products). 0 = pas encore créé : le bouton est caché.
	PRODUIT_PASSER_ETAPE = 0,

	-- Un parcours plus rapide que ça est impossible à la main : il n'entre pas au classement (anti-triche).
	TEMPS_MIN_CLASSABLE = 45,

	TAILLE_CLASSEMENT = 10,
	DELAI_RAFRAICHIR_CLASSEMENT = 60, -- secondes
	DELAI_MIN_ENTRE_DEMANDES = 1, -- secondes, pour « Recommencer »
	DELAI_REAPPARITION = 1.5, -- secondes
	MAX_ACHATS_MEMORISES = 100,

	-- Noms des DataStore : les changer revient à repartir de zéro.
	STORE_JOUEURS = "Joueurs_v1",
	STORE_CLASSEMENT = "MeilleursTemps_v1",
}

return table.freeze(Reglages)
