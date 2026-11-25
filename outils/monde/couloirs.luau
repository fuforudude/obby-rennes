-- Couloirs de saut, pour les contrôles de carte (verifier-sauts.luau, verifier-ascension.luau) : un saut a beau tenir
-- dans les limites de vide et de montée, un mur, un plafond ou un décor solide en travers peut le barrer. On rejoue
-- donc des sauts entiers d'une plateforme à l'autre (physique réelle de outils/monde/physique.luau) et on compte la
-- part qui se pose. Le sauteur vise tout droit un point d'arrivée, à pleine vitesse, et s'y laisse tomber ; un mur
-- l'arrête sans l'empêcher de monter, un plafond lui coupe son élan, un autre solide sous ses pieds fait rater l'arc, une pièce
-- mortelle frôlée aussi.
-- Tous les solides comptent, plateformes ou non (CanQuery ou non). Un joueur qui contourne fait au moins aussi bien.
local Formes = require("./formes")
local Physique = require("./physique")

local Couloirs = {}

-- Le personnage : trois sphères empilées (pieds, buste, tête), environ 5 studs de haut et 1,7 de large ; les pieds sont
-- un peu relevés pour qu'un arc ne frotte pas la plateforme où il se pose.
local RAYON = 0.85
local SPHERES = { 1, 2.5, 4.1 }
local PAS_TEMPS = 0.02
local PAS_ARCS = 7919
local ARCS_SANS_SUCCES = 150
local MAILLE = 3 -- points de départ et d'arrivée par axe
local PROFONDEUR = 8 -- studs de plateforme explorés en arrière du bord le plus proche de l'autre
local MARGE = 0.2 -- du bord
local INSTANTS_SECOND_SAUT = { 0.2, 0.27, 0.35, 0.45, 0.54 } -- s après le décollage ; 0,27 est le sommet

type Rect = { x1: number, x2: number, z1: number, z2: number, haut: number }

local G, V0 = Physique.G, Physique.V0

-- La partie de `a` tournée vers `b`, en mailles.
local function points(a: Rect, b: Rect): { { number } }
	local gx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2)) + PROFONDEUR
	local gz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2)) + PROFONDEUR
	local function suite(bas: number, haut: number): { number }
		if haut - bas <= 2 * MARGE then
			return { (bas + haut) / 2 }
		end
		local t = {}
		for i = 0, MAILLE - 1 do
			table.insert(t, bas + MARGE + (haut - bas - 2 * MARGE) * i / (MAILLE - 1))
		end
		return t
	end
	local liste = {}
	for _, x in suite(math.max(a.x1, b.x1 - gx), math.min(a.x2, b.x2 + gx)) do
		for _, z in suite(math.max(a.z1, b.z1 - gz), math.min(a.z2, b.z2 + gz)) do
			table.insert(liste, { x, z })
		end
	end
	return liste
end

