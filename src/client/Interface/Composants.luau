--!strict
-- Les petites briques communes des écrans de l'interface : couleurs, création d'objets, texte borné, bouton plein,
-- animation courte. Rien ne s'exécute au `require`.
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ascension = require(ReplicatedStorage.Partage.Ascension)
local Remotes = require(ReplicatedStorage.Partage.Remotes)

local Composants = {}

Composants.COULEURS = {
	fond = Color3.fromRGB(20, 24, 34),
	texte = Color3.fromRGB(255, 255, 255),
	discret = Color3.fromRGB(170, 180, 200),
	vinci = Color3.fromRGB(30, 90, 170),
	alerte = Color3.fromRGB(220, 70, 60),
	or_ = Color3.fromRGB(240, 190, 50),
	aura = Color3.fromRGB(255, 120, 220),
	gain = Color3.fromRGB(110, 240, 130),
	-- Capacités : une couleur vive par capacité, un gris sombre quand elle est consommée.
	course = Color3.fromRGB(40, 130, 230),
	doubleSaut = Color3.fromRGB(40, 170, 90),
	dash = Color3.fromRGB(235, 120, 30),
	consomme = Color3.fromRGB(60, 66, 82),
	grise = Color3.fromRGB(95, 102, 120),
}

Composants.DUREE_FONDU = 0.15 -- toutes les animations restent sous 0,3 s

function Composants.creer(classe: string, proprietes: { [string]: any }, parent: Instance?): any
	local objet = Instance.new(classe)
	for nom, valeur in proprietes do
		(objet :: any)[nom] = valeur
	end
	if parent then
		objet.Parent = parent
	end
	return objet
end

function Composants.arrondir(objet: Instance, rayon: number?)
	Composants.creer("UICorner", { CornerRadius = UDim.new(0, rayon or 10) }, objet)
end

function Composants.libelle(parent: Instance, proprietes: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = Composants.COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}
	for nom, valeur in proprietes do
		if nom ~= "TailleMax" then -- notre option à nous, pas une propriété Roblox
			base[nom] = valeur
		end
	end
	local l = Composants.creer("TextLabel", base, parent)
	Composants.creer("UITextSizeConstraint", { MaxTextSize = proprietes.TailleMax or 22, MinTextSize = 10 }, l)
	return l
end

function Composants.jouer(objet: Instance, duree: number, proprietes: { [string]: any }): Tween
	local t =
		TweenService:Create(objet, TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), proprietes)
	t:Play()
	return t
end

--- Un bouton plein, sélectionnable à la manette. La taille est donnée par l'appelant (échelle + contraintes).
function Composants.bouton(parent: Instance, texte: string, couleur: Color3, rayon: number): TextButton
	local creer = Composants.creer
	local b = creer("TextButton", {
		BackgroundColor3 = couleur,
		TextColor3 = Composants.COULEURS.texte,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		Text = texte,
		AutoButtonColor = true,
		Selectable = true,
	}, parent)
	Composants.arrondir(b, rayon)
	creer("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, b)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
	}, b)
	return b
end

--- Un RemoteEvent du jeu, ou `nil` s'il n'est pas déclaré dans Remotes.luau : l'interface reste alors
--- muette sur cette fonction au lieu de s'arrêter.
function Composants.remote(nom: string): RemoteEvent?
	local ok, resultat = pcall(Remotes.obtenir, nom)
	if ok then
		return resultat
	end
	warn(`Interface : remote {nom} indisponible ({resultat})`)
	return nil
end

--- « 182 m » : la hauteur en studs, mise en forme par `Ascension.formaterHauteur` (partage/Ascension.luau).
function Composants.formaterHauteur(studs: number): string
	return Ascension.formaterHauteur(studs)
end

return Composants
