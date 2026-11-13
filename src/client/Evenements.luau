--!strict
-- Les événements de la carte : objets qui tombent des balcons, rame, drones de livraison, trafic. Tout ce qui porte
-- le tag `Evenement` est animé ici, par chaque client, d'après l'horloge du serveur (`workspace:GetServerTimeNow()`) :
-- tous les joueurs voient la même chose au même moment, sans que le serveur ne déplace rien (voir Horaires.luau
-- pour le cycle). Contrat des attributs : docs/specs/2026-11-13-evenements-batiments-interface.md.
--
-- Pendant le préavis, l'enfant facultatif `Preavis` (une BasePart : ombre au sol, phares) apparaît en clignotant, à
-- l'endroit où la carte l'a posé. Pendant le danger, l'objet se déplace (Passage : de Depart à Arrivee ; Chute : de
-- Hauteur studs au-dessus de sa place vers sa place, en accélérant). Hors danger, il est rangé très loin (rien n'est
-- détruit, pas d'ombre, pas de pièce à parcourir à chaque image).
--
-- Contact : si le personnage local touche une pièce de l'objet pendant le danger, le client le signale au serveur
-- (RemoteEvent ToucheParEvenement) qui vérifie et tue le joueur. Pourquoi pas `humanoide.Health = 0` ou
-- `humanoide:ChangeState(Dead)` ici : le client est bien propriétaire de son personnage, mais Roblox ne garantit
-- pas qu'une mort décidée côté client soit vue par le serveur (Humanoid.Died de Parcours.luau, qui compte la
-- chute) ; et ça n'a pas pu être essayé en jeu. Le signalement validé par le serveur est sûr à coup sûr.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Horaires = require(ReplicatedStorage.Partage.Horaires)
local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local TAG = "Evenement"
local DELAI_ENTRE_SIGNALEMENTS = Reglages.EVENEMENT_DELAI_MIN + 0.1 -- un peu plus que le serveur, qui ignore les rafales
local RANGEMENT = Vector3.new(0, 0, Reglages.EVENEMENT_RANGEMENT)

-- Une pièce de l'objet qui blesse : sa position relative au pivot de l'objet et sa demi-taille.
type Piece = { decalage: CFrame, demi: Vector3 }

type Evenement = {
	objet: PVInstance,
	params: Horaires.Parametres,
	posee: CFrame, -- le pivot tel que posé dans la carte
	pieces: { Piece },
	preavis: BasePart?,
	preavisPose: CFrame, -- où la carte a posé le préavis
	preavisVisible: boolean?, -- nil tant que pas encore appliqué
	actif: boolean?, -- nil tant que pas encore placé
}

local evenements: { Evenement } = {}
local parObjet: { [Instance]: Evenement } = {}
local demarre = false

-- Le personnage local, retrouvé quand il change (pas de recherche à chaque image).
local personnageSuivi: Model? = nil
local racine: BasePart? = nil
local humanoide: Humanoid? = nil
local dernierSignalement = -math.huge

local toucheParEvenement: RemoteEvent? = nil

local function estDansPreavis(descendant: Instance, preavis: BasePart?): boolean
	return preavis ~= nil and (descendant == preavis or descendant:IsDescendantOf(preavis))
end

local function collecterPieces(objet: PVInstance, posee: CFrame, preavis: BasePart?): { Piece }
	local pieces: { Piece } = {}
	local function ajouter(partie: BasePart)
		if not estDansPreavis(partie, preavis) then
			table.insert(pieces, { decalage = posee:ToObjectSpace(partie.CFrame), demi = partie.Size / 2 })
		end
	end
	if objet:IsA("BasePart") then
		ajouter(objet)
	end
	for _, d in objet:GetDescendants() do
		if d:IsA("BasePart") then
			ajouter(d)
		end
	end
	return pieces
end

local function enregistrer(instance: Instance)
	if parObjet[instance] then
		return
	end
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		warn(`[Evenements] {instance:GetFullName()} : un Model ou une BasePart est attendu`)
		return
	end
	local objet = instance :: PVInstance
	local params = Horaires.depuisAttributs(objet:GetAttributes())
	if not params then
		warn(
			`[Evenements] {objet:GetFullName()} : attributs invalides (Type, Periode, Decalage, Preavis, trajet), ignoré`
		)
		return
	end
	local posee = objet:GetPivot()
	local candidat = objet:FindFirstChild("Preavis")
	local preavis: BasePart? = if candidat and candidat:IsA("BasePart") then candidat else nil
	if candidat and not preavis then
		warn(`[Evenements] {objet:GetFullName()}.Preavis n'est pas une BasePart : ignoré`)
	end
	local evenement: Evenement = {
		objet = objet,
		params = params,
		posee = posee,
		pieces = collecterPieces(objet, posee, preavis),
		preavis = preavis,
		preavisPose = if preavis then preavis.CFrame else posee,
		preavisVisible = nil,
		actif = nil,
	}
	parObjet[objet] = evenement
	table.insert(evenements, evenement)
