--!strict
-- Les classements mondiaux, chacun dans un OrderedDataStore et sur ses panneaux de la carte :
-- - meilleurs temps du tuto (millisecondes, le plus petit gagne), panneaux tagués « TableauClassement » ;
-- - plus grosse aura (aura totale, la plus grande gagne), panneaux tagués « TableauAura » ;
-- - plus grande hauteur atteinte dans l'ascension (studs, la plus grande gagne), panneaux « TableauHauteur » ;
-- - meilleur chrono de l'ascension (millisecondes, le plus petit gagne), panneaux « TableauAscension ».
-- Une valeur qui bouge sans arrêt (l'aura à chaque checkpoint, la hauteur à chaque relevé) n'est pas écrite à
-- chaque fois : elle est notée dans `enAttente` et envoyée par lots, ou tout de suite au départ du joueur
-- (budget DataStore). Un record rare (une arrivée, un sommet) est écrit au moment où il est soumis.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ascension = require(ReplicatedStorage.Partage.Ascension)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)

type Tableau = {
	store: OrderedDataStore?,
	tag: string,
	croissant: boolean, -- true : le plus petit en tête (temps)
	formater: (number) -> string,
	vide: string,
	-- UserId → valeur notée pas encore écrite, pour les tableaux envoyés par lots. nil : écriture à la soumission.
	enAttente: { [number]: number }?,
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
	enAttente = {},
}

local tableauHauteur: Tableau = {
	store = nil,
	tag = "TableauHauteur",
	croissant = false,
	formater = Ascension.formaterHauteur,
	vide = "Personne n'est encore monté.\nLève la tête.",
	enAttente = {},
}

local tableauAscension: Tableau = {
	store = nil,
	tag = "TableauAscension",
	croissant = true,
	formater = function(ms: number): string
		return Regles.formaterTemps(ms / 1000)
	end,
	vide = "Personne n'a encore touché le sommet.\nVas-y.",
}

-- Tous les tableaux, dans l'ordre où ils s'affichent et s'envoient.
local tableaux: { Tableau } = { tableauTemps, tableauAura, tableauHauteur, tableauAscension }

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

--- Soumet une valeur à un tableau : écrite tout de suite si elle bat celle déjà classée. Ne bloque pas l'appelant.
local function soumettre(tableau: Tableau, joueur: Player, valeur: number)
	local id = joueur.UserId
	task.spawn(function()
		if ecrire(tableau, id, valeur) then
			rafraichirTableau(tableau)
		end
	end)
end

--- Note une valeur qui bouge souvent : elle partira au prochain lot (ou au départ du joueur).
local function signaler(tableau: Tableau, joueur: Player, valeur: number)
	local attente = tableau.enAttente
	if attente then
		attente[joueur.UserId] = math.floor(valeur)
	end
end

--- Écrit tout de suite la valeur en attente de ce joueur (à son départ). Ne bloque pas l'appelant.
local function envoyerMaintenant(tableau: Tableau, joueur: Player)
	local attente = tableau.enAttente
	local id = joueur.UserId
	local valeur = if attente then attente[id] else nil
	if not attente or valeur == nil then
		return
	end
	attente[id] = nil
	task.spawn(ecrire, tableau, id, valeur)
end

local function envoyerLot(tableau: Tableau)
	local lot = tableau.enAttente
	if not lot then
		return
	end
	local suite: { [number]: number } = {}
	tableau.enAttente = suite
	for id, valeur in lot do
		if valeur > 0 and not ecrire(tableau, id, valeur) and suite[id] == nil then
			suite[id] = valeur -- échec : on réessaiera au prochain lot
		end
	end
end

local Classement = {}

--- Relit tous les classements et met les panneaux à jour.
function Classement.rafraichir()
	for _, tableau in tableaux do
		rafraichirTableau(tableau)
	end
end

--- Enregistre un temps de parcours (en secondes) s'il bat celui déjà classé pour ce joueur.
function Classement.soumettre(joueur: Player, secondes: number)
	soumettre(tableauTemps, joueur, Regles.versMillisecondes(secondes))
end

--- Enregistre un chrono d'ascension (en secondes) s'il bat celui déjà classé pour ce joueur.
function Classement.soumettreAscension(joueur: Player, secondes: number)
	soumettre(tableauAscension, joueur, Regles.versMillisecondes(secondes))
end

--- Note la nouvelle aura du joueur ; elle partira au prochain lot (ou à son départ).
function Classement.signalerAura(joueur: Player, aura: number)
	signaler(tableauAura, joueur, aura)
end

--- Écrit tout de suite l'aura en attente de ce joueur (à son départ). Ne bloque pas l'appelant.
function Classement.envoyerAura(joueur: Player)
	envoyerMaintenant(tableauAura, joueur)
end

--- Note la nouvelle hauteur maximale du joueur (en studs) ; elle partira au prochain lot (ou à son départ).
function Classement.signalerHauteur(joueur: Player, studs: number)
	signaler(tableauHauteur, joueur, studs)
end

--- Écrit tout de suite la hauteur en attente de ce joueur (à son départ). Ne bloque pas l'appelant.
function Classement.envoyerHauteur(joueur: Player)
	envoyerMaintenant(tableauHauteur, joueur)
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
	tableauHauteur.store = ouvrir(Reglages.STORE_HAUTEUR)
	tableauAscension.store = ouvrir(Reglages.STORE_ASCENSION)
	task.spawn(function()
		while true do
			for _, tableau in tableaux do
				envoyerLot(tableau)
			end
			Classement.rafraichir()
			task.wait(Reglages.DELAI_RAFRAICHIR_CLASSEMENT)
		end
	end)
end

return Classement
