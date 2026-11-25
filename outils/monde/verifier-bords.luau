-- Usage : lune run outils/monde/verifier-bords.luau [carte.rbxm …] (défaut : toutes les cartes du registre
-- outils/monde/monde.json ; après lune run outils/monde/generer.luau). `inventaire` en argument affiche aussi ce qui est toléré.
--
-- « Il faut qu'on puisse être sur tout l'obstacle, pas traverser les bords » : ce qui paraît être l'obstacle porte le
-- joueur. Trois contrôles :
-- 1. Bords : une pièce visible non solide qui touche une surface marchable ne dépasse aucun solide de plus de
--    TOLERANCE studs, ni par le dessus ni par les flancs (à PORTEE studs de la surface au plus). Une pièce traversable
--    à dessein est nommée dans EXCEPTIONS, avec sa raison ; une exception qui ne sert plus est un défaut. De même,
--    un objet visible posé sur la surface (plus de SAILLIE studs de haut) ne se traverse pas.
-- 2. Bords invisibles : aucune pièce solide transparente, aucun solide dont la collision n'épouse pas la forme
--    visible (maillage, SpecialMesh).
-- 3. Habillage solide de l'ascension (ce qui porte une dalle du chemin) : il tient dans l'aplomb de sa dalle, ses
--    faces sont droites et aucun de ses dessus n'offre HAUTEUR_DEBOUT studs libres. On ne peut donc s'y poser nulle
--    part : il ne raccourcit aucun saut et ne contourne aucune porte de capacité (verifier-ascension ne le compte
--    pas comme plateforme).
-- Code de sortie 1 au moindre défaut.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3 = roblox.Vector3

local TOLERANCE = 0.3 -- studs : au-delà, le joueur voit un bord et passe au travers
local CONTACT = 0.5 -- une pièce non solide à cette distance d'une surface marchable paraît en faire partie
local PORTEE = 6 -- on ne juge que ce qui est à cette distance horizontale de la surface
local DESSOUS, DESSUS = 12, 8 -- et entre ces hauteurs sous et sur elle
local PAS = 0.5 -- maille de l'échantillonnage
local HAUTEUR_DEBOUT = 4.5 -- le personnage en fait environ 5 : sous ce plafond, il ne tient pas debout
local INVISIBLE = 0.95
local SAILLIE = 0.5 -- un objet plus haut que ça, posé sur une surface, se heurte : il doit être solide

-- Motif du chemin (dossiers et nom de la pièce) -> raison. Les exceptions valent pour toutes les cartes.
local EXCEPTIONS: { { motif: string, raison: string } } = {
	{ motif = "^Evenements%.Evenements%.", raison = "danger ou préavis d'un événement : son contact tue" },
	{
		motif = "%.Tunnel$",
		raison = "bouche d'ombre d'où sort la rame ; son toit, solide, contournerait les escalators",
	},
	{
		motif = "%.7_Parlement%.Comble$",
		raison = "pente à 70° : solide, on la monterait pour longer l'ardoise mortelle",
	},
	{ motif = "%.Etage%d+$", raison = "plaque d'étage à toucher, translucide, dans l'emprise de la dalle" },
	{ motif = "%.FaisceauEtage$", raison = "faisceau de lumière au-dessus de la plaque d'étage" },
	{ motif = "%.RailMobile$", raison = "trait de lumière ; solide, il rattraperait qui rate la nacelle" },
}

local inventaire = false
local cartes = {}
for _, a in process.args do
	if a == "inventaire" then
		inventaire = true
	else
		table.insert(cartes, a)
	end
end
local parDefaut = #cartes == 0
if parDefaut then
	for _, entree in serde.decode("json", fs.readFile("outils/monde/monde.json")) :: any do
		table.insert(cartes, entree.sortie)
	end
	table.sort(cartes)
end

local defauts = 0
local function defaut(message: string)
	defauts += 1
	print("  DÉFAUT : " .. message)
end

