--!strict
-- Ce que l'interface affiche, en fonctions pures (testées) : l'étape, le chrono, l'aura et sa série, le texte des
-- panneaux d'anecdote du décor, le résumé de l'écran d'arrivée. Aucun texte français ici : les phrases sont dans
-- src/client/Interface/Textes.luau ; ce module ne rend que des nombres mis en forme et des états.
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

--- Échappe les caractères du texte enrichi de Roblox (RichText), pour qu'une anecdote ne casse pas le balisage.
function Affichage.echapper(texte: string): string
	local resultat = texte:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return resultat
end

--- Le texte d'un panneau du décor : la zone en titre, l'anecdote, puis la vanne (texte enrichi).
function Affichage.textePanneau(etape: Etapes.Etape): string
	local zone = Affichage.echapper(etape.zone)
	local anecdote = Affichage.echapper(etape.anecdote)
	local blague = Affichage.echapper(etape.blague)
	return `<b>{zone}</b>\n\n{anecdote}\n\n<i>{blague}</i>`
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

return Affichage
