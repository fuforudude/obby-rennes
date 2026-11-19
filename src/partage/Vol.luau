--!strict
-- Le mode vol des testeurs, en fonctions pures (sans Roblox) : ce que teste tests/partage/Vol.spec.luau.
-- Le serveur (serveur/Vol.luau) s'en sert pour décider seul de qui vole ; le client (client/Vol.luau) pour calculer
-- la vitesse. La liste des testeurs est `Reglages.TESTEURS` : le service et les tests la passent à la MÊME fonction
-- (`decider`), jamais une copie construite à part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signalement = require(ReplicatedStorage.Partage.Signalement)

export type Raison = "pas_testeur" | "trop_souvent" | "joueur_mort" | "donnees_absentes"

-- Ce que `decider` doit savoir du joueur, rassemblé par le service seulement si l'identifiant et la cadence passent.
export type Entree = {
	vivant: boolean, -- le personnage existe et son Humanoid a de la vie
	pret: boolean, -- les données du joueur sont chargées (sa course est suivie)
}

local Vol = {}

--- La liste est-elle bien formée ? `{ [identifiant entier] = true }` (rien d'autre). Sert de garde-fou sur Reglages.TESTEURS.
function Vol.listeValide(liste: any): boolean
	if typeof(liste) ~= "table" then
		return false
	end
	for cle, valeur in liste :: { [any]: any } do
		if typeof(cle) ~= "number" or cle ~= math.floor(cle) or cle == 0 or valeur ~= true then
			return false
		end
	end
	return true
end

--- Cet identifiant peut-il voler ? Faux pour tout ce qui n'est pas un entier non nul listé à `true` (nil, texte, NaN,
--- table, identifiant absent de la liste, liste absente ou abîmée).
function Vol.estTesteur(liste: { [number]: boolean }?, identifiant: any): boolean
	if typeof(liste) ~= "table" or typeof(identifiant) ~= "number" then
		return false
	end
	if identifiant ~= identifiant or identifiant ~= math.floor(identifiant) or identifiant == 0 then
		return false
	end
	return liste[identifiant] == true
end

--- La bascule : le vol actif s'arrête, le vol arrêté démarre.
function Vol.basculer(enVol: boolean): boolean
	return not enVol
end

--- Le serveur accepte-t-il cette demande de bascule ? Rend le NOUVEL état du vol (true : il vole, false : il ne vole
--- plus), ou nil et la raison du refus. Ordre, du moins cher au plus cher :
---   1. l'identifiant est dans `liste` (sinon rien ne se passe, et rien n'est mémorisé : un client hors liste qui
---      envoie la demande en boucle n'occupe pas de mémoire) ;
---   2. la cadence : au moins `delai` secondes depuis la dernière bascule ACCEPTÉE (`derniers`, clé `cle`) ;
---   3. pour entrer en vol seulement : personnage vivant et données chargées. Sortir du vol est toujours permis.
--- L'heure n'est notée qu'une fois la demande acceptée : un refus (mort, trop tôt) ne repousse pas la suivante.
function Vol.decider(
	liste: { [number]: boolean }?,
	derniers: { [any]: number },
	cle: any,
	identifiant: any,
	instant: number,
	delai: number,
	enVol: boolean,
	entree: () -> Entree
): (boolean?, Raison?)
	if not Vol.estTesteur(liste, identifiant) then
		return nil, "pas_testeur"
	end
	if Signalement.tropSouvent(instant, derniers[cle], delai) then
		return nil, "trop_souvent"
	end
	local nouvel = Vol.basculer(enVol)
	if nouvel then
		local e = entree()
		if not e.vivant then
			return nil, "joueur_mort"
		end
		if not e.pret then
			return nil, "donnees_absentes"
		end
	end
	derniers[cle] = instant
	return nouvel, nil
end

--- La vitesse (studs/s) voulue pour une image de vol.
---   mouvement : Humanoid.MoveDirection (monde, sur le plan, longueur <= 1, déjà orienté d'après la caméra) ;
---   regard    : la direction de la caméra (3D) : avancer, c'est aller là où l'on regarde, en montant si l'on regarde en haut ;
---   vertical  : -1 (descendre), 0 ou 1 (monter), touches Ctrl et Espace ;
---   vitesse   : Reglages.VOL_VITESSE.
--- La vitesse totale ne dépasse jamais `vitesse` (pas de diagonale plus rapide).
function Vol.vitesse(mouvement: Vector3, regard: Vector3, vertical: number, vitesse: number): Vector3
	local direction = Vector3.new(0, 0, 0)
	local plat = Vector3.new(regard.X, 0, regard.Z)
	if mouvement.Magnitude > 1e-3 then
		if plat.Magnitude > 1e-3 and regard.Magnitude > 1e-3 then
			local avant = plat.Unit
			local droite = Vector3.new(-avant.Z, 0, avant.X)
			direction = regard.Unit * mouvement:Dot(avant) + droite * mouvement:Dot(droite)
		else
			direction = mouvement -- regard à la verticale : rien à décomposer
		end
	end
	direction += Vector3.new(0, math.clamp(vertical, -1, 1), 0)
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	return direction * vitesse
end

return table.freeze(Vol)
