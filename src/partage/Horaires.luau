--!strict
-- Les horaires des événements de la carte (objets qui tombent, rame, drones, trafic) : des fonctions pures.
-- Tous les joueurs calculent le même état à partir de `workspace:GetServerTimeNow()`.
--
-- Le cycle, de période P, avec phase = (t - decalage) mod P :
--   actif    phase dans [0, duree)            le danger (Decalage = l'instant où il commence)
--   attente  phase dans [duree, P - preavis)  rien
--   preavis  phase dans [P - preavis, P)      l'avertissement, juste avant le danger suivant
-- Une période doit contenir le danger et son préavis (preavis + duree <= P) : sinon le préavis d'un danger
-- tomberait dans le danger précédent.

export type Etat = "attente" | "preavis" | "actif"

export type Horaire = { periode: number, decalage: number, duree: number }

export type Parametres = {
	type: "Passage" | "Chute",
	periode: number,
	decalage: number,
	preavis: number,
	duree: number, -- DureePassage ou DureeChute
	depart: Vector3?, -- Passage
	arrivee: Vector3?, -- Passage
	hauteur: number?, -- Chute
}

local function fini(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local Horaires = {}

--- Les durées sont-elles cohérentes ? (nombres finis, période et fenêtre > 0, préavis >= 0, le tout dans la période)
function Horaires.valide(periode: number, preavis: number, duree: number): boolean
	return fini(periode)
		and fini(preavis)
		and fini(duree)
		and periode > 0
		and duree > 0
		and preavis >= 0
		and preavis + duree <= periode
end

--- L'état à l'instant t et la progression (0 à 1) dans la fenêtre courante : celle du danger quand il est actif,
--- celle du préavis pendant le préavis, 0 en attente. Lève une erreur si les paramètres sont incohérents
--- (voir `valide`) : un appelant qui lit des attributs de la carte vérifie d'abord avec `valide`.
function Horaires.etat(t: number, periode: number, decalage: number, preavis: number, duree: number): (Etat, number)
	assert(Horaires.valide(periode, preavis, duree), "Horaires.etat : période, préavis ou durée incohérents")
	assert(fini(t) and fini(decalage), "Horaires.etat : instant ou décalage invalide")
	-- « % » de Luau rend toujours un résultat dans [0, periode), même pour un nombre négatif.
	local phase = (t - decalage) % periode
	if phase < duree then
		return "actif", phase / duree
	end
	local debutPreavis = periode - preavis
	if preavis > 0 and phase >= debutPreavis then
		return "preavis", (phase - debutPreavis) / preavis
	end
	return "attente", 0
end

--- Le premier instant >= `depuis` à partir duquel aucun des dangers n'est actif pendant `dureeMin` secondes
--- d'affilée (cherché sur `horizon` secondes), ou nil. Sert aux vérifications : « chaque descente a toujours une
--- façon sûre de passer ».
function Horaires.prochaineFenetreSure(
	horaires: { Horaire },
	depuis: number,
	dureeMin: number,
	horizon: number
): number?
	local limite = depuis + horizon + dureeMin
	-- Toutes les fenêtres actives qui touchent [depuis, limite], triées par début.
	local fenetres: { { debut: number, fin: number } } = {}
	for _, h in horaires do
		local k = math.floor((depuis - h.decalage - h.duree) / h.periode)
		local debut = h.decalage + k * h.periode
		while debut < limite do
			if debut + h.duree > depuis then
				table.insert(fenetres, { debut = debut, fin = debut + h.duree })
			end
			debut += h.periode
		end
	end
	table.sort(fenetres, function(a, b)
		return a.debut < b.debut
	end)
	local curseur = depuis
	for _, f in fenetres do
		if f.debut - curseur >= dureeMin then
			return curseur
		end
		curseur = math.max(curseur, f.fin)
	end
	if curseur <= depuis + horizon then
		return curseur
	end
	return nil
end

--- Le danger est-il actif à l'instant t, à `tolerance` secondes près (avant ou après) ? Sert au serveur pour
--- accepter le signalement d'un joueur dont l'horloge ou le réseau a un peu de retard.
function Horaires.actifAutour(t: number, periode: number, decalage: number, duree: number, tolerance: number): boolean
	if
		not (fini(t) and fini(decalage) and fini(tolerance) and tolerance >= 0 and Horaires.valide(periode, 0, duree))
	then
		return false
	end
	local phase = (t - decalage) % periode
	return phase < duree + tolerance or phase > periode - tolerance
end

--- Le préavis est-il allumé ? Il clignote `frequence` fois par seconde, puis reste allumé en continu pendant les
--- 0,35 dernières secondes avant le danger. `progression` et `duree` : ceux de l'état « preavis » (durée du préavis).
function Horaires.preavisAllume(progression: number, duree: number, frequence: number): boolean
	local reste = (1 - progression) * duree
	if reste < 0.35 then
		return true
	end
	return math.floor(reste * 2 * frequence) % 2 == 0
end

--- L'angle (en degrés) d'un balancier à l'instant t : une sinusoïde d'amplitude `amplitude` de part et d'autre de la
--- position posée (0 à l'instant `decalage`, puis vers l'angle positif), d'un aller-retour complet par `periode`.
function Horaires.angleBalancier(t: number, amplitude: number, periode: number, decalage: number): number
	return amplitude * math.sin(2 * math.pi * (t - decalage) / periode)
end

--- Lit les attributs d'un objet `Evenement` (table attribut -> valeur, par exemple `objet:GetAttributes()`).
--- Rend nil si un attribut manque, a le mauvais type ou si les durées sont incohérentes.
function Horaires.depuisAttributs(attributs: { [string]: any }): Parametres?
	local genre = attributs.Type
	local periode, decalage, preavis = attributs.Periode, attributs.Decalage, attributs.Preavis
	if not (fini(periode) and fini(decalage) and fini(preavis)) then
		return nil
	end
	if genre == "Passage" then
		local duree = attributs.DureePassage
		local depart, arrivee = attributs.Depart, attributs.Arrivee
		if
			typeof(depart) ~= "Vector3"
			or typeof(arrivee) ~= "Vector3"
			or not Horaires.valide(periode, preavis, duree)
		then
			return nil
		end
		return {
			type = "Passage",
			periode = periode,
			decalage = decalage,
			preavis = preavis,
			duree = duree,
			depart = depart,
			arrivee = arrivee,
		}
	elseif genre == "Chute" then
		local duree, hauteur = attributs.DureeChute, attributs.Hauteur
		if not fini(hauteur) or hauteur <= 0 or not Horaires.valide(periode, preavis, duree) then
			return nil
		end
		return {
			type = "Chute",
			periode = periode,
			decalage = decalage,
			preavis = preavis,
			duree = duree,
			hauteur = hauteur,
		}
	end
	return nil
end

return table.freeze(Horaires)
