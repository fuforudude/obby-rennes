-- Usage : lune run outils/monde/verifier-contrats.luau [carte.rbxm ...]
-- (défaut : toutes les sorties de outils/monde/monde.json ; après lune run outils/monde/generer.luau).
--
-- Contrats carte ↔ jeu, sur l'ensemble des cartes données :
-- - aucun tag inconnu : chaque tag posé est dans TAGS_CONNUS ci-dessous (ce que le jeu lit vraiment). Un tag mal
--   orthographié ou un nouveau piège que personne ne lit serait sinon ignoré en silence ;
-- - les checkpoints (tag « Checkpoint ») portent un Numero entier, et l'ensemble des Numero est exactement
--   0..NB_ETAPES (src/partage/Reglages.luau), chacun une seule fois : ni trou, ni doublon, ni numéro en trop.
-- Code de sortie 1 au moindre défaut.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Reglages = require("./physique").Reglages

-- Les tags que le jeu lit, et qui les lit. Ajouter un tag à la carte = l'ajouter ici, avec son lecteur.
local TAGS_CONNUS = {
	Checkpoint = "src/serveur/Parcours.luau",
	Mortel = "src/serveur/Obstacles/Mortel.luau",
	Fragile = "src/serveur/Obstacles/Fragile.luau",
	Mobile = "src/serveur/Obstacles/Mobile.luau",
	Tournant = "src/serveur/Obstacles/Tournant.luau",
	Balancier = "src/serveur/Obstacles/Balancier.luau",
	Laser = "src/serveur/Obstacles/Laser.luau",
	Effondrable = "src/serveur/Obstacles/Effondrable.luau",
	PiegeMur = "src/serveur/Obstacles/PiegeMur.luau",
	DeblocageCapacite = "src/serveur/Capacites.luau",
	Evenement = "src/client/Evenements.luau et src/serveur/Evenements.luau",
	PanneauAnecdote = "src/client/Interface/Panneaux.luau",
	PiedAscension = "src/serveur/Ascension.luau",
	EtageAscension = "src/serveur/Ascension.luau",
	SommetAscension = "src/serveur/Ascension.luau",
	TableauClassement = "src/serveur/Classement.luau",
	TableauAura = "src/serveur/Classement.luau",
	TableauHauteur = "src/serveur/Classement.luau",
	TableauAscension = "src/serveur/Classement.luau",
}

local fichiers = process.args
if #fichiers == 0 then
	fichiers = {}
	for _, entree in serde.decode("json", fs.readFile("outils/monde/monde.json")) do
		table.insert(fichiers, entree.sortie)
	end
	table.sort(fichiers)
end

local defauts = 0
local function defaut(message: string)
	defauts += 1
	print("  DÉFAUT : " .. message)
end

local NB_ETAPES = Reglages.NB_ETAPES
local checkpoints: { [number]: { string } } = {}
local parTag: { [string]: number } = {}

for _, chemin in fichiers do
	for _, racine in roblox.deserializeModel(fs.readFile(chemin)) do
		local instances = racine:GetDescendants()
		table.insert(instances, racine)
		for _, d in instances do
			for _, tag in d:GetTags() do
				parTag[tag] = (parTag[tag] or 0) + 1
				if not TAGS_CONNUS[tag] then
					defaut(`{chemin} : {d:GetFullName()} porte le tag inconnu « {tag} » (aucun lecteur dans le jeu)`)
				end
			end
			if d:HasTag("Checkpoint") then
				local n = d:GetAttribute("Numero")
				if typeof(n) ~= "number" or n % 1 ~= 0 then
					defaut(`{chemin} : {d:GetFullName()} taguée Checkpoint, Numero {tostring(n)} (entier attendu)`)
				else
					checkpoints[n] = checkpoints[n] or {}
					table.insert(checkpoints[n], `{chemin} : {d:GetFullName()}`)
				end
			end
		end
	end
end

for n = 0, NB_ETAPES do
	local poses = checkpoints[n]
	if not poses then
		defaut(`aucun checkpoint de Numero {n} (attendus : 0..{NB_ETAPES}, NB_ETAPES de Reglages)`)
	elseif #poses > 1 then
		defaut(`checkpoint de Numero {n} en {#poses} exemplaires : {table.concat(poses, ", ")}`)
	end
end
for n, poses in checkpoints do
	if n < 0 or n > NB_ETAPES then
		defaut(`checkpoint de Numero {n} hors de 0..{NB_ETAPES} : {table.concat(poses, ", ")}`)
	end
end

local resume = {}
for tag, nombre in parTag do
	table.insert(resume, `{tag} {nombre}`)
end
table.sort(resume)
print(`{table.concat(fichiers, ", ")} : tags {table.concat(resume, ", ")}`)
print(`checkpoints attendus 0..{NB_ETAPES} ; défauts : {defauts}`)
if defauts > 0 then
	process.exit(1)
end
