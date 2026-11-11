--!strict
-- Les vannes affichées quand on tombe (le barème de l'aura, lui, est dans Reglages et compté par le serveur).
local CHUTES = {
	"Skill issue.",
	"Le jus de poubelle t'a ratio.",
	"Tombé comme ta moyenne du S1.",
	"Même le métro en grève va plus loin que toi.",
	"-50 aura. Ça pique.",
	"Retour au checkpoint. Comme ton dossier Parcoursup : en attente.",
	"La Vilaine te remercie pour ta visite.",
	"Ohio moment.",
	"Ton partiel t'attend toujours. Il est patient, lui.",
	"C'est pas la chute qui compte, c'est la remontée.",
	"Le crachin breton t'a fait glisser. C'est ça, l'excuse.",
	"Galettino Saucissino a vu ça. Il ne dira rien. Peut-être.",
	"Même le crachin tombe avec plus de style.",
	"Pas de rattrapage pour ce saut. Ah si, en fait.",
}

local Vannes = {}

--- La vanne de la n-ième chute (on fait le tour de la liste, sans répéter deux fois de suite la même).
function Vannes.chute(n: number): string
	return CHUTES[(n - 1) % #CHUTES + 1]
end

function Vannes.nombreDeChutes(): number
	return #CHUTES
end

return table.freeze(Vannes)
