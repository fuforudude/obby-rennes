-- Construction des événements, des balanciers et des panneaux d'anecdotes de « Partiel maintenu ».
--
-- Même forme que outils/monde/Parcours.luau : renvoie une fonction qui reçoit R (constructeurs Roblox) et rend le
-- modèle construit (monde/Evenements.rbxm par outils/monde/generer.luau, ou aperçu dans Studio).
-- Les coordonnées des plateformes et des checkpoints viennent de Parcours.luau (elles ne bougent pas) ;
-- outils/monde/verifier-evenements.luau contrôle les horaires et les positions par rapport à monde/Parcours.rbxm.
--
-- Contrats (spec docs/specs/2026-11-13-evenements-batiments-interface.md) :
-- - tag « Evenement » sur un Model (PrimaryPart = son pivot) : attributs Type (« Passage » ou « Chute »), Periode,
--   Decalage (instant où le danger commence), Preavis ; Passage : Depart, Arrivee (positions du pivot),
--   DureePassage ; Chute : Hauteur, DureeChute. Enfant « Preavis » : lumière ou ombre, laissée à sa place posée par
--   le client (signal fixe près de la plateforme, ombre au sol sous le point d'impact). Toutes les pièces sont ancrées,
--   sans collision, sans toucher ni requête : le client les anime et teste le contact avec son personnage.
--   Un Passage est posé à son Depart ; une Chute est posée à son point d'impact (sur la dalle).
-- - tag « Balancier » sur une BasePart ancrée posée au repos : Pivot, Axe, Amplitude (degrés), Periode, Decalage.
--   Attributs de contrôle seulement (lus par verifier-evenements.luau, ignorés par le jeu) : ZoneControleMin et
--   ZoneControleMax, la boîte que le joueur traverse, où l'on mesure la fenêtre de passage.
-- - tag « PanneauAnecdote » + Numero (0 à 15) : SurfaceGui (face avant) avec un TextLabel « Texte » vide.

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local NumberRange, NumberSequence, ColorSequence = R.NumberRange, R.NumberSequence, R.ColorSequence

	math.randomseed(1312)
	local SOL = -10

	local racine = Instance.new("Model")
	racine.Name = "Evenements"

	local function dossier(parent, nom: string)
		local d = Instance.new("Folder")
		d.Name = nom
		d.Parent = parent
		return d
	end

	local accents = {
		coloc = Color3.fromRGB(255, 140, 60),
		fac = Color3.fromRGB(160, 90, 255),
		metro = Color3.fromRGB(255, 60, 80),
		cortege = Color3.fromRGB(255, 200, 30),
		tour = Color3.fromRGB(120, 230, 40),
		soif = Color3.fromRGB(255, 80, 190),
		vilaine = Color3.fromRGB(40, 190, 255),
		parlement = Color3.fromRGB(255, 215, 90),
		thabor = Color3.fromRGB(60, 220, 120),
		vinci = Color3.fromRGB(60, 140, 255),
	}

	---------------------------------------------------------------------------------------------------------------
	-- Outils.

	local DEBOUT = CFrame.Angles(0, 0, math.rad(90)) -- un cylindre Roblox est couché sur X : on le redresse

	-- Pièce ancrée placée par son CFrame (jamais par Position : non enregistrée dans le .rbxm).
	local function piece(parent, nom: string, sx, sy, sz, cf, couleur, materiau, forme)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = cf
		p.Color = couleur
		p.Material = materiau or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if forme then
			p.Shape = forme
		end
		p.Parent = parent
		return p
	end

	-- Décor qu'on traverse : sans collision, ne déclenche rien.
	local function fantome(p)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		return p
	end

	local function boite(parent, nom, x1, x2, y1, y2, z1, z2, couleur, materiau)
		return fantome(
			piece(
				parent,
				nom,
				x2 - x1,
				y2 - y1,
				z2 - z1,
				CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
				couleur,
				materiau
			)
		)
	end

	-- Rotation autour de la verticale pour que la face avant (-Z local) regarde dans la direction (dx, dz).
	local function versLaDirection(dx, dz)
		return CFrame.Angles(0, math.atan2(-dx, -dz), 0)
	end

	local function texteFixe(part, face, contenu: string, encre, fond)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Name = "Texte"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = fond
		label.TextColor3 = encre
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Text = contenu
		label.Parent = gui
		gui.Parent = part
	end

	-- Un objet d'événement : Model étiqueté, pièces sans collision.
	local function evenement(parent, nom: string, attributs: { [string]: any })
		local m = Instance.new("Model")
		m.Name = nom
		for cle, valeur in attributs do
			m:SetAttribute(cle, valeur)
		end
		m:AddTag("Evenement")
		m.Parent = parent
		return m
	end

	local function finir(modele, corps)
		modele.PrimaryPart = corps
		for _, d in modele:GetDescendants() do
			if d:IsA("BasePart") then
				fantome(d)
			end
		end
		return modele
	end

	-- Lumière de préavis (phares, clignotant, feu) : reste à sa place posée, le client la fait clignoter.
	local function lumiere(modele, sx, sy, sz, cf, couleur, forme)
		local l = piece(modele, "Preavis", sx, sy, sz, cf, couleur, Enum.Material.Neon, forme)
		l.CastShadow = false
		return l
	end

	-- Ombre au sol, sous le point d'impact d'une chute.
	local function ombre(modele, diametre, x, dessus, z)
		local o = piece(
			modele,
			"Preavis",
			0.06,
			diametre,
			diametre,
			CFrame.new(x, dessus + 0.03, z) * DEBOUT,
			Color3.fromRGB(15, 15, 20),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		o.Transparency = 0.4
		o.CastShadow = false
		return o
	end

	local racineEvenements = dossier(racine, "Evenements")
	local decor = dossier(racine, "Decor")

	---------------------------------------------------------------------------------------------------------------
	-- 1 · La coloc : pots de fleurs, linge et cartons qui tombent des balcons du dessus.
	-- Balcons de Parcours.luau (dalles 4 × 4, dessus) : B1 (7, 36, 3), B2 (14, 32, -3), B4 (30, 24, 6), B5 (37, 20, 0),
	-- B6 (44, 16, -6). L'étendoir mobile (22, 28, 0) n'a rien : il bouge déjà.
	local coloc = dossier(racineEvenements, "Coloc")
	local HAUTEUR_CHUTE, DUREE_CHUTE, PREAVIS_CHUTE = 14, 0.9, 1.2

	local function chute(nom, x, dessus, z, periode, decalage)
		return evenement(coloc, nom, {
			Type = "Chute",
			Periode = periode,
			Decalage = decalage,
			Preavis = PREAVIS_CHUTE,
			Hauteur = HAUTEUR_CHUTE,
			DureeChute = DUREE_CHUTE,
		})
	end

	local function potDeFleurs(x, dessus, z, periode, decalage)
		local m = chute("PotDeFleurs", x, dessus, z, periode, decalage)
		local pot = piece(
			m,
			"Pot",
			1.5,
			1.4,
			1.5,
			CFrame.new(x, dessus + 0.7, z),
			Color3.fromRGB(200, 100, 60),
			Enum.Material.Slate
		)
		local fleurs = Color3.fromHSV(math.random(), 0.7, 1)
		piece(
			m,
			"Geranium",
			1.9,
			1.9,
			1.9,
			CFrame.new(x, dessus + 2, z),
			fleurs,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		ombre(m, 2.6, x, dessus, z)
		return finir(m, pot)
	end

	local function linge(x, dessus, z, periode, decalage)
		local m = chute("Linge", x, dessus, z, periode, decalage)
		local couleur = Color3.fromHSV(math.random(), 0.45, 0.95)
		local drap = piece(
			m,
			"DrapMouille",
			2.8,
			0.25,
			2.4,
			CFrame.new(x, dessus + 0.4, z) * CFrame.Angles(0, math.rad(math.random(-20, 20)), math.rad(8)),
			couleur,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Chaussette",
			0.5,
			0.3,
			1.4,
			CFrame.new(x + 0.6, dessus + 0.7, z - 0.4),
			Color3.fromRGB(240, 240, 240),
			Enum.Material.Fabric
		)
		-- Le drap est plat : une boîte invisible lui donne la hauteur d'un objet qui touche.
		local contact = piece(m, "Contact", 2.6, 3, 2.4, CFrame.new(x, dessus + 1.5, z), couleur)
		contact.Transparency = 1
		ombre(m, 3, x, dessus, z)
		return finir(m, drap)
	end

	local function carton(x, dessus, z, periode, decalage)
		local m = chute("Carton", x, dessus, z, periode, decalage)
		local corps = piece(
			m,
			"Carton",
			2,
			1.7,
			2,
			CFrame.new(x, dessus + 0.85, z) * CFrame.Angles(0, math.rad(math.random(0, 40)), 0),
			Color3.fromRGB(190, 145, 95),
			Enum.Material.Cardboard
		)
		piece(
			m,
			"Scotch",
			2.05,
			0.1,
			0.4,
			corps.CFrame * CFrame.new(0, 0.86, 0),
			Color3.fromRGB(225, 200, 150),
			Enum.Material.SmoothPlastic
		)
		ombre(m, 2.8, x, dessus, z)
		return finir(m, corps)
	end

	-- Les balcons du dessus, d'où tombent les objets (décor sans collision).
	local function balconDuDessus(x, dessus, z)
		local y = dessus + HAUTEUR_CHUTE - 0.3
		boite(decor, "BalconDuDessus", x - 2.4, x + 2.4, y - 0.5, y, z - 2.4, z + 2.4, Color3.fromRGB(205, 205, 210))
		boite(
			decor,
			"Rambarde",
			x - 2.4,
			x + 2.4,
			y,
			y + 1.4,
			z + 2.2,
			z + 2.4,
			Color3.fromRGB(70, 75, 85),
			Enum.Material.Metal
		)
	end
	for _, b in { { 7, 36, 3 }, { 14, 32, -3 }, { 30, 24, 6 }, { 37, 20, 0 }, { 44, 16, -6 } } do
		balconDuDessus(b[1], b[2], b[3])
	end

	potDeFleurs(7.2, 36, 2.8, 6, 0)
	linge(14, 32, -3, 7, 2.5)
	carton(14.3, 32, -3.3, 10, 6)
	carton(30, 24, 6, 8, 3.3)
	potDeFleurs(37, 20, 0.2, 6.5, 1.4)
	linge(36.8, 20, -0.2, 9, 5.2)
	potDeFleurs(44, 16, -6, 7.5, 4.1)

	---------------------------------------------------------------------------------------------------------------
	-- 2 · Les escalators du viaduc : une rame de la ligne a qui coupe la descente, sur deux voies.
	-- Escalators (4 × 6) : E1 (213, 30), E2 (219, 26), E3 en panne (225, 22, fragile : on n'y attend pas), E4 (231, 18).
	local metro = dossier(racineEvenements, "Metro")
	local ROUGE_STAR = Color3.fromRGB(235, 50, 60)

	-- Une rame qui traverse en Z au niveau des pieds, de tunnel en tunnel ; un feu fixe près de l'escalator.
	-- `zMoins` : distance du centre de la rame cachée dans le tunnel côté -Z (45 par défaut, moins si le décor gêne).
	local function rame(nom, x, dessus, sens, periode, decalage, feuX, feuZ, zMoins)
		zMoins = zMoins or 45
		local yc = dessus + 0.2 + 3.5
		local bouts = { [-1] = Vector3.new(x, yc, -zMoins), [1] = Vector3.new(x, yc, 45) }
		local depart, arrivee = bouts[-sens], bouts[sens]
		local m = evenement(metro, nom, {
			Type = "Passage",
			Periode = periode,
			Decalage = decalage,
			Preavis = 1.5,
			Depart = depart,
			Arrivee = arrivee,
			DureePassage = 2,
		})
		local corps = piece(m, "Caisse", 5, 7, 22, CFrame.new(depart), ROUGE_STAR, Enum.Material.Metal)
		piece(
			m,
			"Vitres",
			5.1,
			2,
			20,
			CFrame.new(depart + Vector3.new(0, 1, 0)),
			Color3.fromRGB(30, 40, 60),
			Enum.Material.Glass
		)
		piece(
			m,
			"Phares",
			3.5,
			0.8,
			0.2,
			CFrame.new(depart + Vector3.new(0, -2.2, 11.05 * sens)),
			Color3.fromRGB(255, 245, 200),
			Enum.Material.Neon
		)
		lumiere(m, 0.9, 0.9, 0.9, CFrame.new(feuX, dessus + 5.5, feuZ), Color3.fromRGB(255, 70, 40), Enum.PartType.Ball)
		finir(m, corps)
		-- Décor : voie sous l'escalator, tunnels aux deux bouts, poteau du feu.
		boite(
			decor,
			"Voie",
			x - 2,
			x + 2,
			dessus - 2.2,
			dessus - 1,
			-zMoins - 12,
			57,
			Color3.fromRGB(120, 125, 135),
			Enum.Material.Concrete
		)
		for _, bout in { -zMoins, 45 } do
			boite(
				decor,
				"Tunnel",
				x - 3.2,
				x + 3.2,
				dessus - 1,
				dessus + 8.6,
				bout - 12.5,
				bout + 12.5,
				Color3.fromRGB(45, 45, 55),
				Enum.Material.Concrete
			)
		end
		boite(
			decor,
			"PoteauFeu",
			feuX - 0.2,
			feuX + 0.2,
			SOL,
			dessus + 5,
			feuZ - 0.2,
			feuZ + 0.2,
			Color3.fromRGB(50, 50, 55)
		)
	end
	rame("RameLigneA", 219, 26, 1, 8, 1, 222.6, -5)
	rame("RameLigneA", 231, 18, -1, 9.5, 5, 234.6, 5, 22.5) -- pavillon de l'hôtel de ville en z < -35

	---------------------------------------------------------------------------------------------------------------
	-- 3 · Les échafaudages de la tour : des drones de livraison qui coupent la descente.
	-- Échafaudages (4 × 4) : S1 (421, 58, 0), S2 (430, 50, 4), S3 (439, 42, -4), S4 (448, 34, 0). Le rebord
	-- (412, 66), à la sortie de la fenêtre, reste sûr : on y attend.
	local tour = dossier(racineEvenements, "Tour")
	local tubesPoses = {}

	-- `zMin` : bout du trajet côté -Z (z - 28 par défaut, plus près là où le décor gêne).
	local function drone(x, dessus, z, sens, periode, decalage, zMin)
		local yc = dessus + 3.2
		local bouts = { [-1] = Vector3.new(x, yc, zMin or z - 28), [1] = Vector3.new(x, yc, z + 28) }
		local depart, arrivee = bouts[-sens], bouts[sens]
		local m = evenement(tour, "DroneDeLivraison", {
			Type = "Passage",
			Periode = periode,
			Decalage = decalage,
			Preavis = 1.3,
			Depart = depart,
			Arrivee = arrivee,
			DureePassage = 1.6,
		})
		local corps = piece(
			m,
			"Corps",
			1.6,
			0.7,
			1.6,
			CFrame.new(depart),
			Color3.fromRGB(240, 240, 245),
			Enum.Material.SmoothPlastic
		)
		piece(
			m,
			"Helices",
			2.8,
			0.15,
			2.8,
			CFrame.new(depart + Vector3.new(0, 0.45, 0)),
			Color3.fromRGB(35, 35, 40),
			Enum.Material.Metal
		)
		piece(
			m,
			"Colis",
			1.3,
			1.2,
			1.3,
			CFrame.new(depart + Vector3.new(0, -1, 0)),
			Color3.fromRGB(190, 145, 95),
			Enum.Material.Cardboard
		)
		-- Clignotant sur le tube d'échafaudage, au coin de la dalle (un tube par dalle, partagé).
		local tx, tz = x + 2.4, z - 2.4 * sens
		local cle = `{x},{dessus}`
		local decalageLampe = if tubesPoses[cle] then 1.1 else 0
		lumiere(
			m,
			0.8,
			0.8,
			0.8,
			CFrame.new(tx, dessus + 4.8 + decalageLampe, tz),
			Color3.fromRGB(255, 170, 20),
			Enum.PartType.Ball
		)
		boite(
			decor,
			"TubeEchafaudage",
			tx - 0.18,
			tx + 0.18,
			SOL,
			dessus + 4.4 + decalageLampe,
			tz - 0.18,
			tz + 0.18,
			Color3.fromRGB(240, 160, 40),
			Enum.Material.Metal
		)
		tubesPoses[cle] = true
		return finir(m, corps)
	end
	drone(421, 58, 0, 1, 6, 0.5)
	drone(430, 50, 4, -1, 7, 3)
	drone(439, 42, -4, 1, 5.5, 2, -15) -- affiche « ascenseur en panne » en z = -17
	drone(448, 34, 0, -1, 8, 5)
	drone(448, 34, 0, 1, 12, 9.5)

	---------------------------------------------------------------------------------------------------------------
	-- 4 · Rue de la Soif : voitures, bus et trottinettes qui coupent la terrasse en Z, sur sa bande d'entrée
	-- (X 517 à 520,6), hors du balayage de l'enseigne tournante (rayon 11 autour de X = 532). On attend sur le
	-- dernier auvent (511, 14), on traverse la bande, puis l'enseigne.
	-- Ils sortent d'une porte cochère et entrent dans celle d'en face.
	local soif = dossier(racineEvenements, "RueDeLaSoif")
	local VOIE_X, DESSUS_TERRASSE = 518.8, 10

	local function vehicule(nom, longueur, sens, periode, decalage, duree, hauteurPhare)
		local demi = longueur / 2
		local zDepart = -(9 + demi + 0.5) * sens
		local m = evenement(soif, nom, {
			Type = "Passage",
			Periode = periode,
			Decalage = decalage,
			Preavis = 1.3,
			Depart = Vector3.new(VOIE_X, 0, zDepart), -- Y fixé par l'appelant
			Arrivee = Vector3.new(VOIE_X, 0, -zDepart),
			DureePassage = duree,
		})
		-- Phares de préavis, fixes, à la bouche de la porte cochère de départ.
		lumiere(
			m,
			2.6,
			0.6,
			0.2,
			CFrame.new(VOIE_X, DESSUS_TERRASSE + hauteurPhare, -9.3 * sens),
			Color3.fromRGB(255, 245, 190)
		)
		return m, zDepart
	end

	local function poserPivot(m, corps)
		local pos = corps.CFrame.Position
		m:SetAttribute("Depart", pos)
		m:SetAttribute("Arrivee", Vector3.new(pos.X, pos.Y, -pos.Z))
		return finir(m, corps)
	end

	local function voiture(sens, periode, decalage)
		local m, z = vehicule("Voiture", 6, sens, periode, decalage, 1.1, 1.1)
		local couleur = Color3.fromHSV(math.random(), 0.6, 0.9)
		local y0 = DESSUS_TERRASSE + 0.3
		local corps =
			piece(m, "Carrosserie", 3.4, 1.6, 6, CFrame.new(VOIE_X, y0 + 0.8, z), couleur, Enum.Material.Metal)
		piece(m, "Habitacle", 3, 1.4, 3.4, CFrame.new(VOIE_X, y0 + 2.3, z - 0.3 * sens), couleur, Enum.Material.Metal)
		piece(
			m,
			"Vitres",
			3.05,
			1,
			3.45,
			CFrame.new(VOIE_X, y0 + 2.35, z - 0.3 * sens),
			Color3.fromRGB(40, 50, 70),
			Enum.Material.Glass
		)
		return poserPivot(m, corps)
	end

	local function bus(sens, periode, decalage)
		local m, z = vehicule("BusStar", 6.8, sens, periode, decalage, 1.8, 4.6)
		local y0 = DESSUS_TERRASSE + 0.3
		local corps = piece(
			m,
			"Caisse",
			3.6,
			5.5,
			6.8,
			CFrame.new(VOIE_X, y0 + 2.75, z),
			Color3.fromRGB(235, 235, 240),
			Enum.Material.Metal
		)
		piece(m, "Bande", 3.65, 1, 6.85, CFrame.new(VOIE_X, y0 + 1, z), ROUGE_STAR, Enum.Material.Metal)
		piece(
			m,
			"Vitres",
			3.65,
			1.6,
			6.2,
			CFrame.new(VOIE_X, y0 + 3.6, z),
			Color3.fromRGB(40, 50, 70),
			Enum.Material.Glass
		)
		return poserPivot(m, corps)
	end

	local function trottinette(sens, periode, decalage)
		local m, z = vehicule("Trottinette", 3, sens, periode, decalage, 0.9, 1.9)
		local y0 = DESSUS_TERRASSE + 0.3
		local corps = piece(
			m,
			"Plateau",
			0.8,
			0.3,
			3,
			CFrame.new(VOIE_X, y0 + 0.15, z),
			Color3.fromRGB(30, 30, 35),
			Enum.Material.Metal
		)
		piece(
			m,
			"Guidon",
			0.3,
			3.2,
			0.3,
			CFrame.new(VOIE_X, y0 + 1.9, z + 1.3 * sens),
			Color3.fromRGB(60, 200, 120),
			Enum.Material.Metal
		)
		local couleur = Color3.fromHSV(math.random(), 0.5, 0.8)
		piece(m, "Pilote", 1.6, 2.2, 1, CFrame.new(VOIE_X, y0 + 2.7, z), couleur, Enum.Material.Fabric)
		piece(
			m,
			"Casque",
			1.2,
			1.2,
			1.2,
			CFrame.new(VOIE_X, y0 + 4.4, z),
			Color3.fromRGB(250, 210, 40),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		return poserPivot(m, corps)
	end

	-- Périodes de pgcd 4 (cycle complet de 48 s) : deux véhicules ne sont jamais dans la voie en même temps.
	voiture(1, 8, 0)
	bus(1, 16, 3.6)
	trottinette(-1, 12, 2.1)
	voiture(-1, 24, 17.7)

	-- Les portes cochères (décor sans collision), au-delà de la portée de l'enseigne, et la chaussée entre elles et
	-- la terrasse.
	local pierre = Color3.fromRGB(225, 205, 175)
	for _, cote in { -1, 1 } do
		local z1, z2 = if cote < 0 then -16.4 else 9, if cote < 0 then -9 else 16.4
		boite(decor, "PorteCochere", 511.5, VOIE_X - 2.1, SOL, 30, z1, z2, pierre, Enum.Material.Brick)
		boite(decor, "PorteCochere", VOIE_X + 2.1, 524, SOL, 30, z1, z2, pierre, Enum.Material.Brick)
		boite(decor, "PorteCochere", VOIE_X - 2.1, VOIE_X + 2.1, 17, 30, z1, z2, pierre, Enum.Material.Brick)
		boite(
			decor,
			"PorteCochere",
			VOIE_X - 2.1,
			VOIE_X + 2.1,
			SOL,
			9.9,
			z1,
			z2,
			Color3.fromRGB(70, 70, 75),
			Enum.Material.Asphalt
		)
		local za, zb = if cote < 0 then -9 else 5, if cote < 0 then -5 else 9
		boite(
			decor,
			"Chaussee",
			VOIE_X - 2.1,
			VOIE_X + 2.1,
			9.3,
			9.9,
			za,
			zb,
			Color3.fromRGB(70, 70, 75),
			Enum.Material.Asphalt
		)
		local toit = boite(decor, "Toit", 511, 524.5, 30, 31, z1, z2, Color3.fromRGB(85, 95, 120), Enum.Material.Slate)
		toit.CastShadow = true
	end

	---------------------------------------------------------------------------------------------------------------
	-- Balanciers : une seule pièce qui bascule autour de son pivot ; le serveur la libère et la fait osciller.
	-- Ils poussent, ils ne tuent pas.
	local balanciers = dossier(racine, "Balanciers")

	local function balancier(p, pivot, axe, amplitude, periode, decalage, zoneMin, zoneMax)
		p.CanQuery = false
		p:SetAttribute("Pivot", pivot)
		p:SetAttribute("Axe", axe.Unit)
		p:SetAttribute("Amplitude", amplitude)
		p:SetAttribute("Periode", periode)
		p:SetAttribute("Decalage", decalage)
		p:SetAttribute("ZoneControleMin", zoneMin)
		p:SetAttribute("ZoneControleMax", zoneMax)
		p:AddTag("Balancier")
		return p
	end

	-- Corde visuelle (Beam) entre un point fixe d'une pièce de décor et un point de la pièce qui bouge.
	local function corde(fixe, pointFixe, mobile, pointMobile, couleur)
		local a0 = Instance.new("Attachment")
		a0.Name = "Accroche"
		a0.CFrame = fixe.CFrame:Inverse() * CFrame.new(pointFixe)
		a0.Parent = fixe
		local a1 = Instance.new("Attachment")
		a1.Name = "Accroche"
		a1.CFrame = mobile.CFrame:Inverse() * CFrame.new(pointMobile)
		a1.Parent = mobile
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.3
		b.Width1 = 0.3
		b.FaceCamera = true
		b.Segments = 1
		b.Color = ColorSequence.new(couleur)
		b.Transparency = NumberSequence.new(0)
		b.LightInfluence = 1
		b.Parent = mobile
	end

	-- Porte battante de l'amphi : la porte va-et-vient de la fenêtre de sortie (X 124 à 125, Z -4 à 4, Y 31 à 40),
	-- gond côté Z = -3,6. On saute du checkpoint 2 vers le rebord (128, 31) quand elle est ouverte.
	do
		local porte = piece(
			balanciers,
			"PorteBattanteAmphi",
			0.4,
			7,
			7.2,
			CFrame.new(124.5, 34.8, 0),
			Color3.fromRGB(150, 95, 55),
			Enum.Material.Wood
		)
		texteFixe(
			porte,
			Enum.NormalId.Left,
			"AMPHI B\nPOUSSEZ",
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(110, 60, 30)
		)
		texteFixe(
			porte,
			Enum.NormalId.Right,
			"AMPHI B\nTIREZ",
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(110, 60, 30)
		)
		balancier(
			porte,
			Vector3.new(124.5, 34.8, -3.6),
			Vector3.new(0, 1, 0),
			80,
			5.5,
			0,
			Vector3.new(123, 31.5, -1.5),
			Vector3.new(126, 36, 4)
		)
	end

	-- Portillons du portique de validation, à la sortie de la station (checkpoint 4, dalle 237..249 × -6..6) :
	-- deux battants en miroir qui s'ouvrent et se ferment ensemble.
	do
		local station = dossier(decor, "PortiqueStation")
		for _, cote in { -1, 1 } do
			local gondZ = 5.9 * cote
			local battant = piece(
				balanciers,
				"PortillonValidation",
				0.3,
				4.5,
				5.6,
				CFrame.new(247, 16.55, gondZ - 2.8 * cote),
				Color3.fromRGB(190, 225, 240),
				Enum.Material.Glass
			)
			battant.Transparency = 0.25
			balancier(
				battant,
				Vector3.new(247, 16.55, gondZ),
				Vector3.new(0, -cote, 0),
				75,
				6,
				1,
				Vector3.new(246, 14.5, -2),
				Vector3.new(248, 19, 2)
			)
			local valideur = boite(
				station,
				"Valideur",
				246.5,
				247.5,
				14,
				19.4,
				6.05 * cote - 0.25,
				6.05 * cote + 0.25,
				Color3.fromRGB(60, 65, 75),
				Enum.Material.Metal
			)
			valideur.CastShadow = true
			boite(
				station,
				"Voyant",
				246.4,
				247.6,
				18.4,
				19,
				6.05 * cote - 0.3,
				6.05 * cote + 0.3,
				Color3.fromRGB(80, 230, 90),
				Enum.Material.Neon
			)
		end
	end

	-- Pancarte géante du cortège, suspendue à un portique au-dessus de la sortie du checkpoint 5 (X 302) :
	-- elle balance en travers du chemin.
	do
		local d = dossier(decor, "PortiqueCortege")
		local poutre =
			boite(d, "Poutre", 301.5, 302.5, 34, 35, -19.5, 19.5, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		for _, cote in { -1, 1 } do
			boite(
				d,
				"Poteau",
				301.5,
				302.5,
				SOL,
				34,
				cote * 19 - 0.5,
				cote * 19 + 0.5,
				Color3.fromRGB(60, 60, 70),
				Enum.Material.Metal
			)
		end
		local pancarte = piece(
			balanciers,
			"PancarteGeante",
			0.6,
			5,
			7,
			CFrame.new(302, 22.3, 0),
			Color3.fromRGB(255, 205, 40),
			Enum.Material.SmoothPlastic
		)
		texteFixe(
			pancarte,
			Enum.NormalId.Left,
			"PLUS DE CRÊPES\nAU RU",
			Color3.fromRGB(190, 30, 30),
			Color3.fromRGB(255, 220, 90)
		)
		texteFixe(
			pancarte,
			Enum.NormalId.Right,
			"DES PRISES\nDANS L'AMPHI",
			Color3.fromRGB(190, 30, 30),
			Color3.fromRGB(255, 220, 90)
		)
		for _, dz in { -3, 3 } do
			corde(poutre, Vector3.new(302, 34, 0), pancarte, Vector3.new(302, 24.8, dz), Color3.fromRGB(80, 60, 40))
		end
		balancier(
			pancarte,
			Vector3.new(302, 34, 0),
			Vector3.new(1, 0, 0),
			70,
			7,
			2,
			Vector3.new(301, 19.5, -6),
			Vector3.new(303, 24.5, 6)
		)
	end

	-- Cloche (les clochers ne sont jamais loin, rue de la Soif) : clocheton au-dessus de la sortie du checkpoint 9,
	-- sur le toit plat du bar « Le Rattrapage » (dalle 482..494 × -6..6, dessus 28 ; les maisons voisines ont des
	-- pignons qui gêneraient la cloche).
	do
		local d = dossier(decor, "Clocheton")
		local X, PIVOT_Y = 492, 40
		local bois = Color3.fromRGB(95, 60, 35)
		local poutre = boite(d, "Joug", X - 0.6, X + 0.6, PIVOT_Y, PIVOT_Y + 1.2, -13.5, 13.5, bois, Enum.Material.Wood)
		for _, cote in { -1, 1 } do
			boite(
				d,
				"Montant",
				X - 0.6,
				X + 0.6,
				SOL,
				PIVOT_Y,
				cote * 13 - 0.6,
				cote * 13 + 0.6,
				bois,
				Enum.Material.Wood
			)
		end
		local cloche = piece(
			balanciers,
			"Cloche",
			3.4,
			3.2,
			3.2,
			CFrame.new(X, 30, 0) * DEBOUT,
			Color3.fromRGB(190, 140, 60),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		corde(poutre, Vector3.new(X, PIVOT_Y, 0), cloche, Vector3.new(X, 31.7, 0), Color3.fromRGB(60, 60, 60))
		balancier(
			cloche,
			Vector3.new(X, PIVOT_Y, 0),
			Vector3.new(1, 0, 0),
			80,
			7,
			0.7,
			Vector3.new(X - 1, 28.5, -6),
			Vector3.new(X + 1, 33, 6)
		)
	end

	-- Bôme d'une péniche amarrée le long du ponton (599, 5) : elle balaie le ponton à hauteur de taille.
	do
		local d = dossier(decor, "PenicheAmarree")
		boite(d, "Coque", 591, 604, 1.5, 3.6, -12.5, -5.9, Color3.fromRGB(40, 70, 120), Enum.Material.Wood)
		boite(d, "Rouf", 593, 602, 3.6, 5.2, -11.8, -8.2, Color3.fromRGB(235, 225, 200), Enum.Material.Wood)
		fantome(
			piece(
				d,
				"Mat",
				14,
				0.5,
				0.5,
				CFrame.new(599, 9.6, -6.4) * DEBOUT,
				Color3.fromRGB(200, 190, 170),
				Enum.Material.Wood,
				Enum.PartType.Cylinder
			)
		)
		local bome = piece(
			balanciers,
			"BomeDePeniche",
			0.7,
			2.4,
			9,
			CFrame.new(599, 6.6, -1.9),
			Color3.fromRGB(245, 240, 225),
			Enum.Material.Fabric
		)
		balancier(
			bome,
			Vector3.new(599, 6.6, -6.4),
			Vector3.new(0, 1, 0),
			75,
			6,
			3,
			Vector3.new(597, 5.5, -4),
			Vector3.new(601, 10, 4)
		)
	end

	-- Arroseur à bras du Thabor, sur la haie (798, 18) : un bras bas qui balaie la haie (on le saute ou on attend).
	do
		local d = dossier(decor, "Arroseur")
		boite(d, "Tuyau", 797.75, 798.25, 12, 18.6, -6.75, -6.25, Color3.fromRGB(60, 140, 70), Enum.Material.Metal)
		local bras = piece(
			balanciers,
			"ArroseurABras",
			0.8,
			1,
			9,
			CFrame.new(798, 18.9, -2),
			Color3.fromRGB(230, 230, 235),
			Enum.Material.Metal
		)
		local eau = Instance.new("ParticleEmitter")
		eau.Rate = 40
		eau.Lifetime = NumberRange.new(0.6, 0.9)
		eau.Speed = NumberRange.new(6, 9)
		eau.SpreadAngle = R.Vector2.new(15, 15)
		eau.Acceleration = Vector3.new(0, -30, 0)
		eau.EmissionDirection = Enum.NormalId.Top
		eau.Size = NumberSequence.new(0.2)
		eau.Transparency = NumberSequence.new(0.3)
		eau.Color = ColorSequence.new(Color3.fromRGB(170, 215, 255))
		eau.Parent = bras
		balancier(
			bras,
			Vector3.new(798, 18.9, -6.5),
			Vector3.new(0, 1, 0),
			85,
			6.5,
			1.5,
			Vector3.new(796, 18.3, -4),
			Vector3.new(800, 21, 4)
		)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Panneaux d'anecdotes : un par checkpoint, sur le côté de la dalle (hors des sauts), tourné vers son centre.
	-- Le client écrit le texte (texte enrichi : nom de zone, anecdote, vanne) dans le TextLabel « Texte ».
	local panneaux = dossier(racine, "PanneauxAnecdotes")
	local LARGEUR, HAUTEUR = 8.5, 5.5

	local function panneau(numero: number, cf, accent, piedDepuis)
		local p = piece(panneaux, `PanneauAnecdote{numero}`, LARGEUR, HAUTEUR, 0.3, cf, Color3.fromRGB(25, 27, 35))
		fantome(p)
		p:SetAttribute("Numero", numero)
		p:AddTag("PanneauAnecdote")
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 45
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Texte"
		label.Position = UDim2.fromScale(0.04, 0.06)
		label.Size = UDim2.fromScale(0.92, 0.88)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.TextScaled = true
		label.TextWrapped = true
		label.RichText = true
		label.Font = Enum.Font.Gotham
		label.Text = ""
		label.Parent = gui
		gui.Parent = p
		-- Liseré de la couleur de la zone en haut, et pied jusqu'au sol (ou au toit) quand le panneau est dehors.
		fantome(
			piece(
				panneaux,
				"Lisere",
				LARGEUR + 0.2,
				0.4,
				0.4,
				cf * CFrame.new(0, HAUTEUR / 2 + 0.2, 0),
				accent,
				Enum.Material.Neon
			)
		).CastShadow =
			false
		if piedDepuis then
			local bas = cf.Position.Y - HAUTEUR / 2
			local dos = (cf * CFrame.new(0, 0, 0.45)).Position -- derrière le panneau (+Z local)
			fantome(
				piece(
					panneaux,
					"Pied",
					0.5,
					bas + 1 - piedDepuis,
					0.5,
					CFrame.new(dos.X, (bas + 1 + piedDepuis) / 2, dos.Z),
					Color3.fromRGB(55, 60, 70),
					Enum.Material.Metal
				)
			)
		end
		return p
	end

	-- Panneau à côté d'une dalle de checkpoint (centre cx, dessus, cz ; côté de taille t) : décalé de `dx` en X, sur
	-- le côté `cote` (-1 : Z négatif), et tourné vers le centre de la dalle.
	local function aCote(numero, cx, dessus, cz, t, cote, dx, accent, piedDepuis)
		local x, z = cx + dx, cz + cote * (t / 2 + 3.5)
		local y = dessus + 1.5 + HAUTEUR / 2
		local cf = CFrame.new(x, y, z) * versLaDirection(cx - x, cz - z)
		return panneau(numero, cf, accent, piedDepuis)
	end

	aCote(0, -5, 40, 0, 14, -1, 4.5, accents.coloc, SOL)
	aCote(1, 54, 10, 0, 12, 1, 4.5, accents.fac, SOL)
	aCote(2, 119, 31, 0, 8, -1, 0, accents.fac, 22)
	aCote(3, 202, 34, 0, 12, -1, 3, accents.metro, SOL)
	aCote(4, 243, 14, 0, 12, -1, 4.5, accents.metro, SOL)
	aCote(5, 298, 19, 0, 12, -1, -4.5, accents.cortege, SOL)
	aCote(6, 342, 19, 0, 12, -1, 4.5, accents.cortege, SOL)
	aCote(7, 374, 24, 0, 8, 1, 0, accents.tour, SOL)
	aCote(8, 404.5, 66, 0, 6, 1, -1, accents.tour, 63)
	aCote(9, 488, 28, 0, 12, -1, -4.5, accents.soif, SOL)
	aCote(10, 559, 10, 0, 12, -1, 4.5, accents.soif, SOL)
	aCote(11, 611, 5, 0, 12, -1, 4.5, accents.vilaine, 2)
	aCote(12, 647, 17, 0, 12, -1, 4.5, accents.vilaine, 2)
	aCote(13, 715, 42, 0, 8, -1, 4.5, accents.parlement, 40.6)
	aCote(14, 810, 18, 0, 12, -1, 4.5, accents.thabor, 12)
	-- Salle de partiel (checkpoint 15, dalle 828..840 × 2..14) : panneau au mur ouest, face à la salle.
	panneau(15, CFrame.new(826.3, 46.5, 8) * versLaDirection(1, 0), accents.vinci, nil)

	return racine
end
