-- Les obstacles de la tour, côté règles pures (src/partage/Pieges.luau) : le piège de mur (lecture des attributs,
-- déclenchement par la distance, cycle sortie / rentrée / repos, poussée horizontale), le laser (balayage régulier
-- calé sur l'horloge du serveur) et la plateforme qui s'effondre (chute puis retour).
-- Un `it` par critère d'acceptation de docs/specs/2026-11-18-tour-exigeante.md, et un par refus de validation.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Pieges = require(ReplicatedStorage.Partage.Pieges)

	-- Les valeurs du jeu sont dans Reglages ; les tests passent les leurs pour rester indépendants de l'équilibrage.
	local DEFAUTS_PIEGE = { portee = 10, poussee = 60, pousseeMax = 65, repos = 1.2 }
	local DEFAUTS_EFFONDRABLE = { delaiChute = 0.5, delaiRetour = 4 }

	local function proche(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	local function attributsPiege(modif: { [string]: any }?): { [string]: any }
		local a: { [string]: any } = {
			Direction = Vector3.new(1, 0, 0),
			Distance = 6,
			DureeSortie = 0.12,
			DureeRentree = 0.5,
		}
		for cle, valeur in modif or {} do
			a[cle] = if valeur == "absent" then nil else valeur
		end
		return a
	end

	-- Les défauts que le SERVICE passe vraiment (Pieges.defautsPiege / defautsEffondrable, lus dans Reglages) : les
	-- autres tests de ce fichier passent leurs propres tables, donc ne voyaient pas un champ oublié par l'appelant.
	describe("défauts construits à partir des réglages du jeu", function()
		local Reglages = require(ReplicatedStorage.Partage.Reglages)

		it("les défauts du piège de mur sont complets : la lecture d'une pointe bien décrite aboutit", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege(), Pieges.defautsPiege()) :: any
			expect(p).to.be.ok()
			expect(p.portee).to.equal(Reglages.PIEGE_PORTEE)
			expect(p.poussee).to.equal(Reglages.PIEGE_POUSSEE)
			expect(p.repos).to.equal(Reglages.PIEGE_REPOS)
		end)

		it("les défauts du piège de mur plafonnent la poussée de la carte au plafond des réglages", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege({ Poussee = 1000 }), Pieges.defautsPiege()) :: any
			expect(p.poussee).to.equal(Reglages.PIEGE_POUSSEE_MAX)
		end)

		it("chaque défaut du piège de mur est un nombre fini et positif", function()
			for _, valeur in Pieges.defautsPiege() do
				expect(type(valeur)).to.equal("number")
				expect(valeur > 0 and valeur < math.huge).to.equal(true) -- ni 0, ni négatif, ni infini, ni NaN
			end
		end)

		it("les défauts de la plateforme qui s'effondre sont complets", function()
			local e = Pieges.effondrableDepuisAttributs({}, Pieges.defautsEffondrable()) :: any
			expect(e).to.be.ok()
			expect(e.delaiChute).to.equal(Reglages.EFFONDRABLE_DELAI)
			expect(e.delaiRetour).to.equal(Reglages.EFFONDRABLE_RETOUR)
		end)
	end)

	describe("piège de mur : lecture des attributs de la carte", function()
		it("lit une pointe bien décrite, et complète portée et poussée par les réglages", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege(), DEFAUTS_PIEGE)
			expect(p).to.be.ok()
			expect((p :: any).distance).to.equal(6)
			expect((p :: any).dureeSortie).to.equal(0.12)
			expect((p :: any).dureeRentree).to.equal(0.5)
			expect((p :: any).portee).to.equal(10)
			expect((p :: any).poussee).to.equal(60)
			expect((p :: any).repos).to.equal(1.2)
			expect((p :: any).direction.X).to.equal(1)
		end)

		it("laisse la carte régler sa propre portée et sa propre poussée", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege({ Portee = 4, Poussee = 35 }), DEFAUTS_PIEGE)
			expect((p :: any).portee).to.equal(4)
			expect((p :: any).poussee).to.equal(35)
		end)

		it("plafonne la poussée de la carte : une valeur au-dessus du dash est ramenée au plafond", function()
			local Reglages = require(ReplicatedStorage.Partage.Reglages)
			local defauts =
				{ portee = 10, poussee = Reglages.PIEGE_POUSSEE, pousseeMax = Reglages.PIEGE_POUSSEE_MAX, repos = 1.2 }
			local p = Pieges.piegeDepuisAttributs(attributsPiege({ Poussee = 120 }), defauts) :: any
			expect(p.poussee).to.equal(Reglages.PIEGE_POUSSEE_MAX)
			expect(p.poussee < Reglages.DASH_VITESSE).to.equal(true)
			local sous = Pieges.piegeDepuisAttributs(attributsPiege({ Poussee = 35 }), defauts) :: any
			expect(sous.poussee).to.equal(35)
		end)

		it("sans Repos, la fenêtre de passage est celle des réglages ; un Repos absurde refuse le piège", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege(), DEFAUTS_PIEGE) :: any
			expect(p.repos).to.equal(1.2)
			local carte = Pieges.piegeDepuisAttributs(attributsPiege({ Repos = 2 }), DEFAUTS_PIEGE) :: any
			expect(carte.repos).to.equal(2)
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Repos = 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Repos = -1 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Repos = "long" }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Repos = 0 / 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
		end)

		it("normalise la direction (une carte peut donner un vecteur non unitaire)", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege({ Direction = Vector3.new(0, 0, 4) }), DEFAUTS_PIEGE)
			expect(proche((p :: any).direction.Z, 1)).to.equal(true)
			expect(proche((p :: any).direction.Magnitude, 1)).to.equal(true)
		end)

		it("ignore la part verticale de la direction : la poussée reste horizontale", function()
			local p = Pieges.piegeDepuisAttributs(attributsPiege({ Direction = Vector3.new(1, 5, 0) }), DEFAUTS_PIEGE)
			expect((p :: any).direction.Y).to.equal(0)
			expect(proche((p :: any).direction.X, 1)).to.equal(true)
		end)

		it("refuse une direction qui n'est pas un Vector3 (mauvais type)", function()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Direction = "x" }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Direction = 3 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Direction = "absent" }), DEFAUTS_PIEGE)).never.to.be.ok()
		end)

		it("refuse une direction nulle ou purement verticale (rien à pousser dans le plan)", function()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Direction = Vector3.new(0, 0, 0) }), DEFAUTS_PIEGE)).never.to.be.ok()
			local haut = attributsPiege({ Direction = Vector3.new(0, 1, 0) })
			expect(Pieges.piegeDepuisAttributs(haut, DEFAUTS_PIEGE)).never.to.be.ok()
		end)

		it("refuse une distance, une durée ou une portée absurdes", function()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Distance = 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Distance = -2 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Distance = 0 / 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ DureeSortie = 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ DureeRentree = -1 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ DureeSortie = math.huge }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Portee = -5 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Poussee = 0 }), DEFAUTS_PIEGE)).never.to.be.ok()
			expect(Pieges.piegeDepuisAttributs(attributsPiege({ Poussee = "fort" }), DEFAUTS_PIEGE)).never.to.be.ok()
		end)
	end)

	describe("piège de mur : la pointe sort quand le joueur approche, pas avant", function()
		local p = Pieges.piegeDepuisAttributs(attributsPiege(), DEFAUTS_PIEGE) :: any

		it("se déclenche quand un joueur entre dans la portée", function()
			expect(Pieges.doitDeclencher("pret", 9.9, p.portee)).to.equal(true)
			expect(Pieges.doitDeclencher("pret", 0, p.portee)).to.equal(true)
			expect(Pieges.doitDeclencher("pret", 10, p.portee)).to.equal(true)
		end)

		it("ne se déclenche pas sur un joueur trop loin", function()
			expect(Pieges.doitDeclencher("pret", 10.1, p.portee)).to.equal(false)
			expect(Pieges.doitDeclencher("pret", 400, p.portee)).to.equal(false)
		end)

		it("ne se redéclenche pas tant qu'il n'est pas revenu au repos (trop souvent)", function()
			expect(Pieges.doitDeclencher("sortie", 1, p.portee)).to.equal(false)
			expect(Pieges.doitDeclencher("rentree", 1, p.portee)).to.equal(false)
			expect(Pieges.doitDeclencher("repos", 1, p.portee)).to.equal(false)
		end)

		it("ne se déclenche pas sans distance mesurable (personne, ou position abîmée)", function()
			expect(Pieges.doitDeclencher("pret", nil, p.portee)).to.equal(false)
			expect(Pieges.doitDeclencher("pret", 0 / 0, p.portee)).to.equal(false)
		end)
	end)

	describe("piège de mur : le cycle sortie / rentrée / repos", function()
		local p =
			Pieges.piegeDepuisAttributs(attributsPiege({ DureeSortie = 0.2, DureeRentree = 0.5 }), DEFAUTS_PIEGE) :: any

		local function phase(ecoule: number)
			return Pieges.phasePiege(ecoule, p)
		end

		it("sort en DureeSortie secondes, de la fente jusqu'au bout", function()
			local etat, avance = phase(0)
			expect(etat).to.equal("sortie")
			expect(avance).to.equal(0)
			etat, avance = phase(0.1)
			expect(etat).to.equal("sortie")
			expect(proche(avance, 0.5)).to.equal(true)
			etat, avance = phase(0.199)
			expect(etat).to.equal("sortie")
			expect(avance > 0.99).to.equal(true)
		end)

		it("rentre en DureeRentree secondes, du bout jusqu'à la fente", function()
			local etat, avance = phase(0.2)
			expect(etat).to.equal("rentree")
			expect(avance).to.equal(1)
			etat, avance = phase(0.45)
			expect(etat).to.equal("rentree")
			expect(proche(avance, 0.5)).to.equal(true)
			etat, avance = phase(0.699)
			expect(etat).to.equal("rentree")
			expect(avance < 0.01).to.equal(true)
		end)

		it("se repose rentrée avant de pouvoir se redéclencher", function()
			local etat, avance = phase(0.7)
			expect(etat).to.equal("repos")
			expect(avance).to.equal(0)
			expect(phase(1.8)).to.equal("repos")
		end)

		it("redevient prête une fois le repos écoulé", function()
			-- 0,2 + 0,5 + 1,2 = 1,9 s
			local etat, avance = phase(1.9)
			expect(etat).to.equal("pret")
			expect(avance).to.equal(0)
			expect(phase(60)).to.equal("pret")
		end)

		it("avant tout déclenchement, la pointe est rentrée et prête", function()
			local etat, avance = phase(-1)
			expect(etat).to.equal("pret")
			expect(avance).to.equal(0)
		end)
	end)

	describe("piège de mur : la poussée projette à l'horizontale, sans tuer", function()
		it("impose la vitesse de poussée dans la direction du piège", function()
			local v = Pieges.vitesseApresPoussee(Vector3.new(3, -20, 0), Vector3.new(1, 0, 0), 60)
			expect(v.X).to.equal(60)
			expect(v.Z).to.equal(0)
		end)

		it("ne touche pas à la vitesse verticale (ni envol ni écrasement au sol)", function()
			local v = Pieges.vitesseApresPoussee(Vector3.new(0, -42.5, 0), Vector3.new(0, 0, 1), 60)
			expect(v.Y).to.equal(-42.5)
			expect(v.Z).to.equal(60)
		end)

		it("les réglages gardent la poussée par défaut et son plafond sous la vitesse du dash", function()
			-- Un dash lancé dans l'autre sens reprend la main. La poussée posée par la carte est testée plus haut.
			local Reglages = require(ReplicatedStorage.Partage.Reglages)
			expect(Reglages.PIEGE_POUSSEE > 0).to.equal(true)
			expect(Reglages.PIEGE_POUSSEE <= Reglages.PIEGE_POUSSEE_MAX).to.equal(true)
			expect(Reglages.PIEGE_POUSSEE_MAX < Reglages.DASH_VITESSE).to.equal(true)
		end)
	end)

	describe("laser : balayage régulier, calé sur l'horloge du serveur", function()
		local DEPART, ARRIVEE = Vector3.new(0, 100, 0), Vector3.new(20, 100, 0)

		local function attributs(modif: { [string]: any }?): { [string]: any }
			local a: { [string]: any } = { Depart = DEPART, Arrivee = ARRIVEE, Periode = 4, Decalage = 0 }
			for cle, valeur in modif or {} do
				a[cle] = if valeur == "absent" then nil else valeur
			end
			return a
		end

		it("lit un laser bien décrit", function()
			local l = Pieges.laserDepuisAttributs(attributs())
			expect(l).to.be.ok()
			expect((l :: any).periode).to.equal(4)
			expect((l :: any).decalage).to.equal(0)
		end)

		it("refuse des extrémités qui ne sont pas des Vector3, ou confondues (mauvais type)", function()
			expect(Pieges.laserDepuisAttributs(attributs({ Depart = 3 }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Arrivee = "absent" }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Arrivee = DEPART }))).never.to.be.ok()
		end)

		it("refuse une période ou un décalage absurdes", function()
			expect(Pieges.laserDepuisAttributs(attributs({ Periode = 0 }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Periode = -4 }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Periode = math.huge }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Decalage = 0 / 0 }))).never.to.be.ok()
			expect(Pieges.laserDepuisAttributs(attributs({ Decalage = "2" }))).never.to.be.ok()
		end)

		it("part du départ au décalage, atteint l'arrivée à la demi-période, et revient", function()
			expect(Pieges.fractionBalayage(0, 4, 0)).to.equal(0)
			expect(proche(Pieges.fractionBalayage(1, 4, 0), 0.5)).to.equal(true)
			expect(proche(Pieges.fractionBalayage(2, 4, 0), 1)).to.equal(true)
			expect(proche(Pieges.fractionBalayage(3, 4, 0), 0.5)).to.equal(true)
			expect(proche(Pieges.fractionBalayage(4, 4, 0), 0)).to.equal(true)
		end)

		it("rend le même balayage à chaque période : le rythme est apprenable", function()
			expect(proche(Pieges.fractionBalayage(1, 4, 0), Pieges.fractionBalayage(41, 4, 0))).to.equal(true)
			expect(proche(Pieges.fractionBalayage(2.5, 4, 0), Pieges.fractionBalayage(1002.5, 4, 0))).to.equal(true)
		end)

		it("le décalage décale le balayage, y compris avant l'instant zéro", function()
			expect(proche(Pieges.fractionBalayage(1, 4, 1), 0)).to.equal(true)
			expect(proche(Pieges.fractionBalayage(3, 4, 1), 1)).to.equal(true)
			expect(proche(Pieges.fractionBalayage(-3, 4, 1), 0)).to.equal(true)
		end)

		it("la position suit la fraction, du départ à l'arrivée", function()
			local l = Pieges.laserDepuisAttributs(attributs()) :: any
			expect(proche(Pieges.positionLaser(0, l).X, 0)).to.equal(true)
			expect(proche(Pieges.positionLaser(1, l).X, 10)).to.equal(true)
			expect(proche(Pieges.positionLaser(2, l).X, 20)).to.equal(true)
			expect(proche(Pieges.positionLaser(1, l).Y, 100)).to.equal(true)
		end)
	end)

	describe("plateforme qui s'effondre : elle tombe après le premier contact et revient", function()
		local function attributs(modif: { [string]: any }?): { [string]: any }
			local a: { [string]: any } = {}
			for cle, valeur in modif or {} do
				a[cle] = if valeur == "absent" then nil else valeur
			end
			return a
		end

		it("sans attribut, prend les délais des réglages (0,5 s avant la chute)", function()
			local e = Pieges.effondrableDepuisAttributs(attributs(), DEFAUTS_EFFONDRABLE)
			expect(e).to.be.ok()
			expect((e :: any).delaiChute).to.equal(0.5)
			expect((e :: any).delaiRetour).to.equal(4)
		end)

		it("laisse la carte régler ses propres délais", function()
			local e = Pieges.effondrableDepuisAttributs(
				attributs({ DelaiChute = 0.25, DelaiRetour = 6 }),
				DEFAUTS_EFFONDRABLE
			)
			expect((e :: any).delaiChute).to.equal(0.25)
			expect((e :: any).delaiRetour).to.equal(6)
		end)

		it("refuse des délais absurdes (mauvais type, négatif, infini)", function()
			local function refus(modif)
				return Pieges.effondrableDepuisAttributs(attributs(modif), DEFAUTS_EFFONDRABLE)
			end
			expect(refus({ DelaiChute = -1 })).never.to.be.ok()
			expect(refus({ DelaiChute = "0.5" })).never.to.be.ok()
			expect(refus({ DelaiRetour = 0 })).never.to.be.ok()
			expect(refus({ DelaiRetour = 0 / 0 })).never.to.be.ok()
			expect(refus({ DelaiRetour = math.huge })).never.to.be.ok()
		end)

		it("tient pendant DelaiChute, puis tombe, puis revient à sa place", function()
			local e = Pieges.effondrableDepuisAttributs(attributs(), DEFAUTS_EFFONDRABLE) :: any
			expect(Pieges.cycleEffondrable(0, e)).to.equal("tient")
			expect(Pieges.cycleEffondrable(0.49, e)).to.equal("tient")
			expect(Pieges.cycleEffondrable(0.5, e)).to.equal("tombee")
			expect(Pieges.cycleEffondrable(4.49, e)).to.equal("tombee")
			expect(Pieges.cycleEffondrable(4.5, e)).to.equal("revenue")
			expect(Pieges.cycleEffondrable(100, e)).to.equal("revenue")
		end)

		it("la chute libre est plafonnée, et raccourcie si le retour arrive plus tôt", function()
			expect(Pieges.dureeChuteLibre(4, 1.5)).to.equal(1.5)
			expect(Pieges.dureeChuteLibre(1.5, 1.5)).to.equal(1.5)
			expect(Pieges.dureeChuteLibre(0.8, 1.5)).to.equal(0.8)
		end)

		it("avant le premier contact, elle tient", function()
			local e = Pieges.effondrableDepuisAttributs(attributs(), DEFAUTS_EFFONDRABLE) :: any
			expect(Pieges.cycleEffondrable(-2, e)).to.equal("tient")
		end)
	end)

	describe("balancier : le multiplicateur de poussée des pancartes qui basculent", function()
		it("vaut 1 quand l'attribut est absent (les balanciers d'avant ne changent pas)", function()
			expect(Pieges.multiplicateurPoussee(nil, 20)).to.equal(1)
		end)

		it("accepte un multiplicateur raisonnable", function()
			expect(Pieges.multiplicateurPoussee(3, 20)).to.equal(3)
			expect(Pieges.multiplicateurPoussee(0.5, 20)).to.equal(0.5)
			expect(Pieges.multiplicateurPoussee(20, 20)).to.equal(20)
		end)

		it("refuse une valeur absurde et revient à 1 (mauvais type, négatif, hors plafond)", function()
			expect(Pieges.multiplicateurPoussee("fort", 20)).to.equal(1)
			expect(Pieges.multiplicateurPoussee(0, 20)).to.equal(1)
			expect(Pieges.multiplicateurPoussee(-4, 20)).to.equal(1)
			expect(Pieges.multiplicateurPoussee(0 / 0, 20)).to.equal(1)
			expect(Pieges.multiplicateurPoussee(math.huge, 20)).to.equal(1)
			expect(Pieges.multiplicateurPoussee(1000, 20)).to.equal(1)
		end)
	end)
end
