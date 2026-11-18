--!strict
-- Les capacités de déplacement du joueur local : course, double saut (avec saut périlleux) et dash.
-- Le client bouge son personnage (fluide, sans délai réseau) ; le serveur surveille que ce reste possible
-- (serveur/Capacites.luau). Une capacité non débloquée ne fait rien et n'a pas de bouton. L'état « débloquée » vient du
-- champ `capacites` d'EtatCourse (envoyé par le serveur) et du remote CapaciteDebloquee (au moment du déblocage).
--
-- Commandes
--   Course     : maintenir Maj gauche, la gâchette gauche (ButtonL2) ou le bouton tactile « COURIR ».
--   Double saut: appuyer sur saut en l'air (touche, manette ou bouton de saut tactile).
--   Dash       : touche Q (la touche marquée A sur un clavier français : KeyCode.Q), ButtonB, ou bouton tactile « DASH ».
--
-- Boutons tactiles : une rangée en bas à droite, AU-DESSUS du bouton de saut de Roblox (qui occupe les ~110 studs du
-- bas) et loin du joystick (bas gauche) : « DASH » à droite, « COURIR » à sa gauche. Visibles seulement sur un appareil
-- tactile et seulement une fois la capacité débloquée. Les icônes d'état (recharge...) sont à l'interface (Interface/).
--
-- Une seule connexion par image au plus : RenderStepped n'est connecté que pendant les 0,45 s d'une vrille.
-- Toutes les connexions d'un personnage sont coupées à CharacterRemoving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Mouvement = require(ReplicatedStorage.Partage.Capacites)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local TOUCHE_DASH = Enum.KeyCode.Q -- la touche marquée A sur un clavier français (AZERTY)
local TOUCHE_COURSE = Enum.KeyCode.LeftShift
local DUREE_FOV = 0.2 -- secondes : le champ de vision s'élargit et revient en douceur
local TAILLE_BOUTON = 64 -- pixels

type Vrille = {
	articulation: Motor6D,
	c0: CFrame, -- la valeur d'origine, remise à la fin
	debut: number,
	connexion: RBXScriptConnection?,
}

type DashActif = {
	id: number,
	attache: Attachment,
	vitesse: LinearVelocity,
	direction: Vector3,
}

-- Tout ce qui dépend du personnage actuel ; remplacé (et défait) à chaque apparition.
type Session = {
	actif: boolean,
	personnage: Model,
	humanoide: Humanoid,
	racine: BasePart,
	connexions: { RBXScriptConnection },
	enCourse: boolean,
	vitesseBase: number, -- WalkSpeed avant la course
	fovBase: number, -- champ de vision avant la course
	tweenFov: Tween?,
	doubleDispo: boolean, -- le double saut de cet envol n'est pas encore utilisé
	dashDispo: boolean, -- le dash de cet envol n'est pas encore utilisé
	dash: DashActif?,
	vrille: Vrille?,
}

local joueur = Players.LocalPlayer
local debloquees: { [string]: boolean } = {}
local sourcesCourse: { [string]: boolean } = {} -- qui demande de courir : clavier, manette, tactile
local session: Session? = nil
local compteurDash = 0
local boutons: { course: TextButton?, dash: TextButton? } = {}
local demarre = false

-- Course ---------------------------------------------------------------------------------------------------------

local function courseVoulue(): boolean
	return debloquees.course == true
		and (sourcesCourse.clavier == true or sourcesCourse.manette == true or sourcesCourse.tactile == true)
end

local function animerFov(s: Session, cible: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if s.tweenFov then
		s.tweenFov:Cancel()
	end
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(DUREE_FOV, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = cible }
	)
	s.tweenFov = tween
	tween:Play()
end

