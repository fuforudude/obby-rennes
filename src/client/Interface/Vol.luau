--!strict
-- La mention du mode vol (testeurs seulement) : une petite pastille en bas à gauche, deux lignes, « Vol actif » et
-- « Partie non classée ». Elle n'existe qu'entre un `EtatVol(true)` et le `EtatVol(false)` suivant du serveur : pour un
-- joueur qui ne reçoit jamais `true`, rien n'est créé, ni caché ni vide. Elle ne lit aucune touche et n'envoie rien.
-- Texte à taille fixe calculée (pas de TextScaled) d'après la hauteur de l'écran, bornée à 14-18 px ; la pastille
-- s'ajuste au texte (AutomaticSize), deux lignes courtes : elle tient dans un écran étroit. Fondu court, sans clignoter.
local Composants = require(script.Parent.Composants)
local Textes = require(script.Parent.Textes)

local COULEURS = Composants.COULEURS
local creer = Composants.creer
local jouer = Composants.jouer

local FOND_TRANSPARENCE = 0.25 -- comme le HUD (0,15), un peu plus discret

local Vol = {}

local monte = false

--- Taille de texte fixe : 2,2 % de la hauteur de l'écran, entre 14 et 18 px.
local function tailleTexte(ecran: ScreenGui): number
	return math.clamp(math.floor(ecran.AbsoluteSize.Y * 0.022), 14, 18)
end

--- Prépare l'écoute d'`EtatVol` dans l'interface `gui` (une seule fois). Ne crée aucun élément visuel.
function Vol.monter(gui: ScreenGui)
	if monte then
		return
	end
	monte = true
	local remote = Composants.remote("EtatVol")
	if not remote then
		return
	end

	local mention: Frame? = nil
	local connexionTaille: RBXScriptConnection? = nil

	local function retirer()
		local courante = mention
		if not courante then
			return
		end
		mention = nil
		if connexionTaille then
			connexionTaille:Disconnect()
			connexionTaille = nil
		end
		jouer(courante, Composants.DUREE_FONDU, { BackgroundTransparency = 1 })
		for _, enfant in courante:GetChildren() do
			if enfant:IsA("TextLabel") then
				jouer(enfant, Composants.DUREE_FONDU, { TextTransparency = 1 })
			end
		end
		task.delay(Composants.DUREE_FONDU, function()
			courante:Destroy() -- rien ne reste dans l'interface une fois la mention retirée
		end)
	end

	local function montrer()
		if mention then
			return
		end
		local pastille: Frame = creer("Frame", {
			Name = "Vol",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -10),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = COULEURS.fond,
			BackgroundTransparency = 1,
		}, gui)
		mention = pastille
		Composants.arrondir(pastille, 8)
		creer("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}, pastille)
		creer("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, pastille)

		local lignes: { TextLabel } = {}
		local function ligne(ordre: number, texte: string, couleur: Color3, police: Enum.Font)
			local l: TextLabel = creer("TextLabel", {
				LayoutOrder = ordre,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = texte,
				TextColor3 = couleur,
				Font = police,
				TextSize = tailleTexte(gui),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = 1,
			}, pastille)
			table.insert(lignes, l)
		end
		ligne(1, Textes.volActif, COULEURS.or_, Enum.Font.GothamBold)
		ligne(2, Textes.volNonClasse, COULEURS.texte, Enum.Font.Gotham)

		connexionTaille = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local taille = tailleTexte(gui)
			for _, l in lignes do
				l.TextSize = taille
			end
		end)

		jouer(pastille, Composants.DUREE_FONDU, { BackgroundTransparency = FOND_TRANSPARENCE })
		for _, l in lignes do
			jouer(l, Composants.DUREE_FONDU, { TextTransparency = 0 })
		end
	end

	remote.OnClientEvent:Connect(function(actif: any)
		if actif == true then
			montrer()
		else
			retirer()
		end
	end)
end

return Vol
