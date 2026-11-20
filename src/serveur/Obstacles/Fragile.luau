--!strict
-- Fragile (tuto) : au contact d'un joueur vivant, la plateforme s'efface après Reglages.FRAGILE_DELAI secondes,
-- reste absente Reglages.FRAGILE_ABSENCE secondes, puis revient.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Commun = require(script.Parent.Commun)

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local transparence = part.Transparency
	local enCours = false
	part.Touched:Connect(function(touche)
		if enCours or not Commun.humanoideVivant(touche) then
			return
		end
		enCours = true
		task.delay(Reglages.FRAGILE_DELAI, function()
			part.Transparency = 0.8
			part.CanCollide = false
			task.delay(Reglages.FRAGILE_ABSENCE, function()
				part.Transparency = transparence
				part.CanCollide = true
				enCours = false
			end)
		end)
	end)
	return nil
end

local famille: Commun.Famille = { tag = "Fragile", classe = "BasePart", preparer = preparer }

return famille
