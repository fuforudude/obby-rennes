--!strict
-- Le menu de téléportation vers un palier, ouvert depuis l'entrée « Paliers » du menu en coin (ou la touche P).
-- Un petit panneau au centre : un titre, l'avertissement « se téléporter rend la tentative non classée », une grille
-- de deux colonnes avec un bouton par palier (« Palier 3 · 182 m »), et « Fermer ». Un palier débloqué est un bouton
-- bleu qui envoie l'intention `DemanderTeleportPalier(numero)` ; un palier non débloqué est grisé et ne fait rien.
-- Le serveur décide (palier réellement débloqué, délai de 2 s) : le client ne se déplace jamais lui-même.
-- La hauteur de chaque palier vient de la carte (tag `Palier`, attributs `Numero` et `HauteurRelative`, la hauteur AU-DESSUS DU
-- PIED, comme `EtatAscension.hauteur`) ; elle est mémorisée dès que le palier est vu, car le streaming peut le retirer
-- ensuite. `Hauteur` (le Y absolu de la carte) n'est lu qu'en secours, moins celui du `PiedAscension`.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Affichage = require(ReplicatedStorage.Partage.Affichage)

local Composants = require(script.Parent.Composants)
local Textes = require(script.Parent.Textes)

local COULEURS = Composants.COULEURS
local creer = Composants.creer

local TAG_PALIER = "Palier"
local TAG_PIED = "PiedAscension"

local MenuPaliers = {}

local panneau: Frame? = nil
local grille: Frame? = nil
local boutonFermer: TextButton? = nil
local retour: GuiObject? = nil -- où remettre le curseur de la manette en fermant
local remoteTeleport: RemoteEvent? = nil
local debloques: { number } = {}
local hauteurs: { [number]: number } = {} -- numéro du palier -> hauteur en studs AU-DESSUS DU PIED, lue sur la carte
local avertiHauteur = false -- un seul avertissement par session

--- Le Y absolu du pied de l'ascension (son attribut `Hauteur`), s'il est chargé : repère du secours.
local function hauteurDuPied(): number?
	for _, objet in CollectionService:GetTagged(TAG_PIED) do
		local valeur = objet:GetAttribute("Hauteur")
		if type(valeur) == "number" then
			return valeur
		end
	end
	return nil
end

--- Lit la hauteur d'un palier de la carte : `HauteurRelative`, sinon `Hauteur` moins celle du pied, sinon rien (le
--- bouton affiche « — » plutôt qu'un chiffre faux).
local function lirePalier(objet: Instance)
	local numero = objet:GetAttribute("Numero")
	if type(numero) ~= "number" then
		return
	end
	local relative = objet:GetAttribute("HauteurRelative")
	local hauteur = Affichage.hauteurPalier(relative, objet:GetAttribute("Hauteur"), hauteurDuPied())
	if hauteur ~= nil then
		hauteurs[numero] = hauteur
	end
	if type(relative) ~= "number" and not avertiHauteur then
		avertiHauteur = true
		local suite = if hauteur ~= nil then "secours : Hauteur moins celle du pied" else "hauteur non affichée"
		warn(`Interface : palier {objet:GetFullName()} sans HauteurRelative ({suite}), carte à régénérer`)
	end
end

local function reconstruire()
	local g = grille
	if not g then
		return
	end
	for _, enfant in g:GetChildren() do
		if enfant:IsA("GuiButton") then
			enfant:Destroy()
		end
	end
	local lignes = Affichage.lignesPaliers(debloques, hauteurs, Composants.formaterHauteur)
	for _, ligne in lignes do
		local b = Composants.bouton(
			g,
			Textes.lignePalier(ligne.numero, ligne.hauteur),
			if ligne.debloque then COULEURS.vinci else COULEURS.consomme,
			8
		)
		b.Name = `Palier{ligne.numero}`
		b.LayoutOrder = ligne.numero
		b.SelectionOrder = ligne.numero
		if ligne.debloque then
			b.Activated:Connect(function()
				MenuPaliers.demander(ligne.numero)
			end)
		else
			-- grisé : aucun clic, aucune sélection à la manette, texte terne
			b.AutoButtonColor = false
			b.Active = false
			b.Selectable = false
			b.TextColor3 = COULEURS.grise
		end
	end
end

