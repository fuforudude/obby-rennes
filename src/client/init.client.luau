--!strict
-- Point d'entrée du client : démarre les événements de la carte, les capacités de déplacement, l'interface
-- (Interface/), puis les sons. Les sons en dernier : un message en file n'est remis qu'à la première connexion d'un
-- remote, et c'est l'interface qui en a besoin.
local Capacites = require(script.Capacites)
local Evenements = require(script.Evenements)
local Hud = require(script.Interface.Hud)
local Sons = require(script.Sons)

Evenements.demarrer()
Capacites.demarrer()
Hud.demarrer()
Sons.demarrer()
