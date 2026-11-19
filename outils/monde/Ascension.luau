-- Construction « Ascension » : l'empilement chaotique qui flotte au-dessus de Sup de Vinci (esprit Only Up).
--
-- Renvoie une fonction qui reçoit R, les constructeurs Roblox (Instance, Vector3, Vector2, Color3, CFrame, Enum,
-- UDim2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint), et rend le modèle construit :
-- - dans Lune, par outils/monde/generer.luau, qui écrit monde/Ascension.rbxm ;
-- - dans Studio, collée dans un execute_luau du MCP, pour un aperçu immédiat.
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
-- tranche (contour SelectionBox). Tout le reste — les objets qui portent les dalles et le décor de fond — est
-- fantôme (sans collision, sans toucher, sans requête) et penché : rien de plat et de coloré ne peut tromper.
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

return function(R)
	local Instance, Vector3, Color3, CFrame, Enum, UDim2 = R.Instance, R.Vector3, R.Color3, R.CFrame, R.Enum, R.UDim2
	local Vector2, NumberRange, NumberSequence, ColorSequence, ColorSequenceKeypoint =
		R.Vector2, R.NumberRange, R.NumberSequence, R.ColorSequence, R.ColorSequenceKeypoint

	math.randomseed(20261118) -- toute la variation est tirée ici : la construction est reproductible

	local CX, CZ = 845, 0 -- l'axe de l'ascension : le centre de Sup de Vinci
	local BASE = 66 -- dessus du pied de l'ascension (le toit de la fac est à 56)
	local NB_TRANCHES = 6
	local TRANCHE = 43 -- 6 × 43 = 258 : la hauteur de la tour, découpée en six tranches de couleur
	local SOMMET = BASE + NB_TRANCHES * TRANCHE -- 324 : 258 studs au-dessus du départ
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
	-- Une couleur par tranche de 43 studs : on voit d'un coup d'œil où l'on en est dans la montée.
	local tranches = {
		Color3.fromRGB(60, 140, 255), -- 0 à 43 (bleu Vinci)
		Color3.fromRGB(255, 80, 190), -- 43 à 86 (rose rue de la Soif)
		Color3.fromRGB(255, 140, 40), -- 86 à 129 (orange coloc)
		Color3.fromRGB(255, 200, 30), -- 129 à 172 (jaune cortège)
		Color3.fromRGB(120, 230, 40), -- 172 à 215 (vert tour)
		Color3.fromRGB(70, 220, 255), -- 215 à 258 (cyan sommet)
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
	local dObstacles = dossier("Obstacles")
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

	-- Pièce ancrée placée par le CFrame de son centre, telle quelle (solide) : les obstacles qui poussent.
	local function brut(parent, nom, sx, sy, sz, cf, couleur, materiau)
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
		return p
	end

	-- Pièce fantôme placée par le CFrame de son centre : tout le décor penché de l'ascension.
	local function piece(parent, nom, sx, sy, sz, cf, couleur, materiau)
		return fantome(brut(parent, nom, sx, sy, sz, cf, couleur, materiau))
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
		"AUCUN FILET, AUCUN PALIER",
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

	-- La couleur de la tranche de 43 studs où l'on se trouve.
	local function teinteDe(y: number)
		local k = math.floor((y - BASE) / TRANCHE) + 1
		return tranches[math.clamp(k, 1, #tranches)]
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
	texte(Enum.NormalId.Back, "Tomber ramène ici.\nAucun palier : 258 studs d'un trait.", couleurs.or_).Parent = regles
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
	-- Les six familles d'obstacles. Tout ce qui bouge est posé à côté ou au-dessus d'une dalle du chemin : on le voit
	-- venir, on attend sa fenêtre, on saute. Le contrôle (outils/monde/verifier-ascension.luau) simule chaque cycle et
	-- exige au moins 1,2 s de passage libre, et qu'aucun obstacle ne couvre à lui seul toute la dalle.
	local compte = { PiegeMur = 0, Laser = 0, Effondrable = 0, Balancier = 0, Mobile = 0, Tournant = 0 }
	local function rang(famille: string): number
		compte[famille] += 1
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
			piece(
				dObstacles,
				"BoutTournant",
				1.6,
				1.6,
				1.6,
				CFrame.new(px, y + 2.8, pz)
					* CFrame.Angles(0, a + math.pi / 2, 0)
					* CFrame.new(bout * (bras - 0.8), 0, 0),
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
		-- La poutre et ses deux chandelles : on voit d'où pend la pancarte.
		piece(
			dObstacles,
			"PoutreBalancier",
			1,
			1,
			math.max(hx, hz) * 2 + 8,
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
				CFrame.new(pivot.X, pivot.Y - 6, pivot.Z)
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, 0, c * (math.max(hx, hz) + 3.4)),
				couleurs.acier,
				Enum.Material.Metal
			)
		end
		contour(pancarte, accent, 0.1)
		return pancarte
	end

	-- Piège de mur : un pan de mur dressé au bord de la dalle. Seul indice avant qu'il parte : la fente et la trace
	-- d'usure laissée par les passages précédents (décision de l'utilisateur : pas de voyant, pas de clignotement).
	-- La barre sort d'un coup quand on entre dans sa portée, pousse fort, puis rentre : « DureeSortie » est le temps
	-- passé dehors, « DureeRentree » le temps rentré — c'est la fenêtre de passage.
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
		modele:SetAttribute("DureeSortie", entre(0.7, 1))
		modele:SetAttribute("DureeRentree", entre(1.6, 2.2))
		modele:SetAttribute("Portee", d + demi + 4)
		modele:SetAttribute("Poussee", 120)
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
				hx * 1.4,
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
	local function poserMobile(p, dx: number, dz: number)
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
		-- Le rail : on voit sur quelle course la nacelle va et vient.
		piece(
			dObstacles,
			"RailMobile",
			if math.abs(ux) > math.abs(uz) then amplitude + hx * 2 else 0.4,
			0.4,
			if math.abs(ux) > math.abs(uz) then 0.4 else amplitude + hz * 2,
			CFrame.new(x, y - 1.2, z),
			Color3.fromRGB(60, 64, 72),
			Enum.Material.Metal
		)
		return p
	end

	---------------------------------------------------------------------------------------------------------------
	-- Le chemin : six tranches de 43 studs, de plus en plus exigeantes et de plus en plus peuplées. `serre` est la
	-- part du vide tenable qu'on s'autorise : c'est LE bouton de difficulté (0,86 en bas, 0,96 en haut).
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

	local segments = {
		{
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
			if modele.long and famille ~= "Mobile" and famille ~= "Effondrable" then
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
				if famille ~= "Mobile" and famille ~= "Effondrable" then
					modele.construire(dChemin, part, teinteDe(suivant.y))
				else
					contour(part, teinteDe(suivant.y))
				end
			end
			if famille == "Laser" then
				poserLaser(part)
			elseif famille == "Tournant" then
				poserTournant(part)
			elseif famille == "Balancier" then
				poserBalancier(part, teinteDe(suivant.y))
			elseif famille == "PiegeMur" then
				poserPiegeMur(part)
			elseif famille == "Effondrable" then
				poserEffondrable(part)
				speciales[part] = true
			elseif famille == "Mobile" then
				poserMobile(part, dx, dz)
				speciales[part] = true
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
	-- Ce bloc est construit en dernier pour que les tirages aléatoires du chemin et du décor ne changent pas.
	local acces = {
		{ nom = "BureauVolant", x = 844, y = 48, z = 8, hx = 3, hz = 3, objet = objetBureau },
		{ nom = "ArmoireDeLaVerriere", x = 836, y = 54, z = 10, hx = 3, hz = 3, objet = objetArmoire },
		{ nom = "PanneauDuToit", x = 836, y = 60, z = 20, hx = 3, hz = 3, objet = objetPanneau },
	}
	for i, a in acces do
		local p = dalle(dAcces, a.nom, a.hx * 2, a.hz * 2, a.x, a.y, a.z, couleurs.beton, Enum.Material.Concrete)
		contour(p, ACCES, 0.12)
		a.objet(dAcces, p, ACCES)
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
