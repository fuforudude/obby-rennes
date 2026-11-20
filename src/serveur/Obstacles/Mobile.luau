--!strict
-- Mobile : va-et-vient de `Deplacement` (Vector3) en `Duree` secondes.
-- La plateforme est libérée et tenue par des contraintes rigides dont on fait glisser la cible : contrairement à une
-- pièce ancrée déplacée, elle a une vraie vitesse, donc elle emporte le joueur posé dessus.
local TweenService = game:GetService("TweenService")

local Commun = require(script.Parent.Commun)

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local deplacement = part:GetAttribute("Deplacement")
	local duree = part:GetAttribute("Duree")
	if typeof(deplacement) ~= "Vector3" or typeof(duree) ~= "number" or duree <= 0 then
		warn(`[Obstacles] {part:GetFullName()} : attributs Deplacement / Duree invalides`)
		return nil
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
	return nil
end

local famille: Commun.Famille = { tag = "Mobile", classe = "BasePart", preparer = preparer }

return famille
