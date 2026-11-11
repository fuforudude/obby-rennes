--!strict
-- Les étapes du parcours : nom de la zone, anecdote (vraie) et vanne affichées quand on atteint le checkpoint.
-- Numéros 0 (départ) à 15 (arrivée), dans le même ordre que outils/monde/Parcours.luau.
export type Etape = {
	numero: number,
	zone: string,
	anecdote: string,
	blague: string, -- la vanne du jour (brain rot, sarcasme étudiant) sous l'anecdote
}

local LISTE: { Etape } = {
	{
		numero = 0,
		zone = "La coloc à Villejean",
		anecdote = "Rennes compte plus de 70 000 étudiants : c'est l'une des villes les plus étudiantes de France. Ton partiel est à 8 h. Bonne chance.",
		blague = "Réveil à 7 h 52. Ton aura est en danger critique.",
	},
	{
		numero = 1,
		zone = "Fac bloquée",
		anecdote = "Rennes 2 est l'université des lettres, langues, arts et sciences humaines ; son campus principal est à Villejean.",
		blague = "La fac est bloquée. Ton partiel, lui, ne l'est pas. Skill issue de l'administration.",
	},
	{
		numero = 2,
		zone = "L'amphi bloqué",
		anecdote = "Un blocus se vote en assemblée générale. Rennes 2 est bloquée… mais ton partiel à Sup de Vinci, lui, est maintenu.",
		blague = "AG à 10 h, vote à main levée, trois heures de débat sur l'ordre du jour. Démocratie : +1000 aura.",
	},
	{
		numero = 3,
		zone = "Le viaduc de la ligne b",
		anecdote = "La ligne a du métro a ouvert en 2002 : Rennes a longtemps été présentée comme la plus petite ville du monde équipée d'un métro.",
		blague = "Trafic interrompu. Prochaine rame : quand les poules auront un abonnement STAR.",
	},
	{
		numero = 4,
		zone = "La station",
		anecdote = "La ligne b, ouverte en 2022, roule sans conducteur comme la ligne a ; une partie de son trajet passe sur un viaduc.",
		blague = "Le métro roule sans conducteur, et il fait grève quand même. Sigma.",
	},
	{
		numero = 5,
		zone = "Place de la République",
		anecdote = "La place de la République est le cœur des transports rennais, et un point de départ classique des cortèges.",
		blague = "Le cortège avance à 2 km/h. Toi, tu as un partiel à 8 h. Choisis ta voie.",
	},
	{
		numero = 6,
		zone = "Le cortège",
		anecdote = "Le palais du Commerce, sur la place de la République, abrite la grande poste de Rennes.",
		blague = "La galette-saucisse est passée à 5 €. L'inflation n'épargne personne, pas même la saucisse.",
	},
	{
		numero = 7,
		zone = "Barricades de poubelles",
		anecdote = "En 1720, un grand incendie a ravagé le centre de Rennes pendant près d'une semaine ; la ville a été reconstruite en pierre.",
		blague = "Les poubelles s'entassent : la barricade est triée par couleur. C'est ça, l'écologie.",
	},
	{
		numero = 8,
		zone = "La tour",
		anecdote = "Rennes a ses tours des années 1970 : les deux tours rondes des Horizons font partie des plus hauts immeubles d'habitation de la ville.",
		blague = "25e étage, ascenseur en panne depuis 2019. Cardio : +1000 aura.",
	},
	{
		numero = 9,
		zone = "Rue de la Soif",
		anecdote = "La rue Saint-Michel est surnommée « rue de la Soif » : ses bars s'y suivent porte après porte.",
		blague = "Rue de la Soif, 7 h du matin : les derniers du jeudi soir t'encouragent. Enfin, ils essaient.",
	},
	{
		numero = 10,
		zone = "Rue de la Soif",
		anecdote = "Les maisons à pans de bois du vieux Rennes ont échappé à l'incendie de 1720 ; certaines datent des XVe et XVIe siècles.",
		blague = "Ton rizz ne marche pas sur les colombages. Saute.",
	},
	{
		numero = 11,
		zone = "La Vilaine",
		anecdote = "La Vilaine traverse Rennes d'est en ouest, et l'Ille la rejoint en plein centre-ville.",
		blague = "Il ne pleut pas à Rennes. Il bruine. Nuance importante.",
	},
	{
		numero = 12,
		zone = "Les quais",
		anecdote = "Une partie de la Vilaine a été recouverte au XXe siècle : la place de la République est construite au-dessus de la rivière.",
		blague = "Tomber dans la Vilaine : la seule piscine gratuite de Rennes.",
	},
	{
		numero = 13,
		zone = "Sur le toit du Parlement",
		anecdote = "Le Parlement de Bretagne a brûlé en 1994 lors d'une manifestation de marins-pêcheurs ; restauré, il a rouvert en 1999.",
		blague = "Le Parlement s'est relevé de 1994. Toi, relève-toi de ces colonnes.",
	},
	{
		numero = 14,
		zone = "Le Thabor",
		anecdote = "Le parc du Thabor, ancien jardin de l'abbaye Saint-Melaine, est l'un des plus beaux jardins publics de France.",
		blague = "Pelouse interdite. Même pour réviser. Surtout pour réviser.",
	},
	{
		numero = 15,
		zone = "Sup de Vinci",
		anecdote = "Sup de Vinci, campus de Rennes : la ligne d'arrivée. Tu es à l'heure, le partiel peut commencer.",
		blague = "Arrivé à 7 h 59. Le partiel est reporté : c'était dans le mail de 23 h 47. +5000 aura quand même.",
	},
}

local Etapes = {}

--- L'étape de ce numéro, ou nil s'il n'existe pas.
function Etapes.obtenir(numero: number): Etape?
	return LISTE[numero + 1]
end

--- Nombre de checkpoints, départ compris.
function Etapes.nombre(): number
	return #LISTE
end

return Etapes
