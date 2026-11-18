--!strict
-- Ce que l'interface affiche, en fonctions pures (testées) : l'étape, le chrono, l'aura et sa série, le texte des
-- panneaux d'anecdote du décor, le résumé de l'écran d'arrivée, et pour l'ascension : les capacités à montrer, l'annonce
-- d'un déblocage, la hauteur et le record, les lignes du menu des paliers. Aucune phrase française ici : elles sont
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
	paliers: { number }, -- numéros des paliers débloqués
	debut: number?, -- horloge du serveur ; absent hors tentative
	classable: boolean,
}

export type ResumeAscension = {
	hauteur: string, -- « 182 m »
	record: string?, -- « 245 m » ; absent tant qu'il n'y en a pas
	nonClasse: boolean,
}

export type LignePalier = {
	numero: number,
	hauteur: string?, -- absent quand la carte du palier n'est pas connue du client
	debloque: boolean,
}

local ORDRE_CAPACITES: { Capacite } = { "course", "doubleSaut", "dash" }
-- Les touches clavier de chaque capacité (le dash est sur la touche marquée A, soit KeyCode.Q).
local TOUCHES: { [Capacite]: string } = { course = "Maj", doubleSaut = "Espace", dash = "A" }
local PALIERS_PAR_DEFAUT = 5 -- l'ascension a 4 à 5 paliers ; tant que rien n'est connu, on en liste 5
local PALIERS_MAX = 10 -- garde-fou contre une valeur absurde

local Affichage = {}

Affichage.PALIERS_PAR_DEFAUT = PALIERS_PAR_DEFAUT

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
	for _, capacite in ORDRE_CAPACITES do
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
	for _, capacite in ORDRE_CAPACITES do
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
	local connue = Affichage.capacite(capacite)
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

--- Les numéros de palier valides d'une liste reçue du réseau : entiers de 1 à 10, sans doublon, triés.
local function numerosValides(paliers: any): { number }
	local resultat: { number } = {}
	if type(paliers) ~= "table" then
		return resultat
	end
	for _, numero in paliers do
		if
			type(numero) == "number"
			and numero == math.floor(numero)
			and numero >= 1
			and numero <= PALIERS_MAX
			and not table.find(resultat, numero)
		then
			table.insert(resultat, numero)
		end
	end
	table.sort(resultat)
	return resultat
end

--- Le menu « Paliers » existe dès qu'un palier est débloqué.
function Affichage.paliersDisponibles(paliers: any): boolean
	return #numerosValides(paliers) > 0
end

--- Combien de paliers lister : jusqu'au plus haut palier vu sur la carte ou débloqué ; tant que la carte n'a rien
--- donné (streaming, remote en retard), 5 au moins.
function Affichage.nombrePaliers(debloques: any, hauteurs: { [number]: number }): number
	local debloque = 0
	for _, numero in numerosValides(debloques) do
		debloque = math.max(debloque, numero)
	end
	local vu = 0
	for numero in hauteurs do
		if numero >= 1 and numero <= PALIERS_MAX then
			vu = math.max(vu, numero)
		end
	end
	if vu == 0 then
		return math.max(PALIERS_PAR_DEFAUT, debloque)
	end
	return math.max(vu, debloque)
end

--- La hauteur d'un palier AU-DESSUS DU PIED de l'ascension, en studs (le repère de `EtatAscension.hauteur`).
--- `relative` : attribut `HauteurRelative` de la carte, à préférer. À défaut, `absolue` (attribut `Hauteur`, le Y de
--- la carte) moins `piedAbsolu` (le `Hauteur` du pied). Rend nil si rien de fiable : mieux vaut ne rien afficher
--- qu'un chiffre faux. Un nombre négatif ou infini n'est pas une hauteur.
function Affichage.hauteurPalier(relative: any, absolue: any, piedAbsolu: any): number?
	local function valide(v: any): boolean
		return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
	end
	if valide(relative) and relative >= 0 then
		return relative
	end
	if valide(absolue) and valide(piedAbsolu) and absolue >= piedAbsolu then
		return absolue - piedAbsolu
	end
	return nil
end

--- Une ligne du menu : le numéro, la hauteur du palier (si la carte l'a donnée) et s'il est débloqué.
function Affichage.lignePalier(
	numero: number,
	debloque: boolean,
	hauteur: number?,
	formater: (number) -> string
): LignePalier
	return { numero = numero, hauteur = if hauteur then formater(hauteur) else nil, debloque = debloque }
end

--- Toutes les lignes du menu, de 1 au dernier palier connu ; `hauteurs` : numéro du palier -> hauteur en studs au-dessus du pied.
function Affichage.lignesPaliers(
	debloques: any,
	hauteurs: { [number]: number },
	formater: (number) -> string
): { LignePalier }
	local valides = numerosValides(debloques)
	local lignes: { LignePalier } = {}
	for numero = 1, Affichage.nombrePaliers(valides, hauteurs) do
		table.insert(
			lignes,
			Affichage.lignePalier(numero, table.find(valides, numero) ~= nil, hauteurs[numero], formater)
		)
	end
	return lignes
end

return Affichage
