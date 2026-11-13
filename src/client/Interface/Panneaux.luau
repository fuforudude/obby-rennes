--!strict
-- Les panneaux d'anecdote du décor : chaque pièce taguée `PanneauAnecdote` (attribut `Numero`, 0 à 15) porte un
-- SurfaceGui avec deux TextLabel : `Titre` (le nom de la zone) et `Corps` (l'anecdote, une ligne vide, puis la vanne),
-- en texte simple, sans RichText : la taille du texte est réglée par la carte. Le client y écrit ce que dit
-- Etapes.obtenir pour ce checkpoint. Les panneaux ajoutés plus tard (carte en streaming, génération tardive) sont
-- pris en charge. Si la carte est une ancienne version (un seul label `Texte`), on prévient une fois et on ignore.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Affichage = require(ReplicatedStorage.Partage.Affichage)
local Etapes = require(ReplicatedStorage.Partage.Etapes)

local TAG = "PanneauAnecdote"
local NOM_TITRE = "Titre"
local NOM_CORPS = "Corps"

local Panneaux = {}

local monte = false
local avertiAncienneCarte = false
-- Les connexions de chaque panneau, coupées quand il disparaît (stream-out, destruction, retrait du tag).
local connexions: { [Instance]: { RBXScriptConnection } } = {}

local function oublier(panneau: Instance)
	local liste = connexions[panneau]
	if liste then
		for _, c in liste do
			c:Disconnect()
		end
		connexions[panneau] = nil
	end
end

--- Écrit le texte du checkpoint dans les TextLabel « Titre » et « Corps » du panneau. Rend `true` s'ils sont là.
local function remplir(panneau: Instance): boolean
	local numero = panneau:GetAttribute("Numero")
	if typeof(numero) ~= "number" then
		return false
	end
	local titre = panneau:FindFirstChild(NOM_TITRE, true)
	local corps = panneau:FindFirstChild(NOM_CORPS, true)
	if not (titre and titre:IsA("TextLabel") and corps and corps:IsA("TextLabel")) then
		-- Ancienne carte (label `Texte` seul) : on prévient une fois. Sinon, le SurfaceGui n'est pas encore arrivé.
		local ancien = panneau:FindFirstChild("Texte", true)
		if ancien and ancien:IsA("TextLabel") and not avertiAncienneCarte then
			avertiAncienneCarte = true
			warn(
				`[Panneaux] {panneau:GetFullName()} : label « Texte » sans « Titre » ni « Corps » (ancienne carte), ignoré`
			)
		end
		return false
	end
	local etape = Etapes.obtenir(numero)
	if etape then
		titre.RichText = false
		corps.RichText = false
		titre.Text, corps.Text = Affichage.textePanneau(etape)
	end
	return true
end

local function suivre(panneau: Instance)
	if connexions[panneau] then
		return
	end
	local liste: { RBXScriptConnection } = {}
	connexions[panneau] = liste
	local function essayer()
		remplir(panneau)
	end
	-- Le SurfaceGui, son TextLabel ou l'attribut peuvent arriver après la pièce : on réécrit quand ils apparaissent.
	table.insert(liste, panneau.DescendantAdded:Connect(essayer))
	table.insert(liste, panneau:GetAttributeChangedSignal("Numero"):Connect(essayer))
	table.insert(
		liste,
		panneau.Destroying:Connect(function()
			oublier(panneau)
		end)
	)
	essayer()
end

function Panneaux.monter()
	if monte then
		return
	end
	monte = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(suivre)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(oublier)
	for _, panneau in CollectionService:GetTagged(TAG) do
		suivre(panneau)
	end
end

--- Les panneaux sont dans le décor : ils s'affichent d'eux-mêmes. Rien à montrer ou cacher à l'écran.
function Panneaux.afficher() end
function Panneaux.cacher() end

return Panneaux
