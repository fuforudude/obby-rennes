--!strict
-- Les règles du parcours, en fonctions pures (sans DataStore ni horloge) : c'est ce que teste tests/partage.

export type Course = {
	debut: number?, -- heure serveur du départ (workspace:GetServerTimeNow()), nil si pas de chrono
	passages: number, -- étapes passées en payant pendant cette course
	reprise: boolean, -- course reprise d'une ancienne session (le chrono n'a pas couru depuis le départ)
	serie: number, -- checkpoints enchaînés depuis la dernière chute (multiplicateur d'aura)
	chutes: number, -- chutes pendant cette course
	vol: boolean, -- le joueur a volé (mode testeur, serveur/Vol) pendant cette course : ni classement, ni aura, jusqu'à « Recommencer »
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
	tutoFini: boolean, -- le joueur a atteint l'arrivée du tuto au moins une fois : définitif, « Recommencer » ne le retire pas
	meilleurTemps: number, -- en secondes ; 0 = aucun
	aura: number, -- aura totale, cumulée sur toutes les parties
	achats: { string }, -- PurchaseId déjà traités, les plus récents à la fin
	capacites: { [string]: boolean }, -- capacités débloquées dans le tuto (« course », « doubleSaut », « dash »)
	-- Records de tour : ceux de la tour `versionTour` (Reglages.VERSION_TOUR, voir appliquerVersionTour).
	meilleureHauteur: number, -- plus grande hauteur atteinte dans l'ascension, en studs ; 0 = jamais montée
	meilleurTempsAscension: number, -- meilleur chrono du pied de l'ascension au sommet, en secondes ; 0 = aucun
	versionTour: number, -- version de la tour à laquelle appartiennent les deux records ci-dessus
	anciensRecordsTour: { [string]: RecordsTour }, -- records des tours précédentes, rangés sous leur version ("1"...)
}

export type RecordsTour = { meilleureHauteur: number, meilleurTempsAscension: number }

-- Version du schéma des données sauvegardées. La changer = ajouter la migration de l'ancienne version dans MIGRATIONS.
local VERSION_DONNEES = 2

-- MIGRATIONS[n] fait passer des données brutes (une copie) de la version n à la version n + 1, en place. Elles
-- s'appliquent dans l'ordre depuis la version lue ; `migrer` remet ensuite tout dans la forme actuelle.
local MIGRATIONS: { [number]: (brutes: { [any]: any }) -> () } = {
	-- 1 -> 2 : apparition de la version de tour. Les records de tour d'une sauvegarde v1 sont ceux de la tour 1.
	[1] = function(brutes)
		brutes.versionTour = 1
		brutes.anciensRecordsTour = {}
	end,
}

local Regles = {}

Regles.VERSION_DONNEES = VERSION_DONNEES

-- Attribut posé sur le Player par src/serveur/Ascension.luau : vrai pendant une tentative d'ascension (lu par Parcours).
Regles.ATTRIBUT_EN_ASCENSION = "EnAscension"

--- Un checkpoint touché ne compte que s'il est le suivant, et qu'il existe.
function Regles.peutValider(etapeActuelle: number, etapeTouchee: number, nbEtapes: number): boolean
	return etapeTouchee == etapeActuelle + 1 and etapeTouchee <= nbEtapes
end

--- L'ascension est-elle ouverte à ce joueur ? Exactement `tutoFini`. C'est LA règle, appelée par les deux services
--- qui se partagent la réapparition (src/serveur/Ascension.luau et la dérogation de Parcours.placer) : une seule
--- définition, donc jamais deux conditions qui divergent.
function Regles.ascensionOuverte(donnees: Donnees): boolean
	return donnees.tutoFini
end

--- La réapparition de ce joueur revient-elle au service d'ascension (pas à Parcours) ? Il faut qu'il soit dans une
--- tentative (`enAscension`, l'attribut du joueur) et que l'ascension lui soit ouverte (`ascensionOuverte`).
--- Même fonction pour tous : Parcours ne recopie pas la condition d'ouverture.
function Regles.placeParAscension(enAscension: boolean, donnees: Donnees): boolean
	return enAscension and Regles.ascensionOuverte(donnees)
end

--- « Recommencer » : l'étape repart à 0, rien d'autre ne bouge (aura, tutoFini, records, capacités).
function Regles.recommencer(donnees: Donnees)
	donnees.etape = 0
end

--- Course qui démarre au départ, chrono lancé.
function Regles.nouvelleCourse(maintenant: number): Course
	return { debut = maintenant, passages = 0, reprise = false, serie = 0, chutes = 0, vol = false }
end

--- Course reprise à un checkpoint sauvegardé : le chrono tourne mais le temps ne sera pas classé.
function Regles.courseReprise(maintenant: number): Course
	return { debut = maintenant, passages = 0, reprise = true, serie = 0, chutes = 0, vol = false }
end

--- La course entre-t-elle au classement ? D'une traite, sans passage payant, sans vol, et pas plus rapide que possible.
function Regles.estClassable(course: Course, duree: number, tempsMin: number): boolean
	return course.debut ~= nil and course.passages == 0 and not course.reprise and not course.vol and duree >= tempsMin
end

--- L'aura de cette course compte-t-elle ? Non dès que le joueur a volé : ni gain ni perte. Le classement de l'aura reçoit
--- l'aura TOTALE du joueur : une aura gagnée en volant, même gardée en local, y serait envoyée au gain suivant.
function Regles.auraCompte(course: Course): boolean
	return not course.vol
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
		tutoFini = false,
		meilleurTemps = 0,
		aura = 0,
		achats = {},
		capacites = {},
		meilleureHauteur = 0,
		meilleurTempsAscension = 0,
		versionTour = 1,
		anciensRecordsTour = {},
	}
