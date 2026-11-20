--!strict
-- Effondrable : au premier contact d'un joueur vivant, la plateforme tient encore `DelaiChute` secondes (le temps
-- de la traverser en courant), puis elle est lâchée — elle tombe pour de vrai, à la physique, ce qui se voit bien
-- mieux qu'une pièce qui s'efface. Elle est en même temps rendue traversable (ni collision ni toucher) : le joueur
-- posé dessus tombe au même instant, et la dalle en chute libre ne va bousculer ni tuer personne plus bas dans la
-- tour (une dalle qui rebondit d'étage en étage rendrait la montée des autres joueurs aléatoire).
-- Elle ne tombe que `Reglages.EFFONDRABLE_DUREE_CHUTE` secondes (sinon Roblox la détruirait sous
-- FallenPartsDestroyHeight) : elle est alors réancrée, invisible et traversable. `DelaiRetour` secondes après la
-- chute, elle est remise à sa place d'origine et redevient franchissable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pieges = require(ReplicatedStorage.Partage.Pieges)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Commun = require(script.Parent.Commun)

local function preparer(objet: Instance): Commun.Maj?
	local part = objet :: BasePart
	local parametres = Pieges.effondrableDepuisAttributs(part:GetAttributes(), Pieges.defautsEffondrable())
	if not parametres then
		warn(`[Obstacles] {part:GetFullName()} : attributs DelaiChute / DelaiRetour invalides`)
		return nil
	end
	local pose = part.CFrame
	local collision, toucher, transparence = part.CanCollide, part.CanTouch, part.Transparency
	local enCours = false
	part.Touched:Connect(function(touche)
		if enCours or not Commun.humanoideVivant(touche) then
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
	return nil
end

local famille: Commun.Famille = { tag = "Effondrable", classe = "BasePart", preparer = preparer }

return famille
