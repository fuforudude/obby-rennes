-- Usage : lune run outils/monde/casser-contrats.luau <panne> [sortie.rbxm] [source.rbxm]
--
-- Fabrique un tuto volontairement cassé à partir de monde/Parcours.rbxm, pour prouver que les contrôles voient
-- les hypothèses qu'ils ne doivent plus faire (spec 2026-11-20-refonte-modulaire). Une panne par contrôle :
--   sans-checkpoint-7  le checkpoint n°7 retiré     -> verifier-contrats : « aucun checkpoint de Numero 7 »
--   tag-inconnu        un tag « PiegeInconnu » posé  -> verifier-contrats : « tag inconnu « PiegeInconnu » »
--   zone-10            le dernier checkpoint rangé dans un dossier de zone « 10_Test » et monté de 60 studs : saut
--                      infranchissable -> verifier-sauts : « inatteignable : 10_Test/Checkpoint<N> ». Avec l'ancien
--                      motif de zone (« ^%d_ », un seul chiffre), ce dossier était ignoré et le contrôle restait vert.
--
-- Le fichier écrit est jetable ; on le passe en premier argument au contrôle :
--   lune run outils/monde/casser-contrats.luau zone-10 parcours-casse.rbxm
--   lune run outils/monde/verifier-sauts.luau parcours-casse.rbxm   (doit sortir en code 1)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Reglages = require("./physique").Reglages

local panne = process.args[1]
local sortie = process.args[2] or "parcours-casse.rbxm"
local source = process.args[3] or "monde/Parcours.rbxm"
assert(panne, "panne attendue : sans-checkpoint-7, tag-inconnu ou zone-10")

local modele = roblox.deserializeModel(fs.readFile(source))[1]

local function checkpoint(n: number)
	for _, d in modele:GetDescendants() do
		if d:HasTag("Checkpoint") and d:GetAttribute("Numero") == n then
			return d
		end
	end
	error(`aucun checkpoint de Numero {n} dans {source}`)
end

local pannes: { [string]: () -> string } = {}

pannes["sans-checkpoint-7"] = function(): string
	local cp = checkpoint(7)
	local nom = cp:GetFullName()
	cp:Destroy()
	return `{nom} retiré`
end

pannes["tag-inconnu"] = function(): string
	local cp = checkpoint(0)
	cp:AddTag("PiegeInconnu")
	return `tag « PiegeInconnu » posé sur {cp.Name}`
end

pannes["zone-10"] = function(): string
	local cp = checkpoint(Reglages.NB_ETAPES)
	local zone = roblox.Instance.new("Folder")
	zone.Name = "10_Test"
	zone.Parent = modele
	cp.Parent = zone
	cp.CFrame = cp.CFrame + roblox.Vector3.new(0, 60, 0)
	return `{cp.Name} rangé dans 10_Test et monté de 60 studs`
end

local faire = pannes[panne]
assert(faire, `panne « {panne} » inconnue (sans-checkpoint-7, tag-inconnu ou zone-10)`)
local resume = faire()
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(`{source} -> {sortie} : {resume}`)
