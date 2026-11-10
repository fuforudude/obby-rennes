--!strict
-- Les règles du parcours, en fonctions pures (sans DataStore ni horloge) : c'est ce que teste tests/partage.

export type Course = {
	debut: number?, -- heure serveur du départ (workspace:GetServerTimeNow()), nil si pas de chrono
	passages: number, -- étapes passées en payant pendant cette course
	reprise: boolean, -- course reprise d'une ancienne session (le chrono n'a pas couru depuis le départ)
}

export type Donnees = {
	version: number,
	etape: number,
	meilleurTemps: number, -- en secondes ; 0 = aucun
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
	return { debut = maintenant, passages = 0, reprise = false }
end

--- Course reprise à un checkpoint sauvegardé : le chrono tourne mais le temps ne sera pas classé.
function Regles.courseReprise(maintenant: number): Course
	return { debut = maintenant, passages = 0, reprise = true }
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
	return { version = VERSION_DONNEES, etape = 0, meilleurTemps = 0, achats = {} }
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
	if typeof(brutes.achats) == "table" then
		for _, id in brutes.achats do
			if typeof(id) == "string" then
				table.insert(d.achats, id)
			end
		end
	end
	return d
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
