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

	-- Les capacités : le nom court sur la pastille (toujours lisible, sans icône sur mesure) et l'annonce.
	capaciteCourte = { course = "Course", doubleSaut = "Saut ×2", dash = "Dash" },
	annonceTitre = {
		course = "Course débloquée !",
		doubleSaut = "Double saut débloqué !",
		dash = "Dash débloqué !",
	},
	-- Ce que fait la capacité, dans la phrase « <Verbe> <commande> <suite> » (voir annonceCommande).
	annonceAction = {
		course = { avant = "Maintiens ", apres = " pour courir" },
		doubleSaut = { avant = "Rappuie sur ", apres = " en l'air" },
		dash = { avant = "Appuie sur ", apres = " pour foncer" },
	},
	annonceBouton = "le bouton", -- sur mobile, à la place du nom de la touche
	annonceTon = {
		course = "Le métro est en grève ? Tant pis, tu cours.",
		doubleSaut = "Même la tour ne te retient plus.",
		dash = "La Vilaine ? Tu la survoles, tout simplement.",
	},

	-- Ascension.
	hauteurRecord = "Record",
	nonClasse = "non classé",
}

--- « Maintiens Maj pour courir », ou « Maintiens le bouton pour courir » sur mobile (`touche` absent).
function Textes.annonceCommande(capacite: string, touche: string?): string
	local action = (Textes.annonceAction :: { [string]: { avant: string, apres: string } })[capacite]
	if not action then
		return ""
	end
	return `{action.avant}{touche or Textes.annonceBouton}{action.apres}`
end

--- « Record 245 m », puis « · non classé » quand la tentative ne compte plus.
function Textes.ascensionInfo(record: string?, nonClasse: boolean): string
	local morceaux: { string } = {}
	if record then
		table.insert(morceaux, `{Textes.hauteurRecord} {record}`)
	end
	if nonClasse then
		table.insert(morceaux, Textes.nonClasse)
	end
	return table.concat(morceaux, "  ·  ")
end

--- « 1:23.46   ·   +1 000 aura »
function Textes.arriveeTempsEtGain(temps: string, gain: string): string
	return `{temps}   ·   {gain} aura`
end

--- « Record : 1:20.00 »
function Textes.arriveeRecord(record: string): string
	return `Record : {record}`
end

return table.freeze(Textes)
