--!strict
-- Point d'entrée du serveur : démarre les services de la liste, dans cet ordre. Aucun abonnement ne dépend de
-- l'ordre : `Donnees.surChargement` rejoue les joueurs déjà chargés à un abonné qui arrive après.
-- Un service qui plante au chargement ou au démarrage est signalé (nom et erreur dans la console) sans empêcher les
-- suivants de démarrer : une seule pièce ou un seul module cassé ne doit pas éteindre tout le jeu.
type Service = { demarrer: () -> () }

-- Les ModuleScript, pas encore chargés : un module qui plante dès son `require` est rattrapé comme un `demarrer` raté.
local SERVICES: { { nom: string, module: ModuleScript } } = {
	{ nom = "Obstacles", module = script.Obstacles },
	{ nom = "Evenements", module = script.Evenements },
	{ nom = "Classement", module = script.Classement },
	{ nom = "Parcours", module = script.Parcours },
	{ nom = "Ascension", module = script.Ascension },
	{ nom = "Donnees", module = script.Donnees },
	{ nom = "Boutique", module = script.Boutique },
	{ nom = "Capacites", module = script.Capacites }, -- déblocages et surveillance des déplacements
	{ nom = "Vol", module = script.Vol }, -- mode vol des testeurs : après la surveillance et le parcours qu'il pilote
}

for _, service in SERVICES do
	local ok, erreur = xpcall(function()
		-- `require` d'un module choisi à l'exécution : le vérificateur de types ne peut pas le suivre, d'où le cast.
		local module = (require :: any)(service.module) :: Service
		module.demarrer()
	end, debug.traceback)
	if not ok then
		warn(`[Serveur] {service.nom} : chargement ou demarrer() a échoué : {erreur}`)
	end
end
