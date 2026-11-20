-- Usage : lune run outils/monde/verifier-contrats.luau [carte.rbxm ...] [parcours=table.luau] [tags=tags.luau]
-- (défaut : toutes les sorties de outils/monde/monde.json, le registre des cartes, après lune run
-- outils/monde/generer.luau ; table du parcours : outils/monde/donnees/parcours.luau). `tags=` remplace des entrées
-- de TAGS_CONNUS par celles d'un fichier Luau qui rend { [tag] = lecteurs } : ne sert qu'aux cartes cassées.
--
-- Contrats carte ↔ jeu, sur l'ensemble des cartes données :
-- - aucun tag inconnu : chaque tag posé est dans TAGS_CONNUS ci-dessous (ce que le jeu lit vraiment). Un tag mal
--   orthographié ou un nouveau piège que personne ne lit serait sinon ignoré en silence ;
-- - chaque fichier lecteur cité dans TAGS_CONNUS existe (plusieurs lecteurs séparés par « et ») ;
-- - les checkpoints (tag « Checkpoint ») portent un Numero entier, et l'ensemble des Numero est exactement
--   0..NB_ETAPES (src/partage/Reglages.luau), chacun une seule fois : ni trou, ni doublon, ni numéro en trop ;
-- - la source unique des checkpoints (outils/monde/donnees/parcours.luau) a exactement NB_ETAPES + 1 entrées,
--   numérotées 0..NB_ETAPES dans l'ordre, et le nom de zone écrit sur la carte (`nomArche`) est celui de
--   src/partage/Etapes.luau (HUD, titre du panneau d'anecdote).
-- Code de sortie 1 au moindre défaut.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
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

local fichiers = {}
local cheminParcours = "outils/monde/donnees/parcours.luau"
local cheminTags: string? = nil
for _, arg in process.args do
	local autre = string.match(arg, "^parcours=(.+)$")
	local tags = string.match(arg, "^tags=(.+)$")
	if autre then
		cheminParcours = autre
	elseif tags then
		cheminTags = tags
	else
		table.insert(fichiers, arg)
	end
end
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

if cheminTags then
	for tag, lecteurs in luau.load(fs.readFile(cheminTags), { debugName = cheminTags })() do
		TAGS_CONNUS[tag] = lecteurs
	end
end

-- Un lecteur renommé ou supprimé laisserait un tag « connu » que plus personne ne lit.
for tag, lecteurs in TAGS_CONNUS do
	for chemin in string.gmatch(lecteurs .. " et ", "(.-) et ") do
		if not fs.isFile(chemin) then
			defaut(`TAGS_CONNUS : le lecteur du tag « {tag} », {chemin}, n'existe pas`)
		end
	end
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

-- Source unique des checkpoints : une entrée par checkpoint, dans l'ordre des numéros.
local donnees = luau.load(fs.readFile(cheminParcours), { debugName = cheminParcours })()
local table_ = donnees.checkpoints
if #table_ ~= NB_ETAPES + 1 then
	defaut(
		`{cheminParcours} : la table des checkpoints a {#table_} entrées, NB_ETAPES + 1 = {NB_ETAPES + 1} attendues`
	)
end
for i, c in table_ do
	if c.numero ~= i - 1 then
		defaut(
			`{cheminParcours} : l'entrée {i} porte le numéro {tostring(c.numero)}, {i - 1} attendu (ordre des numéros)`
		)
	end
end

-- Noms de zone : le texte écrit sur la carte (arche ou nom flottant) et celui de src/partage/Etapes.luau (HUD, titre du
-- panneau d'anecdote) nomment la même chose, la zone du checkpoint : ils doivent être identiques.
local Etapes = luau.load(fs.readFile("src/partage/Etapes.luau"), { debugName = "Etapes" })()
for _, c in table_ do
	local etape = Etapes.obtenir(c.numero)
	local zone = etape and etape.zone
	if zone ~= c.nomArche then
		defaut(
			`zone n°{c.numero} : « {tostring(c.nomArche)} » sur la carte ({cheminParcours}), « {tostring(zone)} » dans src/partage/Etapes.luau`
		)
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
