--!strict
-- Tous les RemoteEvent du jeu, créés par le serveur et retrouvés par le client. Aucun n'est créé ailleurs.
--
-- Serveur → client
--   EtatCourse(etat: EtatCourse)      à chaque changement : étape, chrono, passages, record, aura, série
--   Arrivee(temps: number, classable: boolean, record: boolean, gainAura: number)
-- Client → serveur
--   DemanderRecommencer()             repartir de la coloc, chrono à zéro
--   ToucheParEvenement(objet: Instance)  « cet événement (tag Evenement) m'a touché » : le serveur vérifie que le
--                                     danger est actif et que le joueur est près, puis le tue (serveur/Evenements)
-- (« Passer l'étape » passe par MarketplaceService : le client affiche l'achat, le serveur le traite.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EtatCourse = {
	etape: number,
	debut: number?,
	passages: number,
	reprise: boolean,
	meilleurTemps: number,
	aura: number,
	serie: number,
}

local NOMS = { "EtatCourse", "Arrivee", "DemanderRecommencer", "ToucheParEvenement" }
local NOM_DOSSIER = "Remotes"

local function dossier(): Instance
	if RunService:IsServer() then
		local existant = ReplicatedStorage:FindFirstChild(NOM_DOSSIER)
		if existant then
			return existant
		end
		local d = Instance.new("Folder")
		d.Name = NOM_DOSSIER
		for _, nom in NOMS do
			local r = Instance.new("RemoteEvent")
			r.Name = nom
			r.Parent = d
		end
		d.Parent = ReplicatedStorage
		return d
	end
	return ReplicatedStorage:WaitForChild(NOM_DOSSIER)
end

local Remotes = {}

function Remotes.obtenir(nom: string): RemoteEvent
	assert(table.find(NOMS, nom), `Remote inconnu : {nom}`)
	return dossier():WaitForChild(nom) :: RemoteEvent
end

return Remotes
