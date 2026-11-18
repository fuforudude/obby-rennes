--!strict
-- Les capacités de déplacement, côté serveur : déblocage (pièces tagées `DeblocageCapacite` + attribut `Capacite`),
-- et surveillance des déplacements. Le client bouge son personnage (course, double saut, dash : client/Capacites.luau),
-- le serveur vérifie que ce qu'il observe reste possible avec les capacités débloquées. Il ne tue jamais et
-- n'expulse jamais : un déplacement impossible est corrigé (retour à la dernière position valide) et la tentative
-- d'ascension en cours est marquée non classable (Capacites.tentativeSuspecte, lu par serveur/Ascension).
--
-- Surveillance : toutes les SURVEILLANCE_PERIODE secondes, la position de la racine du personnage est comparée à celle
-- de la mesure précédente ; la règle est pure et testée (partage/Capacites.evaluerDeplacement). Les déplacements que
-- le serveur décide lui-même (réapparition, étape passée, téléportation vers un palier, renvoi au pied) ne sont pas
-- de la triche : le code qui téléporte un joueur appelle `Capacites.autoriserTeleportation(joueur)` au même moment
-- (la réapparition est déjà couverte ici). Sans cet appel, la téléportation serait prise pour un déplacement
-- impossible et le joueur serait ramené en arrière.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Mouvement = require(ReplicatedStorage.Partage.Capacites)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local TAG = "DeblocageCapacite"
-- Après une apparition (ou une téléportation décidée par le serveur), on ne compare plus pendant ce délai (s) : le
-- personnage est posé quelque part par un autre service, et la réplication de sa position arrive avec du retard.
local DELAI_APPARITION = 3
local DELAI_TELEPORTATION = 1.5
local DELAI_CORRECTION = 1 -- après un retour en arrière : le temps que le client applique la correction

local capaciteDebloquee = Remotes.obtenir("CapaciteDebloquee")

-- Suivi d'un joueur : la mesure précédente, la dernière position valide (au sol), et l'état de la tentative.
type Suivi = {
	derniere: Vector3?, -- position à la mesure précédente (nil : à reprendre à la prochaine mesure)
	instant: number, -- os.clock() de cette mesure
	valide: Vector3?, -- dernière position valide, au sol
	ignorerJusqua: number, -- os.clock() : pas de comparaison avant (on reprend seulement la position)
	suspect: boolean, -- un déplacement impossible a été vu pendant cette tentative
	alertes: number,
}

local suivis: { [Player]: Suivi } = {}
local liaisonsPlayers: { [Player]: RBXScriptConnection } = {}
local liaisonsPieces: { [Instance]: RBXScriptConnection } = {}
local abonnes: { (Player, string) -> () } = {}
local demarre = false

