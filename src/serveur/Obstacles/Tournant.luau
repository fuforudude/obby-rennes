--!strict
-- Tournant : barre qui tourne à plat autour de sa position, à `Vitesse` rad/s (moteur d'une charnière).
local Commun = require(script.Parent.Commun)

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local vitesse = part:GetAttribute("Vitesse")
	if typeof(vitesse) ~= "number" then
		warn(`[Obstacles] {part:GetFullName()} : attribut Vitesse invalide`)
		return nil
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
	return nil
end

local famille: Commun.Famille = { tag = "Tournant", classe = "BasePart", preparer = preparer }

return famille
