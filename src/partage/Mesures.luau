--!strict
-- Les règles des mesures (src/serveur/Mesures.luau les envoie à AnalyticsService), pures et testées.
-- Entonnoir « première partie » : 1 = arrivée en jeu, 2 à NB_ETAPES + 1 = checkpoints, puis le pied et le sommet de la
-- tour. Ne jamais renuméroter : les chiffres déjà enregistrés par Roblox changeraient de sens.
-- Morts : regroupées par étape (dernier checkpoint validé). Au plus un envoi par joueur et par étape et par session,
-- plus un à son départ ; les morts d'une étape rejouée (« Recommencer ») ne repartent donc pas, sauf celles du départ.

export type Suivi = {
	franchies: { [number]: boolean }, -- étapes de l'entonnoir déjà envoyées
	etape: number?, -- étape des morts en attente
	morts: number, -- morts en attente à cette étape
	envoyees: { [number]: boolean }, -- étapes dont les morts sont déjà parties
}

export type Envoi = { etape: number, morts: number }

-- Ce que `dejaAtteinte` lit de la sauvegarde (jamais modifiée).
export type DonneesLues = {
	etape: number,
	tutoFini: boolean,
	meilleureHauteur: number,
	meilleurTempsAscension: number,
}

local Mesures = {}

Mesures.ARRIVEE_EN_JEU = 1

function Mesures.etapeCheckpoint(numero: number): number
	return Mesures.ARRIVEE_EN_JEU + numero
end

function Mesures.etapePied(nbEtapes: number): number
	return Mesures.etapeCheckpoint(nbEtapes) + 1
end

function Mesures.etapeSommet(nbEtapes: number): number
	return Mesures.etapePied(nbEtapes) + 1
end

function Mesures.nouveauSuivi(): Suivi
	return { franchies = {}, etape = nil, morts = 0, envoyees = {} }
end

--- Ce joueur est-il mesuré ? Jamais un testeur, même à pied (son étape sauvegardée a pu être atteinte en vol dans une
--- partie précédente), ni une course où l'on a volé.
function Mesures.estMesure(testeurs: { [number]: boolean }, identifiant: number, vol: boolean): boolean
	return not vol and testeurs[identifiant] ~= true
end

--- Cette étape de l'entonnoir est-elle à envoyer ? Vrai une seule fois par suivi.
function Mesures.franchir(suivi: Suivi, etape: number): boolean
	if suivi.franchies[etape] then
		return false
	end
	suivi.franchies[etape] = true
	return true
end

--- La plus haute étape de l'entonnoir que la sauvegarde prouve. Envoyée au chargement, elle évite qu'un joueur déjà
--- avancé avant les mesures passe pour un abandon à l'arrivée (Roblox tient pour faites les étapes sautées, et ignore
--- les répétées).
--- `anciensRecordsTour` n'est pas lu : les records d'une tour remplacée (Reglages.VERSION_TOUR) ne prouvent rien sur
--- l'actuelle, et les étapes déjà envoyées pour l'ancienne restent acquises chez Roblox.
function Mesures.dejaAtteinte(donnees: DonneesLues, nbEtapes: number): number
	if donnees.meilleurTempsAscension > 0 then
		return Mesures.etapeSommet(nbEtapes)
	elseif donnees.meilleureHauteur > 0 then
		return Mesures.etapePied(nbEtapes)
	end
	return Mesures.etapeCheckpoint(if donnees.tutoFini then nbEtapes else donnees.etape)
end

--- Les morts en attente, remises à zéro ; nil s'il n'y en a pas.
function Mesures.partir(suivi: Suivi): Envoi?
	local etape, morts = suivi.etape, suivi.morts
	suivi.etape, suivi.morts = nil, 0
	return if etape ~= nil and morts > 0 then { etape = etape, morts = morts } else nil
end

--- Le joueur est maintenant à cette étape : les morts d'une autre sont à envoyer, si elles ne l'ont pas déjà été.
function Mesures.changerEtape(suivi: Suivi, etape: number): Envoi?
	if suivi.etape == etape then
		return nil
	end
	local envoi = Mesures.partir(suivi)
	suivi.etape = etape
	if envoi == nil or suivi.envoyees[envoi.etape] then
		return nil
	end
	suivi.envoyees[envoi.etape] = true
	return envoi
end

--- Une mort à cette étape. Rend l'envoi des morts d'une étape quittée sans checkpoint (« Recommencer »), ou nil.
function Mesures.mort(suivi: Suivi, etape: number): Envoi?
	local envoi = Mesures.changerEtape(suivi, etape)
	suivi.morts += 1
	return envoi
end

--- Valeur du champ personnalisé d'une mort : l'étape, sur deux chiffres pour que le tableau de bord la trie.
function Mesures.libelleEtape(etape: number): string
	return string.format("Etape %02d", etape)
end

return Mesures
