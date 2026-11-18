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

Obstacles.demarrer()
Evenements.demarrer()
Classement.demarrer()
Parcours.demarrer() -- s'abonne au chargement des données : avant Donnees.demarrer()
Ascension.demarrer() -- s'abonne aussi au chargement des données : avant Donnees.demarrer()
Donnees.demarrer()
Boutique.demarrer()
Capacites.demarrer() -- déblocages et surveillance des déplacements
