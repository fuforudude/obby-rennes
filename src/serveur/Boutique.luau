--!strict
-- Achats Robux : le produit développeur « Passer l'étape ». Un achat n'est confirmé à Roblox (PurchaseGranted)
-- qu'une fois l'étape donnée ET sauvegardée ; un achat déjà traité (même PurchaseId) n'est jamais redonné.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Parcours = require(script.Parent.Parcours)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Regles)

local function traiterAchat(recu): Enum.ProductPurchaseDecision
	local joueur = Players:GetPlayerByUserId(recu.PlayerId)
	local donnees = joueur and Donnees.obtenir(joueur)
	if not joueur or not donnees then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox redemandera à sa prochaine connexion
	end
	if Reglages.PRODUIT_PASSER_ETAPE == 0 or recu.ProductId ~= Reglages.PRODUIT_PASSER_ETAPE then
		warn(`[Boutique] produit inconnu : {recu.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Regles.achatDejaTraite(donnees.achats, recu.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- À l'arrivée il n'y a plus d'étape à passer : l'achat est quand même consommé (le bouton y est caché).
	Parcours.passerEtape(joueur)
	Regles.memoriserAchat(donnees.achats, recu.PurchaseId, Reglages.MAX_ACHATS_MEMORISES)
	if not Donnees.sauvegarderMaintenant(joueur) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local Boutique = {}

function Boutique.demarrer()
	MarketplaceService.ProcessReceipt = traiterAchat
end

return Boutique
