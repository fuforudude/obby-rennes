--!strict
-- Les capacités de déplacement, côté serveur : déblocage (pièces tagées `DeblocageCapacite` + attribut `Capacite`),
-- et surveillance des déplacements. Le client bouge son personnage (course, double saut, dash : client/Capacites.luau),
-- le serveur vérifie que ce qu'il observe reste possible avec les capacités débloquées. Il ne tue jamais et
-- n'expulse jamais : un déplacement impossible est corrigé (retour à la dernière position valide) et la tentative
-- d'ascension en cours est marquée non classable (Capacites.tentativeSuspecte, lu par serveur/Ascension).
--
-- Surveillance : la position de la racine du personnage est relevée toutes les SURVEILLANCE_PERIODE secondes, et
-- comparée à celle d'il y a SURVEILLANCE_FENETRE secondes — une fenêtre glissante, et non le relevé précédent :
-- sur une demi-seconde, le terme fixe du maximum (la hauteur d'un envol) laissait passer un script de vol.
-- La règle est pure et testée (partage/Capacites : empiler, evaluerFenetre). Les déplacements que
-- le serveur décide lui-même (réapparition, étape passée, renvoi au pied de l'ascension) ne sont pas
-- de la triche : le code qui téléporte un joueur appelle `Capacites.autoriserTeleportation(joueur)` au même moment
-- (la réapparition est déjà couverte ici). Sans cet appel, la téléportation serait prise pour un déplacement
-- impossible et le joueur serait ramené en arrière.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Mouvement = require(ReplicatedStorage.Partage.Capacites)
local RegleEffets = require(ReplicatedStorage.Partage.EffetsCapacites)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

-- `pcall` d'une fonction qui ne rend rien : Luau déduit alors `(boolean)` et refuse `local ok, erreur = pcall(...)`, alors
-- qu'à l'exécution le second résultat est bien le message d'erreur. Cast local, sans effet à l'exécution.
local pcallAvecErreur: (...any) -> (boolean, any) = pcall :: any

local TAG = "DeblocageCapacite"
-- Après une apparition (ou une téléportation décidée par le serveur), on ne compare plus pendant ce délai (s) : le
-- personnage est posé quelque part par un autre service, et la réplication de sa position arrive avec du retard.
local DELAI_APPARITION = 3
local DELAI_TELEPORTATION = 1.5
local DELAI_CORRECTION = 1 -- après un retour en arrière : le temps que le client applique la correction

local capaciteDebloquee: RemoteEvent
local signalerEffet: RemoteEvent
local effetCapacite: RemoteEvent

-- Suivi d'un joueur : les relevés de la fenêtre glissante, la dernière position valide (au sol), et l'état de la
-- tentative.
type Suivi = {
	tampon: Mouvement.Tampon, -- relevés de la fenêtre (vide : elle se reconstruit, aucun verdict possible)
	valide: Vector3?, -- dernière position valide, au sol
	ignorerJusqua: number, -- os.clock() : avant cet instant, on ne relève rien (position pas fiable)
	suspect: boolean, -- un déplacement impossible a été vu pendant cette tentative
	alertes: number,
	enVol: boolean, -- le joueur vole (accordé par serveur/Vol) : aucun verdict, la fenêtre se réamorce à chaque relevé
}

local suivis: { [Player]: Suivi } = {}
local liaisonsPlayers: { [Player]: RBXScriptConnection } = {}
local liaisonsPieces: { [Instance]: RBXScriptConnection } = {}
local derniersEffets: { [Player]: { [string]: number } } = {} -- par joueur : l'heure du dernier effet relayé, par capacité
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
		tampon = {},
		valide = nil,
		ignorerJusqua = maintenant + delaiIgnore,
		suspect = false,
		alertes = 0,
		enVol = false, -- une nouvelle apparition ne vole jamais
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
		table.clear(suivi.tampon) -- mort ou pas encore chargé : la fenêtre se reconstruira
		return
	end

	local position = racine.Position
	local auSol = humanoide.FloorMaterial ~= Enum.Material.Air
	if maintenant < suivi.ignorerJusqua then
		-- Apparition, téléportation décidée par le serveur, correction : la position répliquée n'est pas fiable.
		-- On ne prend aucun relevé : un relevé pris maintenant servirait de référence fausse à la fenêtre suivante
		-- et ferait refuser un déplacement légitime. Le tampon, lui, n'est pas touché : il est vide, ou ne contient
		-- que la destination posée par `autoriserTeleportation`, qui sert de référence au premier relevé d'après.
		if auSol then
			suivi.valide = position
		end
		return
	end

	local verdict, mesure = Mouvement.mesurer(
		suivi.tampon,
		suivi.enVol,
		capacitesDe(donnees),
		{ instant = maintenant, x = position.X, y = position.Y, z = position.Z }
	)
	if verdict == nil or mesure == nil then
		-- En vol, toute position est valide : si une alerte tombe juste après la sortie, on ramène le joueur là où il a
		-- cessé de voler, pas à un sol d'avant le vol.
		if auSol or suivi.enVol then
			suivi.valide = position
		end
		return
	end

	-- Déplacement impossible sur toute la fenêtre : retour à la dernière position valide, sans autre sanction.
	suivi.suspect = true
	suivi.alertes += 1
	local debut = suivi.tampon[1]
	local cible = suivi.valide or Vector3.new(debut.x, debut.y, debut.z)
	warn(
		string.format(
			"[Capacites] %s : déplacement impossible (%s, %.0f studs sur le plan, %.0f de montée en %.2f s), ramené en arrière",
			joueur.Name,
			verdict,
			mesure.horizontal,
			mesure.montee,
			mesure.duree
		)
	)
	personnage:PivotTo(CFrame.new(cible) * racine.CFrame.Rotation)
	racine.AssemblyLinearVelocity = Vector3.zero
	table.clear(suivi.tampon)
	suivi.ignorerJusqua = maintenant + DELAI_CORRECTION
end

local function surveiller()
	local maintenant = os.clock()
	for joueur, suivi in suivis do
		local ok, erreur = pcallAvecErreur(mesurer, joueur, suivi, maintenant)
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

--- Le tampon repart de la position actuelle de la racine du joueur (seul relevé), qui devient aussi sa dernière position
--- valide. Sans racine, le tampon est vidé : la fenêtre se reconstruira.
local function amorcerSurRacine(joueur: Player, suivi: Suivi, maintenant: number)
	local personnage = joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if racine and racine:IsA("BasePart") then
		local position = racine.Position
		Mouvement.amorcer(suivi.tampon, maintenant, position.X, position.Y, position.Z)
		suivi.valide = position
	else
		table.clear(suivi.tampon)
	end
end

--- À appeler quand le serveur déplace lui-même un joueur (étape passée, renvoi au pied de l'ascension...), dans la
--- même image que le `PivotTo` : le déplacement n'est pas comparé aux capacités.
function Capacites.autoriserTeleportation(joueur: Player)
	local suivi = suivis[joueur]
	if not suivi then
		return
	end
	local maintenant = os.clock()
	-- Le délai ne sert qu'à ignorer la position répliquée, pas fiable un instant : il ne suspend pas la surveillance.
	-- Le tampon repart de la destination (la racine vient d'être placée, dans cette même image), et la première
	-- mesure d'après le délai est comparée à elle : sans quoi des téléportations rapprochées laisseraient la
	-- surveillance aveugle entre deux, le temps de voler en toute impunité. La destination est aussi la dernière
	-- position valide : si une alerte tombe, on ramène le joueur là, pas là où il était avant d'être téléporté.
	suivi.ignorerJusqua = math.max(suivi.ignorerJusqua, maintenant + DELAI_TELEPORTATION)
	amorcerSurRacine(joueur, suivi, maintenant)
end

--- Le joueur se met à voler (accordé par serveur/Vol, qui vérifie la liste des testeurs et appelle ceci seulement
--- après avoir marqué sa course non classable). La surveillance ne juge plus ses déplacements, et la fenêtre repart de
--- sa position : rien de ce qu'il a fait avant ne sert de référence à ce qu'il fait en volant.
function Capacites.entrerVol(joueur: Player)
	local suivi = suivis[joueur]
	if not suivi then
		return
	end
	suivi.enVol = true
	amorcerSurRacine(joueur, suivi, os.clock())
end

--- Le joueur ne vole plus (il l'a demandé, il est mort, il part). La surveillance REPREND TOUT DE SUITE, sans délai
--- ignoré : la fenêtre est amorcée sur la position de sortie, et le prochain relevé (au plus SURVEILLANCE_PERIODE plus
--- tard) est comparé à elle comme n'importe quel déplacement. Même correction que pour la téléportation (voir
--- autoriserTeleportation) : suspendre pour un temps laisserait une fenêtre sans contrôle, qu'un client pourrait
--- rouvrir en rebasculant. Ne touche pas à `ignorerJusqua` : une apparition ou une téléportation du serveur en cours garde
--- son délai légitime.
function Capacites.sortirVol(joueur: Player)
	local suivi = suivis[joueur]
	if not suivi or not suivi.enVol then
		return
	end
	suivi.enVol = false
	-- Le geste (la fenêtre repart de la sortie) est celui de la fonction pure Mouvement.sortirVol, testée telle quelle.
	local personnage = joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if racine and racine:IsA("BasePart") then
		local position = racine.Position
		Mouvement.sortirVol(suivi.tampon, { instant = os.clock(), x = position.X, y = position.Y, z = position.Z })
		suivi.valide = position
	else
		Mouvement.sortirVol(suivi.tampon, nil)
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

-- Effets visibles ------------------------------------------------------------------------------------------------------
-- Le client qui fait un dash ou un double saut joue son effet tout de suite, puis envoie SignalerEffet(capacite). Le
-- serveur ne fait confiance à rien : type, capacité relayable et débloquée, joueur vivant, cadence (la règle est pure et
-- testée : partage/EffetsCapacites.accepter, qui n'enregistre l'heure qu'une fois la validation passée). Accepté, il
-- diffuse EffetCapacite(joueur, capacite) aux AUTRES joueurs à moins de EFFET_DISTANCE_MAX studs (celui d'origine l'a
-- déjà joué ; les plus loin ne verraient rien, on ne leur envoie rien). Le serveur ne joue
-- rien lui-même : un tricheur qui spamme n'obtient au pire qu'un effet cosmétique par capacité et par 0,3 s.

local function surSignalerEffet(joueur: Player, capacite: unknown)
	local derniers = derniersEffets[joueur]
	if not derniers then
		derniers = {}
		derniersEffets[joueur] = derniers
	end
	local accepte = RegleEffets.accepter(derniers, capacite, os.clock(), Reglages.EFFET_DELAI_MIN, function()
		local personnage = joueur.Character
		local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
		return {
			vivant = humanoide ~= nil and humanoide.Health > 0,
			debloquees = Capacites.debloquees(joueur),
		}
	end)
	if not accepte then
		return
	end
	-- Le filtre de distance se fait ici (même constante que le client) pour ne pas envoyer l'effet à ceux qui ne le
	-- verraient pas ; le client garde le sien, qui le protège du streaming. Un joueur sans personnage reçoit tout de
	-- même l'effet : le client décidera.
	local personnage = joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not racine or not racine:IsA("BasePart") then
		return
	end
	for _, autre in Players:GetPlayers() do
		if autre ~= joueur then
			local racineAutre = autre.Character and autre.Character:FindFirstChild("HumanoidRootPart")
			local proche = true
			if racineAutre and racineAutre:IsA("BasePart") then
				local distance = (racineAutre.Position - racine.Position).Magnitude
				proche = RegleEffets.assezProche(distance, Reglages.EFFET_DISTANCE_MAX)
			end
			if proche then
				effetCapacite:FireClient(autre, joueur, capacite)
			end
		end
	end
end

function Capacites.demarrer()
	if demarre then
		return
	end
	demarre = true
	capaciteDebloquee = Remotes.obtenir("CapaciteDebloquee")
	signalerEffet = Remotes.obtenir("SignalerEffet")
	effetCapacite = Remotes.obtenir("EffetCapacite")

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
		derniersEffets[joueur] = nil
	end)
	signalerEffet.OnServerEvent:Connect(surSignalerEffet)

	task.spawn(function()
		while true do
			task.wait(Reglages.SURVEILLANCE_PERIODE)
			surveiller()
		end
	end)
end

return Capacites
