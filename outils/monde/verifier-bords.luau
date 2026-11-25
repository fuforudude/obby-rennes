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

local TOLERANCE = 0.305 -- studs : au-delà, le joueur voit un bord et passe au travers
local CONTACT = 1 -- une pièce non solide à cette distance d'une surface marchable paraît en faire partie
local PORTEE = 6 -- on ne juge que ce qui est à cette distance horizontale de la surface
local DESSOUS_SECONDAIRE = 0.5 -- sous le dessus d'un solide hors du chemin (toit, mur)
local DESSOUS, DESSUS = 12, 8 -- et entre ces hauteurs sous et sur elle
local PAS = 0.5 -- maille de l'échantillonnage
local HAUTEUR_DEBOUT = 4.5 -- le personnage en fait environ 5 : sous ce plafond, il ne tient pas debout
local INVISIBLE = 0.95
local SAILLIE = 0.5 -- un objet plus haut que ça, posé sur une surface, se heurte : il doit être solide

-- Motif du chemin complet (carte, dossiers, nom de la pièce), ancré au début -> raison.
local EXCEPTIONS: { { motif: string, raison: string } } = {
	{ motif = "^Evenements%.Evenements%.", raison = "danger ou préavis d'un événement : son contact tue" },
	{
		motif = "^Evenements%.Decor%.Tunnel$",
		raison = "bouche d'ombre d'où sort la rame ; son toit, solide, contournerait les escalators",
	},
	{
		motif = "^Parcours%.7_Parlement%.Comble$",
		raison = "pente à 70° : solide, on la monterait pour longer l'ardoise mortelle",
	},
	{
		motif = "^Parcours%.4_LaTour%.NezDeDalle$",
		raison = "relief de 0,4 de la façade : solide, il ferait une échelle de rebords le long de la spirale",
	},
	{ motif = "^Parcours%.4_LaTour%.Refend$", raison = "relief de 0,4 de la façade de la tour" },
	{ motif = "^Parcours%.4_LaTour%.Acrotere$", raison = "couronnement du toit de la tour, hors du chemin" },
	{ motif = "^Parcours%.4_LaTour%.NomResidence$", raison = "enseigne du toit de la tour, hors du chemin" },
	{ motif = "^Parcours%.4_LaTour%.Edicule$", raison = "édicule du toit de la tour, hors du chemin" },
	{ motif = "^Parcours%.References%.CadreAffiche$", raison = "cadre d'une affiche (texte) au bord de la rue" },
	{ motif = "^Evenements%.PanneauxAnecdotes%.", raison = "panneau de texte à côté d'un checkpoint" },
	{
		motif = "^Ascension%.Obstacles%.ChandelleBalancier$",
		raison = "solide, elle barrerait Pas2_6 -> Pas2_7 (48 % d'arcs libres au lieu de 66) et ferait un perchoir à 12 studs",
	},
	{ motif = "^Parcours%.0_Coloc%.Mat$", raison = "mât de drapeau sur un toit hors du chemin : solide, un perchoir" },
	{
		motif = "^Parcours%.4_LaTour%.Mat$",
		raison = "mât de drapeau sur un toit hors du chemin : solide, un perchoir",
	},
	{
		motif = "^Parcours%.9_SupDeVinci%.Mat$",
		raison = "mât de drapeau sur un toit hors du chemin : solide, un perchoir",
	},
	{
		motif = "^Ascension%.Pied%.Portique$",
		raison = "fronton de texte : solide, un perchoir 17 studs au-dessus du pied",
	},
	{
		motif = "^Ascension%.Etages%.Etage%d+$",
		raison = "plaque d'étage à toucher, translucide, dans l'emprise de la dalle",
	},
	{ motif = "^Ascension%.Etages%.FaisceauEtage$", raison = "faisceau de lumière au-dessus de la plaque d'étage" },
	{
		motif = "^Ascension%.Obstacles%.RailMobile$",
		raison = "trait de lumière ; solide, il rattraperait qui rate la nacelle",
	},
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
if #cartes == 0 then
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

local Formes = require("./formes")
local Physique = require("./physique")
local lire, distance = Formes.lire, Formes.distance

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
-- `fixes` : les solides qui ne bougent ni ne s'effacent, seuls capables de soutenir une pièce traversable.
local solides, fixes, marchables, traversables, autres = {}, {}, {}, {}, {}
local presentes: { [string]: boolean } = {}
local fond = -math.huge -- dessus de la zone mortelle de la ville : dessous, personne ne marche
for _, fichier in cartes do
	for _, modele in roblox.deserializeModel(fs.readFile(fichier)) do
		presentes[modele.Name] = true
		for _, d in modele:GetDescendants() do
			if not d:IsA("BasePart") then
				continue
			end
			local p = lire(d)
			local mortel = d:HasTag("Mortel")
			if mortel and d.Transparency >= INVISIBLE then
				fond = math.max(fond, p.mx.Y)
			end
			if not d.CanCollide then
				if d.Transparency < INVISIBLE and not mortel then
					table.insert(traversables, p)
				end
				continue
			end
			table.insert(solides, p)
			local pousse = d:HasTag("Tournant") or d:HasTag("Balancier")
			if not (pousse or d:HasTag("Mobile") or d:HasTag("Fragile") or d:HasTag("Effondrable")) then
				table.insert(fixes, p)
			end
			if d.Transparency >= INVISIBLE then
				defaut(`{p.nom} : solide et invisible, le joueur bute sur rien`)
			end
			if
				not (d:IsA("Part") or d:IsA("WedgePart") or d:IsA("SpawnLocation"))
				or d:FindFirstChildOfClass("SpecialMesh")
			then
				defaut(`{p.nom} : {d.ClassName} solide, sa collision peut s'écarter de sa forme visible`)
			end
			if d:HasTag("Checkpoint") or (d.CanQuery and not mortel and not pousse) then
				table.insert(marchables, p)
			elseif not mortel and not pousse then
				table.insert(autres, p)
			end
		end
	end
end
local complet = true
for nom in serde.decode("json", fs.readFile("outils/monde/monde.json")) :: any do
	complet = complet and presentes[nom] == true
end

-- L'habillage d'une dalle de l'ascension : le contrôle 3 prouve qu'on ne s'y tient pas.
local function estHabillage(p): boolean
	return not p.part.CanQuery
		and (p.nom:match("^Ascension%.Chemin%.") ~= nil or p.nom:match("^Ascension%.Acces%.") ~= nil)
end
local function touche(p, mn, mx): boolean
	return p.mn.X <= mx.X and p.mx.X >= mn.X and p.mn.Y <= mx.Y and p.mx.Y >= mn.Y and p.mn.Z <= mx.Z and p.mx.Z >= mn.Z
end

local unite = Vector3.new(1, 1, 1)
-- Y a-t-il HAUTEUR_DEBOUT studs libres au-dessus d'un point du dessus de la pièce ?
local function tientDebout(p): boolean
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
	return libre
end

-- Un solide sans requête (toit, mur, panneau) se marche aussi : tout ce qui est à portée de saut d'une plateforme,
-- les trois capacités en main, en physique réelle, et où il y a la place de tenir debout.
for _, p in autres do
	if p.mx.Y <= fond or estHabillage(p) or not tientDebout(p) then
		continue
	end
	for k = 1, #marchables do
		local s = marchables[k]
		local gx = math.max(0, s.mn.X - p.mx.X, p.mn.X - s.mx.X)
		local gz = math.max(0, s.mn.Z - p.mx.Z, p.mn.Z - s.mx.Z)
		if Physique.franchissable(math.sqrt(gx * gx + gz * gz), p.mx.Y - s.mx.Y, Physique.TOUTES) then
			p.secondaire = true
			table.insert(marchables, p)
			break
		end
	end
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

local debordent = 0
for _, t in traversables do
	local pire, surface, ou_ = 0, nil, nil -- plus grand dépassement hors de la surface
	local saillie, dessous = SAILLIE, nil -- plus haute saillie au-dessus d'elle
	for _, s in marchables do
		-- Hors du chemin, seul le dessus se marche : les reliefs d'une façade plus bas ne le prolongent pas.
		local bas = if s.secondaire then s.mx.Y - DESSOUS_SECONDAIRE else s.mn.Y - CONTACT
		local mn, mx = Vector3.new(s.mn.X - CONTACT, bas, s.mn.Z - CONTACT), s.mx + unite * CONTACT
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
		local zmn = Vector3.new(s.mn.X - PORTEE, if s.secondaire then bas else s.mn.Y - DESSOUS, s.mn.Z - PORTEE)
		local zmx = Vector3.new(s.mx.X + PORTEE, s.mx.Y + DESSUS, s.mx.Z + PORTEE)
		local voisins = {}
		local tmn, tmx = t.mn - unite * 3, t.mx + unite * 3
		for _, v in fixes do
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
if complet then
	for i, e in EXCEPTIONS do
		if not servies[i] then
			defaut(`exception « {e.motif} » inutile : plus aucune pièce ne s'en sert`)
		end
	end
end

-- 3. Habillage solide de l'ascension : les pièces solides sans requête posées dans les dossiers du chemin.
local habillages = 0
for _, p in solides do
	if not estHabillage(p) then
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
	if tientDebout(p) then
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
