--!strict
-- Lance tous les tests (fichiers *.spec.luau de tests/) avec TestEZ et rend un bilan.
-- Utilisé par « roblox tests » (dans le cloud) et par l'agent QA dans Studio (pendant un test en jeu, côté serveur).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage:WaitForChild("DevPackages"):WaitForChild("TestEZ")) :: any

return function()
	local resultats = TestEZ.TestBootstrap:run({ script.Parent }, TestEZ.Reporters.TextReporter)
	return {
		reussis = resultats.successCount,
		echecs = resultats.failureCount,
		ignores = resultats.skippedCount,
		erreurs = resultats.errors,
	}
end
