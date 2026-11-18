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

	-- Capacités de déplacement (Capacites.luau). Référence : personnage Roblox par défaut, marche 16 studs/s, saut de
	-- 7,2 studs de haut (JumpHeight 7.2, gravité 196,2) : un saut dure ~0,54 s et porte à ~8,7 studs en marchant.
	-- Course : la vitesse de marche est multipliée par COURSE_FACTEUR (16 -> 24 studs/s) ; le champ de vision gagne
	-- COURSE_FOV_BONUS degrés tant qu'on court (70 -> 80 par défaut).
	COURSE_FACTEUR = 1.5,
	COURSE_FOV_BONUS = 10,
	-- Dash : pendant DASH_DUREE secondes, vitesse horizontale imposée de DASH_VITESSE studs/s. 70 x 0,2 = 14 studs
	-- parcourus, contre 3,2 (marche) ou 4,8 (course) sans dash : un saut s'allonge de 10,8 ou 9,2 studs (visé : 8 à 12).
	DASH_VITESSE = 70,
	DASH_DUREE = 0.2,
	-- Dash lancé au sol : il se recharge après ce délai (s) si le joueur est resté au sol ; en l'air, à l'atterrissage.
	-- Empêche d'enchaîner des dash au sol en continu (14 studs toutes les 0,2 s = 70 studs/s en permanence).
	DASH_RECHARGE_SOL = 0.6,
	-- Double saut : l'impulsion du second saut vaut SAUT_DOUBLE_FACTEUR x celle du premier. 1 = un second saut aussi
	-- haut que le premier (7,2 + 7,2 = 14,4 studs au total au mieux, en le lançant au sommet du premier).
	SAUT_DOUBLE_FACTEUR = 1,
	-- Durée (s) du tour complet du personnage pendant le double saut (rotation calculée par le code).
	VRILLE_DUREE = 0.45,
	-- Surveillance serveur : toutes les SURVEILLANCE_PERIODE secondes, le déplacement de chaque joueur est comparé à ce
	-- que ses capacités permettent. Au-delà de (maximum x SURVEILLANCE_MARGE + SURVEILLANCE_TOLERANCE studs), il est
	-- ramené à sa dernière position valide. La tolérance fixe absorbe le retard de réplication, les plateformes
	-- mobiles et les bousculades des obstacles ; la marge relative, l'écart entre le modèle et la physique réelle.
	SURVEILLANCE_PERIODE = 0.5,
	SURVEILLANCE_MARGE = 1.3,
	SURVEILLANCE_TOLERANCE = 6,

	-- Ascension (au-dessus de Sup de Vinci). Aura d'un étage franchi : ASCENSION_AURA_BASE pour le premier étage,
	-- puis ASCENSION_AURA_PAR_ETAGE de plus à chaque étage (étage n = BASE + PAR_ETAGE × (n − 1)). Monter haut est
	-- le vrai gain : avec 100 et 40, l'étage 1 rapporte 100 et l'étage 25 en rapporte 1 060, dix fois plus.
	-- Une ascension entière de 25 étages rapporte 14 500 d'aura (Ascension.auraAscension), à comparer aux 16 500
	-- d'un tuto parfait (15 checkpoints en série, puis 1 000 + 5 000 à l'arrivée) : le tuto reste le gros coup
	-- unique, l'ascension devient la raison de revenir. Un étage ne rapporte qu'une fois par tentative.
	ASCENSION_AURA_BASE = 100,
	ASCENSION_AURA_PAR_ETAGE = 40,
	-- Téléportation vers un palier débloqué : pas plus d'une fois toutes les 2 secondes (anti-triche).
	PALIER_DELAI_TELEPORT = 2,
	-- Une ascension plus rapide que ça est impossible à la main : son chrono n'entre pas au classement, comme
	-- TEMPS_MIN_CLASSABLE pour le tuto. À recalibrer sur la tour réelle (au moins 250 studs) : avec le double
	-- saut et le dash, un joueur très bon monte de l'ordre de 15 studs/s, donc jamais la tour en moins de 15 s.
	ASCENSION_TEMPS_MIN_CLASSABLE = 15,
	-- Suivi de la hauteur pendant l'ascension : relevé toutes les ASCENSION_PERIODE_SUIVI secondes, et l'état n'est
	-- renvoyé au client que si la hauteur a bougé d'au moins ASCENSION_PAS_ETAT studs (pas à chaque image).
	ASCENSION_PERIODE_SUIVI = 0.25,
	ASCENSION_PAS_ETAT = 2,
	-- Hauteur (studs au-dessus du pied) en dessous de laquelle retoucher le pied ne relance pas le chrono : sans ça,
	-- rester posé sur la plateforme de départ le remettrait à zéro sans arrêt.
	ASCENSION_SEUIL_DEPART = 8,

	TAILLE_CLASSEMENT = 10,
	DELAI_RAFRAICHIR_CLASSEMENT = 60, -- secondes
	DELAI_MIN_ENTRE_DEMANDES = 1, -- secondes, pour « Recommencer »
	DELAI_REAPPARITION = 1.5, -- secondes
	MAX_ACHATS_MEMORISES = 100,

	-- Noms des DataStore : les changer revient à repartir de zéro.
	STORE_JOUEURS = "Joueurs_v1",
	STORE_CLASSEMENT = "MeilleursTemps_v1",
	STORE_AURA = "Aura_v1",
	STORE_HAUTEUR = "HauteurAscension_v1",
	STORE_ASCENSION = "TempsAscension_v1",
}

return table.freeze(Reglages)
