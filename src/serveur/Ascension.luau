--!strict
-- L'ascension au-dessus de Sup de Vinci : le vrai jeu après le tuto. Un empilement d'objets flottants, des étages
-- qui rapportent de l'aura (d'autant plus qu'ils sont hauts), un chrono du pied au sommet et la hauteur maximale
-- sauvegardée. Depuis la tour exigeante (docs/specs/2026-11-18-tour-exigeante.md), il n'y a **aucun palier** :
-- pas de checkpoint entre le pied et le sommet, pas de téléportation, tomber renvoie toujours au pied.
--
-- Contrats de la carte (tags posés par outils/monde/Ascension.luau) :
--   PiedAscension    la plateforme de départ : origine des hauteurs, et point de renvoi après une chute ;
--   EtageAscension   + Numero : pièce à toucher qui compte un étage franchi (aura croissante) ;
--   SommetAscension  l'arrivée : le chrono s'arrête ;
--   Mortel (déjà sous la ville, et les lasers de la tour) : tue, donc Humanoid.Died, donc réapparition — ramenée
--                    ici au pied.
--
-- Cohabitation avec src/serveur/Parcours.luau (qui replace le joueur à son checkpoint à chaque réapparition) :
-- ce service pose l'attribut `EnAscension` sur le joueur. Tant qu'il vaut true *et* que le joueur a fini le tuto,
-- Parcours ne place plus personne : la réapparition est à nous, au pied de l'ascension. « Avoir fini le tuto » est
-- `donnees.tutoFini`, sauvegardé : les deux côtés l'obtiennent par la même fonction (`Regles.ascensionOuverte`),
-- donc décident de la même chose dans n'importe quel ordre. « Recommencer » remet l'étape à 0 mais pas tutoFini :
-- l'ascension reste ouverte, mais la tentative en cours est abandonnée (Parcours nous prévient par
-- `Parcours.avantRecommencer`) et le joueur retourne au tuto. L'attribut repasse à false au chargement des données
-- et dès que le joueur quitte l'ascension.
-- L'aura des étages passe par Parcours.ajouterAura : même chemin que l'aura des checkpoints (liste des joueurs,
-- classement par lots, état renvoyé au client).
--
-- Cohabitation avec src/serveur/Capacites.luau (surveillance des déplacements) : chaque placement décidé ici (le
-- renvoi au pied) est suivi, dans la même image, de `Capacites.autoriserTeleportation` — sinon la surveillance le
-- prendrait pour un déplacement impossible et ramènerait le joueur en arrière. Un départ du pied appelle
-- `Capacites.nouvelleTentative` (la marque « suspect » repart de zéro), et `Capacites.tentativeSuspecte` décide si
-- la tentative reste classable.
--
-- Le serveur fait autorité : le client ne demande plus rien du tout pour l'ascension (le remote
-- DemanderTeleportPalier a disparu avec les paliers). Les règles d'aura et de classement sont pures et testées :
-- src/partage/Ascension.luau.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classement = require(script.Parent.Classement)
local Donnees = require(script.Parent.Donnees)
local Mesures = require(script.Parent.Mesures)
local Parcours = require(script.Parent.Parcours)
-- Surveillance des déplacements (serveur/Capacites). Pas de cycle : Ascension -> Parcours -> Capacites -> Donnees,
-- et le retour se fait par l'abonnement `Parcours.avantRecommencer`.
local Surveillance = require(script.Parent.Capacites)
local RegleAscension = require(ReplicatedStorage.Partage.Ascension)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

-- `pcall` d'une fonction qui ne rend rien : Luau déduit alors `(boolean)` et refuse `local ok, erreur = pcall(...)`, alors
-- qu'à l'exécution le second résultat est bien le message d'erreur. Cast local, sans effet à l'exécution.
local pcallAvecErreur: (...any) -> (boolean, any) = pcall :: any

local etatAscension: RemoteEvent

-- Attribut posé sur le Player : « c'est Ascension.luau qui place ce joueur » (lu par Parcours.luau).
local ATTRIBUT_EN_ASCENSION = Regles.ATTRIBUT_EN_ASCENSION
-- Hors tentative, l'état de l'ascension est renvoyé toutes ces secondes : un client qui pose sa connexion après le
-- chargement des données ne rate pas son record de hauteur (voir releverTous).
local PERIODE_ETAT_REPOS = 2

