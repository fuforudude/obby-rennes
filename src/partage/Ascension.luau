--!strict
-- L'ascension au-dessus de Sup de Vinci, en fonctions pures (sans jeu, sans horloge, sans DataStore) : l'aura
-- croissante par étage, les paliers, ce qui rend une tentative classable, la hauteur affichée, et la validation
-- d'une demande de téléportation vers un palier.
-- Le service serveur (src/serveur/Ascension.luau) rassemble les données du jeu ; ce module décide.
-- Même esprit que src/partage/Signalement.luau, y compris le piège de la cadence : l'heure n'est notée qu'après
-- avoir vérifié qu'elle est passée (sinon la première demande se refuse elle-même).

-- Barème de l'aura de l'ascension (les valeurs du jeu sont dans Reglages ; les tests passent les leurs).
export type Bareme = {
	ASCENSION_AURA_BASE: number,
	ASCENSION_AURA_PAR_ETAGE: number,
}

-- Une tentative d'ascension en cours (tenue par le service, remise à zéro à chaque départ du pied).
export type Tentative = {
	debut: number?, -- heure serveur du départ au pied de l'ascension ; nil = pas de chrono
	teleportations: number, -- téléportations vers un palier pendant cette tentative
	alertes: number, -- alertes de la surveillance des déplacements (src/serveur/Capacites.luau)
	-- Après une téléportation : les étages dont le dessus est à cette hauteur (studs au-dessus du pied) ou plus bas
	-- ne paient pas. nil = pas de seuil (tentative partie du pied : tous les étages paient).
	hauteurMinimumPayante: number?,
}

export type RaisonTeleport =
	"trop_souvent"
	| "mauvais_type"
	| "pas_en_ascension"
	| "palier_inconnu"
	| "palier_non_debloque"

-- Ce qu'il faut savoir pour accepter une demande de téléportation. `numero` arrive du client : rien n'est supposé.
export type EntreeTeleport = {
	numero: unknown, -- l'argument du RemoteEvent DemanderTeleportPalier, tel qu'il est arrivé
	enAscension: boolean, -- le joueur peut se téléporter : ascension ouverte (tuto fini), personnage vivant
	paliersCarte: { number }, -- hauteur de chaque palier de la carte, rangée par numéro (1 à 5)
	paliersDebloques: { number }, -- numéros des paliers déjà atteints par ce joueur (données sauvegardées)
}

-- 1 stud Roblox vaut à peu près 0,28 m : c'est ce qui rend « 650 studs » comme « 182 m ».
local METRES_PAR_STUD = 0.28

local Ascension = {}

Ascension.METRES_PAR_STUD = METRES_PAR_STUD

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

--- Le plus haut palier atteint à cette hauteur (0 = aucun). `paliers` donne la hauteur du palier n en `paliers[n]`.
function Ascension.palierPour(hauteur: number, paliers: { number }): number
	local atteint = 0
	for numero, hauteurPalier in paliers do
		if hauteur >= hauteurPalier and numero > atteint then
			atteint = numero
		end
	end
	return atteint
end

--- Cette tentative entre-t-elle aux classements ? Chrono parti du pied, aucune téléportation, aucune alerte.
function Ascension.estClassable(tentative: Tentative): boolean
	return tentative.debut ~= nil and tentative.teleportations == 0 and tentative.alertes == 0
end

--- Le seuil d'aura après une téléportation vers un palier : les étages au-dessus du palier d'arrivée paient, ceux
--- à son niveau ou en dessous non. `marge` (studs) évite de payer l'étage posé sur la dalle même du palier, dont la
--- plaque dépasse un peu : c'est le même niveau pour le joueur.
function Ascension.hauteurMinimumPayante(hauteurPalier: number, marge: number): number
	return hauteurPalier + marge
end

--- Cet étage paie-t-il son aura dans cette tentative ? Il faut un chrono parti du pied et aucune alerte de la
--- surveillance (une alerte coupe tout : plus rien du tout), puis, après une téléportation, que l'étage soit
--- au-dessus du seuil. Une téléportation seule ne coupe pas l'aura (elle rend seulement la tentative non classée,
--- voir `estClassable`) : grimper depuis le palier d'arrivée reste récompensé, sans ferme depuis le bas.
--- `hauteurEtage` : dessus de l'étage, en studs au-dessus du pied. Une valeur abîmée (NaN) ne paie pas.
function Ascension.etagePaye(tentative: Tentative, hauteurEtage: number): boolean
	if tentative.debut == nil or tentative.alertes > 0 then
		return false
	end
	local seuil = tentative.hauteurMinimumPayante
	if seuil == nil then
		return hauteurEtage == hauteurEtage
	end
	return hauteurEtage > seuil
end

--- Nouveau record de hauteur ? (la plus grande gagne, contrairement aux temps)
function Ascension.estRecordHauteur(ancienne: number, nouvelle: number): boolean
	return nouvelle > 0 and nouvelle > ancienne
end

--- Le joueur a-t-il quelque chose à voir dans l'interface de l'ascension (un palier ou un record de hauteur) ?
--- Sinon le renvoi périodique de l'état est inutile : le premier envoi, au chargement des données, suffit.
function Ascension.aQuelqueChoseAMontrer(nbPaliers: number, meilleureHauteur: number): boolean
	return nbPaliers > 0 or meilleureHauteur > 0
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

--- Ce joueur demande-t-il une téléportation trop vite ? (Utilisé par `traiterTeleport`, seul juge de la cadence.)
function Ascension.tropSouvent(instant: number, derniere: number?, delaiMin: number): boolean
	return derniere ~= nil and instant - derniere < delaiMin
end

--- Accepte ou refuse une demande de téléportation. Rend `true`, ou `false` et la raison du refus.
--- Ne contrôle pas la cadence (c'est `traiterTeleport`). Du moins cher au plus cher.
function Ascension.validerTeleport(e: EntreeTeleport): (boolean, RaisonTeleport?)
	local numero = e.numero
	if typeof(numero) ~= "number" then
		return false, "mauvais_type"
	end
	local n = numero :: number
	if n ~= n or n == math.huge or n == -math.huge or n % 1 ~= 0 then -- NaN, infini, non entier
		return false, "mauvais_type"
	end
	if not e.enAscension then
		return false, "pas_en_ascension"
	end
	if e.paliersCarte[n] == nil then
		return false, "palier_inconnu"
	end
	if table.find(e.paliersDebloques, n) == nil then
		return false, "palier_non_debloque"
	end
	return true, nil
end

--- Le point d'entrée du service : contrôle la cadence, note l'heure, puis valide.
--- `derniers` : l'heure de la dernière demande de chaque clé (le joueur), table qui vit entre les appels.
--- L'heure est notée dès que la cadence est passée, que la validation accepte ou non : un client qui réclame des
--- paliers non débloqués reste limité à une demande par `delai`. Un refus de cadence ne repousse pas l'heure notée.
--- `entree` est une fonction, appelée seulement si la cadence passe : les rafales sont écartées avant de rassembler
--- quoi que ce soit dans le jeu.
function Ascension.traiterTeleport(
	derniers: { [any]: number },
	cle: any,
	instant: number,
	delai: number,
	entree: () -> EntreeTeleport
): (boolean, RaisonTeleport?)
	if Ascension.tropSouvent(instant, derniers[cle], delai) then
		return false, "trop_souvent"
	end
	derniers[cle] = instant
	return Ascension.validerTeleport(entree())
end

return table.freeze(Ascension)
