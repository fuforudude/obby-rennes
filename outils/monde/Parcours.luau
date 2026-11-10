-- Construction du parcours « Partiel maintenu » : les 15 étapes et le décor de Rennes.
--
-- Renvoie une fonction qui reçoit R, les constructeurs Roblox (Instance, Vector3, Color3, CFrame, Enum, UDim2),
-- et rend le modèle construit. Elle tourne sans changement :
-- - dans Lune, par outils/monde/generer.luau, qui écrit monde/Parcours.rbxm ;
-- - dans Studio, collée dans un execute_luau du MCP, pour un aperçu immédiat.
--
-- Le parcours avance le long de l'axe X (le joueur va vers +X), centré sur Z = 0.
-- Repères de saut (personnage Roblox par défaut) : on monte d'au plus 3 studs, on saute au plus 6 studs de vide.
--
-- Ce que le jeu attend (contrats avec src/serveur) :
-- - tag « Checkpoint » + attribut « Numero » (0 à 15) : les checkpoints ; le 0 est la SpawnLocation du départ ;
-- - tag « Mortel » : tue au toucher ;
-- - tag « Fragile » : s'efface un instant après qu'on a marché dessus ;
-- - tag « Mobile » + attributs « Deplacement » (Vector3) et « Duree » (s) : va-et-vient (pièce ancrée dans le fichier,
--   le serveur la libère et la fait glisser par contraintes physiques pour que le joueur soit porté) ;
-- - tag « Tournant » + attribut « Vitesse » (rad/s) : barre qui tourne autour de son centre et pousse les joueurs ;
-- - tag « TableauClassement » : panneau dont le serveur remplit le TextLabel « Liste » de son SurfaceGui.

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local Vector2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint =
		R.Vector2, R.NumberRange, R.NumberSequence, R.ColorSequence, R.ColorSequenceKeypoint

	local SOL = -10 -- dessus du sol de la ville (décor)

	-- Direction artistique (règles de genre des obbys qui marchent, adaptées à Rennes) :
	-- 1. Le chemin se lit d'un coup d'œil : ce qui se marche est saturé et cerné de la couleur de sa zone ;
	--    le décor de fond est en teintes douces, il ne se confond jamais avec une plateforme.
	-- 2. Une couleur par zone (arche du checkpoint, contours, drapeaux) : on sait où on est, on voit qu'on avance.
	-- 3. Ce qui tue est toujours signalé de la même façon : cerné de rouge vif.
	-- 4. Checkpoints très visibles : dalle lumineuse, grand numéro, arche avec le nom de la zone.
	-- 5. Des repères de Rennes en fond (tours, cathédrale, drapeaux bretons, arbres) pour l'ambiance, sans surcharge.
	local couleurs = {
		bois = Color3.fromRGB(196, 132, 74),
		chaise = Color3.fromRGB(64, 120, 235),
		papier = Color3.fromRGB(255, 252, 235),
		metro = Color3.fromRGB(235, 50, 60),
		quai = Color3.fromRGB(150, 155, 165),
		banderole = Color3.fromRGB(255, 248, 225),
		pancarte = Color3.fromRGB(255, 205, 40),
		camion = Color3.fromRGB(255, 120, 40),
		bac = Color3.fromRGB(40, 170, 90),
		bacJaune = Color3.fromRGB(255, 210, 40),
		carton = Color3.fromRGB(215, 160, 95),
		jus = Color3.fromRGB(150, 210, 30),
		facade = Color3.fromRGB(250, 236, 205),
		colombage = Color3.fromRGB(95, 55, 35),
		toit = Color3.fromRGB(85, 95, 120),
		eau = Color3.fromRGB(40, 150, 230),
		ponton = Color3.fromRGB(170, 115, 70),
		pierre = Color3.fromRGB(235, 222, 190),
		haie = Color3.fromRGB(45, 150, 60),
		pelouse = Color3.fromRGB(120, 230, 70),
		vinci = Color3.fromRGB(25, 85, 185),
		or_ = Color3.fromRGB(255, 200, 40),
		checkpoint = Color3.fromRGB(70, 220, 255),
		danger = Color3.fromRGB(255, 40, 40),
		feuillage = Color3.fromRGB(70, 175, 75),
		tronc = Color3.fromRGB(110, 75, 50),
	}
	-- Couleur de chaque zone, dans l'ordre du parcours.
	local accents = {
		coloc = Color3.fromRGB(255, 140, 60),
		fac = Color3.fromRGB(160, 90, 255),
		metro = Color3.fromRGB(255, 60, 80),
		cortege = Color3.fromRGB(255, 200, 30),
		poubelles = Color3.fromRGB(120, 230, 40),
		soif = Color3.fromRGB(255, 80, 190),
		vilaine = Color3.fromRGB(40, 190, 255),
		parlement = Color3.fromRGB(255, 215, 90),
		thabor = Color3.fromRGB(60, 220, 120),
		vinci = Color3.fromRGB(60, 140, 255),
	}
	local accentDe: { [any]: any } = {} -- dossier de zone → sa couleur (contours posés à la fin)

	local parcours = Instance.new("Model")
	parcours.Name = "Parcours"

	local function dossier(nom: string, accent)
		local d = Instance.new("Folder")
		d.Name = nom
		d.Parent = parcours
		accentDe[d] = accent
		return d
	end

	-- Bloc ancré. `dessus` est la hauteur de sa face supérieure : on raisonne en « où pose-t-on les pieds ».
	local function bloc(
		parent,
		nom: string,
		sx: number,
		sy: number,
		sz: number,
		x: number,
		dessus: number,
		z: number,
		couleur,
		materiau
	)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = CFrame.new(x, dessus - sy / 2, z)
		p.Color = couleur
		p.Material = materiau or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	-- Dalle sur laquelle on marche (1 stud d'épaisseur).
	local function dalle(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, 1, sz, x, dessus, z, couleur, materiau)
	end

	-- Pilier qui descend jusqu'au sol (colonnes, maisons, bacs empilés).
	local function pilier(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, dessus - SOL, sz, x, dessus, z, couleur, materiau)
	end

	-- Décor : ne gêne ni les collisions de jeu ni les calculs de toucher.
	local function decor(p)
		p.CanTouch = false
		p.CanQuery = false
		return p
	end

	local function texte(surface, contenu: string, couleurTexte, couleurFond)
		local gui = Instance.new("SurfaceGui")
		gui.Face = surface
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Name = "Texte"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = couleurFond or Color3.fromRGB(25, 25, 30)
		label.BackgroundTransparency = couleurFond and 0 or 0.1
		label.TextColor3 = couleurTexte or Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = contenu
		label.Parent = gui
		return gui
	end

	-- Panneau sur un poteau, lisible par le joueur qui arrive (il regarde vers +X : on écrit sur la face -X).
	local function panneau(parent, contenu: string, x, dessus, z, largeur)
		largeur = largeur or 8
		decor(bloc(parent, "Poteau", 0.6, 7, 0.6, x, dessus + 4, z, Color3.fromRGB(60, 60, 60), Enum.Material.Metal))
		local plaque = decor(bloc(parent, "Panneau", 0.4, 3, largeur, x, dessus + 6, z, Color3.fromRGB(25, 25, 30)))
		texte(Enum.NormalId.Left, contenu).Parent = plaque
		return plaque
	end

	local function etiqueter(p, tag: string)
		p:AddTag(tag)
		return p
	end

	local function mortel(p)
		return etiqueter(p, "Mortel")
	end

	local function fragile(p)
		p.Color = couleurs.papier
		return etiqueter(p, "Fragile")
	end

	local function mobile(p, deplacement, duree: number)
		p:SetAttribute("Deplacement", deplacement)
		p:SetAttribute("Duree", duree)
		return etiqueter(p, "Mobile")
	end

	local function tournant(p, vitesse: number)
		p:SetAttribute("Vitesse", vitesse)
		return etiqueter(p, "Tournant")
	end

	local function checkpoint(parent, numero: number, x, dessus, z, nomZone: string, taille)
		taille = taille or 12
		local p
		if numero == 0 then
			p = Instance.new("SpawnLocation")
			p.Neutral = true
			p.Duration = 0
			p.Anchored = true
			p.Size = Vector3.new(taille, 1, taille)
			p.CFrame = CFrame.new(x, dessus - 0.5, z)
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.Parent = parent
		else
			p = dalle(parent, "", taille, taille, x, dessus, z, couleurs.checkpoint)
		end
		p.Name = `Checkpoint{numero}`
		p.Color = numero == 15 and couleurs.or_ or couleurs.checkpoint
		p:SetAttribute("Numero", numero)
		etiqueter(p, "Checkpoint")
		-- Le numéro, posé à plat sur la dalle.
		local marque =
			decor(bloc(parent, `Marque{numero}`, 4, 0.05, 4, x, dessus + 0.05, z, p.Color, Enum.Material.Neon))
		marque.CanCollide = false
		texte(Enum.NormalId.Top, tostring(numero), Color3.fromRGB(20, 30, 40), Color3.fromRGB(255, 255, 255)).Parent =
			marque
		-- Arche aux couleurs de la zone, au-dessus de la dalle : le nom se lit en arrivant et en repartant.
		local accent = accentDe[parent] or couleurs.checkpoint
		local demi = taille / 2 + 0.6
		for _, cote in { -1, 1 } do
			decor(
				bloc(parent, "PilierArche", 1.2, 11, 1.2, x, dessus + 11, z + cote * demi, accent, Enum.Material.Neon)
			)
		end
		local fronton =
			decor(bloc(parent, "Arche", 1.2, 3, taille + 2.4, x, dessus + 14, z, Color3.fromRGB(25, 25, 35)))
		local nom = if numero == 0 then nomZone else `{numero} · {nomZone}`
		texte(Enum.NormalId.Left, nom, accent).Parent = fronton
		texte(Enum.NormalId.Right, nom, accent).Parent = fronton
		decor(bloc(parent, "LiseréArche", 1.3, 0.4, taille + 2.4, x, dessus + 11.2, z, accent, Enum.Material.Neon))
		return p
	end

	-- Contour d'une pièce (SelectionBox : aucune pièce en plus, juste un trait autour).
	local function contour(p, couleur, epaisseur)
		local boite = Instance.new("SelectionBox")
		boite.Name = "Contour"
		boite.Adornee = p
		boite.Color3 = couleur
		boite.LineThickness = epaisseur or 0.06
		boite.SurfaceTransparency = 1
		boite.Parent = p
		return boite
	end

	local function arbre(parent, x, z, taille)
		taille = taille or 1
		decor(
			bloc(
				parent,
				"Tronc",
				1.2 * taille,
				6 * taille,
				1.2 * taille,
				x,
				SOL + 6 * taille,
				z,
				couleurs.tronc,
				Enum.Material.Wood
			)
		)
		local feuilles = decor(Instance.new("Part"))
		feuilles.Name = "Feuillage"
		feuilles.Shape = Enum.PartType.Ball
		feuilles.Anchored = true
		feuilles.Size = Vector3.new(7, 7, 7) * taille
		feuilles.CFrame = CFrame.new(x, SOL + 9 * taille, z)
		feuilles.Color = couleurs.feuillage
		feuilles.Material = Enum.Material.Grass
		feuilles.CastShadow = true
		feuilles.Parent = parent
	end

	local function lampadaire(parent, x, z)
		decor(bloc(parent, "Lampadaire", 0.5, 12, 0.5, x, SOL + 12, z, Color3.fromRGB(45, 50, 60), Enum.Material.Metal))
		local tete = decor(
			bloc(parent, "Lampe", 1.6, 0.8, 1.6, x, SOL + 12.6, z, Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
		)
		local lumiere = Instance.new("PointLight")
		lumiere.Range = 14
		lumiere.Brightness = 1.2
		lumiere.Color = Color3.fromRGB(255, 220, 160)
		lumiere.Parent = tete
	end

	-- Gwenn-ha-du simplifié : bandes noires et blanches et un carré d'hermines (blanc).
	local function drapeauBreton(parent, x, dessus, z)
		decor(bloc(parent, "Mat", 0.4, 14, 0.4, x, dessus + 14, z, Color3.fromRGB(220, 220, 220), Enum.Material.Metal))
		for i = 0, 8 do
			local couleur = if i % 2 == 0 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(250, 250, 250)
			decor(bloc(parent, "Bande", 0.15, 0.5, 7, x, dessus + 14 - i * 0.5, z + 3.7, couleur, Enum.Material.Fabric))
		end
		decor(
			bloc(
				parent,
				"Hermines",
				0.2,
				2.5,
				3,
				x,
				dessus + 14,
				z + 1.7,
				Color3.fromRGB(250, 250, 250),
				Enum.Material.Fabric
			)
		)
	end

	local function tableauClassement(parent, x, dessus, z, face)
		local p = decor(bloc(parent, "TableauClassement", 14, 10, 1, x, dessus + 11, z, Color3.fromRGB(20, 20, 30)))
		etiqueter(p, "TableauClassement")
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = p
		local titre = Instance.new("TextLabel")
		titre.Name = "Titre"
		titre.Size = UDim2.fromScale(1, 0.18)
		titre.BackgroundColor3 = couleurs.vinci
		titre.TextColor3 = Color3.fromRGB(255, 255, 255)
		titre.TextScaled = true
		titre.Font = Enum.Font.GothamBlack
		titre.Text = "Meilleurs temps"
		titre.Parent = gui
		local liste = Instance.new("TextLabel")
		liste.Name = "Liste"
		liste.Position = UDim2.fromScale(0.04, 0.2)
		liste.Size = UDim2.fromScale(0.92, 0.78)
		liste.BackgroundTransparency = 1
		liste.TextColor3 = Color3.fromRGB(240, 240, 240)
		liste.TextScaled = true
		liste.TextXAlignment = Enum.TextXAlignment.Left
		liste.TextYAlignment = Enum.TextYAlignment.Top
		liste.Font = Enum.Font.Code
		liste.Text = "Chargement…"
		liste.Parent = gui
		decor(bloc(parent, "PiedTableau", 1, dessus + 6 - SOL, 1, x - 5, dessus + 6, z, Color3.fromRGB(60, 60, 60)))
		decor(bloc(parent, "PiedTableau", 1, dessus + 6 - SOL, 1, x + 5, dessus + 6, z, Color3.fromRGB(60, 60, 60)))
		return p
	end

	-- Maison à colombages : façade claire, poutres sombres sur la face avant (-Z), toit plat où l'on marche.
	local function maison(parent, nom, x, z, largeur, dessus, estDecor)
		local corps = pilier(parent, nom, largeur, largeur, x, dessus, z, couleurs.facade, Enum.Material.Plaster)
		corps.CanQuery = false
		local hauteur = dessus - SOL
		for i = -1, 1 do
			decor(
				bloc(
					parent,
					"Poutre",
					0.5,
					hauteur,
					0.3,
					x + i * largeur / 3,
					dessus,
					z - largeur / 2 - 0.1,
					couleurs.colombage,
					Enum.Material.Wood
				)
			)
		end
		for h = SOL + 4, dessus - 1, 4 do
			decor(
				bloc(
					parent,
					"Poutre",
					largeur,
					0.5,
					0.3,
					x,
					h,
					z - largeur / 2 - 0.1,
					couleurs.colombage,
					Enum.Material.Wood
				)
			)
		end
		local bordure =
			dalle(parent, "Toit", largeur + 0.4, largeur + 0.4, x, dessus, z, couleurs.toit, Enum.Material.Slate)
		bordure.CanTouch = false
		corps.CanTouch = false
		if estDecor then
			decor(bordure)
		end
		return bordure
	end

	-- Immeuble de décor, loin du chemin.
	local function immeuble(parent, x, z, sx, sz, hauteur, couleur, sansFenetres)
		local corps =
			decor(bloc(parent, "Immeuble", sx, hauteur, sz, x, SOL + hauteur, z, couleur, Enum.Material.Concrete))
		if not sansFenetres then
			local face = if z > 0 then z - sz / 2 - 0.1 else z + sz / 2 + 0.1
			for h = SOL + 6, SOL + hauteur - 3, 6 do
				local f = decor(
					bloc(
						parent,
						"Fenetres",
						sx - 3,
						2,
						0.2,
						x,
						h,
						face,
						Color3.fromRGB(150, 200, 235),
						Enum.Material.Glass
					)
				)
				f.CastShadow = false
			end
			decor(
				bloc(
					parent,
					"Corniche",
					sx + 1,
					1,
					sz + 1,
					x,
					SOL + hauteur + 1,
					z,
					Color3.fromRGB(90, 95, 110),
					Enum.Material.Slate
				)
			)
		end
		return corps
	end

	---------------------------------------------------------------------------------------------------------------
	-- La ville : sol, zone mortelle sous le parcours, immeubles.
	local ville = dossier("Ville")
	decor(bloc(ville, "Sol", 900, 2, 300, 380, SOL, 0, Color3.fromRGB(110, 175, 85), Enum.Material.Grass))
	decor(bloc(ville, "Rue", 900, 0.2, 40, 380, SOL + 0.1, 0, Color3.fromRGB(60, 62, 70), Enum.Material.Asphalt))
	for _, cote in { -1, 1 } do
		decor(
			bloc(
				ville,
				"Trottoir",
				900,
				0.6,
				10,
				380,
				SOL + 0.6,
				cote * 25,
				Color3.fromRGB(200, 195, 185),
				Enum.Material.Concrete
			)
		)
	end
	for x = -40, 820, 16 do
		local trait = decor(
			bloc(
				ville,
				"Marquage",
				7,
				0.05,
				0.6,
				x,
				SOL + 0.25,
				0,
				Color3.fromRGB(250, 250, 250),
				Enum.Material.SmoothPlastic
			)
		)
		trait.CastShadow = false
	end
	for i = 0, 26 do
		local x = -30 + i * 32
		lampadaire(ville, x, 21)
		lampadaire(ville, x + 16, -21)
		arbre(ville, x + 8, 34, 0.9 + (i % 3) * 0.15)
		arbre(ville, x + 24, -34, 1 + (i % 2) * 0.2)
	end
	local vide = mortel(bloc(ville, "Vide", 900, 2, 300, 380, -4, 0, Color3.fromRGB(0, 0, 0)))
	vide.Transparency = 1
	vide.CanCollide = false
	vide.CanQuery = false
	-- Teintes douces : le fond ne doit jamais ressembler à une plateforme.
	local teintes = {
		Color3.fromRGB(240, 215, 190),
		Color3.fromRGB(200, 215, 230),
		Color3.fromRGB(235, 200, 200),
		Color3.fromRGB(215, 230, 205),
	}
	for i = 0, 15 do
		local x = -20 + i * 52
		immeuble(ville, x, 70 + (i % 3) * 8, 30, 24, 30 + (i % 4) * 12, teintes[i % 4 + 1])
		immeuble(ville, x + 20, -75 - (i % 2) * 10, 26, 22, 26 + ((i + 1) % 4) * 14, teintes[(i + 2) % 4 + 1])
	end

	-- Repères de Rennes, en fond. Les tours Les Horizons : deux tours rondes, l'une plus haute que l'autre.
	for _, tour in { { x = 120, h = 110 }, { x = 150, h = 85 } } do
		local t = decor(Instance.new("Part"))
		t.Name = "TourLesHorizons"
		t.Shape = Enum.PartType.Cylinder
		t.Anchored = true
		t.Size = Vector3.new(tour.h, 22, 22)
		t.CFrame = CFrame.new(tour.x, SOL + tour.h / 2, -125) * CFrame.Angles(0, 0, math.rad(90))
		t.Color = Color3.fromRGB(235, 235, 240)
		t.Material = Enum.Material.Concrete
		t.Parent = ville
		for h = SOL + 8, SOL + tour.h - 4, 7 do
			local bague = decor(Instance.new("Part"))
			bague.Name = "Balcons"
			bague.Shape = Enum.PartType.Cylinder
			bague.Anchored = true
			bague.Size = Vector3.new(1, 23, 23)
			bague.CFrame = CFrame.new(tour.x, h, -125) * CFrame.Angles(0, 0, math.rad(90))
			bague.Color = Color3.fromRGB(120, 130, 150)
			bague.Material = Enum.Material.Glass
			bague.CastShadow = false
			bague.Parent = ville
		end
	end
	-- La cathédrale Saint-Pierre : façade claire et deux tours carrées, près de la rue de la Soif.
	immeuble(ville, 470, -110, 40, 24, 45, Color3.fromRGB(225, 210, 180), true)
	for _, dx in { -14, 14 } do
		immeuble(ville, 470 + dx, -105, 12, 12, 70, Color3.fromRGB(215, 200, 170), true)
		decor(
			bloc(
				ville,
				"Lanterne",
				8,
				6,
				8,
				470 + dx,
				SOL + 76,
				-105,
				Color3.fromRGB(110, 120, 140),
				Enum.Material.Slate
			)
		)
	end
	local rosace = decor(
		bloc(ville, "Rosace", 0.4, 10, 10, 470, SOL + 32, -97.6, Color3.fromRGB(80, 120, 200), Enum.Material.Glass)
	)
	rosace.Orientation = Vector3.new(0, 90, 0)
	drapeauBreton(ville, -26, 25, 14)

	---------------------------------------------------------------------------------------------------------------
	-- 0 · La coloc à Villejean
	local coloc = dossier("0_Coloc", accents.coloc)
	checkpoint(coloc, 0, 0, 1, 0, "La coloc à Villejean", 14)
	pilier(coloc, "Plancher", 30, 30, -8, 0.9, 0, couleurs.bois, Enum.Material.WoodPlanks).CanTouch = false
	decor(bloc(coloc, "Matelas", 6, 1.5, 9, -16, 2.4, 8, Color3.fromRGB(200, 70, 80), Enum.Material.Fabric))
	decor(bloc(coloc, "Bureau", 6, 3, 3, -16, 4, -9, couleurs.bois, Enum.Material.Wood))
	decor(bloc(coloc, "PizzaDHier", 2, 0.3, 2, -15, 4.3, -9, Color3.fromRGB(230, 170, 80), Enum.Material.SmoothPlastic))
	local mur = decor(bloc(coloc, "Mur", 1, 12, 30, -23, 13, 0, Color3.fromRGB(230, 225, 215), Enum.Material.Plaster))
	texte(
		Enum.NormalId.Right,
		"PARTIEL À 8H\nSUP DE VINCI\n(Rennes 2 est bloquée, pas Sup de Vinci)",
		Color3.fromRGB(200, 30, 30),
		Color3.fromRGB(255, 250, 230)
	).Parent =
		mur
	local titre =
		decor(bloc(coloc, "Titre", 1, 7, 30, -23, 21, 0, Color3.fromRGB(25, 25, 35), Enum.Material.SmoothPlastic))
	texte(Enum.NormalId.Right, "OBBY RENNES · PARTIEL MAINTENU", accents.coloc).Parent = titre
	tableauClassement(coloc, -4, 1, -14, Enum.NormalId.Back)

	---------------------------------------------------------------------------------------------------------------
	-- 1-2 · Fac bloquée
	local fac = dossier("1_FacBloquee", accents.fac)
	dalle(fac, "Table", 6, 4, 14, 2, 3, couleurs.bois, Enum.Material.Wood)
	dalle(fac, "Table", 6, 4, 23, 3, -3, couleurs.bois, Enum.Material.Wood)
	dalle(fac, "Table", 6, 4, 32, 4, 3, couleurs.bois, Enum.Material.Wood)
	checkpoint(fac, 1, 44, 4, 0, "Fac bloquée")
	dalle(fac, "Chaises", 4, 4, 56, 7, 0, couleurs.chaise)
	fragile(dalle(fac, "PileDeCopies", 4, 4, 63, 10, 2, couleurs.papier))
	dalle(fac, "Chaises", 4, 4, 70, 13, -1, couleurs.chaise)
	checkpoint(fac, 2, 82, 13, 0, "Fac bloquée (le blocus)")
	-- Décor : la barricade de chaises et la banderole de l'AG.
	for i = 0, 5 do
		decor(bloc(fac, "ChaiseEmpilee", 3, 3, 3, 50 + i * 4, 1 + (i % 3) * 3, 12, couleurs.chaise))
	end
	decor(bloc(fac, "Mat", 0.5, 20, 0.5, 30, 18, -12, Color3.fromRGB(80, 80, 80)))
	decor(bloc(fac, "Mat", 0.5, 20, 0.5, 60, 18, -12, Color3.fromRGB(80, 80, 80)))
	local banderoleAG =
		decor(bloc(fac, "BanderoleAG", 30, 4, 0.3, 45, 17, -12, couleurs.banderole, Enum.Material.Fabric))
	texte(
		Enum.NormalId.Back,
		"FAC BLOQUÉE · AG À 10H · PARTIELS REPORTÉS (pas les tiens)",
		Color3.fromRGB(180, 20, 20),
		couleurs.banderole
	).Parent =
		banderoleAG

	---------------------------------------------------------------------------------------------------------------
	-- 3-4 · Métro en grève
	local metro = dossier("2_MetroEnGreve", accents.metro)
	local function rame(nom, longueur, x, avecVitres)
		local r = bloc(metro, nom, longueur, 7, 6, x, 13, 0, couleurs.metro, Enum.Material.Metal)
		if avecVitres then
			-- Les vitres sont une pièce à part : seulement sur les rames immobiles, sinon elles resteraient sur place.
			decor(
				bloc(metro, "Vitres", longueur - 2, 2, 6.1, x, 11, 0, Color3.fromRGB(30, 40, 60), Enum.Material.Glass)
			)
		end
		return r
	end
	rame("Rame", 18, 100, true)
	rame("Rame", 18, 124, true)
	mobile(rame("RameQuiRepartQuandMeme", 10, 144, false), Vector3.new(0, 0, 10), 3)
	checkpoint(metro, 3, 161, 13, 0, "Métro en grève")
	dalle(metro, "EscalatorALArret", 4, 6, 172, 11, 0, couleurs.quai, Enum.Material.DiamondPlate)
	dalle(metro, "EscalatorALArret", 4, 6, 179, 9, 0, couleurs.quai, Enum.Material.DiamondPlate)
	dalle(metro, "EscalatorALArret", 4, 6, 186, 7, 0, couleurs.quai, Enum.Material.DiamondPlate)
	checkpoint(metro, 4, 200, 6, 0, "Station République")
	-- Le quai est loin du chemin (Z = -22) : il ne doit pas servir de raccourci ni rattraper les chutes.
	decor(bloc(metro, "Quai", 100, 1, 8, 130, 6, -22, couleurs.quai, Enum.Material.Concrete))
	panneau(metro, "LIGNE A · TRAFIC INTERROMPU\nprochaine rame : un jour", 92, 6, -22, 12)

	---------------------------------------------------------------------------------------------------------------
	-- 5-6 · Cortège place de la République
	local cortege = dossier("3_Cortege", accents.cortege)
	local function banderole(x, dessus, slogan, deplacement, duree)
		local b = dalle(cortege, "Banderole", 4, 12, x, dessus, 0, couleurs.banderole, Enum.Material.Fabric)
		texte(Enum.NormalId.Top, slogan, Color3.fromRGB(190, 30, 30), couleurs.banderole).Parent = b
		return mobile(b, deplacement, duree)
	end
	dalle(cortege, "Pancarte", 2, 2, 211, 7, 0, couleurs.pancarte)
	banderole(220, 7, "DES PRISES DANS LES AMPHIS", Vector3.new(0, 0, 8), 4)
	dalle(cortege, "Pancarte", 2, 2, 228, 8, 0, couleurs.pancarte)
	banderole(236, 8, "NON AUX PARTIELS À 8H", Vector3.new(0, 0, -8), 3)
	dalle(cortege, "Pancarte", 2, 2, 244, 9, 0, couleurs.pancarte)
	checkpoint(cortege, 5, 256, 9, 0, "Place de la République")
	local sono = mobile(
		dalle(cortege, "CamionSono", 8, 8, 272, 9, 0, couleurs.camion, Enum.Material.Metal),
		Vector3.new(12, 0, 0),
		4
	)
	sono.Size = Vector3.new(8, 2, 8)
	sono.CFrame = CFrame.new(272, 8, 0)
	checkpoint(cortege, 6, 300, 9, 0, "Le cortège")
	-- Décor : le palais du Commerce et des pancartes plantées.
	local palais = immeuble(cortege, 270, 45, 80, 20, 28, couleurs.pierre)
	texte(Enum.NormalId.Front, "PALAIS DU COMMERCE", Color3.fromRGB(60, 50, 40), couleurs.pierre).Parent = palais
	local slogans = { "RENDEZ-NOUS LA PAUSE CAFÉ", "WIFI GRATUIT PARTOUT", "UN MICRO-ONDES PAR ÉTUDIANT" }
	for i, slogan in slogans do
		local x = 205 + i * 25
		decor(bloc(cortege, "Manche", 0.4, 18, 0.4, x, 8, -16, couleurs.bois, Enum.Material.Wood))
		local plaque = decor(bloc(cortege, "PancarteDecor", 0.3, 4, 8, x, 12, -16, couleurs.pancarte))
		texte(Enum.NormalId.Left, slogan, Color3.fromRGB(30, 30, 30), couleurs.pancarte).Parent = plaque
	end

	---------------------------------------------------------------------------------------------------------------
	-- 7-8 · Barricades de poubelles
	local poubelles = dossier("4_Barricades", accents.poubelles)
	local jus = mortel(dalle(poubelles, "JusDePoubelle", 34, 20, 330, 6, 0, couleurs.jus, Enum.Material.Mud))
	jus.CanQuery = false
	pilier(poubelles, "Bac", 4, 4, 311, 10, 0, couleurs.bac)
	fragile(dalle(poubelles, "Carton", 4, 4, 318, 10, 2, couleurs.papier))
	pilier(poubelles, "Bac", 4, 4, 325, 12, -2, couleurs.bacJaune)
	fragile(dalle(poubelles, "Carton", 4, 4, 332, 12, 1, couleurs.papier))
	pilier(poubelles, "Bac", 4, 4, 339, 14, 0, couleurs.bac)
	checkpoint(poubelles, 7, 352, 14, 0, "Barricades de poubelles")
	decor(bloc(poubelles, "GrandeBarricade", 6, 23 - SOL, 24, 382, 22, 0, couleurs.bac))
	dalle(poubelles, "SacPoubelle", 4, 4, 364, 17, -4, Color3.fromRGB(30, 30, 30))
	dalle(poubelles, "SacPoubelle", 4, 4, 369, 20, 3, Color3.fromRGB(30, 30, 30))
	dalle(poubelles, "SacPoubelle", 4, 4, 374, 23, -2, Color3.fromRGB(30, 30, 30))
	dalle(poubelles, "HautDeLaBarricade", 8, 8, 382, 23, 0, couleurs.bacJaune)
	checkpoint(poubelles, 8, 398, 20, 0, "Le sommet des poubelles")
	panneau(poubelles, "COLLECTE DES DÉCHETS : EN GRÈVE AUSSI", 346, 14, 10, 12)

	---------------------------------------------------------------------------------------------------------------
	-- 9-10 · Rue de la Soif (rue Saint-Michel)
	local soif = dossier("5_RueDeLaSoif", accents.soif)
	maison(soif, "Maison", 412, 0, 8, 20)
	maison(soif, "Maison", 424, 0, 8, 22)
	pilier(soif, "Cheminee", 2, 2, 433, 24, 0, Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	maison(soif, "Maison", 442, 0, 8, 22)
	checkpoint(soif, 9, 456, 22, 0, "Rue de la Soif")
	dalle(soif, "Passerelle", 30, 10, 480, 22, 0, couleurs.toit, Enum.Material.Slate)
	local enseigne = tournant(
		bloc(soif, "EnseigneDeBar", 1.2, 2, 22, 480, 25, 0, Color3.fromRGB(220, 60, 140), Enum.Material.Neon),
		1.6
	)
	enseigne.CanQuery = false
	checkpoint(soif, 10, 507, 22, 0, "Le dernier bar avant le partiel")
	for i = 0, 5 do
		maison(soif, "MaisonDecor", 412 + i * 18, 24, 12, 14 + (i % 3) * 4, true)
	end

	---------------------------------------------------------------------------------------------------------------
	-- 11-12 · La Vilaine
	local vilaine = dossier("6_LaVilaine", accents.vilaine)
	local eau = mortel(dalle(vilaine, "LaVilaine", 106, 70, 569, 14, 0, couleurs.eau, Enum.Material.Glass))
	eau.Transparency = 0.25
	eau.CanQuery = false
	dalle(vilaine, "Quai", 4, 6, 519, 19, 0, couleurs.pierre, Enum.Material.Cobblestone)
	dalle(vilaine, "Quai", 4, 6, 526, 16, 0, couleurs.pierre, Enum.Material.Cobblestone)
	dalle(vilaine, "Ponton", 4, 8, 534, 16, 0, couleurs.ponton, Enum.Material.WoodPlanks)
	mobile(
		dalle(vilaine, "PenicheALaDerive", 10, 6, 545, 16, 0, Color3.fromRGB(30, 80, 50), Enum.Material.Wood),
		Vector3.new(0, 0, 10),
		5
	)
	dalle(vilaine, "Ponton", 4, 8, 556, 16, 0, couleurs.ponton, Enum.Material.WoodPlanks)
	checkpoint(vilaine, 11, 568, 16, 0, "La Vilaine")
	dalle(vilaine, "Bouee", 3, 3, 580, 16, 0, Color3.fromRGB(240, 90, 40))
	fragile(dalle(vilaine, "BoueeCrevee", 3, 3, 587, 17, 2, couleurs.papier))
	dalle(vilaine, "Bouee", 3, 3, 594, 18, -1, Color3.fromRGB(240, 90, 40))
	fragile(dalle(vilaine, "BoueeCrevee", 3, 3, 601, 18, 1, couleurs.papier))
	checkpoint(vilaine, 12, 614, 18, 0, "Les quais")

	---------------------------------------------------------------------------------------------------------------
	-- 13 · Parlement de Bretagne
	local parlement = dossier("7_Parlement", accents.parlement)
	pilier(parlement, "Colonne", 4, 4, 626, 20, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 3, 3, 633, 22, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 3, 3, 640, 24, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 2, 2, 647, 26, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 2, 2, 654, 27, 0, couleurs.pierre, Enum.Material.Marble)
	checkpoint(parlement, 13, 666, 28, 0, "Parlement de Bretagne")
	local facadeParlement = immeuble(parlement, 650, 40, 70, 16, 40, couleurs.pierre)
	texte(Enum.NormalId.Front, "PARLEMENT DE BRETAGNE", Color3.fromRGB(150, 120, 40), couleurs.pierre).Parent =
		facadeParlement
	decor(bloc(parlement, "Toit", 70, 8, 16, 650, 38, 40, Color3.fromRGB(50, 60, 80), Enum.Material.Slate))
	drapeauBreton(parlement, 625, 38, 36)
	drapeauBreton(parlement, 675, 38, 36)

	---------------------------------------------------------------------------------------------------------------
	-- 14 · Le Thabor
	local thabor = dossier("8_Thabor", accents.thabor)
	local pelouse = mortel(dalle(thabor, "PelouseInterdite", 60, 40, 705, 20, 0, couleurs.pelouse, Enum.Material.Grass))
	pelouse.CanQuery = false
	bloc(thabor, "Haie", 4, 3, 8, 680, 25, 0, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 688, 23, 4, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 696, 23, -4, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 704, 23, 4, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 712, 24, 0, couleurs.haie, Enum.Material.Grass)
	checkpoint(thabor, 14, 726, 24, 0, "Le Thabor")
	panneau(thabor, "PELOUSE INTERDITE\n(vraiment)", 678, 20, 12, 8)
	for i = 0, 6 do
		arbre(thabor, 678 + i * 9, 26 + (i % 2) * 4, 1.4)
		arbre(thabor, 682 + i * 9, -26 - (i % 2) * 4, 1.3)
	end

	---------------------------------------------------------------------------------------------------------------
	-- 15 · Sup de Vinci, salle de partiel
	local vinci = dossier("9_SupDeVinci", accents.vinci)
	dalle(vinci, "Marche", 4, 10, 737, 26, 0, couleurs.pierre, Enum.Material.Concrete)
	dalle(vinci, "Marche", 4, 10, 743, 28, 0, couleurs.pierre, Enum.Material.Concrete)
	dalle(vinci, "Marche", 4, 10, 749, 30, 0, couleurs.pierre, Enum.Material.Concrete)
	checkpoint(vinci, 15, 762, 30, 0, "Sup de Vinci · salle de partiel", 16)
	-- Le bâtiment ferme le parcours : un mur de verre derrière l'arrivée, le nom de l'école sur sa façade.
	decor(pilier(vinci, "Batiment", 30, 40, 785, 52, 0, couleurs.vinci, Enum.Material.Glass))
	local fronton = decor(bloc(vinci, "Fronton", 0.4, 8, 26, 769.8, 48, 0, couleurs.vinci, Enum.Material.SmoothPlastic))
	texte(Enum.NormalId.Left, "SUP DE VINCI", Color3.fromRGB(255, 255, 255), couleurs.vinci).Parent = fronton
	for i = 0, 1 do
		for _, z in { -5, 5 } do
			decor(bloc(vinci, "TableDExamen", 3, 3, 2, 760 + i * 6, 33, z, couleurs.bois, Enum.Material.Wood))
		end
	end
	tableauClassement(vinci, 762, 30, -14, Enum.NormalId.Back)
	drapeauBreton(vinci, 772, 52, -16)
	local canon = decor(bloc(vinci, "Confettis", 14, 0.2, 14, 762, 45, 0, couleurs.or_))
	canon.Transparency = 1
	canon.CanCollide = false
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
		ColorSequenceKeypoint.new(0, accents.vinci),
		ColorSequenceKeypoint.new(0.5, couleurs.or_),
		ColorSequenceKeypoint.new(1, accents.soif),
	})
	confettis.Parent = canon

	---------------------------------------------------------------------------------------------------------------
	-- Lisibilité du chemin : contour de la couleur de la zone sur chaque pièce où l'on pose les pieds,
	-- contour rouge épais sur tout ce qui tue. Le décor (CanQuery = false) n'en a pas.
	for zone, accent in accentDe do
		for _, p in zone:GetDescendants() do
			if not p:IsA("BasePart") or p.Transparency >= 1 then
				continue
			end
			if p:HasTag("Mortel") then
				contour(p, couleurs.danger, 0.2)
			elseif not p:HasTag("Checkpoint") and p.CanCollide and p.CanQuery then
				contour(p, accent)
			end
		end
	end

	return parcours
end
