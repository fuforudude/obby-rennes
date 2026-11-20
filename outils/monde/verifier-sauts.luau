-- Usage : lune run outils/monde/verifier-sauts.luau [fichier.rbxm] (défaut monde/Parcours.rbxm ; après lune run outils/monde/generer.luau).
-- Vérifie le tracé : depuis le départ, peut-on atteindre chaque checkpoint en sautant de plateforme en plateforme ?
-- Saut possible si : montée <= 4,5 ; vide horizontal (entre bords) <= 6,5 (+ 1 par tranche de 4 de descente, au plus 2,5) ;
-- ces valeurs sont les CONTROLE_* de src/partage/Reglages.luau, lues au lancement.
--
-- Les capacités de déplacement (spec 2026-11-18) changent ces limites, mais seulement là où elles sont déjà
-- débloquées : une pièce taguée « DeblocageCapacite » porte l'attribut « Capacite » (« course », « doubleSaut » ou
-- « dash ») et la donne dès qu'on marche dessus. Le parcours en largeur transporte donc, avec chaque plateforme
-- atteinte, les capacités ramassées en chemin, et applique les limites correspondantes (voir `limites`). Deux
-- chemins qui arrivent sur la même plateforme avec des capacités différentes sont réunis : approximation sans
-- conséquence ici, les trois déblocages se suivent sur un chemin unique. Une carte qui vient après le tuto peut
-- déclarer ce que le joueur a forcément en main en y entrant : attribut « CapacitesAcquises » de la racine du
-- modèle, une liste séparée par des virgules (« course,doubleSaut,dash »).
--
-- Signale aussi les plafonds trop bas (moins de 5,5 studs au-dessus d'une plateforme, sur la même emprise),
-- les pièces mortelles collées à une plateforme de départ de saut (voir « mortels trop proches ») et les portes
-- d'apprentissage sans effet (une capacité dont le retrait ne rend aucun checkpoint inatteignable : le passage
-- censé l'enseigner se franchit sans elle, le joueur n'apprend rien) et les capacités qui ne servent qu'une fois
-- (après sa dalle, chaque capacité doit être exigée par au moins trois sauts : voir `exigences`).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Physique réelle du moteur (outils/monde/physique.luau) : elle ne sert qu'à la preuve de stricte nécessité des
-- portes, plus bas. Le modèle prudent ci-dessous reste la règle pour tout le reste.
local Physique = require("./physique")

local modele = roblox.deserializeModel(fs.readFile(process.args[1] or "monde/Parcours.rbxm"))[1]

-- Limites de saut du personnage par défaut (WalkSpeed 16, JumpPower 50) et ce que chaque capacité y ajoute.
-- Le temps en l'air ne dépend pas de la vitesse : courir allonge la portée horizontale du même facteur que la
-- vitesse. Le double saut, lui, sert à monter (la spec ne lui promet pas de portée en plus).
-- Valeurs lues dans src/partage/Reglages.luau (bloc CONTROLE_*), jamais recopiées ici.
local Reglages = Physique.Reglages
local MONTEE = Reglages.CONTROLE_MONTEE -- montée franchissable d'un saut debout
local VIDE = Reglages.CONTROLE_VIDE -- vide franchissable à plat, à l'arrêt
local BONUS_DESCENTE = Reglages.CONTROLE_BONUS_DESCENTE -- au plus ; 1 stud par CONTROLE_DESCENTE_PAS descendus
local DESCENTE_PAS = Reglages.CONTROLE_DESCENTE_PAS
local COURSE_FACTEUR = Reglages.COURSE_FACTEUR -- course : vitesse × COURSE_FACTEUR, donc vide × COURSE_FACTEUR
local DOUBLE_SAUT_MONTEE = Reglages.CONTROLE_MONTEE_DOUBLE -- double saut : montée totale des deux sauts
local DASH_VIDE = Reglages.CONTROLE_DASH_VIDE -- dash : studs de vide en plus
local HAUTEUR_LIBRE = Reglages.CONTROLE_HAUTEUR_LIBRE -- en dessous : plafond trop bas

local CAPACITES = Physique.CAPACITES
local ORDRE = Physique.ORDRE
local TOUTES = Physique.TOUTES
-- Un état (plateforme, capacités en main) se code en un seul nombre : plateforme × ETATS + capacités.
local ETATS = TOUTES + 1

