-- Usage : lune run outils/monde/casser-parcours.luau <panne> [sortie.rbxm] [source.rbxm]
--
-- Fabrique un tuto volontairement cassé à partir de monde/Parcours.rbxm, pour montrer que la section « Portes
-- strictement nécessaires (physique réelle) » de outils/monde/verifier-sauts.luau refuse vraiment un parcours où
-- une capacité cesse d'être obligatoire. Une panne par capacité :
--   course            -> « en physique réelle, un chemin mène au bout sans course »
--   dash              -> « … sans dash »
--   double-saut       -> « … sans doubleSaut »
--
-- Chaque panne vise la **capacité**, pas un saut nommé : elle ne sait pas où est la porte, elle la cherche. Elle
-- rejoue le parcours en largeur en physique réelle **sans** la capacité (exactement comme le contrôle, capacités
-- ramassées en chemin comprises), repère la frontière — les sauts qui mènent de ce qu'on atteint à ce qu'on
-- n'atteint pas — et pose deux marches au tiers et aux deux tiers de chacun. Vide et montée divisés par trois :
-- la frontière s'ouvre. Elle recommence jusqu'à ce que le dernier checkpoint soit atteint sans la capacité. Si
-- le contrôle reste vert après ça, c'est qu'il ne prouve rien.
--
-- Le fichier écrit est jetable ; on le passe en premier argument au contrôle :
--   lune run outils/monde/casser-parcours.luau dash
--   lune run outils/monde/verifier-sauts.luau parcours-casse.rbxm   (doit sortir en code 1)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Physique = require("./physique")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local C = Physique.CAPACITES

local panne = process.args[1]
local sortie = process.args[2] or "parcours-casse.rbxm"
local source = process.args[3] or "monde/Parcours.rbxm"
assert(panne, "panne attendue : course, dash ou double-saut")

local CAPACITE = { course = C.course, dash = C.dash, ["double-saut"] = C.doubleSaut }
local privee = CAPACITE[panne]
assert(privee, `panne « {panne} » inconnue (course, dash ou double-saut)`)

local modele = roblox.deserializeModel(fs.readFile(source))[1]

-- Les plateformes, lues exactement comme outils/monde/verifier-sauts.luau les lit (emprise élargie du déplacement
-- d'une plateforme mobile comprise), pour viser les mêmes sauts que le contrôle.
type Plateforme = {
	part: any,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	haut: number,
	cp: number?,
	donne: number,
}
local plateformes: { Plateforme } = {}
for _, d in modele:GetDescendants() do
	if not d:IsA("BasePart") or not (d.Parent and d.Parent.Name:match("^%d_")) then
		continue
	end
	local marchable = d.CanCollide and d.CanQuery and not d:HasTag("Mortel") and not d:HasTag("Tournant")
	if not (marchable or d:HasTag("Checkpoint")) then
		continue
	end
	local dep = d:GetAttribute("Deplacement")
	local dx, dz = 0, 0
	if typeof(dep) == "Vector3" then
		dx, dz = dep.X, dep.Z
	end
	local s, pos = d.Size, d.CFrame.Position
	table.insert(plateformes, {
		part = d,
		x1 = pos.X - s.X / 2 + math.min(0, dx),
		x2 = pos.X + s.X / 2 + math.max(0, dx),
		z1 = pos.Z - s.Z / 2 + math.min(0, dz),
		z2 = pos.Z + s.Z / 2 + math.max(0, dz),
		haut = pos.Y + s.Y / 2,
		cp = d:GetAttribute("Numero"),
		donne = if d:HasTag("DeblocageCapacite") then C[d:GetAttribute("Capacite")] or 0 else 0,
	})
end

local depart, dernierCp
for _, p in plateformes do
	if p.cp == 0 then
		depart = p
	end
	if p.cp and (dernierCp == nil or p.cp > dernierCp) then
		dernierCp = p.cp
	end
end
assert(depart and dernierCp, `ni départ ni dernier checkpoint dans {source}`)

local function vide(a: Plateforme, b: Plateforme): number
	local gx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2))
	local gz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2))
	return math.sqrt(gx * gx + gz * gz)
