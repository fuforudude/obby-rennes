--!strict
-- Classement mondial des meilleurs temps : OrderedDataStore (meilleur temps de chaque joueur, en millisecondes),
-- affiché sur les panneaux tagués « TableauClassement » de la carte.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)

local store: OrderedDataStore? = nil
local noms: { [number]: string } = {}

local function nomDe(idJoueur: number): string
	if noms[idJoueur] then
		return noms[idJoueur]
	end
	local ok, nom = pcall(Players.GetNameFromUserIdAsync, Players, idJoueur)
	local resultat = if ok and typeof(nom) == "string" then nom else "?"
	noms[idJoueur] = resultat
	return resultat
end

local function afficher(texte: string)
	for _, tableau in CollectionService:GetTagged("TableauClassement") do
		local gui = tableau:FindFirstChildOfClass("SurfaceGui")
		local liste = gui and gui:FindFirstChild("Liste")
		if liste and liste:IsA("TextLabel") then
			liste.Text = texte
		end
	end
end

local Classement = {}

--- Relit les meilleurs temps et met les panneaux à jour.
function Classement.rafraichir()
	if not store then
		afficher("Classement indisponible")
		return
	end
	local ok, page = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(true, Reglages.TAILLE_CLASSEMENT):GetCurrentPage()
	end)
	if not ok then
		afficher("Classement indisponible pour l'instant")
		return
	end
	local lignes = {}
	for rang, entree in page do
		local id = tonumber(entree.key)
		local nom = if id then nomDe(id) else "?"
		table.insert(
			lignes,
			string.format("%2d. %-18s %s", rang, string.sub(nom, 1, 18), Regles.formaterTemps(entree.value / 1000))
		)
	end
	afficher(
		if #lignes > 0 then table.concat(lignes, "\n") else "Personne n'a encore eu son partiel.\nSois le premier !"
	)
end

--- Enregistre un temps (en secondes) s'il bat celui déjà classé pour ce joueur. Ne bloque pas l'appelant.
function Classement.soumettre(joueur: Player, secondes: number)
	if not store then
		return
	end
	local ms = Regles.versMillisecondes(secondes)
	local cle = tostring(joueur.UserId)
	task.spawn(function()
		local ok, erreur = pcall(function()
			(store :: OrderedDataStore):UpdateAsync(cle, function(ancien)
				if typeof(ancien) == "number" and ancien <= ms then
					return nil -- garde le meilleur temps déjà classé
				end
				return ms
			end)
		end)
		if not ok then
			warn(`[Classement] temps non enregistré : {erreur}`)
			return
		end
		Classement.rafraichir()
	end)
end

function Classement.demarrer()
	local ok, resultat = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Reglages.STORE_CLASSEMENT)
	if ok then
		store = resultat
	else
		warn(`[Classement] DataStore inaccessible : {resultat}`)
	end
	task.spawn(function()
		while true do
			Classement.rafraichir()
			task.wait(Reglages.DELAI_RAFRAICHIR_CLASSEMENT)
		end
	end)
end

return Classement
