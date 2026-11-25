--!strict
-- Les mesures envoyées à Roblox (AnalyticsService, visibles dans le Creator Hub) : l'entonnoir « première partie » et
-- les morts par étape. Règles pures et testées : src/partage/Mesures.luau.
-- Roblox n'accepte les envois que d'un serveur de place publiée : rien ne part de Studio.
-- Un testeur n'a pas de suivi, et Parcours et Ascension disent si le joueur a volé : aucune mesure d'un vol
-- (ReglesMesures.estMesure). Seul champ ajouté : le numéro d'étape ; jamais d'identifiant ni de nom de joueur.
-- Une erreur ici n'atteint jamais l'appelant : chaque fonction publique tourne dans son propre fil.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Donnees = require(script.Parent.Donnees)
local Etapes = require(ReplicatedStorage.Partage.Etapes)
local Regles = require(ReplicatedStorage.Partage.Regles)
local ReglesMesures = require(ReplicatedStorage.Partage.Mesures)
local Reglages = require(ReplicatedStorage.Partage.Reglages)

-- Voir Parcours.luau : `pcall` d'une fonction qui ne rend rien, cast local pour les types.
local pcallAvecErreur: (...any) -> (boolean, any) = pcall :: any

local EVENEMENT_MORTS = "MortsParEtape"
local CHAMP_ETAPE = Enum.AnalyticsCustomFieldKeys.CustomField01.Name

local suivis: { [Player]: ReglesMesures.Suivi } = {}
local prevenu = false

--- Un envoi à Roblox : jamais depuis Studio, jamais d'erreur pour l'appelant, et un seul avertissement par serveur.
local function envoyer(fonction: () -> ())
	if RunService:IsStudio() then
		return
	end
	local ok, erreur = pcallAvecErreur(fonction)
	if not ok and not prevenu then
		prevenu = true
		warn(`[Mesures] envoi en échec (les suivants ne sont plus signalés) : {erreur}`)
	end
end

local function nomEtape(etape: number): string
	if etape == ReglesMesures.ARRIVEE_EN_JEU then
		return "Arrivée en jeu"
	elseif etape == ReglesMesures.etapePied(Reglages.NB_ETAPES) then
		return "Pied de la tour"
	elseif etape == ReglesMesures.etapeSommet(Reglages.NB_ETAPES) then
		return "Sommet de la tour"
	end
	local numero = etape - ReglesMesures.ARRIVEE_EN_JEU
	local infos = Etapes.obtenir(numero)
	return `Checkpoint {numero}` .. (if infos then ` : {infos.zone}` else "")
end

local function franchir(joueur: Player, etape: number)
	local suivi = suivis[joueur]
	if suivi and ReglesMesures.franchir(suivi, etape) then
		envoyer(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(joueur, etape, nomEtape(etape))
		end)
	end
end

local function envoyerMorts(joueur: Player, envoi: ReglesMesures.Envoi?)
	if envoi then
		envoyer(function()
			AnalyticsService:LogCustomEvent(joueur, EVENEMENT_MORTS, envoi.morts, {
				[CHAMP_ETAPE] = ReglesMesures.libelleEtape(envoi.etape),
			})
		end)
	end
end

--- Le suivi du joueur s'il est mesuré en ce moment (`vol` : il a volé pendant cette course), sinon nil.
local function suiviMesure(joueur: Player, vol: boolean): ReglesMesures.Suivi?
	return if ReglesMesures.estMesure(Reglages.TESTEURS, joueur.UserId, vol) then suivis[joueur] else nil
end

local function suivre(joueur: Player)
	if not suivis[joueur] and ReglesMesures.estMesure(Reglages.TESTEURS, joueur.UserId, false) then
		suivis[joueur] = ReglesMesures.nouveauSuivi()
		franchir(joueur, ReglesMesures.ARRIVEE_EN_JEU)
	end
end

local Mesures = {}

--- Le joueur vient de valider (ou d'acheter) ce checkpoint. `vol`, ici et plus bas : il a volé pendant cette course.
function Mesures.checkpoint(joueur: Player, numero: number, vol: boolean)
	task.spawn(function()
		local suivi = suiviMesure(joueur, vol)
		if suivi then
			franchir(joueur, ReglesMesures.etapeCheckpoint(numero))
			envoyerMorts(joueur, ReglesMesures.changerEtape(suivi, numero))
		end
	end)
end

--- Le joueur vient de mourir dans le parcours, son dernier checkpoint étant `etape`.
function Mesures.mort(joueur: Player, etape: number, vol: boolean)
	task.spawn(function()
		local suivi = suiviMesure(joueur, vol)
		if suivi then
			envoyerMorts(joueur, ReglesMesures.mort(suivi, etape))
		end
	end)
end

function Mesures.piedTour(joueur: Player, vol: boolean)
	task.spawn(function()
		if suiviMesure(joueur, vol) then
			franchir(joueur, ReglesMesures.etapePied(Reglages.NB_ETAPES))
		end
	end)
end

function Mesures.sommetTour(joueur: Player, vol: boolean)
	task.spawn(function()
		if suiviMesure(joueur, vol) then
			franchir(joueur, ReglesMesures.etapeSommet(Reglages.NB_ETAPES))
		end
	end)
end

function Mesures.demarrer()
	Players.PlayerAdded:Connect(suivre)
	for _, joueur in Players:GetPlayers() do
		suivre(joueur)
	end
	Donnees.surChargement(function(joueur: Player, donnees: Regles.Donnees)
		franchir(joueur, ReglesMesures.dejaAtteinte(donnees, Reglages.NB_ETAPES))
	end)
	Players.PlayerRemoving:Connect(function(joueur)
		local suivi = suivis[joueur]
		suivis[joueur] = nil
		if suivi then
			envoyerMorts(joueur, ReglesMesures.partir(suivi))
		end
	end)
end

return Mesures
