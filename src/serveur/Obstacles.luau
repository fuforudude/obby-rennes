--!strict
-- Les obstacles de la carte, retrouvés par leurs tags (posés par outils/monde/Parcours.luau) :
-- Mortel (tue au toucher), Fragile (s'efface puis revient), Mobile (va-et-vient), Tournant (barre qui tourne).
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

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

local Obstacles = {}

function Obstacles.demarrer()
	local familles: { [string]: (BasePart) -> () } = {
		Mortel = mortel,
		Fragile = fragile,
		Mobile = mobile,
		Tournant = tournant,
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
