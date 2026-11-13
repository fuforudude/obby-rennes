--!strict
-- L'interface du parcours, volontairement légère. En course, un seul petit groupe en haut au centre :
-- étape (7/15), chrono, aura avec la série, bouton « Recommencer ». Le nom de la zone n'apparaît que 2 secondes à
-- chaque nouveau checkpoint ; les anecdotes sont dans le décor (Panneaux.luau). « Passer l'étape » est dans un petit
-- menu en coin. Le record et « non classé » ne se voient qu'à l'arrivée.
-- Tout ce qui s'affiche vient de l'état envoyé par le serveur ; le serveur seul décide (le bouton envoie une demande).
-- Tailles en proportions de l'écran, bornées par des contraintes ; boutons d'au moins 44 px ; animations < 0,3 s.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Affichage = require(ReplicatedStorage.Partage.Affichage)
local Etapes = require(ReplicatedStorage.Partage.Etapes)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)
local Vannes = require(ReplicatedStorage.Partage.Vannes)

local Panneaux = require(script.Parent.Panneaux)
local Textes = require(script.Parent.Textes)

local joueur = Players.LocalPlayer

local COULEURS = {
	fond = Color3.fromRGB(20, 24, 34),
	texte = Color3.fromRGB(255, 255, 255),
	discret = Color3.fromRGB(170, 180, 200),
	vinci = Color3.fromRGB(30, 90, 170),
	alerte = Color3.fromRGB(220, 70, 60),
	or_ = Color3.fromRGB(240, 190, 50),
	aura = Color3.fromRGB(255, 120, 220),
	gain = Color3.fromRGB(110, 240, 130),
}
local DUREE_ZONE = 2 -- le nom de la zone, à chaque nouveau checkpoint
local DUREE_CHUTE = 1.5 -- le message de chute
local DUREE_FONDU = 0.15 -- toutes les animations restent sous 0,3 s
local DUREE_COULEUR_AURA = 1.2 -- l'aura reste verte ou rouge un instant après un gain ou une perte
local DUREE_CONFIRMATION = 3

local function creer(classe: string, proprietes: { [string]: any }, parent: Instance?): any
	local objet = Instance.new(classe)
	for nom, valeur in proprietes do
		(objet :: any)[nom] = valeur
	end
	if parent then
		objet.Parent = parent
	end
	return objet
end

local function arrondir(objet: Instance, rayon: number?)
	creer("UICorner", { CornerRadius = UDim.new(0, rayon or 10) }, objet)
end

local function libelle(parent: Instance, proprietes: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}
	for nom, valeur in proprietes do
		if nom ~= "TailleMax" then -- notre option à nous, pas une propriété Roblox
			base[nom] = valeur
		end
	end
	local l = creer("TextLabel", base, parent)
	creer("UITextSizeConstraint", { MaxTextSize = proprietes.TailleMax or 22, MinTextSize = 10 }, l)
	return l
end

local function jouer(objet: Instance, duree: number, proprietes: { [string]: any }): Tween
	local t =
		TweenService:Create(objet, TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), proprietes)
	t:Play()
	return t
end

--- Un bouton plein, sélectionnable à la manette. La taille est donnée par l'appelant (échelle + contraintes).
local function bouton(parent: Instance, texte: string, couleur: Color3, rayon: number): TextButton
	local b = creer("TextButton", {
		BackgroundColor3 = couleur,
		TextColor3 = COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		Text = texte,
		AutoButtonColor = true,
		Selectable = true,
	}, parent)
	arrondir(b, rayon)
	creer("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, b)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
	}, b)
	return b
end

local Hud = {}

local ecran: ScreenGui? = nil