-- Une pièce, réduite à des nombres : centre, axes, demi-dimensions, forme, boîte alignée.
local function lire(d)
	local cf, s = d.CFrame, d.Size
	local forme = "Bloc"
	if d:IsA("WedgePart") then
		forme = "Coin"
	elseif d:IsA("Part") and d.Shape.Name ~= "Block" then
		forme = d.Shape.Name
	end
	local r, u, l = cf.RightVector, cf.UpVector, -cf.LookVector
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	if forme == "Ball" then
		hx = math.min(hx, hy, hz)
		hy, hz = hx, hx
	elseif forme == "Cylinder" then
		hy = math.min(hy, hz)
		hz = hy
	end
	local e = Vector3.new(
		math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(l.X) * hz,
		math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(l.Y) * hz,
		math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(l.Z) * hz
	)
	return {
		part = d,
		nom = d:GetFullName(),
		c = cf.Position,
		r = r,
		u = u,
		l = l,
		hx = hx,
		hy = hy,
		hz = hz,
		forme = forme,
		mn = cf.Position - e,
		mx = cf.Position + e,
	}
end

-- Distance d'un point (x, y, z) au volume de la pièce (0 dedans).
local function distance(p, x: number, y: number, z: number): number
	local dx, dy, dz = x - p.c.X, y - p.c.Y, z - p.c.Z
	local a = dx * p.r.X + dy * p.r.Y + dz * p.r.Z
	local b = dx * p.u.X + dy * p.u.Y + dz * p.u.Z
	local c = dx * p.l.X + dy * p.l.Y + dz * p.l.Z
	if p.forme == "Ball" then
		return math.max(0, math.sqrt(a * a + b * b + c * c) - p.hx)
	elseif p.forme == "Cylinder" then
		local ex, er = math.max(0, math.abs(a) - p.hx), math.max(0, math.sqrt(b * b + c * c) - p.hy)
		return math.sqrt(ex * ex + er * er)
	end
	local ex, ey, ez = math.max(0, math.abs(a) - p.hx), math.max(0, math.abs(b) - p.hy), math.max(0, math.abs(c) - p.hz)
	local ext = math.sqrt(ex * ex + ey * ey + ez * ez)
	if p.forme == "Coin" then
		-- Coin : la pente va du bas de la face -Z au haut de la face +Z ; au-dessus du plan, on est dehors.
		local n = math.sqrt(p.hy * p.hy + p.hz * p.hz)
		ext = math.max(ext, (b * p.hz - c * p.hy) / n)
	end
	return ext
end

-- Points de la surface de la pièce (mailles de PAS environ), limités à la boîte [mn, mx] donnée.
local function echantillonner(p, mn, mx, voir: (number, number, number) -> ())
	local function suite(h: number): { number }
		local n = math.clamp(math.ceil(2 * h / PAS), 1, 400)
		local t = {}
		for i = 0, n do
			table.insert(t, -h + 2 * h * i / n)
		end
		return t
	end
	local function point(a: number, b: number, c: number)
		local x = p.c.X + a * p.r.X + b * p.u.X + c * p.l.X
		local y = p.c.Y + a * p.r.Y + b * p.u.Y + c * p.l.Y
		local z = p.c.Z + a * p.r.Z + b * p.u.Z + c * p.l.Z
		if x >= mn.X and x <= mx.X and y >= mn.Y and y <= mx.Y and z >= mn.Z and z <= mx.Z then
			voir(x, y, z)
		end
	end
	if p.forme == "Ball" then
		for i = 0, 12 do
			for j = 0, 23 do
				local th, ph = math.pi * i / 12, 2 * math.pi * j / 24
				point(p.hx * math.sin(th) * math.cos(ph), p.hx * math.cos(th), p.hx * math.sin(th) * math.sin(ph))
			end
		end
		return
	elseif p.forme == "Cylinder" then
		for _, a in suite(p.hx) do
			for j = 0, 35 do
				local ph = 2 * math.pi * j / 36
				point(a, p.hy * math.cos(ph), p.hy * math.sin(ph))
			end
		end
		for _, b in suite(p.hy) do
			for _, c in suite(p.hy) do
				if b * b + c * c <= p.hy * p.hy then
					point(-p.hx, b, c)
					point(p.hx, b, c)
				end
			end
		end
		return
	end
	local sa, sb, sc = suite(p.hx), suite(p.hy), suite(p.hz)
	local function dans(b: number, c: number): boolean
		return p.forme ~= "Coin" or b * p.hz <= c * p.hy + 1e-6
	end
	for _, a in sa do
		for _, c in sc do
			if p.forme == "Coin" then
				point(a, c * p.hy / p.hz, c)
			else
				point(a, p.hy, c)
			end
			point(a, -p.hy, c)
		end
		for _, b in sb do
			point(a, b, p.hz)
			if p.forme ~= "Coin" then
				point(a, b, -p.hz)
			end
		end
	end
	for _, b in sb do
		for _, c in sc do
			if dans(b, c) then
				point(-p.hx, b, c)
				point(p.hx, b, c)
			end
		end
	end
