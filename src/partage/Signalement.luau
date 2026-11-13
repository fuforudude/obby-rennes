--!strict
-- La validation d'un « j'ai été touché par un événement » (RemoteEvent ToucheParEvenement), en fonction pure :
-- le service serveur (src/serveur/Evenements.luau) rassemble les données, ce module décide. Rien ici ne lit le jeu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Horaires = require(ReplicatedStorage.Partage.Horaires)

export type Raison =
	"trop_souvent"
	| "objet_invalide"
	| "pas_un_evenement"
	| "attributs_invalides"
	| "joueur_mort"
	| "danger_inactif"
	| "trop_loin"

export type Entree = {
	instant: number, -- l'horloge locale du serveur (os.clock), pour l'espacement des signalements
	dernierSignalement: number?, -- le même horodatage pour le dernier signalement de ce joueur, nil s'il n'y en a pas
	delaiMin: number, -- Reglages.EVENEMENT_DELAI_MIN
	objetValide: boolean, -- le paramètre est une Instance de la carte, Model ou BasePart
	avecTag: boolean, -- elle porte le tag Evenement
	attributs: { [string]: any }, -- ses attributs (GetAttributes)
	heureServeur: number, -- workspace:GetServerTimeNow(), pour savoir si le danger est actif
	tolerance: number, -- Reglages.EVENEMENT_TOLERANCE
	vivant: boolean, -- le personnage existe et son Humanoid a de la vie
	position: Vector3?, -- la position de sa racine ; nil sans personnage
	posee: Vector3, -- le pivot de l'objet tel que posé dans la carte
	demiTaille: number, -- la demi-diagonale de l'objet
	distanceMax: number, -- Reglages.EVENEMENT_DISTANCE_MAX
}

local Signalement = {}

--- Distance d'un point à un segment [a, b].
function Signalement.distanceAuSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local longueur2 = ab:Dot(ab)
	if longueur2 < 1e-9 then
		return (p - a).Magnitude
	end
	local u = math.clamp((p - a):Dot(ab) / longueur2, 0, 1)
	return (p - (a + ab * u)).Magnitude
end

--- Ce joueur signale-t-il trop vite ? Le service l'appelle d'abord, avant de rassembler le reste.
function Signalement.tropSouvent(instant: number, dernierSignalement: number?, delaiMin: number): boolean
	return dernierSignalement ~= nil and instant - dernierSignalement < delaiMin
end

--- Accepte ou refuse un signalement. Rend `true`, ou `false` et la raison du refus (à journaliser si utile).
--- L'ordre des vérifications va du moins cher au plus cher.
function Signalement.valider(e: Entree): (boolean, Raison?)
	if Signalement.tropSouvent(e.instant, e.dernierSignalement, e.delaiMin) then
		return false, "trop_souvent"
	end
	if not e.objetValide then
		return false, "objet_invalide"
	end
	if not e.avecTag then
		return false, "pas_un_evenement"
	end
	local params = Horaires.depuisAttributs(e.attributs)
	if not params then
		return false, "attributs_invalides"
	end
	local position = e.position
	if not e.vivant or not position then
		return false, "joueur_mort"
	end
	if not Horaires.actifAutour(e.heureServeur, params.periode, params.decalage, params.duree, e.tolerance) then
		return false, "danger_inactif"
	end

	-- Trajectoire telle que posée dans la carte : le segment du passage, ou la colonne de la chute.
	local distance
	if params.type == "Passage" then
		distance = Signalement.distanceAuSegment(position, params.depart :: Vector3, params.arrivee :: Vector3)
	else
		distance =
			Signalement.distanceAuSegment(position, e.posee, e.posee + Vector3.new(0, params.hauteur :: number, 0))
	end
	if distance > e.distanceMax + e.demiTaille then
		return false, "trop_loin"
	end
	return true, nil
end

return table.freeze(Signalement)