type Plateforme = {
	nom: string,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	haut: number,
	bas: number?,
	cp: number?,
	donne: number?,
}
local plateformes: { Plateforme } = {}
local solides = {}
local mortels: { Plateforme } = {}
local defauts = 0

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
	local estZone = d.Parent and d.Parent.Name:match("^%d+_") ~= nil
	if not estZone then
		continue
	end
	if d:HasTag("Mortel") then
		local x1, x2, z1, z2 = emprise(d, 0, 0)
		table.insert(mortels, {
			nom = d.Parent.Name .. "/" .. d.Name,
			x1 = x1,
			x2 = x2,
			z1 = z1,
			z2 = z2,
			haut = d.CFrame.Position.Y + d.Size.Y / 2,
			bas = d.CFrame.Position.Y - d.Size.Y / 2,
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
		local donne = 0
		if d:HasTag("DeblocageCapacite") then
			local capacite = d:GetAttribute("Capacite")
			donne = CAPACITES[capacite] or 0
			if donne == 0 then
				print(`  DÉFAUT : {d.Parent.Name}/{d.Name} taguée DeblocageCapacite, Capacite = {tostring(capacite)}`)
				defauts += 1
			end
		end
		table.insert(plateformes, {
			nom = d.Parent.Name .. "/" .. d.Name,
			x1 = x1,
			x2 = x2,
			z1 = z1,
			z2 = z2,
			haut = haut,
			cp = n,
			donne = donne,
		})
	end
end

local function vide(a: Plateforme, b: Plateforme): number
	local gx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2))
	local gz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2))
	return math.sqrt(gx * gx + gz * gz)
end

-- Les limites de saut telles que les voit un joueur qui a déjà `capacites` (masque de bits de CAPACITES).
local function limites(capacites: number): (number, number)
	local montee = if bit32.band(capacites, CAPACITES.doubleSaut) ~= 0 then DOUBLE_SAUT_MONTEE else MONTEE
	local videMax = VIDE
	if bit32.band(capacites, CAPACITES.course) ~= 0 then
		videMax *= COURSE_FACTEUR
	end
	if bit32.band(capacites, CAPACITES.dash) ~= 0 then
		videMax += DASH_VIDE
	end
	return montee, videMax
end

-- `reel` : on juge en physique réelle (tout ce que le moteur permet) au lieu du modèle prudent. Réservé à la
-- preuve de stricte nécessité des portes ; partout ailleurs, c'est le modèle prudent qui décide.
local function sautPossible(a: Plateforme, b: Plateforme, capacites: number, reel: boolean?): boolean
	local montee = b.haut - a.haut
	if reel then
		return Physique.franchissable(vide(a, b), montee, capacites)
	end
	local monteeMax, videMax = limites(capacites)
	if montee > monteeMax then
		return false
	end
	local bonus = if montee < 0 then math.min(BONUS_DESCENTE, -montee / DESCENTE_PAS) else 0
	return vide(a, b) <= videMax + bonus
end

local depart
for i, p in plateformes do
	if p.cp == 0 then
		depart = i
	end
end
if not depart then
	print("DÉFAUT : aucune plateforme Checkpoint de Numero 0 (le départ) dans ce modèle")
	process.exit(1)
end

-- Capacités déjà acquises en arrivant sur ce modèle : l'attribut « CapacitesAcquises » de la racine, une liste
-- séparée par des virgules. Le parcours du tuto n'en met pas (on y débloque tout) ; une carte qui vient après lui,
-- comme l'ascension, y déclare ce que le joueur a forcément en main avant d'y entrer.
local acquises = 0
do
	local liste = modele:GetAttribute("CapacitesAcquises")
	if typeof(liste) == "string" then
		for nom in string.gmatch(liste, "[^,%s]+") do
			if CAPACITES[nom] then
				acquises = bit32.bor(acquises, CAPACITES[nom])
			else
				print(`DÉFAUT : CapacitesAcquises contient « {nom} », inconnue`)
				defauts += 1
			end
		end
		print(`capacités acquises avant cette carte : {liste}`)
	end
end