end

-- Toutes les pièces, toutes cartes confondues (le décor d'une carte peut prolonger une surface d'une autre).
local solides, marchables, traversables = {}, {}, {}
for _, fichier in cartes do
	local modele = roblox.deserializeModel(fs.readFile(fichier))[1]
	for _, d in modele:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local p = lire(d)
		if not d.CanCollide then
			if d.Transparency < INVISIBLE and not d:HasTag("Mortel") then
				table.insert(traversables, p)
			end
			continue
		end
		table.insert(solides, p)
		if d.Transparency >= INVISIBLE then
			defaut(`{p.nom} : solide et invisible, le joueur bute sur rien`)
		end
		if
			not (d:IsA("Part") or d:IsA("WedgePart") or d:IsA("SpawnLocation"))
			or d:FindFirstChildOfClass("SpecialMesh")
		then
			defaut(`{p.nom} : {d.ClassName} solide, sa collision peut s'écarter de sa forme visible`)
		end
		if
			d.CanQuery and not (d:HasTag("Mortel") or d:HasTag("Tournant") or d:HasTag("Balancier"))
			or d:HasTag("Checkpoint")
		then
			table.insert(marchables, p)
		end
	end
end
local function touche(p, mn, mx): boolean
	return p.mn.X <= mx.X and p.mx.X >= mn.X and p.mn.Y <= mx.Y and p.mx.Y >= mn.Y and p.mn.Z <= mx.Z and p.mx.Z >= mn.Z
end

-- 1. Bords. Pour chaque pièce traversable, la surface marchable qu'elle touche et son plus grand dépassement.
local servies: { [number]: number } = {}
local function exception(nom: string): number?
	for i, e in EXCEPTIONS do
		if nom:match(e.motif) then
			return i
		end
	end
	return nil
end

local unite = Vector3.new(1, 1, 1)
local debordent = 0
for _, t in traversables do
	local pire, surface, ou_ = 0, nil, nil -- plus grand dépassement hors de la surface
	local saillie, dessous = SAILLIE, nil -- plus haute saillie au-dessus d'elle
	for _, s in marchables do
		local mn, mx = s.mn - unite * CONTACT, s.mx + unite * CONTACT
		if not touche(t, mn, mx) then
			continue
		end
		local contact = distance(t, s.c.X, s.c.Y, s.c.Z) == 0
		echantillonner(t, mn, mx, function(x, y, z)
			contact = contact or distance(s, x, y, z) <= CONTACT
		end)
		if not contact then
			continue
		end
		local zmn = Vector3.new(s.mn.X - PORTEE, s.mn.Y - DESSOUS, s.mn.Z - PORTEE)
		local zmx = Vector3.new(s.mx.X + PORTEE, s.mx.Y + DESSUS, s.mx.Z + PORTEE)
		local voisins = {}
		local tmn, tmx = t.mn - unite * 3, t.mx + unite * 3
		for _, v in solides do
			if touche(v, tmn, tmx) and touche(v, zmn - unite * 3, zmx + unite * 3) then
				table.insert(voisins, v)
			end
		end
		echantillonner(t, zmn, zmx, function(x, y, z)
			local hx = math.max(0, s.mn.X - x, x - s.mx.X)
			local hz = math.max(0, s.mn.Z - z, z - s.mx.Z)
			local d = math.sqrt(hx * hx + hz * hz)
			local h = y - s.mx.Y
			if (d <= TOLERANCE and h <= saillie) or (d > TOLERANCE and d <= pire) then
				return
			end
			for _, v in voisins do
				if distance(v, x, y, z) <= TOLERANCE then
					return
				end
			end
			if d <= TOLERANCE then
				saillie, dessous = h, s
			else
				pire, surface, ou_ = d, s, h
			end
		end)
	end
	if surface or dessous then
		local i = exception(t.nom)
		if i then
			servies[i] = (servies[i] or 0) + 1
		else
			debordent += 1
		end
		if inventaire or not i then
			local texte = if surface
				then string.format(
					"%s prolonge %s de %.2f studs (à %+.1f de son dessus) sans être solide",
					t.nom,
					surface.nom,
					pire,
					ou_
				)
				else string.format(
					"%s, posée sur %s, se traverse (%.1f studs de haut)",
					t.nom,
					dessous.nom,
					saillie
				)
			if i then
				print(`  toléré : {texte} ({EXCEPTIONS[i].raison})`)
			else
				defaut(texte)
			end
		end
	end
