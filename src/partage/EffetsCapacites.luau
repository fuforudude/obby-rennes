--!strict
-- Les règles des effets visuels du dash et du double saut, en fonctions pures (sans Roblox) : ce que teste
-- tests/partage/EffetsCapacites.spec.luau. Le client (client/EffetsVisuels.luau) les applique, le serveur
-- (serveur/Capacites.luau) s'en sert pour valider les signalements d'effet.
--
-- Réplication : le client qui déclenche la capacité joue son effet tout de suite, puis envoie SignalerEffet(capacite).
-- Le serveur décide ici (accepter) s'il relaie ; les autres clients rejouent l'effet sur son personnage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Signalement = require(ReplicatedStorage.Partage.Signalement)

export type Raison = "mauvais_type" | "pas_replicable" | "trop_souvent" | "joueur_mort" | "pas_debloquee"

-- Ce que `accepter` doit savoir du joueur, rassemblé par le service seulement si la cadence passe.
export type Entree = {
	vivant: boolean, -- le personnage existe et son Humanoid a de la vie
	debloquees: { [string]: boolean }, -- les capacités débloquées du joueur
}

-- Ce que le client joue pour une capacité. Chaque champ est un morceau d'effet, vrai ou faux.
export type Plan = {
	inclinaison: boolean, -- le corps se penche en avant (rotation calculée)
	vrille: boolean, -- le corps fait un tour complet (rotation calculée)
	animation: string?, -- l'animation Roblox à jouer à la place de la rotation calculée, si elle est renseignée
	trainee: boolean, -- une traînée derrière le personnage
	lignes: boolean, -- des lignes de vitesse
	choc: boolean, -- un petit choc de particules au point d'arrivée
	onde: boolean, -- un anneau qui part sous les pieds
}

export type Anneau = {
	rayonDepart: number, -- rayon extérieur au déclenchement
	rayonFin: number, -- rayon extérieur à la fin
	interieurDepart: number, -- rayon intérieur au déclenchement
	interieurFin: number, -- rayon intérieur à la fin (l'anneau reste fin : la bande grandit un peu moins vite)
}

-- Les capacités dont l'effet se voit chez les autres. La course a un effet purement local (champ de vision, traînée au
-- sol), qui n'est pas relayé : c'est un état tenu, pas un événement.
local REPLICABLES: { string } = table.freeze({ "dash", "doubleSaut" })

local PREFIXE_ANIMATION = "rbxassetid://"

local EffetsCapacites = {}

--- `valeur` est-elle une capacité dont l'effet se relaie aux autres joueurs ?
function EffetsCapacites.estReplicable(valeur: any): boolean
	return typeof(valeur) == "string" and table.find(REPLICABLES, valeur) ~= nil
end

--- Un identifiant d'animation Roblox est-il utilisable ? Faux pour "" (emplacement vide) et pour tout ce qui n'est pas
--- « rbxassetid:// » suivi de chiffres.
function EffetsCapacites.animationValide(identifiant: any): boolean
	if typeof(identifiant) ~= "string" then
		return false
	end
	local chiffres = string.match(identifiant, "^" .. PREFIXE_ANIMATION .. "(%d+)$")
	return chiffres ~= nil
end

--- Le serveur relaie-t-il ce signalement d'effet ? Rend `true`, ou `false` et la raison.
--- `derniers` : l'heure du dernier signalement ACCEPTÉ de CE joueur, par capacité (table qui vit entre les appels, une
--- par joueur). `entree` n'est appelée que si le type et la cadence passent : les rafales sont écartées avant de
--- rassembler quoi que ce soit dans le jeu.
--- Piège de Signalement.traiter, évité ici : il note l'heure dès que la cadence passe, validation ou non. Ici l'heure
--- n'est notée QU'APRÈS la validation : un message refusé (joueur mort, capacité pas débloquée) ne bloque pas le
--- signalement légitime qui suit. Un refus de cadence ne repousse jamais l'heure notée.
--- La cadence est par capacité : un dash suivi d'un double saut en moins de `delai` est légitime.
function EffetsCapacites.accepter(
	derniers: { [string]: number },
	capacite: any,
	instant: number,
	delai: number,
	entree: () -> Entree
): (boolean, Raison?)
	if typeof(capacite) ~= "string" then
		return false, "mauvais_type"
	end
	if not EffetsCapacites.estReplicable(capacite) then
		return false, "pas_replicable"
	end
	if Signalement.tropSouvent(instant, derniers[capacite], delai) then
		return false, "trop_souvent"
	end
	local e = entree()
	if not e.vivant then
		return false, "joueur_mort"
	end
	if e.debloquees[capacite] ~= true then
		return false, "pas_debloquee"
	end
	derniers[capacite] = instant
	return true, nil
