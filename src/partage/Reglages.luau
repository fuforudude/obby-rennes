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

	-- Aura : la mécanique centrale. Chaque checkpoint rapporte AURA_BASE × la série (checkpoints enchaînés sans
	-- tomber), plafonnée à AURA_SERIE_MAX. Une chute remet la série à zéro et coûte AURA_PERTE_CHUTE (jamais sous 0).
	-- L'arrivée rapporte AURA_ARRIVEE, et AURA_SANS_CHUTE en plus pour un parcours entier sans tomber.
	-- Une étape passée en Robux ne rapporte rien et remet la série à zéro : pas d'aura achetée.
	AURA_BASE = 100,
	AURA_SERIE_MAX = 10,
	AURA_PERTE_CHUTE = 50,
	AURA_ARRIVEE = 1000,
	AURA_SANS_CHUTE = 5000,

	-- Événements de la carte (objets qui tombent, rame, drones, trafic ; voir Horaires.luau et client/Evenements.luau).
	-- Contact : on agrandit chaque pièce dangereuse de ces marges (studs) autour du centre du personnage, qui est un
	-- peu plus grand que son HumanoidRootPart. Plus petit = plus indulgent.
	EVENEMENT_MARGE_HORIZONTALE = 0.8,
	EVENEMENT_MARGE_VERTICALE = 2,
	-- Fréquence du clignotement du préavis (fois par seconde) ; il reste allumé en continu les 0,35 dernières secondes.
	EVENEMENT_CLIGNOTEMENT = 4,
	-- Un objet « hors service » est rangé à cette distance (studs, sur Z) pour disparaître sans rien détruire.
	EVENEMENT_RANGEMENT = 20000,
	-- Côté serveur, quand un joueur dit avoir été touché : le danger doit être actif à cette tolérance près
	-- (secondes, pour le retard réseau), le joueur à moins de EVENEMENT_DISTANCE_MAX studs de la trajectoire
	-- (plus la demi-taille de l'objet), et pas plus d'un signalement par EVENEMENT_DELAI_MIN secondes.
	EVENEMENT_TOLERANCE = 1,
	EVENEMENT_DISTANCE_MAX = 40,
	EVENEMENT_DELAI_MIN = 0.5,

	TAILLE_CLASSEMENT = 10,
	DELAI_RAFRAICHIR_CLASSEMENT = 60, -- secondes
	DELAI_MIN_ENTRE_DEMANDES = 1, -- secondes, pour « Recommencer »
	DELAI_REAPPARITION = 1.5, -- secondes
	MAX_ACHATS_MEMORISES = 100,

	-- Noms des DataStore : les changer revient à repartir de zéro.
	STORE_JOUEURS = "Joueurs_v1",
	STORE_CLASSEMENT = "MeilleursTemps_v1",
	STORE_AURA = "Aura_v1",
}

return table.freeze(Reglages)
