-- Usage : lune run outils/monde/verifier-sauts.luau (après lune run outils/monde/generer.luau).
-- Vérifie le tracé : depuis le départ, peut-on atteindre chaque checkpoint en sautant de plateforme en plateforme ?
-- Saut possible si : montée <= 4,5 ; vide horizontal (entre bords) <= 6,5 (+ 1 par tranche de 4 de descente, max 9).
-- Signale aussi les plafonds trop bas (moins de 5,5 studs au-dessus d'une plateforme, sur la même emprise).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local modele = roblox.deserializeModel(fs.readFile("monde/Parcours.rbxm"))[1]

type Plateforme = { nom: string, x1: number, x2: number, z1: number, z2: number, haut: number, cp: number? }
local plateformes: { Plateforme } = {}
local solides = {}

local function emprise(p, dx, dz)
	local s, pos = p.Size, p.CFrame.Position
	return pos.X - s.X / 2 + math.min(0, dx),
		pos.X + s.X / 2 + math.max(0, dx),
		pos.Z - s.Z / 2 + math.min(0, dz),
		pos.Z + s.Z / 2 + math.max(0, dz)
end

for _, d in modele:GetDescendants() do
	if not d:IsA("BasePart") then
		continue
	end
	local estZone = d.Parent and d.Parent.Name:match("^%d_") ~= nil
	if not estZone then
		continue
	end
	if d.CanCollide and not d:HasTag("Mortel") and d.Transparency < 1 then
		table.insert(solides, d)
	end
	local marchable = d.CanCollide and d.CanQuery and not d:HasTag("Mortel") and not d:HasTag("Tournant")
	if marchable or d:HasTag("Checkpoint") then
		local dep = d:GetAttribute("Deplacement")
		local dx, dz = 0, 0
		if typeof(dep) == "Vector3" then
			dx, dz = dep.X, dep.Z
		end
		local x1, x2, z1, z2 = emprise(d, dx, dz)
		local haut = d.CFrame.Position.Y + d.Size.Y / 2
		local n = d:GetAttribute("Numero")
		table.insert(
			plateformes,
			{ nom = d.Parent.Name .. "/" .. d.Name, x1 = x1, x2 = x2, z1 = z1, z2 = z2, haut = haut, cp = n }
		)
	end
end

local function vide(a: Plateforme, b: Plateforme): number
	local gx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2))
	local gz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2))
	return math.sqrt(gx * gx + gz * gz)
end

local function sautPossible(a: Plateforme, b: Plateforme): boolean
	local montee = b.haut - a.haut
	if montee > 4.5 then
		return false
	end
	local bonus = if montee < 0 then math.min(2.5, -montee / 4) else 0
	return vide(a, b) <= 6.5 + bonus
end

-- Parcours en largeur depuis le départ.
local depart
for i, p in plateformes do
	if p.cp == 0 then
		depart = i
	end
end
local atteint = { [depart] = true }
local file = { depart }
while #file > 0 do
	local i = table.remove(file, 1)
	for j, q in plateformes do
		if not atteint[j] and sautPossible(plateformes[i], q) then
			atteint[j] = true
			table.insert(file, j)
		end
	end
end

local manquants = {}
for _, p in plateformes do
	if p.cp and not atteint[table.find(plateformes, p)] then
		table.insert(manquants, p.cp)
	end
end
table.sort(manquants)
print(
	`{#plateformes} plateformes, checkpoints inatteignables : {if #manquants == 0
		then "aucun"
		else table.concat(manquants, ", ")}`
)
for i, p in plateformes do
	if not atteint[i] then
		print("  inatteignable : " .. p.nom .. string.format(" (x %.0f, haut %.1f)", (p.x1 + p.x2) / 2, p.haut))
	end
end

-- Plafonds trop bas.
local bas = 0
for _, p in plateformes do
	for _, s in solides do
		local sx1, sx2, sz1, sz2 = emprise(s, 0, 0)
		local dessous = s.CFrame.Position.Y - s.Size.Y / 2
		local chevauche = math.min(p.x2, sx2) - math.max(p.x1, sx1) > 0.5
			and math.min(p.z2, sz2) - math.max(p.z1, sz1) > 0.5
		if chevauche and dessous > p.haut + 0.01 and dessous < p.haut + 5.5 then
			bas += 1
			print(
				string.format(
					"  plafond bas : %s (haut %.1f) sous %s (à %.1f)",
					p.nom,
					p.haut,
					s.Name,
					dessous - p.haut
				)
			)
		end
	end
end
print(`plafonds trop bas : {bas}`)
