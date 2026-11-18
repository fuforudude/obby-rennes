-- Construction « Ascension » : l'empilement chaotique qui flotte au-dessus de Sup de Vinci (esprit Only Up).
--
-- Renvoie une fonction qui reçoit R, les constructeurs Roblox (Instance, Vector3, Vector2, Color3, CFrame, Enum,
-- UDim2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint), et rend le modèle construit :
-- - dans Lune, par outils/monde/generer.luau, qui écrit monde/Ascension.rbxm ;
-- - dans Studio, collée dans un execute_luau du MCP, pour un aperçu immédiat.
--
-- Le tracé. On sort de la salle de partiel (checkpoint 15, en 834, 42, 8), on redescend dans l'atrium de Sup de Vinci
-- par trois meubles qui flottent, on ressort par la porte d'entrée (dalles « Accueil » et « Marche » du Parcours),
-- puis on grimpe par le sud de la fac jusqu'au **pied de l'ascension**, une plateforme qui flotte 10 studs au-dessus
-- du toit. De là, 258 studs de montée en spirale autour de la fac : morceaux d'immeubles rennais retournés, bus STAR,
-- rames de métro, grues, échafaudages, panneaux publicitaires, canapés, armoires, bureaux, bouées, poubelles,
-- pancartes du cortège et une galette-saucisse géante. Quatre paliers (tous les 60 studs) et le sommet.
--
-- Lisibilité : on ne pose les pieds que sur des **dalles horizontales**, saturées et cernées de la couleur de leur
-- tranche (contour SelectionBox). Tout le reste — les objets qui portent les dalles et le décor de fond — est
-- fantôme (sans collision, sans toucher, sans requête) et penché : rien de plat et de coloré ne peut tromper.
--
-- Ce que le jeu attend (contrats de docs/specs/2026-11-18-capacites-et-ascension.md) :
-- - tag « PiedAscension » : la plateforme de départ, où la chute renvoie ;
-- - tag « Palier » + attributs « Numero » (1 à 4) et « Hauteur » : palier acquis définitivement ; enfant « Boutique »
--   (Model vide, attribut « Emplacement ») : la place de la boutique du jalon suivant ;
-- - « Hauteur » est toujours le Y absolu du dessus de la pièce (126, 186, 246, 306 pour les paliers) ; la hauteur
--   gagnée depuis le départ est l'attribut « HauteurRelative » (le pied, taillé à 66, le porte aussi) ;
-- - tag « EtageAscension » + attribut « Numero » : plaque à toucher qui compte un étage franchi (aura) ;
-- - tag « SommetAscension » : l'arrivée ;
-- - tags « TableauHauteur » / « TableauAscension » : panneaux dont le serveur remplit le TextLabel « Liste ».
-- Rien n'est mortel ici : le « Mortel » de la ville (Parcours) sert de détecteur de chute.
--
-- Sauts (personnage par défaut, les trois capacités débloquées) : on ne monte jamais de plus de 8 studs et on ne
-- franchit jamais plus de 16 studs de vide, la montée et le vide étant liés (plus on monte, moins on avance).
-- Chaque dalle est posée à la distance calculée de la précédente : un chemin existe par construction.
-- Contrôle : lune run outils/monde/verifier-ascension.luau

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local Vector2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint =
		R.Vector2, R.NumberRange, R.NumberSequence, R.ColorSequence, R.ColorSequenceKeypoint

	math.randomseed(20261118) -- toute la variation est tirée ici : la construction est reproductible

	local CX, CZ = 845, 0 -- l'axe de l'ascension : le centre de Sup de Vinci
	local BASE = 66 -- dessus du pied de l'ascension (le toit de la fac est à 56)
	local ECART_PALIER = 60
	local PALIERS = { BASE + 60, BASE + 120, BASE + 180, BASE + 240 } -- 126, 186, 246, 306
	local SOMMET = BASE + 258 -- 324 : 258 studs au-dessus du départ
	local ECART_ETAGE = 15

	-- Palette : celle du jeu (outils/monde/Parcours.luau).
	local couleurs = {
		bois = Color3.fromRGB(196, 132, 74),
		chaise = Color3.fromRGB(64, 120, 235),
		papier = Color3.fromRGB(255, 252, 235),
		metro = Color3.fromRGB(235, 50, 60),
		quai = Color3.fromRGB(150, 155, 165),
		pancarte = Color3.fromRGB(255, 205, 40),
		bac = Color3.fromRGB(40, 170, 90),
		facade = Color3.fromRGB(250, 236, 205),
		colombage = Color3.fromRGB(95, 55, 35),
		toit = Color3.fromRGB(85, 95, 120),
		ponton = Color3.fromRGB(170, 115, 70),
		pierre = Color3.fromRGB(235, 222, 190),
		vinci = Color3.fromRGB(25, 85, 185),
		or_ = Color3.fromRGB(255, 200, 40),
		checkpoint = Color3.fromRGB(70, 220, 255),
		feuillage = Color3.fromRGB(70, 175, 75),
		beton = Color3.fromRGB(205, 205, 210),
		acier = Color3.fromRGB(120, 128, 140),
		galette = Color3.fromRGB(205, 160, 95),
		saucisse = Color3.fromRGB(175, 85, 60),
		bus = Color3.fromRGB(235, 235, 240),
	}
	-- Une couleur par tranche : on voit d'un coup d'œil où l'on en est dans la montée.
	local tranches = {
		Color3.fromRGB(60, 140, 255), -- pied -> palier 1 (bleu Vinci)
		Color3.fromRGB(255, 80, 190), -- palier 1 -> 2 (rose rue de la Soif)
		Color3.fromRGB(255, 200, 30), -- palier 2 -> 3 (jaune cortège)
		Color3.fromRGB(120, 230, 40), -- palier 3 -> 4 (vert tour)
		Color3.fromRGB(70, 220, 255), -- palier 4 -> sommet (cyan)
	}
	local ACCES = Color3.fromRGB(255, 140, 60) -- l'accès depuis la salle de partiel (orange coloc)

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
	local dPaliers = dossier("Paliers")
	local dEtages = dossier("Etages")
	local dSommet = dossier("Sommet")
	local dDecor = dossier("Decor")

	---------------------------------------------------------------------------------------------------------------
	-- Outils de construction (les mêmes que outils/monde/Parcours.luau : les constructions ne partagent pas de module).

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

	-- Décor : ne déclenche rien et ne prend pas de contour.
	local function decor(p)
		p.CanTouch = false
		p.CanQuery = false
		return p
	end

	-- Décor fantôme : on le traverse. Tout ce qui n'est pas une dalle du chemin l'est.
	local function fantome(p)
		decor(p)
		p.CanCollide = false
		return p
	end

	-- Dalle sur laquelle on marche (1 stud d'épaisseur) : la seule chose solide de cette carte.
	local function dalle(parent, nom, sx, sz, x, dessus, z, couleur, materiau)
		return bloc(parent, nom, sx, 1, sz, x, dessus, z, couleur, materiau)
	end

	local function contour(p, couleur, epaisseur)
		local boiteSel = Instance.new("SelectionBox")
		boiteSel.Name = "Contour"
		boiteSel.Adornee = p
		boiteSel.Color3 = couleur
		boiteSel.LineThickness = epaisseur or 0.08
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

	-- Pièce fantôme placée par le CFrame de son centre : tout le décor penché de l'ascension.
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

	-- Texte des SurfaceGui : TOUJOURS une taille fixe calculée, jamais TextScaled (en jeu, TextScaled rend un texte
	-- minuscule sur ces panneaux ; la taille fixe est la seule qui a été vue lisible). Les trois constructions
	-- (Parcours.luau, Evenements.luau et Ascension.luau) portent le même bloc ; outils/monde/verifier-ascension.luau le
	-- compare à celui de Parcours.luau et refuse tout TextScaled ou TextSize < 12 sur une SurfaceGui.
	-- DEBUT TEXTE_PUR
	local TAILLE_MIN, TAILLE_MAX = 12, 100 -- TextSize : Roblox le borne à 100
	local REMPLISSAGE_LARGEUR = 0.95 -- marge d'erreur sur la largeur estimée des caractères

	-- Par police : largeur moyenne (en fraction de la taille) d'une minuscule, d'une majuscule, d'un chiffre, d'une
	-- espace et d'un autre signe ; puis hauteur d'une ligne (en fraction de la taille). Estimations prudentes ; la
	-- police Code est à chasse fixe (0,6).
	local METRIQUES = {
		Gotham = { 0.54, 0.70, 0.62, 0.27, 0.42, 1.2 },
		GothamBold = { 0.57, 0.73, 0.64, 0.27, 0.44, 1.2 },
		GothamBlack = { 0.61, 0.78, 0.68, 0.28, 0.46, 1.2 },
		Code = { 0.6, 0.6, 0.6, 0.6, 0.6, 1.1 },
	}

	local function largeurCaractere(c: number, m): number
		if (c >= 97 and c <= 122) or (c >= 0xDF and c <= 0xFF) then
			return m[1]
		elseif (c >= 65 and c <= 90) or (c >= 0xC0 and c <= 0xDE) then
			return m[2]
		elseif c >= 48 and c <= 57 then
			return m[3]
		elseif c == 32 then
			return m[4]
		end
		return m[5]
	end

	-- Le texte en paragraphes (séparés par \n), chacun une liste de largeurs de mots (en fraction de la taille).
	local function decouperTexte(contenu: string, m)
		local paragraphes = {}
		for ligne in string.gmatch(contenu .. "\n", "([^\n]*)\n") do
			local mots = {}
			for mot in string.gmatch(ligne, "%S+") do
				local w = 0
				for _, c in utf8.codes(mot) do
					w += largeurCaractere(c, m)
				end
				table.insert(mots, w)
			end
			table.insert(paragraphes, mots)
		end
		return paragraphes
	end

	-- Nombre de lignes après retour à la ligne glouton, `capacite` étant la largeur de ligne en fraction de la taille.
	local function compterLignes(paragraphes, espace: number, capacite: number): number
		local n = 0
		for _, mots in paragraphes do
			n += 1
			local courante = 0
			for i, w in mots do
				if i > 1 and courante + espace + w <= capacite then
					courante += espace + w
				else
					if i > 1 then
						n += 1
					end
					if w > capacite then -- mot plus long qu'une ligne : coupé
						local en_plus = math.ceil(w / capacite) - 1
						n += en_plus
						courante = w - en_plus * capacite
					else
						courante = w
					end
				end
			end
		end
		return n
	end

	-- La plus grande taille entière (12 à `plafond`, 100 par défaut) pour laquelle `contenu` tient dans largeur ×
	-- hauteur pixels, à la ligne ; rend la taille et le nombre de lignes. 12 si rien ne tient.
	local function ajusterTexte(contenu: string, police: string, largeur: number, hauteur: number, plafond: number?)
		local m = METRIQUES[police] or METRIQUES.GothamBold
		local paragraphes = decouperTexte(contenu, m)
		local utile = largeur * REMPLISSAGE_LARGEUR
		local function lignesA(s: number): number
			return compterLignes(paragraphes, m[4], utile / s)
		end
		local function tient(s: number): boolean
			return lignesA(s) * m[6] * s <= hauteur
		end
		local bas, haut = TAILLE_MIN, math.max(TAILLE_MIN, math.floor(plafond or TAILLE_MAX))
		while bas < haut and tient(bas) do
			local milieu = (bas + haut + 1) // 2
			if tient(milieu) then
				bas = milieu
			else
				haut = milieu - 1
			end
		end
		return bas, lignesA(bas)
	end

	-- La seule règle de taille de texte : fixe, à la ligne, texte brut, entier entre 12 et 100.
	local function reglerTexte(label, largeur: number, hauteur: number, contenu: string, plafond: number?)
		local taille, lignes = ajusterTexte(contenu, label.Font.Name, largeur, hauteur, plafond)
		label.TextScaled = false
		label.TextWrapped = true
		label.RichText = false
		label.TextSize = taille
		return taille, lignes
	end
	-- FIN TEXTE_PUR
	-- Densité des SurfaceGui (même règle que Parcours.luau) : 40 px/stud, sauf les très grandes faces.
	local DENSITE, DENSITE_MIN, GRANDE_FACE, TOILE_GRANDE = 40, 8, 15, 600

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

	local function texteDeCalcul(label): string
		return label:GetAttribute("TexteLePlusLong") or label.Text
	end

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

	-- À appeler en fin de construction : densité de chaque SurfaceGui d'après sa face, puis taille fixe de ses textes.
	local function calibrerSurfaces(racine)
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
		label.TextWrapped = true -- taille fixe réglée par calibrerSurfaces (reglerTexte)
		label.Font = Enum.Font.GothamBold
		label.Text = contenu
		label.Parent = gui
		return gui
	end

	-- Nom flottant au-dessus d'un objet, visible de loin.
	local function etiquette(part, contenu: string, couleur, hauteur, portee)
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

	local function etiqueter(p, tag: string)
		p:AddTag(tag)
		return p
	end

	-- Panneau de classement, accroché en l'air (pas de pieds : on est à 70 studs du sol).
	local function tableau(parent, x, dessus, z, face, tag, intitule, couleurTitre)
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
		-- « %2d. %-14s valeur » (valeur de 10 caractères au plus), en police Code.
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
		return p
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
	-- (la dalle est son toit, son assise, son plateau). Tout l'habillage est fantôme et volontairement penché.

	-- Centre, dessus et demi-dimensions d'une dalle.
	local function reperes(p)
		local pos, s = p.CFrame.Position, p.Size
		return pos.X, pos.Y + s.Y / 2, pos.Z, s.X / 2, s.Z / 2
	end

	local SLOGANS = {
		"ASCENSEUR EN PANNE",
		"GALETTE-SAUCISSE 24/7",
		"ÇA MONTE ENCORE",
		"RATTRAPAGE AU 4e PALIER",
		"PENSE À RESPIRER",
		"STAR · LIGNE VERTICALE",
		"TOUT EN HAUT ?",
		"CRACHIN À PARTIR DE 200",
		"DEUXIÈME SESSION",
		"ON Y EST PRESQUE (NON)",
	}

	-- Morceau d'immeuble rennais retourné : façade penchée, bandeaux de fenêtres, un balcon dans le vide.
	local function objetImmeuble(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local h = entre(10, 18)
		local inclinaison = CFrame.Angles(math.rad(entre(-18, 18)), math.rad(entre(0, 360)), math.rad(entre(-18, 18)))
		local corps = CFrame.new(x, y - 1 - h / 2, z) * inclinaison
		piece(
			parent,
			"Facade",
			hx * 2 + 1.5,
			h,
			hz * 2 + 1.5,
			corps,
			choix({ couleurs.facade, couleurs.pierre }),
			Enum.Material.Concrete
		)
		for _, k in { -0.25, 0.15 } do
			piece(
				parent,
				"Fenetres",
				hx * 2 + 1.7,
				1.8,
				hz * 2 + 1.7,
				corps * CFrame.new(0, h * k, 0),
				Color3.fromRGB(150, 200, 235),
				Enum.Material.Glass
			)
		end
		piece(
			parent,
			"Balcon",
			3.5,
			0.4,
			2.5,
			corps * CFrame.new(hx + 2, h * 0.3, 0) * CFrame.Angles(0, 0, math.rad(12)),
			couleurs.acier,
			Enum.Material.Metal
		)
		piece(
			parent,
			"Colombage",
			0.5,
			h * 0.8,
			0.5,
			corps * CFrame.new(hx * 0.6, 0, hz * 0.9),
			couleurs.colombage,
			Enum.Material.Wood
		)
		if math.random() < 0.4 then
			piece(
				parent,
				"ToitArrache",
				hx * 2 + 2,
				2,
				hz * 2 + 2,
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
		local sx, sz = if longX then hx * 2 + 4 else hx * 2 + 1, if longX then hz * 2 + 1 else hz * 2 + 4
		local corps = CFrame.new(x, y - 4.5, z) * CFrame.Angles(0, 0, math.rad(entre(-7, 7)))
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

	-- Rame de métro debout : la dalle est le flanc d'une voiture plantée à la verticale.
	local function objetRame(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local inclinaison = CFrame.Angles(math.rad(entre(70, 110)), math.rad(entre(0, 360)), 0)
		local corps = CFrame.new(x, y - 8, z) * inclinaison
		piece(parent, "Rame", hx * 2 + 1, 16, hz * 2 + 1, corps, couleurs.quai, Enum.Material.Metal)
		piece(parent, "BandeauRame", hx * 2 + 1.2, 2.2, hz * 2 + 1.2, corps * CFrame.new(0, 5, 0), couleurs.metro)
		for _, k in { -3, 2 } do
			piece(
				parent,
				"PorteRame",
				hx * 2 + 1.3,
				3,
				2.2,
				corps * CFrame.new(0, k, hz),
				Color3.fromRGB(40, 50, 70),
				Enum.Material.Glass
			)
		end
		cylindre(
			parent,
			"Pantographe",
			4,
			0.4,
			corps * CFrame.new(0, -8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			couleurs.acier,
			Enum.Material.Metal
		)
		contour(p, accent)
	end

	-- Grue de chantier : la dalle est sa flèche, la tour part en biais dans le vide.
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
			22,
			2.2,
			CFrame.new(x, y - 13, z) * CFrame.Angles(math.rad(entre(-14, 14)), 0, math.rad(entre(-14, 14))),
			jaune,
			mat
		)
		piece(
			parent,
			"ContrePoids",
			3,
			3,
			3,
			CFrame.new(x + (if longX then -hx - 1 else 0), y - 2.5, z + (if longX then 0 else -hz - 1)),
			couleurs.beton,
			Enum.Material.Concrete
		)
		local bout = CFrame.new(x + (if longX then hx - 1 else 0), y - 1, z + (if longX then 0 else hz - 1))
		piece(parent, "Cable", 0.2, 7, 0.2, bout * CFrame.new(0, -3.5, 0), Color3.fromRGB(40, 40, 45), mat)
		piece(parent, "Crochet", 1.2, 1.2, 1.2, bout * CFrame.new(0, -7.5, 0), couleurs.acier, mat)
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
						* CFrame.Angles(0, 0, math.rad(entre(-5, 5))),
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
			CFrame.new(x, y - h * 0.55, z),
			couleurs.ponton,
			Enum.Material.Wood
		)
		piece(
			parent,
			"Diagonale",
			math.sqrt((hx * 2) ^ 2 + h ^ 2),
			0.3,
			0.3,
			CFrame.new(x, y - 1 - h / 2, z + hz - 0.4) * CFrame.Angles(0, 0, math.atan2(h, hx * 2)),
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
		local cadre = CFrame.new(x, y - 5, z)
			* CFrame.Angles(0, if longX then 0 else math.rad(90), math.rad(entre(-9, 9)))
		local affiche = piece(parent, "Affiche", l, 7, 0.4, cadre, Color3.fromRGB(25, 25, 35))
		texte(Enum.NormalId.Front, choix(SLOGANS), couleurs.or_).Parent = affiche
		texte(Enum.NormalId.Back, choix(SLOGANS), couleurs.checkpoint).Parent = affiche
		piece(parent, "Lisere", l + 0.4, 0.3, 0.6, cadre * CFrame.new(0, 3.7, 0), accent, Enum.Material.Neon)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Pied",
				0.6,
				12,
				0.6,
				cadre * CFrame.new(d * l * 0.35, -9, 0),
				couleurs.acier,
				Enum.Material.Metal
			)
		end
		contour(p, accent)
	end

	-- Canapé : la dalle est l'assise.
	local function objetCanape(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local tissu = choix({ Color3.fromRGB(190, 70, 90), Color3.fromRGB(70, 110, 170), Color3.fromRGB(110, 150, 90) })
		local base = CFrame.new(x, y - 2.5, z) * CFrame.Angles(0, math.rad(entre(0, 360)), math.rad(entre(-8, 8)))
		piece(parent, "Assise", hx * 2 + 0.6, 3, hz * 2 + 0.6, base, tissu, Enum.Material.Fabric)
		piece(parent, "Dossier", hx * 2 + 0.6, 4, 1.2, base * CFrame.new(0, 3, -hz), tissu, Enum.Material.Fabric)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"Accoudoir",
				1.2,
				3,
				hz * 2 + 0.6,
				base * CFrame.new(d * hx, 1.5, 0),
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
			base * CFrame.new(0, 1.8, 0.4),
			Color3.fromRGB(240, 230, 200),
			Enum.Material.Fabric
		)
		for _, d in { -1, 1 } do
			piece(
				parent,
				"PiedCanape",
				0.6,
				1.6,
				0.6,
				base * CFrame.new(d * hx * 0.7, -2.2, 0),
				couleurs.bois,
				Enum.Material.Wood
			)
		end
		contour(p, accent)
	end

	-- Armoire couchée : la dalle est son flanc.
	local function objetArmoire(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 3, z) * CFrame.Angles(math.rad(entre(-12, 12)), math.rad(entre(0, 360)), 0)
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
				base * CFrame.new(d * 0.6, 0, hz + 0.6) * CFrame.Angles(math.rad(90), 0, 0),
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
					CFrame.new(x + sx * (hx - 0.6), y - 3, z + sz * (hz - 0.6))
						* CFrame.Angles(math.rad(entre(-6, 6)), 0, 0),
					couleurs.bois,
					Enum.Material.Wood
				)
			end
		end
		piece(parent, "Caisson", hx, 2.5, hz, CFrame.new(x + hx * 0.4, y - 2.5, z), couleurs.bois, Enum.Material.Wood)
		local chaise = CFrame.new(x - hx - 1, y - 5, z)
			* CFrame.Angles(math.rad(entre(-25, 25)), math.rad(entre(0, 360)), math.rad(entre(-25, 25)))
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

	-- Bouée de la Vilaine : la dalle est posée au milieu de l'anneau.
	local function objetBouee(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local r = math.max(hx, hz) + 2
		cylindre(parent, "Bouee", 2.2, r * 2, CFrame.new(x, y - 2, z) * DEBOUT, Color3.fromRGB(245, 245, 245))
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.rad(45)
			piece(
				parent,
				"Quartier",
				r * 0.8,
				2.4,
				r * 0.8,
				CFrame.new(x + math.cos(a) * r * 0.75, y - 2, z + math.sin(a) * r * 0.75) * CFrame.Angles(0, -a, 0),
				if i % 2 == 0 then couleurs.metro else Color3.fromRGB(245, 245, 245)
			)
		end
		piece(
			parent,
			"Cordage",
			0.25,
			9,
			0.25,
			CFrame.new(x + r, y - 6, z) * CFrame.Angles(math.rad(14), 0, 0),
			couleurs.ponton,
			Enum.Material.Fabric
		)
		contour(p, accent)
	end

	-- Poubelle du cortège : la dalle est son couvercle.
	local function objetPoubelle(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local corps = CFrame.new(x, y - 3.5, z) * CFrame.Angles(math.rad(entre(-10, 10)), 0, math.rad(entre(-10, 10)))
		piece(parent, "Bac", hx * 2 - 0.4, 6, hz * 2 - 0.4, corps, couleurs.bac)
		piece(
			parent,
			"Rebord",
			hx * 2 + 0.3,
			0.6,
			hz * 2 + 0.3,
			corps * CFrame.new(0, 2.8, 0),
			Color3.fromRGB(30, 120, 65)
		)
		for _, d in { -1, 1 } do
			cylindre(
				parent,
				"Roulette",
				0.6,
				1.4,
				corps * CFrame.new(d * (hx - 0.8), -3.2, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(30, 30, 30)
			)
		end
		boule(parent, "Sac", 3, x + hx + 1, y - 2, z - hz, Color3.fromRGB(35, 35, 40))
		contour(p, accent)
	end

	-- Pancarte du cortège, plantée à l'envers.
	local function objetPancarte(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 1, z) * CFrame.Angles(0, math.rad(entre(0, 360)), math.rad(entre(-12, 12)))
		piece(parent, "Manche", 0.5, 14, 0.5, base * CFrame.new(0, -8, 0), couleurs.bois, Enum.Material.Wood)
		local carton =
			piece(parent, "Carton", math.max(hx, hz) * 2.2, 5, 0.35, base * CFrame.new(0, -5, 0.6), couleurs.pancarte)
		texte(Enum.NormalId.Front, choix(SLOGANS), Color3.fromRGB(35, 30, 20), couleurs.pancarte).Parent = carton
		piece(parent, "Scotch", 1.6, 0.2, 0.8, base * CFrame.new(0, -2.6, 0.5), couleurs.papier, Enum.Material.Fabric)
		contour(p, accent)
	end

	-- La galette-saucisse géante : la dalle est la galette, la saucisse roule à côté.
	local function objetGalette(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local r = math.max(hx, hz) + 2.5
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
			CFrame.new(x, y - 2.7, z) * CFrame.Angles(math.rad(6), math.rad(entre(0, 360)), 0),
			couleurs.papier
		)
		piece(parent, "Moutarde", 0.6, 0.25, r, CFrame.new(x, y - 0.6, z - r * 0.55), couleurs.pancarte)
		contour(p, accent)
	end

	-- Container de chantier, panneau de rue, cabine : des objets simples pour varier.
	local function objetContainer(parent, p, accent)
		local x, y, z, hx, hz = reperes(p)
		local base = CFrame.new(x, y - 3, z) * CFrame.Angles(math.rad(entre(-9, 9)), math.rad(entre(0, 360)), 0)
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
	local MONTEE_MAX, VIDE_MAX = 9, 16
	local function videTenable(montee: number): number
		local v = VIDE_MAX - 10 * math.max(0, montee) / MONTEE_MAX
		if montee < 0 then
			v += math.min(4, -montee / 4)
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

	-- La couleur de la tranche où l'on se trouve.
	local function teinteDe(y: number)
		local k = 1
		for _, h in PALIERS do
			if y > h + 0.01 then
				k += 1
			end
		end
		return tranches[math.min(k, #tranches)]
	end

	---------------------------------------------------------------------------------------------------------------
	-- L'accès depuis la salle de partiel (checkpoint 15, en 834, 42, 8 : dalle de 12 × 12, dessus à 42).
	--
	-- Sup de Vinci est un bâtiment fermé (murs du sol à 56, toit plein à 55-56) : on ne peut en sortir que par sa
	-- porte, sur la face -X (ouverture z -4..4, de 18 à 30). L'accès redescend donc de la mezzanine par trois meubles
	-- qui flottent, emprunte les deux dalles du Parcours qui encadrent la porte (« Accueil » en 829, 18, 0 et
	-- « Marche » en 820, 18, 0 : on ressort comme on est entré, de plain-pied), puis remonte par le sud de la fac
	-- jusqu'au pied de l'ascension. Les trois meubles intérieurs restent à l'écart des plateformes de l'atrium et de
	-- l'« Accueil » : aucun plafond bas (moins de 5,5 studs) au-dessus d'une plateforme du tuto.
	-- Un toit vitré ouvrant dans Parcours.luau rendrait cet accès inutile : voir le rendu de la tâche.
	local acces = {
		{ nom = "SortieSalle", x = 833, y = 35, z = -1, hx = 4, hz = 4, objet = objetBureau },
		{ nom = "ArmoireAtrium", x = 836.5, y = 29, z = 6, hx = 4, hz = 3, objet = objetArmoire },
		{ nom = "CanapeAtrium", x = 836, y = 24, z = -1, hx = 3, hz = 3, objet = objetCanape },
		{ nom = "ParvisVolant", x = 812, y = 24, z = 0, hx = 4, hz = 4, objet = objetEchafaudage },
		{ nom = "Container", x = 808, y = 31, z = -13, hx = 4, hz = 4, objet = objetContainer },
		{ nom = "BusRenverse", x = 818, y = 38, z = -24, hx = 4, hz = 4, objet = objetBus },
		{ nom = "Poubelles", x = 828, y = 45, z = -28, hx = 4, hz = 4, objet = objetPoubelle },
		{ nom = "Echafaudage", x = 838, y = 54, z = -26, hx = 4, hz = 4, objet = objetEchafaudage },
		{ nom = "DernierPalier", x = 847, y = 62, z = -17, hx = 4, hz = 4, objet = objetPanneau },
	}
	for i, a in acces do
		local p = dalle(dAcces, a.nom, a.hx * 2, a.hz * 2, a.x, a.y, a.z, couleurs.beton, Enum.Material.Concrete)
		contour(p, ACCES, 0.12)
		a.objet(dAcces, p, ACCES)
		if i == 1 then
			p:SetAttribute("DepartAcces", true) -- repère du contrôle : d'ici, on doit atteindre le pied
			etiquette(p, "SORTIE ↓ L'ASCENSION", ACCES, 4, 200)
		elseif i == 3 then
			etiquette(p, "↓ PAR LA PORTE", ACCES, 4, 200)
		elseif i == 4 then
			etiquette(p, "L'ASCENSION ↑", ACCES, 4, 220)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le pied de l'ascension : 26 × 26 studs qui flottent 10 studs au-dessus du toit de la fac. C'est là que la
	-- chute renvoie, et là que sont les deux tableaux de classement.
	local pied = dalle(dPied, "PiedAscension", 26, 26, CX, BASE, CZ, couleurs.vinci, Enum.Material.DiamondPlate)
	etiqueter(pied, "PiedAscension")
	pied:SetAttribute("Hauteur", BASE)
	pied:SetAttribute("HauteurRelative", 0)
	contour(pied, tranches[1], 0.22)
	etiquette(pied, "PIED DE L'ASCENSION", tranches[1], 7, 400)
	lumiere(pied, tranches[1], 40, 1.6)
	fantome(bloc(dPied, "Lisere", 28, 0.4, 28, CX, BASE + 0.1, CZ, tranches[1], Enum.Material.Neon))
	for _, c in { -1, 1 } do
		fantome(
			bloc(dPied, "PilierPortique", 1, 14, 1, CX - 13, BASE + 14, CZ + c * 12, tranches[1], Enum.Material.Metal)
		)
	end
	local fronton = fantome(bloc(dPied, "Portique", 1.2, 4, 26, CX - 13, BASE + 17, CZ, Color3.fromRGB(20, 20, 30)))
	texte(Enum.NormalId.Right, "L'ASCENSION", tranches[1]).Parent = fronton
	local regles = fantome(bloc(dPied, "Regles", 12, 6, 0.4, CX + 2, BASE + 11, CZ - 14, Color3.fromRGB(20, 20, 30)))
	texte(Enum.NormalId.Back, "Tomber ramène ici.\nLes paliers restent acquis.", couleurs.or_).Parent = regles
	tableau(dPied, CX - 9, BASE, CZ + 14.5, Enum.NormalId.Front, "TableauHauteur", "Plus haut montés", tranches[1])
	tableau(
		dPied,
		CX + 9,
		BASE,
		CZ + 14.5,
		Enum.NormalId.Front,
		"TableauAscension",
		"Meilleures ascensions",
		couleurs.or_
	)
	-- Un bout de toit arraché sous le pied : on comprend qu'il flotte.
	piece(
		dPied,
		"ToitArrache",
		30,
		3,
		30,
		CFrame.new(CX, BASE - 3, CZ) * CFrame.Angles(math.rad(4), 0, math.rad(-3)),
		couleurs.toit,
		Enum.Material.Slate
	)
	for _, d in { -1, 1 } do
		piece(
			dPied,
			"Poutre",
			1.4,
			12,
			1.4,
			CFrame.new(CX + d * 10, BASE - 9, CZ - d * 8) * CFrame.Angles(math.rad(18 * d), 0, math.rad(12)),
			couleurs.acier,
			Enum.Material.Metal
		)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le chemin : cinq tranches, chacune terminée par un palier (le sommet pour la dernière). Dans une tranche, la
	-- montée et le vide grandissent avec l'altitude ; les abords d'un palier restent faciles (on y arrive essoufflé).
	local segments = {
		{
			cible = 60,
			pas = 12,
			monteeMax = 6,
			videMin = 3.5,
			videMax = 9,
			serre = 0.72,
			demi = { 3.6, 4.6 },
			rayon = 24,
			dAngle = 30,
		},
		{
			cible = 60,
			pas = 12,
			monteeMax = 7.5,
			videMin = 4.5,
			videMax = 12,
			serre = 0.8,
			demi = { 3.2, 4.2 },
			rayon = 27,
			dAngle = 34,
		},
		{
			cible = 60,
			pas = 12,
			monteeMax = 8,
			videMin = 5.5,
			videMax = 14,
			serre = 0.86,
			demi = { 2.9, 3.9 },
			rayon = 30,
			dAngle = 38,
		},
		{
			cible = 60,
			pas = 12,
			monteeMax = 8,
			videMin = 6.5,
			videMax = 15.5,
			serre = 0.9,
			demi = { 2.7, 3.6 },
			rayon = 33,
			dAngle = 40,
		},
		{
			cible = 18,
			pas = 4,
			monteeMax = 6,
			videMin = 4,
			videMax = 9,
			serre = 0.78,
			demi = { 3.4, 4.4 },
			rayon = 20,
			dAngle = 34,
		},
	}
	local MONTEE_MIN = 3.5 -- deux pas de suite montent donc de 7 studs : jamais de plafond bas au-dessus d'une dalle
	local MONTEE_ABORDS, VIDE_ABORDS = 4, 6.5 -- le pas qui arrive sur un palier et celui qui en repart

	local chemin: { { pas: Pas, part: any } } = {} -- toutes les plateformes, du pied au sommet, dans l'ordre
	local piedPas: Pas = { x = CX, z = CZ, y = BASE, hx = 13, hz = 13 }
	table.insert(chemin, { pas = piedPas, part = pied })

	-- Palier : grande plateforme sûre, bien visible, avec la place de la boutique du jalon suivant.
	local function construirePalier(numero: number, pas: Pas)
		local p = dalle(
			dPaliers,
			`Palier{numero}`,
			pas.hx * 2,
			pas.hz * 2,
			pas.x,
			pas.y,
			pas.z,
			couleurs.or_,
			Enum.Material.Metal
		)
		etiqueter(p, "Palier")
		p:SetAttribute("Numero", numero)
		p:SetAttribute("Hauteur", pas.y)
		p:SetAttribute("HauteurRelative", pas.y - BASE)
		contour(p, couleurs.or_, 0.24)
		etiquette(p, `PALIER {numero} · {math.floor(pas.y - BASE + 0.5)} studs`, couleurs.or_, 8, 400)
		lumiere(p, couleurs.or_, 36, 1.5)
		fantome(
			bloc(
				dPaliers,
				"Lisere",
				pas.hx * 2 + 2,
				0.4,
				pas.hz * 2 + 2,
				pas.x,
				pas.y + 0.1,
				pas.z,
				couleurs.or_,
				Enum.Material.Neon
			)
		)
		-- La place de la boutique (jalon suivant) : un Model vide, et au sol la marque de son emplacement.
		local ex, ez = pas.x + pas.hx * 0.5, pas.z - pas.hz * 0.5
		local boutique = Instance.new("Model")
		boutique.Name = "Boutique"
		boutique:SetAttribute("Emplacement", Vector3.new(ex, pas.y, ez))
		boutique.Parent = p
		local marque = fantome(
			bloc(dPaliers, "PlaceBoutique", 8, 0.3, 8, ex, pas.y + 0.2, ez, couleurs.checkpoint, Enum.Material.Neon)
		)
		marque.Transparency = 0.4
		local enseigne =
			fantome(bloc(dPaliers, "EnseigneBoutique", 8, 2.4, 0.3, ex, pas.y + 9, ez - 4, Color3.fromRGB(20, 20, 30)))
		texte(Enum.NormalId.Back, "BOUTIQUE (bientôt)", couleurs.checkpoint).Parent = enseigne
		for _, d in { -1, 1 } do
			fantome(
				bloc(
					dPaliers,
					"PiedEnseigne",
					0.4,
					7,
					0.4,
					ex + d * 3.6,
					pas.y + 7,
					ez - 4,
					couleurs.acier,
					Enum.Material.Metal
				)
			)
		end
		-- Un morceau de place rennaise sous le palier : pavés, banc, lampadaire.
		piece(
			dPaliers,
			"Paves",
			pas.hx * 2 + 4,
			2.5,
			pas.hz * 2 + 4,
			CFrame.new(pas.x, pas.y - 2.3, pas.z) * CFrame.Angles(math.rad(3), 0, math.rad(-2)),
			couleurs.pierre,
			Enum.Material.Cobblestone
		)
		piece(
			dPaliers,
			"Banc",
			6,
			0.6,
			1.6,
			CFrame.new(pas.x - pas.hx * 0.5, pas.y + 1.3, pas.z + pas.hz * 0.5),
			couleurs.ponton,
			Enum.Material.Wood
		)
		local lampe = fantome(
			bloc(
				dPaliers,
				"Lampadaire",
				0.5,
				12,
				0.5,
				pas.x - pas.hx * 0.6,
				pas.y + 12,
				pas.z - pas.hz * 0.6,
				Color3.fromRGB(45, 50, 60),
				Enum.Material.Metal
			)
		)
		local tete = fantome(
			bloc(
				dPaliers,
				"Lampe",
				1.6,
				0.8,
				1.6,
				lampe.CFrame.Position.X,
				pas.y + 12.6,
				lampe.CFrame.Position.Z,
				Color3.fromRGB(255, 230, 160),
				Enum.Material.Neon
			)
		)
		lumiere(tete, Color3.fromRGB(255, 220, 160), 18, 1.2)
		arbreFlottant(dPaliers, pas.x + pas.hx * 0.7, pas.y, pas.z + pas.hz * 0.7)
		return p
	end

	local angle = math.rad(205) -- on part vers le sud-ouest (le drapeau breton de la fac est au nord-est)
	local prec = piedPas
	for s, seg in segments do
		local n = seg.pas
		local objectif = if s < #segments then PALIERS[s] else SOMMET
		-- Un grand saut presque à plat par tranche intermédiaire : c'est le seul endroit où le vide peut atteindre
		-- 15 studs (course + dash), puisque le vide tenable se referme dès qu'on monte.
		local dash = if s >= 2 and s < #segments then n // 2 else -1
		local function monteeMaxDe(j: number): number
			if j == dash then
				return 2
			end
			return if j == 1 or j == n then MONTEE_ABORDS else seg.monteeMax
		end
		local function monteeMinDe(j: number): number
			return if j == dash then 0.5 else MONTEE_MIN
		end
		for i = 1, n do
			local restants = n - i
			local reste = objectif - prec.y
			local sommeMax, sommeMin = 0, 0
			for j = i + 1, n do
				sommeMax += monteeMaxDe(j)
				sommeMin += monteeMinDe(j)
			end
			local bas = math.max(monteeMinDe(i), reste - sommeMax)
			local haut = math.min(monteeMaxDe(i), reste - sommeMin)
			haut = math.max(haut, bas)
			local montee = if restants == 0 then reste else entre(bas, haut)
			local videVoulu = if i == dash
				then entre(math.max(11, seg.videMax - 3), seg.videMax)
				else entre(seg.videMin, seg.videMax)
			-- `serre` est la part du vide tenable qu'on s'autorise : c'est LE bouton de difficulté de la tranche.
			local ecart = math.min(videVoulu, (videTenable(montee) - 0.7) * seg.serre)
			if i == 1 or i == n then
				ecart = math.min(ecart, VIDE_ABORDS)
			end
			ecart = math.max(ecart, 2.2)
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
			if modele.long then
				if math.abs(dx) >= math.abs(dz) then
					hx, hz = demi * 1.9, demi * 0.8
				else
					hx, hz = demi * 0.8, demi * 1.9
				end
			end
			if i == n then
				local c = if s < #segments then 11 else 13
				hx, hz = c, c
			end
			local suivant = poser(prec, dx, dz, ecart, montee, hx, hz)
			local part
			if i < n then
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
				modele.construire(dChemin, part, teinteDe(suivant.y))
			elseif s < #segments then
				part = construirePalier(s, suivant)
			else
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
	fantome(bloc(dSommet, "Lisere", 28, 0.4, 28, sx, sy + 0.1, sz, couleurs.or_, Enum.Material.Neon))
	-- Le trophée : la galette-saucisse dorée, sur un socle.
	cylindre(dSommet, "GaletteDoree", 2.4, 14, CFrame.new(sx, sy + 7, sz) * DEBOUT, couleurs.or_, Enum.Material.Neon)
	cylindre(
		dSommet,
		"SaucisseDoree",
		12,
		3.4,
		CFrame.new(sx, sy + 9, sz) * CFrame.Angles(0, math.rad(20), 0),
		couleurs.saucisse
	)
	for _, d in { -1, 1 } do
		fantome(bloc(dSommet, "Socle", 2, 6, 2, sx + d * 5, sy + 6, sz + d * 5, couleurs.pierre, Enum.Material.Marble))
	end
	fantome(
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
		ColorSequenceKeypoint.new(0, tranches[1]),
		ColorSequenceKeypoint.new(0.5, couleurs.or_),
		ColorSequenceKeypoint.new(1, tranches[2]),
	})
	confettis.Parent = canon

	---------------------------------------------------------------------------------------------------------------
	-- Les étages : une plaque à toucher tous les 15 studs de hauteur, sur la plateforme du chemin qui atteint la
	-- hauteur voulue. C'est elle qui compte l'étage franchi (aura croissante, côté serveur).
	local depuis, numero = 2, 0
	for cible = BASE + ECART_ETAGE, SOMMET + 0.01, ECART_ETAGE do
		for k = depuis, #chemin do
			local maillon = chemin[k]
			if maillon.pas.y >= cible - 0.01 then
				numero += 1
				depuis = k + 1
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
				break
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
	-- Lisibilité, dernier mot : toute pièce où l'on pose les pieds porte un contour de la couleur de sa tranche
	-- (celles des objets et des paliers l'ont déjà) ; rien d'autre n'en porte.
	for _, p in ascension:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and p.CanQuery and not p:FindFirstChild("Contour") then
			contour(p, teinteDe(p.CFrame.Position.Y))
		end
	end

	calibrerSurfaces(ascension)
	return ascension
end
