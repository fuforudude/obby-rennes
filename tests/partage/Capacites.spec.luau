-- Les capacités de déplacement : ce qui est débloqué, les vitesses et montées maximales possibles (qui servent à la
-- fois au client et à la surveillance serveur), la portée du dash, et le verdict de la surveillance (un test par
-- raison de refus : trop vite, trop haut, capacité non débloquée, téléportation).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Capacites = require(ReplicatedStorage.Partage.Capacites)
	local Reglages = require(ReplicatedStorage.Partage.Reglages)

	local function proche(valeur: number, attendu: number, ecart: number): boolean
		return math.abs(valeur - attendu) <= ecart
	end

	local AUCUNE = {}
	local COURSE = { course = true }
	local DOUBLE = { doubleSaut = true }
	local DASH = { dash = true }
	local TOUTES = { course = true, doubleSaut = true, dash = true }

	describe("estDebloquee", function()
		it("rend vrai pour une capacité notée dans les données", function()
			expect(Capacites.estDebloquee({ capacites = { course = true } }, "course")).to.equal(true)
		end)

		it("rend faux pour une capacité absente, fausse ou non booléenne", function()
			expect(Capacites.estDebloquee({ capacites = { course = true } }, "dash")).to.equal(false)
			expect(Capacites.estDebloquee({ capacites = { dash = false } }, "dash")).to.equal(false)
			expect(Capacites.estDebloquee({ capacites = { dash = "oui" } }, "dash")).to.equal(false)
		end)

		it("ne plante pas sur des données sans champ capacites, abîmées ou absentes", function()
			expect(Capacites.estDebloquee({}, "course")).to.equal(false)
			expect(Capacites.estDebloquee({ capacites = 12 }, "course")).to.equal(false)
			expect(Capacites.estDebloquee(nil, "course")).to.equal(false)
		end)

		it("rend faux pour un nom de capacité inconnu", function()
			expect(Capacites.estDebloquee({ capacites = { vol = true } }, "vol")).to.equal(false)
		end)
	end)

	describe("estCapacite", function()
		it("reconnaît exactement les trois capacités", function()
			expect(Capacites.estCapacite("course")).to.equal(true)
			expect(Capacites.estCapacite("doubleSaut")).to.equal(true)
			expect(Capacites.estCapacite("dash")).to.equal(true)
			expect(Capacites.estCapacite("vol")).to.equal(false)
			expect(Capacites.estCapacite(3)).to.equal(false)
			expect(Capacites.estCapacite(nil)).to.equal(false)
		end)
	end)

	describe("vitesseMax", function()
		it("vaut la vitesse de marche sans capacité, même en voulant courir", function()
			expect(Capacites.vitesseMax(AUCUNE, false)).to.equal(16)
			expect(Capacites.vitesseMax(AUCUNE, true)).to.equal(16)
			expect(Capacites.vitesseMax(nil, true)).to.equal(16)
		end)

		it("vaut 1,5 fois la marche avec la course, seulement quand on court (course : 24 studs/s)", function()
			expect(Capacites.vitesseMax(COURSE, true)).to.equal(16 * Reglages.COURSE_FACTEUR)
			expect(Capacites.vitesseMax(COURSE, false)).to.equal(16)
		end)

		it("compte le dash : la vitesse maximale est celle du dash", function()
			expect(Capacites.vitesseMax(DASH, false)).to.equal(Reglages.DASH_VITESSE)
			expect(Capacites.vitesseMax(TOUTES, true)).to.equal(Reglages.DASH_VITESSE)
		end)

		it("ne change pas avec le seul double saut", function()
			expect(Capacites.vitesseMax(DOUBLE, true)).to.equal(16)
		end)
	end)

	describe("hauteur et montée", function()
		it("un saut simple monte de 7,2 studs, un double saut de 14,4 studs", function()
			expect(proche(Capacites.hauteurEnvol(AUCUNE), 7.2, 0.001)).to.equal(true)
			expect(proche(Capacites.hauteurEnvol(DOUBLE), 14.4, 0.001)).to.equal(true)
		end)

		it("monteeMax sur une durée nulle vaut la hauteur d'un envol", function()
			expect(proche(Capacites.monteeMax(AUCUNE, 0), 7.2, 0.001)).to.equal(true)
			expect(proche(Capacites.monteeMax(DOUBLE, 0), 14.4, 0.001)).to.equal(true)
		end)

		it("monteeMax croît avec la durée", function()
			expect(Capacites.monteeMax(DOUBLE, 2) > Capacites.monteeMax(DOUBLE, 1)).to.equal(true)
			expect(Capacites.monteeMax(DOUBLE, 1) > Capacites.monteeMax(DOUBLE, 0.5)).to.equal(true)
		end)

		it("le double saut permet de monter plus haut qu'un saut simple", function()
			expect(Capacites.monteeMax(DOUBLE, 1) > Capacites.monteeMax(AUCUNE, 1)).to.equal(true)
		end)

		it("le dash et la course n'ajoutent rien à la montée par les sauts", function()
			expect(Capacites.monteeMax(DASH, 1)).to.equal(Capacites.monteeMax(AUCUNE, 1))
		end)

		it("ne plante pas sur une durée négative ou absurde", function()
			expect(Capacites.monteeMax(AUCUNE, -3)).to.equal(Capacites.monteeMax(AUCUNE, 0))
			expect(Capacites.monteeMax(AUCUNE, 0 / 0)).to.equal(Capacites.monteeMax(AUCUNE, 0))
		end)
	end)

	describe("distanceMax", function()
		it("sans capacité, c'est la marche : 16 studs en une seconde", function()
			expect(proche(Capacites.distanceMax(AUCUNE, 1), 16, 0.001)).to.equal(true)
		end)

		it("avec la course, 24 studs en une seconde", function()
			expect(proche(Capacites.distanceMax(COURSE, 1), 24, 0.001)).to.equal(true)
		end)

		it(
			"avec le dash, ajoute un dash par envol possible (un dash au moins, même sur une durée très courte)",
			function()
				local sansDash = Capacites.distanceMax(AUCUNE, 0.1)
				local avecDash = Capacites.distanceMax(DASH, 0.1)
				expect(proche(avecDash - sansDash, Capacites.extensionDash(16), 0.001)).to.equal(true)
			end
		)

		it(
			"le dash ne peut pas se répéter plus vite qu'un envol (0,54 s) : deux dash en une seconde, pas dix",
			function()
				local sansDash = Capacites.distanceMax(AUCUNE, 1)
				local extra = Capacites.distanceMax(DASH, 1) - sansDash
				expect(proche(extra, 2 * Capacites.extensionDash(16), 0.001)).to.equal(true)
			end
		)
	end)

	describe("extensionDash", function()
		it("allonge un saut de 8 à 12 studs, en marchant comme en courant", function()
			local marche = Capacites.extensionDash(16)
			local course = Capacites.extensionDash(16 * Reglages.COURSE_FACTEUR)
			expect(marche >= 8 and marche <= 12).to.equal(true)
			expect(course >= 8 and course <= 12).to.equal(true)
		end)

		it("ne rend jamais une valeur négative", function()
			expect(Capacites.extensionDash(500)).to.equal(0)
		end)
	end)

	describe("evaluerDeplacement (surveillance)", function()
		it("accepte une marche normale : 8 studs en une demi-seconde", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 8, 0, 0.5)).never.to.be.ok()
		end)

		it("accepte un saut normal depuis le sol", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 4, 7.2, 0.5)).never.to.be.ok()
		end)

		it("accepte un double saut avec dash et course chez un joueur qui a tout", function()
			expect(Capacites.evaluerDeplacement(TOUTES, 25, 14.4, 0.5)).never.to.be.ok()
		end)

		it("refuse une vitesse horizontale trop grande (téléportation à 100 studs en une demi-seconde)", function()
			expect(Capacites.evaluerDeplacement(TOUTES, 100, 0, 0.5)).to.equal("horizontal")
		end)

		it(
			"refuse une vitesse de 60 studs/s sans capacité (marche : 16,4 studs autorisés en 0,5 s, tolérance comprise)",
			function()
				expect(Capacites.evaluerDeplacement(AUCUNE, 30, 0, 0.5)).to.equal("horizontal")
			end
		)

		it("refuse un dash sans la capacité mais l'accepte avec", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 22, 0, 0.5)).to.equal("horizontal")
			expect(Capacites.evaluerDeplacement(DASH, 22, 0, 0.5)).never.to.be.ok()
		end)

		it("refuse une montée plus rapide que sauts et double saut ne le permettent", function()
			expect(Capacites.evaluerDeplacement(DOUBLE, 0, 80, 0.5)).to.equal("vertical")
		end)

		it("refuse un double saut sans la capacité : 38 studs de montée en 0,5 s", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 0, 38, 0.5)).to.equal("vertical")
			expect(Capacites.evaluerDeplacement(DOUBLE, 0, 38, 0.5)).never.to.be.ok()
		end)

		it("ne refuse jamais une chute (montée négative)", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 0, -400, 0.5)).never.to.be.ok()
		end)

		it("refuse un déplacement sur une durée nulle ou absurde sans planter", function()
			expect(Capacites.evaluerDeplacement(AUCUNE, 500, 0, 0)).to.equal("horizontal")
			expect(Capacites.evaluerDeplacement(AUCUNE, 0 / 0, 0, 0.5)).to.equal("horizontal")
			expect(Capacites.evaluerDeplacement(AUCUNE, 1, 0, -1)).never.to.be.ok()
		end)

		it("laisse de la marge : un joueur qui court sur une plateforme mobile n'est pas refusé", function()
			expect(Capacites.evaluerDeplacement(COURSE, 12 + 4, 0, 0.5)).never.to.be.ok()
		end)
	end)

	describe("fenêtre glissante (tampon de relevés)", function()
		local FENETRE = Reglages.SURVEILLANCE_FENETRE
		local PERIODE = Reglages.SURVEILLANCE_PERIODE

		--- Un tampon rempli d'un relevé toutes les PERIODE secondes, de 0 à `duree`, le joueur montant de
		--- `monteeParSeconde` studs/s et avançant de `avanceParSeconde` studs/s.
		local function tamponConstant(duree: number, monteeParSeconde: number, avanceParSeconde: number)
			local tampon = {}
			local instant = 0
			while instant <= duree + 1e-9 do
				Capacites.empiler(tampon, instant, instant * avanceParSeconde, instant * monteeParSeconde, 0, FENETRE)
				instant += PERIODE
			end
			return tampon
		end

		it("oublie les relevés trop vieux mais garde la référence qui couvre toute la fenêtre", function()
			local tampon = tamponConstant(10, 0, 0)
			local mesure = Capacites.deplacementFenetre(tampon)
			expect(mesure).to.be.ok()
			-- La fenêtre comparée couvre au moins FENETRE, et au plus une période de plus.
			expect(mesure.duree >= FENETRE).to.equal(true)
			expect(mesure.duree < FENETRE + PERIODE).to.equal(true)
			expect(#tampon <= math.ceil(FENETRE / PERIODE) + 1).to.equal(true)
		end)

		it("mesure du plus vieux relevé gardé au plus récent", function()
			local tampon = {}
			Capacites.empiler(tampon, 0, 0, 0, 0, FENETRE)
			Capacites.empiler(tampon, 0.5, 3, 10, 4, FENETRE)
			local mesure = Capacites.deplacementFenetre(tampon)
			expect(mesure.horizontal).to.equal(5) -- 3 et 4 sur le plan
			expect(mesure.montee).to.equal(10)
			expect(mesure.duree).to.equal(0.5)
		end)

		it("un seul relevé : pas de mesure, donc aucun verdict (rien n'est refusé au démarrage)", function()
			local tampon = {}
			Capacites.empiler(tampon, 0, 0, 0, 0, FENETRE)
			expect(Capacites.deplacementFenetre(tampon)).never.to.be.ok()
			expect(Capacites.evaluerFenetre(TOUTES, tampon)).never.to.be.ok()
			expect(Capacites.evaluerFenetre(TOUTES, {})).never.to.be.ok()
		end)

		it("accepte une montée tenable tenue sur toute la fenêtre (26 studs/s, sauts enchaînés)", function()
			expect(Capacites.evaluerFenetre(TOUTES, tamponConstant(10, 26, 0))).never.to.be.ok()
		end)

		it("refuse un vol vertical à 50 studs/s, que la fenêtre de 0,5 s acceptait", function()
			expect(Capacites.evaluerFenetre(TOUTES, tamponConstant(10, 50, 0))).to.equal("vertical")
			-- La même vitesse mesurée sur 0,5 s seulement passait : c'est le trou que la fenêtre longue ferme.
			expect(Capacites.evaluerDeplacement(TOUTES, 0, 25, 0.5)).never.to.be.ok()
		end)

		it("refuse un vol horizontal à 60 studs/s, que la fenêtre de 0,5 s acceptait", function()
			expect(Capacites.evaluerFenetre(TOUTES, tamponConstant(10, 0, 60))).to.equal("horizontal")
			expect(Capacites.evaluerDeplacement(TOUTES, 30, 0, 0.5)).never.to.be.ok()
		end)

		it("le plafond vertical de la fenêtre est près de deux fois plus serré que celui de 0,5 s", function()
			local function plafondParSeconde(duree: number): number
				local max = Capacites.monteeMax(TOUTES, duree)
				return (max * Reglages.SURVEILLANCE_MARGE + Reglages.SURVEILLANCE_TOLERANCE) / duree
			end
			expect(plafondParSeconde(FENETRE) < plafondParSeconde(PERIODE) / 1.8).to.equal(true)
			-- Et il reste au-dessus de ce qu'un joueur tient vraiment (26,6 studs/s), marge comprise.
			expect(plafondParSeconde(FENETRE) > 26.6).to.equal(true)
		end)

		it("accepte une course avec dashs enchaînés tenue sur toute la fenêtre", function()
			-- Le mieux possible : course (24 studs/s) plus un dash par envol (0,54 s).
			local parSeconde = Capacites.distanceMax(TOUTES, FENETRE) / FENETRE
			expect(Capacites.evaluerFenetre(TOUTES, tamponConstant(10, 0, parSeconde))).never.to.be.ok()
		end)

		it("ne refuse pas un joueur porté par une plateforme mobile (4 studs/s) qui saute et avance", function()
			expect(Capacites.evaluerFenetre(TOUTES, tamponConstant(10, 26.6 + 4, 24 + 4))).never.to.be.ok()
		end)

		it("ne refuse jamais une chute, même longue", function()
			expect(Capacites.evaluerFenetre(AUCUNE, tamponConstant(10, -300, 0))).never.to.be.ok()
		end)

		it("une fenêtre nulle ou absurde ne garde que le dernier relevé, donc ne refuse rien", function()
			local tampon = {}
			Capacites.empiler(tampon, 0, 0, 0, 0, 0 / 0)
			Capacites.empiler(tampon, 0.5, 0, 0, 0, 0 / 0)
			expect(#tampon).to.equal(1)
			expect(Capacites.evaluerFenetre(AUCUNE, tampon)).never.to.be.ok()
		end)
	end)

	describe("téléportation décidée par le serveur (tampon amorcé à la destination)", function()
		local FENETRE = Reglages.SURVEILLANCE_FENETRE
		-- Le délai pendant lequel le serveur ne prend aucun relevé après une téléportation (serveur/Capacites).
		local DELAI = 1.5

		--- Le tampon juste après le placement : le seul relevé est la destination, à l'instant 0.
		local function apresPlacement(x: number, y: number, z: number)
			return Capacites.amorcer({ { instant = -9, x = 500, y = 500, z = 500 } }, 0, x, y, z)
		end

		it("amorcer repart de la destination : l'ancien tampon est oublié, un seul relevé reste", function()
			local tampon = apresPlacement(10, 20, 30)
			expect(#tampon).to.equal(1)
			expect(tampon[1].instant).to.equal(0)
			expect(tampon[1].x).to.equal(10)
			expect(tampon[1].y).to.equal(20)
			expect(tampon[1].z).to.equal(30)
			expect(Capacites.deplacementFenetre(tampon)).never.to.be.ok() -- pas de verdict sur un seul relevé
		end)

		it(
			"ne compare jamais le saut de la téléportation : un joueur qui reste sur place n'est pas refusé",
			function()
				local tampon = apresPlacement(100, 300, 0) -- très loin du point de départ, qui n'est plus dans le tampon
				Capacites.empiler(tampon, DELAI, 100, 300, 0, FENETRE)
				expect(Capacites.evaluerFenetre(AUCUNE, tampon)).never.to.be.ok()
			end
		)

		it("accepte un joueur qui marche, court ou saute juste après son arrivée", function()
			local marche = apresPlacement(0, 10, 0)
			Capacites.empiler(marche, DELAI, 16 * DELAI, 10, 0, FENETRE)
			expect(Capacites.evaluerFenetre(AUCUNE, marche)).never.to.be.ok()
			local course = apresPlacement(0, 10, 0)
			Capacites.empiler(course, DELAI, 24 * DELAI, 10, 0, FENETRE)
			expect(Capacites.evaluerFenetre(COURSE, course)).never.to.be.ok()
			local saut = apresPlacement(0, 10, 0)
			Capacites.empiler(saut, DELAI, 0, 17.2, 0, FENETRE)
			expect(Capacites.evaluerFenetre(AUCUNE, saut)).never.to.be.ok()
		end)

		it("accepte un joueur qui tombe de la plateforme d'arrivée", function()
			local tampon = apresPlacement(0, 300, 0)
			Capacites.empiler(tampon, DELAI, 5, 0, 0, FENETRE)
			expect(Capacites.evaluerFenetre(AUCUNE, tampon)).never.to.be.ok()
		end)

		it("refuse un vol horizontal pris dès le premier relevé après le délai (le trou des 1,5 s)", function()
			local tampon = apresPlacement(0, 10, 0)
			Capacites.empiler(tampon, DELAI, 150, 10, 0, FENETRE) -- 100 studs/s pendant le délai
			expect(Capacites.evaluerFenetre(TOUTES, tampon)).to.equal("horizontal")
		end)

		it("refuse une montée en vol prise dès le premier relevé après le délai", function()
			local tampon = apresPlacement(0, 10, 0)
			Capacites.empiler(tampon, DELAI, 0, 160, 0, FENETRE) -- 100 studs/s vers le haut
			expect(Capacites.evaluerFenetre(TOUTES, tampon)).to.equal("vertical")
		end)

		it("sans relevé de départ, le même vol ne se voyait pas (c'est ce que l'amorce corrige)", function()
			local sans = {}
			Capacites.empiler(sans, DELAI, 150, 10, 0, FENETRE)
			expect(Capacites.evaluerFenetre(TOUTES, sans)).never.to.be.ok()
		end)

		it("la destination reste la référence tant qu'elle couvre la fenêtre, puis la fenêtre glisse", function()
			local tampon = apresPlacement(0, 10, 0)
			Capacites.empiler(tampon, 1.5, 10, 10, 0, FENETRE)
			Capacites.empiler(tampon, 2, 20, 10, 0, FENETRE)
			expect(tampon[1].instant).to.equal(0) -- 2 s < FENETRE : toujours la référence
			Capacites.empiler(tampon, 4.5, 30, 10, 0, FENETRE)
			expect(tampon[1].instant > 0).to.equal(true) -- au-delà de la fenêtre : la référence suivante a pris le relais
		end)

		it("une téléportation toutes les 2 s : chaque tour est mesuré, le vol n'a plus de pause gratuite", function()
			-- À chaque tour le tampon repart de la destination, et le premier relevé (1,5 s plus tard) est jugé.
			for tour = 1, 5 do
				local tampon = apresPlacement(tour * 100, 50, 0)
				Capacites.empiler(tampon, DELAI, tour * 100 + 120, 50, 0, FENETRE)
				expect(Capacites.evaluerFenetre(TOUTES, tampon)).to.equal("horizontal")
			end
		end)
	end)
end
