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
end