end

local marches = 0
--- Une marche de 6 × 1 × 6 à la fraction `t` du saut a -> b, ajoutée à la carte **et** à la liste des
--- plateformes : la passe suivante la verra et pourra repartir de là.
local function marche(a: Plateforme, b: Plateforme, t: number)
	local pa, pb = a.part.CFrame.Position, b.part.CFrame.Position
	marches += 1
	local p = roblox.Instance.new("Part")
	p.Name = `MarcheDeTriche{marches}`
	p.Anchored = true
	p.Size = Vector3.new(6, 1, 6)
	local x, z = pa.X + (pb.X - pa.X) * t, pa.Z + (pb.Z - pa.Z) * t
	local haut = a.haut + (b.haut - a.haut) * t
	p.CFrame = CFrame.new(x, haut - 0.5, z)
	p.Parent = b.part.Parent
	table.insert(plateformes, {
		part = p,
		x1 = x - 3,
		x2 = x + 3,
		z1 = z - 3,
		z2 = z + 3,
		haut = haut,
		cp = nil,
		donne = 0,
	})
end

--- Ce qu'on atteint sans la capacité, en physique réelle : même parcours en largeur que le contrôle.
local function atteintSansLaCapacite(): { [Plateforme]: number }
	local atteint: { [Plateforme]: number } = {}
	local file = { depart }
	atteint[depart] = bit32.band(depart.donne, bit32.bnot(privee))
	while #file > 0 do
		local a = table.remove(file, 1)
		local caps = atteint[a]
		for _, b in plateformes do
			if a == b or not Physique.franchissable(vide(a, b), b.haut - a.haut, caps) then
				continue
			end
			local avec = bit32.band(bit32.bor(caps, b.donne), bit32.bnot(privee))
			local connu = atteint[b]
			if connu and bit32.band(avec, bit32.bnot(connu)) == 0 then
				continue
			end
			atteint[b] = bit32.bor(connu or 0, avec)
			table.insert(file, b)
		end
	end
	return atteint
end

local function bout(atteint): boolean
	for _, p in plateformes do
		if p.cp == dernierCp and atteint[p] then
			return true
		end
	end
	return false
end

-- Tant que le dernier checkpoint reste hors d'atteinte sans la capacité, on ouvre la frontière.
local PASSES_MAX = 12
local passes, ouverts = 0, 0
while passes < PASSES_MAX do
	local atteint = atteintSansLaCapacite()
	if bout(atteint) then
		break
	end
	passes += 1
	local frontiere = {}
	for _, a in plateformes do
		local caps = atteint[a]
		if not caps then
			continue
		end
		for _, b in plateformes do
			if atteint[b] or a == b then
				continue
			end
			if Physique.franchissable(vide(a, b), b.haut - a.haut, bit32.bor(caps, privee)) then
				table.insert(frontiere, { a, b })
			end
		end
	end
	assert(
		#frontiere > 0,
		`la panne « {panne} » est bloquée : plus aucun saut ne mène de ce qu'on atteint à ce qu'on n'atteint pas`
	)
	for _, paire in frontiere do
		ouverts += 1
		marche(paire[1], paire[2], 1 / 3)
		marche(paire[1], paire[2], 2 / 3)
	end
end
assert(
	ouverts > 0,
	`la panne « {panne} » n'a rien eu à casser : le dernier checkpoint est déjà atteignable sans « {panne} »`
)
assert(passes < PASSES_MAX, `la panne « {panne} » n'a pas réussi à ouvrir la route en {PASSES_MAX} passes`)
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(
	`{source} -> {sortie} : {ouverts} saut(s) de frontière coupés en trois en {passes} passe(s) ({marches} marches)`
)
