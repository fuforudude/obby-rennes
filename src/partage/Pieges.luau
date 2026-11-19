--!strict
-- Les obstacles et pièges de la tour, en fonctions pures (sans jeu, sans horloge, sans instance) : la lecture des
-- attributs posés par la carte, le cycle du piège de mur, le balayage du laser et le cycle de la plateforme qui
-- s'effondre. Le service serveur (src/serveur/Obstacles.luau) ne fait que lire l'horloge, bouger les pièces et
-- pousser les joueurs ; ce module décide.
-- Même esprit que src/partage/Horaires.luau, dont le laser réutilise le cycle : tous les joueurs voient le même
-- balayage parce qu'il se calcule à partir de `workspace:GetServerTimeNow()`.
--
-- Contrats de la carte (tags posés par outils/monde/Ascension.luau) :
--   PiegeMur    sur un Model, enfant `Pointe` (BasePart) : Direction (Vector3, sens de sortie), Distance (studs),
--               DureeSortie, DureeRentree (s), Repos (s, facultatif), Portee (studs, facultatif), Poussee (studs/s,
--               facultatif, plafonnée par Reglages.PIEGE_POUSSEE_MAX).
--               Cycle, du déclenchement au suivant : sortie (DureeSortie : la pointe sort) -> rentrée (DureeRentree :
--               la pointe rentre) -> repos (Repos : pointe rentrée, rien ne la déclenche). DureeSortie et
--               DureeRentree sont des durées d'ANIMATION, pas des temps passés dehors ou rentré. La pointe est
--               dangereuse (elle pousse) pendant la sortie ET la rentrée ; la fenêtre de passage du joueur est
--               `Repos`. Sans attribut `Repos`, c'est Reglages.PIEGE_REPOS qui s'applique, en silence ;
--   Laser       sur une BasePart : Depart, Arrivee (Vector3 absolus), Periode, Decalage (s) ;
--   Effondrable sur une BasePart : DelaiChute (s, facultatif), DelaiRetour (s, facultatif) ;
--   Balancier   (existant) : Poussee (multiplicateur de force, facultatif, 1 par défaut).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Horaires = require(ReplicatedStorage.Partage.Horaires)

export type ParametresPiege = {
	direction: Vector3, -- unitaire et horizontale : le sens dans lequel la pointe sort et pousse
	distance: number, -- course de la pointe, en studs
	dureeSortie: number,
	dureeRentree: number,
	portee: number, -- rayon de déclenchement autour de la pointe rentrée, en studs
	poussee: number, -- vitesse horizontale imposée au joueur touché, en studs/s
	repos: number, -- temps rentré avant de pouvoir se redéclencher, en secondes
}

-- « pret » : rentrée, prête à partir. « sortie » / « rentree » : en mouvement. « repos » : rentrée, en attente.
export type PhasePiege = "pret" | "sortie" | "rentree" | "repos"

export type ParametresLaser = {
	depart: Vector3,
	arrivee: Vector3,
	periode: number, -- un aller-retour complet par période
	decalage: number, -- l'instant où le rayon est au départ
}

export type ParametresEffondrable = {
	delaiChute: number, -- entre le premier contact et la chute
	delaiRetour: number, -- entre la chute et le retour à sa place
}

export type CycleEffondrable = "tient" | "tombee" | "revenue"

export type DefautsPiege = { portee: number, poussee: number, pousseeMax: number, repos: number }
export type DefautsEffondrable = { delaiChute: number, delaiRetour: number }

