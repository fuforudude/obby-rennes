-- Usage : lune run outils/monde/verifier-sauts.luau (après lune run outils/monde/generer.luau).
-- Vérifie le tracé : depuis le départ, peut-on atteindre chaque checkpoint en sautant de plateforme en plateforme ?
-- Saut possible si : montée <= 4,5 ; vide horizontal (entre bords) <= 6,5 (+ 1 par tranche de 4 de descente, max 9).
-- Signale aussi les plafonds trop bas (moins de 5,5 studs au-dessus d'une plateforme, sur la même emprise)
-- et les pièces mortelles collées à une plateforme de départ de saut (voir « mortels trop proches »).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local modele = roblox.deserializeModel(fs.readFile("monde/Parcours.rbxm"))[1]

type Plateforme = { nom: string, x1: number, x2: number, z1: number, z2: number, haut: number, cp: number? }
local plateformes: { Plateforme } = {}
local solides = {}
local mortels: { Plateforme } = {}

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
	if d:HasTag("Mortel") and d.Name ~= "Vide" then
		local x1, x2, z1, z2 = emprise(d, 0, 0)
		table.insert(mortels, {
			nom = d.Parent.Name .. "/" .. d.Name,
			x1 = x1,
			x2 = x2,
			z1 = z1,
			z2 = z2,
			haut = d.CFrame.Position.Y + d.Size.Y / 2,
		})
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

-- Mortels trop proches : pour chaque saut possible a -> b, une pièce mortelle à moins de 1,5 stud (à l'horizontale)
-- de la plateforme de départ, dont le dessus est entre celui du départ et celui de l'arrivée + 3, frôle le
-- personnage pendant le saut. La grande zone « Vide » est exclue (elle est toujours sous le parcours).
local proches = 0
local vus = {}
for i, a in plateformes do
	for j, b in plateformes do
		if i == j or not sautPossible(a, b) then
			continue
		end
		for _, m in mortels do
			if m.haut >= a.haut and m.haut <= b.haut + 3 and vide(a, m) < 1.5 then
				local cle = a.nom .. "|" .. m.nom
				if vus[cle] then
					continue
				end
				vus[cle] = true
				proches += 1
				print(
					string.format(
						"  mortel trop proche : %s (x %.0f..%.0f, haut %.1f) à %.1f de %s (haut %.1f), saut vers %s (haut %.1f)",
						m.nom,
						m.x1,
						m.x2,
						m.haut,
						vide(a, m),
						a.nom,
						a.haut,
						b.nom,
						b.haut
					)
				)
			end
		end
	end
end
print(`mortels trop proches : {proches}`)

-- Un checkpoint inatteignable ou un mortel trop proche bloque la CI ; les plafonds bas restent un avertissement
-- (deux sont voulus : les barres tournantes).
if #manquants > 0 or proches > 0 then
	process.exit(1)
end
