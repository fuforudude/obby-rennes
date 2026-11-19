--!strict
-- Les effets visibles du dash, du double saut et de la course, sur le personnage de N'IMPORTE QUEL joueur : le sien
-- (joué tout de suite, sans attendre le réseau) ou celui d'un autre (rejoué quand le serveur relaie EffetCapacite).
-- Tout est visuel et local à ce client : rien ici ne touche à la physique ni au serveur. Les règles (quoi jouer, durées,
-- profils d'angle) sont dans partage/EffetsCapacites.luau (pur, testé) ; ce module les applique à des objets Roblox.
--
-- Ce qui se joue
--   dash       : corps penché en avant (rotation de l'articulation), traînée de la tête au bassin, lignes de vitesse
--                (ParticleEmitter orienté), petit choc de particules au point d'arrêt. Le champ de vision, lui, bouge
--                dans client/Capacites.luau (il ne concerne que la caméra du joueur local).
--   doubleSaut : vrille complète (c'est ICI qu'elle devient visible des autres : chaque client fait tourner l'articulation
--                du personnage qu'il voit, le C0 d'un Motor6D ne se répliquant pas), onde de choc (anneau) sous les
--                pieds, traînée qui suit la rotation.
--   course     : traînée légère au niveau des pieds, tant qu'on court (local : pas relayée aux autres).
-- Si ANIMATION_DASH / ANIMATION_DOUBLE_SAUT (Reglages) sont renseignés, l'animation Roblox est jouée à la place de la
-- rotation calculée ; le reste ne change pas.
--
-- Performances : aucun objet n'est créé à l'image. Une seule connexion RenderStepped, branchée seulement tant qu'un corps
-- tourne ou se penche (quelques dixièmes de secondes) ; chaque effet crée quelques objets (traînée, émetteurs, anneau) et
-- les détruit à la fin.
--
-- Fin de vie : un enregistrement par personnage regroupe tout ce qui a été créé pour lui. S'il meurt (Humanoid.Died),
-- disparaît du Workspace (déconnexion du joueur, réapparition, streaming) ou si le code l'arrête (`arreter`), TOUT est
-- détruit sur le champ : objets, tweens, animations, connexions, et le C0 de l'articulation est remis à l'identique.
-- Un effet d'un autre joueur ne peut donc jamais bloquer le jeu si son personnage disparaît en cours : rien n'attend ni
-- ne boucle sur lui, et chaque `task.delay` ne fait que détruire ce qui existe encore.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EffetsCapacites = require(ReplicatedStorage.Partage.EffetsCapacites)
local Reglages = require(ReplicatedStorage.Partage.Reglages)

-- Les couleurs des capacités : les mêmes que celles des icônes de l'interface (Interface/Composants.luau).
local COULEURS: { [string]: Color3 } = {
	course = Color3.fromRGB(40, 130, 230),
	doubleSaut = Color3.fromRGB(40, 170, 90),
	dash = Color3.fromRGB(235, 120, 30),
}
local BLANC = Color3.new(1, 1, 1)

-- Lignes de vitesse : étirement des particules le long de leur vitesse (ParticleEmitter.Squash). À inverser de signe si
-- elles apparaissent en carrés ou en tirets trop courts.
local LIGNES_ETIREMENT = -2.5
local LIGNES_DEBIT = 90 -- particules par seconde pendant le dash
local INCLINAISON_PROLONGEMENT = 0.1 -- s : le penché se prolonge un peu après la fin de la poussée, puis redresse

type Mouvement = { debut: number, duree: number }

type Enregistrement = {
	personnage: Model,
	humanoide: Humanoid,
	racine: BasePart,
	actif: boolean,
	objets: { [Instance]: boolean }, -- ce qui a été créé pour ce personnage et qui vit encore
	connexions: { RBXScriptConnection },
	tweens: { Tween },
	pistes: { AnimationTrack },
	articulation: Motor6D?, -- l'articulation tournée, tant qu'un penché ou une vrille est en cours
	c0: CFrame, -- son C0 d'origine, remis à la fin
	inclinaison: Mouvement?,
	vrille: Mouvement?,
	course: { Instance }?, -- la traînée de course et ses attaches, tant qu'on court
}

local registre: { [Model]: Enregistrement } = {}
local enCorps: { [Enregistrement]: boolean } = {} -- ceux dont le corps tourne ou se penche (animé à chaque image)
local connexionImage: RBXScriptConnection? = nil

local Effets = {}

-- Fin de vie -------------------------------------------------------------------------------------------------------

--- Remet le corps droit : C0 d'origine, plus de mouvement en cours.
local function terminerCorps(rec: Enregistrement)
	local articulation = rec.articulation
	rec.articulation = nil
	rec.inclinaison = nil
	rec.vrille = nil
	enCorps[rec] = nil
	if articulation and articulation.Parent then
		articulation.C0 = rec.c0 -- remise exacte à l'état d'origine
	end
end

--- Détruit tout ce qui a été créé pour ce personnage. Sans danger si déjà fait.
local function abandonner(rec: Enregistrement)
	if not rec.actif then
		return
	end
	rec.actif = false
	registre[rec.personnage] = nil
	for _, connexion in rec.connexions do
		connexion:Disconnect()
	end
	table.clear(rec.connexions)
	terminerCorps(rec)
	for _, tween in rec.tweens do
		tween:Cancel()
	end
	table.clear(rec.tweens)
	for _, piste in rec.pistes do
		piste:Stop(0)
		piste:Destroy()
	end
	table.clear(rec.pistes)
	for objet in rec.objets do
		objet:Destroy()
	end
	table.clear(rec.objets)
	rec.course = nil
end

--- Marque un objet comme créé pour ce personnage ; détruit au bout de `duree` secondes si elle est donnée.
local function adopter(rec: Enregistrement, objet: Instance, duree: number?)
	rec.objets[objet] = true
	if duree then
		task.delay(duree, function()
			if rec.objets[objet] then
				rec.objets[objet] = nil
				objet:Destroy()
			end
		end)
	end
end

--- Retrouve (ou crée) l'enregistrement d'un personnage. Rien si son Humanoid ou sa racine manquent, ou s'il est mort :
--- on ne bloque jamais en attendant une pièce qui n'arrive pas (personnage d'un autre joueur pas encore chargé).
local function obtenir(personnage: Model): Enregistrement?
	local existant = registre[personnage]
	if existant then
		return existant
	end
	local humanoide = personnage:FindFirstChildOfClass("Humanoid")
	local racine = personnage:FindFirstChild("HumanoidRootPart")
	if not humanoide or humanoide.Health <= 0 or not racine or not racine:IsA("BasePart") then
		return nil
	end
	if not personnage:IsDescendantOf(workspace) then
		return nil
	end
	local rec: Enregistrement = {
		personnage = personnage,
		humanoide = humanoide,
		racine = racine,
		actif = true,
		objets = {},
		connexions = {},
		tweens = {},
		pistes = {},
		articulation = nil,
		c0 = CFrame.identity,
		inclinaison = nil,
		vrille = nil,
		course = nil,
	}
	registre[personnage] = rec
	table.insert(
		rec.connexions,
		humanoide.Died:Connect(function()
			abandonner(rec)
		end)
	)
	table.insert(
		rec.connexions,
		personnage.AncestryChanged:Connect(function()
			if not personnage:IsDescendantOf(workspace) then
				abandonner(rec)
			end
		end)
	)
	return rec
end

-- Corps penché et vrille ---------------------------------------------------------------------------------------------
-- Méthode (celle de la vrille d'origine) : on fait tourner le CORPS autour de la racine en modifiant le `C0` de
-- l'articulation Motor6D qui relie la HumanoidRootPart au reste (« Root » en R15, « RootJoint » en R6), à chaque image,
-- d'après le temps écoulé. La racine ne tourne pas : physique, contrôle de l'Humanoid et caméra ne voient rien.
-- Le penché et la vrille sont des rotations autour du même axe : on additionne leurs angles, ils peuvent se chevaucher
-- (un dash pendant une vrille).

local function trouverArticulation(racine: BasePart): Motor6D?
	for _, joint in racine:GetJoints() do
		if joint:IsA("Motor6D") and joint.Part0 == racine then
			return joint
		end
	end
	return nil
end

local function surImage()
	local maintenant = os.clock()
	for rec in enCorps do
		local articulation = rec.articulation
		if not rec.actif or not articulation or not articulation.Parent then
			terminerCorps(rec)
			continue
		end
		local angle = 0
		local inclinaison = rec.inclinaison
		if inclinaison then
			local avancement = (maintenant - inclinaison.debut) / inclinaison.duree
			if avancement >= 1 then
				rec.inclinaison = nil
			else
				angle += EffetsCapacites.angleInclinaison(avancement, Reglages.DASH_INCLINAISON)
			end
		end
		local vrille = rec.vrille
		if vrille then
			local avancement = (maintenant - vrille.debut) / vrille.duree
			if avancement >= 1 then
				rec.vrille = nil
			else
				angle += EffetsCapacites.angleVrille(avancement)
			end
		end
		if rec.inclinaison == nil and rec.vrille == nil then
			terminerCorps(rec)
		else
			-- Angle négatif autour de l'axe X de la racine = la tête passe devant (vers l'avant).
			articulation.C0 = CFrame.Angles(-angle, 0, 0) * rec.c0
		end
	end
	if next(enCorps) == nil and connexionImage then
		connexionImage:Disconnect()
		connexionImage = nil
	end
end

local function demarrerCorps(rec: Enregistrement, duree: number, penche: boolean)
	if not rec.articulation then
		local articulation = trouverArticulation(rec.racine)
		if not articulation then
			return
		end
		rec.articulation = articulation
		rec.c0 = articulation.C0 -- l'original, lu avant toute rotation (jamais pendant qu'une rotation est en cours)
	end
	local mouvement: Mouvement = { debut = os.clock(), duree = duree }
	if penche then
		rec.inclinaison = mouvement
	else
		rec.vrille = mouvement
	end
	enCorps[rec] = true
	if not connexionImage then
		connexionImage = RunService.RenderStepped:Connect(surImage)
	end
