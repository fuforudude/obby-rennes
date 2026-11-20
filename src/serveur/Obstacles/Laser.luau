--!strict
-- Laser : la pièce balaie régulièrement de `Depart` à `Arrivee` et revient, un aller-retour par `Periode`, calé sur
-- `workspace:GetServerTimeNow()` par le même cycle que les autres horaires de la carte (partage/Horaires via
-- partage/Pieges) : le rythme est le même pour tous les joueurs, donc apprenable.
-- Elle tue au contact, exactement comme le tag Mortel, et ne bloque pas le passage (pas de collision) : c'est le
-- rayon qui tue, pas le mur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pieges = require(ReplicatedStorage.Partage.Pieges)
local Commun = require(script.Parent.Commun)

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local parametres = Pieges.laserDepuisAttributs(part:GetAttributes())
	if not parametres then
		warn(`[Obstacles] {part:GetFullName()} : attributs Depart / Arrivee / Periode / Decalage invalides`)
		return nil
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	Commun.tuerAuContact(part)
	local rotation = part.CFrame.Rotation
	return function(instant: Commun.Instant)
		part.CFrame = CFrame.new(Pieges.positionLaser(instant.serveur, parametres)) * rotation
	end
end

local famille: Commun.Famille = { tag = "Laser", classe = "BasePart", preparer = preparer }

return famille
