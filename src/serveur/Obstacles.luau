--!strict
-- Les obstacles de la carte, retrouvés par leurs tags (posés par outils/monde/Parcours.luau) :
-- Mortel (tue au toucher), Fragile (s'efface puis revient), Mobile (va-et-vient), Tournant (barre qui tourne),
-- Balancier (oscille autour d'un pivot, pousse sans tuer).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Horaires = require(ReplicatedStorage.Partage.Horaires)

local DELAI_AVANT_CHUTE = 0.5
local DUREE_ABSENCE = 3

local function humanoideVivant(touche: BasePart): Humanoid?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local humanoide = modele and modele:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return humanoide
	end
	return nil
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

local oscillations: { [BasePart]: Oscillation } = {}
local liaisonOscillations: RBXScriptConnection? = nil

local function majOscillations()
	local t = workspace:GetServerTimeNow()
	for _, o in oscillations do
		o.charniere.TargetAngle = Horaires.angleBalancier(t, o.amplitude, o.periode, o.decalage)
	end
end

local function nombreFini(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- Un balancier (battant, pancarte, bôme, cloche…) : la pièce est accrochée à un point fixe (Pivot) par une charnière
-- dont un servo suit une sinusoïde calée sur l'horloge du serveur (Horaires.angleBalancier), de part et d'autre de la
-- position posée. Libérée et simulée par le serveur, elle pousse physiquement les joueurs ; elle ne tue pas.
-- Un seul Heartbeat pour tous les balanciers, déconnecté quand le dernier disparaît.
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
	if not liaisonOscillations then
		liaisonOscillations = RunService.Heartbeat:Connect(majOscillations)
	end
	part.Destroying:Connect(function()
		oscillations[part] = nil
		fixe:Destroy()
		if next(oscillations) == nil and liaisonOscillations then
			liaisonOscillations:Disconnect()
			liaisonOscillations = nil
		end
	end)
end

local Obstacles = {}

function Obstacles.demarrer()
	local familles: { [string]: (BasePart) -> () } = {
		Mortel = mortel,
		Fragile = fragile,
		Mobile = mobile,
		Tournant = tournant,
		Balancier = balancier,
	}
	for tag, preparer in familles do
		for _, objet in CollectionService:GetTagged(tag) do
			if objet:IsA("BasePart") then
				preparer(objet)
			end
		end
	end
end

return Obstacles