--- Crée le panneau dans l'interface `gui` (une seule fois). `retourManette` : l'objet qui reprend le curseur de la
--- manette quand on ferme (le bouton du menu en coin).
function MenuPaliers.monter(gui: ScreenGui, retourManette: GuiObject)
	if panneau then
		return
	end
	retour = retourManette
	remoteTeleport = Composants.remote("DemanderTeleportPalier")

	-- 46 % de la largeur (300 à 440 px), centré ; la hauteur suit le contenu (environ 290 px avec 5 paliers).
	local p = creer("Frame", {
		Name = "MenuPaliers",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.46, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, gui)
	panneau = p
	Composants.arrondir(p, 14)
	creer("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(440, 1000) }, p)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	}, p)
	creer("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, p)

	Composants.libelle(p, {
		Name = "Titre",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Text = Textes.paliersTitre,
		TextColor3 = COULEURS.or_,
		Font = Enum.Font.GothamBlack,
		TailleMax = 22,
	})
	Composants.libelle(p, {
		Name = "Avertissement",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		Text = Textes.paliersAvertissement,
		TextColor3 = COULEURS.discret,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TailleMax = 15,
	})
	local g = creer("Frame", {
		Name = "Grille",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, p)
	grille = g
	creer("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.new(0.48, 0, 0, 44), -- deux colonnes, des boutons d'au moins 44 px de haut
		CellPadding = UDim2.new(0.04, 0, 0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, g)

	local fermer = Composants.bouton(p, Textes.paliersFermer, COULEURS.vinci, 10)
	fermer.Name = "Fermer"
	fermer.LayoutOrder = 4
	fermer.Size = UDim2.new(0.5, 0, 0, 44)
	fermer.SelectionOrder = 20
	boutonFermer = fermer
	fermer.Activated:Connect(function()
		MenuPaliers.fermer()
	end)

	-- Les hauteurs des paliers : celles déjà chargées, puis celles que le streaming amènera.
	for _, objet in CollectionService:GetTagged(TAG_PALIER) do
		lirePalier(objet)
	end
	CollectionService:GetInstanceAddedSignal(TAG_PALIER):Connect(function(objet)
		lirePalier(objet)
		reconstruire()
	end)
end

--- L'état d'ascension a changé : la liste des paliers débloqués (numéros).
--- Le serveur renvoie l'état toutes les 2 s : on ne reconstruit les boutons que si la liste a réellement changé,
--- sinon la grille clignote, un clic tombe pendant la reconstruction et la manette perd son curseur.
function MenuPaliers.definirPaliers(paliers: any)
	local change = not Affichage.memesPaliers(debloques, paliers)
	debloques = {}
	if type(paliers) == "table" then
		for _, numero in paliers do
			if type(numero) == "number" then
				table.insert(debloques, numero)
			end
		end
	end
	if change and panneau and panneau.Visible then
		reconstruire()
	end
end

--- Le menu a-t-il quelque chose à proposer (au moins un palier débloqué) ?
function MenuPaliers.disponible(): boolean
	return Affichage.paliersDisponibles(debloques)
end

function MenuPaliers.estOuvert(): boolean
	return panneau ~= nil and panneau.Visible
end

--- Ouvre le panneau. Rend `false` (sans rien faire) quand il n'y a aucun palier débloqué ou pas de panneau.
function MenuPaliers.ouvrir(): boolean
	if not panneau or not MenuPaliers.disponible() then
		return false
	end
	for _, objet in CollectionService:GetTagged(TAG_PALIER) do
		lirePalier(objet)
	end
	reconstruire()
	panneau.Visible = true
	if GuiService.SelectedObject ~= nil and grille then
		-- manette : le curseur va sur le premier palier utilisable, sinon sur « Fermer »
		local premier: GuiObject? = nil
		for _, enfant in grille:GetChildren() do
			if
				enfant:IsA("GuiButton")
				and enfant.Selectable
				and (premier == nil or enfant.LayoutOrder < premier.LayoutOrder)
			then
				premier = enfant
			end
		end
		GuiService.SelectedObject = premier or boutonFermer
	end
	return true
end

--- Ferme le panneau. Rend `true` s'il était ouvert.
function MenuPaliers.fermer(): boolean
	if not panneau or not panneau.Visible then
		return false
	end
	panneau.Visible = false
	local selection = GuiService.SelectedObject
	if selection ~= nil and selection:IsDescendantOf(panneau) then
		GuiService.SelectedObject = retour -- à la manette, on ne perd pas le curseur
	end
	return true
end

--- Demande la téléportation vers un palier : l'intention part au serveur, qui vérifie et décide.
function MenuPaliers.demander(numero: number)
	if remoteTeleport and table.find(debloques, numero) then
		remoteTeleport:FireServer(numero)
	end
	MenuPaliers.fermer()
end

return MenuPaliers
