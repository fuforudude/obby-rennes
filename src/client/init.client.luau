--!strict
-- Point d'entrée du client : démarre les événements de la carte, les capacités de déplacement, l'interface
-- (Interface/), puis les sons. Un message en file n'est remis qu'à la première connexion d'un remote : EtatCourse et
-- CapaciteDebloquee arrivent d'abord à Capacites (démarré avant l'interface) ; EtatAscension et Arrivee, écoutés par
-- l'interface et par les sons seulement, arrivent d'abord à l'interface, d'où les sons en dernier.
local Capacites = require(script.Capacites)
local Evenements = require(script.Evenements)
local Hud = require(script.Interface.Hud)
local Sons = require(script.Sons)

Evenements.demarrer()
Capacites.demarrer()
Hud.demarrer()
Sons.demarrer()
