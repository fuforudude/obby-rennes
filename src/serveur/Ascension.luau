--!strict
-- L'ascension au-dessus de Sup de Vinci : le vrai jeu après le tuto. Un empilement d'objets flottants, des étages
-- qui rapportent de l'aura (d'autant plus qu'ils sont hauts), 4 à 5 paliers acquis définitivement, un chrono du
-- pied au sommet, la hauteur maximale sauvegardée, et la téléportation vers un palier déjà débloqué.
--
-- Contrats de la carte (tags posés par outils/monde/Ascension.luau) :
--   PiedAscension    la plateforme de départ : origine des hauteurs, et point de renvoi après une chute ;
--   Palier           + Numero (1 à 5) + Hauteur (Y absolu) + HauteurRelative (au-dessus du pied) : plateforme de
--                    palier, débloquée définitivement au toucher ;
--   EtageAscension   + Numero : pièce à toucher qui compte un étage franchi (aura croissante) ;
--   SommetAscension  l'arrivée : le chrono s'arrête ;
--   Mortel (déjà sous la ville) : tue, donc Humanoid.Died, donc réapparition — ramenée ici au pied.
-- La hauteur d'un palier est lue dans sa géométrie (son dessus au-dessus du dessus du pied), pas dans un attribut :
-- c'est le même repère que la hauteur mesurée pour le joueur. `Hauteur` reste le Y absolu (jamais lu ici) ;
-- `HauteurRelative` (la hauteur au-dessus du pied, celle que le serveur et l'interface utilisent) n'est qu'un
-- contrôle, et un écart avec la géométrie est signalé dans la console (la carte et le serveur ne diraient pas la
-- même chose au joueur).
--
-- Cohabitation avec src/serveur/Parcours.luau (qui replace le joueur à son checkpoint à chaque réapparition) :
-- ce service pose l'attribut `EnAscension` sur le joueur. Tant qu'il vaut true *et* que le joueur a fini le tuto,
-- Parcours ne place plus personne : la réapparition est à nous, au pied de l'ascension. « Avoir fini le tuto » est
-- `donnees.tutoFini`, sauvegardé : les deux côtés l'obtiennent par la même fonction (`Regles.ascensionOuverte`),
-- donc décident de la même chose dans n'importe quel ordre. « Recommencer » remet l'étape à 0 mais pas tutoFini :
-- il ne referme pas l'ascension. L'attribut repasse à false au chargement des données et dès que le joueur
-- quitte l'ascension.
-- La téléportation vers un palier débloqué marche aussi hors tentative (depuis la coloc) : elle ouvre alors une
-- tentative d'ascension, non classée.
-- L'aura des étages passe par Parcours.ajouterAura : même chemin que l'aura des checkpoints (liste des joueurs,
-- classement par lots, état renvoyé au client).
--
-- Cohabitation avec src/serveur/Capacites.luau (surveillance des déplacements, Gameplay A) : chaque placement
-- décidé ici (téléportation vers un palier, renvoi au pied) est suivi, dans la même image, de
-- `Capacites.autoriserTeleportation` — sinon la surveillance le prendrait pour un déplacement impossible et
-- ramènerait le joueur en arrière. Un départ du pied appelle `Capacites.nouvelleTentative` (la marque « suspect »
-- repart de zéro), et `Capacites.tentativeSuspecte` décide si la tentative reste classable. Ce module est chargé
-- avec un test d'existence : il arrive par une autre branche et le serveur doit tourner sans lui.
--
-- Le serveur fait autorité : le client ne demande qu'une téléportation, validée par la règle pure et testée
-- src/partage/Ascension.luau. Rien d'autre ne vient du client.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classement = require(script.Parent.Classement)
local Donnees = require(script.Parent.Donnees)
local Parcours = require(script.Parent.Parcours)
local RegleAscension = require(ReplicatedStorage.Partage.Ascension)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local etatAscension = Remotes.obtenir("EtatAscension")
local demanderTeleportPalier = Remotes.obtenir("DemanderTeleportPalier")

-- Attribut posé sur le Player : « c'est Ascension.luau qui place ce joueur » (lu par Parcours.luau).
local ATTRIBUT_EN_ASCENSION = "EnAscension"
-- Écart toléré entre l'attribut HauteurRelative d'un palier et sa position réelle, avant avertissement (studs).
local ECART_HAUTEUR_PALIER = 10

-- Une tentative en cours. Les trois premiers champs sont ceux de la règle pure (RegleAscension.Tentative).
type Tentative = {
	debut: number?, -- heure serveur du départ au pied ; nil après le sommet
	teleportations: number,
	alertes: number,
	hauteurMinimumPayante: number?, -- après une téléportation : seuil d'aura des étages (règle pure)
	etages: { [number]: boolean }, -- étages déjà touchés pendant cette tentative (payés ou non)
	hauteur: number, -- dernière hauteur relevée, en studs au-dessus du pied
	hauteurEnvoyee: number, -- hauteur du dernier EtatAscension envoyé (pour ne pas parler à chaque relevé)
}

local tentatives: { [Player]: Tentative } = {}
local derniereTeleport: { [Player]: number } = {}
local pied: BasePart? = nil
local paliersParts: { [number]: BasePart } = {}
local paliersHauteur: { number } = {} -- hauteur du palier n (au-dessus du pied) en paliersHauteur[n]
local etagesHauteur: { [number]: number } = {} -- hauteur du dessus de l'étage n (au-dessus du pied)
-- src/serveur/Capacites.luau (Gameplay A), s'il est là : surveillance des déplacements et placements autorisés.
local capacites: any = nil

local function maintenant(): number
	return workspace:GetServerTimeNow()
end

--- Appelle une fonction de serveur/Capacites si le module est là. Jamais fatal, mais une erreur se voit : sans
--- `autoriserTeleportation`, chaque placement décidé par le serveur serait pris pour de la triche.
local function appelerCapacites(nom: string, joueur: Player)
	local fonction = if capacites then capacites[nom] else nil
	if typeof(fonction) ~= "function" then
		return
	end
	local ok, erreur = pcall(fonction, joueur)
	if not ok then
		warn(`[Ascension] Capacites.{nom} en échec : {erreur}`)
	end
end

--- La surveillance des déplacements a-t-elle vu quelque chose d'impossible dans cette tentative ?
local function surveillanceAlerte(joueur: Player): boolean
	local fonction = if capacites then capacites.tentativeSuspecte else nil
	if typeof(fonction) ~= "function" then
		return false
	end
	local ok, suspecte = pcall(fonction, joueur)
	return ok and suspecte == true
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
	etatAscension:FireClient(joueur, {
		enAscension = tentative ~= nil,
		hauteur = if tentative then tentative.hauteur else 0,
		meilleureHauteur = donnees.meilleureHauteur,
		paliers = table.clone(donnees.paliers),
		debut = if tentative then tentative.debut else nil,
		classable = tentative ~= nil and RegleAscension.estClassable(tentative),
	})
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
	-- Sans ça, un joueur téléporté en pleine chute arrive avec sa vitesse de chute et retombe aussitôt.
	local racine = personnage:FindFirstChild("HumanoidRootPart")
	if racine and racine:IsA("BasePart") then
		racine.AssemblyLinearVelocity = Vector3.zero
	end
	appelerCapacites("autoriserTeleportation", joueur)
	return true
end

--- Nouvelle tentative : chrono à zéro, étages à repayer, et la tentative redevient classable.
local function demarrerTentative(joueur: Player)
	tentatives[joueur] = {
		debut = maintenant(),
		teleportations = 0,
		alertes = 0,
		hauteurMinimumPayante = nil,
		etages = {},
		hauteur = 0,
		hauteurEnvoyee = 0,
	}
	joueur:SetAttribute(ATTRIBUT_EN_ASCENSION, true)
	appelerCapacites("nouvelleTentative", joueur) -- la marque « suspect » de la surveillance repart de zéro
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
	demarrerTentative(joueur)
end

--- Un étage franchi pour la première fois de cette tentative rapporte son aura (croissante avec la hauteur).
--- Qui paie ou non est décidé par la règle pure `etagePaye` : après une téléportation vers le palier N, seuls les
--- étages au-dessus de ce palier paient (monter reste récompensé, mais se téléporter au sommet ne rapporte pas
--- les étages d'en dessous) ; une alerte de la surveillance coupe tout.
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

--- Un palier touché est acquis définitivement, avec tous ceux d'en dessous (on ne peut pas être là sans les avoir
--- passés — un joueur qui saute par-dessus un palier ne perd pas les précédents).
--- Un palier débloqué est la seule chose irréversible du jalon : il faut une vraie tentative, le tuto fini, et
--- aucune alerte de la surveillance (le Touched arrive avant que serveur/Capacites ramène le tricheur en arrière,
--- donc on refuse aussi sur une alerte vue plus tôt dans la tentative).
local function surPalier(numero: number, touche: BasePart)
	local joueur = joueurDepuis(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	local tentative = joueur and tentatives[joueur]
	if not joueur or not donnees or not tentative or not ascensionOuverte(donnees) then
		return
	end
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1
	end
	if tentative.alertes > 0 then
		return
	end
	local hauteur = tentative.hauteur
	local nouveau = false
	for n = 1, math.max(numero, RegleAscension.palierPour(hauteur, paliersHauteur)) do
		if table.find(donnees.paliers, n) == nil then
			table.insert(donnees.paliers, n)
			nouveau = true
		end
	end
	if nouveau then
		table.sort(donnees.paliers)
		envoyerEtat(joueur)
	end
end

--- Le sommet : le chrono s'arrête, et le temps est classé si la tentative est restée honnête.
local function surSommet(touche: BasePart)
	local joueur = joueurDepuis(touche)
	local donnees = joueur and Donnees.obtenir(joueur)
	local tentative = joueur and tentatives[joueur]
	if not joueur or not donnees or not tentative or tentative.debut == nil then
		return
	end
	local duree = maintenant() - (tentative.debut :: number)
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1 -- dernier mot de la surveillance avant de classer
	end
	local classable = RegleAscension.estClassable(tentative)
	tentative.debut = nil -- le chrono s'arrête
	-- Un temps plus court qu'ASCENSION_TEMPS_MIN_CLASSABLE est impossible à la main : il n'entre pas au classement
	-- (un pied ou un sommet mal placés dans la carte y inscriraient sinon un temps imbattable, pour toujours).
	if
		classable
		and duree >= Reglages.ASCENSION_TEMPS_MIN_CLASSABLE
		and Regles.estRecord(donnees.meilleurTempsAscension, duree)
	then
		donnees.meilleurTempsAscension = duree
		Classement.soumettreAscension(joueur, duree)
	end
	envoyerEtat(joueur)
end

--- « Téléporte-moi au palier n » : la règle pure décide (cadence, type, palier connu et débloqué), puis on place.
--- Marche aussi depuis la coloc (hors tentative) dès que le tuto est fini : la téléportation ouvre alors une
--- tentative d'ascension, comme toucher le pied, mais déjà non classée.
local function surDemandeTeleport(joueur: Player, numero: unknown)
	local accepte = RegleAscension.traiterTeleport(
		derniereTeleport,
		joueur,
		os.clock(),
		Reglages.PALIER_DELAI_TELEPORT,
		function()
			local donnees = Donnees.obtenir(joueur)
			return {
				numero = numero,
				-- Ascension ouverte (tuto fini) et personnage vivant ; pas besoin d'être déjà dans une tentative.
				enAscension = donnees ~= nil and ascensionOuverte(donnees) and hauteurDe(joueur) ~= nil,
				paliersCarte = paliersHauteur,
				paliersDebloques = if donnees then donnees.paliers else {},
			}
		end
	)
	if not accepte then
		return -- requête invalide : ignorée sans erreur
	end
	local part = paliersParts[numero :: number]
	if not part then
		return
	end
	local ouverte = tentatives[joueur] == nil
	if ouverte then
		demarrerTentative(joueur) -- depuis la coloc : Parcours ne replacera plus ce joueur (attribut EnAscension)
	end
	local tentative = tentatives[joueur]
	if not tentative or not placerSur(joueur, part) then
		if ouverte then
			quitterAscension(joueur) -- rien n'a pu être placé : on ne laisse pas une tentative ouverte pour rien
		end
		return
	end
	tentative.teleportations += 1 -- la tentative en cours n'est plus classable
	-- Les étages au-dessus du palier d'arrivée paient normalement, ceux en dessous ne paient rien.
	tentative.hauteurMinimumPayante =
		RegleAscension.hauteurMinimumPayante(paliersHauteur[numero :: number], Reglages.ASCENSION_MARGE_PALIER)
	envoyerEtat(joueur)
end

--- Relevé d'un joueur : hauteur suivie, record sauvegardé, alertes de surveillance, état renvoyé si utile.
local function relever(joueur: Player, tentative: Tentative)
	local hauteur = hauteurDe(joueur)
	local donnees = Donnees.obtenir(joueur)
	if hauteur == nil or donnees == nil then
		return
	end
	tentative.hauteur = hauteur
	if surveillanceAlerte(joueur) then
		tentative.alertes += 1 -- la tentative n'est plus classable (anti-triche, serveur/Capacites)
	end
	-- Une tentative surveillée comme impossible ne monte plus personne au classement de la hauteur ; une
	-- téléportation vers un palier déjà gagné, elle, ne retire rien à la hauteur réellement atteinte.
	local studs = RegleAscension.versStudsEntiers(hauteur)
	if tentative.alertes == 0 and RegleAscension.estRecordHauteur(donnees.meilleureHauteur, studs) then
		donnees.meilleureHauteur = studs
		Classement.signalerHauteur(joueur, studs)
	end
	if math.abs(hauteur - tentative.hauteurEnvoyee) >= Reglages.ASCENSION_PAS_ETAT then
		envoyerEtat(joueur)
	end
end

--- Le tour de tous les joueurs qui montent. Chacun dans son pcall : une erreur chez l'un n'éteint pas le suivi
--- pour tout le serveur (sinon plus de hauteur, plus de record, plus d'état envoyé jusqu'au redémarrage).
local function releverTous()
	for joueur, tentative in tentatives do
		local ok, erreur = pcall(relever, joueur, tentative)
		if not ok then
			warn(`[Ascension] relevé de {joueur.Name} en échec : {erreur}`)
		end
	end
end

--- Réapparition : au pied si le joueur est dans l'ascension, sinon on laisse Parcours.luau faire son travail.
local function surPersonnage(joueur: Player)
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
	joueur:SetAttribute(ATTRIBUT_EN_ASCENSION, false) -- on entre dans l'ascension en touchant son pied
	envoyerEtat(joueur)
end

--- serveur/Capacites arrive par une autre branche : on le charge s'il est là, et on s'en passe sinon (la tentative
--- est alors classable sans surveillance, et un placement du serveur n'est pas annoncé — rien ne casse).
local function brancherCapacites()
	local module = script.Parent:FindFirstChild("Capacites")
	if not module then
		warn("[Ascension] serveur/Capacites absent : pas de surveillance des déplacements")
		return
	end
	local ok, charge = pcall(require, module)
	if ok and typeof(charge) == "table" then
		capacites = charge
	else
		warn(`[Ascension] serveur/Capacites illisible : {charge}`)
	end
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

local function lirePaliers()
	local origine = sommetDuPied()
	for _, part in CollectionService:GetTagged("Palier") do
		local numero = part:GetAttribute("Numero")
		-- Au-delà de Regles.PALIERS_MAX, la sauvegarde l'écarterait : le palier serait débloqué pour la session
		-- puis perdu au rechargement. Mieux vaut le refuser tout de suite, et le dire.
		if
			not part:IsA("BasePart")
			or typeof(numero) ~= "number"
			or numero % 1 ~= 0
			or numero < 1
			or numero > Regles.PALIERS_MAX
		then
			warn(
				`[Ascension] palier ignoré : {part:GetFullName()} (attribut Numero entier de 1 à {Regles.PALIERS_MAX} attendu)`
			)
			continue
		end
		local n = numero :: number
		paliersParts[n] = part
		paliersHauteur[n] = part.Position.Y + part.Size.Y / 2 - (origine or 0)
		-- `Hauteur` est le Y absolu : seule `HauteurRelative` (au-dessus du pied) se compare à notre hauteur.
		local declaree = part:GetAttribute("HauteurRelative")
		if typeof(declaree) ~= "number" then
			warn(`[Ascension] palier {n} sans attribut HauteurRelative : hauteur prise dans la carte`)
		elseif math.abs((declaree :: number) - paliersHauteur[n]) > ECART_HAUTEUR_PALIER then
			warn(`[Ascension] palier {n} : attribut HauteurRelative {declaree}, position réelle {paliersHauteur[n]}`)
		end
		part.Touched:Connect(function(touche)
			surPalier(n, touche)
		end)
	end
	if next(paliersParts) == nil and pied then
		warn("[Ascension] aucun palier dans la carte : rien à débloquer, rien où se téléporter")
	end
end

local function lireEtagesEtSommet()
	for _, part in CollectionService:GetTagged("EtageAscension") do
		local numero = part:GetAttribute("Numero")
		if part:IsA("BasePart") and typeof(numero) == "number" then
			local n = numero :: number
			-- Dessus de l'étage au-dessus du pied : sert à savoir s'il est au-dessus du palier d'arrivée.
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
	brancherCapacites()
	lirePied()
	lirePaliers()
	lireEtagesEtSommet()

	Donnees.surChargement(surChargement)

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
		derniereTeleport[joueur] = nil
	end)

	demanderTeleportPalier.OnServerEvent:Connect(surDemandeTeleport)

	task.spawn(function()
		while true do
			releverTous()
			task.wait(Reglages.ASCENSION_PERIODE_SUIVI)
		end
	end)
end

return Ascension
