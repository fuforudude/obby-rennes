--!strict
-- Point d'entrée du client : démarre les événements de la carte, les capacités de déplacement, les sons, puis l'interface
-- (Interface/).
local Capacites = require(script.Capacites)
local Evenements = require(script.Evenements)
local Hud = require(script.Interface.Hud)
local Sons = require(script.Sons)

Evenements.demarrer()
Capacites.demarrer()
Sons.demarrer()
Hud.demarrer()