-- Une tentative en cours. Les deux premiers champs sont ceux de la règle pure (RegleAscension.Tentative).
type Tentative = {
	debut: number?, -- heure serveur du départ au pied ; nil après le sommet
	alertes: number,
	etages: { [number]: boolean }, -- étages déjà touchés pendant cette tentative (payés ou non)
	hauteur: number, -- dernière hauteur relevée, en studs au-dessus du pied
	hauteurEnvoyee: number, -- hauteur du dernier EtatAscension envoyé (pour ne pas parler à chaque relevé)
	recordSommet: boolean?, -- nil = sommet pas atteint ; sinon : le temps de tour est-il battu ? (son du client)
}

local tentatives: { [Player]: Tentative } = {}
local pied: BasePart? = nil
local etagesHauteur: { [number]: number } = {} -- hauteur du dessus de l'étage n (au-dessus du pied)
-- Renvoi au pied en cours (chute sous la hauteur de garde) : pas deux à la fois pour le même joueur.
local renvoiEnCours: { [Player]: boolean } = {}
-- os.clock() du dernier EtatAscension envoyé à un joueur hors tentative (voir releverTous).
local dernierEtatRepos: { [Player]: number } = {}

local function maintenant(): number
	return workspace:GetServerTimeNow()
end

--- La tentative n'est-elle plus classable pour une raison de surveillance ? Soit la surveillance des déplacements a vu
--- quelque chose d'impossible, soit le joueur a volé (mode testeur) depuis son dernier « Recommencer » : même chemin, donc
--- `tentative.alertes`. Un vol vaut pour toute tentative suivante tant que la course n'est pas recommencée.
local function surveillanceAlerte(joueur: Player): boolean
	return Surveillance.tentativeSuspecte(joueur) or Parcours.aVole(joueur)
end

--- Le joueur vivant derrière une pièce touchée, ou nil (même filtre que Parcours.luau).
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

--- Le dessus de la plateforme de départ : l'origine de toutes les hauteurs de l'ascension.
local function sommetDuPied(): number?
	local p = pied
	return if p then p.Position.Y + p.Size.Y / 2 else nil
end

--- Hauteur du joueur au-dessus du pied, ou nil s'il n'y a pas de pied, de personnage vivant, ou de racine.
local function hauteurDe(joueur: Player): number?
	local origine = sommetDuPied()
	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if origine == nil or not humanoide or humanoide.Health <= 0 or not racine or not racine:IsA("BasePart") then
		return nil
	end
	return racine.Position.Y - (origine :: number)
end

local function envoyerEtat(joueur: Player)
	local donnees = Donnees.obtenir(joueur)
	if not donnees then
		return
	end
	local tentative = tentatives[joueur]
	local classable = tentative ~= nil and RegleAscension.estClassable(tentative)
	etatAscension:FireClient(joueur, Remotes.etatAscension(tentative, donnees.meilleureHauteur, classable))
	if tentative then
		tentative.hauteurEnvoyee = tentative.hauteur
	end
end

--- Pose le personnage sur une plateforme, tourné vers +X comme ailleurs dans le jeu. Rend false s'il n'y a personne
--- à placer. Comme Parcours.luau, on attend la racine : à la réapparition, elle n'est pas toujours déjà là.
--- La surveillance des déplacements est prévenue dans la même image que le PivotTo : ce placement vient du serveur.
local function placerSur(joueur: Player, part: BasePart): boolean
	local personnage = joueur.Character
	if not personnage or not personnage:WaitForChild("HumanoidRootPart", 5) then
		return false
	end
	local position = part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)
	personnage:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
	-- Sans ça, un joueur replacé en pleine chute arrive avec sa vitesse de chute et retombe aussitôt.
	local racine = personnage:FindFirstChild("HumanoidRootPart")
	if racine and racine:IsA("BasePart") then
		racine.AssemblyLinearVelocity = Vector3.zero
	end
	Surveillance.autoriserTeleportation(joueur)
	return true
end