end

-- Animation Roblox à la place de la rotation -----------------------------------------------------------------------

local function jouerAnimation(rec: Enregistrement, identifiant: string)
	local animateur = rec.humanoide:FindFirstChildOfClass("Animator")
	if not animateur then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = identifiant
	local ok, resultat = pcall(function()
		return animateur:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		return -- identifiant refusé : on s'en passe, rien ne casse
	end
	local piste: AnimationTrack = resultat :: any
	piste.Looped = false -- une animation qui boucle ne finirait jamais
	piste.Priority = Enum.AnimationPriority.Action
	table.insert(rec.pistes, piste)
	piste.Stopped:Once(function()
		local i = table.find(rec.pistes, piste)
		if i then
			table.remove(rec.pistes, i)
		end
		piste:Destroy()
	end)
	piste:Play(0.05)
end

-- Objets d'effet -----------------------------------------------------------------------------------------------------

--- Les deux attaches d'une traînée qui suit le corps : la tête et le bas du tronc (la traînée balaie donc tout le corps,
--- et suit la rotation d'une vrille). À défaut, deux points de la racine.
local function attachesDuCorps(rec: Enregistrement): (Attachment, Attachment)
	local tete = rec.personnage:FindFirstChild("Head")
	local bas = rec.personnage:FindFirstChild("LowerTorso") or rec.personnage:FindFirstChild("Torso")
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	if tete and tete:IsA("BasePart") and bas and bas:IsA("BasePart") then
		a0.Position = Vector3.new(0, 0.3, 0)
		a0.Parent = tete
		a1.Position = Vector3.new(0, -0.4, 0)
		a1.Parent = bas
	else
		a0.Position = Vector3.new(0, 1.5, 0)
		a0.Parent = rec.racine
		a1.Position = Vector3.new(0, -1.5, 0)
		a1.Parent = rec.racine
	end
	return a0, a1
end

--- Une traînée entre deux attaches, de la couleur donnée, qui s'efface en `duree` secondes.
local function creerTrainee(
	a0: Attachment,
	a1: Attachment,
	couleur: Color3,
	duree: number,
	transparenceDepart: number
): Trail
	local trainee = Instance.new("Trail")
	trainee.Attachment0 = a0
	trainee.Attachment1 = a1
	trainee.Lifetime = duree
	trainee.Color = ColorSequence.new(couleur)
	trainee.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transparenceDepart),
		NumberSequenceKeypoint.new(1, 1),
	})
	trainee.LightEmission = 0.7
	trainee.MinLength = 0.05
	trainee.FaceCamera = true
	trainee.Parent = a0.Parent
	return trainee
