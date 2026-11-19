--!strict
-- Le mode vol des testeurs, côté serveur. Le client demande (DemanderVol, touche F), le serveur décide SEUL : il lit
-- l'identifiant du joueur dans `Reglages.TESTEURS` (jamais une valeur envoyée par le client), vérifie que le personnage
-- est vivant et une cadence minimale, puis répond par EtatVol. La règle est pure et testée : partage/Vol.decider.
-- Hors liste, la demande est ignorée sans réponse : rien ne laisse deviner que le mode existe, même en la spammant.
--
-- Ce que fait l'accord d'un vol (dans cet ordre) :
--   1. Parcours.marquerVol (le vol est refusé s'il rend false) : la course du joueur n'est plus classable et son aura est figée (Regles.estClassable,
--      Regles.auraCompte), et serveur/Ascension y lit la même marque (Parcours.aVole) pour la tentative d'ascension.
--      Ça dure jusqu'à « Recommencer » (la course est alors remplacée par une neuve). Le vol valide en revanche les
--      checkpoints et sauvegarde l'étape : c'est voulu.
--   2. Capacites.entrerVol : la surveillance des déplacements cesse de juger ce joueur, sa fenêtre se réamorce à chaque
--      relevé (voir partage/Capacites.mesurer).
--   3. EtatVol(true) : seulement maintenant le client commence à voler.
-- À l'arrêt (demande, mort, réapparition, départ), Capacites.sortirVol réamorce la surveillance sur la position de sortie :
-- elle reprend immédiatement.
--
-- Le déplacement lui-même est fait par le client (client/Vol.luau), comme pour le dash : il est propriétaire de la physique
-- de son personnage. Le serveur ne le simule pas ; il ne fait que lever la surveillance, et seulement pour un testeur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Capacites = require(script.Parent.Capacites)
local Donnees = require(script.Parent.Donnees)
local Parcours = require(script.Parent.Parcours)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)
local RegleVol = require(ReplicatedStorage.Partage.Vol)

local demanderVol: RemoteEvent
local etatVol: RemoteEvent

local enVol: { [Player]: boolean } = {}
local dernieres: { [any]: number } = {} -- heure de la dernière bascule acceptée, par joueur
local liaisons: { [Player]: { RBXScriptConnection } } = {}
local demarre = false

--- Le vol s'arrête (le joueur le demande, meurt, réapparaît ou part). `prevenir` : lui dire EtatVol(false).
local function arreter(joueur: Player, prevenir: boolean)
	if not enVol[joueur] then
		return
	end
	enVol[joueur] = nil
	Capacites.sortirVol(joueur)
	if prevenir then
		etatVol:FireClient(joueur, false)
	end
end

local function surDemande(joueur: Player)
	local actuel = enVol[joueur] == true
	local nouvel, raison = RegleVol.decider(
		Reglages.TESTEURS,
		dernieres,
		joueur,
		joueur.UserId,
		os.clock(),
		Reglages.VOL_DELAI_MIN,
		actuel,
		function()
			local personnage = joueur.Character
			local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
			return {
				vivant = humanoide ~= nil and humanoide.Health > 0,
				pret = Donnees.obtenir(joueur) ~= nil,
			}
		end
	)
	if nouvel == nil then
		-- Trop tôt : seul un testeur arrive ici ; on lui redit l'état réel, au cas où son client l'aurait devancé
		-- (il arrête son vol dès l'appui sur F). Les autres refus ne répondent rien.
		if raison == "trop_souvent" then
			etatVol:FireClient(joueur, actuel)
		end
		return
	end
	if nouvel then
		-- D'abord : la course est non classable avant le premier mètre de vol. Course introuvable : pas de vol.
		if not Parcours.marquerVol(joueur) then
			etatVol:FireClient(joueur, false) -- seul un testeur arrive ici : on lui redit qu'il ne vole pas
			return
		end
		enVol[joueur] = true
		Capacites.entrerVol(joueur)
		etatVol:FireClient(joueur, true)
	else
		arreter(joueur, true)
	end
end

local function suivre(joueur: Player)
	if liaisons[joueur] then
		return
	end
	local connexions: { RBXScriptConnection } = {}
	liaisons[joueur] = connexions
	-- Un personnage qui disparaît (mort, « Recommencer », déconnexion) ne laisse pas le joueur en vol : le suivant
	-- apparaît au sol, avec une surveillance neuve (serveur/Capacites.nouveauSuivi).
	table.insert(
		connexions,
		joueur.CharacterRemoving:Connect(function()
			arreter(joueur, true)
		end)
	)
	table.insert(
		connexions,
		joueur.CharacterAdded:Connect(function(personnage)
			local humanoide = personnage:WaitForChild("Humanoid", 10)
			if humanoide and humanoide:IsA("Humanoid") then
				-- Connexion détruite avec le personnage : pas de fuite.
				humanoide.Died:Connect(function()
					arreter(joueur, true)
				end)
			end
		end)
	)
	if joueur.Character then
		local humanoide = joueur.Character:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.Died:Connect(function()
				arreter(joueur, true)
			end)
		end
	end
end

local Vol = {}

function Vol.demarrer()
	if demarre then
		return
	end
	demarre = true
	demanderVol = Remotes.obtenir("DemanderVol")
	etatVol = Remotes.obtenir("EtatVol")
	if not RegleVol.listeValide(Reglages.TESTEURS) then
		warn("[Vol] Reglages.TESTEURS mal formée (attendu { [identifiant] = true }) : personne ne volera")
	end
	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Players.PlayerRemoving:Connect(function(joueur)
		arreter(joueur, false)
		local connexions = liaisons[joueur]
		if connexions then
			for _, connexion in connexions do
				connexion:Disconnect()
			end
			liaisons[joueur] = nil
		end
		dernieres[joueur] = nil
	end)
	demanderVol.OnServerEvent:Connect(surDemande)
end

return Vol
