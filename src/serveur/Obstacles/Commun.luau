--!strict
-- Ce que partagent les familles d'obstacles (src/serveur/Obstacles/) : la forme d'une famille, l'instant passé à
-- ceux qui suivent l'horloge, et la recherche du joueur derrière une pièce touchée. Ce n'est pas une famille :
-- init.luau le saute en parcourant le dossier.

-- Ce que voit, à chaque image, un obstacle qui suit l'horloge.
export type Instant = {
	serveur: number, -- workspace:GetServerTimeNow() : le même pour tous les joueurs (balanciers, lasers)
	horloge: number, -- os.clock() du serveur (cycle des pièges de mur)
	-- Positions des joueurs vivants, relevées toutes les Reglages.PIEGE_PERIODE_SCAN secondes : nil aux autres images.
	positions: { Vector3 }?,
}

-- Mise à jour d'un obstacle à chaque image (Heartbeat), tant qu'il existe.
export type Maj = (Instant) -> ()

-- Une famille d'obstacles : un module de src/serveur/Obstacles/ qui rend cette table.
export type Famille = {
	tag: string, -- le tag posé par la carte (CollectionService)
	classe: "BasePart" | "Model", -- la classe attendue de l'objet tagué ; un autre est signalé et ignoré
	-- Prépare un objet tagué (déjà vérifié de la bonne classe). Rend sa mise à jour s'il suit l'horloge, sinon nil.
	-- Une erreur ou un attribut invalide n'arrête que cet objet.
	preparer: (objet: Instance) -> Maj?,
}

local Commun = {}

function Commun.nombreFini(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

--- L'humanoïde vivant derrière une pièce touchée, ou nil.
function Commun.humanoideVivant(touche: BasePart): Humanoid?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local humanoide = modele and modele:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return humanoide
	end
	return nil
end

--- La racine d'un personnage vivant derrière une pièce touchée, ou nil : c'est elle qu'on pousse.
function Commun.racineVivante(touche: BasePart): BasePart?
	local modele = touche:FindFirstAncestorOfClass("Model")
	local humanoide = modele and modele:FindFirstChildOfClass("Humanoid")
	if not modele or not humanoide or humanoide.Health <= 0 then
		return nil
	end
	local racine = modele:FindFirstChild("HumanoidRootPart")
	return if racine and racine:IsA("BasePart") then racine else nil
end

--- La pièce tue au toucher (tag Mortel, et le rayon des lasers).
function Commun.tuerAuContact(part: BasePart)
	part.Touched:Connect(function(touche)
		local humanoide = Commun.humanoideVivant(touche)
		if humanoide then
			humanoide.Health = 0
		end
	end)
end

return Commun
