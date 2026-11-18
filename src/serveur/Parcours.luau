--!strict
-- Le parcours : checkpoints, réapparition au dernier checkpoint, chrono, aura (série sans chute), arrivée,
-- « Recommencer », « Passer l'étape ».
-- Le serveur décide de tout : le client n'envoie que « je veux recommencer ».
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Capacites = require(script.Parent.Capacites)
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
-- Services qui doivent lâcher le joueur quand il clique « Recommencer » (src/serveur/Ascension.luau y abandonne la
-- tentative d'ascension). Un abonnement plutôt qu'un require : Ascension requiert déjà Parcours.
local avantRecommencer: { (Player) -> () } = {}

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
		aura = donnees.aura,
		serie = course.serie,
	})
end

--- Aura du joueur changée : liste des joueurs (leaderstats) et classement mondial (envoyé par lots).
local function majAura(joueur: Player, donnees: Regles.Donnees)
	local stats = joueur:FindFirstChild("leaderstats")
	local valeur = stats and stats:FindFirstChild("Aura")
	if valeur and valeur:IsA("IntValue") then
		valeur.Value = donnees.aura
	end
	Classement.signalerAura(joueur, donnees.aura)
end

local function creerLeaderstats(joueur: Player, donnees: Regles.Donnees)
	if joueur:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- nom imposé par Roblox : affiché dans la liste des joueurs
	local aura = Instance.new("IntValue")
	aura.Name = "Aura"
	aura.Value = donnees.aura
	aura.Parent = stats
	stats.Parent = joueur
end

--- Cette réapparition est-elle celle de l'ascension ? Un joueur qui a fini le tuto et qui est dans l'ascension
--- (attribut `EnAscension` posé par src/serveur/Ascension.luau) est placé par ce service-là, au pied de
--- l'ascension, pas ici. « A fini le tuto » vient de `Regles.ascensionOuverte` (donc `donnees.tutoFini`), la même
--- fonction que l'ouverture de l'ascension côté src/serveur/Ascension.luau : les deux services doivent toujours dire
--- la même chose, sinon ils se disputent la réapparition.
local function placeParAscension(joueur: Player, donnees: Regles.Donnees): boolean
	return Regles.placeParAscension(joueur:GetAttribute("EnAscension") == true, donnees)
end

--- Pose le personnage sur son dernier checkpoint, tourné vers la suite du parcours (+X).
local function placer(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local personnage = joueur.Character
	if not donnees or not personnage then
		return
	end
	if placeParAscension(joueur, donnees) then
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
	donnees.tutoFini = true -- arrivée atteinte : l'ascension s'ouvre, pour toujours (« Recommencer » n'y change rien)
	local classable = Regles.estClassable(course, duree, Reglages.TEMPS_MIN_CLASSABLE)
	local record = classable and Regles.estRecord(donnees.meilleurTemps, duree)
	if record then
		donnees.meilleurTemps = duree
		Classement.soumettre(joueur, duree)
	end
	local gain = Regles.gainArrivee(course, Reglages)
	donnees.aura += gain
	majAura(joueur, donnees)
	arrivee:FireClient(joueur, duree, classable, record, gain)
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
	local course = courses[joueur]
	if course then
		course.serie += 1
		donnees.aura += Regles.gainCheckpoint(course.serie, Reglages)
		majAura(joueur, donnees)
	end
	if numero == Reglages.NB_ETAPES then
		terminer(joueur)
	end
	envoyerEtat(joueur)
end

--- Le personnage est mort (vide, jus de poubelle, Vilaine, pelouse…) : la série repart de zéro et l'aura baisse.
local function surChute(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	local course = courses[joueur]
	-- Pas de perte d'aura à l'arrivée, ni dans l'ascension.
	if not donnees or not course or donnees.etape >= Reglages.NB_ETAPES or placeParAscension(joueur, donnees) then
		return
	end
	course.serie = 0
	course.chutes += 1
	donnees.aura = Regles.auraApresChute(donnees.aura, Reglages)
	majAura(joueur, donnees)
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
	creerLeaderstats(joueur, donnees)
	Classement.signalerAura(joueur, donnees.aura)
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
	-- D'abord on ferme la tentative d'ascension en cours (attribut EnAscension à false) : sans ça, le joueur serait
	-- remis au pied de l'ascension et non au départ du tuto. Aucune aura n'est touchée, rien n'est classé.
	for _, fonction in avantRecommencer do
		local ok, erreur = pcall(fonction, joueur)
		if not ok then
			warn(`[Parcours] abandon avant « Recommencer » en échec : {erreur}`)
		end
	end
	Regles.recommencer(donnees)
	courses[joueur] = Regles.nouvelleCourse(maintenant())
	joueur:LoadCharacter() -- le nouveau personnage est posé au départ par CharacterAdded
	envoyerEtat(joueur)
end

local Parcours = {}

--- Abonne un service à « Recommencer » : `fonction(joueur)` est appelée avant que le joueur soit renvoyé au départ.
function Parcours.avantRecommencer(fonction: (Player) -> ())
	table.insert(avantRecommencer, fonction)
end

--- Replace le joueur sur son dernier checkpoint. Sert à src/serveur/Ascension.luau, qui rend la main quand il n'a
--- pas réussi à poser le joueur au pied de l'ascension : sans ça, plus personne ne le placerait.
function Parcours.placerAuCheckpoint(joueur: Player)
	placer(joueur)
end

--- Ajoute de l'aura au joueur et la fait suivre partout : liste des joueurs, classement (par lots) et état du
--- client. Même chemin que l'aura des checkpoints. Sert aux étages de l'ascension (src/serveur/Ascension.luau).
--- Rend false si les données ne sont pas chargées ou si le gain est nul.
function Parcours.ajouterAura(joueur: Player, gain: number): boolean
	local donnees = Donnees.obtenir(joueur)
	if not donnees or gain <= 0 then
		return false
	end
	donnees.aura += math.floor(gain)
	majAura(joueur, donnees)
	envoyerEtat(joueur)
	return true
end

--- Avance le joueur d'une étape (achat Robux). Rend false s'il n'y a plus d'étape à passer.
function Parcours.passerEtape(joueur: Player): boolean
	local donnees = Donnees.obtenir(joueur)
	local course = courses[joueur]
	if not donnees or not course or donnees.etape >= Reglages.NB_ETAPES then
		return false
	end
	donnees.etape += 1
	course.passages += 1
	course.serie = 0 -- une étape achetée ne rapporte pas d'aura et casse la série
	placer(joueur)
	-- Ce déplacement vient du serveur : la surveillance ne doit pas le prendre pour un déplacement impossible.
	Capacites.autoriserTeleportation(joueur)
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
		joueur.CharacterAdded:Connect(function(personnage)
			task.defer(placer, joueur)
			local humanoide = personnage:WaitForChild("Humanoid", 10)
			if humanoide and humanoide:IsA("Humanoid") then
				-- Connexion détruite avec le personnage : pas de fuite.
				humanoide.Died:Connect(function()
					surChute(joueur)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		Classement.envoyerAura(joueur) -- dernière aura connue, sans attendre le prochain lot
		courses[joueur] = nil
		derniereDemande[joueur] = nil
	end)

	demanderRecommencer.OnServerEvent:Connect(recommencer)
end

return Parcours
