--!strict
-- L'ascension au-dessus de Sup de Vinci, en fonctions pures (sans jeu, sans horloge, sans DataStore) : l'aura
-- croissante par étage, ce qui rend une tentative classable, et la hauteur affichée.
-- Le service serveur (src/serveur/Ascension.luau) rassemble les données du jeu ; ce module décide.
-- Il n'y a plus de paliers depuis la tour exigeante (docs/specs/2026-11-18-tour-exigeante.md) : aucun checkpoint
-- entre le pied et le sommet, donc plus de téléportation, plus de seuil d'aura, plus de liste à sauvegarder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regles = require(ReplicatedStorage.Partage.Regles)

-- Barème de l'aura de l'ascension (les valeurs du jeu sont dans Reglages ; les tests passent les leurs).
export type Bareme = {
	ASCENSION_AURA_BASE: number,
	ASCENSION_AURA_PAR_ETAGE: number,
}

-- Une tentative d'ascension en cours (tenue par le service, remise à zéro à chaque départ du pied).
export type Tentative = {
	debut: number?, -- heure serveur du départ au pied de l'ascension ; nil = pas de chrono
	alertes: number, -- alertes de la surveillance des déplacements (src/serveur/Capacites.luau)
}

-- 1 stud Roblox vaut à peu près 0,28 m : c'est ce qui rend « 650 studs » comme « 182 m ».
local METRES_PAR_STUD = 0.28

local Ascension = {}

Ascension.METRES_PAR_STUD = METRES_PAR_STUD

--- Les noms des classements de la tour (OrderedDataStore) pour une version de tour (Reglages.VERSION_TOUR) :
--- une nouvelle version ouvre des classements neufs, les anciens restent stockés sous leur nom. La version 1 donne
--- les noms d'origine, « HauteurAscension_v1 » et « TempsAscension_v1 ».
function Ascension.nomsClassementsTour(versionTour: number): { hauteur: string, temps: string }
	return {
		hauteur = `HauteurAscension_v{versionTour}`,
		temps = `TempsAscension_v{versionTour}`,
	}
end

--- Aura d'un étage franchi : la base pour le premier étage, puis de plus en plus haut on monte.
--- Croissante avec la hauteur : l'étage n rapporte BASE + PAR_ETAGE × (n − 1).
--- Un numéro abîmé (NaN, infini, négatif) compte pour l'étage 1 : une pièce mal taguée dans la carte ne rapporte
--- jamais plus que la base.
function Ascension.auraEtage(numeroEtage: number, bareme: Bareme): number
	local sain = numeroEtage == numeroEtage and numeroEtage < math.huge
	local n = math.max(1, math.floor(if sain then numeroEtage else 1))
	return math.floor(bareme.ASCENSION_AURA_BASE + bareme.ASCENSION_AURA_PAR_ETAGE * (n - 1))
end

--- Aura d'une ascension entière de `nbEtages` étages : sert à voir l'équilibrage d'un coup d'œil.
function Ascension.auraAscension(nbEtages: number, bareme: Bareme): number
	local total = 0
	for etage = 1, math.max(0, math.floor(nbEtages)) do
		total += Ascension.auraEtage(etage, bareme)
	end
	return total
end

--- Cette tentative entre-t-elle aux classements ? Chrono parti du pied et aucune alerte de la surveillance.
--- Sans paliers, plus rien d'autre ne peut la salir : on ne monte que par ses propres moyens.
function Ascension.estClassable(tentative: Tentative): boolean
	return tentative.debut ~= nil and tentative.alertes == 0
end

--- Cet étage paie-t-il son aura dans cette tentative ? Il faut un chrono parti du pied et aucune alerte de la
--- surveillance (une alerte coupe tout : plus rien du tout). Sans paliers, il n'y a plus de seuil de hauteur :
--- toute la tour se grimpe d'une traite, donc tous les étages paient.
--- `hauteurEtage` : dessus de l'étage, en studs au-dessus du pied. Une valeur abîmée (NaN) ne paie pas.
function Ascension.etagePaye(tentative: Tentative, hauteurEtage: number): boolean
	if tentative.debut == nil or tentative.alertes > 0 then
		return false
	end
	return hauteurEtage == hauteurEtage
end

--- Nouveau record du temps de tour ? Même définition qu'à Sup de Vinci (serveur/Parcours) : classable, pas plus rapide
--- que possible (`tempsMin` : un pied ou un sommet mal placés dans la carte inscriraient sinon un temps imbattable, pour
--- toujours), et meilleur que l'ancien. La première montée classable (ancien = 0) est donc un record.
function Ascension.estRecordTemps(ancien: number, duree: number, classable: boolean, tempsMin: number): boolean
	return classable and duree >= tempsMin and Regles.estRecord(ancien, duree)
end

--- Nouveau record de hauteur ? (la plus grande gagne, contrairement aux temps)
function Ascension.estRecordHauteur(ancienne: number, nouvelle: number): boolean
	return nouvelle > 0 and nouvelle > ancienne
end

--- Le joueur a-t-il quelque chose à voir dans l'interface de l'ascension (un record de hauteur) ?
--- Sinon le renvoi périodique de l'état est inutile : le premier envoi, au chargement des données, suffit.
function Ascension.aQuelqueChoseAMontrer(meilleureHauteur: number): boolean
	return meilleureHauteur > 0
end

--- « 182 m » : la hauteur en mètres, arrondie, jamais négative.
function Ascension.formaterHauteur(studs: number): string
	local metres = math.floor(math.max(0, studs) * METRES_PAR_STUD + 0.5)
	return `{metres} m`
end

--- Hauteur en studs entiers, pour l'OrderedDataStore du classement (qui ne range que des entiers).
function Ascension.versStudsEntiers(studs: number): number
	return math.floor(math.max(0, studs) + 0.5)
end

return table.freeze(Ascension)
