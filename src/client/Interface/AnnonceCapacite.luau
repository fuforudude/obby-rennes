--!strict
-- L'annonce d'un déblocage : un bandeau au centre de l'écran pendant 3 secondes, à la réception du remote
-- `CapaciteDebloquee(capacite)`. Trois lignes : le nom de la capacité, la touche (ou « le bouton » sur mobile) et
-- une phrase dans le ton du jeu. Il ne bloque rien (aucun bouton, aucun focus) et ne clignote pas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Affichage = require(ReplicatedStorage.Partage.Affichage)

local Composants = require(script.Parent.Composants)
local Textes = require(script.Parent.Textes)

local COULEURS = Composants.COULEURS
local creer = Composants.creer
local jouer = Composants.jouer

local DUREE_ANNONCE = 3

local AnnonceCapacite = {}

local monte = false

--- Crée le bandeau dans l'interface `gui` (une seule fois) et écoute le serveur.
function AnnonceCapacite.monter(gui: ScreenGui)
	if monte then
		return
	end
	monte = true

	-- 46 % de la largeur (280 à 460 px), 20 % de la hauteur (96 à 130 px), centré sur l'écran.
	local bandeau = creer("Frame", {
		Name = "AnnonceCapacite",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.2),
		BackgroundColor3 = COULEURS.fond,
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Composants.arrondir(bandeau, 14)
	creer("UISizeConstraint", { MinSize = Vector2.new(280, 96), MaxSize = Vector2.new(460, 130) }, bandeau)
	local contour: UIStroke = creer("UIStroke", { Color = COULEURS.or_, Thickness = 2, Transparency = 1 }, bandeau)
	creer("UIPadding", {
		PaddingLeft = UDim.new(0.04, 0),
		PaddingRight = UDim.new(0.04, 0),
		PaddingTop = UDim.new(0.06, 0),
		PaddingBottom = UDim.new(0.06, 0),
	}, bandeau)
	creer("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.03, 0),
	}, bandeau)

	local titre = Composants.libelle(bandeau, {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0.4),
		TextColor3 = COULEURS.or_,
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		TailleMax = 30,
	})
	local commande = Composants.libelle(bandeau, {
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0.25),
		TextTransparency = 1,
		TailleMax = 20,
	})
	local phrase = Composants.libelle(bandeau, {
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0.25),
		Font = Enum.Font.Gotham,
		TextColor3 = COULEURS.discret,
		TextTransparency = 1,
		TailleMax = 16,
	})

	local jeton = 0
	local function apparition(visible: boolean)
		local fond = if visible then 0.12 else 1
		local texte = if visible then 0 else 1
		jouer(bandeau, Composants.DUREE_FONDU, { BackgroundTransparency = fond })
		jouer(contour, Composants.DUREE_FONDU, { Transparency = texte })
		jouer(titre, Composants.DUREE_FONDU, { TextTransparency = texte })
		jouer(commande, Composants.DUREE_FONDU, { TextTransparency = texte })
		jouer(phrase, Composants.DUREE_FONDU, { TextTransparency = if visible then 0.1 else 1 })
	end

	local remote = Composants.remote("CapaciteDebloquee")
	if not remote then
		return
	end
	remote.OnClientEvent:Connect(function(capacite: any)
		local annonce = Affichage.annonce(capacite, UserInputService.TouchEnabled)
		if not annonce then
			return -- une valeur inconnue du réseau n'affiche rien
		end
		local cle = annonce.capacite :: string
		titre.Text = (Textes.annonceTitre :: { [string]: string })[cle]
		commande.Text = Textes.annonceCommande(cle, annonce.touche)
		phrase.Text = (Textes.annonceTon :: { [string]: string })[cle]
		bandeau.Visible = true
		apparition(true)
		jeton += 1
		local mien = jeton
		task.delay(DUREE_ANNONCE - Composants.DUREE_FONDU, function()
			if mien == jeton then
				apparition(false)
				task.delay(Composants.DUREE_FONDU, function()
					if mien == jeton then
						bandeau.Visible = false
					end
				end)
			end
		end)
	end)
end

return AnnonceCapacite