--- Met la vitesse et le champ de vision d'accord avec « est-ce que je cours ? » (appelée à chaque changement).
local function appliquerCourse()
	local s = session
	if not s or not s.actif then
		return
	end
	local voulue = courseVoulue() and s.humanoide.Health > 0
	if voulue == s.enCourse then
		return
	end
	s.enCourse = voulue
	if voulue then
		s.vitesseBase = s.humanoide.WalkSpeed
		local camera = workspace.CurrentCamera
		s.fovBase = if camera then camera.FieldOfView else s.fovBase
		s.humanoide.WalkSpeed = s.vitesseBase * Reglages.COURSE_FACTEUR
		animerFov(s, s.fovBase + Reglages.COURSE_FOV_BONUS)
	else
		s.humanoide.WalkSpeed = s.vitesseBase
		animerFov(s, s.fovBase)
	end
end

local function definirSourceCourse(source: string, vrai: boolean)
	sourcesCourse[source] = vrai
	appliquerCourse()
end

-- Vrille (saut périlleux du double saut) ---------------------------------------------------------------------------
-- Méthode : on fait tourner le CORPS autour de la racine en modifiant le `C0` de l'articulation Motor6D qui relie la
-- HumanoidRootPart au reste du corps (« Root » en R15, « RootJoint » en R6), image par image, d'un tour complet en
-- VRILLE_DUREE secondes. La HumanoidRootPart, elle, ne tourne pas : la physique, le contrôle de l'Humanoid, la caméra
-- et le dash ne voient rien. L'Animator n'écrit que `Transform`, jamais `C0` : les animations continuent. Tourner la
-- racine elle-même (CFrame image par image) aurait lutté contre le Humanoid, qui la remet debout. Limite connue : le
-- C0 d'un client ne se réplique pas, donc seuls le joueur et sa caméra voient la vrille (les autres joueurs voient un
-- saut normal) ; pour la montrer aux autres, il faudrait un RemoteEvent de plus (hors de cette tâche).

local function trouverArticulation(racine: BasePart): Motor6D?
	for _, joint in racine:GetJoints() do
		if joint:IsA("Motor6D") and joint.Part0 == racine then
			return joint
		end
	end
	return nil
end

local function finirVrille(s: Session)
	local v = s.vrille
	if not v then
		return
	end
	s.vrille = nil
	if v.connexion then
		v.connexion:Disconnect()
	end
	if v.articulation.Parent then
		v.articulation.C0 = v.c0 -- remise exacte à l'état d'origine
	end
end

local function lancerVrille(s: Session)
	finirVrille(s)
	local articulation = trouverArticulation(s.racine)
	if not articulation then
		return
	end
	local v: Vrille = { articulation = articulation, c0 = articulation.C0, debut = os.clock(), connexion = nil }
	s.vrille = v
	v.connexion = RunService.RenderStepped:Connect(function()
		local avancement = (os.clock() - v.debut) / Reglages.VRILLE_DUREE
		if avancement >= 1 or not s.actif then
			finirVrille(s)
			return
		end
		-- Tour vers l'avant (angle négatif autour de l'axe X de la racine = la tête passe devant), sur l'origine de la
		-- racine : l'angle est calculé ici, à chaque image, d'après le temps écoulé.
		v.articulation.C0 = CFrame.Angles(-2 * math.pi * avancement, 0, 0) * v.c0
	end)
end

-- Double saut ----------------------------------------------------------------------------------------------------

--- Le personnage de référence de ce Humanoid, pour calculer la vitesse de son saut (JumpPower ou JumpHeight).
local function physiqueDe(humanoide: Humanoid): Mouvement.Physique
	local gravite = workspace.Gravity
	local hauteur = if humanoide.UseJumpPower then humanoide.JumpPower ^ 2 / (2 * gravite) else humanoide.JumpHeight
	return { vitesseMarche = humanoide.WalkSpeed, hauteurSaut = hauteur, gravite = gravite }
end