end

--- Le client doit-il rejouer l'effet d'un joueur qui se trouve à cette distance de lui ?
function EffetsCapacites.assezProche(distance: number, distanceMax: number): boolean
	return distance == distance and distance <= distanceMax
end

--- Ce qu'il faut jouer pour une capacité. `animation` est l'emplacement de Reglages (ANIMATION_DASH...) : s'il est
--- renseigné et valide, l'animation remplace la rotation calculée (le reste des effets ne change pas).
function EffetsCapacites.plan(capacite: string, animation: string?): Plan?
	local animee = EffetsCapacites.animationValide(animation)
	local animationJouee: string? = if animee then animation else nil
	if capacite == "dash" then
		return {
			inclinaison = not animee,
			vrille = false,
			animation = animationJouee,
			trainee = true,
			lignes = true,
			choc = true,
			onde = false,
		}
	elseif capacite == "doubleSaut" then
		return {
			inclinaison = false,
			vrille = not animee,
			animation = animationJouee,
			trainee = true,
			lignes = false,
			choc = false,
			onde = true,
		}
	end
	return nil
end

--- La durée (secondes) de la partie « en mouvement » de l'effet : pendant le dash, ou pendant la vrille.
function EffetsCapacites.duree(capacite: string): number
	if capacite == "dash" then
		return Reglages.DASH_DUREE
	elseif capacite == "doubleSaut" then
		return Reglages.VRILLE_DUREE
	end
	return 0
end

--- La durée (secondes) de la traînée derrière le personnage, une fois l'effet fini (le temps qu'elle s'efface).
function EffetsCapacites.dureeTrainee(capacite: string): number
	if capacite == "dash" then
		return Reglages.DASH_TRAINEE_DUREE
	elseif capacite == "doubleSaut" then
		return Reglages.VRILLE_TRAINEE_DUREE
	end
	return 0
end

--- L'angle du saut périlleux (radians, toujours >= 0 : le tour vers l'avant, que le client applique en négatif sur
--- l'axe X) à l'avancement `avancement` (0 au début, 1 à la fin ; borné). Un tour complet en tout.
function EffetsCapacites.angleVrille(avancement: number): number
	return 2 * math.pi * math.clamp(avancement, 0, 1)
end

-- Le profil du penché : monte vite, tient, redescend. Avancement en entrée, 0 à 1 en sortie.
local MONTEE = 0.25 -- part de la durée passée à se pencher
local DESCENTE = 0.35 -- part de la durée passée à se redresser

--- L'angle du corps penché en avant (radians, >= 0) à l'avancement `avancement`, pour un penché maximal de
--- `maxDegres`. 0 au début et à la fin, le maximum au milieu (palier entre la montée et la descente).
function EffetsCapacites.angleInclinaison(avancement: number, maxDegres: number): number
	local t = math.clamp(avancement, 0, 1)
	local facteur
	if t < MONTEE then
		facteur = math.sin((t / MONTEE) * math.pi / 2)
	elseif t > 1 - DESCENTE then
		facteur = math.sin(((1 - t) / DESCENTE) * math.pi / 2)
	else
		facteur = 1
	end
	return math.rad(maxDegres) * facteur
end

--- Les rayons de l'anneau de l'onde de choc : il part de 1 stud de rayon et grandit jusqu'à `rayonMax`, la bande restant
--- fine (0,8 stud au départ, 15 % du rayon à la fin).
function EffetsCapacites.anneau(rayonMax: number): Anneau
	local fin = math.max(rayonMax, 1.5)
	return {
		rayonDepart = 1,
		rayonFin = fin,
		interieurDepart = 0.2,
		interieurFin = fin * 0.85,
	}
end

return table.freeze(EffetsCapacites)
