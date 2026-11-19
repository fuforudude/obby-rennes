--!strict
-- Point d'entrée du serveur : démarre les services dans l'ordre où ils dépendent les uns des autres.
local Ascension = require(script.Ascension)
local Boutique = require(script.Boutique)
local Capacites = require(script.Capacites)
local Classement = require(script.Classement)
local Donnees = require(script.Donnees)
local Evenements = require(script.Evenements)
local Obstacles = require(script.Obstacles)
local Parcours = require(script.Parcours)

-- Un service qui plante au démarrage est signalé (nom et erreur dans la console) sans empêcher les suivants de
-- démarrer : une seule pièce ou un seul module cassé ne doit pas éteindre tout le jeu.
local function demarrer(nom: string, service: { demarrer: () -> () })
	local ok, erreur = xpcall(service.demarrer :: () -> any, debug.traceback)
	if not ok then
		warn(`[Serveur] {nom}.demarrer() a échoué : {erreur}`)
	end
end

demarrer("Obstacles", Obstacles)
demarrer("Evenements", Evenements)
demarrer("Classement", Classement)
demarrer("Parcours", Parcours) -- s'abonne au chargement des données : avant Donnees.demarrer()
demarrer("Ascension", Ascension) -- s'abonne aussi au chargement des données : avant Donnees.demarrer()
demarrer("Donnees", Donnees)
demarrer("Boutique", Boutique)
demarrer("Capacites", Capacites) -- déblocages et surveillance des déplacements
