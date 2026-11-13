--!strict
-- Tous les textes de l'interface, en un seul endroit pour pouvoir les traduire.
-- (Les zones, anecdotes et vannes viennent de src/partage/Etapes.luau, les vannes de chute de Vannes.luau.)
local Textes = {
	chargement = "…",
	aura = "Aura",
	recommencer = "Recommencer",
	recommencerConfirmer = "Sûr ? Encore une fois",
	menu = "Menu",
	passerEtape = "Passer l'étape (R$)",

	arriveeTitre = "Partiel validé !",
	arriveeFermer = "Fermer",
	arriveeSansChute = "SANS TOMBER. Aura légendaire, respect.",
	arriveeNouveauRecord = "Nouveau record !",
	arriveeNonClasse = "Non classé (étape passée ou partie reprise)",
}

--- « 1:23.46   ·   +1 000 aura »
function Textes.arriveeTempsEtGain(temps: string, gain: string): string
	return `{temps}   ·   {gain} aura`
end

--- « Record : 1:20.00 »
function Textes.arriveeRecord(record: string): string
	return `Record : {record}`
end

return table.freeze(Textes)
