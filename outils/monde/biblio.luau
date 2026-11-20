-- Bibliothèque commune des générateurs de carte (outils/monde/<Nom>.luau) : le code partagé n'existe qu'une fois.
-- outils/monde/generer.luau la construit et la passe en second argument : `return function(R, biblio) … end`.
--   - outils de construction (bloc, boite, dalle, pilier, decor, fantome, brut, piece, boule, cylindre, pente,
--     contour), textes (texte, etiquette, tableau, calibrerSurfaces ; règle de taille dans biblio/texte.luau) ;
--   - palettes : `couleurs` (matières et objets) et `accents` (une couleur par zone du parcours) ;
--   - `parcours` : la source unique des checkpoints et de Sup de Vinci (donnees/parcours.luau) ;
--   - `Reglages` : src/partage/Reglages.luau (constantes de saut des contrôles, NB_ETAPES…).
-- Aucun tirage aléatoire ici : chaque générateur garde sa graine et l'ordre de ses tirages.
local Texte = require("./biblio/texte")
local donnees = require("./donnees/parcours")
local Reglages = require("./physique").Reglages

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local ajusterTexte, reglerTexte, TAILLE_MAX = Texte.ajusterTexte, Texte.reglerTexte, Texte.TAILLE_MAX

	local B = {}
	B.Reglages = Reglages
	B.parcours = donnees
	B.texteRegle = Texte

	B.SOL = -10 -- dessus du sol de la ville (décor) ; la zone mortelle du parcours est juste au-dessus, en -4
	local SOL = B.SOL

	-- Direction artistique (règles de genre des obbys qui marchent, adaptées à Rennes) : ce qui se marche est saturé
	-- et cerné de la couleur de sa zone, le décor est en teintes douces ; une couleur par zone (`accents`).
	B.couleurs = {
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
		acier = Color3.fromRGB(120, 128, 140),
		galette = Color3.fromRGB(205, 160, 95),
		saucisse = Color3.fromRGB(175, 85, 60),
		bus = Color3.fromRGB(235, 235, 240),
	}
	B.accents = {
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
	-- Outils de construction. Tout est ancré et placé par CFrame (jamais par Position : non enregistrée dans le .rbxm).

	-- Bloc ancré. `dessus` est la hauteur de sa face supérieure : on raisonne en « où pose-t-on les pieds ».
	function B.bloc(parent, nom: string, sx, sy, sz, x, dessus, z, couleur, materiau)
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
	local bloc = B.bloc

	-- Bloc donné par ses bornes (x1..x2, y1..y2, z1..z2) : pratique pour les murs et les planchers.
	function B.boite(parent, nom: string, x1, x2, y1, y2, z1, z2, couleur, materiau)
		return bloc(parent, nom, x2 - x1, y2 - y1, z2 - z1, (x1 + x2) / 2, y2, (z1 + z2) / 2, couleur, materiau)
	end

	-- Dalle sur laquelle on marche (1 stud d'épaisseur).
	function B.dalle(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, 1, sz, x, dessus, z, couleur, materiau)
	end

	-- Pilier qui descend jusqu'au sol (colonnes, bacs empilés).
	function B.pilier(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, dessus - SOL, sz, x, dessus, z, couleur, materiau)
	end

	-- Décor : ne déclenche rien et ne prend pas de contour (il reste solide, sauf si on le dit).
	function B.decor(p)
		p.CanTouch = false
		p.CanQuery = false
		return p
	end
	local decor = B.decor

	-- Décor qu'on ne doit jamais pouvoir toucher : on le traverse.
	function B.fantome(p)
		decor(p)
		p.CanCollide = false
		return p
	end
	local fantome = B.fantome

	-- Pièce ancrée placée par le CFrame de son centre, telle quelle (solide) ; `forme` facultative (PartType).
	function B.brut(parent, nom, sx, sy, sz, cf, couleur, materiau, forme)
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

	-- Pièce fantôme placée par le CFrame de son centre : détails de façade, décor de fond, pièces tournées.
	function B.piece(parent, nom, sx, sy, sz, cf, couleur, materiau)
		return fantome(B.brut(parent, nom, sx, sy, sz, cf, couleur, materiau))
	end

	function B.boule(parent, nom, taille, x, y, z, couleur, materiau)
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

	B.DEBOUT = CFrame.Angles(0, 0, math.rad(90)) -- un cylindre Roblox est couché sur X : on le redresse
	function B.cylindre(parent, nom, longueur, diametre, cf, couleur, materiau)
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

	-- Pan incliné fantôme (WedgePart) : sa face verticale est du côté +Z local, la pente descend vers -Z local.
	function B.pente(parent, nom, sx, sy, sz, cf, couleur, materiau)
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

	-- Contour de la couleur de la zone (SelectionBox) : ce qui se marche se lit d'un coup d'œil.
	function B.contour(p, couleur, epaisseur)
		local boiteSel = Instance.new("SelectionBox")
		boiteSel.Name = "Contour"
		boiteSel.Adornee = p
		boiteSel.Color3 = couleur
		boiteSel.LineThickness = epaisseur or 0.06
		boiteSel.SurfaceTransparency = 1
		boiteSel.Parent = p
	end

	function B.etiqueter(p, tag: string)
		p:AddTag(tag)
		return p
	end

	---------------------------------------------------------------------------------------------------------------
	-- Textes. Densité des SurfaceGui : le plancher est de 40 px/stud pour toute face dont la plus petite dimension
	-- fait moins de 15 studs (panneaux, tableaux, enseignes courantes). Seules les très grandes enseignes (15 studs et
	-- plus) gardent une toile d'environ 600 px sur leur plus petite dimension (jamais moins de 8 px/stud), pour ne pas
	-- gaspiller de mémoire de texture. Une enseigne d'un seul texte dont la taille calculée dépasserait 100 px (la
	-- limite de TextSize) voit sa densité baissée d'autant : le texte garde 100 px mais couvre plus de studs.
	local DENSITE = 40
	local DENSITE_MIN = 8
	local GRANDE_FACE = 15
	local TOILE_GRANDE = 600

	-- Largeur et hauteur, en studs, de la face d'une pièce qui porte un SurfaceGui.
	local function dimensionsFace(part, face)
		local s = part.Size
		if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
			return s.Z, s.Y
		elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
			return s.X, s.Z
		end
		return s.X, s.Y
	end

	local function densiteDe(part, face)
		local l, h = dimensionsFace(part, face)
		local petite = math.min(l, h)
		if petite < GRANDE_FACE then
			return DENSITE
		end
		return math.clamp(TOILE_GRANDE / petite, DENSITE_MIN, DENSITE)
	end

	-- Le texte le plus long que le code ou le client peut écrire dans un label dont le texte est vide à la
	-- construction : l'attribut « TexteLePlusLong » du label porte ce texte et sert à dimensionner la taille fixe.
	local function texteDeCalcul(label): string
		return label:GetAttribute("TexteLePlusLong") or label.Text
	end

	-- Largeur et hauteur utiles (pixels) d'un TextLabel posé sur une toile de largeur × hauteur pixels.
	local function dimensionsLabel(label, largeur: number, hauteur: number)
		local s = label.Size
		local w = s.X.Scale * largeur + s.X.Offset
		local h = s.Y.Scale * hauteur + s.Y.Offset
		local marge = label:FindFirstChildOfClass("UIPadding")
		if marge then
			w -= marge.PaddingLeft.Offset + marge.PaddingRight.Offset + (marge.PaddingLeft.Scale + marge.PaddingRight.Scale) * w
			h -= marge.PaddingTop.Offset + marge.PaddingBottom.Offset + (marge.PaddingTop.Scale + marge.PaddingBottom.Scale) * h
		end
		return w, h
	end

	-- À appeler en fin de construction : règle la densité de chaque SurfaceGui d'après la face qui la porte, puis la
	-- taille fixe de chacun de ses TextLabel (attribut TexteLePlusLong, sinon son texte).
	function B.calibrerSurfaces(racine)
		for _, gui in racine:GetDescendants() do
			if not (gui:IsA("SurfaceGui") and gui.Parent and gui.Parent:IsA("BasePart")) then
				continue
			end
			local l, h = dimensionsFace(gui.Parent, gui.Face)
			local densite = densiteDe(gui.Parent, gui.Face)
			local labels = {}
			for _, d in gui:GetDescendants() do
				if d:IsA("TextLabel") then
					table.insert(labels, d)
				end
			end
			if #labels == 1 then
				local seul = labels[1]
				local s = seul.Size
				if s.X.Scale == 1 and s.Y.Scale == 1 and s.X.Offset == 0 and s.Y.Offset == 0 then
					local brut = ajusterTexte(texteDeCalcul(seul), seul.Font.Name, l * densite, h * densite, 100000)
					if brut > TAILLE_MAX then
						densite = math.clamp(densite * TAILLE_MAX / brut, DENSITE_MIN, densite)
					end
				end
			end
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = densite
			for _, label in labels do
				local w, hauteur = dimensionsLabel(label, l * densite, h * densite)
				reglerTexte(label, w, hauteur, texteDeCalcul(label))
			end
		end
	end

	-- Enseigne d'un seul texte sur la face `surface` (à ranger dans la pièce qui la porte).
	function B.texte(surface, contenu: string, couleurTexte, couleurFond)
		local gui = Instance.new("SurfaceGui")
		gui.Face = surface
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- densité réglée par calibrerSurfaces
		local label = Instance.new("TextLabel")
		label.Name = "Texte"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = couleurFond or Color3.fromRGB(25, 25, 30)
		label.BackgroundTransparency = couleurFond and 0 or 0.1
		label.TextColor3 = couleurTexte or Color3.fromRGB(255, 255, 255)
		label.TextWrapped = true -- taille fixe réglée par calibrerSurfaces (reglerTexte)
		label.Font = Enum.Font.GothamBold
		label.Text = contenu
		label.Parent = gui
		return gui
	end

	-- Nom flottant au-dessus d'un objet, visible de loin (jusqu'à `portee` studs, 250 par défaut).
	function B.etiquette(part, contenu: string, couleur, hauteur, portee)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(320, 60)
		gui.StudsOffset = Vector3.new(0, hauteur or 4, 0)
		gui.MaxDistance = portee or 250
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

	-- Panneau de classement : `face` dit vers où il regarde ; `mural` = accroché (pas de pieds jusqu'au sol).
	function B.tableau(parent, x, dessus, z, face, tag, intitule, couleurTitre, mural)
		local deCote = face == Enum.NormalId.Left or face == Enum.NormalId.Right
		local sx, sz = if deCote then 1 else 14, if deCote then 14 else 1
		local p = decor(bloc(parent, tag, sx, 10, sz, x, dessus + 11, z, Color3.fromRGB(20, 20, 30)))
		B.etiqueter(p, tag)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- densité réglée par calibrerSurfaces
		gui.Parent = p
		local titre = Instance.new("TextLabel")
		titre.Name = "Titre"
		titre.Size = UDim2.fromScale(1, 0.18)
		titre.BackgroundColor3 = couleurTitre
		titre.TextColor3 = Color3.fromRGB(255, 255, 255)
		titre.Font = Enum.Font.GothamBlack
		titre.Text = intitule
		titre.Parent = gui
		local liste = Instance.new("TextLabel")
		liste.Name = "Liste"
		liste.Position = UDim2.fromScale(0.04, 0.2)
		liste.Size = UDim2.fromScale(0.92, 0.78)
		liste.BackgroundTransparency = 1
		liste.TextColor3 = Color3.fromRGB(240, 240, 240)
		-- Taille fixe calculée (calibrerSurfaces) pour le pire cas écrit par src/serveur/Classement.luau : 10 lignes
		-- « %2d. %-14s valeur » (valeur de 10 caractères au plus), en police Code. Le client règle l'alignement :
		-- centré pour un message, en haut à gauche pour la liste.
		local lignes = {}
		for rang = 1, 10 do
			table.insert(lignes, string.format("%2d. %-14s %s", rang, "WWWWWWWWWWWWWW", "12 345 678"))
		end
		liste:SetAttribute("TexteLePlusLong", table.concat(lignes, "\n"))
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

	return B
end
