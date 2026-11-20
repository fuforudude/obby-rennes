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

	-- Effets visuels des capacités (client/EffetsVisuels.luau). Ils sont joués par le client qui déclenche la capacité
	-- (aucun délai pour lui), puis rejoués chez les autres joueurs : le serveur relaie SignalerEffet en EffetCapacite.
	-- Dash : le corps se penche de DASH_INCLINAISON degrés vers l'avant ; la traînée met DASH_TRAINEE_DUREE secondes à
	-- s'effacer derrière le personnage ; le champ de vision gagne DASH_FOV_BONUS degrés d'un coup puis revient en
	-- DASH_FOV_RETOUR secondes ; DASH_CHOC_PARTICULES particules marquent le point d'arrivée.
	DASH_INCLINAISON = 55,
	DASH_TRAINEE_DUREE = 0.35,
	DASH_FOV_BONUS = 18,
	DASH_FOV_RETOUR = 0.4,
	DASH_CHOC_PARTICULES = 14,
	-- Double saut : l'onde de choc sous les pieds grandit jusqu'à VRILLE_ONDE_RAYON studs en VRILLE_ONDE_DUREE secondes
	-- en s'effaçant ; la traînée de la rotation s'efface en VRILLE_TRAINEE_DUREE secondes.
	VRILLE_ONDE_DUREE = 0.45,
	VRILLE_ONDE_RAYON = 9,
	VRILLE_TRAINEE_DUREE = 0.3,
	-- Course : la traînée au sol s'efface en COURSE_TRAINEE_DUREE secondes.
	COURSE_TRAINEE_DUREE = 0.25,
	-- Réplication : le serveur accepte au plus un signalement d'effet par capacité et par joueur toutes les
	-- EFFET_DELAI_MIN secondes (un dash et un double saut peuvent s'enchaîner en moins de ce délai) ; un client ne
	-- rejoue pas l'effet d'un joueur à plus de EFFET_DISTANCE_MAX studs de lui (invisible de toute façon).
	EFFET_DELAI_MIN = 0.3,
	EFFET_DISTANCE_MAX = 150,
	-- Animations Roblox à la place de la rotation calculée (le corps penché du dash, la vrille du double saut). Vides :
	-- le code calcule la rotation. Pour en mettre une : créer l'animation dans l'Animation Editor de Studio (rig R15
	-- du personnage), la publier sur Roblox (clic droit > Publier dans Roblox), copier son identifiant et écrire ici
	-- "rbxassetid://123456789". Elle est alors jouée chez tout le monde, sans rien changer d'autre : traînée, lignes de
	-- vitesse, onde de choc et champ de vision restent. Elle doit appartenir à l'expérience (ou à son groupe) et ne
	-- pas boucler ; prévoir environ DASH_DUREE (0,2 s) pour le dash et VRILLE_DUREE (0,45 s) pour le double saut.
	ANIMATION_DASH = "",
	ANIMATION_DOUBLE_SAUT = "",
	-- Surveillance serveur : la position de chaque joueur est relevée toutes les SURVEILLANCE_PERIODE secondes, et son
	-- déplacement est comparé à ce que ses capacités permettent sur une **fenêtre glissante** de SURVEILLANCE_FENETRE
	-- secondes (et non d'un relevé au suivant). Au-delà de (maximum x SURVEILLANCE_MARGE + SURVEILLANCE_TOLERANCE
	-- studs) sur la fenêtre, le joueur est ramené à sa dernière position valide. La tolérance fixe absorbe le retard de
	-- réplication, les plateformes mobiles et les bousculades des obstacles ; la marge relative, l'écart entre le
	-- modèle et la physique réelle.
	-- Pourquoi une fenêtre longue : le maximum contient un terme fixe (la hauteur d'un envol, 14,4 studs, qu'il faut
	-- autoriser au cas où la fenêtre tombe pile sur un décollage). Sur 0,5 s il valait à lui seul plus que la montée
	-- mesurée, et le plafond montait à 84 studs/s contre 26,6 réellement tenables : un script de vol passait. Étalé
	-- sur 2,5 s, il pèse cinq fois moins : plafonds de 44,4 studs/s en montée et 57,5 studs/s sur le plan (contre 84
	-- et 67,1), toujours au-dessus du mieux qu'un joueur fait vraiment (26,6 en montée, 42,4 sur le plan avec les
	-- dashs enchaînés). Prix payé : jusqu'à SURVEILLANCE_FENETRE secondes avant la première alerte après une
	-- apparition ou une téléportation décidée par le serveur, le temps que la fenêtre se remplisse.
	SURVEILLANCE_PERIODE = 0.5,
	SURVEILLANCE_FENETRE = 2.5,
	SURVEILLANCE_MARGE = 1.3,
	SURVEILLANCE_TOLERANCE = 6,

	-- Ascension (au-dessus de Sup de Vinci). Aura d'un étage franchi : ASCENSION_AURA_BASE pour le premier étage,
	-- puis ASCENSION_AURA_PAR_ETAGE de plus à chaque étage (étage n = BASE + PAR_ETAGE × (n − 1)). Monter haut est
	-- le vrai gain : avec 100 et 40, l'étage 1 rapporte 100 et l'étage 17 en rapporte 740, sept fois plus.
	-- La tour en construit 17 (outils/monde/Ascension.luau, un étage tous les 15 studs sur 258) : une ascension
	-- entière rapporte 7 140 d'aura (Ascension.auraAscension), à comparer aux 16 500 d'un tuto parfait (15
	-- checkpoints en série, puis 1 000 + 5 000 à l'arrivée) : le tuto reste le gros coup unique, l'ascension
	-- devient la raison de revenir (elle se refait, lui non). Un étage ne rapporte qu'une fois par tentative.
	ASCENSION_AURA_BASE = 100,
	ASCENSION_AURA_PAR_ETAGE = 40,
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
	-- Hauteur (studs au-dessus du pied, donc négative) sous laquelle un joueur en tentative est renvoyé au pied et
	-- recommence. « Tomber renvoie au pied » : sans ça, une chute depuis la tour se terminait sur le toit de Sup de
	-- Vinci (10 studs sous le pied, rien de mortel en dehors des lasers), où le joueur survivait, gardait sa tentative et son
	-- chrono, et où retoucher le pied en remontant ne relançait rien (il était déjà sous ASCENSION_SEUIL_DEPART).
	-- −2 studs : juste sous le dessus du pied, assez bas pour qu'y marcher ne déclenche rien.
	ASCENSION_HAUTEUR_GARDE = -2,

	-- Obstacles de la tour (src/serveur/Obstacles.luau ; règles pures et testées dans src/partage/Pieges.luau).
	-- Les valeurs ci-dessous ne servent que quand la pièce de la carte ne porte pas l'attribut correspondant :
	-- une carte peut toujours régler un piège plus dur ou plus doux que les autres.
	--
	-- Piège de mur : la pointe sort dès qu'un joueur vivant entre dans PIEGE_PORTEE studs de sa fente, rentre, puis
	-- se repose PIEGE_REPOS secondes avant de pouvoir se redéclencher (sans ce repos, un joueur collé au mur serait
	-- repoussé en boucle). Au contact la pointe ne tue pas : elle impose une vitesse horizontale de PIEGE_POUSSEE
	-- studs/s dans sa direction. Pourquoi 60 : pendant la demi-seconde où le joueur reste en l'air, cela fait une
	-- trentaine de studs parcourus, bien au-delà du plus grand vide de la tour (16 studs) — mal placé, on part
	-- vraiment dans le vide. Et c'est moins que DASH_VITESSE (70 studs/s, vitesse imposée) : un dash lancé dans
	-- l'autre sens reprend la main sur la poussée, et le double saut rend la hauteur. Au-delà de 70, plus rien ne
	-- rattraperait la poussée : l'obstacle deviendrait une mort certaine, ce que la spec ne veut pas.
	-- Un même joueur n'est repoussé qu'une fois par PIEGE_DELAI_POUSSEE secondes (Touched se déclenche plusieurs
	-- fois pour un seul contact).
	PIEGE_POUSSEE = 60,
	-- Plafond de la poussée qu'une carte peut demander (attribut « Poussee » du piège) : strictement sous
	-- DASH_VITESSE (70), pour que le dash puisse toujours reprendre la main. Une valeur plus forte est ramenée à ce
	-- plafond au lieu d'être refusée.
	PIEGE_POUSSEE_MAX = 65,
	PIEGE_PORTEE = 10,
	PIEGE_REPOS = 1.2,
	PIEGE_DELAI_POUSSEE = 0.4,
	-- Les pièges cherchent un joueur à portée toutes les PIEGE_PERIODE_SCAN secondes (pas à chaque image : c'est
	-- une distance par piège et par joueur). La pointe, elle, bouge bien à chaque image.
	PIEGE_PERIODE_SCAN = 0.1,
	-- Plateforme qui s'effondre : elle tombe EFFONDRABLE_DELAI secondes après le premier contact (le temps de la
	-- traverser en courant), puis revient à sa place EFFONDRABLE_RETOUR secondes plus tard.
	EFFONDRABLE_DELAI = 0.5,
	EFFONDRABLE_RETOUR = 4,
	-- Combien de temps la dalle tombe librement (secondes), avant d'être réancrée, invisible et traversable, jusqu'à
	-- son retour. Pourquoi si peu : la gravité (196,2 studs/s2) la ferait descendre de 880 studs en 3 s, sous
	-- Workspace.FallenPartsDestroyHeight (-500), et Roblox DÉTRUIRAIT la pièce : la dalle ne reviendrait jamais.
	-- 1,5 s suffit pour que la chute se voie. Si DelaiRetour est plus court, la chute est raccourcie d'autant.
	EFFONDRABLE_DUREE_CHUTE = 1.5,
	-- Balancier : multiplicateur de force (attribut facultatif « Poussee », 1 par défaut) appliqué à la densité de
	-- la pièce — une pancarte plus lourde emporte plus loin, sans changer sa trajectoire ni son horaire. Au-delà de
	-- ce plafond la valeur est refusée : une densité absurde ferait traverser les murs aux joueurs.
	BALANCIER_POUSSEE_MAX = 20,

	-- Mode vol des testeurs (partage/Vol.luau, serveur/Vol.luau, client/Vol.luau). Touche F. Le serveur est seul juge :
	-- un joueur dont l'identifiant n'est pas dans TESTEURS ne vole pas, même avec un client modifié.
	-- Pour ajouter un testeur : une ligne `[identifiant] = true,` dans la table ci-dessous (l'identifiant Roblox est le
	-- nombre de son profil : roblox.com/users/<identifiant>/profile), puis republier. Exemple, à décommenter avec le
	-- vrai identifiant : `-- [123456789] = true,`. Pour en retirer un : supprimer la ligne. Dans Studio, les joueurs
	-- d'un test « Clients et serveurs » ont des identifiants négatifs (-1, -2...).
	-- Une partie où l'on a volé n'est plus classée (ni temps, ni hauteur, ni aura au classement) jusqu'à « Recommencer ».
	TESTEURS = table.freeze({
		[648492337] = true, -- fuforudude, propriétaire du jeu
	} :: { [number]: boolean }),
	-- Vitesse du vol (studs/s), dans les trois dimensions. 50 : de quoi traverser la carte vite sans que les murs
	-- fins ne soient franchis (le dash tient 70 studs/s).
	VOL_VITESSE = 50,
	-- Délai minimal (s) entre deux bascules du vol acceptées par le serveur (cadence côté serveur, et côté client).
	VOL_DELAI_MIN = 0.5,

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

	-- Contrôles de carte (outils/monde/verifier-sauts.luau et verifier-ascension.luau), le jeu ne les lit pas.
	-- « Modèle prudent » du saut : il juge si un saut est jouable sans rage, volontairement sous la physique réelle
	-- (la preuve qu'un vide est infranchissable, elle, prend la physique réelle : outils/monde/physique.luau).
	-- Saut debout : CONTROLE_MONTEE de montée, CONTROLE_VIDE de vide à plat (× COURSE_FACTEUR en courant) ; double
	-- saut : CONTROLE_MONTEE_DOUBLE de montée en tout ; dash : CONTROLE_DASH_VIDE de vide en plus. Une descente
	-- donne 1 stud de vide en plus par CONTROLE_DESCENTE_PAS studs descendus, au plus CONTROLE_BONUS_DESCENTE (tuto)
	-- ou CONTROLE_ASCENSION_BONUS_DESCENTE (tour). Dans la tour, le vide à plat est plafonné à
	-- CONTROLE_ASCENSION_VIDE_MAX et on en perd la part CONTROLE_ASCENSION_PERTE en montant au maximum.
	-- CONTROLE_HAUTEUR_LIBRE : hauteur libre minimale au-dessus d'une plateforme (en dessous, plafond trop bas).
	CONTROLE_MONTEE = 4.5,
	CONTROLE_MONTEE_DOUBLE = 9,
	CONTROLE_VIDE = 6.5,
	CONTROLE_DASH_VIDE = 8,
	CONTROLE_DESCENTE_PAS = 4,
	CONTROLE_BONUS_DESCENTE = 2.5,
	CONTROLE_ASCENSION_BONUS_DESCENTE = 4,
	CONTROLE_ASCENSION_VIDE_MAX = 16,
	CONTROLE_ASCENSION_PERTE = 10 / 16,
	CONTROLE_HAUTEUR_LIBRE = 5.5,
}

return table.freeze(Reglages)
