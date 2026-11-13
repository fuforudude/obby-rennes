--!strict
-- Les panneaux d'anecdote du décor : chaque pièce taguée `PanneauAnecdote` (attribut `Numero`, 0 à 15) porte un
-- SurfaceGui avec un TextLabel nommé `Texte`. Le client y écrit la zone, l'anecdote et la vanne de ce checkpoint
-- (Etapes.obtenir). Les panneaux ajoutés plus tard (carte en streaming, génération tardive) sont pris en charge.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Affichage = require(ReplicatedStorage.Partage.Affichage)
local Etapes = require(ReplicatedStorage.Partage.Etapes)

local TAG = "PanneauAnecdote"
local NOM_TEXTE = "Texte"

local Panneaux = {}

local monte = false
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

--- Écrit le texte du checkpoint dans le TextLabel « Texte » du panneau. Rend `true` s'il l'a trouvé.
local function remplir(panneau: Instance): boolean
	local numero = panneau:GetAttribute("Numero")
	local texte = panneau:FindFirstChild(NOM_TEXTE, true)
	if typeof(numero) ~= "number" or not texte or not texte:IsA("TextLabel") then
		return false
	end
	local etape = Etapes.obtenir(numero)
	if etape then
		texte.RichText = true -- titre en gras et vanne en italique (texte échappé par Affichage)
		texte.Text = Affichage.textePanneau(etape)
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
