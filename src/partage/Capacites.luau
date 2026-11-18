--!strict
-- Les capacités de déplacement (course, double saut, dash) en fonctions pures, sans Roblox : ce que teste
-- tests/partage/Capacites.spec.luau. Le client s'en sert pour savoir ce qui est permis, le serveur pour surveiller :
-- il compare le déplacement réel d'un joueur à ce que ses capacités autorisent au maximum (voir evaluerDeplacement).
--
-- La comparaison se fait sur une **fenêtre glissante** de SURVEILLANCE_FENETRE secondes (empiler / evaluerFenetre),
-- relevée toutes les SURVEILLANCE_PERIODE secondes. Sur une fenêtre courte, le terme fixe du maximum (la hauteur
-- d'un envol, 14,4 studs, qu'il faut autoriser parce que la fenêtre peut tomber pile sur un décollage) comptait
-- autant que la montée elle-même : le plafond valait trois fois ce qu'un joueur tient vraiment. Étalé sur 2,5 s,
-- ce terme pèse cinq fois moins et le plafond se resserre sans refuser un seul déplacement légitime.
--
-- Modèle physique : un personnage Roblox par défaut (marche 16 studs/s, saut de 7,2 studs de haut, gravité 196,2).
-- Les valeurs des capacités elles-mêmes (facteur de course, dash, double saut, marge) sont dans Reglages.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)

export type Capacite = "course" | "doubleSaut" | "dash"
export type Debloquees = { [string]: boolean }

-- Un relevé de position de la surveillance. Trois nombres plutôt qu'un Vector3 : ce module reste pur.
export type Releve = { instant: number, x: number, y: number, z: number }
-- Les relevés récents d'un joueur, du plus vieux au plus récent (voir empiler).
export type Tampon = { Releve }
-- Le déplacement mesuré d'un bout à l'autre de la fenêtre.
export type Deplacement = { horizontal: number, montee: number, duree: number }

-- Le personnage de référence (valeurs par défaut de Roblox).
export type Physique = {
	vitesseMarche: number, -- studs/s
	hauteurSaut: number, -- studs : hauteur d'un saut simple
	gravite: number, -- studs/s²
}

local PHYSIQUE_DEFAUT: Physique = table.freeze({ vitesseMarche = 16, hauteurSaut = 7.2, gravite = 196.2 })

local TOUTES: { Capacite } = table.freeze({ "course", "doubleSaut", "dash" })

local Capacites = {}

Capacites.PHYSIQUE_DEFAUT = PHYSIQUE_DEFAUT
Capacites.TOUTES = TOUTES

--- Nombre fini et positif ou nul (0 sinon : NaN, négatif, infini).
local function positifOuNul(valeur: number): number
	if valeur ~= valeur or valeur < 0 or valeur == math.huge then
		return 0
	end
	return valeur
end

local function possede(capacites: Debloquees?, capacite: Capacite): boolean
	return typeof(capacites) == "table" and capacites[capacite] == true
end

--- `valeur` est-elle le nom d'une des trois capacités ? (validation d'un attribut de la carte, d'un message)
function Capacites.estCapacite(valeur: any): boolean
	return typeof(valeur) == "string" and table.find(TOUTES :: { any }, valeur) ~= nil
end

--- La capacité est-elle débloquée dans les données du joueur ? Tolère des données sans champ `capacites`.
function Capacites.estDebloquee(donnees: { capacites: any? }?, capacite: Capacite | string): boolean
	if typeof(donnees) ~= "table" or typeof(donnees.capacites) ~= "table" then
		return false
	end
	local liste = donnees.capacites :: { [string]: any }
	return Capacites.estCapacite(capacite) and liste[capacite] == true
end

--- Vitesse verticale d'un saut simple (studs/s) : v² = 2 g h.
function Capacites.vitesseSaut(physique: Physique?): number
	local p = physique or PHYSIQUE_DEFAUT
	return math.sqrt(2 * p.gravite * p.hauteurSaut)
end

