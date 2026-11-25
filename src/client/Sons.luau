--!strict
-- Les sons du joueur local : effets et musique. Tout est joué ici, sur ce client ; le serveur n'en joue aucun et aucun
-- son ne change le résultat d'une action. Règles et catalogues : src/partage/Sons.luau.
--
-- Pour l'interface (valable pour la partie en cours, rien n'est sauvegardé ; tout est activé au lancement) :
--   Sons.couperMusique(b) / Sons.couperEffets(b)     true = coupé, false = remis
--   Sons.musiqueCoupee() / Sons.effetsCoupes()       l'état actuel
-- Couper met le volume du SoundGroup à zéro : la musique continue en silence et reprend là où elle en est.
--
-- Un seul objet Sound par son, réutilisé : un son qui ne charge pas est signalé une fois par Roblox, puis silencieux.
-- Les bruits de personnage de Roblox (pas, chute...) passent dans le groupe des effets pour que la coupure les prenne ;
-- sur son propre personnage, son saut et sa mort par défaut sont tus, remplacés par ceux du jeu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Regles = require(ReplicatedStorage.Partage.Sons)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local joueur = Players.LocalPlayer
local REMPLACES = { Jumping = true, Died = true } -- sons de personnage de Roblox (RbxCharacterSounds)

local groupes: { [string]: SoundGroup } = {}
local effets: { [string]: Sound } = {}
local musiques: { [string]: Sound } = {}
local fondus: { [Sound]: Tween } = {}
local musiqueActuelle: string? = nil
local etape: number? = nil
local enAscension = false
local demarre = false

local function groupe(nom: string): SoundGroup
	local existant = groupes[nom]
	if existant then
		return existant
	end
	local g = Instance.new("SoundGroup")
	g.Name = nom
	g.Volume = 1
	g.Parent = SoundService
	groupes[nom] = g
	return g
end

--- L'objet Sound de ce son (créé à la première demande), ou nil s'il n'a pas d'identifiant.
local function obtenir(
	registre: { [string]: Sound },
	catalogue: { [string]: Regles.Son },
	nom: string,
	nomGroupe: string
): Sound?
	local existant = registre[nom]
	if existant then
		return existant
	end
	local description = catalogue[nom]
	if not description or description.id == "" then
		return nil
	end
	local son = Instance.new("Sound")
	son.Name = nom
	son.SoundId = description.id
	son.Volume = description.volume
	son.SoundGroup = groupe(nomGroupe)
	son.Parent = SoundService
	registre[nom] = son
	return son
end

local function jouerEffet(nom: string, vitesse: number?)
	local son = obtenir(effets, Regles.EFFETS, nom, "Effets")
	if son then
		son.PlaybackSpeed = vitesse or 1
		son.TimePosition = 0
		son:Play()
	end
end

local function fondre(son: Sound, volume: number)
	local precedent = fondus[son]
	if precedent then
		precedent:Cancel()
	end
	local tween = TweenService:Create(son, TweenInfo.new(Regles.FONDU, Enum.EasingStyle.Linear), { Volume = volume })
	fondus[son] = tween
	tween.Completed:Once(function(etat)
		-- Un fondu remplacé entre-temps n'arrête rien : sa fin peut arriver après son remplacement.
		if fondus[son] == tween and etat == Enum.PlaybackState.Completed then
			fondus[son] = nil
			if volume == 0 then
				son:Stop()
			end
		end
	end)
	tween:Play()
end

--- Met la musique d'accord avec l'étape et la tour. Même musique : rien ne bouge (réapparaître ne la relance pas).
local function majMusique()
	local voulue = Regles.musique(etape, enAscension)
	if voulue == musiqueActuelle then
		return
	end
	local ancienne = if musiqueActuelle then musiques[musiqueActuelle] else nil
	musiqueActuelle = voulue
	if ancienne then
		fondre(ancienne, 0)
	end
	local nouvelle = if voulue then obtenir(musiques, Regles.MUSIQUES, voulue, "Musique") else nil
	if voulue and nouvelle then
		if not nouvelle.Playing then -- sinon elle s'effaçait encore : elle remonte d'où elle en est
			nouvelle.Looped = true
			nouvelle.Volume = 0
			nouvelle:Play()
		end
		fondre(nouvelle, Regles.MUSIQUES[voulue].volume)
	end
