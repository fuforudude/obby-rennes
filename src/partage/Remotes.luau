--!strict
-- Tous les RemoteEvent du jeu, créés par le serveur et retrouvés par le client. Aucun n'est créé ailleurs.
--
-- Serveur → client
--   EtatCourse(etat: EtatCourse)      à chaque changement : étape, chrono, passages, record, aura, série, capacités
--                                     débloquées. La charge se construit par `Remotes.etatCourse`, fonction pure
--                                     dont la forme est testée (tests/partage/Remotes.spec.luau) : un champ oublié
--                                     ne casse aucune règle mais rend une information invisible au client.
--   Arrivee(temps: number, classable: boolean, record: boolean, gainAura: number)
--   CapaciteDebloquee(capacite: string)  une capacité vient d'être débloquée ("course", "doubleSaut" ou "dash")
--   EtatAscension(etat: EtatAscension)  à chaque changement utile de l'ascension (pas à chaque image) : départ du
--                                     pied, étage, sommet, hauteur qui bouge
--   EffetCapacite(joueur: Player, capacite: string)  « ce joueur vient de faire un dash ou un double saut » : les
--                                     autres clients jouent l'effet (vrille, traînée, onde) sur son personnage.
--                                     Envoyé à tous les joueurs SAUF celui d'origine ; capacite = "dash" ou "doubleSaut"
-- Client → serveur
--   DemanderRecommencer()             repartir de la coloc, chrono à zéro
--   ToucheParEvenement(objet: Instance)  « cet événement (tag Evenement) m'a touché » : le serveur vérifie que le
--                                     danger est actif et que le joueur est près, puis le tue (serveur/Evenements)
--   SignalerEffet(capacite: string)    « j'ai fait un dash / un double saut » (effet déjà joué chez moi) : le serveur
--                                     vérifie le type, la capacité (débloquée), que le joueur est vivant et la cadence
--                                     (au plus un par capacité toutes les EFFET_DELAI_MIN s), puis relaie EffetCapacite
--                                     (serveur/Capacites, règle pure dans partage/EffetsCapacites)
-- (« Passer l'étape » passe par MarketplaceService : le client affiche l'achat, le serveur le traite.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Capacites = require(ReplicatedStorage.Partage.Capacites)

export type EtatCourse = {
	etape: number,
	debut: number?,
	passages: number,
	reprise: boolean,
	meilleurTemps: number,
	aura: number,
	serie: number,
	capacites: { [string]: boolean }, -- capacités débloquées : seule source du client quand il arrive sur le serveur
}

-- Ce que `etatCourse` lit : les données sauvegardées du joueur (partage/Regles.Donnees) et sa course en cours
-- (Regles.Course). Décrits par leur forme pour que ce module ne dépende de rien.
export type DonneesCourse = { etape: number, meilleurTemps: number, aura: number }
export type CourseEnCours = { debut: number?, passages: number, reprise: boolean, serie: number }

export type EtatAscension = {
	enAscension: boolean, -- le joueur est dans une tentative d'ascension (parti du pied)
	hauteur: number, -- hauteur actuelle au-dessus du pied, en studs (0 hors ascension)
	meilleureHauteur: number, -- record personnel sauvegardé, en studs
	debut: number?, -- heure serveur du départ au pied ; nil = pas de chrono (sommet atteint, ou hors ascension)
	classable: boolean, -- aucune alerte de surveillance pendant cette tentative
}

local NOMS = {
	"EtatCourse",
	"Arrivee",
	"CapaciteDebloquee",
	"EtatAscension",
	"DemanderRecommencer",
	"ToucheParEvenement",
	"EffetCapacite",
	"SignalerEffet",
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

--- Construit la charge du remote EtatCourse. Pure et testée : c'est le contrat entre le serveur et le client, et
--- un champ oublié ne se voit dans aucun test de règle (c'est comme ça que `capacites` en avait disparu, laissant
--- un joueur de retour avec ses capacités sauvegardées mais inutilisables jusqu'à son prochain déblocage).
--- `capacites` est recopié : seules les capacités connues et vraiment débloquées partent, et le client ne reçoit
--- jamais la table du serveur.
function Remotes.etatCourse(
	donnees: DonneesCourse,
	course: CourseEnCours,
	capacites: { [string]: boolean }?
): EtatCourse
	local debloquees: { [string]: boolean } = {}
	if typeof(capacites) == "table" then
		for nom, valeur in capacites :: { [string]: boolean } do
			if valeur == true and Capacites.estCapacite(nom) then
				debloquees[nom] = true
			end
		end
	end
	return {
		etape = donnees.etape,
		debut = course.debut,
		passages = course.passages,
		reprise = course.reprise,
		meilleurTemps = donnees.meilleurTemps,
		aura = donnees.aura,
		serie = course.serie,
		capacites = debloquees,
	}
end

function Remotes.obtenir(nom: string): RemoteEvent
	assert(table.find(NOMS, nom), `Remote inconnu : {nom}`)
	return dossier():WaitForChild(nom) :: RemoteEvent
end

return Remotes
