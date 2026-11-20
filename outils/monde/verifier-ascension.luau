-- Usage : lune run outils/monde/verifier-ascension.luau [ascension.rbxm] [parcours.rbxm] (défauts
-- monde/Ascension.rbxm et monde/Parcours.rbxm ; après lune run outils/monde/generer.luau).
--
-- Contrôle l'ascension construite par outils/monde/Ascension.luau :
-- - un chemin existe du « PiedAscension » au « SommetAscension » en ne franchissant que des sauts possibles avec les
--   trois capacités (course, double saut, dash) : montée d'au plus 9 studs, vide d'au plus 16 studs à plat, les deux
--   étant liés (plus on monte, moins on avance) ; le sommet est à au moins 250 studs au-dessus du pied ;
-- - **aucun chemin n'existe sans le dash, ni sans le double saut, ni sans la course** : on rejoue la recherche de
--   chemin en retirant chaque capacité et on exige qu'elle échoue (même technique que la « porte sans effet » de
--   outils/monde/verifier-sauts.luau). C'est ce contrôle qui garantit que la tour exige les trois capacités du pied
--   au sommet ; sans lui, rien n'empêche un tracé qui se franchit au saut simple ;
-- - les six familles d'obstacles (« PiegeMur », « Laser », « Effondrable », « Balancier », « Mobile », « Tournant »)
--   portent les attributs de leur contrat, et **chacune laisse au moins 1,2 s de passage libre par cycle** sur
--   chaque dalle qu'elle menace (simulation sur 120 s, méthode de outils/monde/verifier-evenements.luau) ; aucun
--   obstacle ne couvre à lui seul tout le volume où se tient le personnage, et aucun ne traverse une dalle ;
-- - **aucune pièce taguée « Palier »** : le système de paliers est supprimé (spec 2026-11-18-tour-exigeante) ;
-- - le pied est atteignable depuis la salle de partiel : un chemin existe de la dalle du checkpoint 15 (cherchée
--   dans Parcours.rbxm, elle n'est pas dans ce .rbxm) au pied, en 4 sauts au plus, dont le premier pose sur la dalle
--   marquée « DepartAcces » (l'accès passe par la verrière du toit) et dont aucun ne dépasse 75 % des limites de
--   saut : l'accès est une transition, pas une épreuve ;
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

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

-- Physique réelle du moteur : elle ne sert ici qu'à prouver qu'on n'entre dans la tour que par la salle de
-- partiel (voir « On n'entre dans la tour qu'en ayant fini le tuto »). Les règles de saut ci-dessous restent le
-- modèle prudent, qui décide de la difficulté du tracé.
local Physique = require("./physique")

-- Horaires du jeu (src/partage/Horaires.luau) : la sinusoïde des balanciers. Même chargement que
-- outils/monde/verifier-evenements.luau, avec la formule recopiée si le module n'est pas sur cette branche.
local Horaires
if fs.isFile("src/partage/Horaires.luau") then
	Horaires = luau.load(fs.readFile("src/partage/Horaires.luau"), { debugName = "Horaires" })()
else
	Horaires = {
		angleBalancier = function(t, amplitude, periode, decalage)
			return amplitude * math.sin(2 * math.pi * (t - decalage) / periode)
		end,
	}
end

-- Marges de contact du client : lues dans les réglages du jeu, jamais recopiées.
assert(
	fs.isFile("src/partage/Reglages.luau"),
	"src/partage/Reglages.luau introuvable (lancer depuis la racine du dépôt)"
)
local Reglages = luau.load(fs.readFile("src/partage/Reglages.luau"), { debugName = "Reglages" })()

local chemin = process.args[1] or "monde/Ascension.rbxm"
local modele = roblox.deserializeModel(fs.readFile(chemin))[1]

local defauts = 0
local function defaut(message: string)
	defauts += 1
	print("  DÉFAUT : " .. message)
end

---------------------------------------------------------------------------------------------------------------
-- Règle de saut, capacité par capacité. Repères (personnage Roblox par défaut, WalkSpeed 16, JumpPower 50) : saut
-- debout 6,5 studs de vide et 4,5 de montée ; en courant (× 1,5) 9,75 de vide ; double saut 9 studs de montée en
-- tout ; dash 8 studs de vide en plus (borne basse de la fourchette 8 à 12 de la spec). Le vide à plat est plafonné
-- à 16 studs. Plus on monte, moins on avance : on perd la même part (10/16) du vide tenable quand on va au bout de
-- la montée possible. Avec les trois capacités, cela redonne exactement la formule d'outils/monde/Ascension.luau :
-- videTenable(montee) = 16 − 10 × montee / 9 ; une descente aide un peu (jusqu'à 4 studs de vide en plus).
-- Toutes ces valeurs sont lues dans src/partage/Reglages.luau (COURSE_FACTEUR et le bloc CONTROLE_*), le masque
-- des capacités dans outils/monde/physique.luau : rien n'est recopié ici.
local CAPACITES = Physique.CAPACITES
local ORDRE = Physique.ORDRE
local TOUTES = Physique.TOUTES
local MONTEE_SIMPLE, MONTEE_DOUBLE = Reglages.CONTROLE_MONTEE, Reglages.CONTROLE_MONTEE_DOUBLE
local VIDE_DEBOUT, COURSE_FACTEUR, DASH_VIDE =
	Reglages.CONTROLE_VIDE, Reglages.COURSE_FACTEUR, Reglages.CONTROLE_DASH_VIDE
local VIDE_MAX, HAUTEUR_LIBRE = Reglages.CONTROLE_ASCENSION_VIDE_MAX, Reglages.CONTROLE_HAUTEUR_LIBRE
local PERTE = Reglages.CONTROLE_ASCENSION_PERTE -- part du vide tenable perdue quand on monte au maximum
local BONUS_DESCENTE, DESCENTE_PAS = Reglages.CONTROLE_ASCENSION_BONUS_DESCENTE, Reglages.CONTROLE_DESCENTE_PAS

local function aCapacite(caps: number, nom: string): boolean
	return bit32.band(caps, CAPACITES[nom]) ~= 0
end

local function monteeMaxAvec(caps: number): number
	return if aCapacite(caps, "doubleSaut") then MONTEE_DOUBLE else MONTEE_SIMPLE
end

local function videPlatAvec(caps: number): number
	local v = VIDE_DEBOUT * (if aCapacite(caps, "course") then COURSE_FACTEUR else 1)
	if aCapacite(caps, "dash") then
		v += DASH_VIDE
	end
	return math.min(VIDE_MAX, v)
end

local function videTenableAvec(montee: number, caps: number): number
	local v = videPlatAvec(caps) * (1 - PERTE * math.max(0, montee) / monteeMaxAvec(caps))
	if montee < 0 then
		v += math.min(BONUS_DESCENTE, -montee / DESCENTE_PAS)
	end
	return v
end

-- La règle complète (les trois capacités), celle qu'applique outils/monde/Ascension.luau.
local function videTenable(montee: number): number
	return videTenableAvec(montee, TOUTES)
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

-- Boîtes alignées (AABB) et orientées (OBB, test des axes séparateurs) : reprises de
-- outils/monde/verifier-evenements.luau, pour mesurer ce que les obstacles occupent en bougeant.
type Boite = { min: any, max: any }

local function aabbDePiece(cf, taille): Boite
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local h = taille / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local q = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				mn, mx = mn:Min(q), mx:Max(q)
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

-- Vrai si `petite` est entièrement dans `grande` : l'obstacle couvre tout, il ne reste pas où se mettre.
local function aabbContient(grande: Boite, petite: Boite): boolean
	return grande.min.X <= petite.min.X
		and grande.min.Y <= petite.min.Y
		and grande.min.Z <= petite.min.Z
		and grande.max.X >= petite.max.X
		and grande.max.Y >= petite.max.Y
		and grande.max.Z >= petite.max.Z
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

local plateformes: { Plateforme } = {}
local solides: { Plateforme } = {}
local mortels: { Plateforme } = {}
local etages = {}
local obstacles: { [string]: { any } } =
	{ Laser = {}, Tournant = {}, Balancier = {}, PiegeMur = {}, Mobile = {}, Effondrable = {} }
local FAMILLES_PIECE = { "Laser", "Tournant", "Balancier", "Mobile", "Effondrable" }
-- Les obstacles solides (barre tournante, pancarte qui bascule) poussent, mais on ne s'y tient pas : ils ne sont ni
-- des plateformes (ils ne sont pas horizontaux) ni des pièces solides au sens du plafond bas (ils bougent).
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
	local estObstacle = d:HasTag("Tournant") or d:HasTag("Balancier")
	for _, famille in FAMILLES_PIECE do
		if d:HasTag(famille) then
			table.insert(obstacles[famille], d)
		end
	end
	-- Une plateforme mobile est atteignable sur toute sa course : son emprise est l'union des deux bouts. Le
	-- contrôle dédié (plus bas) vérifie que le saut qui y arrive et celui qui en part restent possibles assez
	-- longtemps par cycle ; ici, on veut seulement qu'elle ne coupe pas le chemin.
	if d:HasTag("Mobile") then
		local dep = d:GetAttribute("Deplacement")
		if typeof(dep) == "Vector3" then
			boite.x1, boite.x2 = math.min(boite.x1, boite.x1 + dep.X), math.max(boite.x2, boite.x2 + dep.X)
			boite.z1, boite.z2 = math.min(boite.z1, boite.z1 + dep.Z), math.max(boite.z2, boite.z2 + dep.Z)
		end
	end
	if d.CanCollide and d.Transparency < 1 and not estObstacle then
		table.insert(solides, boite)
	end
	local marchable = d.CanCollide and d.CanQuery and not d:HasTag("Mortel") and d.Transparency < 1 and not estObstacle
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
	elseif d:HasTag("PiedAscension") or d:HasTag("SommetAscension") then
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

for _, m in modele:GetDescendants() do
	if m:HasTag("PiegeMur") then
		table.insert(obstacles.PiegeMur, m)
	end
	if m:HasTag("Palier") then
		defaut(`{m:GetFullName()} : tag « Palier » (le système de paliers est supprimé)`)
	end
	if m.Name == "Boutique" then
		defaut(`{m:GetFullName()} : reste de la boutique des paliers (elle ira au pied de l'ascension)`)
	end
end

print(`{chemin} : {pieces} pièces, {#plateformes} plateformes, {#etages} étages`)

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
	if d:HasTag("Checkpoint") and d:GetAttribute("Numero") == Reglages.NB_ETAPES then
		salle = boite
	end
end
assert(
	salle,
	`aucune dalle taguée Checkpoint de Numero {Reglages.NB_ETAPES} (NB_ETAPES) dans {cheminParcours} (la salle de partiel)`
)
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

local function sautPossible(a: Plateforme, b: Plateforme, caps: number): boolean
	local montee = b.haut - a.haut
	if montee > monteeMaxAvec(caps) then
		return false
	end
	return vide(a, b) <= videTenableAvec(montee, caps)
end

-- Difficulté d'un saut pour un joueur qui a `caps` : la plus grande des deux parts prises aux limites (montée sur
-- la montée possible, vide sur le vide tenable). 1 = tout juste possible, math.huge = impossible.
local function difficulte(a: Plateforme, b: Plateforme, caps: number?): number
	local avec = caps or TOUTES
	local montee = b.haut - a.haut
	if montee > monteeMaxAvec(avec) then
		return math.huge
	end
	local v, tenable = vide(a, b), videTenableAvec(montee, avec)
	if v > tenable then
		return math.huge
	end
	return math.max(montee / monteeMaxAvec(avec), v / math.max(tenable, 0.001))
end

-- Chemin dont le saut le plus dur est le plus facile possible (goulot minimal) : c'est celui-là qu'on annonce, parce
-- qu'un chemin facile qui existe compte plus qu'un raccourci acrobatique. Rend, par plateforme, la difficulté du
-- goulot pour y arriver et le prédécesseur de ce chemin.
local function goulot(noeuds: { Plateforme }, source: Plateforme, caps: number?)
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
			local w = math.max(d, difficulte(a, b, caps))
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

local meilleur, via = goulot(plateformes, pied, TOUTES)
local suiteSommet: { Plateforme } = {} -- le chemin retenu du pied au sommet (vide s'il n'y en a pas)
if not meilleur[sommet] or meilleur[sommet] == math.huge then
	defaut("aucun chemin du PiedAscension au SommetAscension avec les trois capacités")
else
	local suite = remonter(via, pied, sommet)
	suiteSommet = suite
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

---------------------------------------------------------------------------------------------------------------
-- Les trois capacités sont-elles indispensables ? On rejoue la recherche de chemin en retirant chaque capacité et
-- on exige qu'elle échoue : si le sommet reste atteignable sans le dash, sans le double saut ou sans la course,
-- c'est que la tour se franchit sans elle, et la demande de l'utilisateur n'est pas tenue. Même technique que la
-- « porte sans effet » de outils/monde/verifier-sauts.luau, mais sur un chemin entier au lieu d'un passage.
-- Le graphe est volontairement optimiste (les plateformes mobiles y comptent sur toute leur course) : une
-- impossibilité constatée dessus est d'autant plus sûre.
print("\n== Capacités indispensables ==")
print(
	string.format(
		"avec les trois : vide tenable à plat %.2f, montée %.1f ; sommet à %.0f studs du pied",
		videTenableAvec(0, TOUTES),
		monteeMaxAvec(TOUTES),
		sommet.haut - pied.haut
	)
)
for _, nom in ORDRE do
	local sans = bit32.band(TOUTES, bit32.bnot(CAPACITES[nom]))
	local atteint = goulot(plateformes, pied, sans)
	local plafond = pied.haut
	for p, d in atteint do
		if d ~= math.huge and p.haut > plafond then
			plafond = p.haut
		end
	end
	local accessible = (atteint[sommet] or math.huge) ~= math.huge
	print(
		string.format(
			"  sans %s : vide tenable à plat %.2f, montée %.1f ; on ne dépasse pas %.1f studs au-dessus du pied%s",
			nom,
			videTenableAvec(0, sans),
			monteeMaxAvec(sans),
			plafond - pied.haut,
			if accessible then " — ET LE SOMMET EST ATTEINT" else ""
		)
	)
	if accessible then
		defaut(`un chemin du pied au sommet existe sans {nom} : la tour ne l'exige pas`)
	end
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
local meilleurAcces, viaAcces = goulot(avecSalle, salle, TOUTES)
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
-- On n'entre dans la tour qu'en ayant fini le tuto (révision du 2026-11-19).
--
-- Les portes de la tour (les sauts « course », « dash » et « double » d'outils/monde/Ascension.luau, vérifiées
-- plus haut) sont un critère de **difficulté** : elles disent que le tracé ne se franchit pas confortablement
-- sans les trois capacités. Elles ne prouvent rien sur un joueur réel, qui arrive ici avec les trois en main.
-- Ce qui garantit qu'il les a, c'est le tuto : outils/monde/verifier-sauts.luau montre qu'en physique réelle le
-- checkpoint 15 (la salle de partiel) est hors d'atteinte sans la course, sans le dash et sans le double saut.
--
-- Reste à fermer la porte d'entrée : toute route vers la tour finit par un saut d'une plateforme du tuto vers une
-- plateforme de l'ascension. On exige donc que les seules plateformes du tuto d'où ce saut est possible — en
-- portée réelle, toutes capacités comprises et marge de bord offerte — soient le haut de l'atrium de Sup de
-- Vinci : à moins de ATRIUM_RAYON studs de la salle de partiel et au plus une volée en dessous d'elle. Cette
-- dernière volée fait 8 studs, plus qu'un saut simple (7,2) : on n'y arrive pas sans le double saut, et on n'y
-- arrive pas non plus sans la course ni sans le dash (le reste du tuto le prouve). Tout le reste de la ville est
-- donc trop loin ou trop bas pour entrer dans la tour. C'est pour cela que la tour n'a pas à durcir ses sauts.
local ATRIUM_RAYON, ATRIUM_VOLEE = 25, 8
do
	local fuites = 0
	for _, p in plateformesParcours do
		if p.haut >= salle.haut - ATRIUM_VOLEE and vide(p, salle) <= ATRIUM_RAYON then
			continue -- la salle de partiel et la dernière volée de l'atrium, derrière le double saut
		end
		for _, q in plateformes do
			if Physique.franchissable(vide(p, q), q.haut - p.haut, Physique.TOUTES) then
				fuites += 1
				if fuites <= 5 then
					print(
						string.format(
							"  entrée dérobée : %s (haut %.1f) -> %s (haut %.1f), vide %.2f, montée %+.1f",
							p.nom,
							p.haut,
							q.nom,
							q.haut,
							vide(p, q),
							q.haut - p.haut
						)
					)
				end
			end
		end
	end
	if fuites > 0 then
		defaut(`{fuites} saut(s) mènent du tuto à l'ascension depuis ailleurs que le haut de l'atrium`)
	else
		print("entrée de la tour : on n'y saute que depuis la salle de partiel et le haut de l'atrium")
	end
end

---------------------------------------------------------------------------------------------------------------
-- Les six familles d'obstacles.
--
-- Chaque obstacle qui bouge est ramené à un cycle et à la pose (CFrame + taille) qu'il occupe à l'instant t :
-- - Laser : va-et-vient régulier de « Depart » à « Arrivee » sur « Periode », calé sur « Decalage » (même principe
--   d'horaire que src/partage/Horaires.luau). On le prend à vitesse constante : c'est le cas le plus défavorable
--   pour la fenêtre, puisque c'est celui qui s'attarde le moins aux deux bouts ;
-- - Tournant : un tour complet en 2π / « Vitesse » autour de la verticale de son centre ;
-- - Balancier : la sinusoïde de src/partage/Horaires.luau, d'amplitude « Amplitude » autour de « Pivot » ;
-- - PiegeMur : le cycle de src/partage/Pieges.luau (`phasePiege`) — la pointe sort en « DureeSortie », rentre en
--   « DureeRentree » (elle frappe pendant les deux, cf. src/serveur/Obstacles.luau), puis reste rentrée « Repos »
--   secondes : c'est ça, la fenêtre de passage. On suppose le pire : un joueur qui reste dans la portée, donc un
--   déclenchement dès la fin du repos, donc le cycle qui se répète.
-- Pour chaque dalle qu'un obstacle peut toucher (sa boîte balayée, élargie des marges de contact du client,
-- rencontre le volume où se trouve le centre d'un personnage debout dessus), on simule 120 s et on exige, dans
-- toute tranche d'une période plus 2 s, une fenêtre libre d'au moins 1,2 s — la méthode de
-- outils/monde/verifier-evenements.luau. On exige aussi qu'à aucun instant l'obstacle ne couvre tout ce volume
-- (sinon il barre la route à lui seul) et qu'il ne traverse aucune dalle du chemin.
--
-- Les plateformes mobiles et celles qui s'effondrent sont le chemin lui-même : elles ont leur propre contrôle.
print("\n== Obstacles ==")
local MARGE = Vector3.new(
	Reglages.EVENEMENT_MARGE_HORIZONTALE,
	Reglages.EVENEMENT_MARGE_VERTICALE,
	Reglages.EVENEMENT_MARGE_HORIZONTALE
)
local FENETRE_MIN, DUREE_SIMULEE, PAS_SIM = 1.2, 120, 0.02
-- Plafond de poussée d'un piège de mur (src/partage/Pieges.luau le rabote à cette valeur). Recopié si la branche
-- n'a pas encore le réglage, comme la formule des balanciers plus haut.
local POUSSEE_MAX = Reglages.PIEGE_POUSSEE_MAX or 65
-- Le nombre de tranches se lit sur la carte, jamais recopié : outils/monde/Ascension.luau nomme chaque dalle du
-- chemin « Pas<tranche>_<rang> » (nom déjà lu par casser-ascension.luau). Les tranches vont de 1 à N sans trou.
local NB_TRANCHES = 0
do
	local vues = {}
	for _, d in modele:GetDescendants() do
		local s = d:IsA("BasePart") and tonumber(d.Name:match("^Pas(%d+)_%d+$"))
		if s then
			vues[s] = true
			NB_TRANCHES = math.max(NB_TRANCHES, s)
		end
	end
	if NB_TRANCHES == 0 then
		defaut("aucune dalle « Pas<tranche>_<rang> » : nombre de tranches inconnu")
		NB_TRANCHES = 1
	end
	for k = 1, NB_TRANCHES do
		if not vues[k] then
			defaut(`tranche {k} : aucune dalle « Pas{k}_<rang> » (tranches numérotées 1..{NB_TRANCHES} sans trou)`)
		end
	end
	print(`tranches (lues sur la carte) : {NB_TRANCHES}`)
end

local function nombre(v): boolean
	return typeof(v) == "number" and v == v and math.abs(v) ~= math.huge
end

local function volumeDuCentre(p: Plateforme): Boite
	return { min = Vector3.new(p.x1, p.haut + 2.5, p.z1), max = Vector3.new(p.x2, p.haut + 3.5, p.z2) }
end

local function boiteDePlateforme(p: Plateforme): Boite
	return { min = Vector3.new(p.x1, p.bas, p.z1), max = Vector3.new(p.x2, p.haut, p.z2) }
end

local boiteDe: { [any]: Plateforme } = {}
for _, p in plateformes do
	boiteDe[p.part] = p
end

type Mouvant = { nom: string, famille: string, periode: number, hauteur: number, poseA: (number) -> (any, any) }
local mouvants: { Mouvant } = {}
local parFamille: { [string]: number } =
	{ Laser = 0, Tournant = 0, Balancier = 0, PiegeMur = 0, Mobile = 0, Effondrable = 0 }
local parTranche = table.create(NB_TRANCHES, 0)
local function compter(famille: string, hauteur: number)
	parFamille[famille] += 1
	local k =
		math.clamp(math.floor((hauteur - pied.haut) / ((sommet.haut - pied.haut) / NB_TRANCHES)) + 1, 1, NB_TRANCHES)
	parTranche[k] += 1
end

---------------------------------------------------------------------------------------------------------------
-- Lasers : barres qui balaient et tuent au contact.
for _, l in obstacles.Laser do
	local nom = l:GetFullName()
	local depart, arrivee = l:GetAttribute("Depart"), l:GetAttribute("Arrivee")
	local periode, decalage = l:GetAttribute("Periode"), l:GetAttribute("Decalage")
	compter("Laser", l.CFrame.Position.Y)
	if
		typeof(depart) ~= "Vector3"
		or typeof(arrivee) ~= "Vector3"
		or not nombre(periode)
		or not nombre(decalage)
		or periode <= 0
	then
		defaut(`{nom} : attributs Depart / Arrivee / Periode / Decalage absents ou invalides`)
		continue
	end
	if l.CanCollide then
		defaut(`{nom} : un laser ne porte pas, il tue : il ne doit pas avoir de collision`)
	end
	if not l.CanTouch then
		defaut(`{nom} : un laser doit pouvoir être touché (CanTouch) pour tuer`)
	end
	if (l.CFrame.Position - depart).Magnitude > 0.05 then
		defaut(`{nom} : la pièce n'est pas posée sur son attribut Depart`)
	end
	if (arrivee - depart).Magnitude < 4 then
		defaut(string.format("%s : course de %.1f stud (4 au moins attendus)", nom, (arrivee - depart).Magnitude))
	end
	local cf0, taille = l.CFrame, l.Size
	table.insert(mouvants, {
		nom = nom,
		famille = "Laser",
		periode = periode,
		hauteur = cf0.Position.Y,
		poseA = function(t)
			local phase = (t - decalage) % periode
			local k = if phase < periode / 2 then 2 * phase / periode else 2 - 2 * phase / periode
			return CFrame.new((arrivee - depart) * k) * cf0, taille
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
-- Barres tournantes : plus rapides que celles du tuto (1,6 rad/s).
for _, b in obstacles.Tournant do
	local nom = b:GetFullName()
	local vitesse = b:GetAttribute("Vitesse")
	compter("Tournant", b.CFrame.Position.Y)
	if not nombre(vitesse) or math.abs(vitesse) < 0.1 then
		defaut(`{nom} : attribut Vitesse absent ou invalide`)
		continue
	end
	if math.abs(vitesse) <= 1.6 then
		defaut(
			string.format("%s : %.2f rad/s, pas plus rapide que le tuto (1,6 rad/s attendus au minimum)", nom, vitesse)
		)
	end
	if b.CanQuery then
		defaut(`{nom} : une barre tournante ne se tient pas (CanQuery doit être faux, comme dans le tuto)`)
	end
	if not b.CanCollide then
		defaut(`{nom} : une barre tournante pousse : elle doit être solide`)
	end
	local cf0, taille = b.CFrame, b.Size
	local autour = CFrame.new(cf0.Position)
	table.insert(mouvants, {
		nom = nom,
		famille = "Tournant",
		periode = 2 * math.pi / math.abs(vitesse),
		hauteur = cf0.Position.Y,
		poseA = function(t)
			return autour * CFrame.Angles(0, vitesse * t, 0) * autour:Inverse() * cf0, taille
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
-- Pancartes qui basculent (balanciers) : elles poussent fort, elles ne tuent pas.
for _, b in obstacles.Balancier do
	local nom = b:GetFullName()
	local pivot, axe = b:GetAttribute("Pivot"), b:GetAttribute("Axe")
	local amplitude, periode, decalage =
		b:GetAttribute("Amplitude"), b:GetAttribute("Periode"), b:GetAttribute("Decalage")
	local poussee = b:GetAttribute("Poussee")
	compter("Balancier", b.CFrame.Position.Y)
	if
		typeof(pivot) ~= "Vector3"
		or typeof(axe) ~= "Vector3"
		or not nombre(amplitude)
		or not nombre(periode)
		or not nombre(decalage)
		or amplitude <= 0
		or amplitude > 180
		or periode <= 0
	then
		defaut(`{nom} : attributs Pivot / Axe / Amplitude / Periode / Decalage absents ou invalides`)
		continue
	end
	if math.abs(axe.Magnitude - 1) > 0.01 then
		defaut(`{nom} : Axe non unitaire`)
	end
	if not nombre(poussee) or poussee <= 0 then
		defaut(`{nom} : attribut Poussee absent ou invalide (les pancartes projettent)`)
	end
	if not b.Anchored or not b.CanCollide then
		defaut(`{nom} : doit être ancrée et solide (le serveur la libère et la fait osciller)`)
	end
	local cf0, taille = b.CFrame, b.Size
	local autour = CFrame.new(pivot)
	table.insert(mouvants, {
		nom = nom,
		famille = "Balancier",
		periode = periode,
		hauteur = cf0.Position.Y,
		poseA = function(t)
			local angle = Horaires.angleBalancier(t, amplitude, periode, decalage)
			return autour * CFrame.fromAxisAngle(axe, math.rad(angle)) * autour:Inverse() * cf0, taille
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
-- Pièges de mur : la pointe sort d'un coup et pousse. Seul indice avant déclenchement : la fente et l'usure
-- (décision de l'utilisateur) — donc ni néon ni lumière dans le piège.
for _, m in obstacles.PiegeMur do
	local nom = m:GetFullName()
	local direction, distance = m:GetAttribute("Direction"), m:GetAttribute("Distance")
	local sortie, rentree = m:GetAttribute("DureeSortie"), m:GetAttribute("DureeRentree")
	local repos = m:GetAttribute("Repos")
	local portee, poussee = m:GetAttribute("Portee"), m:GetAttribute("Poussee")
	local pointe = m:FindFirstChild("Pointe")
	compter("PiegeMur", if pointe and pointe:IsA("BasePart") then pointe.CFrame.Position.Y else 0)
	if typeof(direction) ~= "Vector3" or math.abs(direction.Magnitude - 1) > 0.01 then
		defaut(`{nom} : attribut Direction absent ou non unitaire`)
		continue
	end
	for intitule, valeur in { Distance = distance, DureeSortie = sortie, DureeRentree = rentree, Portee = portee } do
		if not nombre(valeur) or valeur <= 0 then
			defaut(`{nom} : attribut {intitule} absent ou invalide`)
		end
	end
	-- « Repos » est la fenêtre de passage : la carte la pose, on ne laisse pas Reglages.PIEGE_REPOS décider en
	-- silence à sa place (un piège réglé trop serré passerait alors inaperçu).
	if not nombre(repos) or repos < FENETRE_MIN then
		defaut(
			`{nom} : attribut Repos {tostring(repos)} — c'est la fenêtre de passage, {FENETRE_MIN} s au moins attendues`
		)
	end
	-- La poussée ne doit jamais tuer : au-delà de PIEGE_POUSSEE_MAX (sous DASH_VITESSE), un dash lancé dans l'autre
	-- sens ne reprend plus la main (décision de l'utilisateur : les pièges poussent fort, ils ne tuent pas). Le
	-- serveur rabote silencieusement une valeur trop grande ; on la refuse ici, avant la partie. L'attribut est
	-- facultatif — mais on contrôle aussi la valeur par défaut du jeu, c'est elle qui s'applique alors.
	if poussee ~= nil and (not nombre(poussee) or poussee <= 0) then
		defaut(`{nom} : attribut Poussee présent mais invalide`)
	else
		local effective = if nombre(poussee) then poussee else Reglages.PIEGE_POUSSEE
		if effective > POUSSEE_MAX then
			defaut(
				string.format(
					"%s : poussée %.0f studs/s > %.0f (plafond du serveur, sous DASH_VITESSE %.0f) — le joueur ne "
						.. "pourrait plus se rattraper au dash, et le serveur raboterait la valeur en silence",
					nom,
					effective,
					POUSSEE_MAX,
					Reglages.DASH_VITESSE
				)
			)
		end
	end
	if not pointe or not pointe:IsA("BasePart") then
		defaut(`{nom} : pas d'enfant « Pointe » (BasePart)`)
		continue
	end
	if pointe.CanCollide then
		defaut(`{pointe:GetFullName()} : la pointe pousse par le code, elle ne doit pas avoir de collision`)
	end
	if not pointe.CanTouch then
		defaut(`{pointe:GetFullName()} : la pointe doit pouvoir être touchée (CanTouch) pour pousser`)
	end
	if not m:FindFirstChild("Fente") or not m:FindFirstChild("Usure") then
		defaut(`{nom} : il faut une « Fente » et une « Usure » — c'est le seul indice avant le déclenchement`)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material == roblox.Enum.Material.Neon then
			defaut(`{d:GetFullName()} : un piège de mur ne s'annonce ni par un néon ni par un voyant`)
		end
		if d:IsA("Light") or d:IsA("PointLight") or d:IsA("SpotLight") then
			defaut(`{d:GetFullName()} : un piège de mur ne s'annonce pas par une lumière`)
		end
	end
	if not nombre(distance) or not nombre(sortie) or not nombre(rentree) or not nombre(repos) then
		continue
	end
	local cf0, taille = pointe.CFrame, pointe.Size
	local periode = sortie + rentree + repos
	table.insert(mouvants, {
		nom = nom,
		famille = "PiegeMur",
		periode = periode,
		hauteur = cf0.Position.Y,
		-- `phasePiege` de src/partage/Pieges.luau : avancement 0 -> 1 pendant la sortie, 1 -> 0 pendant la rentrée,
		-- 0 pendant le repos. La pointe frappe tant qu'elle bouge, pas seulement une fois dehors.
		poseA = function(t)
			local e = t % periode
			local avancement
			if e < sortie then
				avancement = e / sortie
			elseif e < sortie + rentree then
				avancement = 1 - (e - sortie) / rentree
			else
				avancement = 0
			end
			return CFrame.new(direction * distance * avancement) * cf0, taille
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
-- Ce que chaque obstacle balaie, les dalles qu'il menace, et les dalles qu'il traverserait.
local parPlateforme: { [Plateforme]: { Mouvant } } = {}
for _, m in mouvants do
	local echantillons = math.max(24, math.ceil(m.periode / 0.05))
	local poses = table.create(echantillons + 1)
	local balaye: Boite? = nil
	for i = 0, echantillons do
		local cf, taille = m.poseA(i * m.periode / echantillons)
		poses[i + 1] = { cf = cf, taille = taille }
		balaye = union(balaye, aabbDePiece(cf, taille))
	end
	local enveloppe = balaye :: Boite
	local touche = elargir(enveloppe, MARGE)
	local menacees = {}
	for _, p in plateformes do
		if aabbSeCroisent(touche, volumeDuCentre(p)) then
			parPlateforme[p] = parPlateforme[p] or {}
			table.insert(parPlateforme[p], m)
			table.insert(menacees, p.nom:match("[^.]+$") or p.nom)
		end
	end
	if #menacees == 0 then
		defaut(`{m.nom} : ne menace aucune dalle du chemin (obstacle posé hors du chemin ?)`)
	end
	-- Aucun obstacle ne doit traverser une dalle : il la coincerait, ou passerait au travers.
	local voisines = {}
	for _, p in plateformes do
		local boite = boiteDePlateforme(p)
		if aabbSeCroisent(enveloppe, boite) then
			table.insert(voisines, { p = p, obb = obbDeBoite(boite) })
		end
	end
	local traversees = {}
	for _, pose in poses do
		local o = obb(pose.cf, pose.taille)
		for _, v in voisines do
			if not traversees[v.p.nom] and obbSeCroisent(o, v.obb, 0.05) then
				traversees[v.p.nom] = true
				defaut(`{m.nom} : traverse la dalle {v.p.nom} au cours de son cycle`)
			end
		end
	end
	print(
		string.format(
			"%s (%s) : période %.2f s, hauteur %.0f -> %s",
			m.nom:match("[^.]+$") or m.nom,
			m.famille,
			m.periode,
			m.hauteur,
			table.concat(menacees, ", ")
		)
	)
end

---------------------------------------------------------------------------------------------------------------
-- Fenêtre de passage garantie sur chaque dalle menacée.
print("\n-- Fenêtres de passage (simulation sur 120 s, pas de 0,02 s) --")
local menacees = {}
for p in parPlateforme do
	table.insert(menacees, p)
end
table.sort(menacees, function(a, b)
	return a.haut < b.haut
end)
for _, p in menacees do
	local liste = parPlateforme[p]
	local volume = obbDeBoite(elargir(volumeDuCentre(p), MARGE))
	local nu = volumeDuCentre(p)
	local pmax = 0
	for _, m in liste do
		pmax = math.max(pmax, m.periode)
	end
	local n = math.floor(DUREE_SIMULEE / PAS_SIM)
	local libres: { { number } } = {}
	local debut: number? = 0
	local couvertures = {}
	for i = 0, n do
		local t = i * PAS_SIM
		local danger = false
		for _, m in liste do
			local cf, taille = m.poseA(t)
			if obbSeCroisent(obb(cf, taille), volume, 0) then
				danger = true
				if not couvertures[m.nom] and aabbContient(aabbDePiece(cf, taille), nu) then
					couvertures[m.nom] = true
					defaut(`{m.nom} : à lui seul, il couvre toute la dalle {p.nom} (plus où se mettre)`)
				end
			end
		end
		if not danger and not debut then
			debut = t
		elseif danger and debut then
			table.insert(libres, { debut, t })
			debut = nil
		end
	end
	if debut then
		table.insert(libres, { debut, DUREE_SIMULEE })
	end
	-- Fenêtre garantie : la plus petite, sur toutes les tranches [t0, t0 + pmax + 2], de la plus longue fenêtre
	-- libre (coupée aux bords de la tranche).
	local tranche = pmax + 2
	local garantie = math.huge
	local t0 = 0
	while t0 + tranche <= DUREE_SIMULEE do
		local meilleure = 0
		for _, f in libres do
			meilleure = math.max(meilleure, math.min(f[2], t0 + tranche) - math.max(f[1], t0))
		end
		garantie = math.min(garantie, meilleure)
		t0 += 0.05
	end
	local noms = {}
	for _, m in liste do
		table.insert(noms, m.nom:match("[^.]+$") or m.nom)
	end
	print(
		string.format(
			"%s (haut %.0f) : %d obstacle(s) [%s], fenêtre libre garantie %.2f s",
			p.nom:match("[^.]+$") or p.nom,
			p.haut,
			#liste,
			table.concat(noms, ", "),
			garantie
		)
	)
	if garantie < FENETRE_MIN then
		defaut(string.format("%s : fenêtre de passage garantie %.2f s < %.1f s", p.nom, garantie, FENETRE_MIN))
	end
end

---------------------------------------------------------------------------------------------------------------
-- Plateformes mobiles : le saut qui y arrive et celui qui en part doivent rester possibles au moins 1,2 s par
-- cycle. On suit le chemin retenu du pied au sommet pour savoir d'où l'on vient et où l'on va. Le va-et-vient est
-- celui du jeu (src/serveur/Obstacles.luau : tween Sine InOut qui repart en arrière, donc une période de 2 × Duree
-- et une position en (1 − cos(π t / Duree)) / 2).
print("\n-- Plateformes mobiles --")
local rangDansChemin: { [Plateforme]: number } = {}
for i, p in suiteSommet do
	rangDansChemin[p] = i
end

local function plusLongueFenetre(possible: { boolean }, pas: number): number
	local n = #possible
	local plusLongue, courant = 0, 0
	for i = 1, 2 * n do -- deux tours : la fenêtre peut être à cheval sur la fin du cycle
		if possible[(i - 1) % n + 1] then
			courant += 1
			plusLongue = math.max(plusLongue, math.min(courant, n))
		else
			courant = 0
		end
	end
	return plusLongue * pas
end

for _, part in obstacles.Mobile do
	local nom = part:GetFullName()
	local deplacement, duree = part:GetAttribute("Deplacement"), part:GetAttribute("Duree")
	compter("Mobile", part.CFrame.Position.Y)
	if typeof(deplacement) ~= "Vector3" or not nombre(duree) or duree <= 0 then
		defaut(`{nom} : attributs Deplacement / Duree absents ou invalides`)
		continue
	end
	local boite = boiteDe[part]
	local rang = boite and rangDansChemin[boite]
	if not rang then
		defaut(`{nom} : plateforme mobile hors du chemin retenu du pied au sommet`)
		continue
	end
	local mn, mx = emprise(part)
	local function aLInstant(t): Plateforme
		local k = (1 - math.cos(math.pi * t / duree)) / 2
		local d = deplacement * k
		return {
			nom = nom,
			x1 = mn.X + d.X,
			x2 = mx.X + d.X,
			z1 = mn.Z + d.Z,
			z2 = mx.Z + d.Z,
			haut = mx.Y + d.Y,
			bas = mn.Y + d.Y,
		}
	end
	local pas = 0.02
	local n = math.floor(2 * duree / pas)
	local mesures = {}
	for _, cote in
		{
			{ suiteSommet[rang - 1], "le saut d'arrivée", true },
			{ suiteSommet[rang + 1], "le saut de départ", false },
		}
	do
		local voisine, intitule, versElle = cote[1], cote[2], cote[3]
		if not voisine then
			continue
		end
		local possible = table.create(n, false)
		for i = 1, n do
			local ici = aLInstant((i - 1) * pas)
			possible[i] = if versElle then sautPossible(voisine, ici, TOUTES) else sautPossible(ici, voisine, TOUTES)
		end
		local fenetre = plusLongueFenetre(possible, pas)
		table.insert(mesures, string.format("%s %.2f s", intitule, fenetre))
		if fenetre < FENETRE_MIN then
			defaut(
				string.format(
					"%s : %s (%s) n'est possible que %.2f s par cycle (%.1f s au moins attendues)",
					nom,
					intitule,
					voisine.nom:match("[^.]+$") or voisine.nom,
					fenetre,
					FENETRE_MIN
				)
			)
		end
	end
	-- Sur sa course, elle ne doit heurter aucune autre dalle.
	for i = 0, n do
		local ici = aLInstant(i * pas)
		for _, autre in plateformes do
			if autre.part ~= part and aabbSeCroisent(boiteDePlateforme(ici), boiteDePlateforme(autre), 0.1) then
				defaut(`{nom} : sa course la fait heurter {autre.nom}`)
				break
			end
		end
	end
	print(
		string.format(
			"%s : course %.1f stud, période %.1f s, fenêtres %s",
			nom:match("[^.]+$") or nom,
			deplacement.Magnitude,
			2 * duree,
			table.concat(mesures, " / ")
		)
	)
end

---------------------------------------------------------------------------------------------------------------
-- Plateformes qui s'effondrent : elles tombent 0,5 s après le premier contact et reviennent. Jamais deux de suite
-- sur le chemin (on resterait en l'air sans rien où se poser).
print("\n-- Plateformes qui s'effondrent --")
for _, part in obstacles.Effondrable do
	local nom = part:GetFullName()
	local chute, retour = part:GetAttribute("DelaiChute"), part:GetAttribute("DelaiRetour")
	compter("Effondrable", part.CFrame.Position.Y)
	if not nombre(chute) or chute < 0.5 or chute > 1 then
		defaut(`{nom} : DelaiChute {tostring(chute)} (0,5 s attendues, 1 s au plus)`)
	end
	if not nombre(retour) or retour < FENETRE_MIN or retour > 8 then
		defaut(`{nom} : DelaiRetour {tostring(retour)} s (de {FENETRE_MIN} à 8 s attendues : elle doit revenir)`)
	end
	if not boiteDe[part] then
		defaut(`{nom} : une plateforme qui s'effondre doit rester une plateforme du chemin`)
	end
	print(string.format("%s : chute %.2f s, retour %.1f s", nom:match("[^.]+$") or nom, chute or -1, retour or -1))
end
for i = 1, #suiteSommet - 1 do
	local a, b = suiteSommet[i].part, suiteSommet[i + 1].part
	if a and b and a:HasTag("Effondrable") and b:HasTag("Effondrable") then
		defaut(`{suiteSommet[i].nom} et {suiteSommet[i + 1].nom} : deux plateformes qui s'effondrent de suite`)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Les six familles sont présentes, et la densité monte avec l'altitude.
local resume = {}
for _, famille in { "PiegeMur", "Laser", "Effondrable", "Balancier", "Mobile", "Tournant" } do
	table.insert(resume, `{famille} {parFamille[famille]}`)
	if parFamille[famille] == 0 then
		defaut(`aucun obstacle de la famille « {famille} » dans la tour`)
	end
end
print(`\nobstacles : ` .. table.concat(resume, ", ") .. ` ; par tranche : ` .. table.concat(parTranche, ", "))
for k = 2, NB_TRANCHES do
	if parTranche[k] < parTranche[k - 1] then
		defaut(
			`tranche {k} : {parTranche[k]} obstacles contre {parTranche[k - 1]} dans la tranche {k - 1} (les obstacles doivent être de plus en plus denses en montant)`
		)
	end
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