--- La table `capacites` des données du joueur (créée si elle n'existe pas : le champ vient de Regles.migrer).
local function capacitesDe(donnees: any): { [string]: boolean }
	if typeof(donnees.capacites) ~= "table" then
		donnees.capacites = {}
	end
	return donnees.capacites
end

local function joueurVivant(touche: BasePart): Player?
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

local function nouveauSuivi(maintenant: number, delaiIgnore: number): Suivi
	return {
		derniere = nil,
		instant = maintenant,
		valide = nil,
		ignorerJusqua = maintenant + delaiIgnore,
		suspect = false,
		alertes = 0,
	}
end

-- Déblocage ------------------------------------------------------------------------------------------------------

local function surToucheDeblocage(piece: BasePart, touche: BasePart)
	local brut = piece:GetAttribute("Capacite")
	if not Mouvement.estCapacite(brut) then
		return
	end
	local capacite = brut :: string
	local joueur = joueurVivant(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	if not joueur or not donnees then
		return
	end
	local liste = capacitesDe(donnees)
	if liste[capacite] == true then
		return -- déjà débloquée : le toucher ne fait rien (il se répète à chaque contact)
	end
	liste[capacite] = true
	capaciteDebloquee:FireClient(joueur, capacite)
	for _, fonction in abonnes do
		task.spawn(fonction, joueur, capacite)
	end
	-- Sauvegarde sans attendre la prochaine sauvegarde périodique : un déblocage ne doit pas se perdre.
	task.spawn(Donnees.sauvegarderMaintenant, joueur)
end

local function brancherPiece(piece: Instance)
	if not piece:IsA("BasePart") or liaisonsPieces[piece] then
		return
	end
	liaisonsPieces[piece] = piece.Touched:Connect(function(touche)
		surToucheDeblocage(piece, touche)
	end)
end

local function debrancherPiece(piece: Instance)
	local liaison = liaisonsPieces[piece]
	if liaison then
		liaison:Disconnect()
		liaisonsPieces[piece] = nil
	end
end

-- Surveillance ---------------------------------------------------------------------------------------------------

local function mesurer(joueur: Player, suivi: Suivi, maintenant: number)
	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	local donnees = Donnees.obtenir(joueur)
	if
		not personnage
		or not humanoide
		or humanoide.Health <= 0
		or not racine
		or not racine:IsA("BasePart")
		or not donnees
	then
		suivi.derniere = nil -- mort ou pas encore chargé : on repartira de la prochaine position
		return
	end

	local position = racine.Position
	local auSol = humanoide.FloorMaterial ~= Enum.Material.Air
	if suivi.derniere == nil or maintenant < suivi.ignorerJusqua then
		suivi.derniere = position
		suivi.instant = maintenant
		if auSol then
			suivi.valide = position
		end
		return
	end

	local delta = position - suivi.derniere
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local verdict = Mouvement.evaluerDeplacement(capacitesDe(donnees), horizontal, delta.Y, maintenant - suivi.instant)
	if verdict == nil then
		suivi.derniere = position
		suivi.instant = maintenant
		if auSol then
			suivi.valide = position
		end
		return
	end

	-- Déplacement impossible : retour à la dernière position valide, sans autre sanction.
	suivi.suspect = true
	suivi.alertes += 1
	local cible = suivi.valide or suivi.derniere
	warn(
		string.format(
			"[Capacites] %s : déplacement impossible (%s, %.0f studs sur le plan, %.0f de montée en %.2f s), ramené en arrière",
			joueur.Name,
			verdict,
			horizontal,
			delta.Y,
			maintenant - suivi.instant
		)
	)
	personnage:PivotTo(CFrame.new(cible) * racine.CFrame.Rotation)
	racine.AssemblyLinearVelocity = Vector3.zero
	suivi.derniere = cible
	suivi.instant = maintenant
	suivi.ignorerJusqua = maintenant + DELAI_CORRECTION
end

local function surveiller()
	local maintenant = os.clock()
	for joueur, suivi in suivis do
		local ok, erreur = pcall(mesurer, joueur, suivi, maintenant)
		if not ok then
			warn(`[Capacites] surveillance de {joueur.Name} : {erreur}`)
		end
	end
end

local function suivre(joueur: Player)
	if suivis[joueur] then
		return
	end
	suivis[joueur] = nouveauSuivi(os.clock(), DELAI_APPARITION)
	-- Une nouvelle apparition (mort, « Recommencer », renvoi au pied) : une nouvelle tentative, posée par le serveur.
	liaisonsPlayers[joueur] = joueur.CharacterAdded:Connect(function()
		suivis[joueur] = nouveauSuivi(os.clock(), DELAI_APPARITION)
	end)
end

local Capacites = {}

--- Rend true si un déplacement impossible a été vu depuis le début de la tentative en cours (la dernière
--- apparition du personnage, ou le dernier appel à nouvelleTentative) : cette tentative n'est pas classable.
function Capacites.tentativeSuspecte(joueur: Player): boolean
	local suivi = suivis[joueur]
	return suivi ~= nil and suivi.suspect
end

--- Efface la marque « suspect » : une nouvelle tentative commence (ex. le joueur repart du pied de l'ascension).
function Capacites.nouvelleTentative(joueur: Player)
	local suivi = suivis[joueur]
	if suivi then
		suivi.suspect = false
	end
end

--- À appeler quand le serveur déplace lui-même un joueur (étape passée, téléportation vers un palier, renvoi au
--- pied...), dans la même image que le `PivotTo` : le déplacement n'est pas comparé aux capacités.
function Capacites.autoriserTeleportation(joueur: Player)
	local suivi = suivis[joueur]
	if suivi then
		suivi.derniere = nil
		suivi.ignorerJusqua = math.max(suivi.ignorerJusqua, os.clock() + DELAI_TELEPORTATION)
	end
end

--- Les capacités débloquées du joueur (copie ; vide tant que ses données ne sont pas chargées).
function Capacites.debloquees(joueur: Player): { [string]: boolean }
	local donnees = Donnees.obtenir(joueur)
	local copie: { [string]: boolean } = {}
	if donnees then
		for nom, valeur in capacitesDe(donnees) do
			if valeur == true then
				copie[nom] = true
			end
		end
	end
	return copie
end

--- `fonction(joueur, capacite)` est appelée à chaque nouveau déblocage : le service de l'état de la course s'en sert
--- pour renvoyer son état (EtatCourse.capacites) au client.
function Capacites.surDeblocage(fonction: (Player, string) -> ())
	table.insert(abonnes, fonction)
end

function Capacites.demarrer()
	if demarre then
		return
	end
	demarre = true

	for _, piece in CollectionService:GetTagged(TAG) do
		brancherPiece(piece)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(brancherPiece)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(debrancherPiece)

	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		local liaison = liaisonsPlayers[joueur]
		if liaison then
			liaison:Disconnect()
			liaisonsPlayers[joueur] = nil
		end
		suivis[joueur] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Reglages.SURVEILLANCE_PERIODE)
			surveiller()
		end
	end)
end

return Capacites
