-- Physique réelle du saut, pour les contrôles de carte (outils/monde/verifier-sauts.luau et
-- outils/monde/verifier-ascension.luau). Ce module ne sert **qu'à prouver qu'un passage est strictement
-- infranchissable** sans telle capacité. Il ne dit pas si un saut est confortable : cette question-là garde son
-- modèle prudent, propre à chaque contrôle (montée 4,5 / vide 6,5 à l'arrêt, plafond 16).
--
-- Deux modèles, deux usages :
--   * modèle prudent  : « ce saut est-il jouable sans rage ? » — marge de sécurité voulue, elle reste ;
--   * physique réelle : « ce vide est-il infranchissable sans la course / le double saut / le dash ? » — aucune
--     marge, au contraire : on donne au joueur tout ce que le moteur lui permet, et on exige quand même qu'il
--     échoue. Une porte qui tient ici tient en jeu.
--
-- Rien n'est recopié en dur : la hauteur du saut, la gravité et la vitesse de marche viennent de
-- `src/partage/Capacites.luau` (PHYSIQUE_DEFAUT), les capacités de `src/partage/Reglages.luau` (COURSE_FACTEUR,
-- DASH_VITESSE, DASH_DUREE, SAUT_DOUBLE_FACTEUR). Changer JumpHeight, la gravité ou DASH_VITESSE change donc
-- immédiatement le verdict des contrôles, au lieu de les laisser mentir.
--
-- Dérivation (personnage par défaut : JumpHeight h = 7,2 studs, gravité g = 196,2 studs/s², marche 16 studs/s) :
--   vitesse de décollage         v0 = sqrt(2 g h) = 53,153 studs/s
--   vol d'un saut simple, à plat T  = 2 v0 / g = 0,5418 s
--   vol d'un double saut, à plat T  = 4 v0 / g = 1,0836 s
--
-- Pourquoi 1,0836 s et non 0,9250 s : le second saut **impose** la vitesse verticale v0 (`src/client/Capacites.luau`
-- fait `math.max(vitesse.Y, v0)`) et se déclenche à n'importe quel moment du vol, pas seulement au sommet. Le
-- déclencher au sommet (0,9250 s de vol) est le meilleur choix pour *monter*, pas pour *aller loin*. Pour aller
-- loin, le mieux est de le déclencher en repassant par la hauteur d'arrivée : on colle alors deux arcs complets
-- bout à bout. En général, pour se poser `m` studs plus haut qu'on est parti, l'optimum se déclenche en
-- redescendant à m/2 (vitesse de chute sqrt(v0² − g m)) et donne T = 2 (v0 + sqrt(v0² − g m)) / g. Un contrôle
-- calé sur 0,9250 s laisserait passer des portes que le joueur franchit vraiment.
--
-- Portée horizontale = vitesse au sol × T, plus le gain d'un dash (un seul par envol : `extensionDash`). Le temps
-- de vol ne descend jamais sous v0/g = 0,27 s, toujours plus que DASH_DUREE (0,2 s) : le dash tient entier dans
-- n'importe quel saut.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

assert(
	fs.isFile("src/partage/Reglages.luau") and fs.isFile("src/partage/Capacites.luau"),
	"src/partage/Reglages.luau et src/partage/Capacites.luau introuvables (lancer depuis la racine du dépôt)"
)
local Reglages = luau.load(fs.readFile("src/partage/Reglages.luau"), { debugName = "Reglages" })()
-- `src/partage/Capacites.luau` est écrit pour Roblox : on lui donne juste de quoi atteindre Reglages — un faux
-- `game` dont tout chemin d'instance se résout en lui-même, et un `require` qui rend les réglages déjà chargés.
local faussesInstances = setmetatable({}, {
	__index = function(t)
		return t
	end,
})
local Jeu = luau.load(fs.readFile("src/partage/Capacites.luau"), {
	debugName = "Capacites",
	environment = {
		game = {
			GetService = function()
				return faussesInstances
			end,
		},
		require = function()
			return Reglages
		end,
	},
})()

local P = Jeu.PHYSIQUE_DEFAUT
local V0 = Jeu.vitesseSaut(P) -- vitesse de décollage, studs/s
local G = P.gravite
local HAUTEUR_SIMPLE = P.hauteurSaut -- montée maximale d'un saut simple
local HAUTEUR_DOUBLE = Jeu.hauteurEnvol({ doubleSaut = true }, P) -- et des deux sauts enchaînés

local Physique = {}

-- Les capacités en masque de bits : le seul endroit où ce masque est défini (les contrôles le lisent ici).
Physique.CAPACITES = { course = 1, doubleSaut = 2, dash = 4 }
Physique.ORDRE = { "course", "doubleSaut", "dash" } -- ordre d'affichage et de déblocage
Physique.TOUTES = 0
for _, bit in Physique.CAPACITES do
	Physique.TOUTES = bit32.bor(Physique.TOUTES, bit)
end
-- Les réglages du jeu, déjà chargés ici : les contrôles y lisent NB_ETAPES et les CONTROLE_* du modèle prudent.
Physique.Reglages = Reglages

-- Le joueur ne part pas du bord exact et ne se pose pas sur le bord exact : son corps déborde un peu des deux
-- côtés. On lui offre ces studs en plus avant de déclarer un vide infranchissable, pour que la preuve tienne même
-- quand il décolle au dernier pixel.
Physique.MARGE_BORD = 2

Physique.HAUTEUR_SIMPLE = HAUTEUR_SIMPLE
Physique.HAUTEUR_DOUBLE = HAUTEUR_DOUBLE

local function a(caps: number, nom: string): boolean
	return bit32.band(caps, Physique.CAPACITES[nom]) ~= 0
end

--- Montée maximale réellement atteignable avec `caps` (studs).
function Physique.monteeMax(caps: number): number
	return if a(caps, "doubleSaut") then HAUTEUR_DOUBLE else HAUTEUR_SIMPLE
end

--- Durée de vol (s) d'un envol qui part d'une plateforme et se pose `montee` studs plus haut (négatif : plus bas),
--- au mieux de ce que `caps` permet. math.huge serait faux : on rend -1 quand la montée est hors de portée.
function Physique.tempsVol(montee: number, caps: number): number
	if montee > Physique.monteeMax(caps) then
		return -1
	end
	if a(caps, "doubleSaut") then
		return 2 * (V0 + math.sqrt(V0 * V0 - G * montee)) / G
	end
	return (V0 + math.sqrt(V0 * V0 - 2 * G * montee)) / G
end

--- Vitesse horizontale soutenue (studs/s) : marche, ou course si elle est débloquée.
function Physique.vitesseSol(caps: number): number
	return P.vitesseMarche * (if a(caps, "course") then Reglages.COURSE_FACTEUR else 1)
end

--- Portée horizontale maximale (studs) d'un envol qui se pose `montee` studs plus haut, avec `caps`. -1 si la
--- montée est hors de portée.
function Physique.portee(montee: number, caps: number): number
	local t = Physique.tempsVol(montee, caps)
	if t < 0 then
		return -1
	end
	local v = Physique.vitesseSol(caps)
	local d = v * t
	if a(caps, "dash") then
		d += Jeu.extensionDash(v)
	end
	return d
end

--- Ce saut (vide entre bords, montée) est-il franchissable en physique réelle avec `caps` ? Marge de bord comprise :
--- un « non » d'ici est un vrai « non » en jeu.
function Physique.franchissable(vide: number, montee: number, caps: number): boolean
	local portee = Physique.portee(montee, caps)
	return portee >= 0 and vide <= portee + Physique.MARGE_BORD
end

--- Le nom lisible d'un jeu de capacités (« aucune », « course + dash »…).
function Physique.nommer(caps: number): string
	local noms = {}
	for _, nom in Physique.ORDRE do
		if a(caps, nom) then
			table.insert(noms, nom)
		end
	end
	return if #noms == 0 then "aucune" else table.concat(noms, " + ")
end

return Physique
