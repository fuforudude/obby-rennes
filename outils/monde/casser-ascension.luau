-- Usage : lune run outils/monde/casser-ascension.luau <panne> [sortie.rbxm] [source.rbxm]
--
-- Fabrique une ascension volontairement cassée à partir de monde/Ascension.rbxm, pour montrer que
-- outils/monde/verifier-ascension.luau la refuse vraiment. Chaque panne vise un contrôle :
--   marches      une marche de plus entre chaque dalle du chemin : tout se franchit au saut simple
--                -> « un chemin du pied au sommet existe sans course / sans doubleSaut / sans dash »
--   lasers       période des lasers ramenée à 1,5 s -> « fenêtre de passage garantie … < 1,2 s »
--   pieges       Repos des pièges de mur ramené à 0,4 s -> « attribut Repos … 1,2 s au moins attendues »
--   repos        attribut Repos retiré -> « attribut Repos nil » (pas de repli silencieux sur PIEGE_REPOS)
--   poussee      Poussee des pièges portée à 120 studs/s -> « poussée 120 studs/s > 65 »
--   balanciers   pancartes gonflées à 40 studs -> « à lui seul, il couvre toute la dalle »
--   mobiles      Duree des plateformes mobiles ramenée à 0,3 s -> « le saut d'arrivée … par cycle »
--   effondrables DelaiRetour porté à 20 s -> « DelaiRetour … de 1,2 à 8 s attendues »
--   tournants    Vitesse ramenée à 1,2 rad/s -> « pas plus rapide que le tuto »
--
-- Le fichier écrit est jetable : on le passe en premier argument au contrôle, par exemple
--   lune run outils/monde/casser-ascension.luau lasers
--   lune run outils/monde/verifier-ascension.luau /tmp/ascension-cassee.rbxm
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local panne = process.args[1]
local sortie = process.args[2] or "ascension-cassee.rbxm"
local source = process.args[3] or "monde/Ascension.rbxm"
assert(
	panne,
	"panne attendue : marches, lasers, pieges, repos, poussee, balanciers, mobiles, effondrables ou tournants"
)

local modele = roblox.deserializeModel(fs.readFile(source))[1]

local function tagues(tag: string)
	local liste = {}
	for _, d in modele:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(liste, d)
		end
	end
	return liste
end

local pannes: { [string]: () -> string } = {}

-- Une marche de plus entre chaque dalle du chemin : les montées et les vides sont divisés par deux, donc tout se
-- franchit sans course, sans double saut et sans dash. C'est exactement ce que les trois contrôles doivent refuser.
function pannes.marches(): string
	local suite = {}
	for _, d in modele:GetDescendants() do
		if
			d:IsA("BasePart")
			and (d:HasTag("PiedAscension") or d:HasTag("SommetAscension") or d.Name:match("^Pas%d+_%d+$"))
		then
			table.insert(suite, d)
		end
	end
	table.sort(suite, function(a, b)
		return a.CFrame.Position.Y < b.CFrame.Position.Y
	end)
	local parent = suite[2].Parent
	for i = 1, #suite - 1 do
		local a, b = suite[i], suite[i + 1]
		local hautA = a.CFrame.Position.Y + a.Size.Y / 2
		local hautB = b.CFrame.Position.Y + b.Size.Y / 2
		local marche = roblox.Instance.new("Part")
		marche.Name = `Marche{i}`
		marche.Anchored = true
		marche.Size = Vector3.new(6, 1, 6)
		marche.CFrame = CFrame.new(
			(a.CFrame.Position.X + b.CFrame.Position.X) / 2,
			(hautA + hautB) / 2 - 0.5,
			(a.CFrame.Position.Z + b.CFrame.Position.Z) / 2
		)
		marche.Parent = parent
	end
	return `{#suite - 1} marches ajoutées`
end

function pannes.lasers(): string
	local n = 0
	for _, l in tagues("Laser") do
		l:SetAttribute("Periode", 1.5)
		n += 1
	end
	return `{n} lasers ramenés à une période de 1,5 s`
end

-- La fenêtre de passage d'un piège de mur, c'est son repos (la pointe frappe pendant la sortie ET la rentrée :
-- src/partage/Pieges.luau). Trop court, la dalle n'est plus traversable.
function pannes.pieges(): string
	local n = 0
	for _, m in tagues("PiegeMur") do
		m:SetAttribute("Repos", 0.4)
		n += 1
	end
	return `{n} pièges de mur ramenés à 0,4 s de repos`
end

-- Repos absent : le serveur retomberait en silence sur Reglages.PIEGE_REPOS. Le contrôle doit l'exiger.
function pannes.repos(): string
	local n = 0
	for _, m in tagues("PiegeMur") do
		m:SetAttribute("Repos", nil)
		n += 1
	end
	return `{n} pièges de mur privés de leur attribut Repos`
end

-- Poussée au-dessus du plafond du serveur : le joueur ne peut plus se rattraper au dash, et le serveur raboterait
-- la valeur sans rien dire.
function pannes.poussee(): string
	local n = 0
	for _, m in tagues("PiegeMur") do
		m:SetAttribute("Poussee", 120)
		n += 1
	end
	return `{n} pièges de mur poussant à 120 studs/s`
end

function pannes.balanciers(): string
	local n = 0
	for _, b in tagues("Balancier") do
		b.Size = Vector3.new(40, 40, 40)
		n += 1
	end
	return `{n} pancartes gonflées à 40 studs`
end

function pannes.mobiles(): string
	local n = 0
	for _, p in tagues("Mobile") do
		p:SetAttribute("Duree", 0.3)
		n += 1
	end
	return `{n} plateformes mobiles ramenées à 0,3 s de course`
end

function pannes.effondrables(): string
	local n = 0
	for _, p in tagues("Effondrable") do
		p:SetAttribute("DelaiRetour", 20)
		n += 1
	end
	return `{n} plateformes qui s'effondrent avec un retour à 20 s`
end

function pannes.tournants(): string
	local n = 0
	for _, b in tagues("Tournant") do
		b:SetAttribute("Vitesse", 1.2)
		n += 1
	end
	return `{n} barres tournantes ramenées à 1,2 rad/s (le tuto en fait 1,6)`
end

local faire = pannes[panne]
assert(faire, `panne « {panne} » inconnue`)
local resume = faire()
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(`{source} -> {sortie} : {resume}`)
