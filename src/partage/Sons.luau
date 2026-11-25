--!strict
-- Les règles des sons, pures et testées : musique d'une zone et de la tour, hauteur du son de checkpoint, arrivée ou
-- record, et les catalogues (identifiants et volumes). La lecture est dans src/client/Sons.luau.
-- Identifiants : uniquement de l'audio gratuit du compte Roblox (propriétaire 1), vérifié un par un le 2026-11-25 sur
-- l'API publique du Creator Store (apis.roblox.com/toolbox-service/v1/items/details?assetIds=...). Un identifiant vide
-- = pas de son. Aucun morceau sous marque ou d'artiste.

export type Son = { id: string, volume: number }

local Sons = {}

-- Durée (s) du fondu enchaîné entre deux musiques.
Sons.FONDU = 1.5

Sons.MUSIQUES = {
	calme = { id = "rbxassetid://15675069601", volume = 0.2 }, -- Roblox_UI_Loop_Calm_Music, 95 s
	ville = { id = "rbxassetid://130053244401794", volume = 0.2 }, -- TutorialMusic_01, 262 s
	tour = { id = "rbxassetid://15930255433", volume = 0.2 }, -- Roblox_RetroFluteMusic_01, 108 s
} :: { [string]: Son }

Sons.EFFETS = {
	saut = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4 }, -- fourni avec Roblox
	doubleSaut = { id = "rbxassetid://12222124", volume = 0.4 }, -- Short spring sound.wav
	dash = { id = "rbxassetid://12222200", volume = 0.5 }, -- swoosh.wav
	checkpoint = { id = "rbxassetid://12221990", volume = 0.5 }, -- electronicpingshort.wav
	mort = { id = "rbxassetid://79348298352567", volume = 0.5 }, -- Official OOF Sound Effect
	capacite = { id = "rbxassetid://17208327798", volume = 0.6 }, -- Roblox GUI - Aura
	arrivee = { id = "rbxassetid://15675043410", volume = 0.6 }, -- Roblox_UI_Tonal_Stinger
	record = { id = "rbxassetid://12222253", volume = 0.6 }, -- victory.wav
} :: { [string]: Son }

-- Premier checkpoint de chaque musique du parcours : campus et métro, centre-ville, puis la Vilaine et le Thabor.
local DEBUTS: { { etape: number, musique: string } } = {
	{ etape = 11, musique = "calme" },
	{ etape = 5, musique = "ville" },
	{ etape = 0, musique = "calme" },
}

--- Le nom de la musique à jouer (clé de MUSIQUES), ou nil (étape pas encore connue).
function Sons.musique(etape: number?, enAscension: boolean): string?
	if enAscension then
		return "tour"
	end
	if etape == nil then
		return nil
	end
	for _, debut in DEBUTS do
		if etape >= debut.etape then
			return debut.musique
		end
	end
	return nil
end

--- Vitesse de lecture du son de checkpoint : un ton (deux demi-tons) plus haut par checkpoint de la série.
function Sons.vitesseCheckpoint(serie: number, serieMax: number): number
	return 2 ^ (2 * (math.clamp(serie, 1, serieMax) - 1) / 12)
end

--- Le son de checkpoint joue-t-il quand l'étape passe de `avant` (nil : première réception) à `apres` ? Pas à
--- l'arrivée, qui a son propre son.
function Sons.joueCheckpoint(avant: number?, apres: number, nbEtapes: number): boolean
	return avant ~= nil and apres > avant and apres < nbEtapes
end

--- Le seul effet joué à l'arrivée.
function Sons.arrivee(record: boolean): string
	return if record then "record" else "arrivee"
end

-- Ce que `sommet` lit d'un EtatAscension (partage/Remotes).
export type EtatSommet = { recordSommet: boolean? }

--- L'effet à jouer quand l'état de l'ascension passe de `avant` (nil : première réception) à `apres`, ou nil. Il ne joue
--- qu'au passage « sommet pas atteint » -> « atteint » : ni sur un état répété, ni sur un premier message déjà au sommet.
function Sons.sommet(avant: EtatSommet?, apres: EtatSommet): string?
	if avant == nil or avant.recordSommet ~= nil or apres.recordSommet == nil then
		return nil
	end
	return Sons.arrivee(apres.recordSommet)
end

return Sons
