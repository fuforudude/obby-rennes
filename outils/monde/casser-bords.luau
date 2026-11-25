-- Usage : lune run outils/monde/casser-bords.luau <panne> <sortie.rbxm>
--
-- Fabrique une carte volontairement cassée pour montrer que outils/monde/verifier-bords.luau refuse vraiment :
--   bord        -> le liseré du pied de l'ascension dépasse d'1 stud de sa dalle, sans être solide
--   traverse    -> un garde-corps de la spirale se traverse
--   invisible   -> une pièce solide est transparente
--   aplomb      -> une façade solide dépasse de la dalle qu'elle porte
--   penche      -> une façade solide est penchée
--   rebord      -> une façade solide pend assez bas sous sa dalle pour qu'on tienne debout dessus
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local panne, sortie = process.args[1], process.args[2]
assert(panne and sortie, "panne et sortie attendues")

local PANNES: { [string]: { carte: string, dossier: string, piece: string, casser: (any) -> () } } = {
	bord = {
		carte = "Ascension",
		dossier = "Pied",
		piece = "Lisere",
		casser = function(p)
			p.Size = Vector3.new(28, 0.4, 28)
		end,
	},
	traverse = {
		carte = "Parcours",
		dossier = "4_LaTour",
		piece = "GardeCorps",
		casser = function(p)
			p.CanCollide = false
		end,
	},
	invisible = {
		carte = "Parcours",
		dossier = "4_LaTour",
		piece = "GardeCorps",
		casser = function(p)
			p.Transparency = 1
		end,
	},
	aplomb = {
		carte = "Ascension",
		dossier = "Chemin",
		piece = "Facade",
		casser = function(p)
			p.CFrame += Vector3.new(2, 0, 0)
		end,
	},
	penche = {
		carte = "Ascension",
		dossier = "Chemin",
		piece = "Facade",
		casser = function(p)
			p.Size = Vector3.new(1, 4, 1)
			p.CFrame *= CFrame.Angles(math.rad(10), 0, 0)
		end,
	},
	rebord = {
		carte = "Ascension",
		dossier = "Chemin",
		piece = "Facade",
		casser = function(p)
			p.CFrame -= Vector3.new(0, 8, 0)
		end,
	},
}

local p = assert(PANNES[panne], `panne « {panne} » inconnue`)
local source = `monde/{p.carte}.rbxm`
local modele = roblox.deserializeModel(fs.readFile(source))[1]
local piece = modele:FindFirstChild(p.dossier):FindFirstChild(p.piece)
assert(piece, `{source} : aucune pièce {p.dossier}/{p.piece}, la panne « {panne} » n'a rien à casser`)
p.casser(piece)
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(`{source} -> {sortie} : {p.dossier}/{p.piece}, panne « {panne} »`)