--- Nouvelle tentative : chrono à zéro, étages à repayer, et la tentative redevient classable.
local function demarrerTentative(joueur: Player)
	tentatives[joueur] = {
		debut = maintenant(),
		alertes = 0,
		etages = {},
		hauteur = 0,
		hauteurEnvoyee = 0,
		recordSommet = nil,
	}
	joueur:SetAttribute(ATTRIBUT_EN_ASCENSION, true)
	Surveillance.nouvelleTentative(joueur) -- la marque « suspect » de la surveillance repart de zéro
	envoyerEtat(joueur)
end

--- Le joueur n'est plus dans l'ascension : Parcours.luau reprend la main sur sa réapparition.
local function quitterAscension(joueur: Player)
	tentatives[joueur] = nil
	joueur:SetAttribute(ATTRIBUT_EN_ASCENSION, false)
	envoyerEtat(joueur)
end

--- Chute : le joueur repart du pied de l'ascension (jamais du checkpoint du tuto), tentative remise à zéro.
local function replacerAuPied(joueur: Player)
	local p = pied
	if not p or not placerSur(joueur, p) then
		-- Pas de pied dans la carte, ou racine jamais arrivée : on rend la main à Parcours, qui a déjà renoncé à
		-- cause de l'attribut. Sans ce rappel, le joueur resterait au point d'apparition de Roblox.
		quitterAscension(joueur)
		Parcours.placerAuCheckpoint(joueur)
		return
	end
	demarrerTentative(joueur)
end

--- Renvoi au pied après une chute, au plus un à la fois par joueur : `replacerAuPied` attend la racine (jusqu'à
--- 5 s), et le relevé suivant verrait le joueur encore en bas et le renverrait une seconde fois.
local function renvoyerApresChute(joueur: Player)
	if renvoiEnCours[joueur] then
		return
	end
	renvoiEnCours[joueur] = true
	task.spawn(function()
		local ok, erreur = pcallAvecErreur(replacerAuPied, joueur)
		renvoiEnCours[joueur] = nil
		if not ok then
			warn(`[Ascension] renvoi au pied de {joueur.Name} en échec : {erreur}`)
		end
	end)
end

--- L'ascension n'est ouverte qu'au joueur qui a fini le tuto (`tutoFini`, sauvegardé). C'est la même fonction que
--- celle de la dérogation de Parcours.placer : les deux services doivent dire la même chose, sinon ils se
--- disputent la réapparition.
local ascensionOuverte = Regles.ascensionOuverte