function Hud.monter()
	if ecran then
		return
	end
	local gui = creer("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		-- ScreenInsets reste à sa valeur par défaut (CoreUISafe) : rien du HUD ne passe sous la barre de Roblox
		-- (menu en haut à gauche) ni sous l'encoche des téléphones.
	}, nil)
	ecran = gui

	-- Le groupe de course, en haut au centre : 330 à 480 px de large, 64 à 80 px de haut.
	local groupe = creer("Frame", {
		Name = "Groupe",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromScale(0.42, 0.14),
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 0.15,
	}, gui)
	arrondir(groupe)
	creer("UISizeConstraint", { MinSize = Vector2.new(330, 64), MaxSize = Vector2.new(480, 80) }, groupe)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, groupe)

	-- À gauche (62 % de la largeur) : l'étape et le chrono sur une ligne, l'aura dessous.
	local stats = creer("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.62, 1),
	}, groupe)
	local texteEtape = libelle(stats, {
		Name = "Etape",
		Size = UDim2.fromScale(0.3, 0.5),
		Text = Textes.chargement,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COULEURS.or_,
	})
	local texteChrono = libelle(stats, {
		Name = "Chrono",
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.7, 0.5),
		Text = Affichage.chrono(nil, 0, nil),
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local texteAura = libelle(stats, {
		Name = "Aura",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(1, 0.5),
		Text = `{Textes.aura} 0`,
		TextColor3 = COULEURS.aura,
		Font = Enum.Font.GothamBlack,
	})
	local echelleAura = creer("UIScale", { Scale = 1 }, texteAura)

	-- À droite (35 %) : Recommencer, sur toute la hauteur du groupe (au moins 52 px).
	local boutonRecommencer = bouton(groupe, Textes.recommencer, COULEURS.alerte, 8)
	boutonRecommencer.Name = "Recommencer"
	boutonRecommencer.AnchorPoint = Vector2.new(1, 0)
	boutonRecommencer.Position = UDim2.fromScale(1, 0)
	boutonRecommencer.Size = UDim2.fromScale(0.35, 1)
	boutonRecommencer.SelectionOrder = 1

	-- Le nom de la zone, juste sous le groupe, 2 secondes à chaque nouveau checkpoint.
	local texteZone = libelle(groupe, {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromScale(1.3, 0.55),
		Text = "",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextColor3 = COULEURS.or_,
		Font = Enum.Font.GothamBlack,
		TailleMax = 28,
	})

	-- Le message de chute : petit, au tiers de la hauteur, 1,5 seconde.
	local texteChute = libelle(gui, {
		Name = "Chute",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.5, 0.05),
		Text = "",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextColor3 = COULEURS.alerte,
		Font = Enum.Font.GothamBold,
		TailleMax = 20,
	})

	-- Le menu en coin : une icône (trois barres) au bord gauche, à 30 % de la hauteur, sous la barre de Roblox.
	-- Il ouvre un petit panneau avec « Passer l'étape ». Caché tant que le produit n'existe pas.
	local icone = creer("TextButton", {
		Name = "Menu",
		Position = UDim2.new(0, 8, 0.3, 0),
		Size = UDim2.fromScale(0.05, 0.09),
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 0.15,
		Text = "",
		AutoButtonColor = true,
		Selectable = true,
		SelectionOrder = 2,
		Visible = false,
	}, gui)
	arrondir(icone, 10)
	creer("UIAspectRatioConstraint", { AspectRatio = 1 }, icone)
	creer("UISizeConstraint", { MinSize = Vector2.new(44, 44), MaxSize = Vector2.new(56, 56) }, icone)
	for i = 0, 2 do
		local barre = creer("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.32 + i * 0.18),
			Size = UDim2.fromScale(0.5, 0.08),
			BackgroundColor3 = COULEURS.texte,
			BorderSizePixel = 0,
		}, icone)
		arrondir(barre, 4)
	end
	local boutonPasser = bouton(icone, Textes.passerEtape, COULEURS.vinci, 8)
	boutonPasser.Name = "PasserEtape"
	boutonPasser.AnchorPoint = Vector2.new(0, 0.5)
	boutonPasser.Position = UDim2.new(1, 6, 0.5, 0)
	boutonPasser.Size = UDim2.fromScale(4.2, 1) -- 4,2 fois l'icône : 185 à 235 px de large, même hauteur
	boutonPasser.Visible = false
	boutonPasser.SelectionOrder = 3

	-- Écran d'arrivée : compact, au centre. Conservé : temps, aura gagnée, record, non classé.
	local fin = creer("Frame", {
		Name = "Arrivee",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.36, 0.3),
		BackgroundColor3 = COULEURS.fond,
		Visible = false,
	}, gui)
	arrondir(fin, 16)
	creer("UISizeConstraint", { MinSize = Vector2.new(280, 220), MaxSize = Vector2.new(460, 280) }, fin)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
		PaddingTop = UDim.new(0.04, 0),
		PaddingBottom = UDim.new(0.04, 0),
	}, fin)
	creer("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.02, 0),
	}, fin)
	libelle(fin, {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0.2),
		Text = Textes.arriveeTitre,
		TextColor3 = COULEURS.or_,
		Font = Enum.Font.GothamBlack,
		TailleMax = 32,
	})
	local tempsFin = libelle(fin, {
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0.17),
		Font = Enum.Font.Code,
		TailleMax = 26,
	})
	local recordFin = libelle(fin, {
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0.11),
		Font = Enum.Font.Gotham,
		TextColor3 = COULEURS.discret,
		TailleMax = 18,
	})
	local mentionFin = libelle(fin, {
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0.11),
		Font = Enum.Font.Gotham,
		TextColor3 = COULEURS.discret,
		TailleMax = 16,
	})
	local fermer = bouton(fin, Textes.arriveeFermer, COULEURS.vinci, 10)
	fermer.LayoutOrder = 5
	fermer.Size = UDim2.fromScale(0.45, 0.2)
	creer("UISizeConstraint", { MinSize = Vector2.new(120, 44) }, fermer)

	gui.Parent = joueur:WaitForChild("PlayerGui")

	-- État reçu du serveur.
	local etat: Remotes.EtatCourse? = nil
	local derniereEtapeVue = -1
	local dernierTemps: number? = nil

	local jetonZone = 0
	local function montrerZone(numero: number)
		local etape = Etapes.obtenir(numero)
		if not etape then
			return
		end
		texteZone.Text = etape.zone
		jouer(texteZone, DUREE_FONDU, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
		jetonZone += 1
		local jeton = jetonZone
		task.delay(DUREE_ZONE - DUREE_FONDU, function()
			if jeton == jetonZone then
				jouer(texteZone, DUREE_FONDU, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end

	-- Aura, comptée par le serveur : le total et la série. À chaque gain ou perte, le texte grossit un instant et se
	-- colore (vert / rouge), puis reprend sa couleur. Pas de clignotement.
	local aura = 0
	local serie = 0
	local jetonAura = 0
	local function afficherAura(nouvelle: number, nouvelleSerie: number)
		local delta = nouvelle - aura
		local premiere = etat == nil
		aura = nouvelle
		serie = nouvelleSerie
		texteAura.Text = `{Textes.aura} {Affichage.aura(aura, serie, Reglages.AURA_SERIE_MAX)}`
		if delta == 0 or premiere then
			return
		end
		jetonAura += 1
		local jeton = jetonAura
		texteAura.TextColor3 = if delta > 0 then COULEURS.gain else COULEURS.alerte
		jouer(echelleAura, 0.12, { Scale = 1.15 }).Completed:Once(function()
			if jeton == jetonAura then
				jouer(echelleAura, 0.15, { Scale = 1 })
			end
		end)
		task.delay(DUREE_COULEUR_AURA, function()
			if jeton == jetonAura then
				jouer(texteAura, 0.25, { TextColor3 = COULEURS.aura })
			end
		end)
	end

	local chutes = 0
	local jetonChute = 0
	local function surChute()
		chutes += 1
		texteChute.Text = Vannes.chute(chutes)
		jouer(texteChute, DUREE_FONDU, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
		jetonChute += 1
		local jeton = jetonChute
		task.delay(DUREE_CHUTE - DUREE_FONDU, function()
			if jeton == jetonChute then
				jouer(texteChute, DUREE_FONDU, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end

	local function suivrePersonnage(personnage: Model)
		local humanoide = personnage:WaitForChild("Humanoid", 10)
		if humanoide and humanoide:IsA("Humanoid") then
			humanoide.Died:Connect(surChute) -- se déconnecte tout seul quand le personnage est détruit
		end
	end
	joueur.CharacterAdded:Connect(suivrePersonnage)
	if joueur.Character then
		task.spawn(suivrePersonnage, joueur.Character)
	end

	local function afficherChrono()
		local debut = if etat then etat.debut else nil
		texteChrono.Text = Affichage.chrono(debut, workspace:GetServerTimeNow(), dernierTemps)
	end

	-- Le menu en coin.
	local function fermerMenu()
		if boutonPasser.Visible then
			boutonPasser.Visible = false
			if GuiService.SelectedObject == boutonPasser then
				GuiService.SelectedObject = icone -- à la manette, on ne perd pas le curseur
			end
		end
	end
	--- Ouvre ou ferme le menu. Rend `false` (sans rien faire) quand il n'existe pas : produit à 0, dernière étape,
	--- ou interface cachée.
	local function basculerMenu(): boolean
		if not icone.Visible or not (ecran and ecran.Enabled) then
			return false
		end
		if boutonPasser.Visible then
			fermerMenu()
		else
			boutonPasser.Visible = true
			if GuiService.SelectedObject == icone then
				GuiService.SelectedObject = boutonPasser
			end
		end
		return true
	end
	icone.Activated:Connect(function()
		basculerMenu()
	end)

	Remotes.obtenir("EtatCourse").OnClientEvent:Connect(function(nouvel: Remotes.EtatCourse)
		afficherAura(nouvel.aura, nouvel.serie) -- avant `etat = nouvel` : la première réception n'est pas un gain
		etat = nouvel
		texteEtape.Text = Affichage.etape(nouvel.etape, Reglages.NB_ETAPES)
		if nouvel.etape ~= derniereEtapeVue then
			if nouvel.etape > derniereEtapeVue or nouvel.etape == 0 then
				montrerZone(nouvel.etape)
			end
			derniereEtapeVue = nouvel.etape
		end
		if nouvel.debut then
			dernierTemps = nil
		end
		icone.Visible = Affichage.passerVisible(Reglages.PRODUIT_PASSER_ETAPE, nouvel.etape, Reglages.NB_ETAPES)
		if not icone.Visible then
			fermerMenu()
		end
		afficherChrono()
	end)

	Remotes.obtenir("Arrivee").OnClientEvent
		:Connect(function(temps: number, classable: boolean, record: boolean, gainAura: number)
			dernierTemps = temps
			local meilleur = if etat then etat.meilleurTemps else 0
			local resume = Affichage.arrivee(temps, classable, record, gainAura, meilleur, Reglages.AURA_ARRIVEE)
			tempsFin.Text = Textes.arriveeTempsEtGain(resume.temps, resume.gain)
			-- Le record et « non classé » ne se voient qu'ici.
			if resume.nouveauRecord then
				recordFin.Text = `{Textes.arriveeNouveauRecord} {resume.temps}`
				recordFin.TextColor3 = COULEURS.gain
			elseif resume.record then
				recordFin.Text = Textes.arriveeRecord(resume.record)
				recordFin.TextColor3 = COULEURS.discret
			else
				recordFin.Text = ""
			end
			recordFin.Visible = recordFin.Text ~= ""
			if resume.nonClasse then
				mentionFin.Text = Textes.arriveeNonClasse
				mentionFin.TextColor3 = COULEURS.discret
			elseif resume.sansChute then
				mentionFin.Text = Textes.arriveeSansChute
				mentionFin.TextColor3 = COULEURS.aura
			else
				mentionFin.Text = ""
			end
			mentionFin.Visible = mentionFin.Text ~= ""
			fin.Visible = true
			if GuiService.SelectedObject ~= nil then
				GuiService.SelectedObject = fermer -- manette : le curseur va sur « Fermer »
			end
			afficherChrono()
		end)

	fermer.Activated:Connect(function()
		fin.Visible = false
		if GuiService.SelectedObject == fermer then
			GuiService.SelectedObject = boutonRecommencer
		end
	end)

	-- Un premier clic demande confirmation : on ne perd pas sa progression par erreur.
	local confirmation = 0
	--- Rend `true` si la demande a été prise en compte ; `false` (sans rien faire) quand Recommencer n'a pas de sens :
	--- interface cachée ou état de la course pas encore reçu. Le raccourci laisse alors passer la touche.
	local function demanderRecommencer(): boolean
		if not (ecran and ecran.Enabled) or etat == nil then
			return false
		end
		if etat.etape > 0 and confirmation == 0 then
			confirmation += 1
			local jeton = confirmation
			boutonRecommencer.Text = Textes.recommencerConfirmer
			task.delay(DUREE_CONFIRMATION, function()
				if confirmation == jeton then
					confirmation = 0
					boutonRecommencer.Text = Textes.recommencer
				end
			end)
			return true
		end
		confirmation = 0
		boutonRecommencer.Text = Textes.recommencer
		fin.Visible = false
		Remotes.obtenir("DemanderRecommencer"):FireServer()
		return true
	end
	boutonRecommencer.Activated:Connect(function()
		demanderRecommencer()
	end)

	boutonPasser.Activated:Connect(function()
		if Reglages.PRODUIT_PASSER_ETAPE ~= 0 then
			MarketplaceService:PromptProductPurchase(joueur, Reglages.PRODUIT_PASSER_ETAPE)
		end
		fermerMenu()
	end)

	-- Raccourcis par ContextActionService (clavier et manette) ; pas de bouton tactile : l'écran a déjà les siens.
	-- R / Y : Recommencer (avec la même double confirmation). M / X : le menu en coin.
	-- La fonction rend `true` quand elle a agi. Sinon (menu caché, Recommencer sans objet), la touche est laissée
	-- passer : elle ne doit pas être confisquée à un autre usage (X et Y de la manette, M).
	local function action(
		fonction: () -> boolean
	): (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult
		return function(_nom, etatEntree, _entree)
			if etatEntree == Enum.UserInputState.Begin and fonction() then
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end
	end
	ContextActionService:BindAction(
		"HudRecommencer",
		action(demanderRecommencer),
		false,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:BindAction("HudMenu", action(basculerMenu), false, Enum.KeyCode.M, Enum.KeyCode.ButtonX)

	-- Le chrono s'affiche dix fois par seconde : assez fluide, sans travail à chaque image.
	local cumul = 0
	RunService.Heartbeat:Connect(function(dt)
		cumul += dt
		if cumul >= 0.1 then
			cumul = 0
			afficherChrono()
		end
	end)
end

function Hud.afficher()
	if ecran then
		ecran.Enabled = true
	end
end

function Hud.cacher()
	if ecran then
		ecran.Enabled = false
	end
end

--- Monte et affiche l'interface du parcours, et remplit les panneaux d'anecdote du décor.
function Hud.demarrer()
	Hud.monter()
	Hud.afficher()
	Panneaux.monter()
end

return Hud