local function fini(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

--- Un nombre fini et strictement positif, ou nil pour prendre la valeur par défaut. Rend nil si la valeur est là
--- mais absurde : une carte mal réglée se signale, elle ne se devine pas.
local function nombrePositif(valeur: any, defaut: number): number?
	if valeur == nil then
		return defaut
	end
	if not fini(valeur) or valeur <= 0 then
		return nil
	end
	return valeur :: number
end

local Pieges = {}

--- Lit les attributs d'un Model `PiegeMur` (table attribut -> valeur, par exemple `modele:GetAttributes()`).
--- Rend nil si un attribut manque, a le mauvais type ou n'a pas de sens : l'appelant avertit et ignore le piège.
--- `Portee`, `Poussee` et `Repos` sont facultatifs (les réglages du jeu complètent, sans avertir : une carte qui
--- oublie `Repos` prend `PIEGE_REPOS`) ; une valeur présente mais absurde (0, négative, NaN, pas un nombre) refuse le
--- piège. `Poussee` est plafonnée à `defauts.pousseeMax` (strictement sous le dash) : au-delà, le joueur ne pourrait
--- plus rattraper la poussée. La direction est ramenée à l'unité et
--- à l'horizontale, parce que la poussée est horizontale et que le joueur doit pouvoir la rattraper au dash.
function Pieges.piegeDepuisAttributs(attributs: { [string]: any }, defauts: DefautsPiege): ParametresPiege?
	local direction = attributs.Direction
	if typeof(direction) ~= "Vector3" then
		return nil
	end
	local plat = Vector3.new((direction :: Vector3).X, 0, (direction :: Vector3).Z)
	if not fini(plat.Magnitude) or plat.Magnitude < 1e-4 then
		return nil -- direction nulle ou purement verticale : rien à pousser dans le plan
	end
	local distance = nombrePositif(attributs.Distance, 0)
	local dureeSortie = nombrePositif(attributs.DureeSortie, 0)
	local dureeRentree = nombrePositif(attributs.DureeRentree, 0)
	local portee = nombrePositif(attributs.Portee, defauts.portee)
	local poussee = nombrePositif(attributs.Poussee, defauts.poussee)
	if poussee ~= nil then
		poussee = math.min(poussee, defauts.pousseeMax) -- la carte ne peut pas dépasser le dash : voir Reglages.PIEGE_POUSSEE_MAX
	end
	local repos = nombrePositif(attributs.Repos, defauts.repos)
	if
		distance == nil
		or distance == 0
		or dureeSortie == nil
		or dureeSortie == 0
		or dureeRentree == nil
		or dureeRentree == 0
		or portee == nil
		or poussee == nil
		or repos == nil
	then
		return nil
	end
	return {
		direction = plat.Unit,
		distance = distance :: number,
		dureeSortie = dureeSortie :: number,
		dureeRentree = dureeRentree :: number,
		portee = portee :: number,
		poussee = poussee :: number,
		repos = repos :: number,
	}
end

--- Où en est la pointe, `ecoule` secondes après son déclenchement, et de combien elle est sortie (0 rentrée,
--- 1 complètement dehors). Avant tout déclenchement (`ecoule` négatif), elle est rentrée et prête.
function Pieges.phasePiege(ecoule: number, p: ParametresPiege): (PhasePiege, number)
	if not fini(ecoule) or ecoule < 0 then
		return "pret", 0
	end
	if ecoule < p.dureeSortie then
		return "sortie", ecoule / p.dureeSortie
	end
	local finRentree = p.dureeSortie + p.dureeRentree
	if ecoule < finRentree then
		return "rentree", 1 - (ecoule - p.dureeSortie) / p.dureeRentree
	end
	if ecoule < finRentree + p.repos then
		return "repos", 0
	end
	return "pret", 0
end

--- La pointe part-elle ? Il faut qu'elle soit prête (ni en mouvement ni au repos) et qu'un joueur vivant soit à
--- `portee` studs ou moins. `distance` vient du jeu : nil (personne) ou abîmée (NaN) ne déclenche rien.
function Pieges.doitDeclencher(phase: PhasePiege, distance: number?, portee: number): boolean
	if phase ~= "pret" or not fini(distance) then
		return false
	end
	return (distance :: number) <= portee
end

--- La vitesse du joueur après la poussée : la vitesse horizontale est remplacée par `poussee` studs/s dans la
--- direction du piège, la vitesse verticale est laissée telle quelle (le piège projette, il ne soulève pas et
--- n'écrase pas au sol). Elle ne tue jamais : c'est le vide qui tue, et le dash ou le double saut rattrapent.
function Pieges.vitesseApresPoussee(vitesse: Vector3, direction: Vector3, poussee: number): Vector3
	return Vector3.new(direction.X * poussee, vitesse.Y, direction.Z * poussee)
end

--- Lit les attributs d'une BasePart `Laser`. Rend nil si une extrémité manque, n'est pas un Vector3, si les deux
--- sont confondues (pas de balayage), ou si la période ou le décalage sont absurdes.
function Pieges.laserDepuisAttributs(attributs: { [string]: any }): ParametresLaser?
	local depart, arrivee = attributs.Depart, attributs.Arrivee
	local periode, decalage = attributs.Periode, attributs.Decalage
	if typeof(depart) ~= "Vector3" or typeof(arrivee) ~= "Vector3" then
		return nil
	end
	if not fini(decalage) or not Horaires.valide(periode, 0, periode) then
		return nil
	end
	if ((arrivee :: Vector3) - (depart :: Vector3)).Magnitude < 1e-4 then
		return nil
	end
	return { depart = depart :: Vector3, arrivee = arrivee :: Vector3, periode = periode, decalage = decalage }
end

--- Où en est le balayage à l'instant t : 0 au départ, 1 à l'arrivée, aller-retour régulier (triangle) d'un cycle
--- complet par période. Le cycle vient de `Horaires.etat` : même horloge et même façon de compter la phase que
--- les événements de la ville et les balanciers, donc le même rythme pour tous les joueurs.
function Pieges.fractionBalayage(t: number, periode: number, decalage: number): number
	local _, progression = Horaires.etat(t, periode, decalage, 0, periode)
	return if progression < 0.5 then progression * 2 else 2 - progression * 2
end

--- La position du rayon à l'instant t.
function Pieges.positionLaser(t: number, p: ParametresLaser): Vector3
	local f = Pieges.fractionBalayage(t, p.periode, p.decalage)
	return p.depart + (p.arrivee - p.depart) * f
end

--- Lit les attributs d'une BasePart `Effondrable`. Les deux délais sont facultatifs (les réglages du jeu
--- complètent) ; une valeur présente mais absurde fait refuser la plateforme plutôt que de la deviner.
function Pieges.effondrableDepuisAttributs(
	attributs: { [string]: any },
	defauts: DefautsEffondrable
): ParametresEffondrable?
	local delaiChute = nombrePositif(attributs.DelaiChute, defauts.delaiChute)
	local delaiRetour = nombrePositif(attributs.DelaiRetour, defauts.delaiRetour)
	if delaiChute == nil or delaiRetour == nil then
		return nil
	end
	return { delaiChute = delaiChute :: number, delaiRetour = delaiRetour :: number }
end

--- Combien de temps la dalle tombe librement : au plus `maximum`, et jamais plus que `delaiRetour` (sinon elle
--- serait réancrée après son propre retour). Pourquoi un plafond : voir Reglages.EFFONDRABLE_DUREE_CHUTE.
function Pieges.dureeChuteLibre(delaiRetour: number, maximum: number): number
	return math.min(delaiRetour, maximum)
end

--- Où en est la plateforme, `ecoule` secondes après le premier contact : elle tient encore, elle est tombée, ou
--- elle est revenue à sa place (et peut retomber au contact suivant).
function Pieges.cycleEffondrable(ecoule: number, p: ParametresEffondrable): CycleEffondrable
	if not fini(ecoule) or ecoule < p.delaiChute then
		return "tient"
	end
	if ecoule < p.delaiChute + p.delaiRetour then
		return "tombee"
	end
	return "revenue"
end

--- Le multiplicateur de force d'un balancier (attribut facultatif `Poussee` des pancartes qui basculent).
--- 1 par défaut, et 1 aussi pour une valeur absurde : un balancier mal réglé pousse comme avant, il ne projette
--- pas les joueurs à travers la tour.
function Pieges.multiplicateurPoussee(valeur: any, plafond: number): number
	if not fini(valeur) or (valeur :: number) <= 0 or (valeur :: number) > plafond then
		return 1
	end
	return valeur :: number
end

return table.freeze(Pieges)
