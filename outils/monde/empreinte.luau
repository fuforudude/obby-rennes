-- Empreinte des cartes : une ligne par instance, triée, stable et diffable, pour prouver qu'une refonte d'un
-- générateur ne change pas la carte (spec 2026-11-20-refonte-modulaire).
--   lune run outils/monde/empreinte.luau <sortie.txt> [fichier.rbxm | dossier ...]   (défaut : le dossier monde)
-- Lecture seule : n'écrit que <sortie.txt>. Comparer deux empreintes : git diff --no-index avant.txt apres.txt.
--
-- Chaque ligne : fichier, chemin complet, classe, puis pour une BasePart la position, la rotation (degrés), la taille,
-- la couleur, le matériau, la transparence et les drapeaux de collision (et la forme d'une Part), pour un Model sa
-- PrimaryPart, pour un Attachment son CFrame, pour une SurfaceGui sa face, son mode et sa densité, pour un objet
-- d'interface sa position et sa taille, pour un texte son contenu, sa taille, sa police et sa couleur, pour une
-- lumière et un décalque leurs propriétés principales, enfin les tags triés et les attributs triés. Nombres arrondis
-- à 0,01. Tout ce qui se voit en jeu doit y être : tout-verifier.mjs accepte des octets différents quand
-- l'empreinte est identique. Le fichier n'est désigné que par son nom (sans dossier) :
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
	elseif t == "UDim2" then
		return `({nombre(v.X.Scale)}, {nombre(v.X.Offset)}, {nombre(v.Y.Scale)}, {nombre(v.Y.Offset)})`
	elseif t == "Font" then
		return `{v.Family} {v.Weight.Name} {v.Style.Name}`
	elseif t == "EnumItem" then
		return v.Name
	elseif t == "Instance" then
		return v:GetFullName()
	elseif t == "nil" or t == "boolean" then
		return tostring(v)
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
	-- Propriétés lues par nom, ajoutées sous la forme « nom=valeur » dans l'ordre donné.
	local function proprietes(noms: { string })
		for _, nom in noms do
			table.insert(champs, `{nom}={formater(inst[nom])}`)
		end
	end
	if inst:IsA("Part") then
		proprietes({ "Shape" })
	end
	if inst:IsA("Model") then
		proprietes({ "PrimaryPart" })
	end
	if inst:IsA("Attachment") then
		proprietes({ "CFrame" })
	end
	if inst:IsA("SurfaceGui") then
		proprietes({ "Face", "SizingMode", "PixelsPerStud", "LightInfluence", "AlwaysOnTop" })
	end
	if inst:IsA("BillboardGui") then
		proprietes({ "Size", "StudsOffset", "MaxDistance", "AlwaysOnTop" })
	end
	if inst:IsA("GuiObject") then
		proprietes({ "Position", "Size", "BackgroundColor3", "BackgroundTransparency", "Visible" })
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		table.insert(champs, "texte=" .. formater(inst.Text))
		proprietes({
			"TextSize",
			"FontFace",
			"TextColor3",
			"TextTransparency",
			"TextScaled",
			"TextWrapped",
			"TextXAlignment",
			"TextYAlignment",
		})
	end
	if inst:IsA("Light") then
		proprietes({ "Enabled", "Brightness", "Color", "Shadows" })
		if inst:IsA("PointLight") then
			proprietes({ "Range" })
		elseif inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
			proprietes({ "Range", "Angle", "Face" })
		end
	end
	if inst:IsA("Decal") then -- Texture en hérite
		proprietes({ "Texture", "Face", "Color3", "Transparency" })
		if inst:IsA("Texture") then
			proprietes({ "StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV" })
		end
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