end

--- Pose une traînée de capacité sur le corps pendant `enMouvement` secondes, puis la laisse s'effacer.
local function trainerCorps(rec: Enregistrement, capacite: string, enMouvement: number)
	local a0, a1 = attachesDuCorps(rec)
	local duree = EffetsCapacites.dureeTrainee(capacite)
	local trainee = creerTrainee(a0, a1, COULEURS[capacite] or BLANC, duree, 0.15)
	local reste = enMouvement + duree + 0.1 -- le temps que la queue s'efface, avant de tout détruire
	adopter(rec, a0, reste)
	adopter(rec, a1, reste)
	adopter(rec, trainee, reste)
	task.delay(enMouvement, function()
		if rec.objets[trainee] then
			trainee.Enabled = false -- plus de nouveaux morceaux : la queue s'efface seule
		end
	end)
end

--- Des particules courtes (étincelles) émises une seule fois en un point du monde : le choc d'un arrivée.
local function eclater(rec: Enregistrement, position: Vector3, couleur: Color3, nombre: number)
	local attache = Instance.new("Attachment")
	attache.WorldPosition = position
	attache.Parent = workspace.Terrain -- une attache posée dans le monde : elle reste là où le choc a eu lieu
	local emetteur = Instance.new("ParticleEmitter")
	emetteur.Rate = 0
	emetteur.Lifetime = NumberRange.new(0.25, 0.45)
	emetteur.Speed = NumberRange.new(10, 22)
	emetteur.SpreadAngle = Vector2.new(80, 80)
	emetteur.EmissionDirection = Enum.NormalId.Top
	emetteur.Acceleration = Vector3.new(0, -30, 0)
	emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emetteur.Color = ColorSequence.new(couleur)
	emetteur.LightEmission = 0.8
	emetteur.Parent = attache
	adopter(rec, attache, 0.8)
	emetteur:Emit(nombre)
