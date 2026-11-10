--!strict
-- Les règles du parcours, en fonctions pures (sans DataStore ni horloge) : c'est ce que teste tests/partage.

export type Course = {
	debut: number?, -- heure serveur du départ (workspace:GetServerTimeNow()), nil si pas de chrono
	passages: number, -- étapes passées en payant pendant cette course
	reprise: boolean, -- course reprise d'une ancienne session (le chrono n'a pas couru depuis le départ)
	serie: number, -- checkpoints enchaînés depuis la dernière chute (multiplicateur d'aura)
	chutes: number, -- chutes pendant cette course
}

-- Barème de l'aura (les valeurs du jeu sont dans Reglages ; les tests passent les leurs).
export type Bareme = {
	AURA_BASE: number,
	AURA_SERIE_MAX: number,
	AURA_PERTE_CHUTE: number,
	AURA_ARRIVEE: number,
	AURA_SANS_CHUTE: number,
}

export type Donnees = {
	version: number,
	etape: number,
	meilleurTemps: number, -- en secondes ; 0 = aucun
	aura: number, -- aura totale, cumulée sur toutes les parties
	achats: { string }, -- PurchaseId déjà traités, les plus récents à la fin
}

local VERSION_DONNEES = 1

local Regles = {}

--- Un checkpoint touché ne compte que s'il est le suivant, et qu'il existe.
function Regles.peutValider(etapeActuelle: number, etapeTouchee: number, nbEtapes: number): boolean
	return etapeTouchee == etapeActuelle + 1 and etapeTouchee <= nbEtapes
end

--- Course qui démarre au départ, chrono lancé.
function Regles.nouvelleCourse(maintenant: number): Course
	return { debut = maintenant, passages = 0, reprise = false, serie = 0, chutes = 0 }
end

--- Course reprise à un checkpoint sauvegardé : le chrono tourne mais le temps ne sera pas classé.
function Regles.courseReprise(maintenant: number): Course
	return { debut = maintenant, passages = 0, reprise = true, serie = 0, chutes = 0 }
end

--- La course entre-t-elle au classement ? D'une traite, sans passage payant, et pas plus rapide que possible.
function Regles.estClassable(course: Course, duree: number, tempsMin: number): boolean
	return course.debut ~= nil and course.passages == 0 and not course.reprise and duree >= tempsMin
end

--- Nouveau record personnel ? (0 = pas encore de temps)
function Regles.estRecord(ancien: number, nouveau: number): boolean
	return nouveau > 0 and (ancien <= 0 or nouveau < ancien)
end

--- « 4:07.25 » : minutes, secondes, centièmes.
function Regles.formaterTemps(secondes: number): string
	local centiemes = math.floor(math.max(0, secondes) * 100 + 0.5)
	local minutes = centiemes // 6000
	local reste = centiemes % 6000
	return string.format("%d:%02d.%02d", minutes, reste // 100, reste % 100)
end

--- Temps en millisecondes entières, pour l'OrderedDataStore (qui ne range que des entiers).
function Regles.versMillisecondes(secondes: number): number
	return math.floor(secondes * 1000 + 0.5)
end

function Regles.donneesNeuves(): Donnees
	return { version = VERSION_DONNEES, etape = 0, meilleurTemps = 0, aura = 0, achats = {} }
end

--- Remet des données lues (peut-être anciennes ou abîmées) dans la forme actuelle, sans rien perdre d'utile.
function Regles.migrer(brutes: any, nbEtapes: number): Donnees
	local d = Regles.donneesNeuves()
	if typeof(brutes) ~= "table" then
		return d
	end
	local etape = brutes.etape
	if typeof(etape) == "number" and etape == etape then -- etape == etape écarte NaN
		d.etape = math.clamp(math.floor(etape), 0, nbEtapes)
	end
	if typeof(brutes.meilleurTemps) == "number" and brutes.meilleurTemps > 0 then
		d.meilleurTemps = brutes.meilleurTemps
	end
	local aura = brutes.aura
	if typeof(aura) == "number" and aura == aura and aura > 0 and aura < math.huge then
		d.aura = math.floor(aura)
	end
	if typeof(brutes.achats) == "table" then
		for _, id in brutes.achats do
			if typeof(id) == "string" then
				table.insert(d.achats, id)
			end
		end
	end
	return d
end

--- Aura d'un checkpoint atteint : la base multipliée par la série (déjà comptée avec ce checkpoint), plafonnée.
function Regles.gainCheckpoint(serie: number, bareme: Bareme): number
	return bareme.AURA_BASE * math.clamp(serie, 1, bareme.AURA_SERIE_MAX)
end

--- Aura après une chute : on perd un peu, jamais en dessous de zéro.
function Regles.auraApresChute(aura: number, bareme: Bareme): number
	return math.max(0, aura - bareme.AURA_PERTE_CHUTE)
end

--- Aura de l'arrivée : un bonus, et le gros bonus pour un parcours entier d'une traite sans tomber ni payer.
function Regles.gainArrivee(course: Course, bareme: Bareme): number
	local sansFaute = course.chutes == 0 and course.passages == 0 and not course.reprise
	return bareme.AURA_ARRIVEE + (if sansFaute then bareme.AURA_SANS_CHUTE else 0)
end

--- « 12 345 » : l'aura avec des espaces entre les milliers.
function Regles.formaterAura(aura: number): string
	local chiffres = tostring(math.max(0, math.floor(aura)))
	local resultat = chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (resultat:gsub("^ ", ""))
end

function Regles.achatDejaTraite(achats: { string }, idAchat: string): boolean
	return table.find(achats, idAchat) ~= nil
end

--- Mémorise un achat traité ; garde seulement les `max` plus récents.
function Regles.memoriserAchat(achats: { string }, idAchat: string, max: number)
	table.insert(achats, idAchat)
	while #achats > max do
		table.remove(achats, 1)
	end
end

return Regles
