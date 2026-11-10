--!strict
-- Les étapes du parcours : nom de la zone et anecdote affichée quand on atteint le checkpoint.
-- Numéros 0 (départ) à 15 (arrivée), dans le même ordre que outils/monde/Parcours.luau.
export type Etape = {
	numero: number,
	zone: string,
	anecdote: string,
}

local LISTE: { Etape } = {
	{
		numero = 0,
		zone = "La coloc à Villejean",
		anecdote = "Rennes compte plus de 70 000 étudiants : c'est l'une des villes les plus étudiantes de France. Ton partiel est à 8 h. Bonne chance.",
	},
	{
		numero = 1,
		zone = "Fac bloquée",
		anecdote = "Rennes 2 est l'université des lettres, langues, arts et sciences humaines ; son campus principal est à Villejean.",
	},
	{
		numero = 2,
		zone = "Fac bloquée",
		anecdote = "Un blocus se vote en assemblée générale. Rennes 2 est bloquée… mais ton partiel à Sup de Vinci, lui, est maintenu.",
	},
	{
		numero = 3,
		zone = "Métro en grève",
		anecdote = "La ligne a du métro a ouvert en 2002 : Rennes a longtemps été présentée comme la plus petite ville du monde équipée d'un métro.",
	},
	{
		numero = 4,
		zone = "Métro en grève",
		anecdote = "La ligne b, ouverte en 2022, roule sans conducteur, comme la ligne a. Sans conducteur, mais pas sans grève.",
	},
	{
		numero = 5,
		zone = "Place de la République",
		anecdote = "La place de la République est le cœur des transports rennais, et un point de départ classique des cortèges.",
	},
	{
		numero = 6,
		zone = "Le cortège",
		anecdote = "Le palais du Commerce, sur la place de la République, abrite la grande poste de Rennes.",
	},
	{
		numero = 7,
		zone = "Barricades de poubelles",
		anecdote = "En 1720, un grand incendie a ravagé le centre de Rennes pendant près d'une semaine ; la ville a été reconstruite en pierre.",
	},
	{
		numero = 8,
		zone = "Barricades de poubelles",
		anecdote = "Le marché des Lices, le samedi matin, est l'un des plus grands marchés de France. Les poubelles du samedi midi aussi.",
	},
	{
		numero = 9,
		zone = "Rue de la Soif",
		anecdote = "La rue Saint-Michel est surnommée « rue de la Soif » : ses bars s'y suivent porte après porte.",
	},
	{
		numero = 10,
		zone = "Rue de la Soif",
		anecdote = "Les maisons à pans de bois du vieux Rennes ont échappé à l'incendie de 1720 ; certaines datent des XVe et XVIe siècles.",
	},
	{
		numero = 11,
		zone = "La Vilaine",
		anecdote = "La Vilaine traverse Rennes d'est en ouest, et l'Ille la rejoint en plein centre-ville.",
	},
	{
		numero = 12,
		zone = "Les quais",
		anecdote = "Une partie de la Vilaine a été recouverte au XXe siècle : la place de la République est construite au-dessus de la rivière.",
	},
	{
		numero = 13,
		zone = "Parlement de Bretagne",
		anecdote = "Le Parlement de Bretagne a brûlé en 1994 lors d'une manifestation de marins-pêcheurs ; restauré, il a rouvert en 1999.",
	},
	{
		numero = 14,
		zone = "Le Thabor",
		anecdote = "Le parc du Thabor, ancien jardin de l'abbaye Saint-Melaine, est l'un des plus beaux jardins publics de France.",
	},
	{
		numero = 15,
		zone = "Sup de Vinci",
		anecdote = "Sup de Vinci, l'école du numérique. Tu es arrivé à l'heure : le partiel peut commencer.",
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