end

--- Les lignes de vitesse du dash : un émetteur sur la racine, qui crache vers l'arrière des particules étirées le long de
--- leur vitesse, laissées dans le monde (elles « défilent » à mesure que le personnage avance).
local function lancerLignes(rec: Enregistrement, duree: number)
	local attache = Instance.new("Attachment")
	attache.Parent = rec.racine
	local emetteur = Instance.new("ParticleEmitter")
	emetteur.Rate = LIGNES_DEBIT
	emetteur.Lifetime = NumberRange.new(0.15, 0.3)
	emetteur.Speed = NumberRange.new(8, 16)
	emetteur.SpreadAngle = Vector2.new(30, 30)
	emetteur.EmissionDirection = Enum.NormalId.Back -- derrière le personnage (la racine regarde dans le sens du dash)
	emetteur.Orientation = Enum.ParticleOrientation.VelocityParallel
	emetteur.Squash = NumberSequence.new(LIGNES_ETIREMENT)
	emetteur.LockedToPart = false -- les lignes restent dans le monde
	emetteur.Size = NumberSequence.new(0.9)
	emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emetteur.Color = ColorSequence.new(BLANC)
	emetteur.LightEmission = 1
	emetteur.Parent = attache
	adopter(rec, attache, duree + 0.5) -- le temps que les dernières particules s'éteignent
	task.delay(duree, function()
		if rec.objets[attache] then
			emetteur.Enabled = false
		end
	end)
end

