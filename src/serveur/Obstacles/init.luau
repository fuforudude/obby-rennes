--!strict
-- Les obstacles de la carte, retrouvés par leurs tags (posés par outils/monde/Parcours.luau et
-- outils/monde/Ascension.luau). Registre : chaque module de ce dossier (sauf Commun) est une famille, décrite par
-- `{ tag, classe, preparer }` (type Commun.Famille) :
--   Mortel      tue au toucher ;
--   Fragile     s'efface puis revient (tuto) ;
--   Mobile      va-et-vient ;
--   Tournant    barre qui tourne ;
--   Balancier   oscille autour d'un pivot, pousse sans tuer ; attribut facultatif Poussee (multiplicateur) ;
--   PiegeMur    (Model) pointe qui sort du mur quand un joueur approche et le projette, sans le tuer ;
--   Laser       balayage régulier d'une extrémité à l'autre, mortel au contact ;
--   Effondrable plateforme qui tombe après le premier contact, puis revient à sa place.
-- Ajouter un type de piège : un module ici, et sa règle pure testée dans src/partage/Pieges.luau. Aucune liste à
-- tenir à jour : ce service parcourt le dossier.
-- Les décisions (lecture des attributs, cycle du piège, balayage du laser) sont des fonctions pures testées :
-- src/partage/Pieges.luau. Les familles ne font que lire l'horloge, bouger les pièces et pousser les joueurs. Un
-- attribut invalide est signalé par `warn` et l'obstacle est ignoré.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reglages = require(ReplicatedStorage.Partage.Reglages)
local Commun = require(script.Commun)

-- Un seul ensemble pour tout ce qui suit l'horloge (balanciers, lasers, pointes…), quelle que soit la famille : un
-- seul Heartbeat, connecté au premier objet suivi et déconnecté quand il n'en reste aucun.
local suivis: { [Instance]: Commun.Maj } = {}
local liaisonHorloge: RBXScriptConnection? = nil
local signales: { [Instance]: true } = {} -- objets dont la mise à jour a déjà planté : signalés une seule fois
local prochainScan = 0

--- Les positions des joueurs vivants : relevées une seule fois par scan, partagées par tous les obstacles.
local function positionsVivantes(): { Vector3 }
	local positions = {}
	for _, joueur in Players:GetPlayers() do
		local personnage = joueur.Character
		local humanoide = personnage and personnage:FindFirstChildOfClass("Humanoid")
		local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
		if humanoide and humanoide.Health > 0 and racine and racine:IsA("BasePart") then
			table.insert(positions, racine.Position)
		end
	end
	return positions
end

local function majHorloge()
	local instant: Commun.Instant = { serveur = workspace:GetServerTimeNow(), horloge = os.clock(), positions = nil }
	-- Les objets bougent à chaque image ; la recherche des joueurs à portée, elle, est plus rare.
	if instant.horloge >= prochainScan then
		prochainScan = instant.horloge + Reglages.PIEGE_PERIODE_SCAN
		instant.positions = positionsVivantes()
	end
	-- Une famille qui plante n'arrête pas les autres sur cette image ; l'erreur est signalée une fois par objet.
	for objet, maj in suivis do
		-- Le cast : le vérificateur de types refuse `pcall` sur une fonction qui ne rend rien.
		local ok, erreur = pcall(maj :: (Commun.Instant) -> any, instant)
		if not ok and not signales[objet] then
			signales[objet] = true
			warn(`[Obstacles] {objet:GetFullName()} : erreur à la mise à jour (signalée une seule fois) : {erreur}`)
		end
	end
end

local function suivre(objet: Instance, maj: Commun.Maj)
	suivis[objet] = maj
	if not liaisonHorloge then
		liaisonHorloge = RunService.Heartbeat:Connect(majHorloge)
	end
	objet.Destroying:Connect(function()
		suivis[objet] = nil
		signales[objet] = nil
		local liaison = liaisonHorloge
		if liaison and next(suivis) == nil then
			liaison:Disconnect()
			liaisonHorloge = nil
		end
	end)
end

--- La famille décrite par ce module, ou nil (signalé) s'il ne rend pas une famille valide.
local function lireFamille(module: ModuleScript): Commun.Famille?
	-- `require` d'un module trouvé à l'exécution : le vérificateur de types ne peut pas le suivre, d'où le cast.
	local ok, famille = pcall(require :: any, module)
	if
		not ok
		or typeof(famille) ~= "table"
		or typeof(famille.tag) ~= "string"
		or (famille.classe ~= "BasePart" and famille.classe ~= "Model")
		or typeof(famille.preparer) ~= "function"
	then
		warn(
			`[Obstacles] {module:GetFullName()} : pas une famille d'obstacles ({if ok
				then "tag, classe, preparer"
				else famille})`
		)
		return nil
	end
	return famille
end

local Obstacles = {}

function Obstacles.demarrer()
	local tags: { [string]: boolean } = {}
	for _, module in script:GetChildren() do
		if not module:IsA("ModuleScript") or module == script.Commun then
			continue
		end
		local famille = lireFamille(module)
		if not famille then
			continue
		end
		if tags[famille.tag] then
			warn(`[Obstacles] tag {famille.tag} déjà pris par une autre famille : {module:GetFullName()} ignoré`)
			continue
		end
		tags[famille.tag] = true
		-- Un objet mal configuré ne doit jamais empêcher les suivants (ni les autres services : voir
		-- init.server.luau) de démarrer : l'erreur est signalée avec le nom de l'objet, puis on passe au suivant.
		for _, objet in CollectionService:GetTagged(famille.tag) do
			if not objet:IsA(famille.classe) then
				warn(`[Obstacles] {objet:GetFullName()} : le tag {famille.tag} se pose sur un {famille.classe}`)
				continue
			end
			local ok, resultat = pcall(famille.preparer, objet)
			if not ok then
				warn(`[Obstacles] {objet:GetFullName()} ({famille.tag}) : erreur à la préparation : {resultat}`)
			elseif resultat then
				suivre(objet, resultat)
			end
		end
	end
end

return Obstacles
