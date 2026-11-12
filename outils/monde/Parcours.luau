-- Construction du parcours « Partiel maintenu » : les 15 étapes et le décor de Rennes.
--
-- Renvoie une fonction qui reçoit R, les constructeurs Roblox (Instance, Vector3, Vector2, Color3, CFrame, Enum,
-- UDim2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint), et rend le modèle construit :
-- - dans Lune, par outils/monde/generer.luau, qui écrit monde/Parcours.rbxm ;
-- - dans Studio, collée dans un execute_luau du MCP, pour un aperçu immédiat.
--
-- Le tracé : un seul chemin, mais en trois dimensions. On part du balcon d'un immeuble, on descend par les balcons,
-- on entre dans la fac par une fenêtre et on traverse l'amphi, on saute de rame en rame sur le viaduc, on traverse
-- le cortège, on grimpe la barricade de poubelles puis on monte en spirale autour d'une tour, on y entre à un étage,
-- on ressort de l'autre côté et on redescend, on passe de toit en toit rue de la Soif puis dans la rue, au ras de la
-- Vilaine, on escalade le Parlement et on court sur son toit, on saute de cime en cime au Thabor, et on monte
-- l'atrium de Sup de Vinci jusqu'à la salle de partiel. On avance globalement vers +X.
-- Repères de saut (personnage par défaut) : on monte d'au plus 4 studs, on saute au plus 6 studs de vide.
--
-- Ce que le jeu attend (contrats avec src/serveur) :
-- - tag « Checkpoint » + attribut « Numero » (0 à 15) : les checkpoints ; le 0 est la SpawnLocation du départ ;
-- - tag « Mortel » : tue au toucher ;
-- - tag « Fragile » : s'efface un instant après qu'on a marché dessus ;
-- - tag « Mobile » + attributs « Deplacement » (Vector3) et « Duree » (s) : va-et-vient ;
-- - tag « Tournant » + attribut « Vitesse » (rad/s) : barre qui tourne autour de son centre et pousse les joueurs ;
-- - tags « TableauClassement » / « TableauAura » : panneaux dont le serveur remplit le TextLabel « Liste ».

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local Vector2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint =
		R.Vector2, R.NumberRange, R.NumberSequence, R.ColorSequence, R.ColorSequenceKeypoint

	local SOL = -10 -- dessus du sol de la ville (décor) ; la zone mortelle est juste au-dessus, en -4

	-- Direction artistique (règles de genre des obbys qui marchent, adaptées à Rennes) :
	-- 1. Le chemin se lit d'un coup d'œil : ce qui se marche est saturé et cerné de la couleur de sa zone ;
	--    le décor est en teintes douces et ne se confond jamais avec une plateforme.
	-- 2. Une couleur par zone (arches, contours) : on sait où on est, on voit qu'on avance.
	-- 3. Ce qui tue est toujours cerné de rouge vif.
	-- 4. Checkpoints très visibles : dalle lumineuse, grand numéro, arche (ou nom flottant à l'intérieur).
	-- 5. Des repères de Rennes en fond, et des bâtiments qu'on traverse pour de vrai.
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
		beton = Color3.fromRGB(205, 205, 210),
	}
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

	---------------------------------------------------------------------------------------------------------------
	-- Outils de construction.

	-- Bloc ancré. `dessus` est la hauteur de sa face supérieure : on raisonne en « où pose-t-on les pieds ».
	local function bloc(parent, nom: string, sx, sy, sz, x, dessus, z, couleur, materiau)
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

	-- Bloc donné par ses bornes (x1..x2, y1..y2, z1..z2) : pratique pour les murs et les planchers.
	local function boite(parent, nom: string, x1, x2, y1, y2, z1, z2, couleur, materiau)
		return bloc(parent, nom, x2 - x1, y2 - y1, z2 - z1, (x1 + x2) / 2, y2, (z1 + z2) / 2, couleur, materiau)
	end

	-- Dalle sur laquelle on marche (1 stud d'épaisseur).
	local function dalle(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, 1, sz, x, dessus, z, couleur, materiau)
	end

	-- Pilier qui descend jusqu'au sol (colonnes, bacs empilés).
	local function pilier(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, dessus - SOL, sz, x, dessus, z, couleur, materiau)
	end

	-- Décor : ne déclenche rien et ne prend pas de contour (il reste solide, sauf si on le dit).
	local function decor(p)
		p.CanTouch = false
		p.CanQuery = false
		return p
	end

	-- Décor de fond qu'on ne doit jamais pouvoir toucher : on le traverse et on tombe dans la zone mortelle.
	local function fantome(p)
		decor(p)
		p.CanCollide = false
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

	-- Nom flottant au-dessus d'un objet, visible de loin.
	local function etiquette(part, contenu: string, couleur, hauteur)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(320, 60)
		gui.StudsOffset = Vector3.new(0, hauteur or 4, 0)
		gui.MaxDistance = 250
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = couleur or Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Text = contenu
		label.Parent = gui
		gui.Parent = part
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
		p.CanQuery = false
		return etiqueter(p, "Tournant")
	end

	-- Checkpoint : dalle lumineuse et grand numéro ; arche aux couleurs de la zone dehors, nom flottant dedans.
	local function checkpoint(parent, numero: number, x, dessus, z, nomZone: string, taille, interieur)
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
		local marque =
			decor(bloc(parent, `Marque{numero}`, 4, 0.05, 4, x, dessus + 0.05, z, p.Color, Enum.Material.Neon))
		marque.CanCollide = false
		texte(Enum.NormalId.Top, tostring(numero), Color3.fromRGB(20, 30, 40), Color3.fromRGB(255, 255, 255)).Parent =
			marque
		local accent = accentDe[parent] or couleurs.checkpoint
		local nom = if numero == 0 then nomZone else `{numero} · {nomZone}`
		if interieur then
			etiquette(marque, nom, accent, 5)
			return p
		end
		local demi = taille / 2 + 0.6
		for _, cote in { -1, 1 } do
			decor(
				bloc(parent, "PilierArche", 1.2, 11, 1.2, x, dessus + 11, z + cote * demi, accent, Enum.Material.Neon)
			)
		end
		local fronton =
			decor(bloc(parent, "Arche", 1.2, 3, taille + 2.4, x, dessus + 14, z, Color3.fromRGB(25, 25, 35)))
		texte(Enum.NormalId.Left, nom, accent).Parent = fronton
		texte(Enum.NormalId.Right, nom, accent).Parent = fronton
		decor(bloc(parent, "LisereArche", 1.3, 0.4, taille + 2.4, x, dessus + 11.2, z, accent, Enum.Material.Neon))
		return p
	end

	-- Panneau de classement : `face` dit vers où il regarde ; `mural` = accroché à un mur (pas de pieds).
	local function tableau(parent, x, dessus, z, face, tag, intitule, couleurTitre, mural)
		local deCote = face == Enum.NormalId.Left or face == Enum.NormalId.Right
		local sx, sz = if deCote then 1 else 14, if deCote then 14 else 1
		local p = decor(bloc(parent, tag, sx, 10, sz, x, dessus + 11, z, Color3.fromRGB(20, 20, 30)))
		etiqueter(p, tag)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = p
		local titre = Instance.new("TextLabel")
		titre.Name = "Titre"
		titre.Size = UDim2.fromScale(1, 0.18)
		titre.BackgroundColor3 = couleurTitre
		titre.TextColor3 = Color3.fromRGB(255, 255, 255)
		titre.TextScaled = true
		titre.Font = Enum.Font.GothamBlack
		titre.Text = intitule
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
		if not mural then
			for _, d in { -5, 5 } do
				local px, pz = if deCote then x else x + d, if deCote then z + d else z
				decor(
					bloc(parent, "PiedTableau", 1, dessus + 6 - SOL, 1, px, dessus + 6, pz, Color3.fromRGB(60, 60, 60))
				)
			end
		end
		return p
	end

	-- Bâtiment creux qu'on traverse : quatre murs, un toit, et des ouvertures (porte, fenêtre) par face.
	-- ouvertures[face] = { centre, largeur, bas, haut } ; face « -X », « +X », « -Z » ou « +Z ».
	local function batiment(parent, nom, x1, x2, z1, z2, haut, couleur, materiau, ouvertures)
		local function mur(ax1, ax2, az1, az2, o, leLongDeZ)
			if not o then
				decor(boite(parent, nom .. "Mur", ax1, ax2, SOL, haut, az1, az2, couleur, materiau))
				return
			end
			decor(boite(parent, nom .. "Mur", ax1, ax2, SOL, o.bas, az1, az2, couleur, materiau))
			decor(boite(parent, nom .. "Mur", ax1, ax2, o.haut, haut, az1, az2, couleur, materiau))
			local g, d = o.centre - o.largeur / 2, o.centre + o.largeur / 2
			if leLongDeZ then
				decor(boite(parent, nom .. "Mur", ax1, ax2, o.bas, o.haut, az1, g, couleur, materiau))
				decor(boite(parent, nom .. "Mur", ax1, ax2, o.bas, o.haut, d, az2, couleur, materiau))
			else
				decor(boite(parent, nom .. "Mur", ax1, g, o.bas, o.haut, az1, az2, couleur, materiau))
				decor(boite(parent, nom .. "Mur", d, ax2, o.bas, o.haut, az1, az2, couleur, materiau))
			end
			-- Encadrement néon : l'ouverture se voit de loin, c'est là qu'on va.
			local cadre = Color3.fromRGB(255, 255, 255)
			if leLongDeZ then
				fantome(
					boite(
						parent,
						"Encadrement",
						ax1 - 0.1,
						ax2 + 0.1,
						o.haut,
						o.haut + 0.4,
						g,
						d,
						cadre,
						Enum.Material.Neon
					)
				)
			else
				fantome(
					boite(
						parent,
						"Encadrement",
						g,
						d,
						o.haut,
						o.haut + 0.4,
						az1 - 0.1,
						az2 + 0.1,
						cadre,
						Enum.Material.Neon
					)
				)
			end
		end
		mur(x1, x1 + 1, z1, z2, ouvertures["-X"], true)
		mur(x2 - 1, x2, z1, z2, ouvertures["+X"], true)
		mur(x1 + 1, x2 - 1, z1, z1 + 1, ouvertures["-Z"], false)
		mur(x1 + 1, x2 - 1, z2 - 1, z2, ouvertures["+Z"], false)
		decor(
			boite(
				parent,
				nom .. "Toit",
				x1 - 0.5,
				x2 + 0.5,
				haut - 1,
				haut,
				z1 - 0.5,
				z2 + 0.5,
				Color3.fromRGB(80, 85, 100),
				Enum.Material.Slate
			)
		)
		-- Bandes de fenêtres sur les grandes faces (décor, sans collision).
		for y = SOL + 6, haut - 4, 6 do
			for _, zf in { z1 - 0.15, z2 + 0.15 } do
				local f = fantome(
					boite(
						parent,
						"Fenetres",
						x1 + 2,
						x2 - 2,
						y,
						y + 2,
						zf - 0.1,
						zf + 0.1,
						Color3.fromRGB(150, 200, 235),
						Enum.Material.Glass
					)
				)
				f.CastShadow = false
			end
		end
	end

	local function contour(p, couleur, epaisseur)
		local boiteSel = Instance.new("SelectionBox")
		boiteSel.Name = "Contour"
		boiteSel.Adornee = p
		boiteSel.Color3 = couleur
		boiteSel.LineThickness = epaisseur or 0.06
		boiteSel.SurfaceTransparency = 1
		boiteSel.Parent = p
	end

	local function boule(parent, nom, taille, x, y, z, couleur, materiau)
		local b = Instance.new("Part")
		b.Name = nom
		b.Shape = Enum.PartType.Ball
		b.Anchored = true
		b.Size = Vector3.new(taille, taille, taille)
		b.CFrame = CFrame.new(x, y, z)
		b.Color = couleur
		b.Material = materiau or Enum.Material.SmoothPlastic
		b.Parent = parent
		return fantome(b)
	end

	local DEBOUT = CFrame.Angles(0, 0, math.rad(90)) -- un cylindre Roblox est couché sur X : on le redresse
	local function cylindre(parent, nom, longueur, diametre, cf, couleur, materiau)
		local c = Instance.new("Part")
		c.Name = nom
		c.Shape = Enum.PartType.Cylinder
		c.Anchored = true
		c.Size = Vector3.new(longueur, diametre, diametre)
		c.CFrame = cf
		c.Color = couleur
		c.Material = materiau or Enum.Material.SmoothPlastic
		c.Parent = parent
		return fantome(c)
	end

	local function arbre(parent, x, z, taille, base)
		taille = taille or 1
		base = base or SOL
		fantome(
			bloc(
				parent,
				"Tronc",
				1.2 * taille,
				6 * taille,
				1.2 * taille,
				x,
				base + 6 * taille,
				z,
				couleurs.tronc,
				Enum.Material.Wood
			)
		)
		boule(parent, "Feuillage", 7 * taille, x, base + 9 * taille, z, couleurs.feuillage, Enum.Material.Grass)
	end

	local function lampadaire(parent, x, z)
		fantome(
			bloc(parent, "Lampadaire", 0.5, 12, 0.5, x, SOL + 12, z, Color3.fromRGB(45, 50, 60), Enum.Material.Metal)
		)
		local tete = fantome(
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
		fantome(
			bloc(parent, "Mat", 0.4, 14, 0.4, x, dessus + 14, z, Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
		)
		for i = 0, 8 do
			local couleur = if i % 2 == 0 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(250, 250, 250)
			fantome(
				bloc(parent, "Bande", 0.15, 0.5, 7, x, dessus + 14 - i * 0.5, z + 3.7, couleur, Enum.Material.Fabric)
			)
		end
		fantome(
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

	-- Maison à colombages : façade claire, poutres sombres sur la face -Z, toit plat où l'on marche.
	local function maison(parent, nom, x, z, largeur, dessus, estDecor)
		local corps =
			decor(pilier(parent, nom, largeur, largeur, x, dessus - 0.5, z, couleurs.facade, Enum.Material.Plaster))
		local hauteur = dessus - SOL
		for i = -1, 1 do
			fantome(
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
			fantome(
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
		local toit =
			dalle(parent, "Toit", largeur + 0.4, largeur + 0.4, x, dessus, z, couleurs.toit, Enum.Material.Slate)
		if estDecor then
			fantome(toit)
			corps.CanCollide = false
		end
		return toit
	end

	local function immeuble(parent, x, z, sx, sz, hauteur, couleur, sansFenetres)
		local corps =
			fantome(bloc(parent, "Immeuble", sx, hauteur, sz, x, SOL + hauteur, z, couleur, Enum.Material.Concrete))
		if not sansFenetres then
			local face = if z > 0 then z - sz / 2 - 0.1 else z + sz / 2 + 0.1
			for h = SOL + 6, SOL + hauteur - 3, 6 do
				local f = fantome(
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
			fantome(
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
	-- La ville : sol, zone mortelle, rue, arbres, lampadaires, immeubles pastel, repères rennais en fond.
	-- Tout ce décor est « fantôme » : un joueur qui tombe le traverse et finit dans la zone mortelle.
	local ville = dossier("Ville")
	decor(bloc(ville, "Sol", 1150, 2, 320, 345, SOL, 0, Color3.fromRGB(110, 175, 85), Enum.Material.Grass))
	fantome(bloc(ville, "Rue", 1150, 0.2, 40, 345, SOL + 0.1, 0, Color3.fromRGB(60, 62, 70), Enum.Material.Asphalt))
	for _, cote in { -1, 1 } do
		fantome(
			bloc(
				ville,
				"Trottoir",
				1150,
				0.6,
				10,
				345,
				SOL + 0.6,
				cote * 25,
				Color3.fromRGB(200, 195, 185),
				Enum.Material.Concrete
			)
		)
	end
	for x = -60, 900, 16 do
		local trait = fantome(bloc(ville, "Marquage", 7, 0.05, 0.6, x, SOL + 0.25, 0, Color3.fromRGB(250, 250, 250)))
		trait.CastShadow = false
	end
	local vide = mortel(bloc(ville, "Vide", 1150, 2, 320, 345, -4, 0, Color3.fromRGB(0, 0, 0)))
	vide.Transparency = 1
	vide.CanCollide = false
	vide.CanQuery = false
	for i = 0, 29 do
		local x = -50 + i * 32
		lampadaire(ville, x, 21)
		lampadaire(ville, x + 16, -21)
		arbre(ville, x + 8, 34, 0.9 + (i % 3) * 0.15)
		arbre(ville, x + 24, -34, 1 + (i % 2) * 0.2)
	end
	local teintes = {
		Color3.fromRGB(240, 215, 190),
		Color3.fromRGB(200, 215, 230),
		Color3.fromRGB(235, 200, 200),
		Color3.fromRGB(215, 230, 205),
	}
	for i = 0, 17 do
		local x = -40 + i * 52
		immeuble(ville, x, 80 + (i % 3) * 8, 30, 24, 30 + (i % 4) * 12, teintes[i % 4 + 1])
		immeuble(ville, x + 20, -85 - (i % 2) * 10, 26, 22, 26 + ((i + 1) % 4) * 14, teintes[(i + 2) % 4 + 1])
	end
	-- Les tours Les Horizons, en fond : deux tours rondes, l'une plus haute que l'autre.
	for _, t in { { x = 120, h = 110 }, { x = 150, h = 85 } } do
		cylindre(
			ville,
			"TourLesHorizons",
			t.h,
			22,
			CFrame.new(t.x, SOL + t.h / 2, -135) * DEBOUT,
			Color3.fromRGB(235, 235, 240),
			Enum.Material.Concrete
		)
		for h = SOL + 8, SOL + t.h - 4, 7 do
			local bague = cylindre(
				ville,
				"Balcons",
				1,
				23,
				CFrame.new(t.x, h, -135) * DEBOUT,
				Color3.fromRGB(120, 130, 150),
				Enum.Material.Glass
			)
			bague.CastShadow = false
		end
	end
	-- La cathédrale Saint-Pierre : façade claire et deux tours carrées.
	immeuble(ville, 480, -120, 40, 24, 45, Color3.fromRGB(225, 210, 180), true)
	for _, dx in { -14, 14 } do
		immeuble(ville, 480 + dx, -115, 12, 12, 70, Color3.fromRGB(215, 200, 170), true)
		fantome(
			bloc(
				ville,
				"Lanterne",
				8,
				6,
				8,
				480 + dx,
				SOL + 76,
				-115,
				Color3.fromRGB(110, 120, 140),
				Enum.Material.Slate
			)
		)
	end
	local rosace = fantome(
		bloc(ville, "Rosace", 0.4, 10, 10, 480, SOL + 32, -107.6, Color3.fromRGB(80, 120, 200), Enum.Material.Glass)
	)
	rosace.Orientation = Vector3.new(0, 90, 0)

	---------------------------------------------------------------------------------------------------------------
	-- 0 · La coloc à Villejean : départ sur le balcon du 5e, descente par les balcons et l'étendoir à linge.
	local coloc = dossier("0_Coloc", accents.coloc)
	decor(
		boite(coloc, "ImmeubleColoc", -40, -12, SOL, 52, -20, 20, Color3.fromRGB(240, 220, 200), Enum.Material.Concrete)
	)
	for y = SOL + 6, 48, 6 do
		if y < 36 or y > 46 then
			fantome(
				boite(
					coloc,
					"Fenetres",
					-11.9,
					-11.7,
					y,
					y + 2,
					-18,
					18,
					Color3.fromRGB(150, 200, 235),
					Enum.Material.Glass
				)
			)
		end
	end
	checkpoint(coloc, 0, -5, 40, 0, "La coloc à Villejean", 14)
	local titre = decor(boite(coloc, "Titre", -13, -12, 52, 58, -14, 14, Color3.fromRGB(25, 25, 35)))
	texte(Enum.NormalId.Right, "OBBY RENNES · PARTIEL MAINTENU", accents.coloc).Parent = titre
	tableau(coloc, -11.5, 40, -13.5, Enum.NormalId.Right, "TableauClassement", "Meilleurs temps", couleurs.vinci, true)
	tableau(coloc, -11.5, 40, 13.5, Enum.NormalId.Right, "TableauAura", "Plus grosse aura", accents.soif, true)
	drapeauBreton(coloc, -14, 52, -18)
	dalle(coloc, "Balcon", 4, 4, 7, 36, 3, couleurs.beton, Enum.Material.Concrete)
	dalle(coloc, "Balcon", 4, 4, 14, 32, -3, couleurs.beton, Enum.Material.Concrete)
	mobile(dalle(coloc, "EtendoirALinge", 4, 4, 22, 28, 0, couleurs.bois, Enum.Material.Wood), Vector3.new(0, 0, 8), 3)
	dalle(coloc, "Balcon", 4, 4, 30, 24, 6, couleurs.beton, Enum.Material.Concrete)
	dalle(coloc, "Balcon", 4, 4, 37, 20, 0, couleurs.beton, Enum.Material.Concrete)
	dalle(coloc, "Balcon", 4, 4, 44, 16, -6, couleurs.beton, Enum.Material.Concrete)

	---------------------------------------------------------------------------------------------------------------
	-- 1-2 · Fac bloquée : on grimpe l'escalier de chaises jusqu'à la fenêtre, on traverse l'amphi par les
	-- rangées (le sol est couvert de café renversé), et on ressort par la fenêtre d'en face.
	local fac = dossier("1_FacBloquee", accents.fac)
	checkpoint(fac, 1, 54, 10, 0, "Fac bloquée")
	dalle(fac, "Chaises", 4, 4, 64, 13, -3, couleurs.chaise)
	dalle(fac, "Chaises", 4, 4, 69.5, 16, 3, couleurs.chaise)
	fragile(dalle(fac, "PileDeCopies", 4, 4, 75, 19, -3, couleurs.papier))
	dalle(fac, "Chaises", 4, 4, 80.5, 22, 2, couleurs.chaise)
	batiment(fac, "Fac", 85, 125, -18, 18, 42, Color3.fromRGB(215, 200, 235), Enum.Material.Concrete, {
		["-X"] = { centre = 0, largeur = 8, bas = 24, haut = 34 },
		["+X"] = { centre = 0, largeur = 8, bas = 31, haut = 40 },
	})
	local banderoleAG =
		decor(boite(fac, "BanderoleAG", 84.6, 84.9, 35, 39, -14, 14, couleurs.banderole, Enum.Material.Fabric))
	texte(
		Enum.NormalId.Left,
		"FAC BLOQUÉE · AG À 10H · PARTIELS REPORTÉS (pas les tiens)",
		Color3.fromRGB(180, 20, 20),
		couleurs.banderole
	).Parent =
		banderoleAG
	mortel(boite(fac, "CafeRenverse", 86, 124, 21, 22, -17, 17, Color3.fromRGB(110, 70, 40), Enum.Material.Slate))
	dalle(fac, "Estrade", 6, 12, 89, 24, 0, couleurs.bois, Enum.Material.WoodPlanks)
	dalle(fac, "Rangee", 3, 20, 96, 25, 0, couleurs.bois, Enum.Material.Wood)
	dalle(fac, "Rangee", 3, 20, 101.5, 27, 0, couleurs.bois, Enum.Material.Wood)
	dalle(fac, "Rangee", 3, 20, 107, 29, 0, couleurs.bois, Enum.Material.Wood)
	dalle(fac, "Rangee", 3, 20, 112.5, 31, 0, couleurs.bois, Enum.Material.Wood)
	checkpoint(fac, 2, 119, 31, 0, "L'amphi bloqué", 8, true)
	local tableauNoir = decor(boite(fac, "TableauNoir", 86, 86.3, 27, 32, -14, -7, Color3.fromRGB(30, 60, 40)))
	texte(
		Enum.NormalId.Right,
		"PARTIEL MAINTENU\n(on a dit)",
		Color3.fromRGB(240, 240, 230),
		Color3.fromRGB(30, 60, 40)
	).Parent =
		tableauNoir

	---------------------------------------------------------------------------------------------------------------
	-- 3-4 · Le viaduc de la ligne b : de rame en rame au-dessus de la ville, puis on redescend vers la station.
	local metro = dossier("2_Metro", accents.metro)
	dalle(metro, "Rebord", 4, 6, 128, 31, 0, couleurs.beton, Enum.Material.Concrete)
	local function rame(nom, longueur, x)
		return bloc(metro, nom, longueur, 7, 6, x, 34, 0, couleurs.metro, Enum.Material.Metal)
	end
	for _, x in { 142, 166 } do
		rame("Rame", 18, x)
		fantome(bloc(metro, "Vitres", 16, 2, 6.1, x, 32, 0, Color3.fromRGB(30, 40, 60), Enum.Material.Glass))
		decor(bloc(metro, "PileDuViaduc", 3, 27 - SOL, 3, x, 27, 0, couleurs.beton, Enum.Material.Concrete))
	end
	mobile(rame("RameQuiRepartQuandMeme", 10, 185), Vector3.new(0, 0, 10), 3)
	checkpoint(metro, 3, 202, 34, 0, "Le viaduc de la ligne b")
	decor(bloc(metro, "PileDuViaduc", 4, 33 - SOL, 4, 202, 33, 0, couleurs.beton, Enum.Material.Concrete))
	dalle(metro, "Escalator", 4, 6, 213, 30, 0, couleurs.quai, Enum.Material.DiamondPlate)
	dalle(metro, "Escalator", 4, 6, 219, 26, 0, couleurs.quai, Enum.Material.DiamondPlate)
	fragile(dalle(metro, "EscalatorEnPanne", 4, 6, 225, 22, 0, couleurs.papier))
	dalle(metro, "Escalator", 4, 6, 231, 18, 0, couleurs.quai, Enum.Material.DiamondPlate)
	checkpoint(metro, 4, 243, 14, 0, "La station")
	local girouette = decor(bloc(metro, "PanneauStation", 0.4, 3, 12, 196.5, 44, -9, Color3.fromRGB(20, 20, 25)))
	texte(Enum.NormalId.Left, "LIGNE B · TRAFIC INTERROMPU", Color3.fromRGB(255, 170, 30)).Parent = girouette

	---------------------------------------------------------------------------------------------------------------
	-- 5-6 · Le cortège, place de la République : pancartes, banderoles qui bougent, camion sono.
	local cortege = dossier("3_Cortege", accents.cortege)
	local function banderole(x, dessus, slogan, deplacement, duree)
		local b = dalle(cortege, "Banderole", 4, 12, x, dessus, 0, couleurs.banderole, Enum.Material.Fabric)
		texte(Enum.NormalId.Top, slogan, Color3.fromRGB(190, 30, 30), couleurs.banderole).Parent = b
		return mobile(b, deplacement, duree)
	end
	dalle(cortege, "Pancarte", 2, 2, 254, 15, 0, couleurs.pancarte)
	banderole(262, 15, "DES PRISES DANS LES AMPHIS", Vector3.new(0, 0, 8), 4)
	dalle(cortege, "Pancarte", 2, 2, 270, 17, 0, couleurs.pancarte)
	banderole(278, 17, "NON AUX PARTIELS À 8H", Vector3.new(0, 0, -8), 3)
	dalle(cortege, "Pancarte", 2, 2, 286, 19, 0, couleurs.pancarte)
	checkpoint(cortege, 5, 298, 19, 0, "Place de la République")
	local sono = mobile(
		bloc(cortege, "CamionSono", 8, 2, 8, 314, 19, 0, couleurs.camion, Enum.Material.Metal),
		Vector3.new(12, 0, 0),
		4
	)
	etiquette(sono, "♪ SONO ♪", couleurs.pancarte, 3)
	checkpoint(cortege, 6, 342, 19, 0, "Le cortège")
	local palais = immeuble(cortege, 300, 48, 70, 20, 28, couleurs.pierre, true)
	texte(Enum.NormalId.Front, "PALAIS DU COMMERCE", Color3.fromRGB(60, 50, 40), couleurs.pierre).Parent = palais

	---------------------------------------------------------------------------------------------------------------
	-- 7-8 · La barricade de poubelles, puis la tour : une spirale de balcons autour, on entre au 20e par la
	-- fenêtre, on traverse l'appart (le sol est couvert de Lego, le ventilo de plafond tourne), on ressort de
	-- l'autre côté et on redescend par les échafaudages.
	local tour = dossier("4_LaTour", accents.tour)
	mortel(boite(tour, "JusDePoubelle", 349, 372, 13, 14, -10, 10, couleurs.jus, Enum.Material.Mud))
	pilier(tour, "Bac", 4, 4, 353, 21, 0, couleurs.bac)
	fragile(dalle(tour, "Carton", 4, 4, 360.5, 22, 2, couleurs.papier))
	pilier(tour, "Bac", 4, 4, 367, 23, -1, couleurs.bacJaune)
	checkpoint(tour, 7, 374, 24, 0, "Barricades de poubelles", 8, true)
	local CX = 395 -- centre de la tour (murs de 381 à 409 en X, de -14 à 14 en Z)
	batiment(tour, "Tour", CX - 14, CX + 14, -14, 14, 78, Color3.fromRGB(235, 225, 210), Enum.Material.Concrete, {
		["-X"] = { centre = 0, largeur = 8, bas = 64, haut = 74 },
		["+X"] = { centre = 0, largeur = 8, bas = 66, haut = 76 },
	})
	-- La spirale : balcons de 5 × 5 qui montent de 2,5 à chaque saut, une fois et quart autour de la tour.
	local spirale = {
		{ 376, -11 },
		{ 378, -19 },
		{ 386, -20 },
		{ 395, -20 },
		{ 404, -20 },
		{ 412, -19 },
		{ 414, -11 },
		{ 414, -2 },
		{ 414, 7 },
		{ 413, 15 },
		{ 406, 20 },
		{ 397, 20 },
		{ 388, 20 },
		{ 379, 19 },
		{ 376, 11 },
		{ 376, 2 },
	}
	for i, pos in spirale do
		local b = dalle(tour, "Balcon", 5, 5, pos[1], 24 + 2.5 * i, pos[2], couleurs.beton, Enum.Material.Concrete)
		if i == 5 or i == 12 then
			fragile(b)
		end
		fantome(
			bloc(
				tour,
				"Rambarde",
				0.3,
				1.2,
				0.3,
				pos[1],
				24 + 2.5 * i + 1.2,
				pos[2],
				Color3.fromRGB(60, 65, 75),
				Enum.Material.Metal
			)
		)
	end
	-- L'appart du 20e.
	mortel(
		boite(
			tour,
			"SolEnLego",
			CX - 13,
			CX + 13,
			62,
			63,
			-13,
			13,
			Color3.fromRGB(230, 60, 60),
			Enum.Material.SmoothPlastic
		)
	)
	dalle(tour, "Paillasson", 4, 8, CX - 11, 64, 0, Color3.fromRGB(150, 100, 60), Enum.Material.Fabric)
	fragile(dalle(tour, "CartonDeDemenagement", 4, 4, CX - 5, 65, 0, couleurs.papier))
	dalle(tour, "Canape", 6, 6, CX + 2, 66, -4, Color3.fromRGB(80, 110, 200), Enum.Material.Fabric)
	tournant(
		bloc(tour, "VentiloDePlafond", 1.2, 2, 8, CX + 2, 69, 0, Color3.fromRGB(240, 240, 240), Enum.Material.Neon),
		1.4
	)
	checkpoint(tour, 8, CX + 9.5, 66, 0, "La tour", 6, true)
	local motDuVoisin = decor(boite(tour, "MotDuVoisin", CX - 13, CX - 12.8, 66, 69, 6, 11, couleurs.papier))
	texte(
		Enum.NormalId.Right,
		"MERCI DE NE PLUS\nFAIRE DE PARCOURS\nDANS L'APPART",
		Color3.fromRGB(30, 30, 30),
		couleurs.papier
	).Parent =
		motDuVoisin
	-- La descente par les échafaudages.
	dalle(tour, "Rebord", 4, 6, CX + 17, 66, 0, couleurs.beton, Enum.Material.Concrete)
	dalle(tour, "Echafaudage", 4, 4, CX + 26, 58, 0, Color3.fromRGB(240, 160, 40), Enum.Material.Metal)
	dalle(tour, "Echafaudage", 4, 4, CX + 35, 50, 4, Color3.fromRGB(240, 160, 40), Enum.Material.Metal)
	dalle(tour, "Echafaudage", 4, 4, CX + 44, 42, -4, Color3.fromRGB(240, 160, 40), Enum.Material.Metal)
	dalle(tour, "Echafaudage", 4, 4, CX + 53, 34, 0, Color3.fromRGB(240, 160, 40), Enum.Material.Metal)
	drapeauBreton(tour, CX + 12, 78, -12)

	---------------------------------------------------------------------------------------------------------------
	-- 9-10 · Rue de la Soif : de toit en toit, puis on descend dans la rue par les auvents des bars.
	local soif = dossier("5_RueDeLaSoif", accents.soif)
	maison(soif, "Maison", 458, 0, 8, 31)
	pilier(soif, "Cheminee", 2, 2, 466, 33, 0, Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	maison(soif, "Maison", 475, 0, 8, 30)
	maison(soif, "Maison", 488, 0, 12, 27)
	checkpoint(soif, 9, 488, 28, 0, "Rue de la Soif")
	dalle(soif, "Auvent", 4, 6, 499, 24, 0, Color3.fromRGB(200, 40, 60), Enum.Material.Fabric)
	dalle(soif, "Auvent", 4, 6, 505, 19, 0, Color3.fromRGB(40, 120, 200), Enum.Material.Fabric)
	dalle(soif, "Auvent", 4, 6, 511, 14, 0, Color3.fromRGB(240, 180, 40), Enum.Material.Fabric)
	dalle(soif, "Terrasse", 30, 10, 532, 10, 0, couleurs.bois, Enum.Material.WoodPlanks)
	tournant(bloc(soif, "EnseigneDeBar", 1.2, 2, 22, 532, 13, 0, Color3.fromRGB(220, 60, 140), Enum.Material.Neon), 1.6)
	checkpoint(soif, 10, 559, 10, 0, "Le dernier bar avant le partiel")
	for i = 0, 6 do
		maison(soif, "MaisonDecor", 455 + i * 16, 26, 12, 16 + (i % 3) * 5, true)
	end

	---------------------------------------------------------------------------------------------------------------
	-- 11-12 · La Vilaine : au ras de l'eau (mortelle), péniche à la dérive, puis on remonte par les bouées.
	local vilaine = dossier("6_LaVilaine", accents.vilaine)
	local eau = mortel(boite(vilaine, "LaVilaine", 566, 680, 1, 2, -35, 35, couleurs.eau, Enum.Material.Glass))
	eau.Transparency = 0.25
	dalle(vilaine, "Quai", 4, 6, 570, 7, 0, couleurs.pierre, Enum.Material.Cobblestone)
	dalle(vilaine, "Ponton", 4, 8, 577, 5, 0, couleurs.ponton, Enum.Material.WoodPlanks)
	mobile(
		dalle(vilaine, "PenicheALaDerive", 10, 6, 588, 5, 0, Color3.fromRGB(30, 80, 50), Enum.Material.Wood),
		Vector3.new(0, 0, 10),
		5
	)
	dalle(vilaine, "Ponton", 4, 8, 599, 5, 0, couleurs.ponton, Enum.Material.WoodPlanks)
	checkpoint(vilaine, 11, 611, 5, 0, "La Vilaine")
	dalle(vilaine, "Bouee", 4, 4, 622, 8, 0, Color3.fromRGB(240, 90, 40))
	fragile(dalle(vilaine, "BoueeCrevee", 4, 4, 629, 11, 2, couleurs.papier))
	dalle(vilaine, "Bouee", 4, 4, 636, 14, -1, Color3.fromRGB(240, 90, 40))
	checkpoint(vilaine, 12, 647, 17, 0, "Les quais")
	for _, dz in { -4, 4 } do
		decor(bloc(vilaine, "PileDuPont", 3, 15, 3, 647, 16, dz, couleurs.pierre, Enum.Material.Cobblestone))
	end

	---------------------------------------------------------------------------------------------------------------
	-- 13 · Le Parlement de Bretagne : colonnes, corniches de la façade, puis le toit d'ardoise (glissant, donc
	-- mortel) qu'on traverse de lucarne en lucarne.
	local parlement = dossier("7_Parlement", accents.parlement)
	pilier(parlement, "Colonne", 4, 4, 657, 20, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 3, 3, 664, 23, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 3, 3, 671, 26, 0, couleurs.pierre, Enum.Material.Marble)
	pilier(parlement, "Colonne", 2, 2, 677, 29, 0, couleurs.pierre, Enum.Material.Marble)
	decor(boite(parlement, "Parlement", 685, 745, SOL, 40, -15, 15, couleurs.pierre, Enum.Material.Marble))
	local frontonParlement = decor(boite(parlement, "Fronton", 684.6, 685, 18, 28, -12, 12, couleurs.pierre))
	texte(Enum.NormalId.Left, "PARLEMENT DE BRETAGNE", Color3.fromRGB(150, 120, 40), couleurs.pierre).Parent =
		frontonParlement
	dalle(parlement, "Corniche", 4, 4, 683, 32, 0, couleurs.or_, Enum.Material.Marble)
	dalle(parlement, "Corniche", 4, 4, 683, 35, 6, couleurs.or_, Enum.Material.Marble)
	dalle(parlement, "Corniche", 4, 4, 683, 38, 12, couleurs.or_, Enum.Material.Marble)
	mortel(
		boite(
			parlement,
			"ArdoiseGlissante",
			690,
			745,
			40,
			40.6,
			-15,
			15,
			Color3.fromRGB(50, 60, 80),
			Enum.Material.Slate
		)
	)
	-- Gouttière de pierre le long du bord de la façade, de X = 685 jusqu'à la première lucarne (X = 690) : on y
	-- atterrit depuis la dernière corniche, bien au-dessus de l'ardoise (qui ne commence qu'à X = 690).
	boite(parlement, "Gouttiere", 685, 690, 40, 41.5, -15, 15, couleurs.pierre, Enum.Material.Marble)
	-- On monte la façade en diagonale (corniches de Z = 0 à Z = 12), puis on revient vers l'axe de lucarne en lucarne.
	local lucarnes = { { 692, 8 }, { 697, 0 }, { 705, 0 }, { 723, 0 }, { 731, 0 }, { 739, 0 } }
	for _, l in lucarnes do
		bloc(parlement, "Lucarne", 4, 2, 4, l[1], 42, l[2], couleurs.pierre, Enum.Material.Marble)
	end
	decor(bloc(parlement, "Campanile", 8, 2, 8, 715, 41, 0, couleurs.pierre, Enum.Material.Marble))
	checkpoint(parlement, 13, 715, 42, 0, "Sur le toit du Parlement", 8)
	drapeauBreton(parlement, 743, 40, -14)
	drapeauBreton(parlement, 743, 40, 6)

	---------------------------------------------------------------------------------------------------------------
	-- 14 · Le Thabor : de cime en cime au-dessus de la pelouse interdite (mortelle), puis les haies.
	local thabor = dossier("8_Thabor", accents.thabor)
	mortel(boite(thabor, "PelouseInterdite", 748, 818, 11, 12, -30, 30, couleurs.pelouse, Enum.Material.Grass))
	local cimes = { { 750, 36, 0 }, { 758, 30, 4 }, { 766, 24, -4 }, { 774, 18, 3 } }
	for _, c in cimes do
		bloc(thabor, "Cime", 6, 3, 6, c[1], c[2], c[3], couleurs.feuillage, Enum.Material.Grass)
		decor(bloc(thabor, "Tronc", 1.5, c[2] - 3 - SOL, 1.5, c[1], c[2] - 3, c[3], couleurs.tronc, Enum.Material.Wood))
	end
	bloc(thabor, "Haie", 4, 3, 8, 782, 16, -3, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 790, 17, 4, couleurs.haie, Enum.Material.Grass)
	bloc(thabor, "Haie", 4, 3, 8, 798, 18, 0, couleurs.haie, Enum.Material.Grass)
	checkpoint(thabor, 14, 810, 18, 0, "Le Thabor")
	local pancarte = fantome(bloc(thabor, "PancartePelouse", 0.4, 3, 8, 760, 18, 14, Color3.fromRGB(25, 25, 30)))
	texte(Enum.NormalId.Left, "PELOUSE INTERDITE\n(vraiment)", Color3.fromRGB(255, 255, 255)).Parent = pancarte
	for i = 0, 5 do
		arbre(thabor, 752 + i * 11, 24 + (i % 2) * 4, 1.4, 12)
		arbre(thabor, 756 + i * 11, -24 - (i % 2) * 4, 1.3, 12)
	end

	---------------------------------------------------------------------------------------------------------------
	-- 15 · Sup de Vinci : on entre par la porte, on monte l'atrium de palier en palier (le hall en travaux est
	-- mortel), et on arrive dans la salle de partiel, en mezzanine.
	local vinci = dossier("9_SupDeVinci", accents.vinci)
	dalle(vinci, "Marche", 4, 4, 820, 18, 0, couleurs.pierre, Enum.Material.Concrete)
	batiment(vinci, "SupDeVinci", 825, 865, -16, 16, 56, Color3.fromRGB(70, 120, 200), Enum.Material.Glass, {
		["-X"] = { centre = 0, largeur = 8, bas = 18, haut = 30 },
	})
	local frontonVinci = decor(boite(vinci, "Fronton", 824.6, 825, 34, 42, -13, 13, couleurs.vinci))
	texte(Enum.NormalId.Left, "SUP DE VINCI", Color3.fromRGB(255, 255, 255), couleurs.vinci).Parent = frontonVinci
	mortel(
		boite(
			vinci,
			"HallEnTravaux",
			826,
			864,
			15,
			16,
			-15,
			15,
			Color3.fromRGB(240, 170, 40),
			Enum.Material.DiamondPlate
		)
	)
	dalle(vinci, "Accueil", 6, 8, 829, 18, 0, couleurs.beton, Enum.Material.Concrete)
	local paliers = { { 837, -10 }, { 845, -11 }, { 853, -11 }, { 860, -5 }, { 860, 4 }, { 853, 11 }, { 845, 11 } }
	for i, pos in paliers do
		local p = dalle(vinci, "Palier", 5, 5, pos[1], 18 + 3 * i, pos[2], couleurs.beton, Enum.Material.Concrete)
		if i == 3 then
			fragile(p)
		end
	end
	checkpoint(vinci, 15, 834, 42, 8, "Sup de Vinci · salle de partiel", 12, true)
	for _, x in { 831, 837 } do
		for _, z in { 5, 11 } do
			decor(bloc(vinci, "TableDExamen", 3, 3, 2, x, 45, z, couleurs.bois, Enum.Material.Wood))
		end
	end
	tableau(vinci, 836, 42, 14.5, Enum.NormalId.Front, "TableauClassement", "Meilleurs temps", couleurs.vinci, true)
	tableau(vinci, 851, 42, 14.5, Enum.NormalId.Front, "TableauAura", "Plus grosse aura", accents.soif, true)
	drapeauBreton(vinci, 862, 56, -15)
	local canon = fantome(bloc(vinci, "Confettis", 12, 0.2, 12, 834, 52, 8, couleurs.or_))
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
		ColorSequenceKeypoint.new(0, accents.vinci),
		ColorSequenceKeypoint.new(0.5, couleurs.or_),
		ColorSequenceKeypoint.new(1, accents.soif),
	})
	confettis.Parent = canon

	---------------------------------------------------------------------------------------------------------------
	-- Références : bâtiments de Rennes, sarcasme sur la vie étudiante, mascottes brain rot maison.
	-- Tout est fantôme (on ne peut pas s'y poser) et hors du chemin.
	local refs = dossier("References")

	-- Affiche sur pied au bord du chemin (Z = ±17), tournée vers le parcours.
	local function affiche(contenu: string, x, haut, cote, fond, encre)
		local z = cote * 17
		fantome(
			bloc(
				refs,
				"PiedAffiche",
				0.6,
				haut - SOL - 3,
				0.6,
				x,
				haut - 3,
				z,
				Color3.fromRGB(50, 55, 65),
				Enum.Material.Metal
			)
		)
		local plaque = fantome(bloc(refs, "Affiche", 12, 6, 0.4, x, haut + 3, z, fond))
		texte(if cote < 0 then Enum.NormalId.Back else Enum.NormalId.Front, contenu, encre, fond).Parent = plaque
		fantome(
			bloc(
				refs,
				"CadreAffiche",
				12.6,
				0.4,
				0.6,
				x,
				haut + 3.2,
				z,
				Color3.fromRGB(30, 30, 35),
				Enum.Material.Metal
			)
		)
	end
	local noir, blanc = Color3.fromRGB(20, 20, 25), Color3.fromRGB(255, 255, 255)
	affiche(
		"STUDIO 9 m² · 690 €/mois\ncharges non comprises · vue sur poubelle",
		20,
		38,
		1,
		Color3.fromRGB(255, 240, 200),
		noir
	)
	affiche(
		"COLOC CHERCHE 4e COLOC\ndoit aimer les pâtes et les grèves",
		45,
		22,
		-1,
		Color3.fromRGB(250, 120, 40),
		blanc
	)
	affiche("PROCHAINE RAME :\nquand les poules auront un pass STAR", 150, 40, -1, Color3.fromRGB(235, 50, 60), blanc)
	affiche("+1000 AURA\nsi tu passes sans tomber", 172, 40, 1, Color3.fromRGB(255, 120, 220), noir)
	affiche("PARCOURSUP\nrang 4 867 · en attente", 268, 22, 1, blanc, Color3.fromRGB(30, 80, 170))
	affiche("RU : PLUS DE FRITES\nil reste du chou-fleur", 300, 25, -1, Color3.fromRGB(120, 200, 60), noir)
	affiche("GALETTE-SAUCISSE · 5 €\n(3 € avant l'inflation)", 330, 24, -1, Color3.fromRGB(205, 150, 75), noir)
	affiche(
		"GRÈVE DES ÉBOUEURS : J+12\nl'odeur, elle, ne fait pas grève",
		358,
		27,
		1,
		Color3.fromRGB(40, 170, 90),
		blanc
	)
	affiche("ASCENSEUR EN PANNE\ndepuis 2019", 440, 44, -1, Color3.fromRGB(240, 160, 40), noir)
	affiche(
		"TRANSMUSICALES\ncomplet · comme ton agenda",
		478,
		36,
		-1,
		Color3.fromRGB(20, 20, 30),
		Color3.fromRGB(255, 70, 180)
	)
	affiche("SKIBIDI PARTIEL\n8 h · amphi B · pas de rattrapage", 520, 16, 1, Color3.fromRGB(255, 220, 40), noir)
	affiche("IL NE PLEUT PAS À RENNES\nil bruine.", 575, 12, -1, Color3.fromRGB(120, 140, 160), blanc)
	affiche("BAIGNADE INTERDITE\n(sauf si tu rates le saut)", 605, 12, 1, Color3.fromRGB(40, 150, 230), blanc)
	affiche("KOUIGN-AMANN\n0 % de beurre doux, 100 % de bonheur", 660, 26, -1, Color3.fromRGB(230, 170, 70), noir)
	affiche("POV : t'as révisé\nla veille à 3 h", 770, 30, 1, Color3.fromRGB(150, 90, 255), blanc)
	affiche(
		"LOYER, BOURSE, INFLATION\nle vrai boss final",
		818,
		26,
		-1,
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(200, 40, 40)
	)

	-- Galettino Saucissino : mascotte brain rot maison, une galette-saucisse géante à lunettes, près du cortège.
	do
		local x, z = 318, -42
		cylindre(refs, "Jambe", 8, 2.2, CFrame.new(x - 3, SOL + 4, z) * DEBOUT, Color3.fromRGB(170, 70, 50))
		cylindre(refs, "Jambe", 8, 2.2, CFrame.new(x + 3, SOL + 4, z) * DEBOUT, Color3.fromRGB(170, 70, 50))
		fantome(bloc(refs, "Galette", 16, 22, 2, x, SOL + 30, z - 2, Color3.fromRGB(205, 150, 75), Enum.Material.Sand))
		cylindre(refs, "Saucisse", 22, 7, CFrame.new(x, SOL + 19, z + 1) * DEBOUT, Color3.fromRGB(185, 75, 55))
		local tete = boule(refs, "Tete", 7, x, SOL + 30, z + 1, Color3.fromRGB(185, 75, 55))
		fantome(
			bloc(refs, "Lunettes", 7.5, 1.6, 0.6, x, SOL + 32, z + 4.6, Color3.fromRGB(15, 15, 20), Enum.Material.Glass)
		)
		fantome(bloc(refs, "Sourire", 3, 0.5, 0.4, x, SOL + 28.6, z + 4.4, Color3.fromRGB(40, 15, 10)))
		etiquette(tete, "GALETTINO SAUCISSINO", Color3.fromRGB(255, 210, 60), 7)
	end

	-- Kouign Amannini : deuxième mascotte maison, un kouign-amann à couronne qui surveille la Vilaine.
	do
		local x, z = 640, -46
		local corps = boule(refs, "KouignAmann", 16, x, SOL + 5, z, Color3.fromRGB(215, 140, 55), Enum.Material.Sand)
		corps.Size = Vector3.new(16, 10, 16)
		for _, dx in { -3, 3 } do
			boule(refs, "Oeil", 3, x + dx, SOL + 8, z + 6.5, Color3.fromRGB(255, 255, 255))
			boule(refs, "Pupille", 1.4, x + dx, SOL + 8, z + 7.8, Color3.fromRGB(15, 15, 20))
		end
		for i = 0, 4 do
			local angle = math.rad(i * 72)
			fantome(
				bloc(
					refs,
					"Couronne",
					1,
					3,
					1,
					x + math.cos(angle) * 3,
					SOL + 12.5,
					z + math.sin(angle) * 3,
					couleurs.or_,
					Enum.Material.Neon
				)
			)
		end
		etiquette(corps, "KOUIGN AMANNINI", Color3.fromRGB(255, 200, 80), 9)
	end

	-- Hôtel de ville et son horloge : il est toujours l'heure du partiel.
	do
		local x, z = 270, -50
		immeuble(refs, x, z, 44, 14, 24, Color3.fromRGB(235, 220, 185), true)
		immeuble(refs, x, z, 10, 10, 44, Color3.fromRGB(225, 210, 175), true)
		fantome(bloc(refs, "Dome", 6, 6, 6, x, SOL + 50, z, Color3.fromRGB(80, 95, 120), Enum.Material.Slate))
		local horloge = fantome(bloc(refs, "Horloge", 6, 6, 0.4, x, SOL + 38, z + 5.2, Color3.fromRGB(255, 250, 235)))
		texte(Enum.NormalId.Back, "8:00", Color3.fromRGB(30, 30, 40), Color3.fromRGB(255, 250, 235)).Parent = horloge
		local fronton = fantome(bloc(refs, "Fronton", 30, 3, 0.4, x, SOL + 20, z + 7.2, Color3.fromRGB(235, 220, 185)))
		texte(Enum.NormalId.Back, "HÔTEL DE VILLE", Color3.fromRGB(90, 70, 40), Color3.fromRGB(235, 220, 185)).Parent =
			fronton
	end

	-- Portes Mordelaises : deux tours rondes et une porte, l'ancienne entrée de la ville.
	do
		local x, z = 470, -48
		for _, dx in { -9, 9 } do
			cylindre(
				refs,
				"TourMordelaise",
				26,
				10,
				CFrame.new(x + dx, SOL + 13, z) * DEBOUT,
				Color3.fromRGB(150, 140, 125),
				Enum.Material.Cobblestone
			)
			fantome(
				bloc(
					refs,
					"Creneau",
					11,
					2,
					11,
					x + dx,
					SOL + 28,
					z,
					Color3.fromRGB(130, 120, 105),
					Enum.Material.Cobblestone
				)
			)
		end
		local porte = fantome(
			bloc(refs, "Porte", 8, 18, 8, x, SOL + 18, z, Color3.fromRGB(160, 150, 135), Enum.Material.Cobblestone)
		)
		texte(Enum.NormalId.Back, "PORTES MORDELAISES", Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 100, 90)).Parent =
			porte
	end

	-- Les Champs Libres : bâtiment incliné et planétarium en boule de verre, au bord de la Vilaine.
	do
		local x, z = 600, -54
		local corps = fantome(
			bloc(refs, "ChampsLibres", 30, 18, 16, x, SOL + 18, z, Color3.fromRGB(70, 75, 90), Enum.Material.Glass)
		)
		corps.CFrame = corps.CFrame * CFrame.Angles(0, 0, math.rad(-8))
		boule(refs, "Planetarium", 14, x + 18, SOL + 8, z + 2, Color3.fromRGB(150, 200, 240), Enum.Material.Glass)
		local enseigne = fantome(bloc(refs, "Enseigne", 20, 3, 0.4, x, SOL + 22, z + 8.4, Color3.fromRGB(20, 20, 30)))
		texte(Enum.NormalId.Back, "LES CHAMPS LIBRES", Color3.fromRGB(255, 255, 255)).Parent = enseigne
	end

	-- Le crachin breton : un nuage qui bruine au-dessus de la Vilaine.
	do
		for i = 0, 4 do
			boule(refs, "Nuage", 12 + (i % 2) * 4, 575 + i * 9, 58 + (i % 2) * 2, 2, Color3.fromRGB(205, 210, 220))
		end
		local source = fantome(bloc(refs, "Bruine", 44, 0.2, 18, 593, 54, 2, Color3.fromRGB(200, 200, 210)))
		source.Transparency = 1
		local pluie = Instance.new("ParticleEmitter")
		pluie.Rate = 120
		pluie.Lifetime = NumberRange.new(1.5, 2)
		pluie.Speed = NumberRange.new(28, 34)
		pluie.EmissionDirection = Enum.NormalId.Bottom
		pluie.Size = NumberSequence.new(0.12)
		pluie.Transparency = NumberSequence.new(0.4)
		pluie.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
		pluie.Parent = source
	end

	-- Un bus STAR en grève, garé dans la rue.
	do
		local x, z = 230, -28
		fantome(bloc(refs, "Bus", 24, 8, 7, x, SOL + 9, z, Color3.fromRGB(235, 235, 240)))
		fantome(bloc(refs, "BandeBus", 24.2, 2, 7.2, x, SOL + 4, z, Color3.fromRGB(220, 40, 50)))
		fantome(bloc(refs, "VitresBus", 22, 2.5, 7.1, x, SOL + 7.5, z, Color3.fromRGB(40, 50, 70), Enum.Material.Glass))
		for _, dx in { -8, 8 } do
			cylindre(
				refs,
				"Roue",
				1.5,
				3,
				CFrame.new(x + dx, SOL + 1.5, z) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(25, 25, 25)
			)
		end
		local girouetteBus =
			fantome(bloc(refs, "Girouette", 0.4, 1.5, 6, x - 12.2, SOL + 8.6, z, Color3.fromRGB(10, 10, 10)))
		texte(Enum.NormalId.Left, "EN GRÈVE", Color3.fromRGB(255, 170, 30), Color3.fromRGB(10, 10, 10)).Parent =
			girouetteBus
	end

	-- Roazhon Park, derrière le départ : tribunes rouges et noires autour d'une pelouse.
	do
		local x, z = -115, 0
		fantome(bloc(refs, "Pelouse", 50, 0.4, 34, x, SOL + 0.4, z, Color3.fromRGB(70, 170, 70), Enum.Material.Grass))
		local tribunes = {
			{ dx = 0, dz = -23, sx = 60, sz = 10 },
			{ dx = 0, dz = 23, sx = 60, sz = 10 },
			{ dx = -31, dz = 0, sx = 10, sz = 36 },
			{ dx = 31, dz = 0, sx = 10, sz = 36 },
		}
		for i, t in tribunes do
			local couleur = if i % 2 == 0 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(210, 30, 40)
			fantome(
				bloc(refs, "Tribune", t.sx, 16, t.sz, x + t.dx, SOL + 16, z + t.dz, couleur, Enum.Material.Concrete)
			)
		end
		local nom = fantome(bloc(refs, "NomStade", 0.4, 4, 30, x + 36.2, SOL + 13, z, Color3.fromRGB(210, 30, 40)))
		texte(Enum.NormalId.Right, "ROAZHON PARK", Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 30, 40)).Parent =
			nom
	end

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