--- Hauteur maximale d'un envol (studs) : un saut, plus le double saut lancé au sommet du premier s'il est débloqué.
function Capacites.hauteurEnvol(capacites: Debloquees?, physique: Physique?): number
	local p = physique or PHYSIQUE_DEFAUT
	local hauteur = p.hauteurSaut
	if possede(capacites, "doubleSaut") then
		local v2 = Reglages.SAUT_DOUBLE_FACTEUR * Capacites.vitesseSaut(p)
		hauteur += v2 * v2 / (2 * p.gravite)
	end
	return hauteur
end

--- Vitesse de marche (studs/s) : la normale, ou multipliée par la course si elle est débloquée ET qu'on court.
local function vitesseAuSol(capacites: Debloquees?, enCourse: boolean, physique: Physique): number
	if enCourse and possede(capacites, "course") then
		return physique.vitesseMarche * Reglages.COURSE_FACTEUR
	end
	return physique.vitesseMarche
end

--- Vitesse horizontale maximale possible (studs/s) avec ces capacités : marche, course si `enCourse` et débloquée,
--- et la vitesse du dash s'il est débloqué (pendant DASH_DUREE seulement : voir distanceMax pour une durée).
function Capacites.vitesseMax(capacites: Debloquees?, enCourse: boolean, physique: Physique?): number
	local p = physique or PHYSIQUE_DEFAUT
	local vitesse = vitesseAuSol(capacites, enCourse, p)
	if possede(capacites, "dash") then
		vitesse = math.max(vitesse, Reglages.DASH_VITESSE)
	end
	return vitesse
end

--- Distance horizontale gagnée par un dash par rapport à la même durée sans dash (studs), pour un joueur qui
--- avance à `vitesseSol` studs/s : (DASH_VITESSE - vitesseSol) x DASH_DUREE. C'est de combien un dash allonge un saut.
function Capacites.extensionDash(vitesseSol: number): number
	return math.max(0, (Reglages.DASH_VITESSE - vitesseSol) * Reglages.DASH_DUREE)
end

--- Durée minimale d'un envol complet (s) : monter puis retomber au même niveau. Un dash par envol au plus, donc pas
--- deux dash plus rapprochés que ça (le dash lancé au sol attend en plus DASH_RECHARGE_SOL).
local function dureeEnvolMin(physique: Physique): number
	return 2 * Capacites.vitesseSaut(physique) / physique.gravite
end

