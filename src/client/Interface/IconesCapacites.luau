--!strict
-- Les capacités débloquées, en une petite rangée de pastilles en bas au centre de l'écran (loin du menu Roblox en haut
-- à gauche, du joystick en bas à gauche et du bouton de saut en bas à droite) : « Course », « Saut ×2 », « Dash ».
-- Une pastille en couleur vive = capacité disponible ; grise = consommée (double saut ou dash déjà utilisé avant de
-- toucher le sol), elle reprend sa couleur au contact du sol. Une capacité non débloquée n'a pas de pastille.
-- L'état vient d'EtatCourse.capacites (débloquées) et des attributs du joueur `CapaciteDoubleSautPrete` et
-- `CapaciteDashPrete` (booléens posés par le contrôleur des capacités) ; absents, la capacité est montrée disponible.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Affichage = require(ReplicatedStorage.Partage.Affichage)
local Capacites = require(ReplicatedStorage.Partage.Capacites)

local Composants = require(script.Parent.Composants)
local Textes = require(script.Parent.Textes)

local COULEURS = Composants.COULEURS
local creer = Composants.creer
local jouer = Composants.jouer

local ATTRIBUT_DOUBLE_SAUT = Capacites.ATTRIBUT_DOUBLE_SAUT_PRET
local ATTRIBUT_DASH = Capacites.ATTRIBUT_DASH_PRET
local DUREE_RECHARGE = 0.1 -- le retour en couleur, très court

local COULEUR_CAPACITE: { [string]: Color3 } = {
	course = COULEURS.course,
	doubleSaut = COULEURS.doubleSaut,
	dash = COULEURS.dash,
}
local ORDRE: { Affichage.Capacite } = { "course", "doubleSaut", "dash" }

local IconesCapacites = {}

local joueur = Players.LocalPlayer
local rangee: Frame? = nil
local pastilles: { [string]: TextLabel } = {}
local debloquees: any = nil -- EtatCourse.capacites, tel que reçu

--- Un attribut booléen du joueur ; `nil` tant que le contrôleur ne l'a pas posé.
local function lireAttribut(nom: string): boolean?
	local valeur = joueur:GetAttribute(nom)
	if type(valeur) == "boolean" then
		return valeur
	end
	return nil
end

local function rafraichir()
	local icones = Affichage.icones(debloquees, lireAttribut(ATTRIBUT_DOUBLE_SAUT), lireAttribut(ATTRIBUT_DASH))
	local parCapacite: { [string]: Affichage.IconeCapacite } = {}
	for _, icone in icones do
		parCapacite[icone.capacite] = icone
	end
	for capacite, pastille in pastilles do
		local icone = parCapacite[capacite]
		pastille.Visible = icone ~= nil
		if icone then
			jouer(pastille, DUREE_RECHARGE, {
				BackgroundColor3 = if icone.disponible then COULEUR_CAPACITE[capacite] else COULEURS.consomme,
				TextColor3 = if icone.disponible then COULEURS.texte else COULEURS.grise,
			})
		end
	end
end

--- Crée la rangée dans l'interface `gui` (une seule fois) et suit les attributs du joueur.
function IconesCapacites.monter(gui: ScreenGui)
	if rangee then
		return
	end
	-- 34 % de la largeur de l'écran, bornée à 210-330 px ; 12 % de la hauteur, bornée à 40-52 px ; collée en bas au
	-- centre, 10 px au-dessus du bord. Sur un téléphone de 568 px de large : 193 px, de x = 187 à x = 381.
	local conteneur = creer("Frame", {
		Name = "Capacites",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromScale(0.34, 0.12),
		BackgroundTransparency = 1,
	}, gui)
	rangee = conteneur
	creer("UISizeConstraint", { MinSize = Vector2.new(210, 40), MaxSize = Vector2.new(330, 52) }, conteneur)
	creer("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.03, 0),
	}, conteneur)

	local noms = Textes.capaciteCourte :: { [string]: string }
	for ordre, capacite in ORDRE do
		local pastille = Composants.libelle(conteneur, {
			Name = capacite,
			LayoutOrder = ordre,
			Size = UDim2.fromScale(0.3, 1),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = COULEUR_CAPACITE[capacite],
			Text = noms[capacite],
			TailleMax = 18,
			Visible = false,
		})
		Composants.arrondir(pastille, 10)
		creer("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}, pastille)
		pastilles[capacite] = pastille
	end

	joueur:GetAttributeChangedSignal(ATTRIBUT_DOUBLE_SAUT):Connect(rafraichir)
	joueur:GetAttributeChangedSignal(ATTRIBUT_DASH):Connect(rafraichir)
end

--- Les capacités débloquées, telles que le serveur les envoie (EtatCourse.capacites : nom -> vrai).
function IconesCapacites.definir(capacites: any)
	debloquees = capacites
	rafraichir()
end

return IconesCapacites
