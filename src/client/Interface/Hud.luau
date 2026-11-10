--!strict
-- L'interface du parcours : étape et zone, chrono, anecdote à chaque checkpoint, boutons « Recommencer » et
-- « Passer l'étape », écran d'arrivée. Tout ce qui s'affiche vient de l'état envoyé par le serveur.
-- Tailles en proportions de l'écran et boutons d'au moins 44 px : lisible sur ordinateur, mobile et tablette.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Etapes = require(ReplicatedStorage.Partage.Etapes)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)
local Remotes = require(ReplicatedStorage.Partage.Remotes)
local Vannes = require(ReplicatedStorage.Partage.Vannes)

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
local DUREE_VANNE_CHUTE = 2.5
local DUREE_ANECDOTE = 8
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
	creer("UITextSizeConstraint", { MaxTextSize = proprietes.TailleMax or 28, MinTextSize = 10 }, l)
	return l
end

local function bouton(parent: Instance, texte: string, couleur: Color3, position: UDim2): TextButton
	local b = creer("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = position,
		Size = UDim2.new(0.22, 0, 0.08, 0),
		BackgroundColor3 = couleur,
		TextColor3 = COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Text = texte,
		AutoButtonColor = true,
	}, parent)
	arrondir(b)
	creer("UISizeConstraint", { MinSize = Vector2.new(150, 44), MaxSize = Vector2.new(280, 60) }, b)
	creer("UITextSizeConstraint", { MaxTextSize = 22 }, b)
	creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	return b
end

local Hud = {}