--- Distance horizontale maximale (studs) qu'un joueur peut parcourir en `duree` secondes : il court en permanence
--- (s'il a la course), et fait autant de dash que les envols le permettent (un dash par envol, au moins un).
function Capacites.distanceMax(capacites: Debloquees?, duree: number, physique: Physique?): number
	local p = physique or PHYSIQUE_DEFAUT
	local d = positifOuNul(duree)
	local vitesse = vitesseAuSol(capacites, true, p)
	local distance = vitesse * d
	if possede(capacites, "dash") then
		local nbDash = math.floor(d / dureeEnvolMin(p)) + 1
		distance += nbDash * Capacites.extensionDash(vitesse)
	end
	return distance
end

--- Montée maximale (studs) possible en `duree` secondes : des sauts (et doubles sauts) enchaînés sans perdre une
--- image (chaque saut posé sur une plateforme exactement à son sommet : vitesse moyenne de montée = la moitié de
--- la vitesse du saut), ou une pente raide gravie à la vitesse de course ; plus la hauteur d'un envol, pour
--- l'alignement de la fenêtre de mesure sur l'envol. Le dash ne monte pas (vitesse imposée sur le plan horizontal).
function Capacites.monteeMax(capacites: Debloquees?, duree: number, physique: Physique?): number
	local p = physique or PHYSIQUE_DEFAUT
	local d = positifOuNul(duree)
	local tauxSauts = Capacites.vitesseSaut(p) / 2
	local taux = math.max(tauxSauts, vitesseAuSol(capacites, true, p))
	return taux * d + Capacites.hauteurEnvol(capacites, p)
end

--- Verdict de la surveillance serveur : le joueur s'est déplacé de `distanceHorizontale` studs et a monté de
--- `montee` studs (négatif : chute, jamais refusée) en `duree` secondes. Rend nil si c'est possible avec ses
--- capacités, sinon « horizontal » (trop vite sur le plan) ou « vertical » (monte trop vite). Le maximum est élargi
--- de SURVEILLANCE_MARGE (relatif) et SURVEILLANCE_TOLERANCE (studs, fixe). Une valeur absurde (NaN) est refusée.
function Capacites.evaluerDeplacement(
	capacites: Debloquees?,
	distanceHorizontale: number,
	montee: number,
	duree: number,
	physique: Physique?
): string?
	local marge, tolerance = Reglages.SURVEILLANCE_MARGE, Reglages.SURVEILLANCE_TOLERANCE
	local maxHorizontal = Capacites.distanceMax(capacites, duree, physique) * marge + tolerance
	if not (distanceHorizontale <= maxHorizontal) then -- écrit ainsi pour refuser aussi NaN
		return "horizontal"
	end
	local maxVertical = Capacites.monteeMax(capacites, duree, physique) * marge + tolerance
	if not (montee <= maxVertical) then
		return "vertical"
	end
	return nil
end

--- Ajoute un relevé au tampon et oublie ce qui est plus vieux que `fenetre` secondes — en gardant un seul relevé
--- au-delà : c'est lui la référence, pour que la fenêtre comparée couvre toujours `fenetre` entière (sinon elle
--- rétrécirait jusqu'à une période et le plafond se relâcherait d'autant). Le tampon est modifié et rendu.
function Capacites.empiler(tampon: Tampon, instant: number, x: number, y: number, z: number, fenetre: number?): Tampon
	table.insert(tampon, { instant = instant, x = x, y = y, z = z })
	local limite = instant - positifOuNul(if fenetre ~= nil then fenetre else Reglages.SURVEILLANCE_FENETRE)
	while #tampon >= 2 and tampon[2].instant <= limite do
		table.remove(tampon, 1)
	end
	return tampon
end

--- Le serveur vient de placer le joueur à (x, y, z) : le tampon repart de cette destination, avec ce seul relevé.
--- Les relevés suivants se mesurent depuis elle, et non depuis le point de départ de la téléportation (le saut de
--- position n'est jamais comparé). Sans ce relevé de départ, la surveillance restait aveugle jusqu'à la deuxième
--- mesure après le délai de la téléportation, et un client qui demande une téléportation de palier toutes les 2 s
--- ne se faisait jamais mesurer. Le tampon est modifié et rendu.
function Capacites.amorcer(tampon: Tampon, instant: number, x: number, y: number, z: number): Tampon
	table.clear(tampon)
	table.insert(tampon, { instant = instant, x = x, y = y, z = z })
	return tampon
end

--- Le déplacement mesuré sur la fenêtre : du plus vieux relevé gardé au plus récent. nil s'il n'y a pas deux
--- relevés à comparer (apparition, téléportation du serveur, correction : la fenêtre se reconstruit).
function Capacites.deplacementFenetre(tampon: Tampon): Deplacement?
	if #tampon < 2 then
		return nil
	end
	local debut, fin = tampon[1], tampon[#tampon]
	local dx, dz = fin.x - debut.x, fin.z - debut.z
	return {
		horizontal = math.sqrt(dx * dx + dz * dz),
		montee = fin.y - debut.y,
		duree = fin.instant - debut.instant,
	}
end

--- Verdict de la surveillance sur toute la fenêtre du tampon : nil (rien d'anormal, ou pas assez de relevés),
--- « horizontal » ou « vertical ». Rend aussi la mesure, pour le journal du serveur.
function Capacites.evaluerFenetre(capacites: Debloquees?, tampon: Tampon, physique: Physique?): (string?, Deplacement?)
	local mesure = Capacites.deplacementFenetre(tampon)
	if mesure == nil then
		return nil, nil
	end
	local m = mesure :: Deplacement
	return Capacites.evaluerDeplacement(capacites, m.horizontal, m.montee, m.duree, physique), m
end

return Capacites
