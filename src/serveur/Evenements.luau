--!strict
-- Les événements de la carte (tag Evenement) sont animés par chaque client, calés sur l'horloge du serveur
-- (src/client/Evenements.luau). Le serveur ne les déplace pas : il écoute seulement « je suis touché » et tue le
-- joueur, ce qui déclenche Humanoid.Died donc le décompte de la chute dans Parcours.luau.
-- Le serveur ne fait pas confiance au client : le danger doit être actif à cet instant (à la tolérance du réseau
-- près), le joueur près de la trajectoire, vivant, et les signalements espacés. Un tricheur n'y gagne rien d'autre
-- que de se tuer lui-même ; un client qui ne signale pas ne meurt pas (choix de la spec : décision de l'étudiant).
-- La règle elle-même est une fonction pure et testée (src/partage/Signalement.luau) ; ce service rassemble les
-- données du jeu et applique la décision.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)
local Signalement = require(ReplicatedStorage.Partage.Signalement)

local toucheParEvenement = Remotes.obtenir("ToucheParEvenement")

local dernierSignalement: { [Player]: number } = {}

local function demiTaille(objet: Instance): number
	if objet:IsA("Model") then
		return objet:GetExtentsSize().Magnitude / 2
	elseif objet:IsA("BasePart") then
		return objet.Size.Magnitude / 2
	end
	return math.huge
end

--- Rassemble ce que la règle (Signalement.valider) doit savoir, sans rien décider.
local function rassembler(joueur: Player, objet: unknown): Signalement.Entree
	local valide = typeof(objet) == "Instance"
		and objet:IsDescendantOf(workspace)
		and (objet:IsA("Model") or objet:IsA("BasePart"))
	local instance: any = if valide then objet else nil

	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	local position: Vector3? = if racine and racine:IsA("BasePart") then racine.Position else nil

	return {
		objetValide = valide,
		avecTag = instance ~= nil and CollectionService:HasTag(instance, "Evenement"),
		attributs = if instance then instance:GetAttributes() else {},
		heureServeur = workspace:GetServerTimeNow(),
		tolerance = Reglages.EVENEMENT_TOLERANCE,
		vivant = humanoide ~= nil and humanoide.Health > 0,
		position = position,
		posee = if instance then instance:GetPivot().Position else Vector3.zero,
		demiTaille = if instance then demiTaille(instance) else 0,
		distanceMax = Reglages.EVENEMENT_DISTANCE_MAX,
	}
end

local function surSignalement(joueur: Player, objet: unknown)
	-- Cadence puis validation : une seule fonction pure et testée (les rafales sont écartées avant de rassembler).
	local accepte = Signalement.traiter(dernierSignalement, joueur, os.clock(), Reglages.EVENEMENT_DELAI_MIN, function()
		return rassembler(joueur, objet)
	end)
	if not accepte then
		return
	end
	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.Health = 0 -- le serveur voit Died : Parcours.luau compte la chute
	end
end

local Evenements = {}

function Evenements.demarrer()
	toucheParEvenement.OnServerEvent:Connect(surSignalement)
	Players.PlayerRemoving:Connect(function(joueur)
		dernierSignalement[joueur] = nil
	end)
end

return Evenements