end

local function hauteurValide(x: any): number
	return if typeof(x) == "number" and x == x and x > 0 and x < math.huge then math.floor(x) else 0
end

local function tempsValide(x: any): number
	return if typeof(x) == "number" and x == x and x > 0 and x < math.huge then x else 0
end

--- Remet des données lues (peut-être anciennes ou abîmées) dans la forme actuelle, sans rien perdre d'utile.
--- Lit `version` (absente ou abîmée : 1), applique les MIGRATIONS de cette version à l'actuelle sur une copie, puis
--- valide chaque champ. Une version plus récente que celle du code (retour en arrière du jeu) n'applique rien.
function Regles.migrer(entree: any, nbEtapes: number): Donnees
	local d = Regles.donneesNeuves()
	if typeof(entree) ~= "table" then
		return d
	end
	local brutes = table.clone(entree)
	local version = brutes.version
	version = if typeof(version) == "number" and version == version and version >= 1 then math.floor(version) else 1
	for v = version, VERSION_DONNEES - 1 do
		MIGRATIONS[v](brutes)
	end
	local etape = brutes.etape
	if typeof(etape) == "number" and etape == etape then -- etape == etape écarte NaN
		d.etape = math.clamp(math.floor(etape), 0, nbEtapes)
	end
	-- Tuto fini : un joueur d'avant le champ l'a fini s'il est à l'arrivée ; un champ déjà sauvegardé à true reste
	-- vrai même quand l'étape est repartie à 0 (« Recommencer »). Jamais d'autre valeur que true ou false.
	d.tutoFini = brutes.tutoFini == true or d.etape >= nbEtapes
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
	-- `paliers` (sauvegardes d'avant la tour exigeante) : le champ n'existe plus, il est simplement ignoré. Il
	-- n'est pas recopié dans les données actuelles, et sa présence ne doit rien casser au chargement.
	d.meilleureHauteur = hauteurValide(brutes.meilleureHauteur)
	d.meilleurTempsAscension = tempsValide(brutes.meilleurTempsAscension)
	-- Version de tour abîmée : on garde les records en les rangeant dans la tour 1, plutôt que de les effacer.
	local versionTour = brutes.versionTour
	d.versionTour = if typeof(versionTour) == "number"
			and versionTour >= 1
			and versionTour % 1 == 0
		then versionTour
		else 1
	if typeof(brutes.anciensRecordsTour) == "table" then
		for cle, records in brutes.anciensRecordsTour do
			if typeof(cle) == "string" and typeof(records) == "table" then
				d.anciensRecordsTour[cle] = {
					meilleureHauteur = hauteurValide(records.meilleureHauteur),
					meilleurTempsAscension = tempsValide(records.meilleurTempsAscension),
				}
			end
		end
	end
	return d
end

--- Met les records de tour à la version de tour du jeu (Reglages.VERSION_TOUR). Même version : rien ne bouge.
--- Autre version : les records de l'ancienne tour sont rangés dans `anciensRecordsTour` (sous leur version, s'il y
--- en a), et ceux de la nouvelle tour repartent de 0. Parcours, aura et capacités ne sont jamais touchés.
--- VERSION_TOUR ne fait que monter : une archive déjà présente sous la même version serait remplacée.
function Regles.appliquerVersionTour(d: Donnees, versionTour: number)
	if d.versionTour == versionTour then
		return
	end
	if d.meilleureHauteur > 0 or d.meilleurTempsAscension > 0 then
		d.anciensRecordsTour[tostring(d.versionTour)] = {
			meilleureHauteur = d.meilleureHauteur,
			meilleurTempsAscension = d.meilleurTempsAscension,
		}
	end
	d.meilleureHauteur = 0
	d.meilleurTempsAscension = 0
	d.versionTour = versionTour
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
