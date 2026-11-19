-- Usage : lune run outils/monde/casser-parcours.luau <panne> [sortie.rbxm] [source.rbxm]
--
-- Fabrique un tuto volontairement cassé à partir de monde/Parcours.rbxm, pour montrer que
-- outils/monde/verifier-sauts.luau refuse vraiment une porte de capacité qui ne tient plus en physique réelle.
-- Une panne par porte, chacune posant des marches au milieu du passage qui la rend obligatoire :
--   porte-course      marche entre la DalleDeLaCourse et la BanderoleTendue (9,5 studs en montant de 4,5)
--                     -> « en physique réelle, un chemin mène au bout sans course »
--   porte-dash        marche entre le TremplinDuDash et le checkpoint 7 (16,5 studs au-dessus du jus de poubelle)
--                     -> « … sans dash »
--   porte-double-saut marche au milieu de chaque volée de 8 studs de l'atrium de Sup de Vinci
--                     -> « … sans doubleSaut »
--
-- Le fichier écrit est jetable ; on le passe en premier argument au contrôle :
--   lune run outils/monde/casser-parcours.luau porte-dash
--   lune run outils/monde/verifier-sauts.luau parcours-casse.rbxm   (doit sortir en code 1)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local panne = process.args[1]
local sortie = process.args[2] or "parcours-casse.rbxm"
local source = process.args[3] or "monde/Parcours.rbxm"
assert(panne, "panne attendue : porte-course, porte-dash ou porte-double-saut")

local modele = roblox.deserializeModel(fs.readFile(source))[1]

local marches = 0

--- Toutes les pièces de ce nom, dans l'ordre de l'arbre.
local function nommees(nom: string)
	local liste = {}
	for _, d in modele:GetDescendants() do
		if d:IsA("BasePart") and d.Name == nom then
			table.insert(liste, d)
		end
	end
	return liste
end

local function unique(nom: string)
	local liste = nommees(nom)
	assert(#liste == 1, `{#liste} pièce(s) nommée(s) « {nom} » dans {source} (une seule attendue)`)
	return liste[1]
end

local function dessus(p)
	return p.CFrame.Position.Y + p.Size.Y / 2
end

--- Une marche de 6 × 1 × 6 à mi-chemin de `a` vers `b` : elle coupe en deux le vide ET la montée, donc n'importe
--- quel saut du jeu se franchit alors en deux fois, sans aucune capacité.
local function marche(a, b)
	local pa, pb = a.CFrame.Position, b.CFrame.Position
	local p = roblox.Instance.new("Part")
	marches += 1
	p.Name = `MarcheDeTriche{marches}`
	p.Anchored = true
	p.Size = Vector3.new(6, 1, 6)
	p.CFrame = CFrame.new((pa.X + pb.X) / 2, (dessus(a) + dessus(b)) / 2 - 0.5, (pa.Z + pb.Z) / 2)
	p.Parent = b.Parent
end

local pannes: { [string]: () -> string } = {}

pannes["porte-course"] = function(): string
	marche(unique("DalleDeLaCourse"), unique("BanderoleTendue"))
	return "une marche au milieu du parvis du métro"
end

pannes["porte-dash"] = function(): string
	marche(unique("TremplinDuDash"), unique("Checkpoint7"))
	return "une marche au milieu du jus de poubelle"
end

-- L'atrium est reconnu à sa géométrie et non à des noms de dalles précis : toute paire de dalles séparée d'une
-- volée (7,5 à 9 studs de montée) et assez proche pour qu'on saute de l'une à l'autre reçoit sa marche.
pannes["porte-double-saut"] = function(): string
	local dalles = {}
	for _, nom in { "Marche", "Palier", "Checkpoint15" } do
		for _, p in nommees(nom) do
			table.insert(dalles, p)
		end
	end
	for _, a in dalles do
		for _, b in dalles do
			local montee = dessus(b) - dessus(a)
			local ecart = (Vector3.new(a.CFrame.Position.X, 0, a.CFrame.Position.Z) - Vector3.new(
				b.CFrame.Position.X,
				0,
				b.CFrame.Position.Z
			)).Magnitude
			if montee >= 7.5 and montee <= 9 and ecart <= 20 then
				marche(a, b)
			end
		end
	end
	return "une marche au milieu de chaque volée de l'atrium"
end

local faire = pannes[panne]
assert(faire, `panne « {panne} » inconnue`)
local resume = faire()
assert(marches > 0, `la panne « {panne} » n'a rien trouvé à casser : la carte a changé de forme`)
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(`{source} -> {sortie} : {resume} ({marches} marche(s))`)