--- Toucher le pied (re)lance une tentative.
local function surPied(touche: BasePart)
	local joueur = joueurDepuis(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	if not joueur or not donnees or not ascensionOuverte(donnees) then
		return
	end
	local tentative = tentatives[joueur]
	if tentative and tentative.debut ~= nil and tentative.hauteur <= Reglages.ASCENSION_SEUIL_DEPART then
		return -- déjà posé au départ : rester là ne remet pas le chrono à zéro sans arrêt
	end
	Mesures.piedTour(joueur, Parcours.aVole(joueur))
	demarrerTentative(joueur)
end

--- Un étage franchi pour la première fois de cette tentative rapporte son aura (croissante avec la hauteur).
--- Qui paie ou non est décidé par la règle pure `etagePaye` : sans paliers, tous les étages d'une tentative partie
--- du pied paient, et une alerte de la surveillance coupe tout.
--- L'étage est marqué comme franchi dans tous les cas : il ne se repaie pas en retouchant la pièce.
local function surEtage(numero: number, touche: BasePart)
	local joueur = joueurDepuis(touche)
	local tentative = joueur and tentatives[joueur]
	if not joueur or not tentative or tentative.etages[numero] then
		return
	end
	tentative.etages[numero] = true
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1
	end
	local hauteur = etagesHauteur[numero]
	if hauteur == nil or not RegleAscension.etagePaye(tentative, hauteur) then
		return
	end
	Parcours.ajouterAura(joueur, RegleAscension.auraEtage(numero, Reglages))
end

--- Le sommet : le chrono s'arrête, et le temps est classé si la tentative est restée honnête.
local function surSommet(touche: BasePart)
	local joueur = joueurDepuis(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	local tentative = joueur and tentatives[joueur]
	if not joueur or not donnees or not tentative or tentative.debut == nil then
		return
	end
	Mesures.sommetTour(joueur, Parcours.aVole(joueur))
	local duree = maintenant() - (tentative.debut :: number)
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1 -- dernier mot de la surveillance avant de classer
	end
	local classable = RegleAscension.estClassable(tentative)
	tentative.debut = nil -- le chrono s'arrête
	-- Un temps plus court qu'ASCENSION_TEMPS_MIN_CLASSABLE est impossible à la main : il n'entre pas au classement.
	local record = RegleAscension.estRecordTemps(
		donnees.meilleurTempsAscension,
		duree,
		classable,
		Reglages.ASCENSION_TEMPS_MIN_CLASSABLE
	)
	tentative.recordSommet = record
	if record then
		donnees.meilleurTempsAscension = duree
		Classement.soumettreAscension(joueur, duree)
	end
	envoyerEtat(joueur)
end

--- Relevé d'un joueur : hauteur suivie, record sauvegardé, alertes de surveillance, état renvoyé si utile.
local function relever(joueur: Player, tentative: Tentative)
	local hauteur = hauteurDe(joueur)
	local donnees = Donnees.obtenir(joueur)
	if hauteur == nil or donnees == nil then
		return
	end
	-- « Tomber renvoie au pied » : en dehors des lasers, rien n'est mortel dans la tour, et une chute se termine
	-- sur le toit de Sup de Vinci (10 studs sous le pied), où le joueur survivait avec sa tentative et son chrono
	-- — et où retoucher le pied en remontant ne relançait rien (il était déjà sous ASCENSION_SEUIL_DEPART). Sous
	-- la hauteur de garde, on le repose au pied et la tentative recommence.
	if hauteur < Reglages.ASCENSION_HAUTEUR_GARDE then
		renvoyerApresChute(joueur)
		return
	end
	tentative.hauteur = hauteur
	local etaitClassable = tentative.alertes == 0
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1 -- la tentative n'est plus classable (anti-triche, serveur/Capacites, ou vol)
	end
	-- Une tentative surveillée comme impossible ne monte plus personne au classement de la hauteur.
	local studs = RegleAscension.versStudsEntiers(hauteur)
	if tentative.alertes == 0 and RegleAscension.estRecordHauteur(donnees.meilleureHauteur, studs) then
		donnees.meilleureHauteur = studs
		Classement.signalerHauteur(joueur, studs)
	end
	-- « Non classé » doit s'afficher tout de suite, pas au prochain mouvement de hauteur.
	if
		(etaitClassable and tentative.alertes > 0)
		or math.abs(hauteur - tentative.hauteurEnvoyee) >= Reglages.ASCENSION_PAS_ETAT
	then
		envoyerEtat(joueur)
	end
end

--- Le tour de tous les joueurs. Ceux qui montent sont relevés à chaque tour ; les autres reçoivent l'état de
--- l'ascension toutes les PERIODE_ETAT_REPOS secondes, s'ils ont un record de hauteur à montrer.
--- Pourquoi ce rappel : hors tentative, l'état ne partait qu'une fois, au chargement des données — souvent avant
--- que le client ait posé sa connexion (`Hud.monter` tourne après `Evenements.demarrer()` et `Capacites.demarrer()`).
--- Le message était perdu et le record n'apparaissait jamais pour un joueur de retour. Un envoi lent et répété
--- plutôt qu'un envoi retardé : rien à deviner sur le moment où le client est prêt, et l'interface se rattrape
--- aussi quand elle se reconstruit (changement de personnage, rechargement d'un bout de HUD). La charge est
--- minuscule (cinq champs) et les joueurs en tentative, eux, ne passent pas par là.
--- Chacun dans son pcall : une erreur chez l'un n'éteint pas le suivi pour tout le serveur (sinon plus de hauteur,
--- plus de record, plus d'état envoyé jusqu'au redémarrage).
local function releverTous()
	for joueur, tentative in tentatives do
		local ok, erreur = pcallAvecErreur(relever, joueur, tentative)
		if not ok then
			warn(`[Ascension] relevé de {joueur.Name} en échec : {erreur}`)
		end
	end
	local instant = os.clock()
	for _, joueur in Players:GetPlayers() do
		if tentatives[joueur] == nil and instant - (dernierEtatRepos[joueur] or -math.huge) >= PERIODE_ETAT_REPOS then
			-- Rien à montrer (aucun record, le cas de presque tout le monde pendant le tuto) : le premier envoi de
			-- `surChargement` suffit, on ne répète pas. Les données pas encore chargées attendent aussi :
			-- `surChargement` enverra l'état à leur arrivée.
			local donnees = Donnees.obtenir(joueur)
			if donnees and RegleAscension.aQuelqueChoseAMontrer(donnees.meilleureHauteur) then
				dernierEtatRepos[joueur] = instant
				local ok, erreur = pcallAvecErreur(envoyerEtat, joueur)
				if not ok then
					warn(`[Ascension] état hors tentative de {joueur.Name} en échec : {erreur}`)
				end
			end
		end
	end
end

--- Réapparition : au pied si le joueur est dans l'ascension, sinon on laisse Parcours.luau faire son travail.
local function surPersonnage(joueur: Player)
	-- Nouveau personnage : l'interface se reconstruit, l'état doit repartir tout de suite (les deux branches
	-- ci-dessous l'envoient ; si les données ne sont pas encore chargées, c'est le rappel périodique qui le fera).
	dernierEtatRepos[joueur] = nil
	local donnees = Donnees.obtenir(joueur)
	if not donnees then
		return
	end
	if not ascensionOuverte(donnees) or tentatives[joueur] == nil then
		quitterAscension(joueur)
		return
	end
	-- Après les autres abonnés de CharacterAdded (dont Parcours, qui nous laisse la main par l'attribut).
	task.defer(replacerAuPied, joueur)
end

local function surChargement(joueur: Player)
	tentatives[joueur] = nil
	renvoiEnCours[joueur] = nil
	dernierEtatRepos[joueur] = nil -- l'état repart au prochain tour, puis toutes les PERIODE_ETAT_REPOS secondes
	joueur:SetAttribute(ATTRIBUT_EN_ASCENSION, false) -- on entre dans l'ascension en touchant son pied
	envoyerEtat(joueur)
end

local function lirePied()
	for _, part in CollectionService:GetTagged("PiedAscension") do
		if not part:IsA("BasePart") then
			continue
		end
		if pied then
			-- Une seule plateforme de départ : c'est l'origine des hauteurs, deux donneraient deux repères.
			warn(`[Ascension] plusieurs pièces PiedAscension : {part:GetFullName()} ignorée`)
			continue
		end
		pied = part
		part.Touched:Connect(surPied)
	end
	if not pied then
		warn("[Ascension] aucune pièce PiedAscension dans la carte : pas d'ascension (monde/Ascension.rbxm)")
	end
end

local function lireEtagesEtSommet()
	for _, part in CollectionService:GetTagged("EtageAscension") do
		local numero = part:GetAttribute("Numero")
		if part:IsA("BasePart") and typeof(numero) == "number" then
			local n = numero :: number
			-- Dessus de l'étage au-dessus du pied : sert aux contrôles de la carte et au journal.
			etagesHauteur[n] = part.Position.Y + part.Size.Y / 2 - (sommetDuPied() or 0)
			part.Touched:Connect(function(touche)
				surEtage(n, touche)
			end)
		else
			warn(`[Ascension] étage ignoré : {part:GetFullName()} (attribut Numero attendu)`)
		end
	end
	for _, part in CollectionService:GetTagged("SommetAscension") do
		if part:IsA("BasePart") then
			part.Touched:Connect(surSommet)
		end
	end
end

local Ascension = {}

function Ascension.demarrer()
	etatAscension = Remotes.obtenir("EtatAscension")
	lirePied()
	lireEtagesEtSommet()

	Donnees.surChargement(surChargement)
	-- « Recommencer » renvoie au tuto : la tentative d'ascension est abandonnée (jamais classée : le chrono et le
	-- classement ne se règlent qu'au sommet), le record de hauteur et tutoFini restent acquis.
	Parcours.avantRecommencer(quitterAscension)

	local function suivre(joueur: Player)
		joueur.CharacterAdded:Connect(function()
			surPersonnage(joueur)
		end)
	end
	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		Classement.envoyerHauteur(joueur) -- dernière hauteur connue, sans attendre le prochain lot
		tentatives[joueur] = nil
		renvoiEnCours[joueur] = nil
		dernierEtatRepos[joueur] = nil
	end)

	task.spawn(function()
		while true do
			releverTous()
			task.wait(Reglages.ASCENSION_PERIODE_SUIVI)
		end
	end)
end

return Ascension
