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
	capacites: { [string]: boolean }, -- capacités débloquées dans le tuto (« course », « doubleSaut », « dash »)
	paliers: { number }, -- numéros des paliers d'ascension atteints, définitifs, rangés croissants
	meilleureHauteur: number, -- plus grande hauteur atteinte dans l'ascension, en studs ; 0 = jamais montée
	meilleurTempsAscension: number, -- meilleur chrono du pied de l'ascension au sommet, en secondes ; 0 = aucun
}

local VERSION_DONNEES = 1

-- Paliers de l'ascension : la carte en pose 4 à 5 (tag Palier, attribut Numero). Ce n'est qu'un garde-fou contre
-- une valeur absurde, volontairement large (comme Affichage.PALIERS_MAX) : c'est la carte qui dit combien il y en
-- a, pas la sauvegarde — une carte qui en gagnerait un sixième ne doit pas faire perdre sa progression au joueur.
-- Un numéro hors bornes est écarté, jamais ramené dans les bornes (on ne débloque jamais un palier non atteint).
local PALIERS_MAX = 10

local Regles = {}

-- Garde-fou public : le serveur refuse un palier de la carte au-delà, sinon il le débloquerait pour la session puis
-- le perdrait au rechargement sans un mot (src/serveur/Ascension.luau).
Regles.PALIERS_MAX = PALIERS_MAX

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
	return {
		version = VERSION_DONNEES,
		etape = 0,
		meilleurTemps = 0,
		aura = 0,
		achats = {},
		capacites = {},
		paliers = {},
		meilleureHauteur = 0,
		meilleurTempsAscension = 0,
	}
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
	-- Capacités du tuto : seul un déblocage explicite (true) est gardé ; le nom est celui du contrat (Capacites).
	if typeof(brutes.capacites) == "table" then
		for nom, debloquee in brutes.capacites do
			if typeof(nom) == "string" and debloquee == true then
				d.capacites[nom] = true
			end
		end
	end
	-- Paliers d'ascension : des numéros entiers de 1 à PALIERS_MAX, sans doublon, rangés croissants.
	if typeof(brutes.paliers) == "table" then
		for _, numero in brutes.paliers do
			if
				typeof(numero) == "number"
				and numero % 1 == 0
				and numero >= 1
				and numero <= PALIERS_MAX
				and table.find(d.paliers, numero) == nil
			then
				table.insert(d.paliers, numero)
			end
		end
		table.sort(d.paliers)
	end
	local hauteur = brutes.meilleureHauteur
	if typeof(hauteur) == "number" and hauteur == hauteur and hauteur > 0 and hauteur < math.huge then
		d.meilleureHauteur = math.floor(hauteur)
	end
	local temps = brutes.meilleurTempsAscension
	if typeof(temps) == "number" and temps == temps and temps > 0 and temps < math.huge then
		d.meilleurTempsAscension = temps
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