end

local function retirer(objet: Instance)
	local evenement = parObjet[objet]
	if not evenement then
		return
	end
	parObjet[objet] = nil
	local i = table.find(evenements, evenement)
	if i then
		table.remove(evenements, i)
	end
end

--- Montre ou range le préavis (la pièce garde sa place de la carte quand elle est montrée).
local function afficherPreavis(evenement: Evenement, visible: boolean)
	local preavis = evenement.preavis
	if preavis then
		preavis.CFrame = if visible then evenement.preavisPose else evenement.preavisPose + RANGEMENT
	end
	evenement.preavisVisible = visible
end

local function poseDuDanger(evenement: Evenement, progression: number): CFrame
	local params = evenement.params
	if params.type == "Passage" then
		local depart, arrivee = params.depart :: Vector3, params.arrivee :: Vector3
		return CFrame.new(depart:Lerp(arrivee, progression)) * evenement.posee.Rotation
	end
	-- Chute : part de Hauteur studs au-dessus, accélère (distance restante en 1 - progression²), finit à sa place.
	return evenement.posee + Vector3.new(0, (params.hauteur :: number) * (1 - progression * progression), 0)
end

--- Le centre du personnage est-il dans une pièce de l'objet, agrandie des marges de Reglages ?
local function touche(evenement: Evenement, pose: CFrame, position: Vector3): boolean
	local relatif = pose:PointToObjectSpace(position)
	local mh, mv = Reglages.EVENEMENT_MARGE_HORIZONTALE, Reglages.EVENEMENT_MARGE_VERTICALE
	for _, piece in evenement.pieces do
		local q = piece.decalage:PointToObjectSpace(relatif)
		local d = piece.demi
		if math.abs(q.X) <= d.X + mh and math.abs(q.Y) <= d.Y + mv and math.abs(q.Z) <= d.Z + mh then
			return true
		end
	end
	return false
end

local function suivrePersonnage()
	local personnage = Players.LocalPlayer.Character
	if personnage ~= personnageSuivi then
		personnageSuivi = personnage
		racine = nil
		humanoide = nil
	end
	if personnage and (racine == nil or humanoide == nil) then
		local r = personnage:FindFirstChild("HumanoidRootPart")
		local h = personnage:FindFirstChildOfClass("Humanoid")
		racine = if r and r:IsA("BasePart") then r else nil
		humanoide = h
	end
end

local function signaler(objet: PVInstance)
	local instant = os.clock()
	if instant - dernierSignalement < DELAI_ENTRE_SIGNALEMENTS then
		return
	end
	dernierSignalement = instant
	if toucheParEvenement then
		toucheParEvenement:FireServer(objet)
	end
end

local function surImage()
	local t = workspace:GetServerTimeNow()
	suivrePersonnage()
	local position: Vector3? = nil
	if racine and humanoide and humanoide.Health > 0 then
		position = racine.Position
	end

	for _, evenement in evenements do
		local params = evenement.params
		local etat, progression = Horaires.etat(t, params.periode, params.decalage, params.preavis, params.duree)
		if etat == "actif" then
			local pose = poseDuDanger(evenement, progression)
			evenement.objet:PivotTo(pose)
			evenement.actif = true
			-- Le préavis d'une chute (l'ombre) reste jusqu'à l'impact ; celui d'un passage s'éteint quand il arrive.
			-- Réappliqué à chaque image : le préavis est un enfant de l'objet, que PivotTo vient de déplacer.
			afficherPreavis(evenement, params.type == "Chute")
			if position and touche(evenement, pose, position) then
				signaler(evenement.objet)
			end
		else
			local visible = etat == "preavis"
				and Horaires.preavisAllume(progression, params.preavis, Reglages.EVENEMENT_CLIGNOTEMENT)
			if evenement.actif ~= false then
				evenement.objet:PivotTo(evenement.posee + RANGEMENT)
				evenement.actif = false
				afficherPreavis(evenement, visible)
			elseif evenement.preavisVisible ~= visible then
				afficherPreavis(evenement, visible)
			end
		end
	end
end

local Evenements = {}

function Evenements.demarrer()
	if demarre then
		return
	end
	demarre = true
	toucheParEvenement = Remotes.obtenir("ToucheParEvenement")
	CollectionService:GetInstanceAddedSignal(TAG):Connect(enregistrer)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(retirer)
	for _, objet in CollectionService:GetTagged(TAG) do
		enregistrer(objet)
	end
	-- Une seule connexion pour tous les événements, vivante tant que le jeu tourne.
	RunService.RenderStepped:Connect(surImage)
end

return Evenements
