--!strict
-- Les deux classements mondiaux, chacun dans un OrderedDataStore et sur ses panneaux de la carte :
-- - meilleurs temps (millisecondes, le plus petit gagne), panneaux tagués « TableauClassement » ;
-- - plus grosse aura (aura totale, la plus grande gagne), panneaux tagués « TableauAura ».
-- L'aura change à chaque checkpoint : elle n'est pas écrite à chaque fois, mais envoyée par lots (budget DataStore).
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)

type Tableau = {
	store: OrderedDataStore?,
	tag: string,
	croissant: boolean, -- true : le plus petit en tête (temps)
	formater: (number) -> string,
	vide: string,
}

local tableauTemps: Tableau = {
	store = nil,
	tag = "TableauClassement",
	croissant = true,
	formater = function(ms: number): string
		return Regles.formaterTemps(ms / 1000)
	end,
	vide = "Personne n'a encore eu son partiel.\nSois le premier !",
}

local tableauAura: Tableau = {
	store = nil,
	tag = "TableauAura",
	croissant = false,
	formater = Regles.formaterAura,
	vide = "Aucune aura pour l'instant.\nVa la chercher.",
}

local noms: { [number]: string } = {}
local auraEnAttente: { [number]: number } = {} -- UserId → dernière aura pas encore écrite

local function nomDe(idJoueur: number): string
	if noms[idJoueur] then
		return noms[idJoueur]
	end
	local ok, nom = pcall(Players.GetNameFromUserIdAsync, Players, idJoueur)
	local resultat = if ok and typeof(nom) == "string" then nom else "?"
	noms[idJoueur] = resultat
	return resultat
end

--- Écrit `texte` sur les panneaux du tableau. Un message court (vide, indisponible) est centré ; la liste des scores
--- est alignée en haut à gauche (le label `Liste` a une taille de texte fixe, prévue pour TAILLE_CLASSEMENT lignes).
local function afficher(tableau: Tableau, texte: string, centre: boolean)
	for _, panneau in CollectionService:GetTagged(tableau.tag) do
		local gui = panneau:FindFirstChildOfClass("SurfaceGui")
		local liste = gui and gui:FindFirstChild("Liste")
		if liste and liste:IsA("TextLabel") then
			liste.Text = texte
			liste.TextXAlignment = if centre then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			liste.TextYAlignment = if centre then Enum.TextYAlignment.Center else Enum.TextYAlignment.Top
		end
	end
end

local function rafraichirTableau(tableau: Tableau)
	local store = tableau.store
	if not store then
		afficher(tableau, "Classement indisponible", true)
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(tableau.croissant, Reglages.TAILLE_CLASSEMENT):GetCurrentPage()
	end)
	if not ok then
		afficher(tableau, "Classement indisponible pour l'instant", true)
		return
	end
	local lignes = {}
	for rang, entree in page do
		local id = tonumber(entree.key)
		local nom = if id then nomDe(id) else "?"
		table.insert(
			lignes,
			string.format("%2d. %-14s %s", rang, string.sub(nom, 1, 14), tableau.formater(entree.value))
		)
	end
	if #lignes > 0 then
		afficher(tableau, table.concat(lignes, "\n"), false)
	else
		afficher(tableau, tableau.vide, true)
	end
end

--- Écrit `valeur` pour ce joueur si elle est meilleure que celle déjà classée. Rend true si l'écriture a abouti.
local function ecrire(tableau: Tableau, idJoueur: number, valeur: number): boolean
	local store = tableau.store
	if not store then
		return false
	end
	local ok, erreur = pcall(function()
		store:UpdateAsync(tostring(idJoueur), function(ancien)
			if typeof(ancien) == "number" then
				local meilleur = if tableau.croissant then ancien <= valeur else ancien >= valeur
				if meilleur then
					return nil -- on garde la valeur déjà classée
				end
			end
			return valeur
		end)
	end)
	if not ok then
		warn(`[Classement] {tableau.tag} : valeur non enregistrée ({erreur})`)
	end
	return ok
end

local Classement = {}

--- Relit les deux classements et met les panneaux à jour.
function Classement.rafraichir()
	rafraichirTableau(tableauTemps)
	rafraichirTableau(tableauAura)
end

--- Enregistre un temps (en secondes) s'il bat celui déjà classé pour ce joueur. Ne bloque pas l'appelant.
function Classement.soumettre(joueur: Player, secondes: number)
	local id = joueur.UserId
	task.spawn(function()
		if ecrire(tableauTemps, id, Regles.versMillisecondes(secondes)) then
			rafraichirTableau(tableauTemps)
		end
	end)
end

--- Note la nouvelle aura du joueur ; elle partira au prochain lot (ou à son départ).
function Classement.signalerAura(joueur: Player, aura: number)
	auraEnAttente[joueur.UserId] = math.floor(aura)
end

--- Écrit tout de suite l'aura en attente de ce joueur (à son départ). Ne bloque pas l'appelant.
function Classement.envoyerAura(joueur: Player)
	local id = joueur.UserId
	local aura = auraEnAttente[id]
	if aura == nil then
		return
	end
	auraEnAttente[id] = nil
	task.spawn(ecrire, tableauAura, id, aura)
end

local function envoyerLot()
	local lot = auraEnAttente
	auraEnAttente = {}
	for id, aura in lot do
		if aura > 0 and not ecrire(tableauAura, id, aura) and auraEnAttente[id] == nil then
			auraEnAttente[id] = aura -- échec : on réessaiera au prochain lot
		end
	end
end

local function ouvrir(nom: string): OrderedDataStore?
	local ok, resultat = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, nom)
	if ok then
		return resultat
	end
	warn(`[Classement] DataStore {nom} inaccessible : {resultat}`)
	return nil
end

function Classement.demarrer()
	tableauTemps.store = ouvrir(Reglages.STORE_CLASSEMENT)
	tableauAura.store = ouvrir(Reglages.STORE_AURA)
	task.spawn(function()
		while true do
			envoyerLot()
			Classement.rafraichir()
			task.wait(Reglages.DELAI_RAFRAICHIR_CLASSEMENT)
		end
	end)
end

return Classement
