--!strict
-- Les événements de la carte (tag Evenement) sont animés par chaque client, calés sur l'horloge du serveur
-- (src/client/Evenements.luau). Le serveur ne les déplace pas : il écoute seulement « je suis touché » et tue le
-- joueur, ce qui déclenche Humanoid.Died donc le décompte de la chute dans Parcours.luau.
-- Le serveur ne fait pas confiance au client : le danger doit être actif à cet instant (à la tolérance du réseau
-- près), le joueur près de la trajectoire, vivant, et les signalements espacés. Un tricheur n'y gagne rien d'autre
-- que de se tuer lui-même ; un client qui ne signale pas ne meurt pas (choix de la spec : décision de l'étudiant).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Horaires = require(ReplicatedStorage.Partage.Horaires)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local toucheParEvenement = Remotes.obtenir("ToucheParEvenement")

local dernierSignalement: { [Player]: number } = {}

--- Distance d'un point à un segment [a, b].
local function distanceAuSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local longueur2 = ab:Dot(ab)
	if longueur2 < 1e-9 then
		return (p - a).Magnitude
	end
	local u = math.clamp((p - a):Dot(ab) / longueur2, 0, 1)
	return (p - (a + ab * u)).Magnitude
end

local function demiTaille(objet: Instance): number
	if objet:IsA("Model") then
		return objet:GetExtentsSize().Magnitude / 2
	elseif objet:IsA("BasePart") then
		return objet.Size.Magnitude / 2
	end
	return math.huge
end

--- Le joueur est-il assez près de la trajectoire de l'objet (telle que posée dans la carte) pour l'avoir touché ?
local function assezPres(objet: Instance, params: Horaires.Parametres, position: Vector3): boolean
	local posee = (objet :: any):GetPivot().Position
	local distance
	if params.type == "Passage" then
		distance = distanceAuSegment(position, params.depart :: Vector3, params.arrivee :: Vector3)
	else
		distance = distanceAuSegment(position, posee, posee + Vector3.new(0, params.hauteur :: number, 0))
	end
	return distance <= Reglages.EVENEMENT_DISTANCE_MAX + demiTaille(objet)
end

local function surSignalement(joueur: Player, objet: unknown)
	local instant = os.clock()
	if instant - (dernierSignalement[joueur] or -math.huge) < Reglages.EVENEMENT_DELAI_MIN then
		return
	end
	dernierSignalement[joueur] = instant

	if typeof(objet) ~= "Instance" or not objet:IsDescendantOf(workspace) then
		return
	end
	if not CollectionService:HasTag(objet, "Evenement") or not (objet:IsA("Model") or objet:IsA("BasePart")) then
		return
	end
	local params = Horaires.depuisAttributs(objet:GetAttributes())
	if not params then
		return
	end

	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not humanoide or humanoide.Health <= 0 or not racine or not racine:IsA("BasePart") then
		return
	end

	if
		not Horaires.actifAutour(
			workspace:GetServerTimeNow(),
			params.periode,
			params.decalage,
			params.duree,
			Reglages.EVENEMENT_TOLERANCE
		)
	then
		return
	end
	if not assezPres(objet, params, racine.Position) then
		return
	end

	humanoide.Health = 0 -- le serveur voit Died : Parcours.luau compte la chute
end

local Evenements = {}

function Evenements.demarrer()
	toucheParEvenement.OnServerEvent:Connect(surSignalement)
	Players.PlayerRemoving:Connect(function(joueur)
		dernierSignalement[joueur] = nil
	end)
end

return Evenements