end
if parDefaut then
	for i, e in EXCEPTIONS do
		if not servies[i] then
			defaut(`exception « {e.motif} » inutile : plus aucune pièce ne s'en sert`)
		end
	end
end

-- 3. Habillage solide de l'ascension : les pièces solides sans requête posées dans les dossiers du chemin.
local habillages = 0
for _, p in solides do
	if p.part.CanQuery or not (p.nom:match("^Ascension%.Chemin%.") or p.nom:match("^Ascension%.Acces%.")) then
		continue
	end
	habillages += 1
	local dalle = nil
	for _, s in marchables do
		if
			p.mn.X >= s.mn.X - 0.01
			and p.mx.X <= s.mx.X + 0.01
			and p.mn.Z >= s.mn.Z - 0.01
			and p.mx.Z <= s.mx.Z + 0.01
			and p.mx.Y < s.mx.Y
			and (dalle == nil or s.mn.Y < dalle.mn.Y)
		then
			dalle = s -- la dalle la plus basse qui couvre la pièce
		end
	end
	if not dalle then
		defaut(`{p.nom} : habillage solide hors de l'aplomb de sa dalle, on peut s'y poser`)
		continue
	end
	-- Cylindres et boules n'ont pas de face droite : seul leur dessus compte (contrôle suivant).
	if p.forme == "Bloc" then
		for _, axe in { p.r, p.u, p.l } do
			if math.abs(axe.Y) > 0.001 and math.abs(axe.Y) < 0.999 then
				defaut(`{p.nom} : habillage solide penché, sa pente se grimpe`)
				break
			end
		end
	end
	local voisins = {}
	for _, v in solides do
		if v ~= p and touche(v, p.mn, p.mx + Vector3.new(0, HAUTEUR_DEBOUT, 0)) then
			table.insert(voisins, v)
		end
	end
	local libre = false
	echantillonner(p, p.mn - unite, p.mx + unite, function(x, y, z)
		if libre or y < p.mx.Y - 0.01 and p.forme == "Bloc" or y < p.c.Y then
			return
		end
		for h = 0.05, HAUTEUR_DEBOUT, 0.25 do
			for _, v in voisins do
				if distance(v, x, y + h, z) <= 0.06 then
					return
				end
			end
		end
		libre = true
	end)
	if libre then
		defaut(`{p.nom} : on tient debout sur cet habillage (plus de {HAUTEUR_DEBOUT} studs libres sous {dalle.nom})`)
	end
end
print(`{habillages} pièces d'habillage solide de l'ascension`)

print(
	`{#marchables} surfaces marchables, {#traversables} pièces traversables : {debordent} bord(s) qui ne portent pas`
)
if defauts > 0 then
	print(`défauts : {defauts}`)
	process.exit(1)
end
