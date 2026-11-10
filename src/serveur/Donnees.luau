--!strict
-- Le seul module qui touche aux données sauvegardées des joueurs. ProfileStore (Wally) gère les DataStore :
-- verrou de session (deux serveurs n'écrivent jamais en même temps), sauvegardes périodiques, et à la fermeture.
-- Voir docs/adr/0001-profilestore.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore) :: any

type Donnees = Regles.Donnees

local DELAI_MAX_SAUVEGARDE = 15 -- secondes

local profils: { [Player]: any } = {}
local abonnes: { (Player, Donnees) -> () } = {}
local store: any = nil

local Donnees = {}

--- Les données du joueur, ou nil tant qu'elles ne sont pas chargées (il ne joue pas encore).
function Donnees.obtenir(joueur: Player): Donnees?
	local profil = profils[joueur]
	return if profil then profil.Data else nil
end

--- Appelle `fonction` chaque fois que les données d'un joueur sont prêtes.
function Donnees.surChargement(fonction: (Player, Donnees) -> ())
	table.insert(abonnes, fonction)
end

--- Sauvegarde tout de suite et attend la fin de l'écriture. Sert aux achats Robux : la récompense doit être
--- enregistrée avant de confirmer l'achat. Rend false si l'écriture n'a pas abouti à temps.
function Donnees.sauvegarderMaintenant(joueur: Player): boolean
	local profil = profils[joueur]
	if not profil or not profil:IsActive() then
		return false
	end
	local fini = false
	local connexion = profil.OnAfterSave:Connect(function()
		fini = true
	end)
	profil:Save()
	local debut = os.clock()
	while not fini and os.clock() - debut < DELAI_MAX_SAUVEGARDE and profil:IsActive() do
		task.wait(0.1)
	end
	connexion:Disconnect()
	return fini
end

local function charger(joueur: Player)
	local profil = store:StartSessionAsync(tostring(joueur.UserId), {
		Cancel = function()
			return joueur.Parent ~= Players
		end,
	})
	if profil == nil then
		-- Données inaccessibles : on ne laisse pas jouer avec des données vides qui écraseraient la sauvegarde.
		if joueur.Parent == Players then
			joueur:Kick("Impossible de charger ta progression. Réessaie dans un instant.")
		end
		return
	end
	profil:AddUserId(joueur.UserId) -- RGPD : permet de retrouver et d'effacer les données d'un joueur
	profil.Data = Regles.migrer(profil.Data, Reglages.NB_ETAPES)
	profil.OnSessionEnd:Connect(function()
		profils[joueur] = nil
		joueur:Kick("Ta progression a été ouverte sur un autre serveur.")
	end)
	if joueur.Parent ~= Players then
		profil:EndSession()
		return
	end
	profils[joueur] = profil
	for _, fonction in abonnes do
		task.spawn(fonction, joueur, profil.Data)
	end
end

function Donnees.demarrer()
	store = ProfileStore.New(Reglages.STORE_JOUEURS, Regles.donneesNeuves())
	Players.PlayerAdded:Connect(charger)
	for _, joueur in Players:GetPlayers() do
		task.spawn(charger, joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		local profil = profils[joueur]
		if profil then
			profils[joueur] = nil
			profil:EndSession()
		end
	end)
end

return Donnees
