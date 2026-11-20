-- Empreinte des cartes : une ligne par instance, triée, stable et diffable, pour prouver qu'une refonte d'un
-- générateur ne change pas la carte (spec 2026-11-20-refonte-modulaire).
--   lune run outils/monde/empreinte.luau <sortie.txt> [fichier.rbxm | dossier ...]   (défaut : le dossier monde)
-- Lecture seule : n'écrit que <sortie.txt>. Comparer deux empreintes : git diff --no-index avant.txt apres.txt.
--
-- Chaque ligne : fichier, chemin complet, classe, puis pour une BasePart la position, la rotation (degrés), la taille,
-- la couleur, le matériau, la transparence et les drapeaux de collision, pour un texte son contenu, enfin les tags
-- triés et les attributs triés. Nombres arrondis à 0,01. Le fichier n'est désigné que par son nom (sans dossier) :
-- deux copies d'une même carte rangées ailleurs ont la même empreinte.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local sortie = process.args[1]
assert(sortie, "usage : lune run outils/monde/empreinte.luau <sortie.txt> [fichier.rbxm | dossier ...]")

local function nombre(x: number): string
	local s = string.format("%.2f", x)
	return if s == "-0.00" then "0.00" else s
end

local function formater(v: any): string
	local t = typeof(v)
	if t == "number" then
		return nombre(v)
	elseif t == "Vector3" then
		return `({nombre(v.X)}, {nombre(v.Y)}, {nombre(v.Z)})`
	elseif t == "Vector2" then
		return `({nombre(v.X)}, {nombre(v.Y)})`
	elseif t == "Color3" then
		return string.format("rgb(%d, %d, %d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "CFrame" then
		local rx, ry, rz = v:ToEulerAnglesXYZ()
		return `{formater(v.Position)} rot({nombre(math.deg(rx))}, {nombre(math.deg(ry))}, {nombre(math.deg(rz))})`
	elseif t == "string" then
		return (string.format("%q", v):gsub("\\\n", "\\n"))
	end
	return `{t}:{tostring(v)}`
end

local function ligne(fichier: string, inst: any): string
	local champs = { fichier, inst:GetFullName(), inst.ClassName }
	if inst:IsA("BasePart") then
		table.insert(champs, "cf=" .. formater(inst.CFrame))
		table.insert(champs, "taille=" .. formater(inst.Size))
		table.insert(champs, "couleur=" .. formater(inst.Color))
		table.insert(champs, "matiere=" .. inst.Material.Name)
		table.insert(champs, "transp=" .. nombre(inst.Transparency))
		table.insert(
			champs,
			string.format(
				"ancre=%s collision=%s toucher=%s requete=%s",
				tostring(inst.Anchored),
				tostring(inst.CanCollide),
				tostring(inst.CanTouch),
				tostring(inst.CanQuery)
			)
		)
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		table.insert(champs, "texte=" .. formater(inst.Text))
	end
	local tags = inst:GetTags()
	table.sort(tags)
	if #tags > 0 then
		table.insert(champs, "tags=" .. table.concat(tags, ","))
	end
	local attributs = {}
	for nom, valeur in inst:GetAttributes() do
		table.insert(attributs, `{nom}={formater(valeur)}`)
	end
	table.sort(attributs)
	if #attributs > 0 then
		table.insert(champs, "attributs=" .. table.concat(attributs, ";"))
	end
	return table.concat(champs, " | ")
end

-- Les fichiers à lire : ceux donnés, ou les .rbxm des dossiers donnés (monde par défaut), triés par nom.
local fichiers = {}
for _, chemin in (if #process.args > 1 then { table.unpack(process.args, 2) } else { "monde" }) do
	if fs.isDir(chemin) then
		for _, nom in fs.readDir(chemin) do
			if nom:match("%.rbxm$") then
				table.insert(fichiers, chemin .. "/" .. nom)
			end
		end
	else
		table.insert(fichiers, chemin)
	end
end
table.sort(fichiers, function(a, b)
	return (a:match("[^/\\]+$") :: string) < (b:match("[^/\\]+$") :: string)
end)
assert(#fichiers > 0, "aucun fichier .rbxm à lire")

local lignes = {}
for _, chemin in fichiers do
	local nom = chemin:match("[^/\\]+$") :: string
	local avant = #lignes
	for _, racine in roblox.deserializeModel(fs.readFile(chemin)) do
		table.insert(lignes, ligne(nom, racine))
		for _, d in racine:GetDescendants() do
			table.insert(lignes, ligne(nom, d))
		end
	end
	print(`{chemin} : {#lignes - avant} instances`)
end
table.sort(lignes)
fs.writeFile(sortie, table.concat(lignes, "\n") .. "\n")
print(`{sortie} : {#lignes} lignes`)