--- Part (0 à 1) des arcs possibles de `a` à `b` avec `caps` qui se posent sur `b` malgré les `solides` (formes lues par
--- formes.luau), et nombre d'arcs possibles. Sans arc possible : 0, 0. Avec `seuil`, on s'arrête dès que cette part est
--- acquise (le résultat est alors une estimation, au moins égale au seuil).
function Couloirs.partLibre(a: Rect, b: Rect, caps: number, solides: { any }, seuil: number?): (number, number)
	local montee = b.haut - a.haut
	if montee > Physique.monteeMax(caps) then
		return 0, 0
	end
	local vitesse = Physique.vitesseSol(caps)
	local gain = Physique.gainDash(caps)

	-- Les façons de voler : (instant du second saut ou nil, durée sans obstacle).
	local vols: { { t2: number, duree: number } } = {}
	if montee <= Physique.HAUTEUR_SIMPLE then
		table.insert(vols, { t2 = math.huge, duree = Physique.tempsVol(montee, 0) })
	end
	if bit32.band(caps, Physique.CAPACITES.doubleSaut) ~= 0 then
		for _, t2 in INSTANTS_SECOND_SAUT do
			local reste = V0 * V0 - 2 * G * (montee - (V0 * t2 - G * t2 * t2 / 2))
			if reste >= 0 then
				table.insert(vols, { t2 = t2, duree = t2 + (V0 + math.sqrt(reste)) / G })
			end
		end
	end

	-- Solides à portée du couloir.
	local x1, x2 = math.min(a.x1, b.x1) - 1, math.max(a.x2, b.x2) + 1
	local z1, z2 = math.min(a.z1, b.z1) - 1, math.max(a.z2, b.z2) + 1
	local y1, y2 = math.min(a.haut, b.haut) - 2, math.max(a.haut, b.haut) + Physique.HAUTEUR_DOUBLE + 6
	local proches = {}
	for _, s in solides do
		if s.mn.X <= x2 and s.mx.X >= x1 and s.mn.Z <= z2 and s.mx.Z >= z1 and s.mn.Y <= y2 and s.mx.Y >= y1 then
			table.insert(proches, s)
		end
	end
	local tue = false
	local function heurte(x: number, y: number, z: number): boolean
		for _, s in proches do
			local mn, mx = s.mn, s.mx
			if
				x + RAYON >= mn.X
				and x - RAYON <= mx.X
				and z + RAYON >= mn.Z
				and z - RAYON <= mx.Z
				and y + 5 >= mn.Y
				and y <= mx.Y
			then
				for _, h in SPHERES do
					if Formes.distance(s, x, y + h, z) < RAYON then
						tue = tue or s.mortel
						return true
					end
				end
			end
		end
		return false
	end

	local function seRejoue(p: { number }, q: { number }, d: number, t2: number, dash: boolean): boolean
		local ux, uz = if d > 0 then (q[1] - p[1]) / d else 0, if d > 0 then (q[2] - p[2]) / d else 0
		local fait, y, vy, t, second = 0, a.haut, V0, 0, false
		tue = false
		while not tue do
			t += PAS_TEMPS
			if not second and t >= t2 then
				second, vy = true, math.max(vy, V0)
			end
			local dy = vy * PAS_TEMPS - G * PAS_TEMPS * PAS_TEMPS / 2
			vy -= G * PAS_TEMPS
			local x, z = p[1] + ux * fait, p[2] + uz * fait
			if dy <= 0 and y + dy <= b.haut then
				-- À hauteur d'arrivée : posé si l'on est au-dessus de `b` (le pied déborde un peu du bord).
				if
					x >= b.x1 - 0.5
					and x <= b.x2 + 0.5
					and z >= b.z1 - 0.5
					and z <= b.z2 + 0.5
					and y >= b.haut - 0.01
				then
					return true
				elseif y + dy < b.haut - 2 then
					return false
				end
			end
			if heurte(x, y + dy, z) then
				if dy <= 0 then
					return false -- posé ailleurs
				end
				vy = 0
			else
				y += dy
			end
			local v = if dash and t <= Physique.Reglages.DASH_DUREE then Physique.Reglages.DASH_VITESSE else vitesse
			local suivant = math.min(d, fait + v * PAS_TEMPS)
			if not heurte(p[1] + ux * suivant, y, p[2] + uz * suivant) then
				fait = suivant
			end
		end
		return false
	end

	local arcs = {}
	local arrivees = points(b, a)
	for _, p in points(a, b) do
		for _, q in arrivees do
			local d = math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
			for _, vol in vols do
				if d <= vitesse * vol.duree + gain then
					table.insert(arcs, { p = p, q = q, d = d, vol = vol })
				end
			end
		end
	end
	-- Parcours par grands pas (premier, donc chaque arc une fois) : un échantillon partiel reste représentatif.
	local n, libres, faits = #arcs, 0, 0
	local voulus = if seuil then math.ceil(seuil * n) else math.huge
	for k = 0, n - 1 do
		local arc = arcs[k * PAS_ARCS % n + 1]
		if seuil and faits >= ARCS_SANS_SUCCES and libres == 0 then
			break -- barré : inutile de rejouer le reste
		end
		faits += 1
		if seRejoue(arc.p, arc.q, arc.d, arc.vol.t2, arc.d > vitesse * arc.vol.duree) then
			libres += 1
			if libres >= voulus then
				break
			end
		end
	end
	return if n == 0 then 0 else libres / (if libres >= voulus then faits else n), n
end

return Couloirs