--- L'onde de choc : un anneau posé dans le monde sous les pieds, qui grandit et s'efface (aucune pièce n'a de collision).
local function lancerOnde(rec: Enregistrement)
	local pied = rec.humanoide.HipHeight + rec.racine.Size.Y / 2
	local support = Instance.new("Part")
	support.Name = "OndeDeChoc"
	support.Anchored = true
	support.CanCollide = false
	support.CanQuery = false
	support.CanTouch = false
	support.CastShadow = false
	support.Transparency = 1
	support.Size = Vector3.new(1, 1, 1)
	support.CFrame = CFrame.new(rec.racine.Position - Vector3.new(0, pied, 0))
	local anneau = EffetsCapacites.anneau(Reglages.VRILLE_ONDE_RAYON)
	local bande = Instance.new("CylinderHandleAdornment")
	bande.Adornee = support
	bande.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- l'axe du cylindre debout : l'anneau est à plat
	bande.Height = 0.15
	bande.Radius = anneau.rayonDepart
	bande.InnerRadius = anneau.interieurDepart
	bande.Color3 = COULEURS.doubleSaut
	bande.Transparency = 0.25
	bande.Parent = support
	support.Parent = workspace.Terrain
	adopter(rec, support, Reglages.VRILLE_ONDE_DUREE + 0.1)
	local tween = TweenService:Create(
		bande,
		TweenInfo.new(Reglages.VRILLE_ONDE_DUREE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Radius = anneau.rayonFin, InnerRadius = anneau.interieurFin, Transparency = 1 }
	)
	table.insert(rec.tweens, tween)
	tween:Play()
end

-- Les effets ---------------------------------------------------------------------------------------------------------

local function jouerDash(rec: Enregistrement, plan: EffetsCapacites.Plan)
	local duree = EffetsCapacites.duree("dash")
	if plan.inclinaison then
		demarrerCorps(rec, duree + INCLINAISON_PROLONGEMENT, true)
	end
	if plan.animation then
		jouerAnimation(rec, plan.animation)
	end
	if plan.trainee then
		trainerCorps(rec, "dash", duree)
	end
	if plan.lignes then
		lancerLignes(rec, duree)
	end
	if plan.choc then
		task.delay(duree, function()
			if rec.actif then
				local pied = rec.humanoide.HipHeight + rec.racine.Size.Y / 2
				eclater(
					rec,
					rec.racine.Position - Vector3.new(0, pied - 0.2, 0),
					COULEURS.dash,
					Reglages.DASH_CHOC_PARTICULES
				)
			end
		end)
	end
end

local function jouerDoubleSaut(rec: Enregistrement, plan: EffetsCapacites.Plan)
	local duree = EffetsCapacites.duree("doubleSaut")
	if plan.onde then
		lancerOnde(rec)
	end
	if plan.vrille then
		demarrerCorps(rec, duree, false)
	end
	if plan.animation then
		jouerAnimation(rec, plan.animation)
	end
	if plan.trainee then
		trainerCorps(rec, "doubleSaut", duree)
	end
end

--- Joue l'effet d'une capacité ("dash" ou "doubleSaut") sur le personnage donné (celui du joueur local ou d'un autre).
--- Sans effet si le personnage est incomplet, mort ou absent du Workspace.
function Effets.jouer(capacite: string, personnage: Model)
	local animation = if capacite == "dash"
		then Reglages.ANIMATION_DASH
		elseif capacite == "doubleSaut" then Reglages.ANIMATION_DOUBLE_SAUT
		else nil
	local plan = EffetsCapacites.plan(capacite, animation)
	if not plan then
		return
	end
	local rec = obtenir(personnage)
	if not rec then
		return
	end
	if capacite == "dash" then
		jouerDash(rec, plan)
	else
		jouerDoubleSaut(rec, plan)
	end
end

--- La traînée légère de la course, au niveau des pieds : posée quand on se met à courir, laissée à s'effacer quand on
--- s'arrête. Appeler plusieurs fois avec la même valeur ne fait rien de plus.
function Effets.course(personnage: Model, court: boolean)
	local rec = if court then obtenir(personnage) else registre[personnage]
	if not rec then
		return
	end
	local actuelle = rec.course
	if court then
		if actuelle then
			return
		end
		local pied = rec.humanoide.HipHeight + rec.racine.Size.Y / 2 - 0.15
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-0.6, -pied, 0)
		a0.Parent = rec.racine
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0.6, -pied, 0)
		a1.Parent = rec.racine
		local trainee = creerTrainee(a0, a1, COULEURS.course, Reglages.COURSE_TRAINEE_DUREE, 0.6)
		-- Annoté : sans ça Luau déduit `{ Attachment }` des deux premiers éléments et refuse la `Trail`.
		local objets: { Instance } = { a0, a1, trainee }
		rec.course = objets
		adopter(rec, a0)
		adopter(rec, a1)
		adopter(rec, trainee)
	elseif actuelle then
		rec.course = nil
		local reste = Reglages.COURSE_TRAINEE_DUREE + 0.1
		for _, objet in actuelle do
			if objet:IsA("Trail") then
				objet.Enabled = false
			end
			adopter(rec, objet, reste)
		end
	end
end

--- Arrête tout sur ce personnage et détruit tout ce qui a été créé (mort, réapparition, départ du joueur).
function Effets.arreter(personnage: Model)
	local rec = registre[personnage]
	if rec then
		abandonner(rec)
	end
end

return Effets