function Hud.demarrer()
	local ecran = creer("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = false }, nil)

	-- Bandeau du haut : étape, zone, chrono.
	local bandeau = creer("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.42, 0, 0.11, 0),
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 0.15,
	}, ecran)
	arrondir(bandeau)
	creer("UISizeConstraint", { MinSize = Vector2.new(260, 64), MaxSize = Vector2.new(560, 96) }, bandeau)
	local texteEtape = libelle(bandeau, {
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.fromScale(0.92, 0.46),
		Text = "Chargement…",
	})
	local texteChrono = libelle(bandeau, {
		Position = UDim2.fromScale(0.04, 0.54),
		Size = UDim2.fromScale(0.92, 0.4),
		Text = "",
		Font = Enum.Font.Code,
		TextColor3 = COULEURS.discret,
		TailleMax = 22,
	})

	-- Compteur d'aura (la mécanique centrale), bien visible sous le bandeau.
	local texteAura = libelle(bandeau, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromScale(0.8, 0.5),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = COULEURS.fond,
		Text = "Aura 0",
		TextColor3 = COULEURS.aura,
		Font = Enum.Font.GothamBlack,
		TailleMax = 26,
	})
	arrondir(texteAura, 8)

	-- Vanne quand on tombe, en haut au centre.
	local texteChute = libelle(ecran, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromScale(0.6, 0.07),
		Text = "",
		TextColor3 = COULEURS.alerte,
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.GothamBlack,
		TailleMax = 34,
		Visible = false,
	})

	-- Anecdote (vraie) et vanne du jour, à chaque nouveau checkpoint.
	local carte = creer("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.86, 0),
		Size = UDim2.new(0.5, 0, 0.21, 0),
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, ecran)
	arrondir(carte)
	creer("UISizeConstraint", { MinSize = Vector2.new(280, 120), MaxSize = Vector2.new(640, 190) }, carte)
	local titreCarte = libelle(carte, {
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.92, 0.22),
		TextColor3 = COULEURS.or_,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local texteCarte = libelle(carte, {
		Position = UDim2.fromScale(0.04, 0.3),
		Size = UDim2.fromScale(0.92, 0.4),
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TailleMax = 20,
	})
	local blagueCarte = libelle(carte, {
		Position = UDim2.fromScale(0.04, 0.72),
		Size = UDim2.fromScale(0.92, 0.24),
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		TextColor3 = COULEURS.aura,
		TextXAlignment = Enum.TextXAlignment.Left,
		TailleMax = 18,
	})

	-- Boutons en bas à droite (au-dessus des commandes tactiles de saut sur mobile, qui sont plus bas).
	local boutonRecommencer = bouton(ecran, "Recommencer", COULEURS.alerte, UDim2.new(0.98, 0, 0.62, 0))
	local boutonPasser = bouton(ecran, "Passer l'étape (R$)", COULEURS.vinci, UDim2.new(0.98, 0, 0.52, 0))
	boutonPasser.Visible = false

	-- Écran d'arrivée.
	local fin = creer("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.44, 0.34),
		BackgroundColor3 = COULEURS.fond,
		Visible = false,
	}, ecran)
	arrondir(fin, 16)
	creer("UISizeConstraint", { MinSize = Vector2.new(280, 190), MaxSize = Vector2.new(520, 300) }, fin)
	libelle(fin, {
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(0.9, 0.24),
		Text = "Partiel validé !",
		TextColor3 = COULEURS.or_,
		Font = Enum.Font.GothamBlack,
		TailleMax = 40,
	})
	local tempsFin = libelle(fin, {
		Position = UDim2.fromScale(0.05, 0.32),
		Size = UDim2.fromScale(0.9, 0.2),
		Font = Enum.Font.Code,
		TailleMax = 34,
	})
	local detailFin = libelle(fin, {
		Position = UDim2.fromScale(0.05, 0.53),
		Size = UDim2.fromScale(0.9, 0.16),
		Font = Enum.Font.Gotham,
		TextColor3 = COULEURS.discret,
		TailleMax = 20,
	})
	local fermer = creer("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.5, 0.18),
		BackgroundColor3 = COULEURS.vinci,
		TextColor3 = COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Text = "Fermer",
	}, fin)
	arrondir(fermer)
	creer("UISizeConstraint", { MinSize = Vector2.new(120, 44) }, fermer)
	creer("UITextSizeConstraint", { MaxTextSize = 22 }, fermer)

	ecran.Parent = joueur:WaitForChild("PlayerGui")

	-- État reçu du serveur.
	local etat: Remotes.EtatCourse? = nil
	local derniereEtapeVue = -1
	local jetonAnecdote = 0
	local dernierTemps: number? = nil

	local function montrerAnecdote(numero: number)
		local etape = Etapes.obtenir(numero)
		if not etape then
			return
		end
		titreCarte.Text = `Étape {numero} · {etape.zone}`
		texteCarte.Text = etape.anecdote
		blagueCarte.Text = etape.blague
		carte.Visible = true
		jetonAnecdote += 1
		local jeton = jetonAnecdote
		task.delay(DUREE_ANECDOTE, function()
			if jeton == jetonAnecdote then
				carte.Visible = false
			end
		end)
	end

	-- Aura, comptée par le serveur : on affiche le total et la série, et on fait clignoter le gain ou la perte.
	local aura: number? = nil
	local serie = 0
	local jetonAura = 0
	local function libelleAura(): string
		local multiplicateur = math.clamp(serie, 0, Reglages.AURA_SERIE_MAX)
		local texteSerie = if multiplicateur >= 2 then `  ·  série ×{multiplicateur}` else ""
		return `Aura {Regles.formaterAura(aura or 0)}{texteSerie}`
	end
	local function afficherAura(nouvelle: number, nouvelleSerie: number)
		local ancienne = aura
		aura = nouvelle
		serie = nouvelleSerie
		if ancienne == nil or ancienne == nouvelle then
			texteAura.Text = libelleAura()
			return
		end
		local delta = nouvelle - ancienne
		texteAura.Text = `{libelleAura()}  ({if delta > 0 then "+" else ""}{Regles.formaterAura(math.abs(delta))})`
		texteAura.TextColor3 = if delta > 0 then COULEURS.gain else COULEURS.alerte
		jetonAura += 1
		local jeton = jetonAura
		task.delay(1.5, function()
			if jeton == jetonAura then
				texteAura.Text = libelleAura()
				texteAura.TextColor3 = COULEURS.aura
			end
		end)
	end

	local chutes = 0
	local jetonChute = 0
	local function surChute()
		chutes += 1
		texteChute.Text = Vannes.chute(chutes)
		texteChute.Visible = true
		jetonChute += 1
		local jeton = jetonChute
		task.delay(DUREE_VANNE_CHUTE, function()
			if jeton == jetonChute then
				texteChute.Visible = false
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
		if not etat then
			return
		end
		local mention = ""
		if etat.reprise or etat.passages > 0 then
			mention = "  · non classé"
		end
		local record = if etat.meilleurTemps > 0 then `  · record {Regles.formaterTemps(etat.meilleurTemps)}` else ""
		if etat.debut then
			texteChrono.Text = Regles.formaterTemps(workspace:GetServerTimeNow() - etat.debut) .. mention .. record
		elseif dernierTemps then
			texteChrono.Text = Regles.formaterTemps(dernierTemps) .. record
		else
			texteChrono.Text = record
		end
	end

	Remotes.obtenir("EtatCourse").OnClientEvent:Connect(function(nouvel: Remotes.EtatCourse)
		etat = nouvel
		local etape = Etapes.obtenir(nouvel.etape)
		texteEtape.Text = `Étape {nouvel.etape} / {Reglages.NB_ETAPES} · {if etape then etape.zone else ""}`
		if nouvel.etape ~= derniereEtapeVue then
			if nouvel.etape > derniereEtapeVue or nouvel.etape == 0 then
				montrerAnecdote(nouvel.etape)
			end
			derniereEtapeVue = nouvel.etape
		end
		if nouvel.debut then
			dernierTemps = nil
		end
		boutonPasser.Visible = Reglages.PRODUIT_PASSER_ETAPE ~= 0 and nouvel.etape < Reglages.NB_ETAPES
		afficherAura(nouvel.aura, nouvel.serie)
		afficherChrono()
	end)

	Remotes.obtenir("Arrivee").OnClientEvent
		:Connect(function(temps: number, classable: boolean, record: boolean, gainAura: number)
			dernierTemps = temps
			tempsFin.Text = `{Regles.formaterTemps(temps)}   ·   +{Regles.formaterAura(gainAura)} aura`
			local sansChute = gainAura > Reglages.AURA_ARRIVEE
			if sansChute then
				detailFin.Text = "SANS TOMBER. Aura légendaire, respect."
			elseif record then
				detailFin.Text = "Nouveau record ! Regarde le classement."
			elseif classable then
				detailFin.Text = "Pas de record cette fois. Recommence sans tomber pour l'aura max."
			else
				detailFin.Text = "Temps non classé (étape passée ou partie reprise)."
			end
			fin.Visible = true
		end)

	fermer.Activated:Connect(function()
		fin.Visible = false
	end)

	-- Un premier clic demande confirmation : on ne perd pas sa progression par erreur.
	local confirmation = 0
	boutonRecommencer.Activated:Connect(function()
		if etat and etat.etape > 0 and confirmation == 0 then
			confirmation += 1
			local jeton = confirmation
			boutonRecommencer.Text = "Sûr ? Clique encore"
			task.delay(DUREE_CONFIRMATION, function()
				if confirmation == jeton then
					confirmation = 0
					boutonRecommencer.Text = "Recommencer"
				end
			end)
			return
		end
		confirmation = 0
		boutonRecommencer.Text = "Recommencer"
		fin.Visible = false
		Remotes.obtenir("DemanderRecommencer"):FireServer()
	end)

	boutonPasser.Activated:Connect(function()
		if Reglages.PRODUIT_PASSER_ETAPE ~= 0 then
			MarketplaceService:PromptProductPurchase(joueur, Reglages.PRODUIT_PASSER_ETAPE)
		end
	end)

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

return Hud
