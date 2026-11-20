-- L'ascension : aura croissante par étage, chrono classable, hauteur affichée.
-- Depuis la tour exigeante il n'y a plus de paliers : plus de téléportation à valider, plus de seuil d'aura.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Ascension = require(ReplicatedStorage.Partage.Ascension)

	-- Le barème du jeu (Reglages.ASCENSION_*) ; les tests passent le leur pour rester indépendants de l'équilibrage.
	local BAREME = {
		ASCENSION_AURA_BASE = 100,
		ASCENSION_AURA_PAR_ETAGE = 40,
	}

	describe("chaque étage franchi rapporte de l'aura, d'autant plus que l'étage est haut", function()
		it("le premier étage rapporte la base", function()
			expect(Ascension.auraEtage(1, BAREME)).to.equal(100)
		end)

		it("chaque étage rapporte plus que celui d'en dessous", function()
			expect(Ascension.auraEtage(2, BAREME)).to.equal(140)
			expect(Ascension.auraEtage(10, BAREME)).to.equal(460)
			expect(Ascension.auraEtage(11, BAREME) > Ascension.auraEtage(10, BAREME)).to.equal(true)
		end)

		it("un étage haut vaut nettement plus qu'un étage bas", function()
			-- Au 25e étage, dix fois l'étage du bas : monter haut est le vrai gain.
			expect(Ascension.auraEtage(25, BAREME)).to.equal(1060)
			expect(Ascension.auraEtage(25, BAREME) >= 10 * Ascension.auraEtage(1, BAREME)).to.equal(true)
		end)

		it("un numéro d'étage abîmé compte pour l'étage 1, jamais plus", function()
			expect(Ascension.auraEtage(0, BAREME)).to.equal(100)
			expect(Ascension.auraEtage(-5, BAREME)).to.equal(100)
			expect(Ascension.auraEtage(3.7, BAREME)).to.equal(180) -- étage 3
			expect(Ascension.auraEtage(0 / 0, BAREME)).to.equal(100)
			expect(Ascension.auraEtage(math.huge, BAREME)).to.equal(100)
		end)

		it("l'aura d'une ascension complète reste du même ordre qu'un tuto parfait (équilibrage)", function()
			-- 25 étages : 100 + 140 + ... + 1060 = 14 500 ; le tuto parfait en rapporte environ 16 500.
			expect(Ascension.auraAscension(25, BAREME)).to.equal(14500)
			expect(Ascension.auraAscension(0, BAREME)).to.equal(0)
			expect(Ascension.auraAscension(1, BAREME)).to.equal(100)
		end)
	end)

	describe("le chrono de l'ascension n'est classé que s'il est honnête", function()
		local function tentative(modif: { [string]: any }?)
			local t: { [string]: any } = { debut = 100, alertes = 0 }
			for cle, valeur in modif or {} do
				t[cle] = valeur
			end
			if t.debut == false then
				t.debut = nil
			end
			return t
		end

		it("classe une ascension montée d'une traite, sans alerte", function()
			expect(Ascension.estClassable(tentative())).to.equal(true)
		end)

		it("une alerte de la surveillance des déplacements rend la tentative non classée", function()
			expect(Ascension.estClassable(tentative({ alertes = 1 }))).to.equal(false)
		end)

		it("sans chrono parti du pied, il n'y a rien à classer", function()
			expect(Ascension.estClassable(tentative({ debut = false }))).to.equal(false)
		end)

		it("un record de hauteur est une hauteur plus grande que l'ancienne", function()
			expect(Ascension.estRecordHauteur(0, 42)).to.equal(true)
			expect(Ascension.estRecordHauteur(42, 80)).to.equal(true)
			expect(Ascension.estRecordHauteur(80, 42)).to.equal(false)
			expect(Ascension.estRecordHauteur(80, 80)).to.equal(false)
			expect(Ascension.estRecordHauteur(0, 0)).to.equal(false)
		end)

		it("le renvoi périodique de l'état ne vise que ceux qui ont un record de hauteur à montrer", function()
			expect(Ascension.aQuelqueChoseAMontrer(0)).to.equal(false) -- le tuto : rien à répéter
			expect(Ascension.aQuelqueChoseAMontrer(120)).to.equal(true)
			expect(Ascension.aQuelqueChoseAMontrer(400)).to.equal(true)
		end)
	end)

	describe("sans paliers, tous les étages paient — sauf après une alerte de surveillance", function()
		-- Étages tous les 15 studs : la tour en compte 17 jusqu'au sommet.
		local function hauteurEtage(numero: number): number
			return numero * 15 + 0.95 -- le dessus de la plaque est un peu au-dessus de la dalle
		end
		local function tentative(modif: { [string]: any }?)
			local t: { [string]: any } = { debut = 100, alertes = 0 }
			for cle, valeur in modif or {} do
				t[cle] = valeur
			end
			return t
		end
		local function auraTotale(t: { [string]: any }): number
			local total = 0
			for numero = 1, 17 do
				if Ascension.etagePaye(t, hauteurEtage(numero)) then
					total += Ascension.auraEtage(numero, BAREME)
				end
			end
			return total
		end

		it("une montée depuis le pied paie tous les étages, du premier au dernier", function()
			expect(Ascension.etagePaye(tentative(), hauteurEtage(1))).to.equal(true)
			expect(Ascension.etagePaye(tentative(), hauteurEtage(17))).to.equal(true)
			expect(auraTotale(tentative())).to.equal(Ascension.auraAscension(17, BAREME))
			expect(auraTotale(tentative())).to.equal(7140)
		end)

		it("une alerte de la surveillance : plus rien ne paie, à aucune hauteur", function()
			local t = tentative({ alertes = 1 })
			expect(Ascension.etagePaye(t, hauteurEtage(1))).to.equal(false)
			expect(Ascension.etagePaye(t, hauteurEtage(17))).to.equal(false)
			expect(auraTotale(t)).to.equal(0)
		end)

		it("sans chrono (après le sommet), plus rien ne paie", function()
			local t = tentative()
			t.debut = nil
			expect(Ascension.etagePaye(t, hauteurEtage(5))).to.equal(false)
		end)

		it("une hauteur d'étage abîmée ne paie pas", function()
			expect(Ascension.etagePaye(tentative(), 0 / 0)).to.equal(false)
		end)
	end)

	describe("hauteur affichée en mètres", function()
		it("rend une hauteur lisible (1 stud vaut environ 0,28 m)", function()
			expect(Ascension.formaterHauteur(650)).to.equal("182 m")
			expect(Ascension.formaterHauteur(250)).to.equal("70 m")
			expect(Ascension.formaterHauteur(0)).to.equal("0 m")
		end)

		it("arrondit au mètre et ne descend jamais sous zéro", function()
			expect(Ascension.formaterHauteur(10)).to.equal("3 m") -- 2,8 m
			expect(Ascension.formaterHauteur(5)).to.equal("1 m") -- 1,4 m
			expect(Ascension.formaterHauteur(-200)).to.equal("0 m")
		end)

		it("rend des studs entiers pour le classement", function()
			expect(Ascension.versStudsEntiers(182.4)).to.equal(182)
			expect(Ascension.versStudsEntiers(182.6)).to.equal(183)
			expect(Ascension.versStudsEntiers(-5)).to.equal(0)
		end)
	end)

	describe("les classements de la tour dépendent de la version de tour", function()
		it("la version 1 donne exactement les noms actuels (rien ne repart à vide à la livraison)", function()
			local noms = Ascension.nomsClassementsTour(1)
			expect(noms.hauteur).to.equal("HauteurAscension_v1")
			expect(noms.temps).to.equal("TempsAscension_v1")
		end)

		it("la version 2 ouvre des classements neufs", function()
			local noms = Ascension.nomsClassementsTour(2)
			expect(noms.hauteur).to.equal("HauteurAscension_v2")
			expect(noms.temps).to.equal("TempsAscension_v2")
		end)

		it("le réglage du jeu est un entier à partir de 1", function()
			local Reglages = require(ReplicatedStorage.Partage.Reglages)
			expect(type(Reglages.VERSION_TOUR)).to.equal("number")
			expect(Reglages.VERSION_TOUR >= 1 and Reglages.VERSION_TOUR % 1 == 0).to.equal(true)
		end)
	end)
end