-- Parcours en largeur depuis le départ, en transportant les capacités ramassées en chemin. `privee` est le masque
-- des capacités que l'on refuse de donner : avec 0 on explore le parcours tel qu'il se joue, avec le masque d'une
-- capacité on vérifie que son passage d'apprentissage barre bien la route. Rend, par plateforme atteinte, les
-- capacités dont on y dispose, et par quelle plateforme on y est arrivé (pour afficher la route trouvée quand une
-- porte ne tient pas : c'est elle qu'il faut corriger).
local function explorer(privee: number, reel: boolean?): ({ [number]: number }, { [number]: number })
	local atteint: { [number]: number } = {}
	local venant: { [number]: number } = {}
	local file = {}
	local function pousser(i: number, capacites: number, depuis: number?)
		local avec = bit32.band(bit32.bor(capacites, plateformes[i].donne or 0), bit32.bnot(privee))
		local connu = atteint[i]
		if connu and bit32.band(avec, bit32.bnot(connu)) == 0 then
			return -- déjà vu, et sans capacité nouvelle à y apporter
		end
		if connu == nil and depuis then
			venant[i] = depuis
		end
		atteint[i] = bit32.bor(connu or 0, avec)
		table.insert(file, i)
	end
	pousser(depart, acquises)
	while #file > 0 do
		local i = table.remove(file, 1)
		local capacites = atteint[i]
		for j, q in plateformes do
			if sautPossible(plateformes[i], q, capacites, reel) then
				pousser(j, capacites, i)
			end
		end
	end
	return atteint, venant
end

-- Les numéros des checkpoints qu'on n'atteint pas, dans l'ordre.
local function inatteignables(atteint: { [number]: number }): { number }
	local manquants = {}
	for i, p in plateformes do
		if p.cp and not atteint[i] then
			table.insert(manquants, p.cp)
		end
	end
	table.sort(manquants)
	return manquants
end

local atteint = explorer(0)
local manquants = inatteignables(atteint)
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

-- Les capacités, leur dalle de déblocage et l'effet de leur passage d'apprentissage.
local posees = {}
for _, p in plateformes do
	if (p.donne or 0) ~= 0 then
		for _, nom in ORDRE do
			if p.donne == CAPACITES[nom] then
				if posees[nom] then
					print(`  DÉFAUT : capacité {nom} débloquée deux fois ({posees[nom]} et {p.nom})`)
					defauts += 1
				end
				posees[nom] = p.nom
			end
		end
	end