end

local function adopter(objet: Instance, estLocal: boolean)
	local parent = objet.Parent
	if objet:IsA("Sound") and parent and parent.Name == "HumanoidRootPart" then
		objet.SoundGroup = groupe("Effets")
		if estLocal and REMPLACES[objet.Name] then
			objet.Volume = 0
		end
	end
end

-- Connexions détruites avec le personnage : pas de fuite.
local function suivrePersonnage(personnage: Model, estLocal: boolean)
	personnage.DescendantAdded:Connect(function(objet)
		adopter(objet, estLocal)
	end)
	for _, objet in personnage:GetDescendants() do
		adopter(objet, estLocal)
	end
	if not estLocal then
		return
	end
	local humanoide = personnage:WaitForChild("Humanoid", 10)
	if humanoide and humanoide:IsA("Humanoid") then
		humanoide.StateChanged:Connect(function(_, etat)
			if etat == Enum.HumanoidStateType.Jumping then
				jouerEffet("saut")
			end
		end)
		humanoide.Died:Connect(function()
			jouerEffet("mort")
		end)
	end
end

local function suivre(autre: Player)
	local estLocal = autre == joueur
	autre.CharacterAdded:Connect(function(personnage)
		suivrePersonnage(personnage, estLocal)
	end)
	if autre.Character then
		task.spawn(suivrePersonnage, autre.Character, estLocal)
	end
end

local Sons = {}

--- Joue un effet du catalogue (clé de Regles.EFFETS). Ne lève jamais d'erreur chez l'appelant.
function Sons.jouer(nom: string)
	task.spawn(jouerEffet, nom)
end

--- L'état de la course, transmis par client/Capacites (seul des deux à se connecter à EtatCourse). Reçu avant
--- `demarrer`, il est mémorisé sans rien jouer, et appliqué au démarrage.
function Sons.surEtat(etat: any)
	if typeof(etat) ~= "table" or typeof(etat.etape) ~= "number" then
		return
	end
	local avant = etape
	etape = etat.etape
	if not demarre then
		return
	end
	if Regles.joueCheckpoint(avant, etat.etape, Reglages.NB_ETAPES) then
		jouerEffet("checkpoint", Regles.vitesseCheckpoint(etat.serie, Reglages.AURA_SERIE_MAX))
	end
	majMusique()
end

function Sons.couperMusique(b: boolean)
	groupe("Musique").Volume = if b then 0 else 1
end

function Sons.couperEffets(b: boolean)
	groupe("Effets").Volume = if b then 0 else 1
end

function Sons.musiqueCoupee(): boolean
	return groupe("Musique").Volume == 0
end

function Sons.effetsCoupes(): boolean
	return groupe("Effets").Volume == 0
end

function Sons.demarrer()
	if demarre then
		return
	end
	demarre = true

	-- Créés d'avance : le premier saut s'entend tout de suite au lieu d'attendre le chargement.
	for nom in Regles.EFFETS do
		obtenir(effets, Regles.EFFETS, nom, "Effets")
	end

	Players.PlayerAdded:Connect(suivre)
	for _, autre in Players:GetPlayers() do
		suivre(autre)
	end

	majMusique() -- l'état reçu avant le démarrage

	-- Les remotes : sans bloquer le démarrage du reste du client.
	task.spawn(function()
		Remotes.obtenir("EtatAscension").OnClientEvent:Connect(function(etat: Remotes.EtatAscension)
			enAscension = etat.enAscension
			majMusique()
		end)
		Remotes.obtenir("Arrivee").OnClientEvent:Connect(function(_temps: number, _classable: boolean, record: boolean)
			jouerEffet(Regles.arrivee(record))
		end)
		Remotes.obtenir("CapaciteDebloquee").OnClientEvent:Connect(function()
			jouerEffet("capacite")
		end)
	end)
end

return Sons
