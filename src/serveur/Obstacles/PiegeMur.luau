--!strict
-- PiegeMur (sur un Model, enfant `Pointe`) : une pointe (ou une barre) rentrée dans le mur, dont le seul indice est
-- une fente et une trace d'usure posées par la carte. Dès qu'un joueur vivant entre dans `Portee` studs de la fente,
-- elle sort en `DureeSortie` secondes, rentre en `DureeRentree`, puis se repose avant de pouvoir repartir. Elle ne
-- tue pas : au contact elle projette le joueur à l'horizontale (voir `pousser`).
-- La pointe reste ancrée et c'est le serveur qui la déplace : tous les joueurs la voient au même endroit, et une
-- pièce ancrée ne peut pas être poussée hors de son mur par un joueur qui s'y jette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pieges = require(ReplicatedStorage.Partage.Pieges)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Commun = require(script.Parent.Commun)

-- Attribut posé sur le HumanoidRootPart : heure du dernier coup de pointe reçu. Sur le personnage plutôt que dans
-- une table du service : il disparaît avec lui, donc rien à nettoyer et rien qui fuit.
local ATTRIBUT_DERNIERE_POUSSEE = "DernierePousseePiege"

type Piege = {
	pointe: BasePart,
	pose: CFrame, -- la pointe rentrée : l'origine de sa course et le centre de sa portée
	parametres: Pieges.ParametresPiege,
	debut: number, -- os.clock() du dernier déclenchement ; -inf tant qu'elle n'a jamais bougé
	phase: Pieges.PhasePiege,
	avancement: number, -- dernière sortie appliquée (0 rentrée, 1 dehors) : on ne réécrit pas un CFrame identique
}

--- Distance du plus proche de ces points à `point`, ou nil s'il n'y en a aucun.
local function distanceAuPlusProche(positions: { Vector3 }, point: Vector3): number?
	local meilleure: number? = nil
	for _, position in positions do
		local d = (position - point).Magnitude
		if meilleure == nil or d < meilleure then
			meilleure = d
		end
	end
	return meilleure
end

-- Les pointes bougent à chaque image ; la recherche d'un joueur à portée, elle, n'a lieu qu'aux images où
-- `positions` est donné.
local function majPiege(piege: Piege, horloge: number, positions: { Vector3 }?)
	local phase: Pieges.PhasePiege, avancement = Pieges.phasePiege(horloge - piege.debut, piege.parametres)
	if
		positions
		and Pieges.doitDeclencher(phase, distanceAuPlusProche(positions, piege.pose.Position), piege.parametres.portee)
	then
		piege.debut = horloge
		phase, avancement = "sortie", 0
	end
	piege.phase = phase
	if math.abs(avancement - piege.avancement) > 1e-4 then
		piege.avancement = avancement
		piege.pointe.CFrame = piege.pose + piege.parametres.direction * (piege.parametres.distance * avancement)
	end
end

--- Le coup de pointe : la vitesse horizontale du joueur est remplacée par celle du piège, dans sa direction.
--- Elle ne tue jamais (c'est le vide qui tue) et reste rattrapable : voir Reglages.PIEGE_POUSSEE.
--- Un même joueur n'est repoussé qu'une fois par PIEGE_DELAI_POUSSEE secondes : `Touched` se déclenche plusieurs
--- fois pour un seul contact, et sans ce délai la pointe collerait le joueur à elle.
local function pousser(piege: Piege, touche: BasePart)
	if piege.phase ~= "sortie" and piege.phase ~= "rentree" then
		return -- la pointe est rentrée : on ne pousse pas en frôlant le mur
	end
	local racine = Commun.racineVivante(touche)
	if not racine then
		return
	end
	local horloge = os.clock()
	local derniere = racine:GetAttribute(ATTRIBUT_DERNIERE_POUSSEE)
	if Commun.nombreFini(derniere) and horloge - (derniere :: number) < Reglages.PIEGE_DELAI_POUSSEE then
		return
	end
	racine:SetAttribute(ATTRIBUT_DERNIERE_POUSSEE, horloge)
	racine.AssemblyLinearVelocity =
		Pieges.vitesseApresPoussee(racine.AssemblyLinearVelocity, piege.parametres.direction, piege.parametres.poussee)
end

local function preparer(objet: Instance): Commun.Maj?
	local modele = objet :: Model
	-- Les défauts viennent de Pieges.defautsPiege() (avec pousseeMax) : la même table que les tests.
	local parametres = Pieges.piegeDepuisAttributs(modele:GetAttributes(), Pieges.defautsPiege())
	if not parametres then
		warn(
			`[Obstacles] {modele:GetFullName()} : attributs Direction / Distance / DureeSortie / DureeRentree / Portee / Poussee invalides`
		)
		return nil
	end
	local pointe = modele:FindFirstChild("Pointe")
	if not pointe or not pointe:IsA("BasePart") then
		warn(`[Obstacles] {modele:GetFullName()} : enfant Pointe (BasePart) attendu`)
		return nil
	end
	pointe.Anchored = true
	pointe.CanTouch = true
	local piege: Piege = {
		pointe = pointe,
		pose = pointe.CFrame,
		parametres = parametres,
		debut = -math.huge, -- jamais déclenchée : la pointe est rentrée et prête
		phase = "pret",
		avancement = 0,
	}
	pointe.Touched:Connect(function(touche)
		pousser(piege, touche)
	end)
	return function(instant: Commun.Instant)
		majPiege(piege, instant.horloge, instant.positions)
	end
end

local famille: Commun.Famille = { tag = "PiegeMur", classe = "Model", preparer = preparer }

return famille