end
local montee0, vide0 = limites(0)
print(
	string.format(
		"limites de base : montée %.1f, vide %.1f (+%.1f au plus en descente)",
		montee0,
		vide0,
		BONUS_DESCENTE
	)
)
-- Combien de fois le joueur est-il *obligé* de se servir de la capacité `c` ? Une capacité qui ne sert qu'au
-- passage d'apprentissage est un gadget : la spec veut qu'elle reste nécessaire ensuite.
--
-- Un saut a -> b « exige `c` » s'il est possible avec les capacités dont on dispose en a mais impossible sans `c`.
-- On cherche la route du départ au dernier checkpoint qui en compte le moins : ce minimum est le nombre de sauts
-- que *personne* ne peut éviter, quel que soit le chemin pris. Compter les sauts exigeants d'un seul chemin ne
-- prouverait rien (il suffirait d'un détour facile à côté) ; le minimum, lui, se prouve.
--
-- Parcours à moindre coût (0-1 BFS) sur les états (plateforme, capacités en main) : le coût d'une arête vaut 1 si
-- elle exige `c`, 0 sinon, et une arête de coût 0 passe en tête de file. Avant la dalle de `c` aucune arête ne
-- peut coûter 1 (on n'a pas `c`) : on mesure donc bien ce qui est exigé *après* le déblocage.
local MIN_EXIGENCES = 3
local dernierCp = 0
for _, p in plateformes do
	if p.cp and p.cp > dernierCp then
		dernierCp = p.cp
	end
end

type Etape = { avant: number, depuis: number, vers: number, exigeant: boolean }
local function exigences(c: number): (number, { string })
	local cout: { [number]: number } = {}
	local venant: { [number]: Etape } = {}
	-- File à deux bouts : `tete` (arrivées par une arête gratuite, en pile) puis `queue` (arêtes à 1, en file).
	local tete, queue = {}, {}
	local function poser(k: number, c0: number, etape: Etape?, gratuit: boolean)
		if cout[k] and cout[k] <= c0 then
			return
		end
		cout[k] = c0
		venant[k] = etape
		table.insert(if gratuit then tete else queue, k)
	end
	local depuisDepart = depart * ETATS + bit32.bor(acquises, plateformes[depart].donne or 0)
	poser(depuisDepart, 0, nil, true)
	while #tete > 0 or #queue > 0 do
		local k = if #tete > 0 then table.remove(tete) else table.remove(queue, 1)
		local caps = k % ETATS
		local i = (k - caps) // ETATS
		local c0 = cout[k]
		for j, q in plateformes do
			if j == i or not sautPossible(plateformes[i], q, caps) then
				continue
			end
			local exigeant = not sautPossible(plateformes[i], q, bit32.band(caps, bit32.bnot(c)))
			local suivant = j * ETATS + bit32.bor(caps, q.donne or 0)
			poser(
				suivant,
				c0 + (if exigeant then 1 else 0),
				{ avant = k, depuis = i, vers = j, exigeant = exigeant },
				not exigeant
			)
		end
	end
	local arrivee, coutArrivee = nil, math.huge
	for k, c0 in cout do
		if plateformes[(k - k % ETATS) // ETATS].cp == dernierCp and c0 < coutArrivee then
			arrivee, coutArrivee = k, c0
		end
	end
	if not arrivee then
		return -1, {} -- le dernier checkpoint n'est pas atteignable : signalé ailleurs
	end
	-- Les sauts exigeants de cette route la moins exigeante, du départ à l'arrivée.
	local sauts, k = {}, arrivee
	while venant[k] do
		local e = venant[k]
		if e.exigeant then
			local a, b = plateformes[e.depuis], plateformes[e.vers]
			table.insert(
				sauts,
				1,
				string.format(
					"%s (x %.0f, haut %.1f) -> %s (x %.0f, haut %.1f) : vide %.2f, montée %+.1f",
					a.nom,
					(a.x1 + a.x2) / 2,
					a.haut,
					b.nom,
					(b.x1 + b.x2) / 2,
					b.haut,
					vide(a, b),
					b.haut - a.haut
				)
			)
		end
		k = e.avant
	end
	return coutArrivee, sauts
end

for _, nom in ORDRE do
	if not posees[nom] then
		continue
	end
	local montee, videMax = limites(CAPACITES[nom])
	local sans = inatteignables(explorer(CAPACITES[nom]))
	print(
		string.format(
			"  %s : dalle %s ; avec elle seule montée %.1f, vide %.2f ; sans elle %d checkpoint(s) inatteignable(s) : %s",
			nom,
			posees[nom],
			montee,
			videMax,
			#sans - #manquants,
			table.concat(sans, ", ")
		)
	)
	-- On ne juge les portes que sur un parcours entier : s'il est déjà coupé ailleurs, tout est inatteignable de
	-- toute façon et l'écart ne veut plus rien dire.
	if #manquants == 0 and #sans == 0 then
		print(`  DÉFAUT : le passage d'apprentissage de {nom} se franchit sans elle (porte sans effet)`)
		defauts += 1
	end
	-- Une capacité ne doit pas servir qu'une fois : après sa dalle, le parcours doit l'exiger encore.
	if #manquants == 0 then
		local combien, sauts = exigences(CAPACITES[nom])
		print(`    {combien} saut(s) exigent {nom} sur la route la moins exigeante (minimum {MIN_EXIGENCES}) :`)
		for _, n in sauts do
			print(`      {n}`)
		end
		if combien < MIN_EXIGENCES then
			print(
				`  DÉFAUT : {nom} n'est exigée que par {combien} saut(s) après son déblocage, il en faut {MIN_EXIGENCES}`
			)
			defauts += 1
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Portes strictement nécessaires, en **physique réelle** (spec 2026-11-18, critère d'acceptation révisé).
--
-- Les deux contrôles ci-dessus jugent avec le modèle prudent : ils disent qu'un joueur *raisonnable* ne passe pas
-- sans la capacité. Ce n'est pas la même chose que « personne ne passe ». Ici on rejoue exactement le même parcours
-- en largeur, mais avec tout ce que le moteur permet vraiment (outils/monde/physique.luau) : course, vol du double
-- saut déclenché au meilleur moment, dash, plus deux studs de marge de bord offerts au joueur. Si un chemin existe
-- quand même jusqu'au dernier checkpoint sans la capacité, la porte est décorative et c'est un défaut.
--
-- Le jeu de capacités disponible varie le long du chemin : le parcours en largeur transporte ce qui a été ramassé
-- en route, donc chaque saut est jugé avec ce que le joueur a vraiment en main à cet endroit (rien au début, la
-- course devant la porte du dash, etc.), et le minimum est pris sur tous les chemins.
--
-- Le critère est **global** : « aucun chemin ne mène au bout sans la capacité ». Il n'exige pas un saut dédié qui
-- la verrouille à lui seul, et il ne dit pas où se trouve le verrou — un parcours peut parfaitement rendre une
-- capacité obligatoire bien après la dalle qui l'enseigne (c'est le cas du double saut, verrouillé par l'atrium
-- de Sup de Vinci et non par le balcon de la tour).
print("\n== Portes strictement nécessaires (physique réelle) ==")
print(
	string.format(
		"  repères : saut simple %.1f studs de montée, double saut %.1f ; marge de bord offerte %.0f stud(s)",
		Physique.HAUTEUR_SIMPLE,
		Physique.HAUTEUR_DOUBLE,
		Physique.MARGE_BORD
	)
)
for caps = 0, TOUTES do
	print(
		string.format(
			"  plafond réel avec %-28s : vide %5.2f à plat, %5.2f en montant de 4, montée %.1f",
			Physique.nommer(caps),
			Physique.portee(0, caps),
			Physique.portee(4, caps),
			Physique.monteeMax(caps)
		)
	)
end
for _, nom in ORDRE do
	if not posees[nom] or #manquants > 0 then
		continue
	end
	local atteintReel, venantReel = explorer(CAPACITES[nom], true)
	local sansReel = inatteignables(atteintReel)
	if #sansReel == 0 then
		print(`  DÉFAUT : en physique réelle, un chemin mène au bout sans {nom} : la porte ne tient pas en jeu`)
		defauts += 1
		-- La route trouvée : les sauts qui, dans le modèle prudent, auraient été refusés sans la capacité. Ce sont
		-- eux qu'il faut agrandir (ou déplacer avant le déblocage qui les rend franchissables).
		local fin
		for i, p in plateformes do
			if p.cp == dernierCp and atteintReel[i] then
				fin = i
			end
		end
		local suite = {}
		while fin do
			table.insert(suite, 1, fin)
			fin = venantReel[fin]
		end
		for k = 1, #suite - 1 do
			local a, b = plateformes[suite[k]], plateformes[suite[k + 1]]
			local caps = bit32.band(atteintReel[suite[k]] or 0, bit32.bnot(CAPACITES[nom]))
			if not sautPossible(a, b, caps) then
				print(
					string.format(
						"      passé quand même : %s (haut %.1f) -> %s (haut %.1f), vide %.2f, montée %+.1f (portée réelle %.2f avec %s)",
						a.nom,
						a.haut,
						b.nom,
						b.haut,
						vide(a, b),
						b.haut - a.haut,
						Physique.portee(b.haut - a.haut, caps),
						Physique.nommer(caps)
					)
				)
			end
		end
	else
		print(`  {nom} : sans elle, {#sansReel} checkpoint(s) restent hors d'atteinte (le premier : {sansReel[1]})`)
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
		if chevauche and dessous > p.haut + 0.01 and dessous < p.haut + HAUTEUR_LIBRE then
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

-- Mortels trop proches : pour chaque saut possible a -> b, une pièce mortelle m à moins de 1,5 stud (à
-- l'horizontale) de a ou de b est signalée si elle occupe la hauteur où passe le corps :
-- m.bas < max(a.haut, b.haut) + 5 et m.haut >= min(a.haut, b.haut). Un sol mortel sous la plateforme voisine
-- (m.haut <= haut de cette plateforme) n'est pas un piège : il n'est pas signalé pour elle.
local proches = 0
local vus = {}
for i, a in plateformes do
	for j, b in plateformes do
		if i == j or not sautPossible(a, b, atteint[i] or 0) then
			continue
		end
		for k, m in mortels do
			if m.bas >= math.max(a.haut, b.haut) + 5 or m.haut < math.min(a.haut, b.haut) then
				continue
			end
			for _, cote in { { i, a }, { j, b } } do
				local idx, p = cote[1], cote[2]
				local cle = idx .. "|" .. k
				if vus[cle] or vide(p, m) >= 1.5 or m.haut <= p.haut then
					continue
				end
				vus[cle] = true
				proches += 1
				print(
					string.format(
						"  mortel trop proche : %s (x %.0f..%.0f, bas %.1f, haut %.1f) à %.1f de %s (x %.0f, haut %.1f), saut %s -> %s",
						m.nom,
						m.x1,
						m.x2,
						m.bas,
						m.haut,
						vide(p, m),
						p.nom,
						(p.x1 + p.x2) / 2,
						p.haut,
						a.nom,
						b.nom
					)
				)
			end
		end
	end
end
print(`mortels trop proches : {proches}`)

-- Un checkpoint inatteignable, un mortel trop proche ou une porte d'apprentissage sans effet bloque la CI ; les
-- plafonds bas restent un avertissement (deux sont voulus : les barres tournantes).
if #manquants > 0 or proches > 0 or defauts > 0 then
	print(`défauts : {defauts}`)
	process.exit(1)
end
