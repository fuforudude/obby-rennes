--!strict
-- Les obstacles de la carte, retrouvés par leurs tags (posés par outils/monde/Parcours.luau et
-- outils/monde/Ascension.luau) :
--   Mortel      tue au toucher ;
--   Fragile     s'efface puis revient (tuto) ;
--   Mobile      va-et-vient ;
--   Tournant    barre qui tourne ;
--   Balancier   oscille autour d'un pivot, pousse sans tuer ; attribut facultatif Poussee (multiplicateur) ;
--   PiegeMur    (Model) pointe qui sort du mur quand un joueur approche et le projette, sans le tuer ;
--   Laser       balayage régulier d'une extrémité à l'autre, mortel au contact ;
--   Effondrable plateforme qui tombe après le premier contact, puis revient à sa place.
-- Les décisions (lecture des attributs, cycle du piège, balayage du laser, cycle de l'effondrable) sont des
-- fonctions pures testées : src/partage/Pieges.luau. Ici on ne fait que lire l'horloge du serveur, bouger les
-- pièces et pousser les joueurs. Un attribut invalide est signalé par `warn` et l'obstacle est ignoré.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Horaires = require(ReplicatedStorage.Partage.Horaires)
local Pieges = require(ReplicatedStorage.Partage.Pieges)
local Reglages = require(ReplicatedStorage.Partage.Reglages)

local DELAI_AVANT_CHUTE = 0.5
local DUREE_ABSENCE = 3
-- Attribut posé sur le HumanoidRootPart : heure du dernier coup de pointe reçu. Sur le personnage plutôt que dans
-- une table du service : il disparaît avec lui, donc rien à nettoyer et rien qui fuit.
local ATTRIBUT_DERNIERE_POUSSEE = "DernierePousseePiege"

local function humanoideVivant(touche: BasePart): Humanoid?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local humanoide = modele and modele:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return humanoide
	end
	return nil
end

--- La racine d'un personnage vivant derrière une pièce touchée, ou nil : c'est elle qu'on pousse.
local function racineVivante(touche: BasePart): BasePart?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local humanoide = modele and modele:FindFirstChildOfClass("Humanoid")
	if not modele or not humanoide or humanoide.Health <= 0 then
		return nil
	end
	local racine = modele:FindFirstChild("HumanoidRootPart")
	return if racine and racine:IsA("BasePart") then racine else nil
end

local function nombreFini(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function mortel(part: BasePart)
	part.Touched:Connect(function(touche)
		local humanoide = humanoideVivant(touche)
		if humanoide then
			humanoide.Health = 0
		end
	end)
end

local function fragile(part: BasePart)
	local transparence = part.Transparency
	local enCours = false
	part.Touched:Connect(function(touche)
		if enCours or not humanoideVivant(touche) then
			return
		end
		enCours = true
		task.delay(DELAI_AVANT_CHUTE, function()
			part.Transparency = 0.8
			part.CanCollide = false
			task.delay(DUREE_ABSENCE, function()
				part.Transparency = transparence
				part.CanCollide = true
				enCours = false
			end)
		end)
	end)
end

-- La plateforme est libérée et tenue par des contraintes rigides dont on fait glisser la cible : contrairement à une
-- pièce ancrée déplacée, elle a une vraie vitesse, donc elle emporte le joueur posé dessus.
local function mobile(part: BasePart)
	local deplacement = part:GetAttribute("Deplacement")
	local duree = part:GetAttribute("Duree")
	if typeof(deplacement) ~= "Vector3" or typeof(duree) ~= "number" or duree <= 0 then
		warn(`[Obstacles] {part:GetFullName()} : attributs Deplacement / Duree invalides`)
		return
	end
	local attache = Instance.new("Attachment")
	attache.Parent = part
	local position = Instance.new("AlignPosition")
	position.Mode = Enum.PositionAlignmentMode.OneAttachment
	position.Attachment0 = attache
	position.RigidityEnabled = true
	position.Position = part.Position
	position.Parent = part
	local orientation = Instance.new("AlignOrientation")
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attache
	orientation.RigidityEnabled = true
	orientation.CFrame = part.CFrame.Rotation
	orientation.Parent = part
	part.Anchored = false
	part:SetNetworkOwner(nil) -- le serveur simule : tous les joueurs voient la même position
	TweenService:Create(
		position,
		TweenInfo.new(duree, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = part.Position + deplacement }
	):Play()
end

local function tournant(part: BasePart)
	local vitesse = part:GetAttribute("Vitesse")
	if typeof(vitesse) ~= "number" then
		warn(`[Obstacles] {part:GetFullName()} : attribut Vitesse invalide`)
		return
	end
	local pivot = Instance.new("Part")
	pivot.Name = part.Name .. "Pivot"
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.Transparency = 1
	pivot.Size = Vector3.one
	pivot.CFrame = part.CFrame
	pivot.Parent = part.Parent
	-- Axe des attachements (leur axe X) = verticale du monde : la barre tourne à plat.
	local axe = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis)
	local a0 = Instance.new("Attachment")
	a0.CFrame = axe
	a0.Parent = pivot
	local a1 = Instance.new("Attachment")
	a1.CFrame = axe
	a1.Parent = part
	local charniere = Instance.new("HingeConstraint")
	charniere.ActuatorType = Enum.ActuatorType.Motor
	charniere.AngularVelocity = vitesse
	charniere.MotorMaxTorque = math.huge
	charniere.MotorMaxAcceleration = math.huge
	charniere.Attachment0 = a0
	charniere.Attachment1 = a1
	charniere.Parent = part
	part.Anchored = false
	part:SetNetworkOwner(nil)
end

type Oscillation = { charniere: HingeConstraint, amplitude: number, periode: number, decalage: number }
type Laser = { part: BasePart, rotation: CFrame, parametres: Pieges.ParametresLaser }
type Piege = {
	pointe: BasePart,
	pose: CFrame, -- la pointe rentrée : l'origine de sa course et le centre de sa portée
	parametres: Pieges.ParametresPiege,
	debut: number, -- os.clock() du dernier déclenchement ; -inf tant qu'elle n'a jamais bougé
	phase: Pieges.PhasePiege,
	avancement: number, -- dernière sortie appliquée (0 rentrée, 1 dehors) : on ne réécrit pas un CFrame identique
}

-- Un seul Heartbeat pour tout ce qui suit l'horloge (balanciers, lasers, pointes), connecté au premier obstacle
-- enregistré et déconnecté quand il n'en reste aucun.
local oscillations: { [BasePart]: Oscillation } = {}
local lasers: { [BasePart]: Laser } = {}
local piegesMur: { [Model]: Piege } = {}
local liaisonHorloge: RBXScriptConnection? = nil
local prochainScan = 0

--- Les positions des joueurs vivants : relevées une seule fois par scan, partagées par tous les pièges.
local function positionsVivantes(): { Vector3 }
	local positions = {}
	for _, joueur in Players:GetPlayers() do
		local personnage = joueur.Character
		local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
		local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
		if humanoide and humanoide.Health > 0 and racine and racine:IsA("BasePart") then
			table.insert(positions, racine.Position)
		end
	end
	return positions
end

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

-- `positions` n'est donné qu'aux images où l'on scanne.
local function majPiege(piege: Piege, horloge: number, positions: { Vector3 }?)
	local phase, avancement = Pieges.phasePiege(horloge - piege.debut, piege.parametres)
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

local function majHorloge()
	local t = workspace:GetServerTimeNow()
	for _, o in oscillations do
		o.charniere.TargetAngle = Horaires.angleBalancier(t, o.amplitude, o.periode, o.decalage)
	end
	for _, l in lasers do
		l.part.CFrame = CFrame.new(Pieges.positionLaser(t, l.parametres)) * l.rotation
	end
	if next(piegesMur) ~= nil then
		-- Les pointes bougent à chaque image ; la recherche d'un joueur à portée, elle, est plus rare.
		local horloge = os.clock()
		local positions = nil
		if horloge >= prochainScan then
			prochainScan = horloge + Reglages.PIEGE_PERIODE_SCAN
			positions = positionsVivantes()
		end
		for _, piege in piegesMur do
			majPiege(piege, horloge, positions)
		end
	end
end

local function suivreHorloge()
	if not liaisonHorloge then
		liaisonHorloge = RunService.Heartbeat:Connect(majHorloge)
	end
end

local function oublierSiVide()
	if liaisonHorloge and next(oscillations) == nil and next(lasers) == nil and next(piegesMur) == nil then
		liaisonHorloge:Disconnect()
		liaisonHorloge = nil
	end
end

-- Un balancier (battant, pancarte, bôme, cloche…) : la pièce est accrochée à un point fixe (Pivot) par une charnière
-- dont un servo suit une sinusoïde calée sur l'horloge du serveur (Horaires.angleBalancier), de part et d'autre de la
-- position posée. Libérée et simulée par le serveur, elle pousse physiquement les joueurs ; elle ne tue pas.
-- L'attribut facultatif `Poussee` (multiplicateur, 1 par défaut) est appliqué à la densité de la pièce : une
-- pancarte plus lourde emporte le joueur plus loin, sans rien changer à sa trajectoire ni à son horaire — donc sans
-- toucher à la fenêtre de passage que vérifient les contrôles de la carte.
local function balancier(part: BasePart)
	local pivot = part:GetAttribute("Pivot")
	local axe = part:GetAttribute("Axe")
	local amplitude = part:GetAttribute("Amplitude")
	local periode = part:GetAttribute("Periode")
	local decalage = part:GetAttribute("Decalage") or 0
	if
		typeof(pivot) ~= "Vector3"
		or typeof(axe) ~= "Vector3"
		or axe.Magnitude < 0.9
		or axe.Magnitude > 1.1
		or not nombreFini(amplitude)
		or amplitude <= 0
		or amplitude > 180
		or not nombreFini(periode)
		or periode <= 0
		or not nombreFini(decalage)
	then
		warn(
			`[Obstacles] {part:GetFullName()} : attributs Pivot / Axe (unitaire) / Amplitude / Periode / Decalage invalides`
		)
		return
	end
	local declaree = part:GetAttribute("Poussee")
	local poussee = Pieges.multiplicateurPoussee(declaree, Reglages.BALANCIER_POUSSEE_MAX)
	if declaree ~= nil and declaree ~= poussee then
		warn(`[Obstacles] {part:GetFullName()} : attribut Poussee invalide, pris pour 1`)
	end
	if poussee ~= 1 then
		local actuelles = part.CustomPhysicalProperties or PhysicalProperties.new(part.Material)
		part.CustomPhysicalProperties = PhysicalProperties.new(
			actuelles.Density * poussee,
			actuelles.Friction,
			actuelles.Elasticity,
			actuelles.FrictionWeight,
			actuelles.ElasticityWeight
		)
	end
	local sens = axe.Unit
	-- Repère de la charnière : son axe X est l'axe du balancier, les autres axes sont quelconques mais orthogonaux.
	local reference = if math.abs(sens:Dot(Vector3.yAxis)) < 0.99 then Vector3.yAxis else Vector3.zAxis
	local orthogonal = (reference - sens * sens:Dot(reference)).Unit
	local repere = CFrame.fromMatrix(Vector3.zero, sens, orthogonal)

	local fixe = Instance.new("Part")
	fixe.Name = part.Name .. "Pivot"
	fixe.Anchored = true
	fixe.CanCollide = false
	fixe.CanTouch = false
	fixe.CanQuery = false
	fixe.Transparency = 1
	fixe.Size = Vector3.one
	fixe.CFrame = CFrame.new(pivot)
	fixe.Parent = part.Parent
	local a0 = Instance.new("Attachment")
	a0.CFrame = repere
	a0.Parent = fixe
	local a1 = Instance.new("Attachment")
	a1.CFrame = part.CFrame:ToObjectSpace(CFrame.new(pivot) * repere) -- confondu avec a0 tant que la pièce est posée
	a1.Parent = part

	local pic = math.rad(amplitude) * 2 * math.pi / periode -- vitesse angulaire maximale de la sinusoïde, en rad/s
	local charniere = Instance.new("HingeConstraint")
	charniere.ActuatorType = Enum.ActuatorType.Servo
	charniere.LimitsEnabled = false
	charniere.ServoMaxTorque = math.huge
	charniere.AngularSpeed = math.max(pic * 10, 10) -- de la marge : le servo doit toujours rattraper la cible
	charniere.TargetAngle = Horaires.angleBalancier(workspace:GetServerTimeNow(), amplitude, periode, decalage)
	charniere.Attachment0 = a0
	charniere.Attachment1 = a1
	charniere.Parent = part
	part.Anchored = false
	part:SetNetworkOwner(nil) -- le serveur simule : tous les joueurs voient (et subissent) la même chose

	oscillations[part] = { charniere = charniere, amplitude = amplitude, periode = periode, decalage = decalage }
	suivreHorloge()
	part.Destroying:Connect(function()
		oscillations[part] = nil
		fixe:Destroy()
		oublierSiVide()
	end)
end

-- Un rayon laser : la pièce balaie régulièrement de `Depart` à `Arrivee` et revient, un aller-retour par `Periode`,
-- calé sur `workspace:GetServerTimeNow()` par le même cycle que les autres horaires de la carte
-- (partage/Horaires via partage/Pieges) : le rythme est le même pour tous les joueurs, donc apprenable.
-- Elle tue au contact, exactement comme le tag Mortel, et ne bloque pas le passage (pas de collision) : c'est le
-- rayon qui tue, pas le mur.
local function laser(part: BasePart)
	local parametres = Pieges.laserDepuisAttributs(part:GetAttributes())
	if not parametres then
		warn(`[Obstacles] {part:GetFullName()} : attributs Depart / Arrivee / Periode / Decalage invalides`)
		return
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	mortel(part)
	lasers[part] = { part = part, rotation = part.CFrame.Rotation, parametres = parametres }
	suivreHorloge()
	part.Destroying:Connect(function()
		lasers[part] = nil
		oublierSiVide()
	end)
end

-- Une plateforme qui s'effondre : au premier contact d'un joueur vivant, elle tient encore `DelaiChute` secondes
-- (le temps de la traverser en courant), puis elle est lâchée — elle tombe pour de vrai, à la physique, ce qui se
-- voit bien mieux qu'une pièce qui s'efface. Elle est en même temps rendue traversable (ni collision ni toucher) :
-- le joueur posé dessus tombe au même instant, et la dalle en chute libre ne va bousculer ni tuer personne plus
-- bas dans la tour (une dalle qui rebondit d'étage en étage rendrait la montée des autres joueurs aléatoire).
-- Elle ne tombe que `Reglages.EFFONDRABLE_DUREE_CHUTE` secondes (sinon Roblox la détruirait sous
-- FallenPartsDestroyHeight) : elle est alors réancrée, invisible et traversable. `DelaiRetour` secondes après la
-- chute, elle est remise à sa place d'origine et redevient franchissable.
local function effondrable(part: BasePart)
	local parametres = Pieges.effondrableDepuisAttributs(part:GetAttributes(), {
		delaiChute = Reglages.EFFONDRABLE_DELAI,
		delaiRetour = Reglages.EFFONDRABLE_RETOUR,
	})
	if not parametres then
		warn(`[Obstacles] {part:GetFullName()} : attributs DelaiChute / DelaiRetour invalides`)
		return
	end
	local pose = part.CFrame
	local collision, toucher, transparence = part.CanCollide, part.CanTouch, part.Transparency
	local enCours = false
	part.Touched:Connect(function(touche)
		if enCours or not humanoideVivant(touche) then
			return
		end
		enCours = true
		task.delay(parametres.delaiChute, function()
			part.CanCollide = false
			part.CanTouch = false
			part.Anchored = false
			part:SetNetworkOwner(nil)
			-- Chute libre limitée : plus longtemps, la dalle passerait sous FallenPartsDestroyHeight et serait détruite.
			local chute = Pieges.dureeChuteLibre(parametres.delaiRetour, Reglages.EFFONDRABLE_DUREE_CHUTE)
			task.delay(chute, function()
				part.Anchored = true -- figée là où elle est, invisible et traversable jusqu'au retour
				part.Transparency = 1
				task.delay(parametres.delaiRetour - chute, function()
					part.Anchored = true
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
					part.CFrame = pose
					part.Transparency = transparence
					part.CanCollide = collision
					part.CanTouch = toucher
					enCours = false
				end)
			end)
		end)
	end)
end

--- Le coup de pointe : la vitesse horizontale du joueur est remplacée par celle du piège, dans sa direction.
--- Elle ne tue jamais (c'est le vide qui tue) et reste rattrapable : voir Reglages.PIEGE_POUSSEE.
--- Un même joueur n'est repoussé qu'une fois par PIEGE_DELAI_POUSSEE secondes : `Touched` se déclenche plusieurs
--- fois pour un seul contact, et sans ce délai la pointe collerait le joueur à elle.
local function pousser(piege: Piege, touche: BasePart)
	if piege.phase ~= "sortie" and piege.phase ~= "rentree" then
		return -- la pointe est rentrée : on ne pousse pas en frôlant le mur
	end
	local racine = racineVivante(touche)
	if not racine then
		return
	end
	local horloge = os.clock()
	local derniere = racine:GetAttribute(ATTRIBUT_DERNIERE_POUSSEE)
	if nombreFini(derniere) and horloge - (derniere :: number) < Reglages.PIEGE_DELAI_POUSSEE then
		return
	end
	racine:SetAttribute(ATTRIBUT_DERNIERE_POUSSEE, horloge)
	racine.AssemblyLinearVelocity =
		Pieges.vitesseApresPoussee(racine.AssemblyLinearVelocity, piege.parametres.direction, piege.parametres.poussee)
end

-- Un piège de mur : une pointe (ou une barre) rentrée dans le mur, dont le seul indice est une fente et une trace
-- d'usure posées par la carte. Dès qu'un joueur vivant entre dans `Portee` studs de la fente, elle sort en
-- `DureeSortie` secondes, rentre en `DureeRentree`, puis se repose avant de pouvoir repartir. Elle ne tue pas :
-- au contact elle projette le joueur à l'horizontale (voir `pousser`).
-- La pointe reste ancrée et c'est le serveur qui la déplace : tous les joueurs la voient au même endroit, et une
-- pièce ancrée ne peut pas être poussée hors de son mur par un joueur qui s'y jette.
local function piegeMur(modele: Model)
	local parametres = Pieges.piegeDepuisAttributs(modele:GetAttributes(), {
		portee = Reglages.PIEGE_PORTEE,
		poussee = Reglages.PIEGE_POUSSEE,
		repos = Reglages.PIEGE_REPOS,
	})
	if not parametres then
		warn(
			`[Obstacles] {modele:GetFullName()} : attributs Direction / Distance / DureeSortie / DureeRentree / Portee / Poussee invalides`
		)
		return
	end
	local pointe = modele:FindFirstChild("Pointe")
	if not pointe or not pointe:IsA("BasePart") then
		warn(`[Obstacles] {modele:GetFullName()} : enfant Pointe (BasePart) attendu`)
		return
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
	piegesMur[modele] = piege
	suivreHorloge()
	pointe.Touched:Connect(function(touche)
		pousser(piege, touche)
	end)
	modele.Destroying:Connect(function()
		piegesMur[modele] = nil
		oublierSiVide()
	end)
end

local Obstacles = {}

function Obstacles.demarrer()
	local parts: { [string]: (BasePart) -> () } = {
		Mortel = mortel,
		Fragile = fragile,
		Mobile = mobile,
		Tournant = tournant,
		Balancier = balancier,
		Laser = laser,
		Effondrable = effondrable,
	}
	for tag, preparer in parts do
		for _, objet in CollectionService:GetTagged(tag) do
			if objet:IsA("BasePart") then
				preparer(objet)
			end
		end
	end
	for _, objet in CollectionService:GetTagged("PiegeMur") do
		if objet:IsA("Model") then
			piegeMur(objet)
		else
			warn(`[Obstacles] {objet:GetFullName()} : le tag PiegeMur se pose sur un Model`)
		end
	end
end

return Obstacles
