-- Usage : lune run outils/monde/casser-bords.luau <panne> <sortie.rbxm>
--
-- Fabrique une carte volontairement cassée pour montrer que les contrôles des bords refusent vraiment. Par
-- outils/monde/verifier-bords.luau :
--   bord        -> le liseré du pied de l'ascension dépasse d'1 stud de sa dalle, sans être solide
--   traverse    -> un garde-corps de la spirale se traverse
--   invisible   -> une pièce solide est transparente
--   aplomb      -> une façade solide dépasse de la dalle qu'elle porte
--   penche      -> une façade solide est penchée
--   rebord      -> une façade solide pend assez bas sous sa dalle pour qu'on tienne debout dessus
--   maillage    -> un garde-corps solide est déformé par un SpecialMesh
--   mobile      -> le liseré du pied déborde, mais une pièce qui s'efface (Fragile) passe dessous : elle ne soutient rien
--   toit        -> un éclat de la verrière (toit sans requête, hors du chemin) déborde au-dessus du vide
--   exception   -> plus aucun faisceau d'étage : l'exception qui les nomme ne sert plus (carte écrite avec les deux
--                  autres : ce contrôle-là veut toutes les cartes)
-- Par verifier-sauts.luau :
--   mur         -> un mur solide sans requête en travers du tuto, à x = 463,5
--   balcon      -> le balcon 8 de la spirale retiré (ou celui du rang en 3e argument ; après le 9, le dash
--                  et le double saut en sautent un de toute façon) : les garde-corps ne remplacent pas un balcon
--   comble      -> le comble mortel du Parlement prolongé jusqu'aux corniches qu'on escalade
-- Par verifier-evenements.luau :
--   passage     -> la chaussée relevée en travers de la voie
--   balancier   -> un valideur dans le balayage de son portillon
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local panne, sortie = process.args[1], process.args[2]
assert(panne and sortie, "panne et sortie attendues")

type Panne = { carte: string, dossier: string, piece: string, casser: (any) -> (), tout: boolean? }
local PANNES: { [string]: Panne } = {
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
	-- Une petite cale à part, sous une dalle : rien d'autre ne bouge, seul le penché est en cause.
	penche = {
		carte = "Ascension",
		dossier = "Chemin",
		piece = "Pas1_1",
		casser = function(p)
			local cale = roblox.Instance.new("Part")
			cale.Name = "Cale"
			cale.Anchored = true
			cale.CanQuery = false
			cale.Size = Vector3.new(0.5, 1, 0.5)
			cale.CFrame = CFrame.new(p.CFrame.Position - Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(10), 0, 0)
			cale.Parent = p.Parent
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
	maillage = {
		carte = "Parcours",
		dossier = "4_LaTour",
		piece = "GardeCorps",
		casser = function(p)
			roblox.Instance.new("SpecialMesh").Parent = p
		end,
	},
	mobile = {
		carte = "Ascension",
		dossier = "Pied",
		piece = "Lisere",
		casser = function(p)
			p.Size = Vector3.new(28, 0.4, 28)
			local dessous = roblox.Instance.new("Part")
			dessous.Name = "PlancheFragile"
			dessous.Anchored = true
			dessous.Size = Vector3.new(30, 0.2, 30)
			dessous.CFrame = p.CFrame - Vector3.new(0, 0.3, 0)
			dessous:AddTag("Fragile")
			dessous.Parent = p.Parent
		end,
	},
	toit = {
		carte = "Parcours",
		dossier = "9_SupDeVinci",
		piece = "EclatVerriere",
		casser = function(p)
			p.Size = Vector3.new(2.1, 0.12, 4)
		end,
	},
	mur = {
		carte = "Parcours",
		dossier = "5_RueDeLaSoif",
		piece = "Cheminee",
		casser = function(p)
			local mur = roblox.Instance.new("Part")
			mur.Name = "MurDeTriche"
			mur.Anchored = true
			mur.CanQuery = false
			mur.Size = Vector3.new(1, 140, 140)
			mur.CFrame = CFrame.new(463.5, 60, 0)
			mur.Parent = p.Parent
		end,
	},
	comble = {
		carte = "Parcours",
		dossier = "7_Parlement",
		piece = "Comble",
		casser = function(p)
			for _, e in p.Parent:GetChildren() do
				if e.Name == "Comble" then
					e.Size += Vector3.new(6, 0, 0)
					e.CFrame = e.CFrame - Vector3.new(3, 0, 0)
				end
			end
		end,
	},
	balcon = {
		carte = "Parcours",
		dossier = "4_LaTour",
		piece = "Balcon",
		casser = function(p)
			local rang = tonumber(process.args[3] or "8")
			local n = 0
			for _, e in p.Parent:GetChildren() do
				if e.Name == "Balcon" or e.Name == "BalconDuDoubleSaut" then
					n += 1
					if n == rang then
						e:Destroy()
						return
					end
				end
			end
			error(`pas de balcon {rang}`)
		end,
	},
	passage = {
		carte = "Evenements",
		dossier = "Decor",
		piece = "Chaussee",
		casser = function(p)
			p.Size += Vector3.new(0, 6, 0)
			p.CFrame += Vector3.new(0, 3, 0)
		end,
	},
	balancier = {
		carte = "Evenements",
		dossier = "Decor",
		piece = "Valideur",
		casser = function(p)
			p.CFrame = CFrame.new(p.CFrame.X, p.CFrame.Y, p.CFrame.Z * 0.75)
		end,
	},
	exception = {
		carte = "Ascension",
		dossier = "Etages",
		piece = "FaisceauEtage",
		tout = true,
		casser = function(p)
			for _, e in p.Parent:GetChildren() do
				if e.Name == "FaisceauEtage" then
					e.CanCollide = false
					e.Transparency = 1
				end
			end
		end,
	},
}

local p = assert(PANNES[panne], `panne « {panne} » inconnue`)
local source = `monde/{p.carte}.rbxm`
local modele = roblox.deserializeModel(fs.readFile(source))[1]
local piece = modele:FindFirstChild(p.dossier):FindFirstChild(p.piece, true)
assert(piece, `{source} : aucune pièce {p.dossier}/{p.piece}, la panne « {panne} » n'a rien à casser`)
p.casser(piece)
local modeles = { modele }
if p.tout then
	for _, nom in { "Ascension", "Evenements", "Parcours" } do
		if nom ~= p.carte then
			table.insert(modeles, roblox.deserializeModel(fs.readFile(`monde/{nom}.rbxm`))[1])
		end
	end
end
fs.writeFile(sortie, roblox.serializeModel(modeles))
print(`{source} -> {sortie} : {p.dossier}/{p.piece}, panne « {panne} »`)
