--!strict
-- Tous les RemoteEvent du jeu, créés par le serveur et retrouvés par le client. Aucun n'est créé ailleurs.
--
-- Serveur → client
--   EtatCourse(etat: EtatCourse)      à chaque changement : étape, chrono, passages, record, aura, série
--   Arrivee(temps: number, classable: boolean, record: boolean, gainAura: number)
--   CapaciteDebloquee(capacite: string)  une capacité vient d'être débloquée ("course", "doubleSaut" ou "dash")
--   EtatAscension(etat: EtatAscension)  à chaque changement utile de l'ascension (pas à chaque image) : départ du
--                                     pied, étage, palier débloqué, téléportation, sommet, hauteur qui bouge
-- Client → serveur
--   DemanderRecommencer()             repartir de la coloc, chrono à zéro
--   ToucheParEvenement(objet: Instance)  « cet événement (tag Evenement) m'a touché » : le serveur vérifie que le
--                                     danger est actif et que le joueur est près, puis le tue (serveur/Evenements)
--   DemanderTeleportPalier(numero: number)  « téléporte-moi au palier numero » : le serveur vérifie que le palier
--                                     existe, qu'il est débloqué, que le joueur est dans l'ascension et qu'il ne
--                                     demande pas plus d'une fois toutes les PALIER_DELAI_TELEPORT secondes
--                                     (serveur/Ascension, règle pure dans partage/Ascension)
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

export type EtatAscension = {
	enAscension: boolean, -- le joueur est dans une tentative d'ascension (parti du pied)
	hauteur: number, -- hauteur actuelle au-dessus du pied, en studs (0 hors ascension)
	meilleureHauteur: number, -- record personnel sauvegardé, en studs
	paliers: { number }, -- numéros des paliers débloqués (la téléportation n'accepte que ceux-là)
	debut: number?, -- heure serveur du départ au pied ; nil = pas de chrono (sommet atteint, ou hors ascension)
	classable: boolean, -- ni téléportation ni alerte de surveillance pendant cette tentative
}

local NOMS = {
	"EtatCourse",
	"Arrivee",
	"CapaciteDebloquee",
	"EtatAscension",
	"DemanderRecommencer",
	"ToucheParEvenement",
	"DemanderTeleportPalier",
}
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
