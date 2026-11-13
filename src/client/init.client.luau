--!strict
-- Point d'entrée du client : démarre les événements de la carte, puis l'interface (Interface/).
local Evenements = require(script.Evenements)
local Hud = require(script.Interface.Hud)

Evenements.demarrer()
Hud.demarrer()
