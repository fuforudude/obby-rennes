--!strict
-- Balancier (battant, pancarte, bôme, cloche…) : la pièce est accrochée à un point fixe (Pivot) par une charnière
-- dont un servo suit une sinusoïde calée sur l'horloge du serveur (Horaires.angleBalancier), de part et d'autre de la
-- position posée. Libérée et simulée par le serveur, elle pousse physiquement les joueurs ; elle ne tue pas.
-- L'attribut facultatif `Poussee` (multiplicateur, 1 par défaut) est appliqué à la densité de la pièce : une
-- pancarte plus lourde emporte le joueur plus loin, sans rien changer à sa trajectoire ni à son horaire — donc sans
-- toucher à la fenêtre de passage que vérifient les contrôles de la carte.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Horaires = require(ReplicatedStorage.Partage.Horaires)
local Pieges = require(ReplicatedStorage.Partage.Pieges)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Commun = require(script.Parent.Commun)

local nombreFini = Commun.nombreFini

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local pivot = part:GetAttribute("Pivot")
	local axe = part:GetAttribute("Axe")
	-- Types déclarés d'avance : `nombreFini` valide la valeur juste après, mais Luau ne s'en sert pas pour affiner le type.
	local amplitude = part:GetAttribute("Amplitude") :: number
	local periode = part:GetAttribute("Periode") :: number
	local decalage = (part:GetAttribute("Decalage") or 0) :: number
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
		return nil
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

	part.Destroying:Connect(function()
		fixe:Destroy()
	end)
	return function(instant: Commun.Instant)
		charniere.TargetAngle = Horaires.angleBalancier(instant.serveur, amplitude, periode, decalage)
	end
end

local famille: Commun.Famille = { tag = "Balancier", classe = "BasePart", preparer = preparer }

return famille
