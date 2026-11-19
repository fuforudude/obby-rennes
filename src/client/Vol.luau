--!strict
-- Le vol des testeurs, côté client. La touche F (lue dans client/Capacites.luau, avec les autres entrées) appelle
-- `Vol.demander()` : le client envoie DemanderVol et NE VOLE PAS. Il ne commence que sur EtatVol(true), la réponse du
-- serveur, qui a vérifié l'identifiant contre Reglages.TESTEURS (serveur/Vol.luau). Un joueur hors liste n'a aucune réponse.
--
-- Mise en œuvre : une contrainte physique (LinearVelocity en mode vecteur, comme le dash) impose la vitesse du personnage,
-- gravité comprise, tant que le vol dure. Le personnage reste un corps physique : il est bloqué par les murs et le sol,
-- exactement comme à pied (on ne le téléporte jamais, et il n'est jamais passé en « sans collision »). Direction : où
-- l'on regarde (caméra) avec les touches de déplacement habituelles, Espace pour monter, Ctrl gauche pour descendre
-- (calcul pur : partage/Vol.vitesse).
--
-- À la sortie : la contrainte disparaît, la vitesse horizontale est annulée, la chute continue normalement (Roblox n'a
-- pas de dégâts de chute). Le vol s'arrête aussi tout seul à la mort ou à la disparition du personnage, et sur
-- EtatVol(false). Une seule connexion par image, seulement pendant le vol.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)
local RegleVol = require(ReplicatedStorage.Partage.Vol)

local TOUCHE_MONTER = Enum.KeyCode.Space
local TOUCHE_DESCENDRE = Enum.KeyCode.LeftControl

type SessionVol = {
	humanoide: Humanoid,
	racine: BasePart,
	attache: Attachment,
	vitesse: LinearVelocity,
	connexions: { RBXScriptConnection },
}

local joueur = Players.LocalPlayer
local session: SessionVol? = nil
local demanderVol: RemoteEvent? = nil -- une fois trouvé (sans bloquer le démarrage)
local derniereDemande = -math.huge -- os.clock() de la dernière demande envoyée
local demarre = false

local Vol = {}

--- Le personnage est-il en train de voler ? (client/Capacites s'en sert pour couper double saut et dash pendant le vol.)
function Vol.actif(): boolean
	return session ~= nil
end

--- Arrête le vol local : plus de contrainte, plus de vitesse horizontale, la chute reprend normalement.
local function arreter()
	local s = session
	if not s then
		return
	end
	session = nil
	for _, connexion in s.connexions do
		connexion:Disconnect()
	end
	table.clear(s.connexions)
	s.vitesse:Destroy()
	s.attache:Destroy()
	if s.racine.Parent then
		local v = s.racine.AssemblyLinearVelocity
		s.racine.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
	end
end

--- Commence à voler (après EtatVol(true) seulement).
local function demarrerVol()
	if session then
		return
	end
	local personnage = joueur.Character
	local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	if not humanoide or humanoide.Health <= 0 or not racine or not racine:IsA("BasePart") then
		return
	end

	local attache = Instance.new("Attachment")
	attache.Name = "VolAttache"
	attache.Parent = racine
	local vitesse = Instance.new("LinearVelocity")
	vitesse.Name = "VolVitesse"
	vitesse.Attachment0 = attache
	vitesse.RelativeTo = Enum.ActuatorRelativeTo.World
	vitesse.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	vitesse.VectorVelocity = Vector3.zero
	vitesse.MaxForce = math.huge
	vitesse.Parent = racine

	local s: SessionVol =
		{ humanoide = humanoide, racine = racine, attache = attache, vitesse = vitesse, connexions = {} }
	session = s
	table.insert(
		s.connexions,
		humanoide.Died:Connect(function()
			arreter()
		end)
	)
	table.insert(
		s.connexions,
		RunService.Heartbeat:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local vertical = 0
			if not UserInputService:GetFocusedTextBox() then -- pas pendant qu'on écrit dans le chat
				if UserInputService:IsKeyDown(TOUCHE_MONTER) then
					vertical += 1
				end
				if UserInputService:IsKeyDown(TOUCHE_DESCENDRE) then
					vertical -= 1
				end
			end
			vitesse.VectorVelocity =
				RegleVol.vitesse(humanoide.MoveDirection, camera.CFrame.LookVector, vertical, Reglages.VOL_VITESSE)
		end)
	)
end

--- La touche F : demande la bascule au serveur. Demander ne fait pas voler : seul EtatVol(true) le fait. Pour arrêter,
--- le client s'arrête tout de suite (le serveur, s'il refuse, le lui redit par EtatVol(true) et le vol reprend).
function Vol.demander()
	local remote = demanderVol
	local maintenant = os.clock()
	if not remote or maintenant - derniereDemande < Reglages.VOL_DELAI_MIN then
		return
	end
	derniereDemande = maintenant
	arreter()
	remote:FireServer()
end

local function surEtat(actif: any)
	if actif == true then
		demarrerVol()
	elseif actif == false then
		arreter()
	end
end

function Vol.demarrer()
	if demarre then
		return
	end
	demarre = true
	joueur.CharacterRemoving:Connect(arreter)
	-- Les remotes : sans bloquer le démarrage du reste du client.
	task.spawn(function()
		Remotes.obtenir("EtatVol").OnClientEvent:Connect(surEtat)
		demanderVol = Remotes.obtenir("DemanderVol")
	end)
end

return Vol
