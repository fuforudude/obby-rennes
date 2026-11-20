--!strict
-- Point d'entrée du serveur : démarre les services de la liste, dans cet ordre. Aucun abonnement ne dépend de
-- l'ordre : `Donnees.surChargement` rejoue les joueurs déjà chargés à un abonné qui arrive après.
-- Un service qui plante au démarrage est signalé (nom et erreur dans la console) sans empêcher les suivants de
-- démarrer : une seule pièce ou un seul module cassé ne doit pas éteindre tout le jeu.
type Service = { demarrer: () -> () }

local SERVICES: { { nom: string, module: Service } } = {
	{ nom = "Obstacles", module = require(script.Obstacles) },
	{ nom = "Evenements", module = require(script.Evenements) },
	{ nom = "Classement", module = require(script.Classement) },
	{ nom = "Parcours", module = require(script.Parcours) },
	{ nom = "Ascension", module = require(script.Ascension) },
	{ nom = "Donnees", module = require(script.Donnees) },
	{ nom = "Boutique", module = require(script.Boutique) },
	{ nom = "Capacites", module = require(script.Capacites) }, -- déblocages et surveillance des déplacements
	{ nom = "Vol", module = require(script.Vol) }, -- mode vol des testeurs : après la surveillance et le parcours qu'il pilote
}

for _, service in SERVICES do
	local ok, erreur = xpcall(service.module.demarrer :: () -> any, debug.traceback)
	if not ok then
		warn(`[Serveur] {service.nom}.demarrer() a échoué : {erreur}`)
	end
end
