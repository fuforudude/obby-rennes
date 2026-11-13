-- Usage : lune run outils/monde/verifier-evenements.luau [Evenements.rbxm] [Parcours.rbxm]
-- (défauts monde/Evenements.rbxm et monde/Parcours.rbxm ; après lune run outils/monde/generer.luau).
--
-- Contrôle les événements, les balanciers et les panneaux d'anecdotes posés par outils/monde/Evenements.luau :
-- - Evenement : attributs du contrat cohérents (préavis >= 1 s, préavis + durée <= période, enfant Preavis) ; pour
--   chaque plateforme du parcours que l'objet peut toucher, on simule les horaires sur deux minutes et on exige, dans
--   toute tranche d'une période (la plus longue des objets qui la touchent) plus 2 s, une fenêtre sûre d'au moins 2 s.
--   « Peut toucher » : la boîte balayée par l'objet (hors Preavis), élargie des marges de contact du client (0,8 stud
--   à l'horizontale, 2 à la verticale), rencontre le volume où se trouve le centre d'un personnage debout sur la
--   dalle. Prudent : toute la fenêtre active compte comme dangereuse pour la plateforme, même si l'objet n'y passe
--   qu'une partie du temps.
-- - Balancier : sur une période, la fenêtre de passage (la pièce hors de sa zone ZoneControleMin/Max) dure au moins
--   1,5 s d'affilée ; sur toute son amplitude, la pièce ne touche aucune pièce solide de la carte.
-- - Volume de réapparition de chaque checkpoint (pièce taguée Checkpoint de Parcours.rbxm : cylindre de rayon 2
--   centré sur la dalle, de son dessus à dessus + 5) : aucun événement (boîte balayée élargie des marges de contact)
--   ni aucun balancier (sur toute son amplitude) ne doit y entrer. C'est un défaut : le personnage réapparaît
--   là, un danger qui y passe le pousserait ou le tuerait à la réapparition.
-- - PanneauAnecdote : Numero 0 à 15, une fois chacun, un TextLabel « Titre » et un TextLabel « Corps », près de son checkpoint, sans toucher de
--   pièce solide de la carte.
-- Horaires : ceux de src/partage/Horaires.luau (chargé s'il existe, sinon même formule recopiée ci-dessous) ;
-- marges de contact : celles de src/partage/Reglages.luau (EVENEMENT_MARGE_HORIZONTALE / _VERTICALE).
-- Code de sortie 1 au moindre défaut.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

---------------------------------------------------------------------------------------------------------------
-- Horaires (src/partage/Horaires.luau) : phase = (t - Decalage) % Periode ; actif dans [0, duree), préavis les
-- `Preavis` dernières secondes de la période.
local Horaires
if fs.isFile("src/partage/Horaires.luau") then
	Horaires = luau.load(fs.readFile("src/partage/Horaires.luau"), { debugName = "Horaires" })()
	print("horaires : src/partage/Horaires.luau")
else
	Horaires = {
		valide = function(periode, preavis, duree)
			return periode > 0 and duree > 0 and preavis >= 0 and preavis + duree <= periode
		end,
		etat = function(t, periode, decalage, preavis, duree)
			local phase = (t - decalage) % periode
			if phase < duree then
				return "actif", phase / duree
			end
			if preavis > 0 and phase >= periode - preavis then
				return "preavis", (phase - (periode - preavis)) / preavis
			end
			return "attente", 0
		end,
		angleBalancier = function(t, amplitude, periode, decalage)
			return amplitude * math.sin(2 * math.pi * (t - decalage) / periode)
		end,
	}
	print("horaires : formule recopiée (src/partage/Horaires.luau absent de cette branche)")
end

-- Marges de contact du client : lues dans les réglages du jeu, jamais recopiées.
assert(
	fs.isFile("src/partage/Reglages.luau"),
	"src/partage/Reglages.luau introuvable (lancer depuis la racine du dépôt)"
)
local Reglages = luau.load(fs.readFile("src/partage/Reglages.luau"), { debugName = "Reglages" })()
assert(
	type(Reglages.EVENEMENT_MARGE_HORIZONTALE) == "number" and type(Reglages.EVENEMENT_MARGE_VERTICALE) == "number",
	"Reglages.EVENEMENT_MARGE_HORIZONTALE / EVENEMENT_MARGE_VERTICALE absents"
)
print("marges de contact : src/partage/Reglages.luau")

local evenementsModele = roblox.deserializeModel(fs.readFile(process.args[1] or "monde/Evenements.rbxm"))[1]
local parcoursModele = roblox.deserializeModel(fs.readFile(process.args[2] or "monde/Parcours.rbxm"))[1]

local defauts, avertissements = 0, 0
local function defaut(message: string)
	defauts += 1
	print("  DÉFAUT : " .. message)
end
-- Recoupement avec du décor sans collision : rien ne bloque, mais ça se voit ; à regarder.
local function avertir(message: string)
	avertissements += 1
	print("  avertissement : " .. message)
end

---------------------------------------------------------------------------------------------------------------
-- Géométrie : boîtes alignées (AABB) et orientées (OBB, test des axes séparateurs).
type Boite = { min: any, max: any }

local function aabbDePiece(cf, taille): Boite
	local h = taille / 2
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				mn = mn:Min(p)
				mx = mx:Max(p)
			end
		end
	end
	return { min = mn, max = mx }
end

local function union(a: Boite?, b: Boite): Boite
	if not a then
		return b
	end
	return { min = a.min:Min(b.min), max = a.max:Max(b.max) }
end

local function decaler(b: Boite, d): Boite
	return { min = b.min + d, max = b.max + d }
end

local function elargir(b: Boite, d): Boite
	return { min = b.min - d, max = b.max + d }
end

local function aabbSeCroisent(a: Boite, b: Boite, tolerance: number?): boolean
	local e = tolerance or 0
	return a.min.X < b.max.X - e
		and b.min.X < a.max.X - e
		and a.min.Y < b.max.Y - e
		and b.min.Y < a.max.Y - e
		and a.min.Z < b.max.Z - e
		and b.min.Z < a.max.Z - e
end

local function obb(cf, taille)
	return {
		c = cf.Position,
		axes = { cf.XVector, cf.YVector, cf.ZVector },
		h = { taille.X / 2, taille.Y / 2, taille.Z / 2 },
	}
end

local function obbDeBoite(b: Boite)
	return obb(CFrame.new((b.min + b.max) / 2), b.max - b.min)
end

-- Vrai si les deux boîtes orientées s'interpénètrent de plus de `tolerance`.
local function obbSeCroisent(a, b, tolerance: number?): boolean
	local e = tolerance or 0.02
	local d = b.c - a.c
	local function separe(axe): boolean
		if axe.Magnitude < 1e-6 then
			return false
		end
		axe = axe.Unit
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += a.h[i] * math.abs(a.axes[i]:Dot(axe))
			rb += b.h[i] * math.abs(b.axes[i]:Dot(axe))
		end
		return math.abs(d:Dot(axe)) > ra + rb - e
	end
	for i = 1, 3 do
		if separe(a.axes[i]) or separe(b.axes[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separe(a.axes[i]:Cross(b.axes[j])) then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------------------
-- Les plateformes du parcours (mêmes critères que verifier-sauts.luau) et ses pièces solides.
type Plateforme = { nom: string, x1: number, x2: number, z1: number, z2: number, haut: number, cp: number? }
local plateformes: { Plateforme } = {}
local solides = {}
local fantomes = {} -- décor visible sans collision
local checkpoints = {}

for _, d in parcoursModele:GetDescendants() do
	if not d:IsA("BasePart") then
		continue
	end
	if d.CanCollide and d.Transparency < 1 then
		table.insert(
			solides,
			{ nom = d:GetFullName(), boite = aabbDePiece(d.CFrame, d.Size), obb = obb(d.CFrame, d.Size) }
		)
	elseif d.Transparency < 1 and d.Name ~= "Sol" then
		table.insert(
			fantomes,
			{ nom = d:GetFullName(), boite = aabbDePiece(d.CFrame, d.Size), obb = obb(d.CFrame, d.Size) }
		)
	end
	local estZone = d.Parent and d.Parent.Name:match("^%d_") ~= nil
	if not estZone then
		continue
	end
	local marchable = d.CanCollide and d.CanQuery and not d:HasTag("Mortel") and not d:HasTag("Tournant")
	if marchable or d:HasTag("Checkpoint") then
		local dep = d:GetAttribute("Deplacement")
		local dx, dz = 0, 0
		if typeof(dep) == "Vector3" then
			dx, dz = dep.X, dep.Z
		end
		local s, pos = d.Size, d.CFrame.Position
		local n = d:GetAttribute("Numero")
		table.insert(plateformes, {
			nom = d.Parent.Name .. "/" .. d.Name .. string.format(" (%.0f, %.0f, %.0f)", pos.X, pos.Y + s.Y / 2, pos.Z),
			x1 = pos.X - s.X / 2 + math.min(0, dx),
			x2 = pos.X + s.X / 2 + math.max(0, dx),
			z1 = pos.Z - s.Z / 2 + math.min(0, dz),
			z2 = pos.Z + s.Z / 2 + math.max(0, dz),
			haut = pos.Y + s.Y / 2,
			cp = n,
		})
		if typeof(n) == "number" then
			checkpoints[n] = pos
		end
	end
end

-- Volume de réapparition d'un checkpoint : cylindre de rayon RAYON_APPARITION autour du centre de la dalle, du dessus
-- à dessus + HAUTEUR_APPARITION. Il est échantillonné (un anneau tous les 0,25 stud de rayon, un point tous les
-- 0,25 stud le long de chaque anneau, un niveau tous les 0,25 stud) ; une pièce testée contre ces points est élargie de DILATATION (environ la moitié du pas) pour
-- que rien de fin ne passe entre deux points.
local RAYON_APPARITION, HAUTEUR_APPARITION, DILATATION = 2, 5, 0.15
type Apparition = { nom: string, centre: any, points: { any } }
local apparitions: { Apparition } = {}
for _, d in parcoursModele:GetDescendants() do
	if d:IsA("BasePart") and d:HasTag("Checkpoint") then
		local pos, s = d.CFrame.Position, d.Size
		local dessus = pos.Y + s.Y / 2
		local points = {}
		for k = 0, HAUTEUR_APPARITION / 0.25 do
			local y = dessus + k * 0.25
			table.insert(points, Vector3.new(pos.X, y, pos.Z))
			for r = 0.25, RAYON_APPARITION, 0.25 do
				local nb = math.ceil(2 * math.pi * r / 0.25) -- un point tous les 0,25 stud le long de l'anneau
				for a = 0, nb - 1 do
					local angle = a * 2 * math.pi / nb
					table.insert(points, Vector3.new(pos.X + r * math.cos(angle), y, pos.Z + r * math.sin(angle)))
				end
			end
		end
		table.insert(apparitions, {
			nom = `{d.Name} ({string.format("%.1f, %.1f, %.1f", pos.X, dessus, pos.Z)})`,
			centre = Vector3.new(pos.X, dessus + HAUTEUR_APPARITION / 2, pos.Z),
			points = points,
		})
	end
end

-- Où peut être le centre d'un personnage debout sur la dalle (environ 3 studs au-dessus du dessus).
local function volumeDuCentre(p: Plateforme): Boite
	return { min = Vector3.new(p.x1, p.haut + 2.5, p.z1), max = Vector3.new(p.x2, p.haut + 3.5, p.z2) }
end

---------------------------------------------------------------------------------------------------------------
-- Événements.
print("\n== Événements ==")
local MARGE = Vector3.new(
	Reglages.EVENEMENT_MARGE_HORIZONTALE,
	Reglages.EVENEMENT_MARGE_VERTICALE,
	Reglages.EVENEMENT_MARGE_HORIZONTALE
) -- marges de contact du client
local DUREE_SIMULEE, PAS = 120, 0.01

type Horaire = { nom: string, periode: number, decalage: number, preavis: number, duree: number }
local parPlateforme: { [Plateforme]: { Horaire } } = {}
local nbEvenements = 0

for _, m in evenementsModele:GetDescendants() do
	if not m:HasTag("Evenement") then
		continue
	end
	nbEvenements += 1
	local nom = m:GetFullName()
	local genre = m:GetAttribute("Type")
	local periode, decalage, preavis = m:GetAttribute("Periode"), m:GetAttribute("Decalage"), m:GetAttribute("Preavis")
	local duree = if genre == "Passage" then m:GetAttribute("DureePassage") else m:GetAttribute("DureeChute")
	if not m:IsA("Model") or not m.PrimaryPart then
		defaut(`{nom} : pas un Model avec PrimaryPart`)
		continue
	end
	if
		typeof(periode) ~= "number"
		or typeof(decalage) ~= "number"
		or typeof(preavis) ~= "number"
		or typeof(duree) ~= "number"
		or not Horaires.valide(periode, preavis, duree)
	then
		defaut(`{nom} : Periode / Decalage / Preavis / durée absents ou incohérents`)
		continue
	end
	if preavis < 1 then
		defaut(`{nom} : préavis {preavis} s < 1 s`)
	end
	if not m:FindFirstChild("Preavis") then
		defaut(`{nom} : pas d'enfant Preavis`)
	end
	local pivot = m.PrimaryPart.CFrame.Position
	local corps: Boite? = nil
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Anchored ~= true or p.CanCollide or p.CanTouch or p.CanQuery then
				defaut(`{p:GetFullName()} : doit être ancrée, sans collision, sans toucher ni requête`)
			end
			if p.Name ~= "Preavis" then
				corps = union(corps, aabbDePiece(p.CFrame, p.Size))
			end
		end
	end
	if not corps then
		defaut(`{nom} : aucune pièce`)
		continue
	end
	local balaye: Boite
	if genre == "Passage" then
		local depart, arrivee = m:GetAttribute("Depart"), m:GetAttribute("Arrivee")
		if typeof(depart) ~= "Vector3" or typeof(arrivee) ~= "Vector3" then
			defaut(`{nom} : Depart / Arrivee absents`)
			continue
		end
		balaye = union(decaler(corps, depart - pivot), decaler(corps, arrivee - pivot))
	elseif genre == "Chute" then
		local hauteur = m:GetAttribute("Hauteur")
		if typeof(hauteur) ~= "number" or hauteur <= 0 then
			defaut(`{nom} : Hauteur absente`)
			continue
		end
		balaye = union(corps, decaler(corps, Vector3.new(0, hauteur, 0)))
	else
		defaut(`{nom} : Type inconnu ({genre})`)
		continue
	end
	-- La trajectoire ne traverse aucune pièce solide de la carte (sinon l'objet passerait à travers un mur).
	for _, s in solides do
		if aabbSeCroisent(balaye, s.boite, 0.05) then
			defaut(`{nom} : sa trajectoire traverse {s.nom}`)
		end
	end
	local touche = elargir(balaye, MARGE)
	for _, ap in apparitions do
		for _, pt in ap.points do
			if
				pt.X > touche.min.X
				and pt.X < touche.max.X
				and pt.Y > touche.min.Y
				and pt.Y < touche.max.Y
				and pt.Z > touche.min.Z
				and pt.Z < touche.max.Z
			then
				defaut(`{nom} : un danger passe dans le volume de réapparition du checkpoint {ap.nom}`)
				break
			end
		end
	end
	local concernees = {}
	for _, p in plateformes do
		if aabbSeCroisent(touche, volumeDuCentre(p)) then
			parPlateforme[p] = parPlateforme[p] or {}
			table.insert(parPlateforme[p], {
				nom = m.Parent.Name .. "/" .. m.Name,
				periode = periode,
				decalage = decalage,
				preavis = preavis,
				duree = duree,
			})
			table.insert(concernees, p.nom)
		end
	end
	if #concernees == 0 then
		defaut(`{nom} : ne passe sur aucune plateforme (hors du chemin ?)`)
	end
	print(
		string.format(
			"%s/%s : %s, période %.1f s, décalage %.1f s, préavis %.1f s, danger %.1f s -> %s",
			m.Parent.Name,
			m.Name,
			genre,
			periode,
			decalage,
			preavis,
			duree,
			table.concat(concernees, ", ")
		)
	)
end

print("\n-- Fenêtres sûres par plateforme (simulation sur 120 s, pas de 0,01 s) --")
local tries = {}
for p in parPlateforme do
	table.insert(tries, p)
end
table.sort(tries, function(a, b)
	return a.x1 < b.x1
end)
for _, p in tries do
	local horaires = parPlateforme[p]
	local pmax = 0
	for _, h in horaires do
		pmax = math.max(pmax, h.periode)
	end
	-- Fenêtres sûres (aucun danger actif) sur [0, DUREE_SIMULEE].
	local n = math.floor(DUREE_SIMULEE / PAS)
	local sures: { { number } } = {}
	local debut: number? = nil
	local plusCourteEntreDeux = math.huge
	for i = 0, n do
		local t = i * PAS
		local danger = false
		for _, h in horaires do
			if Horaires.etat(t, h.periode, h.decalage, h.preavis, h.duree) == "actif" then
				danger = true
				break
			end
		end
		if not danger and not debut then
			debut = t
		elseif danger and debut then
			table.insert(sures, { debut, t })
			if debut > 0 then
				plusCourteEntreDeux = math.min(plusCourteEntreDeux, t - debut)
			end
			debut = nil
		end
	end
	if debut then
		table.insert(sures, { debut, DUREE_SIMULEE })
	end
	-- Fenêtre sûre garantie : la plus petite, sur toutes les tranches [t0, t0 + pmax + 2], de la plus longue
	-- fenêtre sûre (coupée aux bords de la tranche).
	local tranche = pmax + 2
	local garantie = math.huge
	local t0 = 0
	while t0 + tranche <= DUREE_SIMULEE do
		local meilleure = 0
		for _, f in sures do
			local l = math.min(f[2], t0 + tranche) - math.max(f[1], t0)
			if l > meilleure then
				meilleure = l
			end
		end
		garantie = math.min(garantie, meilleure)
		t0 += 0.05
	end
	local noms = {}
	for _, h in horaires do
		table.insert(noms, h.nom)
	end
	print(
		string.format(
			"%s : %d objet(s) [%s], fenêtre sûre garantie par cycle %.2f s (plus courte accalmie entre deux dangers %.2f s)",
			p.nom,
			#horaires,
			table.concat(noms, ", "),
			garantie,
			if plusCourteEntreDeux == math.huge then 0 else plusCourteEntreDeux
		)
	)
	if garantie < 2 then
		defaut(`{p.nom} : fenêtre sûre garantie {string.format("%.2f", garantie)} s < 2 s`)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Balanciers.
print("\n== Balanciers ==")
local nbBalanciers = 0
for _, b in evenementsModele:GetDescendants() do
	if not b:HasTag("Balancier") then
		continue
	end
	nbBalanciers += 1
	local nom = b:GetFullName()
	local pivot, axe = b:GetAttribute("Pivot"), b:GetAttribute("Axe")
	local amplitude, periode, decalage =
		b:GetAttribute("Amplitude"), b:GetAttribute("Periode"), b:GetAttribute("Decalage")
	local zmin, zmax = b:GetAttribute("ZoneControleMin"), b:GetAttribute("ZoneControleMax")
	if
		not b:IsA("BasePart")
		or typeof(pivot) ~= "Vector3"
		or typeof(axe) ~= "Vector3"
		or typeof(amplitude) ~= "number"
		or typeof(periode) ~= "number"
		or typeof(decalage) ~= "number"
		or typeof(zmin) ~= "Vector3"
		or typeof(zmax) ~= "Vector3"
	then
		defaut(`{nom} : attributs manquants`)
		continue
	end
	if not b.Anchored or not b.CanCollide then
		defaut(`{nom} : doit être ancré et solide (il pousse)`)
	end
	if math.abs(axe.Magnitude - 1) > 0.01 or amplitude <= 0 or amplitude > 180 or periode <= 0 then
		defaut(`{nom} : Axe non unitaire ou Amplitude / Periode hors limites`)
	end
	local cf0, taille = b.CFrame, b.Size
	local autourDuPivot = CFrame.new(pivot)
	local function aLAngle(degres: number)
		return autourDuPivot * CFrame.fromAxisAngle(axe, math.rad(degres)) * autourDuPivot:Inverse() * cf0
	end
	local zone = obbDeBoite({ min = zmin, max = zmax })
	-- Fenêtre de passage sur une période.
	local pas = 0.005
	local n = math.floor(periode / pas)
	local libre = table.create(n)
	local bouche = 0
	for i = 0, n - 1 do
		local t = decalage + i * pas
		local angle = Horaires.angleBalancier(t, amplitude, periode, decalage)
		libre[i + 1] = not obbSeCroisent(obb(aLAngle(angle), taille), zone, 0)
		if not libre[i + 1] then
			bouche += 1
		end
	end
	local plusLongue, courant = 0, 0
	for i = 1, 2 * n do -- deux tours pour la fenêtre à cheval sur la fin de période
		if libre[(i - 1) % n + 1] then
			courant += 1
			plusLongue = math.max(plusLongue, math.min(courant, n))
		else
			courant = 0
		end
	end
	local fenetre = plusLongue * pas
	if bouche == 0 then
		defaut(`{nom} : ne passe jamais dans sa zone de contrôle (zone mal placée ?)`)
	end
	-- Contact avec la carte sur toute l'amplitude.
	local rayon = (cf0.Position - pivot).Magnitude + taille.Magnitude / 2
	local function prochesParmi(liste)
		local proches = {}
		for _, s in liste do
			local c = (s.boite.min + s.boite.max) / 2
			local demi = (s.boite.max - s.boite.min) / 2
			local ecart = ((c - pivot):Abs() - demi):Max(Vector3.zero)
			if ecart.Magnitude <= rayon then
				table.insert(proches, s)
			end
		end
		return proches
	end
	local function contactsAvec(proches)
		local contacts = {}
		local angle = -amplitude
		while angle <= amplitude + 1e-6 do
			local o = obb(aLAngle(angle), taille)
			for _, s in proches do
				if not contacts[s.nom] and obbSeCroisent(o, s.obb) then
					contacts[s.nom] = angle
				end
			end
			angle += 0.5
		end
		return contacts
	end
	for nomSolide, a in contactsAvec(prochesParmi(solides)) do
		defaut(`{nom} touche {nomSolide} (à {a}°)`)
	end
	for nomDecor, a in contactsAvec(prochesParmi(fantomes)) do
		avertir(`{nom} traverse le décor {nomDecor} (à {a}°)`)
	end
	-- Volume de réapparition des checkpoints : jamais balayé, sur toute l'amplitude.
	for _, ap in apparitions do
		if (ap.centre - pivot).Magnitude > rayon + RAYON_APPARITION + HAUTEUR_APPARITION then
			continue
		end
		local angle = -amplitude
		local pris: number? = nil
		while not pris and angle <= amplitude + 1e-6 do
			local o = obb(aLAngle(angle), taille)
			for _, pt in ap.points do
				local d = pt - o.c
				if
					math.abs(d:Dot(o.axes[1])) <= o.h[1] + DILATATION
					and math.abs(d:Dot(o.axes[2])) <= o.h[2] + DILATATION
					and math.abs(d:Dot(o.axes[3])) <= o.h[3] + DILATATION
				then
					pris = angle
					break
				end
			end
			angle += 0.5
		end
		if pris then
			defaut(`{nom} balaie le volume de réapparition du checkpoint {ap.nom} (à {pris}°)`)
		end
	end
	print(
		string.format(
			"%s : pivot (%.1f, %.1f, %.1f), amplitude %d°, période %.1f s, décalage %.1f s, fenêtre de passage %.2f s, zone bouchée %d %% du temps",
			nom,
			pivot.X,
			pivot.Y,
			pivot.Z,
			amplitude,
			periode,
			decalage,
			fenetre,
			math.floor(100 * bouche / n + 0.5)
		)
	)
	if fenetre < 1.5 then
		defaut(`{nom} : fenêtre de passage {string.format("%.2f", fenetre)} s < 1,5 s`)
	end
end
if nbBalanciers < 5 or nbBalanciers > 8 then
	defaut(`{nbBalanciers} balanciers (5 à 7 obstacles attendus)`)
end

---------------------------------------------------------------------------------------------------------------
-- Panneaux d'anecdotes.
print("\n== Panneaux d'anecdotes ==")
local vus = {}
for _, p in evenementsModele:GetDescendants() do
	if not p:HasTag("PanneauAnecdote") then
		continue
	end
	local n = p:GetAttribute("Numero")
	if typeof(n) ~= "number" or n < 0 or n > 15 or n % 1 ~= 0 then
		defaut(`{p:GetFullName()} : Numero invalide`)
		continue
	end
	if vus[n] then
		defaut(`PanneauAnecdote {n} en double`)
	end
	vus[n] = true
	local gui = p:FindFirstChildOfClass("SurfaceGui")
	for _, nom in { "Titre", "Corps" } do
		local label = gui and gui:FindFirstChild(nom)
		if not label or not label:IsA("TextLabel") then
			defaut(`PanneauAnecdote {n} : pas de SurfaceGui avec un TextLabel « {nom} »`)
		end
	end
	if gui and gui:FindFirstChild("Texte") then
		defaut(`PanneauAnecdote {n} : l'ancien label « Texte » est encore là`)
	end
	local corps = gui and gui:FindFirstChild("Corps")
	if corps and corps:IsA("TextLabel") and (corps.TextScaled or not corps.TextWrapped or corps.RichText) then
		defaut(`PanneauAnecdote {n} : « Corps » doit être à taille fixe, à la ligne, sans texte enrichi`)
	end
	local cp = checkpoints[n]
	local distance = if cp then (p.CFrame.Position - cp).Magnitude else math.huge
	if distance > 16 then
		defaut(`PanneauAnecdote {n} : à {string.format("%.1f", distance)} studs de son checkpoint`)
	end
	local o = obb(p.CFrame, p.Size)
	for _, s in solides do
		if obbSeCroisent(o, s.obb) then
			defaut(`PanneauAnecdote {n} touche {s.nom}`)
		end
	end
	for _, s in fantomes do
		if obbSeCroisent(o, s.obb) then
			avertir(`PanneauAnecdote {n} traverse le décor {s.nom}`)
		end
	end
end
for n = 0, 15 do
	if not vus[n] then
		defaut(`PanneauAnecdote {n} absent`)
	end
end
print(`panneaux : {#(function()
	local l = {}
	for n in vus do
		table.insert(l, n)
	end
	return l
end)()} / 16`)

---------------------------------------------------------------------------------------------------------------
-- « ! » de préavis (BillboardGui « FeuRouge », AlwaysOnTop faux : le décor opaque le cache). Pour chacun, aucune
-- pièce opaque (Parcours.rbxm hors pièces tournantes, et le décor fixe d'Evenements.rbxm : dossier « Decor ») ne doit
-- couper le segment entre lui et les yeux d'un joueur qui attend (dernier auvent de la rue de la Soif, y 14 + 4,5 ;
-- terrasse, y 10 + 4,5), ni le contenir (carré de 2 studs, retiré du mur d'un stud de marge à plat : rien n'est dans
-- le cube de demi-côté 0,9 autour de son centre) ; et il ne recouvre aucun véhicule (volume balayé par un
-- événement de passage, agrandi d'un stud).
print("\n== « ! » de préavis ==")
local occulteurs = {}
for _, d in parcoursModele:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency <= 0.5 and not d:HasTag("Tournant") then
		table.insert(occulteurs, { nom = d:GetFullName(), obb = obb(d.CFrame, d.Size) })
	end
end
for _, d in evenementsModele:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency <= 0.5 and d.Name ~= "Preavis" and d:FindFirstAncestor("Decor") then
		table.insert(occulteurs, { nom = d:GetFullName(), obb = obb(d.CFrame, d.Size) })
	end
end

-- Le segment [a, b] traverse-t-il la boîte orientée ? (test des plans parallèles, dans le repère de la boîte ;
-- `marge` rétrécit la boîte pour ne pas compter un simple effleurement)
local function segmentCoupe(a, b, o, marge: number): boolean
	local tmin, tmax = 0, 1
	local d = b - a
	for i = 1, 3 do
		local axe = o.axes[i]
		local h = o.h[i] - marge
		local p0 = (a - o.c):Dot(axe)
		local dp = d:Dot(axe)
		if math.abs(dp) < 1e-9 then
			if math.abs(p0) > h then
				return false
			end
		else
			local t1, t2 = (-h - p0) / dp, (h - p0) / dp
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return false
			end
		end
	end
	return true
end

local yeux = {}
for _, z in { -3, 0, 3 } do
	table.insert(yeux, { nom = `auvent (511, 18.5, {z})`, pos = Vector3.new(511, 18.5, z) })
end
for _, x in { 518, 524, 530, 536, 542, 546 } do
	for _, z in { -4, 0, 4 } do
		table.insert(yeux, { nom = `terrasse ({x}, 14.5, {z})`, pos = Vector3.new(x, 14.5, z) })
	end
end

local balayes = {} -- volumes balayés par les véhicules (hors bande de préavis)
for _, m in evenementsModele:GetDescendants() do
	if m:HasTag("Evenement") and m:GetAttribute("Type") == "Passage" and m.PrimaryPart then
		local corps: Boite? = nil
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Preavis" then
				corps = union(corps, aabbDePiece(p.CFrame, p.Size))
			end
		end
		local depart, arrivee = m:GetAttribute("Depart"), m:GetAttribute("Arrivee")
		if corps and typeof(depart) == "Vector3" and typeof(arrivee) == "Vector3" then
			local pivot = m.PrimaryPart.CFrame.Position
			table.insert(balayes, {
				nom = m:GetFullName(),
				boite = union(decaler(corps, depart - pivot), decaler(corps, arrivee - pivot)),
			})
		end
	end
end

local nbFeux, nbSegments = 0, 0
for _, g in evenementsModele:GetDescendants() do
	if not (g:IsA("BillboardGui") and g.Name == "FeuRouge") then
		continue
	end
	nbFeux += 1
	local bande = g.Parent :: any
	local centre = bande.CFrame.Position + g.StudsOffsetWorldSpace
	local nom = g:GetFullName()
	if g.AlwaysOnTop or g.MaxDistance ~= 80 or g.Size.X.Scale ~= 2 then
		defaut(`{nom} : « ! » à 2 studs, AlwaysOnTop faux, MaxDistance 80 attendus`)
	end
	local cube = obbDeBoite({ min = centre - Vector3.new(0.9, 0.9, 0.9), max = centre + Vector3.new(0.9, 0.9, 0.9) })
	for _, o in occulteurs do
		if obbSeCroisent(cube, o.obb, 0) then
			defaut(`{nom} ({string.format("%.1f, %.1f, %.1f", centre.X, centre.Y, centre.Z)}) touche {o.nom}`)
		end
	end
	for _, v in balayes do
		if
			aabbSeCroisent(
				elargir(v.boite, Vector3.new(1, 1, 1)),
				{ min = centre - Vector3.one, max = centre + Vector3.one }
			)
		then
			defaut(`{nom} recouvre le passage de {v.nom}`)
		end
	end
	if g:FindFirstAncestor("RueDeLaSoif") then
		for _, oeil in yeux do
			nbSegments += 1
			for _, o in occulteurs do
				if segmentCoupe(oeil.pos, centre, o.obb, 0.05) then
					defaut(`{nom} caché depuis {oeil.nom} par {o.nom}`)
					break
				end
			end
		end
	end
end
print(`{nbFeux} « ! », {nbSegments} lignes de vue testées contre {#occulteurs} pièces opaques`)
assert(nbFeux > 0, "aucun « ! » de préavis trouvé")

---------------------------------------------------------------------------------------------------------------
local pieces = 0
for _, d in evenementsModele:GetDescendants() do
	if d:IsA("BasePart") then
		pieces += 1
	end
end
print(`\n{nbEvenements} événements, {nbBalanciers} balanciers, {pieces} pièces dans Evenements.rbxm`)
print(`défauts : {defauts}, avertissements : {avertissements}`)
if defauts > 0 then
	process.exit(1)
end
