--!strict
-- Ce que l'interface affiche, en fonctions pures (testées) : l'étape, le chrono, l'aura et sa série, le texte des
-- panneaux d'anecdote du décor, le résumé de l'écran d'arrivée, et pour l'ascension : les capacités à montrer, l'annonce
-- d'un déblocage, la hauteur et le record. Aucune phrase française ici : elles sont
-- dans src/client/Interface/Textes.luau ; ce module ne rend que des nombres mis en forme, des noms de touche et des
-- états. La mise en forme d'une hauteur (« 182 m ») appartient à Ascension.formaterHauteur : l'appelant la passe en
-- paramètre (`formater`), ce qui garde ce module sans dépendance et testable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Etapes = require(ReplicatedStorage.Partage.Etapes)
local Regles = require(ReplicatedStorage.Partage.Regles)

export type ResumeArrivee = {
	temps: string, -- « 1:23.46 »
	gain: string, -- « +1 100 » (aura gagnée sur le parcours)
	record: string?, -- le meilleur temps, absent tant qu'il n'y en a pas
	nouveauRecord: boolean,
	nonClasse: boolean, -- étape passée ou partie reprise : le temps n'entre pas au classement
	sansChute: boolean, -- aura légendaire : parcours entier sans tomber
}

-- Les capacités de déplacement (mêmes noms que src/partage/Capacites.luau).
export type Capacite = "course" | "doubleSaut" | "dash"

export type IconeCapacite = {
	capacite: Capacite,
	disponible: boolean, -- false : consommée (double saut ou dash déjà utilisé), revient au contact du sol
}

export type Annonce = {
	capacite: Capacite,
	touche: string?, -- « Maj », « Espace », « A » ; absent sur mobile (on parle alors du bouton)
}

--- L'état d'ascension envoyé par le serveur (remote EtatAscension).
export type EtatAscension = {
	enAscension: boolean,
	hauteur: number, -- studs
	meilleureHauteur: number, -- studs
	debut: number?, -- horloge du serveur ; absent hors tentative
	classable: boolean,
}

export type ResumeAscension = {
	hauteur: string, -- « 182 m »
	record: string?, -- « 245 m » ; absent tant qu'il n'y en a pas
	nonClasse: boolean,
}

local ORDRE_CAPACITES: { Capacite } = { "course", "doubleSaut", "dash" }
-- Les touches clavier de chaque capacité (le dash est sur la touche marquée A, soit KeyCode.Q).
local TOUCHES: { [Capacite]: string } = { course = "Maj", doubleSaut = "Espace", dash = "A" }

local Affichage = {}

--- « 7/15 » : le numéro de l'étape sur le total, toujours entre 0 et le total.
function Affichage.etape(numero: number, total: number): string
	return `{math.clamp(math.floor(numero), 0, total)}/{total}`
end

--- « 4 200 ×6 » : l'aura, puis la série à partir de ×2 (plafonnée).
function Affichage.aura(aura: number, serie: number, serieMax: number): string
	local texte = Regles.formaterAura(aura)
	local multiplicateur = math.clamp(math.floor(serie), 0, serieMax)
	if multiplicateur >= 2 then
		texte ..= ` ×{multiplicateur}`
	end
	return texte
end

--- Le chrono : depuis `debut` (horloge du serveur) en course, sinon le dernier temps de la course finie, sinon zéro.
function Affichage.chrono(debut: number?, maintenant: number, dernierTemps: number?): string
	if debut then
		return Regles.formaterTemps(maintenant - debut)
	end
	return Regles.formaterTemps(dernierTemps or 0)
end

--- Le menu en coin n'existe que si le produit « Passer l'étape » est créé et qu'il reste une étape à passer.
function Affichage.passerVisible(produit: number, etape: number, total: number): boolean
	return produit ~= 0 and etape < total
end

--- Le texte d'un panneau du décor, en deux morceaux de texte simple (sans balises) : le titre (la zone) et le corps
--- (l'anecdote, une ligne vide, puis la vanne).
function Affichage.textePanneau(etape: Etapes.Etape): (string, string)
	return etape.zone, `{etape.anecdote}\n\n{etape.blague}`
end

--- Résumé de l'écran d'arrivée. `gainAura` > `auraArrivee` veut dire que le bonus « sans chute » est compris.
function Affichage.arrivee(
	temps: number,
	classable: boolean,
	record: boolean,
	gainAura: number,
	meilleurTemps: number,
	auraArrivee: number
): ResumeArrivee
	return {
		temps = Regles.formaterTemps(temps),
		gain = `+{Regles.formaterAura(gainAura)}`,
		record = if meilleurTemps > 0 then Regles.formaterTemps(meilleurTemps) else nil,
		nouveauRecord = record,
		nonClasse = not classable,
		sansChute = gainAura > auraArrivee,
	}
end

--- Une capacité reconnue (ou `nil` pour toute autre valeur : une donnée reçue du réseau n'est jamais crue).
function Affichage.capacite(valeur: any): Capacite?
	if type(valeur) ~= "string" then
		return nil
	end
	for _, capacite: Capacite in ORDRE_CAPACITES do
		if capacite == valeur then
			return capacite
		end
	end
	return nil
end

--- Les capacités à montrer, dans l'ordre course, double saut, dash : seulement les débloquées (`capacites` vient de
--- EtatCourse). `doubleSautPret` et `dashPret` viennent des attributs du joueur posés par le contrôleur des capacités ;
--- absents (`nil`), la capacité est montrée disponible. La course ne se consomme jamais.
function Affichage.icones(capacites: any, doubleSautPret: boolean?, dashPret: boolean?): { IconeCapacite }
	local resultat: { IconeCapacite } = {}
	if type(capacites) ~= "table" then
		return resultat
	end
	for _, capacite: Capacite in ORDRE_CAPACITES do
		if capacites[capacite] == true then
			local consommee = (capacite == "doubleSaut" and doubleSautPret == false)
				or (capacite == "dash" and dashPret == false)
			table.insert(resultat, { capacite = capacite, disponible = not consommee })
		end
	end
	return resultat
end

--- L'annonce d'un déblocage : la capacité et la touche (rien sur mobile, où l'on parle du bouton). `nil` si la
--- capacité reçue n'existe pas.
function Affichage.annonce(capacite: any, tactile: boolean): Annonce?
	local connue: Capacite? = Affichage.capacite(capacite)
	if not connue then
		return nil
	end
	return { capacite = connue, touche = if tactile then nil else TOUCHES[connue] }
end

--- La hauteur du joueur et son record, mis en forme par `formater` (Ascension.formaterHauteur). Le record n'existe
--- qu'à partir d'une première hauteur ; « non classé » dès que la tentative n'est plus classable.
function Affichage.ascension(etat: EtatAscension, formater: (number) -> string): ResumeAscension
	return {
		hauteur = formater(math.max(0, etat.hauteur)),
		record = if etat.meilleureHauteur > 0 then formater(etat.meilleureHauteur) else nil,
		nonClasse = not etat.classable,
	}
end

return Affichage