local function tenterDoubleSaut()
	local s = session
	if not s or not s.actif or debloquees.doubleSaut ~= true or not s.doubleDispo then
		return
	end
	local humanoide = s.humanoide
	local etat = humanoide:GetState()
	-- En l'air seulement : au sol, c'est le saut normal du Humanoid qui s'en occupe.
	if humanoide.Health <= 0 or humanoide.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if etat ~= Enum.HumanoidStateType.Freefall and etat ~= Enum.HumanoidStateType.Jumping then
		return
	end
	s.doubleDispo = false
	-- Impulsion verticale : on impose la vitesse verticale du saut (FACTEUR x celle d'un saut simple), sans toucher à la
	-- vitesse horizontale. On pose la vitesse de l'assemblage plutôt que d'appliquer une force sur la racine, qui
	-- ferait aussi tourner le personnage (la racine n'est pas à son centre de masse).
	local vitesse = s.racine.AssemblyLinearVelocity
	local cible = Mouvement.vitesseSaut(physiqueDe(humanoide)) * Reglages.SAUT_DOUBLE_FACTEUR
	s.racine.AssemblyLinearVelocity = Vector3.new(vitesse.X, math.max(vitesse.Y, cible), vitesse.Z)
	lancerVrille(s)
end

-- Dash -----------------------------------------------------------------------------------------------------------

--- La direction du regard à plat (la caméra ; l'orientation du personnage si la caméra regarde à la verticale).
local function directionRegard(s: Session): Vector3?
	local camera = workspace.CurrentCamera
	local regard = if camera then camera.CFrame.LookVector else s.racine.CFrame.LookVector
	local plat = Vector3.new(regard.X, 0, regard.Z)
	if plat.Magnitude < 0.1 then
		local devant = s.racine.CFrame.LookVector
		plat = Vector3.new(devant.X, 0, devant.Z)
	end
	if plat.Magnitude < 0.1 then
		return nil
	end
	return plat.Unit
end

local function finirDash(s: Session, id: number)
	local d = s.dash
	if not d or d.id ~= id then
		return
	end
	s.dash = nil
	d.vitesse:Destroy()
	d.attache:Destroy()
	if not s.actif then
		return
	end
	-- Sans ça, la vitesse du dash (70 studs/s) serait conservée en l'air, et le saut s'allongerait bien au-delà de la
	-- distance voulue : à la fin on revient à la vitesse de marche (ou de course) dans la même direction.
	local vitesse = s.racine.AssemblyLinearVelocity
	local sortie = s.humanoide.WalkSpeed
	s.racine.AssemblyLinearVelocity = Vector3.new(d.direction.X * sortie, vitesse.Y, d.direction.Z * sortie)
	-- Un dash lancé au sol se recharge après un court délai si on est resté au sol ; en l'air, à l'atterrissage.
	if s.humanoide.FloorMaterial ~= Enum.Material.Air then
		task.delay(Reglages.DASH_RECHARGE_SOL, function()
			if s.actif and s.dash == nil and s.humanoide.FloorMaterial ~= Enum.Material.Air then
				s.dashDispo = true
			end
		end)
	end
end

local function lancerDash()
	local s = session
	if not s or not s.actif or debloquees.dash ~= true or not s.dashDispo or s.dash ~= nil then
		return
	end
	if s.humanoide.Health <= 0 or s.humanoide.Sit then
		return
	end
	local direction = directionRegard(s)
	if not direction then
		return
	end
	s.dashDispo = false
	compteurDash += 1
	local id = compteurDash

	-- Une contrainte physique (LinearVelocity) fixe la vitesse sur le plan horizontal pendant DASH_DUREE secondes, avec
	-- une force illimitée ; la verticale reste libre (la gravité continue). Elle est retirée à la fin : on ne
	-- téléporte jamais le personnage, il se déplace par la physique et rencontre les obstacles.
	local attache = Instance.new("Attachment")
	attache.Name = "DashAttache"
	attache.Parent = s.racine
	local vitesse = Instance.new("LinearVelocity")
	vitesse.Name = "DashVitesse"
	vitesse.Attachment0 = attache
	vitesse.RelativeTo = Enum.ActuatorRelativeTo.World
	vitesse.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	vitesse.PrimaryTangentAxis = Vector3.xAxis
	vitesse.SecondaryTangentAxis = Vector3.zAxis
	vitesse.PlaneVelocity = Vector2.new(direction.X * Reglages.DASH_VITESSE, direction.Z * Reglages.DASH_VITESSE)
	vitesse.MaxForce = math.huge
	vitesse.Parent = s.racine
	s.dash = { id = id, attache = attache, vitesse = vitesse, direction = direction }

	-- Le personnage regarde où il file (une seule fois, au départ : rien n'est forcé ensuite).
	local position = s.racine.Position
	s.racine.CFrame = CFrame.lookAt(position, position + direction)

	task.delay(Reglages.DASH_DUREE, finirDash, s, id)
end

-- Personnage ------------------------------------------------------------------------------------------------------

local function fermerSession()
	local s = session
	if not s then
		return
	end
	session = nil
	s.actif = false
	for _, connexion in s.connexions do
		connexion:Disconnect()
	end
	table.clear(s.connexions)
	finirVrille(s)
	if s.dash then
		s.dash.vitesse:Destroy()
		s.dash.attache:Destroy()
		s.dash = nil
	end
	if s.tweenFov then
		s.tweenFov:Cancel()
	end
	if s.enCourse then
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = s.fovBase -- le champ de vision revient à la normale, même si le personnage disparaît
		end
	end
end

local function ouvrirSession(personnage: Model)
	local humanoide = personnage:WaitForChild("Humanoid", 10)
	local racine = personnage:WaitForChild("HumanoidRootPart", 10)
	if not humanoide or not humanoide:IsA("Humanoid") or not racine or not racine:IsA("BasePart") then
		return
	end
	if joueur.Character ~= personnage then
		return -- un autre personnage est déjà apparu pendant l'attente
	end
	fermerSession()

	local camera = workspace.CurrentCamera
	local s: Session = {
		actif = true,
		personnage = personnage,
		humanoide = humanoide,
		racine = racine,
		connexions = {},
		enCourse = false,
		vitesseBase = humanoide.WalkSpeed,
		fovBase = if camera then camera.FieldOfView else 70,
		tweenFov = nil,
		doubleDispo = true,
		dashDispo = true,
		dash = nil,
		vrille = nil,
	}
	session = s

	-- Recharge : au contact du sol. Landed = atterrissage après un envol (recharge double saut et dash) ;
	-- Running = au sol (recharge le double saut ; le dash lancé au sol a son propre délai).
	table.insert(
		s.connexions,
		humanoide.StateChanged:Connect(function(_, nouvel)
			if nouvel == Enum.HumanoidStateType.Landed then
				s.doubleDispo = true
				s.dashDispo = true
			elseif nouvel == Enum.HumanoidStateType.Running or nouvel == Enum.HumanoidStateType.RunningNoPhysics then
				s.doubleDispo = true
			end
		end)
	)
	table.insert(
		s.connexions,
		humanoide.Died:Connect(function()
			finirVrille(s)
			appliquerCourse() -- plus de course pour un personnage mort : la vitesse et le champ de vision se remettent
		end)
	)
	appliquerCourse()
end

-- Boutons tactiles -----------------------------------------------------------------------------------------------

local function rafraichirBoutons()
	if boutons.course then
		boutons.course.Visible = debloquees.course == true
	end
	if boutons.dash then
		boutons.dash.Visible = debloquees.dash == true
	end
end

local function creerBouton(parent: Instance, texte: string, decalageX: number): TextButton
	local bouton = Instance.new("TextButton")
	bouton.Name = texte
	bouton.AnchorPoint = Vector2.new(1, 1)
	-- Au-dessus du bouton de saut de Roblox (qui monte au plus à 110 px du bas), à droite, hors du joystick.
	bouton.Position = UDim2.new(1, decalageX, 1, -135)
	bouton.Size = UDim2.fromOffset(TAILLE_BOUTON, TAILLE_BOUTON)
	bouton.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bouton.BackgroundTransparency = 0.35
	bouton.AutoButtonColor = true
	bouton.Text = texte
	bouton.TextColor3 = Color3.new(1, 1, 1)
	bouton.TextSize = 14
	bouton.Font = Enum.Font.GothamBold
	bouton.Visible = false
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(1, 0)
	coin.Parent = bouton
	local contour = Instance.new("UIStroke")
	contour.Color = Color3.fromRGB(240, 240, 255)
	contour.Transparency = 0.4
	contour.Thickness = 2
	contour.Parent = bouton
	bouton.Parent = parent
	return bouton
end

local function estAppui(entree: InputObject): boolean
	return entree.UserInputType == Enum.UserInputType.Touch or entree.UserInputType == Enum.UserInputType.MouseButton1
end

local function creerBoutonsTactiles()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CapacitesBoutons"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- les décalages se comptent depuis le vrai bas de l'écran, comme le bouton de saut
	gui.DisplayOrder = 1
	gui.Parent = joueur:WaitForChild("PlayerGui")

	local dash = creerBouton(gui, "DASH", -40)
	local course = creerBouton(gui, "COURIR", -40 - TAILLE_BOUTON - 16)
	boutons.dash = dash
	boutons.course = course

	-- Appui (pas relâchement) pour le dash : la réponse est immédiate ; maintenir pour courir.
	dash.InputBegan:Connect(function(entree)
		if estAppui(entree) then
			lancerDash()
		end
	end)
	course.InputBegan:Connect(function(entree)
		if estAppui(entree) then
			definirSourceCourse("tactile", true)
		end
	end)
	course.InputEnded:Connect(function(entree)
		if estAppui(entree) then
			definirSourceCourse("tactile", false)
		end
	end)
	rafraichirBoutons()
end

-- État reçu du serveur ---------------------------------------------------------------------------------------------

local function noterDebloquee(nom: string)
	if Mouvement.estCapacite(nom) then
		debloquees[nom] = true
	end
end

local function surEtat(etat: any)
	-- `capacites` est ajouté à EtatCourse par la progression ; absent, on ne change rien.
	local liste = if typeof(etat) == "table" then etat.capacites else nil
	if typeof(liste) ~= "table" then
		return
	end
	for _, nom in Mouvement.TOUTES do
		debloquees[nom] = liste[nom] == true
	end
	rafraichirBoutons()
	appliquerCourse()
end

local Capacites = {}

--- Les capacités débloquées côté client (copie), pour l'interface.
function Capacites.debloquees(): { [string]: boolean }
	return table.clone(debloquees)
end

function Capacites.demarrer()
	if demarre then
		return
	end
	demarre = true

	UserInputService.InputBegan:Connect(function(entree, traite)
		local touche = entree.KeyCode
		if touche == TOUCHE_COURSE then
			if not traite then -- pas pendant qu'on écrit dans le chat
				definirSourceCourse("clavier", true)
			end
		elseif touche == Enum.KeyCode.ButtonL2 then
			definirSourceCourse("manette", true)
		elseif touche == TOUCHE_DASH or touche == Enum.KeyCode.ButtonB then
			if not traite then
				lancerDash()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(entree)
		if entree.KeyCode == TOUCHE_COURSE then
			definirSourceCourse("clavier", false)
		elseif entree.KeyCode == Enum.KeyCode.ButtonL2 then
			definirSourceCourse("manette", false)
		end
	end)
	-- Fenêtre quittée touche enfoncée : le relâchement ne serait jamais reçu.
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(sourcesCourse)
		appliquerCourse()
	end)
	UserInputService.JumpRequest:Connect(tenterDoubleSaut)

	if UserInputService.TouchEnabled then
		task.spawn(creerBoutonsTactiles)
	end

	-- Le personnage : une session par apparition, défaite à la disparition.
	joueur.CharacterRemoving:Connect(fermerSession)
	joueur.CharacterAdded:Connect(function(personnage)
		task.spawn(ouvrirSession, personnage)
	end)
	if joueur.Character then
		task.spawn(ouvrirSession, joueur.Character)
	end

	-- Les remotes : sans bloquer le démarrage du reste du client.
	task.spawn(function()
		Remotes.obtenir("CapaciteDebloquee").OnClientEvent:Connect(function(nom: any)
			if typeof(nom) == "string" then
				noterDebloquee(nom)
				rafraichirBoutons()
				appliquerCourse()
			end
		end)
		Remotes.obtenir("EtatCourse").OnClientEvent:Connect(surEtat)
	end)
end

return Capacites
