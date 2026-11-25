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
--   mur          un mur solide sans requête entre le pied et Pas1_1 -> « saut … barré »
--   mur-acces    un mur solide sans requête devant PanneauDuToit -> « saut ArmoireDeLaVerriere -> PanneauDuToit barré »
--   frole-mortel une murette mortelle au milieu du saut Pas1_5 -> Pas1_6 (inoffensive, on passerait par-dessus ;
--                4e argument « inoffensif » pour le voir) -> « saut Pas1_5 -> Pas1_6 barré »
--   passager     une poutre solide sans requête au-dessus de la course d'une nacelle -> « elle ou son passager »
--   laser-habillage  un habillage solide dans le balayage d'un laser -> « traverse »
--   bouts        bouts des barres tournantes portés à 3 studs -> « dépasse de la barre »
--   tag-sans-simulateur  tag « Fragile » (un piège du tuto, connu du jeu) posé sur une dalle du chemin
--                -> « tag « Fragile » sans simulateur » (aucune famille du registre FAMILLES ne le contrôle)
--   famille-inconnue     le générateur outils/monde/Ascension.luau, avec une famille « Ascenseur » glissée dans
--                la première tranche de `segments` : c'est **la génération** qui doit échouer (« famille d'obstacle
--                inconnue « Ascenseur » ») ; cette fabrique sort alors en erreur et n'écrit rien.
--
-- Le fichier écrit est jetable : on le passe en premier argument au contrôle, par exemple
--   lune run outils/monde/casser-ascension.luau lasers
--   lune run outils/monde/verifier-ascension.luau /tmp/ascension-cassee.rbxm
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local panne = process.args[1]
local sortie = process.args[2] or "ascension-cassee.rbxm"
local source = process.args[3] or "monde/Ascension.rbxm"
assert(
	panne,
	"panne attendue : marches, lasers, pieges, repos, poussee, balanciers, mobiles, effondrables, tournants, bouts, mur, mur-acces, frole-mortel, passager, laser-habillage, "
		.. "tag-sans-simulateur ou famille-inconnue"
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

-- Un solide sans requête (le verifier ne le compte pas comme plateforme), dans le dossier des obstacles.
local function solide(nom: string, taille, cf)
	local p = roblox.Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanQuery = false
	p.Size = taille
	p.CFrame = cf
	p.Parent = modele:FindFirstChild("Obstacles")
	return p
end

function pannes.mur(): string
	local pied = tagues("PiedAscension")[1]
	local pas = modele:FindFirstChild("Chemin"):FindFirstChild("Pas1_1")
	local milieu = (pied.CFrame.Position + pas.CFrame.Position) / 2
	local vers = pas.CFrame.Position - pied.CFrame.Position
	-- En travers du saut, au ras de Pas1_1, trop haut pour les deux sauts enchaînés.
	local dir = Vector3.new(vers.X, 0, vers.Z).Unit
	local centre = pas.CFrame.Position - dir * (pas.Size.Magnitude / 2 + 1)
	solide(
		"MurDeTriche",
		Vector3.new(1, 60, 60),
		CFrame.new(centre.X, milieu.Y, centre.Z) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
	)
	return "un mur entre le pied et Pas1_1"
end

pannes["mur-acces"] = function(): string
	local p = modele:FindFirstChild("Acces"):FindFirstChild("PanneauDuToit").CFrame.Position
	solide("MurDeTriche", Vector3.new(60, 60, 1), CFrame.new(p.X, p.Y, p.Z - 4))
	return "un mur devant PanneauDuToit"
end

pannes["frole-mortel"] = function(): string
	local chemin = modele:FindFirstChild("Chemin")
	local a, b = chemin:FindFirstChild("Pas1_5").CFrame.Position, chemin:FindFirstChild("Pas1_6").CFrame.Position
	local vers = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local milieu = (a + b) / 2
	local haut = math.max(a.Y, b.Y) + 4
	local p = solide(
		"MuretteDeTriche",
		Vector3.new(1, 12, 30),
		CFrame.new(milieu.X, haut - 6, milieu.Z) * CFrame.Angles(0, math.atan2(-vers.Z, vers.X), 0)
	)
	if process.args[4] ~= "inoffensif" then
		p:AddTag("Mortel")
	end
	return "une murette mortelle entre Pas1_5 et Pas1_6"
end

function pannes.passager(): string
	local m = tagues("Mobile")[1]
	local milieu = m.CFrame.Position + m:GetAttribute("Deplacement") / 2
	solide("PoutreDeTriche", Vector3.new(1, 1, 1), CFrame.new(milieu + Vector3.new(0, 4, 0)))
	return `une poutre 4 studs au-dessus de la course de {m.Name}`
end

pannes["laser-habillage"] = function(): string
	local l = tagues("Laser")[1]
	for _, d in modele:FindFirstChild("Chemin"):GetChildren() do
		if d:IsA("BasePart") and d.CanCollide and not d.CanQuery then
			d.CFrame = CFrame.new((l:GetAttribute("Depart") + l:GetAttribute("Arrivee")) / 2)
			return `{d.Name} posé dans le balayage de {l.Name}`
		end
	end
	error("aucun habillage solide dans le chemin")
end

function pannes.bouts(): string
	local n = 0
	for _, b in tagues("Tournant") do
		for _, e in b:GetChildren() do
			if e:IsA("BasePart") then
				e.Size = Vector3.new(3, 3, 3)
				n += 1
			end
		end
	end
	assert(n > 0, `aucun bout de barre tournante dans {source}`)
	return `{n} bouts de barre portés à 3 studs`
end

-- Un piège connu du jeu (TAGS_CONNUS de verifier-contrats) mais que verifier-ascension ne sait pas simuler : sa
-- fenêtre de passage ne serait contrôlée par personne.
pannes["tag-sans-simulateur"] = function(): string
	for _, d in modele:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^Pas%d+_%d+$") then
			d:AddTag("Fragile")
			return `tag « Fragile » posé sur {d.Name}`
		end
	end
	error(`aucune dalle « Pas<tranche>_<rang> » dans {source}`)
end

-- Une famille que le registre `poseurs` ne connaît pas : avant le registre, la chaîne de `if` ne posait rien, en
-- silence. La génération doit maintenant échouer ; si elle passe, on écrit sa carte et tout-verifier le signale.
pannes["famille-inconnue"] = function(): string
	local generateur = "outils/monde/Ascension.luau"
	local code = fs.readFile(generateur)
	local motif = "obstacles = {"
	local debut, fin = string.find(code, motif, 1, true)
	assert(debut and fin, `« {motif} » introuvable dans {generateur} : la panne ne sait plus où glisser la famille`)
	code = string.sub(code, 1, fin) .. ' "Ascenseur",' .. string.sub(code, fin + 1)
	local construire = luau.load(code, { debugName = `{generateur} (famille-inconnue)` })()
	modele = construire(roblox, require("./biblio")(roblox))
	return "le générateur a accepté la famille « Ascenseur »"
end

local faire = pannes[panne]
assert(faire, `panne « {panne} » inconnue`)
local resume = faire()
fs.writeFile(sortie, roblox.serializeModel({ modele }))
print(`{source} -> {sortie} : {resume}`)
