--!strict
-- Le parcours : checkpoints, réapparition au dernier checkpoint, chrono, arrivée, « Recommencer », « Passer l'étape ».
-- Le serveur décide de tout : le client n'envoie que « je veux recommencer ».
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classement = require(script.Parent.Classement)
local Donnees = require(script.Parent.Donnees)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local etatCourse = Remotes.obtenir("EtatCourse")
local arrivee = Remotes.obtenir("Arrivee")
local demanderRecommencer = Remotes.obtenir("DemanderRecommencer")

local checkpoints: { [number]: BasePart } = {}
local courses: { [Player]: Regles.Course } = {}
local derniereDemande: { [Player]: number } = {}

local function maintenant(): number
	return workspace:GetServerTimeNow()
end

local function envoyerEtat(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local course = courses[joueur]
	if not donnees or not course then
		return
	end
	etatCourse:FireClient(joueur, {
		etape = donnees.etape,
		debut = course.debut,
		passages = course.passages,
		reprise = course.reprise,
		meilleurTemps = donnees.meilleurTemps,
	})
end

--- Pose le personnage sur son dernier checkpoint, tourné vers la suite du parcours (+X).
local function placer(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local personnage = joueur.Character
	if not donnees or not personnage then
		return
	end
	local cp = checkpoints[donnees.etape]
	if not cp or not personnage:WaitForChild("HumanoidRootPart", 5) then
		return
	end
	local position = cp.Position + Vector3.new(0, cp.Size.Y / 2 + 3, 0)
	personnage:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
end

local function terminer(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local course = courses[joueur]
	if not donnees or not course or course.debut == nil then
		return
	end
	local duree = maintenant() - (course.debut :: number)
	course.debut = nil -- le chrono s'arrête
	local classable = Regles.estClassable(course, duree, Reglages.TEMPS_MIN_CLASSABLE)
	local record = classable and Regles.estRecord(donnees.meilleurTemps, duree)
	if record then
		donnees.meilleurTemps = duree
		Classement.soumettre(joueur, duree)
	end
	arrivee:FireClient(joueur, duree, classable, record)
end

local function joueurDepuis(touche: BasePart): Player?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local joueur = modele and Players:GetPlayerFromCharacter(modele)
	if not joueur or not modele then
		return nil
	end
	local humanoide = modele:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return nil
	end
	return joueur
end

local function surCheckpoint(numero: number, touche: BasePart)
	local joueur = joueurDepuis(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	if not joueur or not donnees or not Regles.peutValider(donnees.etape, numero, Reglages.NB_ETAPES) then
		return
	end
	donnees.etape = numero
	if numero == Reglages.NB_ETAPES then
		terminer(joueur)
	end
	envoyerEtat(joueur)
end

local function surChargement(joueur: Player, donnees: Regles.Donnees)
	local course
	if donnees.etape == 0 then
		course = Regles.nouvelleCourse(maintenant())
	else
		course = Regles.courseReprise(maintenant())
		if donnees.etape >= Reglages.NB_ETAPES then
			course.debut = nil -- déjà arrivé : pas de chrono tant qu'il ne recommence pas
		end
	end
	courses[joueur] = course
	placer(joueur)
	envoyerEtat(joueur)
end

local function recommencer(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local instant = os.clock()
	if not donnees or instant - (derniereDemande[joueur] or 0) < Reglages.DELAI_MIN_ENTRE_DEMANDES then
		return
	end
	derniereDemande[joueur] = instant
	donnees.etape = 0
	courses[joueur] = Regles.nouvelleCourse(maintenant())
	joueur:LoadCharacter() -- le nouveau personnage est posé au départ par CharacterAdded
	envoyerEtat(joueur)
end

local Parcours = {}

--- Avance le joueur d'une étape (achat Robux). Rend false s'il n'y a plus d'étape à passer.
function Parcours.passerEtape(joueur: Player): boolean
	local donnees = Donnees.obtenir(joueur)
	local course = courses[joueur]
	if not donnees or not course or donnees.etape >= Reglages.NB_ETAPES then
		return false
	end
	donnees.etape += 1
	course.passages += 1
	placer(joueur)
	if donnees.etape == Reglages.NB_ETAPES then
		terminer(joueur)
	end
	envoyerEtat(joueur)
	return true
end

function Parcours.demarrer()
	Players.RespawnTime = Reglages.DELAI_REAPPARITION

	for _, cp in CollectionService:GetTagged("Checkpoint") do
		local numero = cp:GetAttribute("Numero")
		if cp:IsA("BasePart") and typeof(numero) == "number" then
			checkpoints[numero] = cp
			cp.Touched:Connect(function(touche)
				surCheckpoint(numero, touche)
			end)
		end
	end
	for numero = 0, Reglages.NB_ETAPES do
		if not checkpoints[numero] then
			warn(`[Parcours] checkpoint {numero} absent de la carte (monde/Parcours.rbxm)`)
		end
	end

	Donnees.surChargement(surChargement)

	local function suivre(joueur: Player)
		joueur.CharacterAdded:Connect(function()
			task.defer(placer, joueur)
		end)
	end
	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		courses[joueur] = nil
		derniereDemande[joueur] = nil
	end)

	demanderRecommencer.OnServerEvent:Connect(recommencer)
end

return Parcours
