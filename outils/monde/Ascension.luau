-- Construction « Ascension » : l'empilement chaotique qui flotte au-dessus de Sup de Vinci (esprit Only Up).
--
-- Renvoie une fonction qui reçoit R (les constructeurs Roblox de Lune) et `biblio`, la bibliothèque commune des
-- générateurs (outils/monde/biblio.luau : outils, palettes, source unique du parcours, Reglages), et rend le modèle
-- construit. outils/monde/generer.luau l'appelle et écrit monde/Ascension.rbxm (aperçu dans Studio : par Rojo).
-- La tour s'accroche à Sup de Vinci et à la salle de partiel par biblio.parcours (outils/monde/donnees/parcours.luau).
--
-- Le tracé. On sort de la salle de partiel (checkpoint 15, en 834, 42, 8) **par le haut** : la verrière ouverte dans
-- le toit de Sup de Vinci (outils/monde/Parcours.luau) se franchit en trois dalles qui montent droit (48, 54, 60),
-- et le quatrième saut pose sur le **pied de l'ascension**, une plateforme qui flotte 10 studs au-dessus du toit. De là, 258 studs de montée en spirale autour de la fac : morceaux d'immeubles rennais retournés, bus STAR,
-- rames de métro, grues, échafaudages, panneaux publicitaires, canapés, armoires, bureaux, bouées, poubelles,
-- pancartes du cortège et une galette-saucisse géante. **Aucun palier, aucun checkpoint** : tomber renvoie au pied
-- (spec docs/specs/2026-11-18-tour-exigeante.md, esprit Only Up).
--
-- Difficulté maximale partout (décision de l'utilisateur). Chaque saut est posé à une part voulue du vide tenable
-- (`serre`, de 0,86 en bas à 0,96 en haut) et six tranches de 43 studs montent en exigence. Trois sortes de sauts
-- rendent chaque capacité **indispensable** (le contrôle le prouve en rejouant la recherche de chemin sans elle) :
-- - porte du dash : 13,5 studs de vide à plat (le vide maximal sans dash est de 9,75) ;
-- - porte de la course : 15,3 studs de vide à plat (sans courir, 14,5 au plus, dash compris) ;
-- - porte du double saut : 8 studs de montée (sans lui, 4,5 au plus).
-- Une respiration très courte par tranche évite d'enchaîner soixante sauts extrêmes sans reprendre son souffle.
--
-- Lisibilité : on ne pose les pieds que sur des **dalles horizontales**, saturées et cernées de la couleur de leur
-- tranche (contour SelectionBox). Les objets qui portent les dalles sont solides et tiennent dans leur aplomb : ce qui
-- paraît être l'obstacle porte le joueur, et aucun saut n'en est raccourci (outils/monde/verifier-bords.luau). Le décor
-- de fond est fantôme (sans collision, sans toucher, sans requête) et penché : rien de plat ne peut tromper.
--
-- Ce que le jeu attend (contrats de docs/specs/2026-11-18-tour-exigeante.md) :
-- - tag « PiedAscension » : la plateforme de départ, où la chute renvoie ;
-- - « Hauteur » est toujours le Y absolu du dessus de la pièce ; la hauteur gagnée depuis le départ est l'attribut
--   « HauteurRelative » (le pied, taillé à 66, le porte aussi, à 0) ;
-- - tag « EtageAscension » + attribut « Numero » : plaque à toucher qui compte un étage franchi (aura) ;
-- - tag « SommetAscension » : l'arrivée ;
-- - tags « TableauHauteur » / « TableauAscension » : panneaux dont le serveur remplit le TextLabel « Liste » ;
-- - les six familles d'obstacles, de plus en plus denses en montant (2, 3, 4, 5, 7 puis 9 par tranche de 43 studs,
--   30 en tout) :
--   - « PiegeMur » (Model) + attributs « Direction » (Vector3 unitaire, sens de sortie), « Distance », « DureeSortie »
--     (temps passé dehors), « DureeRentree » (temps passé rentré, c'est la fenêtre de passage), « Portee »,
--     « Poussee » ; enfant « Pointe » (BasePart). Seul indice avant déclenchement : la fente et la trace d'usure ;
--   - « Laser » (BasePart) + « Depart », « Arrivee » (Vector3 absolus du centre de la barre), « Periode »,
--     « Decalage » : balayage aller-retour régulier, mortel au contact (le serveur tue) ;
--   - « Effondrable » (BasePart du chemin) + « DelaiChute » (0,5) et « DelaiRetour » ;
--   - « Balancier » (BasePart solide) + « Pivot », « Axe », « Amplitude », « Periode », « Decalage » et « Poussee » :
--     les grandes pancartes qui basculent ;
--   - « Mobile » (BasePart du chemin) + « Deplacement » et « Duree » ; « Tournant » + « Vitesse » : comme dans le
--     tuto, mais plus rapides (1,7 à 1,85 rad/s contre 1,6, et des bras deux fois plus longs ; au-delà, la fenêtre
--     de passage tombe sous 1,2 s).
-- Aucune pièce n'est taguée « Mortel » ici : le « Mortel » de la ville (Parcours) sert de détecteur de chute, et les
-- lasers tuent par leur propre tag.
--
-- Sauts (personnage par défaut, les trois capacités débloquées) : on ne monte jamais de plus de 9 studs et on ne
-- franchit jamais plus de 16 studs de vide, la montée et le vide étant liés (plus on monte, moins on avance).
-- Chaque dalle est posée à la distance calculée de la précédente : un chemin existe par construction.
-- Contrôle : lune run outils/monde/verifier-ascension.luau

return function(R, biblio)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local Vector2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint =
		R.Vector2, R.NumberRange, R.NumberSequence, R.ColorSequence, R.ColorSequenceKeypoint

	math.randomseed(20261118) -- toute la variation est tirée ici : la construction est reproductible

	-- L'axe de l'ascension : le centre de Sup de Vinci ; le pied flotte 10 studs au-dessus de son toit (56).
	local SDV = biblio.parcours.supDeVinci
	local CX, CZ = (SDV.x1 + SDV.x2) / 2, (SDV.z1 + SDV.z2) / 2 -- 845, 0
	local BASE = SDV.toit + 10 -- 66 : dessus du pied de l'ascension

	-- Le chemin : six tranches de 43 studs, de plus en plus exigeantes et de plus en plus peuplées. Une entrée par
	-- tranche, dans l'ordre de la montée : ajouter une tranche = ajouter une entrée (la hauteur de la tour suit).
	-- - `couleur` : celle de la tranche (dalles, contours, lumières), prise si possible dans la palette commune
	--   (biblio.accents, biblio.couleurs) : on voit d'un coup d'œil où l'on en est ;
	-- - `serre` : la part du vide tenable qu'on s'autorise, LE bouton de difficulté (0,86 en bas, 0,96 en haut) ;
	-- - `special` : les sauts « porte » (voir PORTES plus bas) et la respiration, par rang de pas ;
	-- - `obstacles` : les familles posées sur la tranche, une par pas ; chacune doit avoir son poseur (registre
	--   `poseurs` plus bas), sinon la génération échoue.
	local segments = {
		{
			couleur = biblio.accents.vinci, -- 0 à 43
			pas = 10,
			serre = 0.86,
			monteeMax = 7,
			videMin = 10.5,
			videMax = 13,
			demi = { 3.6, 4.6 },
			rayon = 24,
			dAngle = 31,
			special = { [3] = "double", [7] = "course", [9] = "respiration" },
			obstacles = { "Mobile", "Tournant" },
		},
		{
			couleur = biblio.accents.soif, -- 43 à 86
			pas = 10,
			serre = 0.89,
			monteeMax = 7.5,
			videMin = 11,
			videMax = 13.5,
			demi = { 3.4, 4.4 },
			rayon = 26,
			dAngle = 33,
			special = { [4] = "dash", [8] = "double", [10] = "respiration" },
			obstacles = { "Laser", "Effondrable", "Balancier" },
		},
		{
			couleur = Color3.fromRGB(255, 140, 40), -- 86 à 129 (orange, un peu plus rouge que biblio.accents.coloc)
			pas = 10,
			serre = 0.92,
			monteeMax = 8,
			videMin = 11.5,
			videMax = 14,
			demi = { 3.2, 4.2 },
			rayon = 28,
			dAngle = 35,
			special = { [4] = "course", [8] = "dash", [10] = "respiration" },
			obstacles = { "PiegeMur", "Laser", "Mobile", "Tournant" },
		},
		{
			couleur = biblio.accents.cortege, -- 129 à 172
			pas = 11,
			serre = 0.94,
			monteeMax = 8.4,
			videMin = 12,
			videMax = 14.5,
			demi = { 3, 4 },
			rayon = 30,
			dAngle = 36,
			special = { [4] = "double", [8] = "course", [11] = "respiration" },
			obstacles = { "Balancier", "PiegeMur", "Laser", "Effondrable", "Mobile", "Tournant" },
		},
		{
			couleur = biblio.accents.tour, -- 172 à 215
			pas = 11,
			serre = 0.95,
			monteeMax = 8.6,
			videMin = 12.5,
			videMax = 15,
			demi = { 2.9, 3.8 },
			rayon = 32,
			dAngle = 38,
			special = { [4] = "dash", [9] = "double", [11] = "respiration" },
			obstacles = { "Laser", "Balancier", "PiegeMur", "Tournant", "Effondrable", "Mobile", "Laser" },
		},
		{
			couleur = biblio.couleurs.checkpoint, -- 215 à 258 (cyan sommet)
			pas = 11,
			serre = 0.96,
			monteeMax = 8.6,
			videMin = 13,
			videMax = 15.5,
			demi = { 2.8, 3.7 },
			rayon = 33,
			dAngle = 39,
			special = { [4] = "course", [8] = "dash", [11] = "respiration" },
			obstacles = {
				"PiegeMur",
				"Laser",
				"Tournant",
				"Balancier",
				"Mobile",
				"Effondrable",
				"Laser",
				"PiegeMur",
			},
		},
	}
	local NB_TRANCHES = #segments
	local TRANCHE = 43 -- 6 × 43 = 258 : la hauteur de la tour, découpée en six tranches de couleur
	local SOMMET = BASE + NB_TRANCHES * TRANCHE -- 324 : 258 studs au-dessus du départ
	local ECART_ETAGE = 15

	-- Palette : celle du jeu (biblio.couleurs) ; l'accès depuis la salle de partiel est orange coloc.
	local couleurs = biblio.couleurs
	local ACCES = biblio.accents.coloc

	local ascension = Instance.new("Model")
	ascension.Name = "Ascension"

	local function dossier(nom: string, parent)
		local d = Instance.new("Folder")
		d.Name = nom
		d.Parent = parent or ascension
		return d
	end

	local dAcces = dossier("Acces")
	local dPied = dossier("Pied")
	local dChemin = dossier("Chemin")
	local dObstacles = dossier("Obstacles")
	local dEtages = dossier("Etages")
	local dSommet = dossier("Sommet")
	local dDecor = dossier("Decor")

	---------------------------------------------------------------------------------------------------------------
	-- Outils de construction et textes : la bibliothèque commune (outils/monde/biblio.luau), un seul exemplaire.
	-- `piece`, `boule`, `cylindre` et `pente` sont fantômes ; `habiller` rend solide ce qui porte une dalle.
	local bloc, dalle, decor, fantome, brut, piece =
		biblio.bloc, biblio.dalle, biblio.decor, biblio.fantome, biblio.brut, biblio.piece
	local boule, cylindre, pente, DEBOUT = biblio.boule, biblio.cylindre, biblio.pente, biblio.DEBOUT
	local texte, etiquette, etiqueter, tableau, calibrerSurfaces =
		biblio.texte, biblio.etiquette, biblio.etiqueter, biblio.tableau, biblio.calibrerSurfaces
	local function contour(p, couleur, epaisseur)
		biblio.contour(p, couleur, epaisseur or 0.08) -- un peu plus épais que dans le tuto : on voit la tour de loin
	end

	local function lumiere(part, couleur, portee, force)
		local l = Instance.new("PointLight")
		l.Range = portee or 24
		l.Brightness = force or 1.4
		l.Color = couleur
		l.Parent = part
	end

	-- Tirage déterministe (math.randomseed en tête de construction).
	local function entre(a: number, b: number): number
		return a + (b - a) * math.random()
	end

	local function choix(liste)
		return liste[math.random(1, #liste)]
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le vocabulaire visuel de l'ascension : chaque dalle du chemin est habillée d'un objet rennais, posé SOUS elle
	-- (la dalle est son toit, son assise, son plateau). L'habillage est solide, d'aplomb et tient sous sa dalle
	-- (`habiller`, plus bas) : ce qui paraît être l'obstacle porte le joueur, et aucun saut n'en est raccourci.

	-- Centre, dessus et demi-dimensions d'une dalle.
	local function reperes(p)
		local pos, s = p.CFrame.Position, p.Size
		return pos.X, pos.Y + s.Y / 2, pos.Z, s.X / 2, s.Z / 2
	end

	-- Inclinaison ou orientation tirée, mais ramenée d'aplomb (0) ou au quart de tour : penché ou de biais, l'objet
	-- dépasserait de sa dalle. Le tirage reste, pour que ceux qui le suivent ne bougent pas.
	local function aplomb(a: number, b: number): number
		entre(a, b)
		return 0
	end
	local function quart(pas: number?): number
		local p = pas or 90
		return math.rad(p * math.floor(entre(0, 360) / p + 0.5))
	end

	local SLOGANS = {
		"ASCENSEUR EN PANNE",
		"GALETTE-SAUCISSE 24/7",
		"ÇA MONTE ENCORE",
		"AUCUN FILET, AUCUN PALIER",
		"PENSE À RESPIRER",
		"STAR · LIGNE VERTICALE",
		"TOUT EN HAUT ?",
		"CRACHIN À PARTIR DE 200",
		"DEUXIÈME SESSION",
		"ON Y EST PRESQUE (NON)",
	}

	-- Morceau d'immeuble rennais retourné : façade, bandeaux de fenêtres, un balcon dans le vide.
	local function objetImmeuble(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local h = entre(10, 18)
		local inclinaison = CFrame.Angles(aplomb(-18, 18), quart(), aplomb(-18, 18))
		local corps = CFrame.new(x, y - 1 - h / 2, z) * inclinaison
		piece(
			parent,
			"Facade",
			hx * 2 - 1.6, -- la place du balcon
			h,
			hz * 2,
			corps,
			choix({ couleurs.facade, couleurs.pierre }),
			Enum.Material.Concrete
		)
		for _, k in { -0.25, 0.15 } do
			piece(
				parent,
				"Fenetres",
				hx * 2 - 1.4,
				1.8,
				hz * 2 + 0.2,
				corps * CFrame.new(0, h * k, 0),
				Color3.fromRGB(150, 200, 235),
				Enum.Material.Glass
			)
		end
		piece(
			parent,
			"Balcon",
			1.2,
			0.4,
			2.5,
			corps * CFrame.new(hx - 0.4, h * 0.3, 0),
			couleurs.acier,
			Enum.Material.Metal
		)
		piece(
			parent,
			"Colombage",
			0.5,
			h * 0.8,
			0.5,
			corps * CFrame.new(hx * 0.6, 0, hz - 0.1),
			couleurs.colombage,
			Enum.Material.Wood
		)
		if math.random() < 0.4 then
			piece(
				parent,
				"ToitArrache",
				hx * 2 - 1.6, -- pas plus large que la façade : ce serait un rebord
				2,
				hz * 2,
				corps * CFrame.new(0, -h / 2 - 1, 0),
				couleurs.toit,
				Enum.Material.Slate
			)
		end
		contour(p, accent)
	end

	-- Bus STAR en travers : la dalle est son toit.
	local function objetBus(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local longX = hx >= hz
		local sx, sz = hx * 2, hz * 2
		local corps = CFrame.new(x, y - 4.5, z) * CFrame.Angles(0, 0, aplomb(-7, 7))
		piece(parent, "Bus", sx, 7, sz, corps, couleurs.bus)
		piece(parent, "BandeBus", sx + 0.2, 1.8, sz + 0.2, corps * CFrame.new(0, -2, 0), couleurs.metro)
		piece(
			parent,
			"VitresBus",
			sx - 1.5,
			2.4,
			sz - 1.5,
			corps * CFrame.new(0, 1.4, 0),
			Color3.fromRGB(40, 50, 70),
			Enum.Material.Glass
		)
		for _, d in { -1, 1 } do
			local dx, dz = if longX then sx * 0.3 * d else 0, if longX then 0 else sz * 0.3 * d
			cylindre(
				parent,
				"Roue",
				1.4,
				3,
				corps * CFrame.new(dx, -4, dz) * CFrame.Angles(0, if longX then math.rad(90) else 0, 0),
				Color3.fromRGB(25, 25, 25)
			)
		end
		local girouette = piece(
			parent,
			"Girouette",
			if longX then 0.3 else 5,
			1.6,
			if longX then 5 else 0.3,
			corps * CFrame.new(if longX then -sx / 2 - 0.2 else 0, 2.2, if longX then 0 else -sz / 2 - 0.2),
			Color3.fromRGB(10, 10, 10)
		)
		texte(
			if longX then Enum.NormalId.Left else Enum.NormalId.Front,
			"VERS LE HAUT",
			Color3.fromRGB(255, 170, 30),
			Color3.fromRGB(10, 10, 10)
		).Parent =
			girouette
		contour(p, accent)
	end

	-- Rame de métro debout : la dalle est le bout d'une voiture plantée à la verticale.
	local function objetRame(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local inclinaison = CFrame.Angles(aplomb(70, 110), quart(), 0)
		local corps = CFrame.new(x, y - 5.5, z) * inclinaison -- pas plus long : il descendrait dans les sauts d'en dessous
		piece(parent, "Rame", hx * 2, 9, hz * 2, corps, couleurs.quai, Enum.Material.Metal)
		piece(parent, "BandeauRame", hx * 2 + 0.2, 2.2, hz * 2 + 0.2, corps * CFrame.new(0, 3, 0), couleurs.metro)
		for _, k in { -2.6, 0.2 } do
			piece(
				parent,
				"PorteRame",
				hx * 2 + 0.2,
				2.4,
				2.2,
				corps * CFrame.new(0, k, hz - 1),
				Color3.fromRGB(40, 50, 70),
				Enum.Material.Glass
			)
		end
		cylindre(
			parent,
			"Pantographe",
			3,
			0.4,
			corps * CFrame.new(0, -4.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			couleurs.acier,
			Enum.Material.Metal
		)
		contour(p, accent)
	end

	-- Grue de chantier : la dalle est sa flèche, la tour plonge dans le vide.
	local function objetGrue(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local longX = hx >= hz
		local mat = Enum.Material.Metal
		local jaune = couleurs.pancarte
		piece(
			parent,
			"Fleche",
			if longX then hx * 2 else 1.2,
			1.2,
			if longX then 1.2 else hz * 2,
			CFrame.new(x, y - 2, z),
			jaune,
			mat
		)
		piece(
			parent,
			"TourGrue",
			2.2,
			10, -- plus long, il descendrait dans les sauts du tour d'en dessous
			2.2,
			CFrame.new(x, y - 7, z) * CFrame.Angles(aplomb(-14, 14), 0, aplomb(-14, 14)),
			jaune,
			mat
		)
		piece(
			parent,
			"ContrePoids",
			3,
			3,
			3,
			CFrame.new(x + (if longX then -hx + 1.5 else 0), y - 2.5, z + (if longX then 0 else -hz + 1.5)),
			couleurs.beton,
			Enum.Material.Concrete
		)
		local bout = CFrame.new(x + (if longX then hx - 1 else 0), y - 1, z + (if longX then 0 else hz - 1))
		piece(parent, "Cable", 0.2, 3, 0.2, bout * CFrame.new(0, -1.5, 0), Color3.fromRGB(40, 40, 45), mat)
		piece(parent, "Crochet", 1.2, 1.2, 1.2, bout * CFrame.new(0, -3.5, 0), couleurs.acier, mat)
		contour(p, accent)
	end

	-- Échafaudage : tubes et planches, la dalle est la planche du haut.
	local function objetEchafaudage(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local h = entre(9, 15)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				piece(
					parent,
					"Tube",
					0.45,
					h,
					0.45,
					CFrame.new(x + sx * (hx - 0.4), y - 1 - h / 2, z + sz * (hz - 0.4))
						* CFrame.Angles(0, 0, aplomb(-5, 5)),
					couleurs.acier,
					Enum.Material.Metal
				)
			end
		end
		piece(
			parent,
			"Planche",
			hx * 1.8,
			0.4,
			hz * 1.8,
			CFrame.new(x, y - 5, z), -- trop près de la dalle pour qu'on tienne debout entre les deux
			couleurs.ponton,
			Enum.Material.Wood
		)
		piece(
			parent,
			"Moise",
			hx * 2 - 0.8,
			0.3,
			0.3,
			CFrame.new(x, y - 3, z + hz - 0.4),
			couleurs.acier,
			Enum.Material.Metal
		)
		piece(
			parent,
			"Bache",
			hx * 2,
			h * 0.7,
			0.15,
			CFrame.new(x, y - 1 - h * 0.45, z - hz + 0.3),
			Color3.fromRGB(230, 240, 245),
			Enum.Material.Fabric
		)
		contour(p, accent)
	end

	-- Panneau publicitaire : la dalle est sa passerelle d'entretien, l'affiche pend dessous.
	local function objetPanneau(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local longX = hx >= hz
		local l = (if longX then hx else hz) * 2 - 0.5
		local cadre = CFrame.new(x, y - 5, z) * CFrame.Angles(0, if longX then 0 else math.rad(90), aplomb(-9, 9))
		local affiche = piece(parent, "Affiche", l, 7, 0.4, cadre, Color3.fromRGB(25, 25, 35))
		texte(Enum.NormalId.Front, choix(SLOGANS), couleurs.or_).Parent = affiche
		texte(Enum.NormalId.Back, choix(SLOGANS), couleurs.checkpoint).Parent = affiche
		piece(parent, "Lisere", l, 0.3, 0.6, cadre * CFrame.new(0, 3.7, 0), accent, Enum.Material.Neon)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Pied",
				0.6,
				12,
				0.38, -- pas plus épais que l'affiche : ce serait un rebord
				cadre * CFrame.new(d * l * 0.35, -9, 0),
				couleurs.acier,
				Enum.Material.Metal
			)
		end
		contour(p, accent)
	end

	-- Canapé retourné : la dalle est posée sur son dessous, le dossier pend.
	local function objetCanape(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local tissu = choix({ Color3.fromRGB(190, 70, 90), Color3.fromRGB(70, 110, 170), Color3.fromRGB(110, 150, 90) })
		local base = CFrame.new(x, y - 2.5, z) * CFrame.Angles(0, quart(), aplomb(-8, 8))
		piece(parent, "Assise", hx * 2, 3, hz * 2, base, tissu, Enum.Material.Fabric)
		piece(parent, "Dossier", hx * 2, 4, 1.2, base * CFrame.new(0, -3, 0.6 - hz), tissu, Enum.Material.Fabric)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Accoudoir",
				1.2,
				3,
				hz * 2,
				base * CFrame.new(d * (hx - 0.6), -2, 0),
				tissu,
				Enum.Material.Fabric
			)
		end
		piece(
			parent,
			"Coussin",
			hx,
			0.8,
			hz,
			base * CFrame.new(0, -1.8, 0.4),
			Color3.fromRGB(240, 230, 200),
			Enum.Material.Fabric
		)
		contour(p, accent)
	end

	-- Armoire couchée : la dalle est son flanc.
	local function objetArmoire(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 3, z) * CFrame.Angles(aplomb(-12, 12), quart(), 0)
		piece(parent, "Armoire", hx * 2 + 0.5, 5, hz * 2 + 0.5, base, couleurs.bois, Enum.Material.Wood)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Porte",
				hx - 0.3,
				4,
				0.3,
				base * CFrame.new(d * hx * 0.5, 0, hz + 0.3),
				Color3.fromRGB(165, 110, 62),
				Enum.Material.Wood
			)
			cylindre(
				parent,
				"Poignee",
				0.8,
				0.3,
				base * CFrame.new(d * 0.6, 0, hz + 0.4) * CFrame.Angles(math.rad(90), 0, 0),
				couleurs.acier,
				Enum.Material.Metal
			)
		end
		piece(
			parent,
			"Miroir",
			hx - 0.5,
			3,
			0.1,
			base * CFrame.new(0, 0, -hz - 0.2),
			Color3.fromRGB(200, 225, 235),
			Enum.Material.Glass
		)
		contour(p, accent)
	end

	-- Bureau de partiel : la dalle est le plateau, la chaise pend dessous.
	local function objetBureau(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				piece(
					parent,
					"PiedBureau",
					0.5,
					4,
					0.5,
					CFrame.new(x + sx * (hx - 0.6), y - 3, z + sz * (hz - 0.6)) * CFrame.Angles(aplomb(-6, 6), 0, 0),
					couleurs.bois,
					Enum.Material.Wood
				)
			end
		end
		piece(parent, "Caisson", hx, 2.5, hz, CFrame.new(x + hx * 0.4, y - 2.5, z), couleurs.bois, Enum.Material.Wood)
		local chaise = CFrame.new(x - hx + 1.4, y - 4, z) * CFrame.Angles(aplomb(-25, 25), quart(), aplomb(-25, 25))
		piece(parent, "Chaise", 2.4, 0.4, 2.4, chaise, couleurs.chaise)
		piece(parent, "DossierChaise", 2.4, 2.4, 0.4, chaise * CFrame.new(0, 1.4, -1), couleurs.chaise)
		local copie = piece(
			parent,
			"Copie",
			1.6,
			0.08,
			2.2,
			CFrame.new(x, y + 0.1, z) * CFrame.Angles(0, math.rad(entre(0, 360)), 0),
			couleurs.papier
		)
		texte(Enum.NormalId.Top, "0/20", Color3.fromRGB(200, 40, 40), couleurs.papier).Parent = copie
		contour(p, accent)
	end

	-- Bouée de la Vilaine : la dalle est posée sur l'anneau, aussi large que lui.
	local function objetBouee(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local r = math.max(hx, hz)
		cylindre(parent, "Bouee", 1.2, r * 2, CFrame.new(x, y - 1.6, z) * DEBOUT, Color3.fromRGB(245, 245, 245))
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.rad(45)
			piece(
				parent,
				"Quartier",
				r * 0.55,
				1.4,
				r * 0.55,
				CFrame.new(x + math.cos(a) * r * 0.5, y - 1.6, z + math.sin(a) * r * 0.5) * CFrame.Angles(0, -a, 0),
				if i % 2 == 0 then couleurs.metro else Color3.fromRGB(245, 245, 245)
			)
		end
		piece(
			parent,
			"Cordage",
			0.25,
			9,
			0.25,
			CFrame.new(x + r - 0.5, y - 6, z),
			couleurs.ponton,
			Enum.Material.Fabric
		)
		contour(p, accent)
	end

	-- Poubelle du cortège : la dalle est son couvercle.
	local function objetPoubelle(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local corps = CFrame.new(x, y - 3.5, z) * CFrame.Angles(aplomb(-10, 10), 0, aplomb(-10, 10))
		piece(parent, "Bac", hx * 2 - 0.4, 6, hz * 2 - 0.4, corps, couleurs.bac)
		piece(parent, "Rebord", hx * 2, 0.6, hz * 2, corps * CFrame.new(0, 2.8, 0), Color3.fromRGB(30, 120, 65))
		for _, d in { -1, 1 } do
			cylindre(
				parent,
				"Roulette",
				0.6,
				1.4,
				corps * CFrame.new(d * (hx - 1), -3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(30, 30, 30)
			)
		end
		boule(parent, "Sac", 3, x + hx - 1.8, y - 8, z - hz + 1.8, Color3.fromRGB(35, 35, 40))
		contour(p, accent)
	end

	-- Pancarte du cortège, plantée à l'envers.
	local function objetPancarte(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 1, z) * CFrame.Angles(0, quart(), aplomb(-12, 12))
		piece(parent, "Manche", 0.5, 14, 0.5, base * CFrame.new(0, -8, 0), couleurs.bois, Enum.Material.Wood)
		local carton =
			piece(parent, "Carton", math.max(hx, hz) * 2, 5, 0.35, base * CFrame.new(0, -5, 0.6), couleurs.pancarte)
		texte(Enum.NormalId.Front, choix(SLOGANS), Color3.fromRGB(35, 30, 20), couleurs.pancarte).Parent = carton
		piece(parent, "Scotch", 1.6, 0.2, 0.8, base * CFrame.new(0, -2.6, 0.5), couleurs.papier, Enum.Material.Fabric)
		contour(p, accent)
	end

	-- La galette-saucisse géante : la dalle est la galette, la saucisse roule à côté.
	local function objetGalette(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local r = math.max(hx, hz)
		cylindre(
			parent,
			"Galette",
			1.6,
			r * 2,
			CFrame.new(x, y - 1.8, z) * DEBOUT,
			couleurs.galette,
			Enum.Material.Sand
		)
		cylindre(
			parent,
			"Saucisse",
			r * 1.4,
			2.6,
			CFrame.new(x, y - 1.8, z - r * 0.55) * CFrame.Angles(0, math.rad(entre(-25, 25)), 0),
			couleurs.saucisse
		)
		piece(
			parent,
			"Papier",
			r * 1.6,
			0.1,
			r * 1.6,
			CFrame.new(x, y - 2.65, z) * CFrame.Angles(0, quart(), 0),
			couleurs.papier
		)
		piece(parent, "Moutarde", 0.6, 0.25, r * 0.8, CFrame.new(x, y - 0.6, z - r * 0.55), couleurs.pancarte)
		contour(p, accent)
	end

	-- Container de chantier, panneau de rue, cabine : des objets simples pour varier.
	local function objetContainer(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 3, z) * CFrame.Angles(aplomb(-9, 9), quart(180), 0)
		local teinte = choix({ Color3.fromRGB(200, 70, 60), Color3.fromRGB(60, 120, 160), couleurs.pancarte })
		piece(parent, "Container", hx * 2 + 0.6, 5, hz * 2 + 0.6, base, teinte, Enum.Material.CorrodedMetal)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Nervure",
				hx * 2 + 0.8,
				4.4,
				0.3,
				base * CFrame.new(0, 0, d * hz * 0.55),
				teinte,
				Enum.Material.CorrodedMetal
			)
		end
		piece(parent, "PlaqueRue", 3.2, 1, 0.2, base * CFrame.new(0, 1.2, hz + 0.5), Color3.fromRGB(35, 70, 130))
		contour(p, accent)
	end

	local OBJETS = {
		{ construire = objetImmeuble, long = false },
		{ construire = objetBus, long = true },
		{ construire = objetRame, long = false },
		{ construire = objetGrue, long = true },
		{ construire = objetEchafaudage, long = false },
		{ construire = objetPanneau, long = true },
		{ construire = objetCanape, long = false },
		{ construire = objetArmoire, long = false },
		{ construire = objetBureau, long = false },
		{ construire = objetBouee, long = false },
		{ construire = objetPoubelle, long = false },
		{ construire = objetPancarte, long = false },
		{ construire = objetGalette, long = false },
		{ construire = objetContainer, long = true },
	}

	-- Pose l'habillage d'une dalle, le réduit d'un seul tenant (autour du centre de la face de dessous) jusqu'à ce qu'il
	-- tienne dans son aplomb, et le rend solide. Solide sans requête (`decor`) : ce n'est pas une plateforme, et on ne
	-- peut se tenir debout nulle part dessus (outils/monde/verifier-bords.luau le prouve). Restent traversables les
	-- reliefs plaqués (0,1 stud : solides, ils feraient des rebords) et la corde de la bouée.
	local RELIEFS = { Fenetres = true, BandeBus = true, PorteRame = true, Copie = true, Cordage = true }
	local function habiller(objet, parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local dejaLa = #parent:GetChildren()
		objet(parent, p, accent)
		local pieces, k = {}, 1
		for i, e in parent:GetChildren() do
			if i <= dejaLa or e.Name == "Copie" then
				continue
			end
			local cf, t = e.CFrame, e.Size
			local a, b, c = cf.XVector * (t.X / 2), cf.YVector * (t.Y / 2), cf.ZVector * (t.Z / 2)
			k = math.min(
				k,
				(hx - 0.05) / (math.abs(cf.X - x) + math.abs(a.X) + math.abs(b.X) + math.abs(c.X)),
				(hz - 0.05) / (math.abs(cf.Z - z) + math.abs(a.Z) + math.abs(b.Z) + math.abs(c.Z))
			)
			table.insert(pieces, e)
		end
		local pied = Vector3.new(x, y - 1, z)
		for _, e in pieces do
			local position = e.CFrame.Position
			e.Size *= k
			e.CFrame = (e.CFrame - position) + (pied + (position - pied) * k)
			if not RELIEFS[e.Name] then
				e.CanCollide = true
			end
		end
	end

	local function melange(a, b, t: number)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end

	-- Arbre du Thabor qui flotte, posé sur une plateforme (décor pur).
	local function arbreFlottant(parent, x: number, base: number, z: number, taille: number?)
		local t = taille or 1
		fantome(
			bloc(
				parent,
				"Tronc",
				1.2 * t,
				6 * t,
				1.2 * t,
				x,
				base + 6 * t,
				z,
				Color3.fromRGB(110, 75, 50),
				Enum.Material.Wood
			)
		)
		boule(parent, "Feuillage", 7 * t, x, base + 9 * t, z, couleurs.feuillage, Enum.Material.Grass)
	end

	-- Toit à deux pans accroché à un repère (décor penché du fond).
	local function deuxPansFlottant(parent, cf, longueur: number, largeur: number)
		pente(
			parent,
			"Pan",
			longueur,
			largeur * 0.8,
			largeur / 2,
			cf * CFrame.new(0, 0, -largeur / 4),
			couleurs.toit,
			Enum.Material.Slate
		)
		pente(
			parent,
			"Pan",
			longueur,
			largeur * 0.8,
			largeur / 2,
			cf * CFrame.new(0, 0, largeur / 4) * CFrame.Angles(0, math.pi, 0),
			couleurs.toit,
			Enum.Material.Slate
		)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Règle de saut, les trois capacités débloquées (course, double saut, dash). Repères : saut debout 5 à 6 studs de
	-- vide et 4,5 de montée ; en courant 8 à 9 de vide ; double saut 9 de montée en tout ; dash 8 à 12 de vide en
	-- plus. Plus on monte, moins on avance : le vide tenable va de 16 studs à plat à 6 studs pour 9 de montée. Une
	-- descente aide un peu. C'est la règle que reprend outils/monde/verifier-ascension.luau.
	-- Constantes lues dans src/partage/Reglages.luau (bloc CONTROLE_*, les mêmes que le contrôle) : 9 de montée au
	-- plus, 16 de vide à plat, 10 de vide perdus en montant au maximum, 1 de vide gagné par 4 descendus (4 au plus).
	local Reglages = biblio.Reglages
	local MONTEE_MAX, VIDE_MAX = Reglages.CONTROLE_MONTEE_DOUBLE, Reglages.CONTROLE_ASCENSION_VIDE_MAX
	local PERTE_MAX = Reglages.CONTROLE_ASCENSION_PERTE * VIDE_MAX
	local BONUS_DESCENTE, DESCENTE_PAS = Reglages.CONTROLE_ASCENSION_BONUS_DESCENTE, Reglages.CONTROLE_DESCENTE_PAS
	local function videTenable(montee: number): number
		local v = VIDE_MAX - PERTE_MAX * math.max(0, montee) / MONTEE_MAX
		if montee < 0 then
			v += math.min(BONUS_DESCENTE, -montee / DESCENTE_PAS)
		end
		return v
	end

	type Pas = { x: number, z: number, y: number, hx: number, hz: number }

	-- Vide bord à bord entre deux dalles alignées sur les axes (la formule du contrôle).
	local function videEntre(a: Pas, b: Pas): number
		local gx = math.max(0, math.abs(b.x - a.x) - (a.hx + b.hx))
		local gz = math.max(0, math.abs(b.z - a.z) - (a.hz + b.hz))
		return math.sqrt(gx * gx + gz * gz)
	end

	-- Pose le pas suivant dans la direction (dx, dz) (normalisée) à exactement `ecart` studs de vide de `prec` : la
	-- distance est trouvée par dichotomie, donc chaque saut du chemin a la difficulté voulue, par construction.
	local function poser(prec: Pas, dx: number, dz: number, ecart: number, montee: number, hx: number, hz: number): Pas
		local bas, haut = 0, 400
		for _ = 1, 50 do
			local milieu = (bas + haut) / 2
			local essai = { x = prec.x + dx * milieu, z = prec.z + dz * milieu, y = prec.y + montee, hx = hx, hz = hz }
			if videEntre(prec, essai) < ecart then
				bas = milieu
			else
				haut = milieu
			end
		end
		local d = (bas + haut) / 2
		return { x = prec.x + dx * d, z = prec.z + dz * d, y = prec.y + montee, hx = hx, hz = hz }
	end

	-- La couleur de la tranche de 43 studs où l'on se trouve.
	local function teinteDe(y: number)
		local k = math.floor((y - BASE) / TRANCHE) + 1
		return segments[math.clamp(k, 1, #segments)].couleur
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le pied de l'ascension : 26 × 26 studs qui flottent 10 studs au-dessus du toit de la fac. C'est là que la
	-- chute renvoie, et là que sont les deux tableaux de classement.
	local pied = dalle(dPied, "PiedAscension", 26, 26, CX, BASE, CZ, couleurs.vinci, Enum.Material.DiamondPlate)
	etiqueter(pied, "PiedAscension")
	pied:SetAttribute("Hauteur", BASE)
	pied:SetAttribute("HauteurRelative", 0)
	contour(pied, segments[1].couleur, 0.22)
	etiquette(pied, "PIED DE L'ASCENSION", segments[1].couleur, 7, 400)
	lumiere(pied, segments[1].couleur, 40, 1.6)
	-- Le liseré ne dépasse pas de la dalle : plus large qu'elle, il passerait pour du sol.
	fantome(bloc(dPied, "Lisere", 26.2, 0.4, 26.2, CX, BASE + 0.1, CZ, segments[1].couleur, Enum.Material.Neon))
	for _, c in { -1, 1 } do
		-- Solide, sur la dalle, et plus haut (17) que les deux sauts enchaînés : on ne grimpe pas dessus.
		decor(
			bloc(
				dPied,
				"PilierPortique",
				1,
				17,
				1,
				CX - 12.5,
				BASE + 17,
				CZ + c * 12,
				segments[1].couleur,
				Enum.Material.Metal
			)
		)
	end
	local fronton = fantome(bloc(dPied, "Portique", 1.2, 4, 26, CX - 12.5, BASE + 17.1, CZ, Color3.fromRGB(20, 20, 30)))
	texte(Enum.NormalId.Right, "L'ASCENSION", segments[1].couleur).Parent = fronton
	local regles = fantome(bloc(dPied, "Regles", 12, 6, 0.4, CX + 2, BASE + 11, CZ - 14, Color3.fromRGB(20, 20, 30)))
	texte(Enum.NormalId.Back, "Tomber ramène ici.\nAucun palier : 258 studs d'un trait.", couleurs.or_).Parent = regles
	tableau(
		dPied,
		CX - 9,
		BASE,
		CZ + 14.5,
		Enum.NormalId.Front,
		"TableauHauteur",
		"Plus haut montés",
		segments[1].couleur,
		true -- accroché en l'air (pas de pieds : on est à 70 studs du sol)
	)
	tableau(
		dPied,
		CX + 9,
		BASE,
		CZ + 14.5,
		Enum.NormalId.Front,
		"TableauAscension",
		"Meilleures ascensions",
		couleurs.or_,
		true
	)
	-- Un bout de toit arraché sous le pied : on comprend qu'il flotte. Solide, dans l'aplomb de la dalle ; les poutres
	-- vont jusqu'au toit de la fac, loin des dalles de l'accès.
	decor(brut(dPied, "ToitArrache", 25.6, 3, 25.6, CFrame.new(CX, BASE - 2.5, CZ), couleurs.toit, Enum.Material.Slate))
	for _, d in { -1, 1 } do
		decor(
			brut(
				dPied,
				"Poutre",
				1.4,
				BASE - 4 - SDV.toit,
				1.4,
				CFrame.new(CX + d * 10, (BASE - 4 + SDV.toit) / 2, CZ + d * 8),
				couleurs.acier,
				Enum.Material.Metal
			)
		)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Les six familles d'obstacles. Tout ce qui bouge est posé à côté ou au-dessus d'une dalle du chemin : on le voit
	-- venir, on attend sa fenêtre, on saute. Le contrôle (outils/monde/verifier-ascension.luau) simule chaque cycle et
	-- exige au moins 1,2 s de passage libre, et qu'aucun obstacle ne couvre à lui seul toute la dalle.
	local compte: { [string]: number } = {} -- rang de chaque obstacle dans sa famille (registre `poseurs`)
	local function rang(famille: string): number
		compte[famille] = (compte[famille] or 0) + 1
		return compte[famille]
	end

	-- Direction horizontale radiale (vers l'extérieur de la tour) en un point : c'est là qu'il y a de la place pour
	-- faire tourner une barre ou dresser un mur sans heurter le reste du chemin.
	local function radiale(x: number, z: number, sens: number)
		local dx, dz = x - CX, z - CZ
		local m = math.sqrt(dx * dx + dz * dz)
		if m < 0.5 then
			dx, dz, m = 1, 0, 1
		end
		return sens * dx / m, sens * dz / m
	end

	-- Jusqu'où va la dalle dans la direction (rx, rz) : la fonction d'appui de sa boîte. C'est ce qu'il faut pour
	-- poser un mât ou un mur « juste à côté » d'une dalle, quelle que soit sa forme et le sens où l'on regarde.
	local function porteeVers(hx: number, hz: number, rx: number, rz: number): number
		return math.abs(rx) * hx + math.abs(rz) * hz
	end

	-- Où le bord de la dalle coupe le rayon qui part de son centre dans la direction (rx, rz). C'est ce qu'il faut
	-- pour qu'un bras tournant vienne vraiment raser la dalle : la fonction d'appui, elle, donne le coin le plus
	-- éloigné, qui n'est pas sur ce rayon.
	local function borduresurRayon(hx: number, hz: number, rx: number, rz: number): number
		local t = math.huge
		if math.abs(rx) > 1e-6 then
			t = math.min(t, hx / math.abs(rx))
		end
		if math.abs(rz) > 1e-6 then
			t = math.min(t, hz / math.abs(rz))
		end
		return t
	end

	-- Laser : barre de néon qui balaie la dalle d'un bord à l'autre, à hauteur de poitrine. Mortelle au contact (le
	-- serveur tue). Rythme fixe et apprenable : aller-retour régulier calé sur l'horloge du serveur.
	local function poserLaser(p)
		local x, y, z, hx, hz = reperes(p)
		local n = rang("Laser")
		-- Le balayage suit le petit côté de la dalle ; la barre est posée en travers, plus longue qu'elle.
		local selonX = hx <= hz
		local ux = if selonX then 1 else 0
		local uz = 1 - ux
		local course = (if selonX then hx else hz) + 5.5
		local longueur = (if selonX then hz else hx) * 2 + 9
		local centre = Vector3.new(x, y + 3, z)
		local depart = centre - Vector3.new(ux * course, 0, uz * course)
		local arrivee = centre + Vector3.new(ux * course, 0, uz * course)
		local barre = brut(
			dObstacles,
			`Laser{n}`,
			if selonX then 0.5 else longueur,
			0.5,
			if selonX then longueur else 0.5,
			CFrame.new(depart),
			Color3.fromRGB(255, 50, 60),
			Enum.Material.Neon
		)
		barre.CanCollide = false
		barre.CanQuery = false
		barre.CanTouch = true -- le serveur tue au contact
		barre:SetAttribute("Depart", depart)
		barre:SetAttribute("Arrivee", arrivee)
		barre:SetAttribute("Periode", entre(6, 7.5))
		barre:SetAttribute("Decalage", entre(0, 6))
		barre:AddTag("Laser")
		lumiere(barre, Color3.fromRGB(255, 60, 70), 18, 2)
		-- Les deux bornes qui tiennent le rail : on voit d'où part le faisceau et jusqu'où il va.
		for _, bout in { depart, arrivee } do
			local borne = piece(
				dObstacles,
				"BorneLaser",
				1.4,
				2.6,
				1.4,
				CFrame.new(bout.X, bout.Y - 0.6, bout.Z),
				Color3.fromRGB(40, 40, 48),
				Enum.Material.Metal
			)
			borne.CastShadow = false
		end
		return barre
	end

	-- Barre tournante : un mât planté dans le vide, à l'extérieur de la spirale, dont le bras vient raser la dalle.
	-- Plus rapide que dans le tuto (1,6 rad/s) : 1,7 à 1,85. Le bras est long et le mât loin, pour que la barre ne
	-- balaie qu'un bord de la dalle : c'est ce qui laisse plus de 1,2 s de passage par tour.
	local function poserTournant(p)
		local x, y, z, hx, hz = reperes(p)
		local n = rang("Tournant")
		local rx, rz = radiale(x, z, 1)
		local d = borduresurRayon(hx, hz, rx, rz) + 10 -- distance du mât au bord de la dalle, dans l'axe
		local px, pz = x + rx * d, z + rz * d
		local bras = 10 - 0.1 -- le bout du bras rase le bord de la dalle (marge de contact comprise), sans la couvrir
		local a = math.atan2(-rz, rx) -- l'angle qui met l'axe X local sur la radiale
		local barre = brut(
			dObstacles,
			`Tournant{n}`,
			bras * 2,
			1.2,
			1,
			CFrame.new(px, y + 2.8, pz) * CFrame.Angles(0, a + math.pi / 2, 0), -- au repos : en travers, hors de la dalle
			couleurs.acier,
			Enum.Material.DiamondPlate
		)
		barre.CanQuery = false -- comme dans le tuto : la barre pousse, on ne se tient pas dessus
		barre:SetAttribute("Vitesse", entre(1.7, 1.85)) -- plus vite que le tuto (1,6), sans fermer la fenêtre
		barre:AddTag("Tournant")
		piece(
			dObstacles,
			"MatTournant",
			1.6,
			16,
			1.6,
			CFrame.new(px, y - 4, pz),
			Color3.fromRGB(55, 58, 66),
			Enum.Material.Metal
		)
		for _, bout in { -1, 1 } do
			-- Enfant direct de la barre : le serveur le soude à elle au démarrage, il tourne avec. Il ne dépasse de la
			-- barre que de 0,05 (juste de quoi la recouvrir) : ce que le contrôle simule, c'est la barre.
			piece(
				barre,
				"BoutTournant",
				1.6,
				1.3,
				1.1,
				CFrame.new(px, y + 2.8, pz)
					* CFrame.Angles(0, a + math.pi / 2, 0)
					* CFrame.new(bout * (bras - 0.75), 0, 0),
				couleurs.pancarte,
				Enum.Material.Neon
			)
		end
		return barre
	end

	-- Pancarte qui bascule : un grand panneau pendu à une poutre, dans l'esprit des pendules de forteresse. Elle barre
	-- le passage et projette (attribut Poussee). Au repos elle pend au milieu de la dalle ; sur les bords de son
	-- amplitude elle se relève assez haut pour libérer le passage.
	local BALANCIER_BRAS = 6.5
	local function poserBalancier(p, accent)
		local x, y, z, hx, hz = reperes(p)
		local n = rang("Balancier")
		local sens = if n % 2 == 0 then -1 else 1
		local ux, uz = radiale(x, z, sens) -- le plan de balancement est radial : la pancarte sort dans le vide
		local axe = Vector3.new(-uz, 0, ux) -- l'axe de la charnière, horizontal et perpendiculaire au balancement
		local pivot = Vector3.new(x, y + 11.5, z)
		local a = math.atan2(-uz, ux)
		local pancarte = brut(
			dObstacles,
			`Balancier{n}`,
			0.6,
			5.5,
			math.max(hx, hz) * 2 + 2,
			CFrame.new(x, y + 11.5 - BALANCIER_BRAS, z) * CFrame.Angles(0, a, 0),
			couleurs.pancarte,
			Enum.Material.WoodPlanks
		)
		pancarte:SetAttribute("Pivot", pivot)
		pancarte:SetAttribute("Axe", axe)
		pancarte:SetAttribute("Amplitude", entre(74, 82))
		pancarte:SetAttribute("Periode", entre(4.6, 5.4))
		pancarte:SetAttribute("Decalage", entre(0, 4))
		pancarte:SetAttribute("Poussee", 1.6)
		pancarte:AddTag("Balancier")
		texte(Enum.NormalId.Right, choix(SLOGANS), Color3.fromRGB(35, 30, 20), couleurs.pancarte).Parent = pancarte
		-- La poutre et ses deux chandelles : on voit d'où pend la pancarte. Assez loin de la dalle pour ne pas en faire
		-- partie, assez près pour ne pas planter dans la dalle voisine.
		local ecart = math.max(math.max(hx, hz) + 2, porteeVers(hx, hz, uz, ux) + 1)
		piece(
			dObstacles,
			"PoutreBalancier",
			1,
			1,
			ecart * 2 + 0.8,
			CFrame.new(pivot.X, pivot.Y, pivot.Z) * CFrame.Angles(0, a, 0),
			couleurs.acier,
			Enum.Material.Metal
		)
		for _, c in { -1, 1 } do
			piece(
				dObstacles,
				"ChandelleBalancier",
				0.8,
				12,
				0.8,
				CFrame.new(pivot.X, pivot.Y - 6, pivot.Z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, c * ecart),
				couleurs.acier,
				Enum.Material.Metal
			)
		end
		contour(pancarte, accent, 0.1)
		return pancarte
	end

	-- Piège de mur : un pan de mur dressé au bord de la dalle. Seul indice avant qu'il parte : la fente et la trace
	-- d'usure laissée par les passages précédents (décision de l'utilisateur : pas de voyant, pas de clignotement).
	-- La barre sort d'un coup quand on entre dans sa portée, pousse fort, puis rentre. Le cycle est celui que lit le
	-- serveur (src/partage/Pieges.luau, `phasePiege`) : « DureeSortie » et « DureeRentree » sont les durées des deux
	-- mouvements (la pointe est dangereuse pendant les deux, soit DureeSortie + DureeRentree), et « Repos » est le
	-- temps rentré avant de pouvoir repartir — c'est la fenêtre de passage, et c'est pour ça qu'on la pose
	-- explicitement au lieu de laisser Reglages.PIEGE_REPOS décider à la place de la carte.
	local PIEGE_DEMI_POINTE = 2
	local function poserPiegeMur(p)
		local x, y, z, hx, hz = reperes(p)
		local n = rang("PiegeMur")
		local sens = if n % 2 == 0 then -1 else 1
		local nx, nz = radiale(x, z, sens) -- la normale qui va de la dalle vers le mur
		local appui = porteeVers(hx, hz, nx, nz)
		local demi = math.max(hx, hz)
		-- Le mur est assez loin pour que la pointe RENTRÉE (dont le bout affleure la face intérieure, à d − 1,2)
		-- laisse la dalle entièrement libre, marge de contact du client comprise : c'est la fenêtre de passage.
		local d = appui + 3.6
		local distance = d - 0.2 -- sortie complète : le bout dépasse le centre de la dalle de 1 stud
		local mx, mz = x + nx * d, z + nz * d
		local a = math.atan2(-nz, nx) -- l'axe X local du mur pointe vers l'extérieur, le long de la normale
		local repere = CFrame.new(mx, y + 4, mz) * CFrame.Angles(0, a, 0)
		local modele = Instance.new("Model")
		modele.Name = `PiegeMur{n}`
		modele.Parent = dObstacles
		modele:SetAttribute("Direction", Vector3.new(-nx, 0, -nz))
		modele:SetAttribute("Distance", distance)
		modele:SetAttribute("DureeSortie", entre(0.12, 0.18)) -- elle jaillit
		modele:SetAttribute("DureeRentree", entre(0.35, 0.5)) -- elle se rétracte un peu plus lentement : on la voit
		modele:SetAttribute("Repos", entre(1.8, 2.4)) -- la fenêtre de passage (1,2 s au moins, marge comprise)
		modele:SetAttribute("Portee", d + demi + 4)
		-- Pas d'attribut Poussee : Reglages.PIEGE_POUSSEE (60) s'applique, et il est sous DASH_VITESSE (70), donc un
		-- dash lancé dans l'autre sens reprend la main. Au-dessus, le piège tuerait, ce que la spec refuse.
		modele:AddTag("PiegeMur")
		piece(modele, "Mur", 2.4, 14, demi * 2 + 5, repere, couleurs.beton, Enum.Material.Concrete)
		-- L'indice, et lui seul : une fente dans la face intérieure et la traînée d'usure sous la fente.
		piece(
			modele,
			"Fente",
			0.3,
			1.7,
			7,
			repere * CFrame.new(-1.25, -1, 0),
			Color3.fromRGB(22, 22, 26),
			Enum.Material.Slate
		)
		piece(
			modele,
			"Usure",
			0.25,
			1.1,
			5.2,
			repere * CFrame.new(-1.27, -2.6, 0),
			Color3.fromRGB(128, 112, 92),
			Enum.Material.CorrodedMetal
		)
		piece(
			modele,
			"Caisson",
			3,
			4,
			5,
			repere * CFrame.new(2.4, -1, 0),
			Color3.fromRGB(48, 50, 58),
			Enum.Material.Metal
		)
		-- La pointe, rentrée : son bout affleure la face intérieure du mur (local X = -1,2).
		local pointe = brut(
			modele,
			"Pointe",
			PIEGE_DEMI_POINTE * 2,
			1.1,
			1.1,
			repere * CFrame.new(PIEGE_DEMI_POINTE - 1.2, -1, 0),
			couleurs.acier,
			Enum.Material.DiamondPlate
		)
		pointe.CanCollide = false
		pointe.CanQuery = false
		pointe.CanTouch = true -- le serveur applique l'impulsion au contact
		modele.PrimaryPart = pointe
		return modele
	end

	-- Plateforme qui s'effondre : elle tombe 0,5 s après le premier contact et revient quelques secondes plus tard.
	local function poserEffondrable(p)
		local x, y, z, hx, hz = reperes(p)
		rang("Effondrable")
		p.Color = Color3.fromRGB(226, 214, 186)
		p.Material = Enum.Material.WoodPlanks
		p:SetAttribute("DelaiChute", 0.5)
		p:SetAttribute("DelaiRetour", entre(3, 4.5))
		p:AddTag("Effondrable")
		for _, c in { -1, 1 } do
			piece(
				dObstacles,
				"PoutreRompue",
				hx * 0.9, -- dans l'aplomb de la dalle ; traversable : elle reste quand la dalle tombe
				0.5,
				0.5,
				CFrame.new(x + c * hx * 0.5, y - 1.6, z - c * hz * 0.5) * CFrame.Angles(0, 0, math.rad(c * 14)),
				couleurs.ponton,
				Enum.Material.Wood
			)
		end
		return p
	end

	-- Plateforme mobile : elle glisse en travers du chemin (jamais vers la dalle d'avant : elle la heurterait).
	local function poserMobile(p, teinte, dx: number, dz: number)
		local x, y, z, hx, hz = reperes(p)
		rang("Mobile")
		local amplitude = 11
		local ux, uz = -dz, dx -- perpendiculaire au sens de la marche
		local deplacement = Vector3.new(ux * amplitude, 0, uz * amplitude)
		p.CFrame = CFrame.new(x - ux * amplitude / 2, p.CFrame.Position.Y, z - uz * amplitude / 2)
		p.Material = Enum.Material.DiamondPlate
		p:SetAttribute("Deplacement", deplacement)
		p:SetAttribute("Duree", entre(2.2, 3))
		p:AddTag("Mobile")
		-- Le rail : on voit sur quelle course la nacelle va et vient. Un trait de lumière, pas une poutre : solide, il
		-- rattraperait qui rate la nacelle.
		local rail = piece(
			dObstacles,
			"RailMobile",
			if math.abs(ux) > math.abs(uz) then amplitude + hx * 2 else 0.4,
			0.4,
			if math.abs(ux) > math.abs(uz) then 0.4 else amplitude + hz * 2,
			CFrame.new(x, y - 1.2, z),
			teinte,
			Enum.Material.Neon
		)
		rail.Transparency = 0.6
		return p
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le chemin, tranche par tranche (`segments`, en tête de la construction).
	--
	-- Trois sortes de sauts « porte » rendent chaque capacité indispensable (deux par tranche, jamais les mêmes
	-- deux fois de suite) :
	-- - « course » : 15,3 studs de vide à plat, quand le vide maximal sans courir est de 14,5 (6,5 + 8 de dash) ;
	-- - « dash » : 13,5 studs de vide à plat, quand le vide maximal sans dash est de 9,75 (6,5 × 1,5) ;
	-- - « double » : 8 studs de montée, quand la montée maximale d'un saut simple est de 4,5.
	-- Une « respiration » par tranche (2 studs de montée, 3 de vide) laisse reprendre son souffle.
	local GATE_COURSE_VIDE = 15.3
	local GATE_DASH_VIDE = 13.5
	local GATE_DOUBLE_MONTEE = 8
	local MONTEE_MIN = 1.6
	local PORTES = {
		course = { montee = 0.2, vide = GATE_COURSE_VIDE },
		dash = { montee = 0.4, vide = GATE_DASH_VIDE },
		double = { montee = GATE_DOUBLE_MONTEE, vide = 3 },
		respiration = { montee = 2, vide = 3 },
	}

	-- Registre des poseurs : une entrée par famille d'obstacle que `segments` peut nommer. `poser(dalle, teinte, dx,
	-- dz)` habille la dalle (teinte de sa tranche, (dx, dz) le sens de la marche) ; `dalleNue` : la dalle bouge ou
	-- tombe, elle garde sa silhouette propre (rien de lourd dessous) et ne reçoit pas de plaque d'étage.
	-- Nouvelle famille = un poseur ici, son simulateur dans outils/monde/verifier-ascension.luau (registre
	-- FAMILLES), son tag dans TAGS_CONNUS (outils/monde/verifier-contrats.luau).
	local poseurs: { [string]: { poser: (any, any, number, number) -> any, dalleNue: boolean? } } = {
		Laser = { poser = poserLaser },
		Tournant = { poser = poserTournant },
		Balancier = { poser = poserBalancier },
		PiegeMur = { poser = poserPiegeMur },
		Effondrable = { poser = poserEffondrable, dalleNue = true },
		Mobile = { poser = poserMobile, dalleNue = true },
	}
	-- Une famille sans poseur ne poserait rien, en silence : on refuse de construire, avant le moindre tirage du
	-- chemin.
	for s, seg in segments do
		for _, famille in seg.obstacles do
			if not poseurs[famille] then
				local connues = {}
				for nom in poseurs do
					table.insert(connues, nom)
				end
				table.sort(connues)
				error(
					`Ascension : segments[{s}] nomme la famille d'obstacle inconnue « {famille} » (aucun poseur ; `
						.. `connues : {table.concat(connues, ", ")})`,
					0
				)
			end
		end
	end

	local chemin: { { pas: Pas, part: any } } = {} -- toutes les plateformes, du pied au sommet, dans l'ordre
	local speciales = {} -- les dalles qui bougent ou tombent : pas de plaque d'étage dessus
	local piedPas: Pas = { x = CX, z = CZ, y = BASE, hx = 13, hz = 13 }
	table.insert(chemin, { pas = piedPas, part = pied })

	local angle = math.rad(205) -- on part vers le sud-ouest (le drapeau breton de la fac est au nord-est)
	local prec = piedPas
	for s, seg in segments do
		local n = seg.pas
		local objectif = BASE + s * TRANCHE
		local special = seg.special or {}
		local function monteeDe(j: number, defaut: number): number
			local porte = PORTES[special[j] or ""]
			return if porte then porte.montee else defaut
		end
		-- Les pas qui reçoivent un obstacle : jamais une porte de capacité (elle doit rester lisible), jamais le
		-- sommet. Ils sont étalés sur la tranche.
		local libres = {}
		for j = 1, n do
			local role = special[j]
			local estSommet = s == #segments and j == n
			if (role == nil or role == "respiration") and not estSommet then
				table.insert(libres, j)
			end
		end
		local surPas = {}
		local pris = {}
		for k, famille in seg.obstacles do
			local rang = math.clamp(math.floor(k * #libres / (#seg.obstacles + 1) + 0.5), 1, #libres)
			while pris[rang] and rang < #libres do
				rang += 1
			end
			while pris[rang] and rang > 1 do
				rang -= 1
			end
			pris[rang] = true
			surPas[libres[rang]] = famille
		end

		for i = 1, n do
			-- Montée : ce qu'il reste à monter, réparti sur les pas restants en respectant leurs bornes.
			local reste = objectif - prec.y
			local sommeMax, sommeMin = 0, 0
			for j = i + 1, n do
				sommeMax += monteeDe(j, seg.monteeMax)
				sommeMin += monteeDe(j, MONTEE_MIN)
			end
			local bas = math.max(monteeDe(i, MONTEE_MIN), reste - sommeMax)
			local haut = math.min(monteeDe(i, seg.monteeMax), reste - sommeMin)
			haut = math.max(haut, bas)
			local montee = if i == n then reste else entre(bas, haut)
			-- Vide : celui de la porte, ou la part `serre` du vide tenable à cette montée.
			local porte = PORTES[special[i] or ""]
			local famille = surPas[i]
			local poseur = if famille then poseurs[famille] else nil
			local dalleNue = poseur ~= nil and poseur.dalleNue == true
			local ecart
			if porte then
				ecart = porte.vide
			else
				local voulu = entre(seg.videMin, seg.videMax)
				-- Une nacelle mobile s'aborde un peu moins à la limite : sa course décale le saut, et il faut
				-- qu'il reste possible plus d'une seconde par cycle (contrôle des fenêtres de passage).
				local pres = famille == "Mobile" or surPas[i - 1] == "Mobile"
				local part = if pres then 0.8 else seg.serre
				ecart = math.max(2.2, math.min(voulu, (videTenable(montee) - 0.35) * part))
			end
			-- Direction : la spirale autour de la fac, avec un rayon qui respire.
			angle += math.rad(seg.dAngle + entre(-8, 14))
			local rayon = seg.rayon + 8 * math.sin(angle * 1.7 + s)
			local dx, dz = CX + rayon * math.sin(angle) - prec.x, CZ - rayon * math.cos(angle) - prec.z
			local m = math.sqrt(dx * dx + dz * dz)
			if m < 0.5 then
				dx, dz, m = math.sin(angle), -math.cos(angle), 1
			end
			dx, dz = dx / m, dz / m
			local modele = OBJETS[math.random(1, #OBJETS)]
			local demi = entre(seg.demi[1], seg.demi[2])
			local hx, hz = demi, demi
			if modele.long and not dalleNue then
				if math.abs(dx) >= math.abs(dz) then
					hx, hz = demi * 1.9, demi * 0.8
				else
					hx, hz = demi * 0.8, demi * 1.9
				end
			end
			if famille == "Mobile" then
				hx, hz = demi + 0.8, demi + 0.8 -- une nacelle un peu plus large : on y atterrit en mouvement
			end
			if i == n and s == #segments then
				hx, hz = 13, 13
			end
			local suivant = poser(prec, dx, dz, ecart, montee, hx, hz)
			local part
			if i == n and s == #segments then
				part = dalle(
					dSommet,
					"SommetAscension",
					hx * 2,
					hz * 2,
					suivant.x,
					suivant.y,
					suivant.z,
					couleurs.or_,
					Enum.Material.Metal
				)
			else
				part = dalle(
					dChemin,
					`Pas{s}_{i}`,
					hx * 2,
					hz * 2,
					suivant.x,
					suivant.y,
					suivant.z,
					couleurs.beton,
					Enum.Material.Concrete
				)
				part.Color = melange(teinteDe(suivant.y), Color3.fromRGB(245, 245, 250), 0.45)
				-- Les dalles qui bougent ou s'effondrent gardent leur silhouette propre : rien de lourd dessous.
				if not dalleNue then
					habiller(modele.construire, dChemin, part, teinteDe(suivant.y))
				else
					contour(part, teinteDe(suivant.y))
				end
			end
			if poseur then
				poseur.poser(part, teinteDe(suivant.y), dx, dz)
				if dalleNue then
					speciales[part] = true
				end
			end
			table.insert(chemin, { pas = suivant, part = part })
			prec = suivant
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le sommet.
	local sommet = chemin[#chemin]
	local sp, sx, sy, sz = sommet.part, sommet.pas.x, sommet.pas.y, sommet.pas.z
	etiqueter(sp, "SommetAscension")
	sp:SetAttribute("Hauteur", sy)
	sp:SetAttribute("HauteurRelative", sy - BASE)
	contour(sp, couleurs.or_, 0.26)
	etiquette(sp, "SOMMET", couleurs.or_, 10, 600)
	lumiere(sp, couleurs.or_, 50, 2)
	fantome(bloc(dSommet, "Lisere", 26.2, 0.4, 26.2, sx, sy + 0.1, sz, couleurs.or_, Enum.Material.Neon))
	-- Le trophée : la galette-saucisse dorée, sur un socle.
	local galetteDoree = cylindre(
		dSommet,
		"GaletteDoree",
		2.4,
		14,
		CFrame.new(sx, sy + 7, sz) * DEBOUT,
		couleurs.or_,
		Enum.Material.Neon
	)
	local saucisseDoree = cylindre(
		dSommet,
		"SaucisseDoree",
		12,
		3.4,
		CFrame.new(sx, sy + 9, sz) * CFrame.Angles(0, math.rad(20), 0),
		couleurs.saucisse
	)
	galetteDoree.CanCollide = true -- le trophée est solide, comme son socle et son mât
	saucisseDoree.CanCollide = true
	for _, d in { -1, 1 } do
		decor(bloc(dSommet, "Socle", 2, 6, 2, sx + d * 5, sy + 6, sz + d * 5, couleurs.pierre, Enum.Material.Marble))
	end
	decor(
		bloc(dSommet, "Mat", 0.4, 16, 0.4, sx - 9, sy + 16, sz - 9, Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	)
	for i = 0, 8 do
		local c = if i % 2 == 0 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(250, 250, 250)
		fantome(bloc(dSommet, "Bande", 0.15, 0.5, 7, sx - 9, sy + 16 - i * 0.5, sz - 5.4, c, Enum.Material.Fabric))
	end
	local panneauSommet =
		fantome(bloc(dSommet, "PanneauSommet", 12, 4, 0.4, sx, sy + 15, sz + 12, Color3.fromRGB(20, 20, 30)))
	texte(Enum.NormalId.Back, `SOMMET · {SOMMET - BASE} studs`, couleurs.or_).Parent = panneauSommet
	local canon = fantome(bloc(dSommet, "Confettis", 14, 0.2, 14, sx, sy + 14, sz, couleurs.or_))
	canon.Transparency = 1
	local confettis = Instance.new("ParticleEmitter")
	confettis.Rate = 25
	confettis.Lifetime = NumberRange.new(3, 5)
	confettis.Speed = NumberRange.new(2, 5)
	confettis.SpreadAngle = Vector2.new(30, 30)
	confettis.Acceleration = Vector3.new(0, -4, 0)
	confettis.Rotation = NumberRange.new(0, 360)
	confettis.RotSpeed = NumberRange.new(-180, 180)
	confettis.Size = NumberSequence.new(0.35)
	confettis.EmissionDirection = Enum.NormalId.Bottom
	confettis.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, segments[1].couleur),
		ColorSequenceKeypoint.new(0.5, couleurs.or_),
		ColorSequenceKeypoint.new(1, segments[2].couleur),
	})
	confettis.Parent = canon

	---------------------------------------------------------------------------------------------------------------
	-- Les étages : une plaque à toucher tous les 15 studs de hauteur, sur la plateforme du chemin dont la hauteur
	-- est la plus proche. C'est elle qui compte l'étage franchi (aura croissante, côté serveur). Jamais sur une
	-- dalle qui bouge ou qui tombe : la plaque, elle, reste en place — on prend alors la voisine la plus proche,
	-- ce qui garde les étages à peu près réguliers.
	local depuis, numero = 2, 0
	for cible = BASE + ECART_ETAGE, SOMMET + 0.01, ECART_ETAGE do
		local choisi, ecartMin = nil, math.huge
		for k = depuis, #chemin do
			local maillon = chemin[k]
			if maillon.pas.y > cible + ECART_ETAGE then
				break
			end
			local e = math.abs(maillon.pas.y - cible)
			if not speciales[maillon.part] and e < ecartMin then
				choisi, ecartMin = k, e
			end
		end
		do
			local maillon = if choisi then chemin[choisi] else nil
			if maillon then
				numero += 1
				depuis = (choisi :: number) + 1
				local p = maillon.part
				local x, y, z, hx, hz = reperes(p)
				local teinte = teinteDe(y)
				local plaque = bloc(
					dEtages,
					`Etage{numero}`,
					hx * 2 - 0.6,
					0.7,
					hz * 2 - 0.6,
					x,
					y + 0.6,
					z,
					teinte,
					Enum.Material.Neon
				)
				plaque.CanCollide = false
				plaque.CanQuery = false
				plaque.Transparency = 0.5
				etiqueter(plaque, "EtageAscension")
				plaque:SetAttribute("Numero", numero)
				plaque:SetAttribute("Hauteur", y)
				plaque:SetAttribute("HauteurRelative", y - BASE)
				etiquette(plaque, `ÉTAGE {numero}`, teinte, 3.4, 170)
				-- Jamais de disque plus large que la dalle (ça passerait pour du sol) : un faisceau vertical.
				local faisceau = cylindre(
					dEtages,
					"FaisceauEtage",
					13,
					1.8,
					CFrame.new(x, y + 7, z) * DEBOUT,
					teinte,
					Enum.Material.Neon
				)
				faisceau.Transparency = 0.6
			end
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le décor de fond : des masses qui flottent loin du chemin, toujours penchées et toujours fantômes — rien de
	-- plat ni de coloré comme une dalle, pour qu'on ne s'y trompe jamais. Et du crachin breton, en altitude.
	local function masseFlottante(x: number, y: number, z: number, taille: number)
		local genre = math.random(1, 5)
		local inclinaison = CFrame.Angles(math.rad(entre(-35, 35)), math.rad(entre(0, 360)), math.rad(entre(-35, 35)))
		local cf = CFrame.new(x, y, z) * inclinaison
		if genre == 1 then -- morceau d'immeuble
			piece(
				dDecor,
				"ImmeubleFlottant",
				taille,
				taille * 2.2,
				taille * 0.9,
				cf,
				choix({ couleurs.facade, couleurs.pierre, couleurs.beton }),
				Enum.Material.Concrete
			)
			for _, k in { -0.3, 0, 0.3 } do
				piece(
					dDecor,
					"Fenetres",
					taille + 0.3,
					taille * 0.25,
					taille * 0.95,
					cf * CFrame.new(0, taille * 2.2 * k, 0),
					Color3.fromRGB(150, 200, 235),
					Enum.Material.Glass
				)
			end
			deuxPansFlottant(dDecor, cf * CFrame.new(0, taille * 1.3, 0), taille, taille * 0.9)
		elseif genre == 2 then -- rame de métro
			piece(
				dDecor,
				"RameFlottante",
				taille * 0.8,
				taille * 3,
				taille * 0.8,
				cf,
				couleurs.quai,
				Enum.Material.Metal
			)
			piece(
				dDecor,
				"BandeauRame",
				taille * 0.85,
				taille * 0.4,
				taille * 0.85,
				cf * CFrame.new(0, taille, 0),
				couleurs.metro
			)
			piece(
				dDecor,
				"VitresRame",
				taille * 0.7,
				taille * 1.8,
				taille * 0.86,
				cf,
				Color3.fromRGB(40, 50, 70),
				Enum.Material.Glass
			)
		elseif genre == 3 then -- grue à l'envers
			piece(
				dDecor,
				"TourGrue",
				taille * 0.5,
				taille * 4,
				taille * 0.5,
				cf,
				couleurs.pancarte,
				Enum.Material.Metal
			)
			piece(
				dDecor,
				"FlecheGrue",
				taille * 5,
				taille * 0.4,
				taille * 0.4,
				cf * CFrame.new(taille * 1.8, taille * 1.8, 0),
				couleurs.pancarte,
				Enum.Material.Metal
			)
			piece(
				dDecor,
				"ContrePoids",
				taille * 0.8,
				taille * 0.8,
				taille * 0.8,
				cf * CFrame.new(-taille, taille * 1.8, 0),
				couleurs.beton,
				Enum.Material.Concrete
			)
		elseif genre == 4 then -- panneau publicitaire géant
			local affiche =
				piece(dDecor, "AfficheGeante", taille * 3, taille * 1.6, 0.5, cf, Color3.fromRGB(25, 25, 35))
			texte(Enum.NormalId.Front, choix(SLOGANS), couleurs.or_).Parent = affiche
			piece(
				dDecor,
				"Lisere",
				taille * 3.2,
				0.4,
				0.8,
				cf * CFrame.new(0, taille * 0.85, 0),
				teinteDe(y),
				Enum.Material.Neon
			)
			for _, d in { -1, 1 } do
				piece(
					dDecor,
					"Pied",
					0.7,
					taille * 2.4,
					0.7,
					cf * CFrame.new(d * taille, -taille * 2, 0),
					couleurs.acier,
					Enum.Material.Metal
				)
			end
		else -- galette-saucisse géante
			cylindre(
				dDecor,
				"GaletteGeante",
				taille * 0.5,
				taille * 3.4,
				cf * DEBOUT,
				couleurs.galette,
				Enum.Material.Sand
			)
			cylindre(
				dDecor,
				"SaucisseGeante",
				taille * 2.6,
				taille * 0.7,
				cf * CFrame.new(0, taille * 0.4, 0),
				couleurs.saucisse
			)
		end
	end

	for i = 1, 26 do
		local a = math.rad(i * 61 + entre(-18, 18))
		local r = entre(52, 105)
		masseFlottante(CX + r * math.sin(a), entre(BASE + 6, SOMMET + 26), CZ - r * math.cos(a), entre(5, 13))
	end
	for i = 1, 22 do
		local a = math.rad(i * 97 + entre(-25, 25))
		local r = entre(58, 125)
		boule(
			dDecor,
			"Nuage",
			entre(14, 34),
			CX + r * math.sin(a),
			entre(BASE + 20, SOMMET + 40),
			CZ - r * math.cos(a),
			Color3.fromRGB(216, 222, 232)
		)
	end
	local crachin = fantome(bloc(dDecor, "Crachin", 90, 0.2, 90, CX, SOMMET + 22, CZ, Color3.fromRGB(200, 200, 210)))
	crachin.Transparency = 1
	local pluie = Instance.new("ParticleEmitter")
	pluie.Rate = 90
	pluie.Lifetime = NumberRange.new(2.5, 3.5)
	pluie.Speed = NumberRange.new(26, 32)
	pluie.EmissionDirection = Enum.NormalId.Bottom
	pluie.Size = NumberSequence.new(0.14)
	pluie.Transparency = NumberSequence.new(0.5)
	pluie.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
	pluie.Parent = crachin

	---------------------------------------------------------------------------------------------------------------
	-- L'accès depuis la salle de partiel (checkpoint 15, en 834, 42, 8 : dalle de 12 × 12, dessus à 42).
	--
	-- Sup de Vinci a une verrière ouverte dans son toit (outils/monde/Parcours.luau : trou x 832..844 / z 2..14,
	-- toit à 55-56) : on sort de la salle de partiel **par le haut**, en quatre sauts qui montent droit jusqu'au
	-- pied de l'ascension. Chaque saut monte de 6 studs sur les 9 possibles et ne franchit que 1 à 4 studs de vide :
	-- c'est une transition, pas une épreuve.
	-- Deux règles tiennent le placement : les deux dalles qui traversent la verrière (48 et 54) restent à 1 stud au
	-- moins du cadre, et aucune dalle n'est posée sous une autre à moins de 5,5 studs (ni sous le pied : la dernière
	-- est au nord du toit, hors de l'emprise du pied). Donc aucun plafond bas au-dessus d'une plateforme du tuto
	-- (la dalle du checkpoint 15, à 42, a 11 studs de libre) ni de l'accès.
	-- Le durcissement de l'atrium (spec 2026-11-18) a relevé le dernier palier du tuto en (845, 42, 12), qui passait
	-- à 5 studs sous « BureauVolant » : celui-ci recule donc de Z = 8 à Z = 5 (emprise Z 2..8 contre 9,5..14,5 pour
	-- le palier, 1,5 stud de marge). Il reste dans l'aplomb de la salle de partiel (Z 2..14), donc les quatre sauts
	-- ne changent pas.
	-- Ce bloc est construit en dernier pour que les tirages aléatoires du chemin et du décor ne changent pas.
	-- Les trois dalles sont placées par rapport à la salle de partiel (le dernier checkpoint de biblio.parcours).
	local salle = biblio.parcours.checkpoints[#biblio.parcours.checkpoints]
	local sx, sy, sz = salle.x, salle.dessus, salle.z
	local acces = {
		{ nom = "BureauVolant", x = sx + 10, y = sy + 6, z = sz - 3, hx = 3, hz = 3, objet = objetBureau }, -- 844, 48, 5
		{ nom = "ArmoireDeLaVerriere", x = sx + 2, y = sy + 12, z = sz + 2, hx = 3, hz = 3, objet = objetArmoire }, -- 836, 54, 10
		{ nom = "PanneauDuToit", x = sx + 2, y = sy + 18, z = sz + 12, hx = 3, hz = 3, objet = objetPanneau }, -- 836, 60, 20
	}
	for i, a in acces do
		local p = dalle(dAcces, a.nom, a.hx * 2, a.hz * 2, a.x, a.y, a.z, couleurs.beton, Enum.Material.Concrete)
		contour(p, ACCES, 0.12)
		habiller(a.objet, dAcces, p, ACCES)
		if i == 1 then
			p:SetAttribute("DepartAcces", true) -- repère du contrôle : d'ici, on doit atteindre le pied
			etiquette(p, "SORTIE ↑ PAR LA VERRIÈRE", ACCES, 4, 200)
		elseif i == 3 then
			etiquette(p, "L'ASCENSION ↑", ACCES, 4, 220)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Lisibilité, dernier mot : toute pièce où l'on pose les pieds porte un contour de la couleur de sa tranche
	-- (celles des objets l'ont déjà) ; rien d'autre n'en porte. Les obstacles qui poussent (barres tournantes,
	-- pancartes qui basculent) sont solides sans être du sol : ils gardent leur propre allure.
	for _, p in ascension:GetDescendants() do
		if not (p:IsA("BasePart") and p.CanCollide and p.CanQuery) or p:FindFirstChild("Contour") then
			continue
		end
		if not (p:HasTag("Tournant") or p:HasTag("Balancier")) then
			contour(p, teinteDe(p.CFrame.Position.Y))
		end
	end

	calibrerSurfaces(ascension)
	return ascension
end
