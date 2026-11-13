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

	-- Densité des SurfaceGui. Le plancher est de 40 px/stud pour toute face dont la plus petite dimension fait moins
	-- de 15 studs (panneaux, tableaux, enseignes courantes) : baisser la densité ne grossit pas le texte (TextScaled et
	-- les tailles fixes suivent le cadre, pas la toile), elle le rend seulement flou. Seules les très grandes enseignes
	-- (15 studs et plus) gardent une toile d'environ 600 px sur leur plus petite dimension (jamais moins de 8 px/stud),
	-- pour ne pas gaspiller de mémoire de texture.
	local DENSITE = 40
	local GRANDE_FACE = 15
	local TOILE_GRANDE = 600
	local function densiteDe(part, face)
		local s = part.Size
		local l, h
		if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
			l, h = s.Z, s.Y
		elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
			l, h = s.X, s.Z
		else
			l, h = s.X, s.Y
		end
		local petite = math.min(l, h)
		if petite < GRANDE_FACE then
			return DENSITE
		end
		return math.clamp(TOILE_GRANDE / petite, 8, DENSITE)
	end

	-- À appeler en fin de construction : règle la densité de chaque SurfaceGui d'après la face qui la porte.
	local function calibrerSurfaces(racine)
		for _, d in racine:GetDescendants() do
			if d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") then
				d.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				d.PixelsPerStud = densiteDe(d.Parent, d.Face)
			end
		end
	end

	local function texte(surface, contenu: string, couleurTexte, couleurFond)
		local gui = Instance.new("SurfaceGui")
		gui.Face = surface
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- densité réglée par calibrerSurfaces
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
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- densité réglée par calibrerSurfaces
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
		-- Taille fixe : 10 lignes en police Code tiennent dans le label (hauteur en pixels / 11 ; 0,78 × 10 studs à
		-- 40 px/stud = 312 px, soit 28 px). Le client règle l'alignement : centré pour un message, en haut à gauche
		-- pour la liste.
		liste.TextScaled = false
		liste.TextWrapped = true
		liste.TextSize = math.floor(0.78 * 10 * DENSITE / 11)
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

	-- Pièce fantôme placée par le CFrame de son centre : détails de façade, décor de fond, pièces tournées.
	local function piece(parent, nom, sx, sy, sz, cf, couleur, materiau)
		local p = Instance.new("Part")
		p.Name = nom
		p.Anchored = true
		p.Size = Vector3.new(sx, sy, sz)
		p.CFrame = cf
		p.Color = couleur
		p.Material = materiau or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return fantome(p)
	end

	-- Pan incliné fantôme (WedgePart) : sa face verticale est du côté +Z local, la pente descend vers -Z local.
	local function pente(parent, nom, sx, sy, sz, cf, couleur, materiau)
		local w = Instance.new("WedgePart")
		w.Name = nom
		w.Anchored = true
		w.Size = Vector3.new(sx, sy, sz)
		w.CFrame = cf
		w.Color = couleur
		w.Material = materiau or Enum.Material.SmoothPlastic
		w.TopSurface = Enum.SurfaceType.Smooth
		w.BottomSurface = Enum.SurfaceType.Smooth
		w.Parent = parent
		return fantome(w)
	end

	-- Toit à deux pans posé à la hauteur `base`, centré en (x, z) : deux WedgePart dos à dos, faîtage le long de X
	-- (`leLongDeX`) ou de Z. `longueur` suit le faîtage, `largeur` va d'un égout à l'autre. Avec une `longueur`
	-- très faible, c'est un triangle debout : pignon, fronton, ogive de porte.
	local function deuxPans(parent, nom, x, base, z, longueur, largeur, hauteur, leLongDeX, couleur, materiau)
		local y = base + hauteur / 2
		materiau = materiau or Enum.Material.Slate
		if leLongDeX then
			pente(parent, nom, longueur, hauteur, largeur / 2, CFrame.new(x, y, z - largeur / 4), couleur, materiau)
			pente(
				parent,
				nom,
				longueur,
				hauteur,
				largeur / 2,
				CFrame.new(x, y, z + largeur / 4) * CFrame.Angles(0, math.pi, 0),
				couleur,
				materiau
			)
		else
			pente(
				parent,
				nom,
				longueur,
				hauteur,
				largeur / 2,
				CFrame.new(x - largeur / 4, y, z) * CFrame.Angles(0, math.pi / 2, 0),
				couleur,
				materiau
			)
			pente(
				parent,
				nom,
				longueur,
				hauteur,
				largeur / 2,
				CFrame.new(x + largeur / 4, y, z) * CFrame.Angles(0, -math.pi / 2, 0),
				couleur,
				materiau
			)
		end
	end

	-- Repère sur un arc de cercle de centre (cx, cz) et de rayon r : angle 0 vers -Z depuis le centre, positif vers
	-- +X. L'axe Z local du repère pointe vers le centre (façade concave vue du centre, convexe vue de l'extérieur).
	local function surArc(cx, cz, r, angle, y)
		return CFrame.new(cx + r * math.sin(angle), y, cz - r * math.cos(angle)) * CFrame.Angles(0, -angle, 0)
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

	-- Maisons à pans de bois de la rue Saint-Michel (« rue de la Soif ») et du centre historique.
	-- Sources regardées : guide du Routard « rue Saint-Michel » (une trentaine de maisons à colombages des XVIe et
	-- XVIIe siècles), techno-science.net « Patrimoine architectural de Rennes » (286 maisons à pans de bois
	-- colorés), fiches Mérimée des maisons rennaises (encorbellement porté par des consoles à chaque niveau), photos
	-- de la rue Saint-Michel et de la place Sainte-Anne.
	-- Traits retenus : maisons étroites et serrées, pignon pointu sur rue, rez-de-chaussée en pierre (les bars),
	-- étages en encorbellement (chaque étage avance un peu sur celui du dessous, une sablière sombre marque chaque
	-- niveau), poteaux serrés, croix de Saint-André sous les fenêtres et décharges en biais, bois peints de couleurs
	-- franches (rouge sang-de-bœuf, vert, bleu, ocre) sur des hourdis clairs.
	local vitre = Color3.fromRGB(150, 200, 235)
	local granitRez = Color3.fromRGB(165, 160, 150)

	-- Un étage de pan de bois sur une face d'axe Z (normale `sens` = -1 ou +1, plan z = zFace), de x1 à x2 et de
	-- y1 à y2 : poteaux d'angle, fenêtre entre deux poteaux, croix de Saint-André dessous, décharges sur les côtés.
	local function panDeBois(parent, x1, x2, y1, y2, zFace, sens, bois, decharges)
		local h, xm = y2 - y1, (x1 + x2) / 2
		local zb = zFace + sens * 0.15
		local fw = math.min(2.8, (x2 - x1) * 0.34)
		local fy1, fy2 = y1 + h * 0.42, y1 + h * 0.86
		piece(parent, "Fenetre", fw, fy2 - fy1, 0.2, CFrame.new(xm, (fy1 + fy2) / 2, zFace + sens * 0.1), vitre)
		for _, xp in { x1 + 0.25, x2 - 0.25, xm - fw / 2 - 0.2, xm + fw / 2 + 0.2 } do
			piece(parent, "Poteau", 0.45, h, 0.3, CFrame.new(xp, (y1 + y2) / 2, zb), bois, Enum.Material.Wood)
		end
		-- Croix de Saint-André dans l'allège, sous la fenêtre.
		local cw, ch = fw, fy1 - y1 - 0.2
		local longueur, angle = math.sqrt(cw * cw + ch * ch), math.atan2(ch, cw)
		for _, s in { -1, 1 } do
			piece(
				parent,
				"Croix",
				longueur,
				0.35,
				0.3,
				CFrame.new(xm, y1 + 0.1 + ch / 2, zb) * CFrame.Angles(0, 0, s * angle),
				bois,
				Enum.Material.Wood
			)
		end
		if decharges then
			-- Une décharge en biais dans chaque panneau latéral, symétriques.
			local pw = (x2 - x1 - fw) / 2 - 0.65
			local l2, a2 = math.sqrt(pw * pw + h * h), math.atan2(h, pw)
			for _, s in { -1, 1 } do
				local xc = xm + s * (fw / 2 + 0.4 + pw / 2)
				piece(
					parent,
					"Decharge",
					l2,
					0.35,
					0.3,
					CFrame.new(xc, (y1 + y2) / 2, zb) * CFrame.Angles(0, 0, -s * a2),
					bois,
					Enum.Material.Wood
				)
			end
		end
	end

	-- Pignon pointu debout dans le plan z = zf : triangle de hourdis et ses deux rives de bois.
	local function pignon(parent, x, base, zf, largeur, hauteur, teinte, bois)
		deuxPans(parent, "Pignon", x, base, zf, 0.3, largeur, hauteur, false, teinte, Enum.Material.Plaster)
		local l, a = math.sqrt(hauteur * hauteur + largeur * largeur / 4), math.atan2(hauteur, largeur / 2)
		for _, s in { -1, 1 } do
			piece(
				parent,
				"Rive",
				l + 0.4,
				0.5,
				0.5,
				CFrame.new(x + s * largeur / 4, base + hauteur / 2, zf) * CFrame.Angles(0, 0, -s * a),
				bois,
				Enum.Material.Wood
			)
		end
		piece(
			parent,
			"Poinçon",
			0.4,
			hauteur * 0.8,
			0.4,
			CFrame.new(x, base + hauteur * 0.4, zf),
			bois,
			Enum.Material.Wood
		)
	end

	-- Maison du chemin : on marche sur sa dalle de toit (emprise inchangée : (largeur + 0.4)², dessus à `dessus`).
	-- Dessous, le corps (solide, comme avant) est fait d'étages en encorbellement : le rez est le plus étroit et
	-- chaque étage avance de 0,3 de chaque côté, le dernier fait exactement `largeur` sous la dalle. Pignons pointus
	-- fantômes sur les faces ±Z, hors de la trajectoire (on saute le long de X).
	local function maisonChemin(parent, nom, x, z, largeur, dessus, teinte, bois, avecPignons, enseigne)
		local toit =
			dalle(parent, "Toit", largeur + 0.4, largeur + 0.4, x, dessus, z, couleurs.toit, Enum.Material.Slate)
		local rez = SOL + 8
		local niveaux = math.max(3, math.floor((dessus - 1 - rez) / 6.4 + 0.5))
		local hEtage = (dessus - 1 - rez) / niveaux
		local d0 = largeur - 0.6 * niveaux
		decor(
			boite(
				parent,
				nom .. "Rez",
				x - d0 / 2,
				x + d0 / 2,
				SOL,
				rez,
				z - d0 / 2,
				z + d0 / 2,
				granitRez,
				Enum.Material.Granite
			)
		)
		for k = 1, niveaux do
			local d = largeur - 0.6 * (niveaux - k)
			local y1 = rez + (k - 1) * hEtage
			decor(
				boite(
					parent,
					nom .. "Etage",
					x - d / 2,
					x + d / 2,
					y1,
					y1 + hEtage,
					z - d / 2,
					z + d / 2,
					teinte,
					Enum.Material.Plaster
				)
			)
			fantome(
				boite(
					parent,
					"Sabliere",
					x - d / 2 - 0.15,
					x + d / 2 + 0.15,
					y1,
					y1 + 0.5,
					z - d / 2 - 0.15,
					z + d / 2 + 0.15,
					bois,
					Enum.Material.Wood
				)
			)
			for _, s in { -1, 1 } do
				panDeBois(parent, x - d / 2, x + d / 2, y1 + 0.5, y1 + hEtage, z + s * d / 2, s, bois, true)
			end
		end
		if avecPignons then
			for _, s in { -1, 1 } do
				pignon(parent, x, dessus - 1, z + s * (largeur / 2 + 0.45), largeur, 4.5, teinte, bois)
			end
		end
		if enseigne then
			local e = piece(
				parent,
				"EnseigneBar",
				d0 - 0.4,
				1.6,
				0.3,
				CFrame.new(x, rez - 1.6, z - d0 / 2 - 0.2),
				Color3.fromRGB(30, 25, 30)
			)
			texte(Enum.NormalId.Front, enseigne, accents.soif).Parent = e
		end
		return toit
	end

	-- Maison de décor (fantôme) dans les rangées de part et d'autre de la rue : façade vers le chemin (z = 0),
	-- étages en encorbellement vers la rue, pignon pointu sur rue et toit d'ardoise à deux pans.
	local function maisonDecor(parent, x, cote, largeur, etages, teinte, bois)
		local profondeur = 10
		local zDos = cote * (23 + profondeur) -- le dos est aligné, la façade avance étage par étage
		local zRue = cote * 23 -- plan de façade du dernier étage
		local rez, hEtage = SOL + 6.5, 5.6
		local function boiteZ(nom, x1, x2, y1, y2, zFace, coul, mat)
			local za, zb = math.min(zFace, zDos), math.max(zFace, zDos)
			return fantome(boite(parent, nom, x1, x2, y1, y2, za, zb, coul, mat))
		end
		local recul = 0.5 * etages
		boiteZ(
			"Rez",
			x - largeur / 2 + 0.3,
			x + largeur / 2 - 0.3,
			SOL,
			rez,
			zRue + cote * recul,
			granitRez,
			Enum.Material.Granite
		)
		piece(
			parent,
			"Vitrine",
			largeur - 2.4,
			3.6,
			0.2,
			CFrame.new(x, SOL + 2.4, zRue + cote * (recul - 0.1)),
			Color3.fromRGB(255, 205, 120),
			Enum.Material.Neon
		)
		for k = 1, etages do
			local zf = zRue + cote * 0.5 * (etages - k)
			local y1 = rez + (k - 1) * hEtage
			boiteZ("Etage", x - largeur / 2, x + largeur / 2, y1, y1 + hEtage, zf, teinte, Enum.Material.Plaster)
			boiteZ(
				"Sabliere",
				x - largeur / 2,
				x + largeur / 2,
				y1,
				y1 + 0.45,
				zf - cote * 0.15,
				bois,
				Enum.Material.Wood
			)
			panDeBois(parent, x - largeur / 2, x + largeur / 2, y1 + 0.45, y1 + hEtage, zf, -cote, bois, false)
		end
		local haut = rez + etages * hEtage
		local hToit = largeur * 0.62
		deuxPans(parent, "Toit", x, haut, (zRue + zDos) / 2, profondeur, largeur + 0.6, hToit, false, couleurs.toit)
		pignon(parent, x, haut, zRue - cote * 0.2, largeur + 0.4, hToit, teinte, bois)
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
		-- Trouées : l'Opéra (côté +Z, x 230 à 310), la cathédrale et les portes Mordelaises (côté -Z, x 430 à 520).
		if x < 230 or x > 310 then
			immeuble(ville, x, 80 + (i % 3) * 8, 30, 24, 30 + (i % 4) * 12, teintes[i % 4 + 1])
		end
		if x + 20 < 430 or x + 20 > 520 then
			immeuble(ville, x + 20, -85 - (i % 2) * 10, 26, 22, 26 + ((i + 1) % 4) * 14, teintes[(i + 2) % 4 + 1])
		end
	end

	-- Les Horizons (Georges Maillols, 1968-1970), en fond.
	-- Sources : fr.wikipedia « Les Horizons » (deux tours accolées, « tours siamoises » ou « épi de maïs », 30 étages
	-- habitables, 96 et 95 m, façades en éléments préfabriqués de béton blanc hauts d'un étage, deux niveaux
	-- techniques sur le toit, « blocs bleus » du projet de Maillols), architecturedecollection.fr (noyau elliptique,
	-- appartements rayonnant autour, formes biomorphiques inspirées de Marina City à Chicago), skyscrapercenter.com
	-- (99,5 m), photos.
	-- Traits retenus : deux tours rondes accolées de hauteur presque égale ; plan festonné (six lobes autour d'un
	-- noyau) ; un balcon filant blanc à chaque étage sur fond de vitrages sombres, ce qui donne l'« épi de maïs » ;
	-- édicule technique et blocs bleus sur le toit.
	do
		local zc, blanc = -140, Color3.fromRGB(250, 250, 248)
		local sombre, bleu = Color3.fromRGB(55, 75, 105), Color3.fromRGB(40, 110, 220)
		for _, t in { { x = 122, h = 118 }, { x = 146, h = 115 } } do
			cylindre(
				ville,
				"NoyauHorizons",
				t.h,
				18,
				CFrame.new(t.x, SOL + t.h / 2, zc) * DEBOUT,
				sombre,
				Enum.Material.Glass
			)
			for i = 0, 5 do
				local a = math.rad(30 + i * 60)
				cylindre(
					ville,
					"Lobe",
					t.h,
					9,
					CFrame.new(t.x + math.cos(a) * 7.5, SOL + t.h / 2, zc + math.sin(a) * 7.5) * DEBOUT,
					sombre,
					Enum.Material.Glass
				)
			end
			for k = 0, 30 do
				local balcon = cylindre(
					ville,
					"BalconFilant",
					0.8,
					26.5,
					CFrame.new(t.x, SOL + 5 + k * (t.h - 8) / 30, zc) * DEBOUT,
					blanc,
					Enum.Material.Concrete
				)
				balcon.CastShadow = false
			end
			cylindre(
				ville,
				"NiveauxTechniques",
				6,
				15,
				CFrame.new(t.x, SOL + t.h + 3, zc) * DEBOUT,
				blanc,
				Enum.Material.Concrete
			)
			piece(ville, "BlocBleu", 5, 5, 9, CFrame.new(t.x - 2.5, SOL + t.h + 8.5, zc), bleu, Enum.Material.Concrete)
			piece(
				ville,
				"BlocBleu",
				4,
				3,
				6,
				CFrame.new(t.x + 3, SOL + t.h + 7.5, zc + 1),
				bleu,
				Enum.Material.Concrete
			)
		end
		-- La jonction des deux tours (circulations) et le mât.
		fantome(boite(ville, "Jonction", 128, 140, SOL, SOL + 112, zc - 5, zc + 5, blanc, Enum.Material.Concrete))
		piece(
			ville,
			"Mat",
			0.6,
			12,
			0.6,
			CFrame.new(119, SOL + 135, zc),
			Color3.fromRGB(200, 200, 205),
			Enum.Material.Metal
		)
	end

	-- La cathédrale Saint-Pierre (façade occidentale, XVIIe-XIXe siècles), en fond derrière la rue de la Soif.
	-- Sources : cityzeum.com (façade de trois niveaux d'ordres dorique, ionique et corinthien, encadrée de deux
	-- tours carrées en granit), techno-science.net (tours de quatre niveaux, 48 m), plan France Relance (deux tours de
	-- 50 m), fiche PSS-archi, photos de la place Saint-Pierre.
	-- Traits retenus : façade plate en granit clair entre deux tours carrées plus hautes ; trois niveaux superposés,
	-- chacun rythmé de colonnes engagées et séparé par une corniche ; grande porte cintrée, baie cintrée, oculus,
	-- fronton triangulaire au sommet de la partie centrale ; tours à quatre niveaux couronnées d'une balustrade et
	-- d'une lanterne à dôme ; nef à toit d'ardoise derrière.
	do
		local x, zf = 480, -104 -- axe de la façade, plan de la façade centrale (elle regarde vers +Z, le chemin)
		local granit, clair = Color3.fromRGB(222, 205, 170), Color3.fromRGB(240, 228, 200)
		local ombre, ardoise = Color3.fromRGB(45, 40, 45), Color3.fromRGB(70, 85, 115)
		fantome(
			boite(ville, "FacadeCathedrale", x - 10, x + 10, SOL, SOL + 44, zf - 14, zf, granit, Enum.Material.Granite)
		)
		deuxPans(ville, "Fronton", x, SOL + 44, zf - 7, 14, 22, 6, false, granit, Enum.Material.Granite)
		local niveaux = {
			{ y1 = SOL, y2 = SOL + 15, colonnes = { -8, -5, 5, 8 } },
			{ y1 = SOL + 16, y2 = SOL + 30, colonnes = { -7, -4, 4, 7 } },
			{ y1 = SOL + 31, y2 = SOL + 43, colonnes = { -5, 5 } },
		}
		for _, n in niveaux do
			for _, dx in n.colonnes do
				cylindre(
					ville,
					"Colonne",
					n.y2 - n.y1,
					1.6,
					CFrame.new(x + dx, (n.y1 + n.y2) / 2, zf + 0.6) * DEBOUT,
					clair,
					Enum.Material.Limestone
				)
			end
			fantome(
				boite(
					ville,
					"Corniche",
					x - 11,
					x + 11,
					n.y2,
					n.y2 + 1,
					zf - 1,
					zf + 1.4,
					clair,
					Enum.Material.Limestone
				)
			)
		end
		-- Porte et baie cintrées (rectangle + demi-cercle), oculus au troisième niveau.
		for _, b in { { y1 = SOL, h = 9, l = 5 }, { y1 = SOL + 19, h = 6, l = 3.4 } } do
			piece(ville, "Baie", b.l, b.h, 0.3, CFrame.new(x, b.y1 + b.h / 2, zf + 0.1), ombre)
			cylindre(
				ville,
				"Cintre",
				0.3,
				b.l,
				CFrame.new(x, b.y1 + b.h, zf + 0.1) * CFrame.Angles(0, math.pi / 2, 0),
				ombre
			)
		end
		cylindre(
			ville,
			"Oculus",
			0.3,
			5,
			CFrame.new(x, SOL + 37, zf + 0.1) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(70, 110, 200),
			Enum.Material.Glass
		)
		for _, cote in { -1, 1 } do
			local tx = x + cote * 17
			fantome(
				boite(
					ville,
					"TourCathedrale",
					tx - 7,
					tx + 7,
					SOL,
					SOL + 66,
					zf - 15,
					zf + 1,
					granit,
					Enum.Material.Granite
				)
			)
			for _, y in { SOL + 15, SOL + 30, SOL + 44, SOL + 58 } do
				fantome(
					boite(
						ville,
						"Corniche",
						tx - 7.6,
						tx + 7.6,
						y,
						y + 1,
						zf - 15.6,
						zf + 1.6,
						clair,
						Enum.Material.Limestone
					)
				)
			end
			for i, y in { SOL, SOL + 16, SOL + 31, SOL + 45 } do
				local h = if i == 4 then 13 else if i == 1 then 15 else 14
				for _, dx in { -4.5, 4.5 } do
					cylindre(
						ville,
						"Colonne",
						h,
						1.4,
						CFrame.new(tx + dx, y + h / 2, zf + 1.6) * DEBOUT,
						clair,
						Enum.Material.Limestone
					)
				end
				if i > 1 then
					piece(ville, "Abat-son", 2.6, 6, 0.3, CFrame.new(tx, y + 6.5, zf + 1.1), ombre)
				end
			end
			fantome(
				boite(
					ville,
					"Balustrade",
					tx - 7.4,
					tx + 7.4,
					SOL + 66,
					SOL + 67.5,
					zf - 15.4,
					zf + 1.4,
					clair,
					Enum.Material.Limestone
				)
			)
			cylindre(
				ville,
				"Lanterne",
				6,
				6,
				CFrame.new(tx, SOL + 70.5, zf - 7) * DEBOUT,
				granit,
				Enum.Material.Granite
			)
			-- Dôme : boule dont la moitié basse est cachée dans la lanterne (une Ball reste ronde dans le moteur).
			boule(ville, "Dome", 6, tx, SOL + 73.5, zf - 7, ardoise, Enum.Material.Slate)
			boule(ville, "Epi", 1.2, tx, SOL + 77, zf - 7, couleurs.or_, Enum.Material.Metal)
		end
		fantome(boite(ville, "Nef", x - 13, x + 13, SOL, SOL + 34, zf - 66, zf - 14, granit, Enum.Material.Granite))
		deuxPans(ville, "ToitNef", x, SOL + 34, zf - 40, 52, 27, 10, false, ardoise)
	end

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
	-- Le palais du Commerce, décalé vers +X pour laisser la place à l'Opéra (en face de l'hôtel de ville).
	local palais = immeuble(cortege, 338, 48, 56, 20, 28, couleurs.pierre, true)
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
		-- Garde-corps vitré (fantôme) sur le bord extérieur du balcon, celui qui ne mène à aucun autre balcon.
		local dx, dz = pos[1] - CX, pos[2]
		local surX = math.abs(dx) > math.abs(dz)
		local gx = if surX then pos[1] + (if dx > 0 then 2.4 else -2.4) else pos[1]
		local gz = if surX then pos[2] else pos[2] + (if dz > 0 then 2.4 else -2.4)
		local verre = fantome(
			bloc(
				tour,
				"GardeCorps",
				if surX then 0.2 else 5,
				1.3,
				if surX then 5 else 0.2,
				gx,
				24 + 2.5 * i + 1.3,
				gz,
				Color3.fromRGB(170, 220, 240),
				Enum.Material.Glass
			)
		)
		verre.Transparency = 0.35
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
	-- La tour elle-même (fictive) : une tour d'habitation rennaise des années 1970, de la famille des Horizons
	-- (béton blanc, un nez de dalle à chaque étage entre les bandes de fenêtres, refends verticaux, édicule bleu sur le
	-- toit). Tout est fantôme et collé aux murs (0,4 de saillie) : les balcons de la spirale restent à 2,5 au moins.
	do
		local blanc, bleu = Color3.fromRGB(250, 248, 240), Color3.fromRGB(40, 110, 220)
		-- Sous l'appart, l'intérieur de la tour est fermé : un bandeau plein par étage.
		for y = 0, 60, 6 do
			fantome(
				boite(tour, "NezDeDalle", CX - 14.4, CX + 14.4, y - 0.6, y, -14.4, 14.4, blanc, Enum.Material.Concrete)
			)
		end
		-- À hauteur de l'appart, seulement sur les faces ±Z (les faces ±X ont les ouvertures).
		for _, y in { 66, 72 } do
			for _, s in { -1, 1 } do
				fantome(
					boite(
						tour,
						"NezDeDalle",
						CX - 14.4,
						CX + 14.4,
						y - 0.6,
						y,
						s * 14,
						s * 14.4,
						blanc,
						Enum.Material.Concrete
					)
				)
			end
		end
		for _, s in { -1, 1 } do
			for _, d in { -7, 7 } do
				fantome(
					boite(
						tour,
						"Refend",
						CX + d - 0.4,
						CX + d + 0.4,
						SOL,
						78,
						s * 14 - 0.4,
						s * 14 + 0.4,
						blanc,
						Enum.Material.Concrete
					)
				)
				fantome(
					boite(
						tour,
						"Refend",
						CX + s * 14 - 0.4,
						CX + s * 14 + 0.4,
						SOL,
						78,
						d * 1.3 - 0.4,
						d * 1.3 + 0.4,
						blanc,
						Enum.Material.Concrete
					)
				)
			end
		end
		-- Bandes de fenêtres des faces ±X (batiment() n'en pose que sur les faces ±Z), sous l'appart seulement.
		for y = SOL + 6, 56, 6 do
			for _, s in { -1, 1 } do
				local f = fantome(
					boite(
						tour,
						"Fenetres",
						CX + s * 14.05,
						CX + s * 14.25,
						y,
						y + 2,
						-12,
						12,
						vitre,
						Enum.Material.Glass
					)
				)
				f.CastShadow = false
			end
		end
		fantome(boite(tour, "Acrotere", CX - 14.4, CX + 14.4, 78, 79, -14.4, 14.4, blanc, Enum.Material.Concrete))
		fantome(boite(tour, "Edicule", CX - 6, CX + 4, 79, 84, -5, 5, bleu, Enum.Material.Concrete))
		local nomTour =
			fantome(boite(tour, "NomResidence", CX - 14.6, CX - 14.4, 79, 82, -10, 10, Color3.fromRGB(25, 25, 35)))
		texte(Enum.NormalId.Left, "RÉSIDENCE LE CRACHIN", accents.tour).Parent = nomTour
	end

	---------------------------------------------------------------------------------------------------------------
	-- 9-10 · Rue de la Soif : de toit en toit, puis on descend dans la rue par les auvents des bars.
	local soif = dossier("5_RueDeLaSoif", accents.soif)
	-- Teintes des hourdis et des bois (franches, comme rue Saint-Michel et rue du Chapitre).
	local hourdis = {
		Color3.fromRGB(250, 236, 205),
		Color3.fromRGB(245, 205, 130),
		Color3.fromRGB(245, 195, 185),
		Color3.fromRGB(252, 250, 242),
		Color3.fromRGB(205, 225, 245),
		Color3.fromRGB(250, 228, 140),
	}
	local bois = {
		Color3.fromRGB(150, 35, 40),
		Color3.fromRGB(95, 55, 35),
		Color3.fromRGB(35, 115, 75),
		Color3.fromRGB(40, 80, 160),
		Color3.fromRGB(205, 110, 35),
		Color3.fromRGB(120, 35, 85),
	}
	maisonChemin(soif, "Maison", 458, 0, 8, 31, hourdis[2], bois[1], true, "AR SKIBIDI")
	pilier(soif, "Cheminee", 2, 2, 466, 33, 0, Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	maisonChemin(soif, "Maison", 475, 0, 8, 30, hourdis[5], bois[4], true, "CHEZ GWENN")
	maisonChemin(soif, "Maison", 488, 0, 12, 27, hourdis[4], bois[3], false, "LE RATTRAPAGE")
	checkpoint(soif, 9, 488, 28, 0, "Rue de la Soif")
	dalle(soif, "Auvent", 4, 6, 499, 24, 0, Color3.fromRGB(200, 40, 60), Enum.Material.Fabric)
	dalle(soif, "Auvent", 4, 6, 505, 19, 0, Color3.fromRGB(40, 120, 200), Enum.Material.Fabric)
	dalle(soif, "Auvent", 4, 6, 511, 14, 0, Color3.fromRGB(240, 180, 40), Enum.Material.Fabric)
	dalle(soif, "Terrasse", 30, 10, 532, 10, 0, couleurs.bois, Enum.Material.WoodPlanks)
	tournant(bloc(soif, "EnseigneDeBar", 1.2, 2, 22, 532, 13, 0, Color3.fromRGB(220, 60, 140), Enum.Material.Neon), 1.6)
	checkpoint(soif, 10, 559, 10, 0, "Le dernier bar avant le partiel")
	-- Les rangées de maisons de part et d'autre de la rue, serrées, de largeurs et de couleurs variées ; côté -Z, une
	-- trouée (x 458 à 492) laisse voir les portes Mordelaises et la cathédrale.
	do
		local largeurs = { 9, 11, 8, 10, 12, 9, 10, 11 }
		local etages = { 3, 2, 3, 4, 2, 3, 3, 2 }
		for _, rangee in { { cote = 1, depart = 448, fin = 566 }, { cote = -1, depart = 430, fin = 566 } } do
			local x, i = rangee.depart, rangee.cote > 0 and 0 or 3
			while x + largeurs[i % #largeurs + 1] <= rangee.fin do
				local l = largeurs[i % #largeurs + 1]
				local cx = x + l / 2
				if rangee.cote > 0 or cx < 458 or cx > 492 then
					maisonDecor(
						soif,
						cx,
						rangee.cote,
						l,
						etages[i % #etages + 1],
						hourdis[i % #hourdis + 1],
						bois[(i * 5 + 2) % #bois + 1]
					)
				end
				x += l
				i += 1
			end
		end
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
	local tuffeau = Color3.fromRGB(250, 238, 205)
	local granitParlement = Color3.fromRGB(150, 150, 162)
	local ardoiseParlement = Color3.fromRGB(55, 68, 100)
	decor(boite(parlement, "Parlement", 685, 745, SOL, 40, -15, 15, tuffeau, Enum.Material.Limestone))
	local frontonParlement =
		fantome(boite(parlement, "Frise", 684.6, 685, 22, 25, -12, 12, tuffeau, Enum.Material.Limestone))
	texte(Enum.NormalId.Left, "PARLEMENT DE BRETAGNE", Color3.fromRGB(150, 120, 40), tuffeau).Parent = frontonParlement
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
		-- Vitre sur la face avant (fantôme, collée, sans rien au-dessus de la dalle où l'on marche).
		fantome(
			boite(
				parlement,
				"VitreLucarne",
				l[1] - 2.1,
				l[1] - 2,
				40.4,
				41.6,
				l[2] - 1,
				l[2] + 1,
				vitre,
				Enum.Material.Glass
			)
		)
	end
	decor(bloc(parlement, "Campanile", 8, 2, 8, 715, 41, 0, couleurs.pierre, Enum.Material.Marble))
	checkpoint(parlement, 13, 715, 42, 0, "Sur le toit du Parlement", 8)
	drapeauBreton(parlement, 743, 40, -14)
	drapeauBreton(parlement, 743, 40, 6)
	-- Le palais du Parlement de Bretagne (Germain Gaultier et Salomon de Brosse, 1618-1655).
	-- Sources : fr.wikipedia « Palais du parlement de Bretagne » (façade sud de sept travées entre deux pavillons
	-- saillants ; soubassement de granit à bossages ; étage de calcaire à pilastres doriques groupés par paires et
	-- hautes baies en plein cintre ; frise, corniche et balustrade ; avant-corps central à deux colonnes, tympan au
	-- cadran solaire et fronton arrondi ; fenêtres des pavillons sous frontons triangulaires ; grand comble d'ardoise à
	-- forte pente sans saillie ; galerie faîtière de plomb où alternent hermines et lys dorés ; quatre statues dorées
	-- aux extrémités du faîtage), lonelyplanet.fr et techno-science.net (granit, tuffeau blanc, ardoise bleue),
	-- universalis.fr (Salomon de Brosse), photos de la place du Parlement.
	-- Traits retenus : les deux grandes façades (±Z) et le pignon qu'on escalade (-X) reprennent cette composition ; le
	-- comble à la Mansart (brisis à environ 70° en ardoise, de l'égout à 26 jusqu'au bord du toit plat à 40) est porté
	-- par des ailes fantômes de 5 studs de part et d'autre du corps : le toit plat mortel où l'on court (« terrasse
	-- faîtière » d'ardoise glissante), ses lucarnes, la gouttière et les corniches gardent leur emprise. Les ailes et
	-- le brisis sont fantômes : qui tombe du toit les traverse et finit dans le vide, comme avant.
	do
		local ombre = Color3.fromRGB(45, 45, 55)
		local plomb = Color3.fromRGB(85, 92, 110)
		local clair = Color3.fromRGB(255, 248, 228)
		local function zr(s, a, b) -- bornes z de a à b, du côté s (-1 ou +1)
			return math.min(s * a, s * b), math.max(s * a, s * b)
		end
		local VERS_Z = CFrame.Angles(0, math.pi / 2, 0) -- cylindre (axe X) tourné pour avoir son axe le long de Z
		for _, s in { -1, 1 } do
			local za, zb = zr(s, 15, 20)
			fantome(boite(parlement, "Aile", 685, 745, SOL, 26, za, zb, tuffeau, Enum.Material.Limestone))
			za, zb = zr(s, 19.9, 20.3)
			fantome(boite(parlement, "Soubassement", 685, 745, SOL, 4, za, zb, granitParlement, Enum.Material.Granite))
			za, zb = zr(s, 20.3, 20.4)
			for _, y in { -5, -1, 3 } do
				fantome(boite(parlement, "Bossage", 685, 745, y - 0.25, y, za, zb, ombre))
			end
			-- Pavillons d'extrémité, en saillie.
			for _, px in { { 685, 697 }, { 733, 745 } } do
				za, zb = zr(s, 20, 21.2)
				fantome(boite(parlement, "Pavillon", px[1], px[2], 4, 27, za, zb, tuffeau, Enum.Material.Limestone))
				za, zb = zr(s, 20, 21.4)
				fantome(
					boite(
						parlement,
						"SoubassementPavillon",
						px[1],
						px[2],
						SOL,
						4,
						za,
						zb,
						granitParlement,
						Enum.Material.Granite
					)
				)
				for _, wx in { px[1] + 3.5, px[2] - 3.5 } do
					piece(parlement, "Fenetre", 2.2, 9, 0.2, CFrame.new(wx, 12.5, s * 21.3), vitre, Enum.Material.Glass)
					deuxPans(
						parlement,
						"FrontonFenetre",
						wx,
						17.4,
						s * 21.35,
						0.3,
						3.4,
						1.4,
						false,
						clair,
						Enum.Material.Limestone
					)
					piece(
						parlement,
						"FenetreBasse",
						2,
						5,
						0.2,
						CFrame.new(wx, -2, s * 21.5),
						vitre,
						Enum.Material.Glass
					)
				end
			end
			-- Sept travées entre les pavillons, rythmées de pilastres jumelés.
			local travee = 36 / 7
			for j = 0, 7 do
				for _, d in { -0.45, 0.45 } do
					piece(
						parlement,
						"Pilastre",
						0.55,
						18,
						0.35,
						CFrame.new(697 + j * travee + d, 13, s * 20.17),
						clair,
						Enum.Material.Limestone
					)
				end
			end
			for i = 1, 7 do
				local xb = 697 + (i - 0.5) * travee
				local zv = 20.1
				if i == 4 then
					zv = 21.1
					za, zb = zr(s, 20, 21)
					fantome(
						boite(
							parlement,
							"AvantCorps",
							xb - 3,
							xb + 3,
							SOL,
							27,
							za,
							zb,
							tuffeau,
							Enum.Material.Limestone
						)
					)
					for _, d in { -2.2, 2.2 } do
						cylindre(
							parlement,
							"Colonne",
							18,
							1.1,
							CFrame.new(xb + d, 13, s * 21.6) * DEBOUT,
							clair,
							Enum.Material.Limestone
						)
					end
					cylindre(
						parlement,
						"FrontonCintre",
						0.6,
						7,
						CFrame.new(xb, 27, s * 20.8) * VERS_Z,
						tuffeau,
						Enum.Material.Limestone
					)
					cylindre(
						parlement,
						"CadranSolaire",
						0.3,
						2.4,
						CFrame.new(xb, 28, s * 21.2) * VERS_Z,
						couleurs.or_,
						Enum.Material.Metal
					)
					piece(
						parlement,
						"Porte",
						3,
						7,
						0.2,
						CFrame.new(xb, SOL + 3.5, s * 21.1),
						Color3.fromRGB(70, 40, 30),
						Enum.Material.Wood
					)
				else
					piece(
						parlement,
						"FenetreBasse",
						2.2,
						5,
						0.2,
						CFrame.new(xb, -2, s * 20.4),
						vitre,
						Enum.Material.Glass
					)
				end
				piece(parlement, "Baie", 2.4, 8, 0.2, CFrame.new(xb, 12, s * zv), vitre, Enum.Material.Glass)
				cylindre(parlement, "Cintre", 0.2, 2.4, CFrame.new(xb, 16, s * zv) * VERS_Z, vitre, Enum.Material.Glass)
			end
			-- Entablement : frise, corniche, balustrade au pied du comble.
			za, zb = zr(s, 20, 20.35)
			fantome(boite(parlement, "Frise", 685, 745, 22, 24, za, zb, tuffeau, Enum.Material.Limestone))
			za, zb = zr(s, 20, 20.8)
			fantome(boite(parlement, "Entablement", 684.4, 745.6, 24, 25, za, zb, clair, Enum.Material.Limestone))
			za, zb = zr(s, 20.1, 20.5)
			fantome(boite(parlement, "Balustrade", 685, 745, 25, 26.6, za, zb, clair, Enum.Material.Limestone))
			-- Le brisis d'ardoise, de l'égout (z = ±20, y = 26) au bord du toit plat (z = ±15, y = 40).
			pente(
				parlement,
				"Comble",
				60,
				14,
				5,
				CFrame.new(715, 33, s * 17.5) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
				ardoiseParlement,
				Enum.Material.Slate
			)
			for _, lx in { 693, 703, 727, 737 } do
				za, zb = zr(s, 16, 19.1)
				fantome(
					boite(
						parlement,
						"LucarneToit",
						lx - 1.3,
						lx + 1.3,
						29,
						33,
						za,
						zb,
						tuffeau,
						Enum.Material.Limestone
					)
				)
				piece(
					parlement,
					"VitreLucarne",
					1.6,
					2.8,
					0.2,
					CFrame.new(lx, 31, s * 19.15),
					vitre,
					Enum.Material.Glass
				)
				deuxPans(parlement, "ToitLucarne", lx, 33, s * 17.6, 3.4, 3, 1.6, false, ardoiseParlement)
			end
			-- Galerie faîtière de plomb, hermines et lys dorés, statues dorées aux extrémités.
			za, zb = zr(s, 14.9, 15.3)
			fantome(boite(parlement, "GalerieFaitiere", 690, 745, 40.6, 41.5, za, zb, plomb, Enum.Material.Metal))
			for k = 0, 5 do
				boule(
					parlement,
					if k % 2 == 0 then "Hermine" else "Lys",
					0.9,
					694 + k * 8.5,
					41.9,
					s * 15.1,
					couleurs.or_,
					Enum.Material.Metal
				)
			end
			for _, sx in { 690.8, 744.6 } do
				cylindre(
					parlement,
					"Statue",
					2.2,
					0.8,
					CFrame.new(sx, 42.6, s * 15.1) * DEBOUT,
					couleurs.or_,
					Enum.Material.Metal
				)
				boule(parlement, "TeteStatue", 0.8, sx, 44, s * 15.1, couleurs.or_, Enum.Material.Metal)
			end
		end
		-- La face -X, qu'on escalade : même composition en relief fantôme (0,8 au plus devant x = 685).
		fantome(boite(parlement, "Soubassement", 684.7, 685, SOL, 4, -20, 20, granitParlement, Enum.Material.Granite))
		for _, y in { -5, -1, 3 } do
			fantome(boite(parlement, "Bossage", 684.6, 684.7, y - 0.25, y, -20, 20, ombre))
		end
		for _, zp in { -15, -6, 6, 15 } do
			for _, d in { -0.45, 0.45 } do
				piece(
					parlement,
					"Pilastre",
					0.35,
					18,
					0.55,
					CFrame.new(684.83, 13, zp + d),
					clair,
					Enum.Material.Limestone
				)
			end
		end
		for _, zb in { -10.5, 0, 10.5 } do
			piece(parlement, "Baie", 0.2, 8, 2.4, CFrame.new(684.9, 12, zb), vitre, Enum.Material.Glass)
			cylindre(parlement, "Cintre", 0.2, 2.4, CFrame.new(684.9, 16, zb), vitre, Enum.Material.Glass)
			piece(parlement, "FenetreBasse", 0.2, 5, 2.2, CFrame.new(684.6, -2, zb), vitre, Enum.Material.Glass)
		end
		for _, s in { -1, 1 } do
			piece(parlement, "Baie", 0.2, 8, 2.2, CFrame.new(684.9, 12, s * 17.5), vitre, Enum.Material.Glass)
			cylindre(
				parlement,
				"Colonne",
				18,
				1.1,
				CFrame.new(684.4, 13, s * 2.6) * DEBOUT,
				clair,
				Enum.Material.Limestone
			)
			piece(parlement, "BaieAttique", 0.2, 5, 2.4, CFrame.new(684.9, 31, s * 10.5), vitre, Enum.Material.Glass)
		end
		fantome(boite(parlement, "Entablement", 684.2, 685, 25, 26, -20.8, 20.8, clair, Enum.Material.Limestone))
		cylindre(parlement, "FrontonCintre", 0.4, 8, CFrame.new(684.8, 34, 0), tuffeau, Enum.Material.Limestone)
		cylindre(parlement, "CadranSolaire", 0.2, 2.6, CFrame.new(684.6, 35, 0), couleurs.or_, Enum.Material.Metal)
	end

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
	affiche(
		"PARCOURSUP : ACCEPTÉ\nRennes, ville de la bruine et de l'aura",
		268,
		22,
		1,
		blanc,
		Color3.fromRGB(30, 80, 170)
	)
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
		"TRANSMUSICALES\ncomplet · les bouchons d'oreilles aussi",
		510, -- hors de la trouée qui montre les portes Mordelaises et la cathédrale
		36,
		-1,
		Color3.fromRGB(20, 20, 30),
		Color3.fromRGB(255, 70, 180)
	)
	affiche("SKIBIDI PARTIEL\n8 h · amphi B · pas de rattrapage", 520, 16, 1, Color3.fromRGB(255, 220, 40), noir)
	affiche("IL NE PLEUT PAS À RENNES\nil bruine.", 575, 12, -1, Color3.fromRGB(120, 140, 160), blanc)
	affiche("BAIGNADE INTERDITE\n(sauf si tu rates le saut)", 605, 12, 1, Color3.fromRGB(40, 150, 230), blanc)
	affiche("KOUIGN-AMANN\n0 % de beurre doux, 100 % de bonheur", 660, 26, -1, Color3.fromRGB(230, 170, 70), noir)
	affiche("POV : t'arrives à l'heure\naura infinie débloquée", 770, 30, 1, Color3.fromRGB(150, 90, 255), blanc)
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

	-- L'hôtel de ville (Jacques V Gabriel, 1734-1743), place de la Mairie, face au chemin.
	-- Sources : pss-archi.eu (fiche FR-35238-2473), routard.com et techno-science.net « Mairie de Rennes » (plan de
	-- 1730 : le présidial et l'hôtel de ville de part et d'autre d'une tour de l'horloge, reliés à elle par deux ailes
	-- concaves ; la courbe répond à la façade arrondie de l'Opéra en face ; la tour abritait le beffroi), Wikipedia
	-- « Rennes City Hall », photos de la place de la Mairie.
	-- Traits retenus : tour centrale carrée en saillie, porte cintrée, horloge (toujours 8:00, l'heure du partiel),
	-- campanile ouvert avec sa cloche, dôme d'ardoise, lanternon et épi doré ; deux ailes en arc de cercle concave
	-- (centre de courbure côté place) à deux niveaux de fenêtres et toit d'ardoise ; deux pavillons d'extrémité à
	-- fronton triangulaire.
	do
		local x, zf = 270, -50 -- axe et plan de la façade (elle regarde vers +Z, le chemin)
		local pierre, clair = Color3.fromRGB(242, 222, 180), Color3.fromRGB(253, 243, 218)
		local ardoise, ombre = Color3.fromRGB(65, 80, 112), Color3.fromRGB(45, 42, 52)
		local R = 40
		local cz = zf + R -- centre de courbure devant la façade, côté place : les ailes sont concaves
		local VERS_Z = CFrame.Angles(0, math.pi / 2, 0)
		for _, s in { -1, 1 } do
			for k = 0, 4 do
				local a = s * math.rad(9 + k * 6.4)
				-- Dans le repère de surArc, +Z regarde la place : le mur s'étend derrière la façade (vers -Z local).
				piece(
					refs,
					"Aile",
					5.6, -- assez large pour fermer l'arc au dos du mur (rayon 52)
					22,
					12,
					surArc(x, cz, R, a, SOL + 11) * CFrame.new(0, 0, -6),
					pierre,
					Enum.Material.Limestone
				)
				piece(refs, "Fenetre", 2, 4.5, 0.2, surArc(x, cz, R - 0.1, a, SOL + 6.5), vitre, Enum.Material.Glass)
				piece(refs, "Fenetre", 2, 5, 0.2, surArc(x, cz, R - 0.1, a, SOL + 15), vitre, Enum.Material.Glass)
				pente(
					refs,
					"Toit",
					5.9,
					5,
					12,
					surArc(x, cz, R, a, SOL + 24.5) * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.pi, 0),
					ardoise,
					Enum.Material.Slate
				)
			end
			-- Pavillon d'extrémité (hôtel de ville d'un côté, présidial de l'autre).
			local a = s * math.rad(43.5)
			piece(
				refs,
				"Pavillon",
				10,
				26,
				14,
				surArc(x, cz, R, a, SOL + 13) * CFrame.new(0, 0, -7),
				pierre,
				Enum.Material.Limestone
			)
			local toit = surArc(x, cz, R, a, SOL + 29) * CFrame.new(0, 0, -7)
			pente(
				refs,
				"Toit",
				10,
				6,
				7,
				toit * CFrame.new(0, 0, 3.5) * CFrame.Angles(0, math.pi, 0),
				ardoise,
				Enum.Material.Slate
			)
			pente(refs, "Toit", 10, 6, 7, toit * CFrame.new(0, 0, -3.5), ardoise, Enum.Material.Slate)
			local fronton = surArc(x, cz, R - 0.25, a, SOL + 23.5)
			pente(
				refs,
				"Fronton",
				0.3,
				3,
				4,
				fronton * CFrame.new(-2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
				clair,
				Enum.Material.Limestone
			)
			pente(
				refs,
				"Fronton",
				0.3,
				3,
				4,
				fronton * CFrame.new(2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
				clair,
				Enum.Material.Limestone
			)
			piece(refs, "Fenetre", 2.2, 5, 0.2, surArc(x, cz, R - 0.1, a, SOL + 7), vitre, Enum.Material.Glass)
			piece(refs, "Fenetre", 2.2, 6, 0.2, surArc(x, cz, R - 0.1, a, SOL + 16), vitre, Enum.Material.Glass)
		end
		-- La tour de l'horloge et son beffroi.
		fantome(
			boite(refs, "TourHorloge", x - 5, x + 5, SOL, SOL + 32, zf - 9, zf + 1, pierre, Enum.Material.Limestone)
		)
		for _, y in { SOL + 22, SOL + 32 } do
			fantome(
				boite(refs, "Corniche", x - 5.6, x + 5.6, y, y + 1, zf - 9.6, zf + 1.6, clair, Enum.Material.Limestone)
			)
		end
		piece(refs, "Porte", 3.6, 7, 0.2, CFrame.new(x, SOL + 3.5, zf + 1.1), ombre)
		cylindre(refs, "Cintre", 0.2, 3.6, CFrame.new(x, SOL + 7, zf + 1.1) * VERS_Z, ombre)
		local nom = piece(refs, "Fronton", 9, 2.4, 0.3, CFrame.new(x, SOL + 19, zf + 1.2), clair)
		texte(Enum.NormalId.Back, "HÔTEL DE VILLE", Color3.fromRGB(90, 70, 40), clair).Parent = nom
		local horloge =
			piece(refs, "Horloge", 5, 5, 0.3, CFrame.new(x, SOL + 27.5, zf + 1.2), Color3.fromRGB(255, 250, 235))
		texte(Enum.NormalId.Back, "8:00", Color3.fromRGB(30, 30, 40), Color3.fromRGB(255, 250, 235)).Parent = horloge
		for _, dx in { -3.4, 3.4 } do
			for _, dz in { -3.4, 3.4 } do
				piece(
					refs,
					"PilierCampanile",
					1.2,
					6,
					1.2,
					CFrame.new(x + dx, SOL + 36, zf - 4 + dz),
					clair,
					Enum.Material.Limestone
				)
			end
		end
		boule(refs, "Cloche", 3.2, x, SOL + 36, zf - 4, couleurs.or_, Enum.Material.Metal)
		-- Dôme : tambour, puis une boule à moitié enfoncée dedans (une Ball reste ronde dans le moteur).
		cylindre(refs, "Tambour", 3, 8.4, CFrame.new(x, SOL + 40.5, zf - 4) * DEBOUT, clair, Enum.Material.Limestone)
		boule(refs, "Dome", 8, x, SOL + 42, zf - 4, ardoise, Enum.Material.Slate)
		cylindre(refs, "Lanternon", 3, 2.4, CFrame.new(x, SOL + 47, zf - 4) * DEBOUT, clair, Enum.Material.Limestone)
		boule(refs, "Epi", 1.2, x, SOL + 49.1, zf - 4, couleurs.or_, Enum.Material.Metal)
	end

	-- L'Opéra (Charles Millardet, 1836), en face de l'hôtel de ville, de l'autre côté du chemin.
	-- Sources : routard.com et guide-tourisme-france.com (façade arrondie de l'Opéra, à laquelle répond la courbe de
	-- l'hôtel de ville), techno-science.net (façade couronnée d'Apollon et des neuf Muses), photos de la place de la
	-- Mairie.
	-- Traits retenus : rotonde convexe qui avance vers la place ; rez-de-chaussée en arcades ; étage de fenêtres
	-- séparées par des colonnes engagées ; corniche et attique ; dix statues (Apollon et les neuf Muses) sur
	-- l'attique ; salle rectangulaire à toit d'ardoise derrière.
	do
		local x, cz, R = 270, 68, 18 -- centre de la rotonde derrière la façade : elle avance jusqu'à z = 50
		local pierre, clair = Color3.fromRGB(246, 220, 172), Color3.fromRGB(255, 244, 220)
		local ombre, ardoise = Color3.fromRGB(45, 40, 52), Color3.fromRGB(65, 80, 112)
		fantome(boite(refs, "Salle", x - 20, x + 20, SOL, SOL + 28, cz, cz + 32, pierre, Enum.Material.Limestone))
		deuxPans(refs, "ToitSalle", x, SOL + 28, cz + 16, 32, 41, 6, false, ardoise)
		cylindre(refs, "Rotonde", 24, 2 * R, CFrame.new(x, SOL + 12, cz) * DEBOUT, pierre, Enum.Material.Limestone)
		cylindre(
			refs,
			"Bandeau",
			0.8,
			2 * R + 1.2,
			CFrame.new(x, SOL + 9.6, cz) * DEBOUT,
			clair,
			Enum.Material.Limestone
		)
		cylindre(
			refs,
			"Corniche",
			1,
			2 * R + 1.6,
			CFrame.new(x, SOL + 20.5, cz) * DEBOUT,
			clair,
			Enum.Material.Limestone
		)
		cylindre(
			refs,
			"Attique",
			3,
			2 * R - 0.6,
			CFrame.new(x, SOL + 25.5, cz) * DEBOUT,
			clair,
			Enum.Material.Limestone
		)
		for k = -3, 3 do
			local a = math.rad(k * 15)
			piece(refs, "Arcade", 3, 5.5, 0.3, surArc(x, cz, R + 0.1, a, SOL + 2.75), ombre)
			cylindre(
				refs,
				"Cintre",
				0.3,
				3,
				surArc(x, cz, R + 0.1, a, SOL + 5.5) * CFrame.Angles(0, math.pi / 2, 0),
				ombre
			)
			piece(refs, "Fenetre", 2.4, 6, 0.3, surArc(x, cz, R + 0.1, a, SOL + 14.5), vitre, Enum.Material.Glass)
		end
		for k = -3.5, 3.5 do
			cylindre(
				refs,
				"Colonne",
				10,
				1.3,
				surArc(x, cz, R + 0.5, math.rad(k * 15), SOL + 15) * DEBOUT,
				clair,
				Enum.Material.Limestone
			)
		end
		for k = -4.5, 4.5 do
			local cf = surArc(x, cz, R - 1.5, math.rad(k * 12), SOL + 28.3)
			cylindre(refs, "Muse", 2.6, 1, cf * DEBOUT, clair, Enum.Material.Marble)
			boule(refs, "TeteMuse", 0.9, cf.Position.X, SOL + 30, cf.Position.Z, clair, Enum.Material.Marble)
		end
		local enseigne =
			piece(refs, "Enseigne", 9, 1.6, 0.3, surArc(x, cz, R + 0.9, 0, SOL + 22.2), Color3.fromRGB(30, 25, 35))
		texte(Enum.NormalId.Front, "OPÉRA", Color3.fromRGB(255, 215, 120)).Parent = enseigne
	end

	-- Les portes Mordelaises (reconstruites vers 1440), l'ancienne entrée de la ville close.
	-- Sources : pop.culture.gouv.fr (notice Mérimée PA00090753), techno-science.net « Porte Mordelaise », unidivers.fr
	-- et routard.com (châtelet à deux tours en granit, porte charretière et porte piétonne, mâchicoulis au sommet des
	-- tours, pont-levis remis en place, vestiges de barbacane), photos.
	-- Traits retenus : deux grosses tours rondes de granit, galerie de mâchicoulis sur corbeaux et créneaux ;
	-- châtelet entre les tours avec sa propre galerie ; grande porte et petite porte en arc brisé ; pont-levis abaissé
	-- et ses chaînes ; meurtrières ; courtines du rempart de part et d'autre.
	do
		local x, z = 470, -48
		local granit, sombre = Color3.fromRGB(165, 155, 142), Color3.fromRGB(35, 30, 35)
		for _, dx in { -9, 9 } do
			local tx = x + dx
			cylindre(
				refs,
				"TourMordelaise",
				24,
				10,
				CFrame.new(tx, SOL + 12, z) * DEBOUT,
				granit,
				Enum.Material.Granite
			)
			cylindre(refs, "Machicoulis", 4, 12, CFrame.new(tx, SOL + 26, z) * DEBOUT, granit, Enum.Material.Granite)
			for i = 0, 7 do
				local a = math.rad(i * 45 + 22.5)
				local function autour(r, y)
					return CFrame.new(tx + math.sin(a) * r, y, z - math.cos(a) * r) * CFrame.Angles(0, -a, 0)
				end
				piece(refs, "Corbeau", 0.8, 2, 1, autour(5.4, SOL + 23), granit, Enum.Material.Granite)
				piece(refs, "Merlon", 1.8, 2, 1, autour(5.5, SOL + 29), granit, Enum.Material.Granite)
			end
			for _, y in { SOL + 9, SOL + 16 } do
				piece(refs, "Meurtriere", 0.5, 2.6, 0.3, CFrame.new(tx, y, z + 5.05), sombre)
			end
		end
		fantome(boite(refs, "Chatelet", x - 4.5, x + 4.5, SOL, SOL + 22, z - 4, z + 4, granit, Enum.Material.Granite))
		fantome(
			boite(
				refs,
				"Machicoulis",
				x - 4.5,
				x + 4.5,
				SOL + 20,
				SOL + 24,
				z + 4,
				z + 5.2,
				granit,
				Enum.Material.Granite
			)
		)
		for _, dx in { -3, 0, 3 } do
			piece(refs, "Merlon", 1.6, 2, 1, CFrame.new(x + dx, SOL + 25, z + 4.6), granit, Enum.Material.Granite)
		end
		piece(refs, "PorteCharretiere", 4.4, 7, 0.3, CFrame.new(x - 1.2, SOL + 3.5, z + 4.05), sombre)
		deuxPans(refs, "Ogive", x - 1.2, SOL + 7, z + 4.05, 0.3, 4.4, 2.4, false, sombre, Enum.Material.SmoothPlastic)
		piece(refs, "PortePietonne", 1.8, 4.4, 0.3, CFrame.new(x + 2.6, SOL + 2.2, z + 4.05), sombre)
		deuxPans(refs, "Ogive", x + 2.6, SOL + 4.4, z + 4.05, 0.3, 1.8, 1.1, false, sombre, Enum.Material.SmoothPlastic)
		fantome(
			boite(
				refs,
				"PontLevis",
				x - 3.4,
				x + 1,
				SOL + 0.3,
				SOL + 0.8,
				z + 4.2,
				z + 11,
				Color3.fromRGB(125, 85, 50),
				Enum.Material.WoodPlanks
			)
		)
		local longueurChaine = math.sqrt(13 * 13 + 6.5 * 6.5)
		for _, cx in { x - 3, x + 0.6 } do
			piece(
				refs,
				"Chaine",
				0.25,
				longueurChaine,
				0.25,
				CFrame.new(cx, SOL + 7.3, z + 7.75) * CFrame.Angles(-math.atan2(6.5, 13), 0, 0),
				sombre,
				Enum.Material.Metal
			)
		end
		for _, r in { { x - 32, x - 14 }, { x + 14, x + 32 } } do
			fantome(boite(refs, "Courtine", r[1], r[2], SOL, SOL + 15, z - 4, z + 3, granit, Enum.Material.Granite))
			for mx = r[1] + 1.5, r[2] - 1, 4 do
				piece(refs, "Merlon", 1.6, 2, 1, CFrame.new(mx, SOL + 16, z + 2.5), granit, Enum.Material.Granite)
			end
		end
		local plaque =
			piece(refs, "Plaque", 7, 1.4, 0.3, CFrame.new(x, SOL + 12, z + 4.2), Color3.fromRGB(110, 100, 90))
		texte(Enum.NormalId.Back, "PORTES MORDELAISES", Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 100, 90)).Parent =
			plaque
	end

	-- Les Champs Libres (Christian de Portzamparc, 2006), au bord de la Vilaine.
	-- Sources : fr.wikipedia « Les Champs Libres » (trois volumes lisibles de l'extérieur : bibliothèque en pyramide
	-- inversée de verre, Musée de Bretagne à l'étage dans une forme qui évoque un dolmen, dôme de zinc du planétarium
	-- de l'Espace des sciences ; grands panneaux roses au relief fissuré, joints droits ou obliques, teinte du schiste
	-- rose d'Ille-et-Vilaine), viamichelin (barre horizontale sur pilotis), pss-archi.eu (40 m, R+6), photos.
	-- Traits retenus : longue barre rose du musée posée sur quelques piles, en porte-à-faux au-dessus du hall vitré ;
	-- bibliothèque en pyramide inversée de verre, plus large en haut, étage par étage ; sphère de zinc du planétarium
	-- à demi enfoncée dans le bout de la barre ; joints obliques sur la façade rose.
	do
		local x, z = 592, -56
		local rose, zinc = Color3.fromRGB(222, 128, 122), Color3.fromRGB(150, 162, 182)
		local verre = Color3.fromRGB(120, 178, 220)
		fantome(
			boite(
				refs,
				"MuseeDeBretagne",
				x - 10,
				x + 34,
				SOL + 13,
				SOL + 25,
				z - 11,
				z + 11,
				rose,
				Enum.Material.Slate
			)
		)
		for _, px in { x - 4, x + 14 } do
			for _, pz in { -7, 7 } do
				fantome(
					boite(
						refs,
						"Pile",
						px - 1.5,
						px + 1.5,
						SOL,
						SOL + 13,
						z + pz - 1.5,
						z + pz + 1.5,
						rose,
						Enum.Material.Slate
					)
				)
			end
		end
		fantome(boite(refs, "Hall", x - 8, x + 18, SOL, SOL + 8, z - 8, z + 8, verre, Enum.Material.Glass))
		for _, j in { { 2, 0 }, { 10, 25 }, { 18, -20 }, { 26, 15 } } do
			piece(
				refs,
				"Joint",
				0.3,
				12.4,
				0.2,
				CFrame.new(x + j[1], SOL + 19, z + 11.05) * CFrame.Angles(0, 0, math.rad(j[2])),
				Color3.fromRGB(150, 78, 78)
			)
		end
		for k = 0, 5 do
			local c = 9 + k * 2.6
			local bx = x - 22
			fantome(
				boite(
					refs,
					"Bibliotheque",
					bx - c / 2,
					bx + c / 2,
					SOL + k * 5,
					SOL + k * 5 + 5,
					z - c / 2,
					z + c / 2,
					verre,
					Enum.Material.Glass
				)
			)
			fantome(
				boite(
					refs,
					"Plancher",
					bx - c / 2 - 0.1,
					bx + c / 2 + 0.1,
					SOL + k * 5 + 4.6,
					SOL + k * 5 + 5,
					z - c / 2 - 0.1,
					z + c / 2 + 0.1,
					Color3.fromRGB(235, 235, 240),
					Enum.Material.Concrete
				)
			)
		end
		boule(refs, "Planetarium", 17, x + 26, SOL + 27, z, zinc, Enum.Material.Metal)
		local enseigne =
			piece(refs, "Enseigne", 20, 2.4, 0.3, CFrame.new(x + 8, SOL + 21.5, z + 11.2), Color3.fromRGB(25, 25, 35))
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

	calibrerSurfaces(parcours)
	return parcours
end
