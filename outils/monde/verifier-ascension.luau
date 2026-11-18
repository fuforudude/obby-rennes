-- Usage : lune run outils/monde/verifier-ascension.luau [ascension.rbxm] [parcours.rbxm] (défauts
-- monde/Ascension.rbxm et monde/Parcours.rbxm ; après lune run outils/monde/generer.luau).
--
-- Contrôle l'ascension construite par outils/monde/Ascension.luau :
-- - un chemin existe du « PiedAscension » au « SommetAscension » en ne franchissant que des sauts possibles avec les
--   trois capacités (course, double saut, dash) : montée d'au plus 9 studs, vide d'au plus 16 studs à plat, les deux
--   étant liés (plus on monte, moins on avance) ; le sommet est à au moins 250 studs au-dessus du pied ;
-- - le pied est atteignable depuis la salle de partiel : un chemin existe de la dalle du checkpoint 15 (cherchée
--   dans Parcours.rbxm, elle n'est pas dans ce .rbxm) au pied, en 4 sauts au plus, dont le premier pose sur la dalle
--   marquée « DepartAcces » (l'accès passe par la verrière du toit) et dont aucun ne dépasse 75 % des limites de
--   saut : l'accès est une transition, pas une épreuve ;
-- - les paliers (tag « Palier ») sont numérotés 1..N sans trou, 4 ou 5, étagés d'environ 60 studs, portent l'attribut
--   « Hauteur » juste et un enfant « Boutique » (Model) ;
-- - les étages (tag « EtageAscension ») sont numérotés 1..M sans trou, de hauteur croissante, espacés d'environ
--   15 studs ;
-- - toute pièce qui porte « HauteurRelative » (ce que lisent le serveur et l'interface) porte aussi « Hauteur »
--   (le Y absolu) et vaut exactement « Hauteur » moins la hauteur du pied, qui est à 0 ;
-- - aucune pièce mortelle à portée d'un saut (ici : aucune pièce mortelle du tout, la chute est détectée par le
--   « Mortel » de la ville) ;
-- - aucun plafond trop bas (moins de 5,5 studs de pièce solide au-dessus d'une plateforme), dans l'ascension comme
--   entre les deux cartes (une pièce du tuto au-dessus d'une dalle de l'accès, une pièce de l'ascension au-dessus
--   d'une plateforme du tuto) ;
-- - toutes les plateformes sont ancrées et horizontales (une dalle penchée fausserait tout le reste) ;
-- - tous les TextLabel de SurfaceGui sont à taille fixe (jamais TextScaled), de 12 à 100 px, et leur texte tient
--   dans son label (pire cas des tableaux : 10 lignes de classement) ; le bloc TEXTE_PUR d'Ascension.luau est
--   identique à celui de Parcours.luau ;
-- - le budget de pièces (1 500) est tenu.
-- Code de sortie 1 au moindre défaut.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local chemin = process.args[1] or "monde/Ascension.rbxm"
local modele = roblox.deserializeModel(fs.readFile(chemin))[1]

local defauts = 0
local function defaut(message: string)
	defauts += 1
	print("  DÉFAUT : " .. message)
end

---------------------------------------------------------------------------------------------------------------
-- Règle de saut, les trois capacités débloquées. Repères (personnage Roblox par défaut) : saut debout 5 à 6 studs de
-- vide et 4,5 de montée ; en courant (× 1,5) 8 à 9 de vide ; double saut 9 de montée en tout ; dash 8 à 12 de vide en
-- plus. Plus on monte, moins on avance : le vide tenable va de 16 studs à plat à 6 studs pour 9 studs de montée.
-- Une descente aide un peu (jusqu'à 4 studs de vide en plus). C'est la règle qu'applique outils/monde/Ascension.luau.
local MONTEE_MAX, VIDE_MAX, HAUTEUR_LIBRE = 9, 16, 5.5
local function videTenable(montee: number): number
	local v = VIDE_MAX - 10 * math.max(0, montee) / MONTEE_MAX
	if montee < 0 then
		v += math.min(4, -montee / 4)
	end
	return v
end

type Plateforme = {
	nom: string,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	haut: number,
	bas: number,
	part: any?,
}

-- Nombre de sauts et difficulté tolérés pour l'accès (de la salle de partiel au pied, par la verrière du toit) :
-- c'est une transition, pas une épreuve.
local ACCES_SAUTS_MAX, ACCES_DIFFICULTE_MAX = 4, 0.75

-- Boîte alignée sur les axes d'une pièce, quelle que soit son orientation.
local function emprise(part)
	local cf, taille = part.CFrame, part.Size
	local h = taille / 2
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				mn, mx = mn:Min(p), mx:Max(p)
			end
		end
	end
	return mn, mx
end

local plateformes: { Plateforme } = {}
local solides: { Plateforme } = {}
local mortels: { Plateforme } = {}
local etages, paliers = {}, {}
local pied, sommet
local depart -- la dalle marquée DepartAcces (sortie de la salle de partiel)
local tableaux = {}
local hauteurs: { Plateforme } = {} -- les pièces qui portent l'attribut « HauteurRelative »
local pieces = 0

for _, d in modele:GetDescendants() do
	if not d:IsA("BasePart") then
		continue
	end
	pieces += 1
	if not d.Anchored then
		defaut(`{d:GetFullName()} : pièce non ancrée`)
	end
	local mn, mx = emprise(d)
	local boite: Plateforme = {
		nom = d:GetFullName(),
		x1 = mn.X,
		x2 = mx.X,
		z1 = mn.Z,
		z2 = mx.Z,
		haut = mx.Y,
		bas = mn.Y,
		part = d,
	}
	if d:HasTag("Mortel") then
		table.insert(mortels, boite)
	end
	if d.CanCollide and d.Transparency < 1 then
		table.insert(solides, boite)
	end
	local marchable = d.CanCollide and d.CanQuery and not d:HasTag("Mortel") and d.Transparency < 1
	if marchable then
		if math.abs(d.CFrame.YVector.Y) < 0.999 then
			defaut(`{boite.nom} : plateforme penchée (on ne doit poser les pieds que sur de l'horizontal)`)
		end
		table.insert(plateformes, boite)
		if d:GetAttribute("DepartAcces") then
			depart = boite
		end
		if d:HasTag("PiedAscension") then
			if pied then
				defaut("plusieurs pièces taguées PiedAscension")
			end
			pied = boite
		end
		if d:HasTag("SommetAscension") then
			if sommet then
				defaut("plusieurs pièces taguées SommetAscension")
			end
			sommet = boite
		end
		if d:HasTag("Palier") then
			table.insert(paliers, { boite = boite, part = d })
		end
	elseif d:HasTag("PiedAscension") or d:HasTag("SommetAscension") or d:HasTag("Palier") then
		defaut(`{boite.nom} : taguée plateforme de jeu mais pas marchable (collision, requête, transparence)`)
	end
	if d:HasTag("EtageAscension") then
		if d.CanCollide then
			defaut(`{boite.nom} : un étage se traverse, il ne doit pas avoir de collision`)
		end
		if not d.CanTouch then
			defaut(`{boite.nom} : un étage doit pouvoir être touché (CanTouch)`)
		end
		table.insert(etages, { boite = boite, numero = d:GetAttribute("Numero") })
	end
	if d:GetAttribute("HauteurRelative") ~= nil then
		table.insert(hauteurs, boite)
	end
	for _, tag in { "TableauHauteur", "TableauAscension" } do
		if d:HasTag(tag) then
			tableaux[tag] = (tableaux[tag] or 0) + 1
		end
	end
end

print(`{chemin} : {pieces} pièces, {#plateformes} plateformes, {#etages} étages, {#paliers} paliers`)

---------------------------------------------------------------------------------------------------------------
-- Le tuto (outils/monde/Parcours.luau), chargé lui aussi, pour deux raisons :
-- - la dalle du checkpoint 15 (la salle de partiel) est le départ de l'accès, et elle n'est pas dans ce .rbxm ;
-- - l'accès traverse la verrière ouverte dans le toit de Sup de Vinci : il faut vérifier qu'aucune pièce du tuto ne
--   fait plafond bas au-dessus d'une dalle de l'accès, ni aucune pièce de l'ascension au-dessus d'une plateforme du
--   tuto. On ne redéclare donc plus ici de coordonnées du Parcours : elles sont lues dans son .rbxm.
local cheminParcours = process.args[2] or "monde/Parcours.rbxm"
assert(
	fs.isFile(cheminParcours),
	`{cheminParcours} absent : lancer « lune run outils/monde/generer.luau » avant ce contrôle`
)
local salle: Plateforme?
local solidesParcours: { Plateforme } = {}
local plateformesParcours: { Plateforme } = {}
for _, d in roblox.deserializeModel(fs.readFile(cheminParcours))[1]:GetDescendants() do
	if not d:IsA("BasePart") then
		continue
	end
	local mn, mx = emprise(d)
	local boite: Plateforme = {
		nom = "Parcours/" .. d.Name,
		x1 = mn.X,
		x2 = mx.X,
		z1 = mn.Z,
		z2 = mx.Z,
		haut = mx.Y,
		bas = mn.Y,
		part = d,
	}
	if d.CanCollide and d.Transparency < 1 then
		table.insert(solidesParcours, boite)
	end
	if d.CanCollide and d.CanQuery and d.Transparency < 1 and not d:HasTag("Mortel") then
		table.insert(plateformesParcours, boite)
	end
	if d:HasTag("Checkpoint") and d:GetAttribute("Numero") == 15 then
		salle = boite
	end
end
assert(salle, `aucune dalle taguée Checkpoint de Numero 15 dans {cheminParcours} (la salle de partiel)`)
print(
	string.format(
		"%s : %d pièces solides, %d plateformes ; salle de partiel %s (x %.0f..%.0f, z %.0f..%.0f, dessus %.0f)",
		cheminParcours,
		#solidesParcours,
		#plateformesParcours,
		salle.nom,
		salle.x1,
		salle.x2,
		salle.z1,
		salle.z2,
		salle.haut
	)
)

if pieces > 1500 then
	defaut(`{pieces} pièces > budget 1 500`)
end
for _, tag in { "TableauHauteur", "TableauAscension" } do
	if tableaux[tag] ~= 1 then
		defaut(`{tableaux[tag] or 0} panneau(x) tagué(s) {tag} (un seul attendu)`)
	end
end
assert(pied, "aucune pièce taguée PiedAscension")
assert(sommet, "aucune pièce taguée SommetAscension")
assert(depart, "aucune dalle avec l'attribut DepartAcces (le départ de l'accès depuis le checkpoint 15)")

---------------------------------------------------------------------------------------------------------------
-- Hauteurs annoncées au jeu : « Hauteur » est le Y absolu de la marche, « HauteurRelative » la hauteur gagnée
-- depuis le pied (c'est elle que lisent le serveur et l'interface). Le pied porte les deux, à 0.
local hauteurPied = pied.part:GetAttribute("Hauteur")
if typeof(hauteurPied) ~= "number" or math.abs(hauteurPied - pied.haut) > 0.01 then
	defaut(string.format("le pied : attribut Hauteur %s, dessus réel %.2f", tostring(hauteurPied), pied.haut))
	hauteurPied = pied.haut
end
if pied.part:GetAttribute("HauteurRelative") ~= 0 then
	defaut(`le pied : HauteurRelative {tostring(pied.part:GetAttribute("HauteurRelative"))} (0 attendu)`)
end
for _, b in hauteurs do
	local h, hr = b.part:GetAttribute("Hauteur"), b.part:GetAttribute("HauteurRelative")
	if typeof(h) ~= "number" then
		defaut(`{b.nom} : HauteurRelative sans attribut Hauteur`)
	elseif typeof(hr) ~= "number" or math.abs(hr - (h - hauteurPied)) > 0.01 then
		defaut(
			string.format(
				"%s : HauteurRelative %s, %.2f attendu (Hauteur %.2f moins le pied %.2f)",
				b.nom,
				tostring(hr),
				h - hauteurPied,
				h,
				hauteurPied
			)
		)
	end
end
print(`attributs HauteurRelative : {#hauteurs} (pied à {hauteurPied})`)

---------------------------------------------------------------------------------------------------------------
-- Le chemin : du pied au sommet, saut par saut.
local function vide(a: Plateforme, b: Plateforme): number
	local gx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2))
	local gz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2))
	return math.sqrt(gx * gx + gz * gz)
end

local function sautPossible(a: Plateforme, b: Plateforme): boolean
	local montee = b.haut - a.haut
	if montee > MONTEE_MAX then
		return false
	end
	return vide(a, b) <= videTenable(montee)
end

-- Difficulté d'un saut : la plus grande des deux parts prises aux limites (montée / 9, vide / vide tenable).
-- 1 = tout juste possible, math.huge = impossible.
local function difficulte(a: Plateforme, b: Plateforme): number
	local montee = b.haut - a.haut
	if montee > MONTEE_MAX then
		return math.huge
	end
	local v, tenable = vide(a, b), videTenable(montee)
	if v > tenable then
		return math.huge
	end
	return math.max(montee / MONTEE_MAX, v / math.max(tenable, 0.001))
end

-- Chemin dont le saut le plus dur est le plus facile possible (goulot minimal) : c'est celui-là qu'on annonce, parce
-- qu'un chemin facile qui existe compte plus qu'un raccourci acrobatique. Rend, par plateforme, la difficulté du
-- goulot pour y arriver et le prédécesseur de ce chemin.
local function goulot(noeuds: { Plateforme }, source: Plateforme)
	local meilleur: { [Plateforme]: number } = { [source] = 0 }
	local via: { [Plateforme]: Plateforme } = {}
	local reglees = {}
	while true do
		local a, d = nil, math.huge
		for n, v in meilleur do
			if not reglees[n] and v < d then
				a, d = n, v
			end
		end
		if not a then
			break
		end
		reglees[a] = true
		for _, b in noeuds do
			local w = math.max(d, difficulte(a, b))
			if w < (meilleur[b] or math.huge) then
				meilleur[b], via[b] = w, a
			end
		end
	end
	return meilleur, via
end

local function remonter(via, source: Plateforme, cible: Plateforme): { Plateforme }
	local suite = { cible }
	while suite[1] ~= source do
		table.insert(suite, 1, via[suite[1]])
	end
	return suite
end

local meilleur, via = goulot(plateformes, pied)
if not meilleur[sommet] or meilleur[sommet] == math.huge then
	defaut("aucun chemin du PiedAscension au SommetAscension avec les trois capacités")
else
	local suite = remonter(via, pied, sommet)
	local sauts = {}
	for i = 1, #suite - 1 do
		local a, b = suite[i], suite[i + 1]
		table.insert(sauts, {
			v = vide(a, b),
			m = b.haut - a.haut,
			d = difficulte(a, b),
			a = a.nom:match("[^.]+$"),
			b = b.nom:match("[^.]+$"),
		})
	end
	print(
		string.format(
			"chemin pied -> sommet : %d sauts, %.1f studs de montée (%.1f -> %.1f), saut le plus dur à %d %% des limites",
			#sauts,
			sommet.haut - pied.haut,
			pied.haut,
			sommet.haut,
			math.floor(100 * meilleur[sommet] + 0.5)
		)
	)
	table.sort(sauts, function(a, b)
		return a.d > b.d
	end)
	local bandes = { 0, 0, 0, 0 }
	for _, j in sauts do
		local k = if j.d < 0.5 then 1 elseif j.d < 0.7 then 2 elseif j.d < 0.85 then 3 else 4
		bandes[k] += 1
	end
	print(
		string.format(
			"  difficulté des sauts : %d faciles (< 50 %%), %d moyens (50-70 %%), %d durs (70-85 %%), %d très durs (> 85 %%)",
			bandes[1],
			bandes[2],
			bandes[3],
			bandes[4]
		)
	)
	for i = 1, math.min(6, #sauts) do
		local j = sauts[i]
		print(
			string.format(
				"  saut dur %d : vide %.1f, montée %.1f (%d %% des limites) %s -> %s",
				i,
				j.v,
				j.m,
				math.floor(100 * j.d + 0.5),
				j.a,
				j.b
			)
		)
	end
end
if sommet.haut - pied.haut < 250 then
	defaut(string.format("%.1f studs du pied au sommet (250 au moins attendus)", sommet.haut - pied.haut))
end

-- Plateformes inatteignables depuis le pied (hors accès, qui est sous le pied).
local inatteignables = 0
for _, p in plateformes do
	if (meilleur[p] or math.huge) == math.huge and p.haut > pied.haut then
		inatteignables += 1
		print(string.format("  inatteignable depuis le pied : %s (haut %.1f)", p.nom, p.haut))
	end
end
if inatteignables > 0 then
	defaut(`{inatteignables} plateforme(s) au-dessus du pied inatteignable(s)`)
end

---------------------------------------------------------------------------------------------------------------
-- L'accès depuis la salle de partiel : de la dalle du checkpoint 15 au pied, par la verrière du toit. Court et
-- facile (ACCES_SAUTS_MAX sauts au plus, chacun sous ACCES_DIFFICULTE_MAX des limites), et il passe bien par la
-- dalle marquée DepartAcces.
local avecSalle = table.clone(plateformes)
table.insert(avecSalle, salle)
local meilleurAcces, viaAcces = goulot(avecSalle, salle)
if (meilleurAcces[pied] or math.huge) == math.huge then
	defaut(`aucun chemin de {salle.nom} (la salle de partiel) au pied de l'ascension`)
else
	local suite = remonter(viaAcces, salle, pied)
	local noms = {}
	for i, p in suite do
		table.insert(noms, string.format("%s (%.0f)", p.nom:match("[^.]+$") or p.nom, p.haut))
		if i == 1 then
			continue
		end
		local a, b = suite[i - 1], p
		local d = difficulte(a, b)
		print(
			string.format(
				"  saut d'accès %d : vide %.1f, montée %.1f (%d %% des limites)",
				i - 1,
				vide(a, b),
				b.haut - a.haut,
				math.floor(100 * d + 0.5)
			)
		)
		if d > ACCES_DIFFICULTE_MAX then
			defaut(
				string.format(
					"saut d'accès %s -> %s à %d %% des limites (%d %% au plus : l'accès est une transition)",
					a.nom:match("[^.]+$") or a.nom,
					b.nom:match("[^.]+$") or b.nom,
					math.floor(100 * d + 0.5),
					math.floor(100 * ACCES_DIFFICULTE_MAX + 0.5)
				)
			)
		end
	end
	print(`accès salle de partiel -> pied : {#suite - 1} sauts : ` .. table.concat(noms, " -> "))
	if #suite - 1 > ACCES_SAUTS_MAX then
		defaut(`accès en {#suite - 1} sauts ({ACCES_SAUTS_MAX} au plus attendus)`)
	end
	if suite[2] ~= depart then
		defaut(
			`l'accès ne commence pas par la dalle marquée DepartAcces ({depart.nom}) mais par {suite[2] and suite[2].nom}`
		)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Paliers : 4 ou 5, numérotés sans trou, étagés d'environ 60 studs, Hauteur juste, enfant Boutique.
table.sort(paliers, function(a, b)
	return a.boite.haut < b.boite.haut
end)
if #paliers < 4 or #paliers > 5 then
	defaut(`{#paliers} paliers (4 ou 5 attendus)`)
end
local numerosVus = {}
for rang, p in paliers do
	local n = p.part:GetAttribute("Numero")
	local h = p.part:GetAttribute("Hauteur")
	if typeof(n) ~= "number" or n ~= rang then
		defaut(`{p.boite.nom} : Numero {tostring(n)}, {rang} attendu (numérotation par hauteur croissante, sans trou)`)
	elseif numerosVus[n] then
		defaut(`palier {n} en double`)
	end
	if typeof(n) == "number" then
		numerosVus[n] = true
	end
	if typeof(h) ~= "number" or math.abs(h - p.boite.haut) > 0.01 then
		defaut(string.format("%s : attribut Hauteur %s, dessus réel %.2f", p.boite.nom, tostring(h), p.boite.haut))
	end
	local boutique = p.part:FindFirstChild("Boutique")
	if not boutique or not boutique:IsA("Model") then
		defaut(`{p.boite.nom} : pas d'enfant « Boutique » (Model) marquant la place de la boutique`)
	end
	local precedent = if rang == 1 then pied.haut else paliers[rang - 1].boite.haut
	local ecart = p.boite.haut - precedent
	print(string.format("palier %d : hauteur %.1f (+%.1f), %s", rang, p.boite.haut, ecart, p.boite.nom))
	if math.abs(ecart - 60) > 8 then
		defaut(string.format("palier %d : %.1f studs depuis le précédent (60 ± 8 attendus)", rang, ecart))
	end
end
if #paliers > 0 and sommet.haut - paliers[#paliers].boite.haut > 60 then
	defaut("le sommet est à plus de 60 studs du dernier palier")
end

---------------------------------------------------------------------------------------------------------------
-- Étages : numérotés 1..M sans trou, hauteur croissante, espacés d'environ 15 studs.
table.sort(etages, function(a, b)
	return a.boite.haut < b.boite.haut
end)
if #etages < 15 then
	defaut(`{#etages} étages (au moins un tous les 15 studs attendu, soit 15 au moins)`)
end
local precedente = pied.haut
for rang, e in etages do
	if typeof(e.numero) ~= "number" or e.numero ~= rang then
		defaut(`{e.boite.nom} : Numero {tostring(e.numero)}, {rang} attendu (sans trou, par hauteur croissante)`)
	end
	local ecart = e.boite.haut - precedente
	if ecart < 8 or ecart > 24 then
		defaut(string.format("étage %d : %.1f studs depuis le précédent (15 ± 7 attendus)", rang, ecart))
	end
	precedente = e.boite.haut
end
print(
	string.format(
		"étages : %d, du premier (%.1f) au dernier (%.1f)",
		#etages,
		if #etages > 0 then etages[1].boite.haut else 0,
		if #etages > 0 then etages[#etages].boite.haut else 0
	)
)

---------------------------------------------------------------------------------------------------------------
-- Pièces mortelles à portée d'un saut : même règle que outils/monde/verifier-sauts.luau. Ici, l'ascension n'a
-- aucune pièce mortelle (la chute est détectée par le « Mortel » de la ville) : toute occurrence est un défaut.
local proches = 0
for _, m in mortels do
	for _, p in plateformes do
		if m.bas < p.haut + 5 and m.haut >= p.haut and vide(p, m) < 1.5 and m.haut > p.haut then
			proches += 1
			defaut(string.format("%s (mortel) à %.1f stud de %s", m.nom, vide(p, m), p.nom))
			break
		end
	end
end
print(`pièces mortelles : {#mortels} (dont {proches} à portée d'un saut)`)

---------------------------------------------------------------------------------------------------------------
-- Plafonds trop bas : une pièce solide à moins de 5,5 studs au-dessus d'une plateforme, sur la même emprise.
-- Trois passes : dans l'ascension, le tuto au-dessus de l'ascension (l'accès traverse le toit de la fac) et
-- l'ascension au-dessus du tuto (le pied et son accès flottent au-dessus de la salle de partiel et de l'atrium).
local function plafondsBas(dessous: { Plateforme }, dessus: { Plateforme }, quoi: string): number
	local n = 0
	for _, p in dessous do
		for _, s in dessus do
			if s.part == p.part then
				continue
			end
			local chevauche = math.min(p.x2, s.x2) - math.max(p.x1, s.x1) > 0.5
				and math.min(p.z2, s.z2) - math.max(p.z1, s.z1) > 0.5
			if chevauche and s.bas > p.haut + 0.01 and s.bas < p.haut + HAUTEUR_LIBRE then
				n += 1
				defaut(
					string.format(
						"plafond bas (%s) : %s (haut %.1f) sous %s (à %.1f)",
						quoi,
						p.nom,
						p.haut,
						s.nom,
						s.bas - p.haut
					)
				)
			end
		end
	end
	return n
end
local avecSalleEtPied = table.clone(plateformes)
table.insert(avecSalleEtPied, salle)
local bas = plafondsBas(plateformes, solides, "ascension")
	+ plafondsBas(avecSalleEtPied, solidesParcours, "tuto au-dessus de l'ascension")
	+ plafondsBas(plateformesParcours, solides, "ascension au-dessus du tuto")
print(`plafonds trop bas : {bas}`)

-- Emprise horizontale de tout ce qui est marchable, pour information (l'axe de l'ascension est en 845, 0).
local ex1, ex2, ez1, ez2 = math.huge, -math.huge, math.huge, -math.huge
for _, p in plateformes do
	ex1, ex2, ez1, ez2 = math.min(ex1, p.x1), math.max(ex2, p.x2), math.min(ez1, p.z1), math.max(ez2, p.z2)
end
print(string.format("emprise des plateformes : x %.0f..%.0f, z %.0f..%.0f", ex1, ex2, ez1, ez2))

---------------------------------------------------------------------------------------------------------------
-- Textes des SurfaceGui : jamais TextScaled, taille fixe de 12 à 100 px, à la ligne, et qui tient dans son label.
-- La règle de taille est le bloc TEXTE_PUR de Parcours.luau, qui doit être identique dans Ascension.luau.
local function blocTextePur(fichier: string): string
	local source = fs.readFile(fichier):gsub("\r\n", "\n")
	local debut = source:find("-- DEBUT TEXTE_PUR\n", 1, true)
	local fin = source:find("\t-- FIN TEXTE_PUR", 1, true)
	assert(debut and fin and fin > debut, `{fichier} : bloc TEXTE_PUR absent`)
	return source:sub(debut, fin - 1)
end
local blocParcours = blocTextePur("outils/monde/Parcours.luau")
if blocParcours ~= blocTextePur("outils/monde/Ascension.luau") then
	defaut("le bloc TEXTE_PUR de Parcours.luau et celui d'Ascension.luau ne sont plus identiques")
end
local ajusterTexte, METRIQUES, TAILLE_MIN, TAILLE_MAX =
	luau.load(blocParcours .. "\nreturn ajusterTexte, METRIQUES, TAILLE_MIN, TAILLE_MAX", { debugName = "TEXTE_PUR" })()

-- Pire cas écrit par src/serveur/Classement.luau dans le TextLabel « Liste » des tableaux.
local lignesClassement = {}
for rang = 1, 10 do
	table.insert(lignesClassement, string.format("%2d. %-14s %s", rang, string.rep("W", 14), "12 345 678"))
end
local listeClassement = table.concat(lignesClassement, "\n")

-- Lune ne lit pas la propriété Font d'un .rbxm mais lit FontFace : on retrouve le nom de police de la règle.
local function policeDe(label): string
	local face = label.FontFace
	if string.find(face.Family, "Inconsolata", 1, true) then
		return "Code"
	end
	local graisse = face.Weight.Name
	if graisse == "Heavy" or graisse == "ExtraBold" then
		return "GothamBlack"
	elseif graisse == "Bold" or graisse == "SemiBold" then
		return "GothamBold"
	end
	return "Gotham"
end

local nbTextes = 0
for _, gui in modele:GetDescendants() do
	if not (gui:IsA("SurfaceGui") and gui.Parent and gui.Parent:IsA("BasePart")) then
		continue
	end
	if gui.SizingMode ~= roblox.Enum.SurfaceGuiSizingMode.PixelsPerStud then
		defaut(`{gui:GetFullName()} n'est pas en PixelsPerStud`)
	end
	local s = gui.Parent.Size
	local l, h = s.X, s.Y
	local face = gui.Face.Name
	if face == "Left" or face == "Right" then
		l, h = s.Z, s.Y
	elseif face == "Top" or face == "Bottom" then
		l, h = s.X, s.Z
	end
	for _, label in gui:GetDescendants() do
		if not label:IsA("TextLabel") then
			continue
		end
		nbTextes += 1
		local nom = label:GetFullName()
		if label.TextScaled then
			defaut(`{nom} : TextScaled (taille de texte fixe obligatoire sur une SurfaceGui)`)
		end
		if label.TextSize < TAILLE_MIN or label.TextSize > TAILLE_MAX then
			defaut(`{nom} : TextSize {label.TextSize} hors de {TAILLE_MIN} à {TAILLE_MAX}`)
		end
		if not label.TextWrapped or label.RichText then
			defaut(`{nom} : TextWrapped faux ou RichText vrai`)
		end
		local toileL, toileH = l * gui.PixelsPerStud, h * gui.PixelsPerStud
		local w = label.Size.X.Scale * toileL + label.Size.X.Offset
		local hauteur = label.Size.Y.Scale * toileH + label.Size.Y.Offset
		local contenu = if label.Name == "Liste" then listeClassement else label.Text
		local police = policeDe(label)
		local taille, lignes = ajusterTexte(contenu, police, w, hauteur, label.TextSize)
		if taille < label.TextSize then
			defaut(
				`{nom} : TextSize {label.TextSize} trop grand, « {contenu:sub(1, 40)} » ne tient pas ({taille} au plus)`
			)
		end
		local m = METRIQUES[police] or METRIQUES.GothamBold
		print(
			string.format(
				"  %s face %.1fx%.1f st %.0f px/st | %d lignes, TextSize %d, %d %% de la hauteur | « %s »",
				gui.Parent.Name,
				l,
				h,
				gui.PixelsPerStud,
				lignes,
				label.TextSize,
				math.floor(100 * lignes * m[6] * label.TextSize / toileH + 0.5),
				(contenu:gsub("\n", " / ")):sub(1, 40)
			)
		)
	end
end
print(`textes de SurfaceGui : {nbTextes}`)
assert(nbTextes > 0, "aucun TextLabel de SurfaceGui trouvé")

---------------------------------------------------------------------------------------------------------------
print(`\ndéfauts : {defauts}`)
if defauts > 0 then
	process.exit(1)
end
