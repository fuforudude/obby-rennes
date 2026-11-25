--!strict
-- Les deux boutons de coupure du son, « Musique » et « Effets », côte à côte en bas, juste au-dessus de la rangée des
-- capacités (IconesCapacites), à droite de la zone du joystick. Cachés tant que l'écran d'arrivée ou l'annonce d'un
-- déblocage est affiché. Un appui coupe ou remet ; le choix vaut pour la partie en cours (rien n'est
-- sauvegardé) et vit dans `Sons` : l'interface le relit, elle n'en garde pas de copie, donc il survit à la
-- réapparition. L'état se lit sans la couleur : deuxième ligne « activée » / « coupée », nom barré quand c'est coupé.
-- Placement : voir `monter`. Animation courte (couleur, 0,15 s) ; sélectionnables à la manette.
local GuiService = game:GetService("GuiService")

local Composants = require(script.Parent.Composants)
local Sons = require(script.Parent.Parent.Sons)
local Textes = require(script.Parent.Textes)

local COULEURS = Composants.COULEURS
local creer = Composants.creer
local jouer = Composants.jouer

local BoutonsSons = {}

local monte = false

--- Un bouton de coupure : `lireCoupe` donne l'état actuel dans `Sons`, `regler(b)` le change.
local function creerBouton(
	parent: Instance,
	ordre: number,
	textes: Textes.BoutonSon,
	lireCoupe: () -> boolean,
	regler: (boolean) -> ()
): TextButton
	local b = Composants.bouton(parent, "", COULEURS.vinci, 10)
	b.Name = textes.nom
	b.LayoutOrder = ordre
	b.SelectionOrder = 3 + ordre -- après Recommencer (1), le menu (2) et Passer l'étape (3)
	b.RichText = true -- le nom barré quand c'est coupé
	b.Size = UDim2.new(0.5, -3, 1, 0) -- la moitié de la rangée, moins la moitié de l'écart

	local function rafraichir()
		local coupe = lireCoupe()
		b.Text = Textes.boutonSon(textes, coupe)
		jouer(b, Composants.DUREE_FONDU, {
			BackgroundColor3 = if coupe then COULEURS.consomme else COULEURS.vinci,
			TextColor3 = if coupe then COULEURS.discret else COULEURS.texte,
		})
	end
	b.Activated:Connect(function()
		regler(not lireCoupe())
		rafraichir()
	end)
	rafraichir()
	return b
end

--- Crée les deux boutons dans l'interface `gui` (une seule fois).
-- Placement (paysage, l'orientation de l'expérience) : bord gauche à 40 % de la largeur + 8 px, juste à droite de la
-- zone du joystick dynamique de Roblox (40 % gauches, du tiers de la hauteur au bas : DynamicThumbstick.lua de
-- Roblox, version archivée du dépôt Core-Scripts) ; 70 px au-dessus du bord (la rangée des capacités monte au plus à
-- 62 px : 8 px de marge), 150 à 190 px de large et 44 à 56 px de haut, deux boutons de 72 à 92 px. Sur 667 x 375 :
-- x de 275 à 448, 70 à 114 px du bas ; à 41 px du bouton Course de Capacites.luau et loin du saut. Hors du menu
-- Roblox (haut gauche), du HUD et du menu en coin. En portrait (non prévu), la zone du joystick est tout le bas de
-- l'écran et le saut se trouverait mordu : à revoir si l'expérience passe en portrait.
function BoutonsSons.monter(gui: ScreenGui)
	if monte then
		return
	end
	monte = true

	local rangee = creer("Frame", {
		Name = "BoutonsSons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.4, 8, 1, -70), -- à droite de la zone du joystick dynamique de Roblox (40 % gauches)
		Size = UDim2.fromScale(0.26, 0.13),
		BackgroundTransparency = 1,
	}, gui)
	creer("UISizeConstraint", { MinSize = Vector2.new(150, 44), MaxSize = Vector2.new(190, 56) }, rangee)
	creer("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, rangee)

	creerBouton(rangee, 1, Textes.musique, Sons.musiqueCoupee, Sons.couperMusique)
	creerBouton(rangee, 2, Textes.effets, Sons.effetsCoupes, Sons.couperEffets)

	-- Cachée tant que l'écran d'arrivée ou l'annonce d'un déblocage est affiché (ils sont dans le même écran, créés
	-- avant) : on suit leur `Visible`, quelle que soit la façon dont ils apparaissent ou se ferment.
	local bloquants: { GuiObject } = {}
	for _, nom in { "Arrivee", "AnnonceCapacite" } do
		local objet = gui:FindFirstChild(nom)
		if objet and objet:IsA("GuiObject") then
			table.insert(bloquants, objet)
		else
			warn(`Interface : {nom} introuvable, les boutons de son ne se cachent pas pour lui`)
		end
	end
	local function majVisible()
		local cache = false
		for _, objet in bloquants do
			cache = cache or objet.Visible
		end
		rangee.Visible = not cache
		local selection = GuiService.SelectedObject
		if cache and selection ~= nil and selection:IsDescendantOf(rangee) then
			GuiService.SelectedObject = nil -- à la manette, pas de curseur sur un bouton caché
		end
	end
	for _, objet in bloquants do
		objet:GetPropertyChangedSignal("Visible"):Connect(majVisible)
	end
	majVisible()
end

return BoutonsSons
