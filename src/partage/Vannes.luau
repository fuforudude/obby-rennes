--!strict
-- Les vannes affichées quand on tombe (le barème de l'aura, lui, est dans Reglages et compté par le serveur).
-- Ton : humour brain rot, qui se moque de la chute, du décor ou d'un personnage, jamais des étudiants ni de leurs
-- notes ; pas de leçon. Courtes : elles s'affichent environ 1,5 seconde.
local CHUTES = {
	"Skill issue.",
	"Le jus de poubelle t'a ratio.",
	"Même la galette-saucisse a plus d'équilibre.",
	"Même le métro en grève va plus loin que toi.",
	"Aura en baisse. Ça pique.",
	"Retour au checkpoint. Le respawn t'attendait.",
	"La Vilaine te remercie pour ta visite.",
	"Ohio moment.",
	"Le partiel attend. Le respawn aussi.",
	"Le sol a gagné ce round.",
	"Le crachin breton t'a fait glisser.",
	"Galettino Saucissino a vu ça. Il ne dira rien. Peut-être.",
	"Même le crachin tombe avec plus de style.",
	"Pas de rattrapage pour ce saut. Ah si, en fait.",
	"Livraison au sol : colis reçu.",
	"Gravité : 1. Toi : 0.",
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
