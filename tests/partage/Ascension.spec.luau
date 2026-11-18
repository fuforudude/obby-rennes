-- L'ascension : aura croissante par étage, paliers, chrono classable, hauteur affichée, et la validation serveur
-- d'une demande de téléportation vers un palier (mauvais type, palier inconnu, palier non débloqué, cadence).
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

	describe("paliers", function()
		-- Cinq paliers, tous les 60 studs, comme la carte de l'ascension.
		local PALIERS = { 60, 120, 180, 240, 300 }

		it("sous le premier palier, aucun palier n'est atteint", function()
			expect(Ascension.palierPour(0, PALIERS)).to.equal(0)
			expect(Ascension.palierPour(59.9, PALIERS)).to.equal(0)
		end)

		it("atteindre la hauteur d'un palier donne ce palier", function()
			expect(Ascension.palierPour(60, PALIERS)).to.equal(1)
			expect(Ascension.palierPour(119, PALIERS)).to.equal(1)
			expect(Ascension.palierPour(180, PALIERS)).to.equal(3)
		end)

		it("au-delà du dernier palier, c'est le dernier", function()
			expect(Ascension.palierPour(1000, PALIERS)).to.equal(5)
		end)

		it("sans palier dans la carte, il n'y a rien à atteindre", function()
			expect(Ascension.palierPour(500, {})).to.equal(0)
		end)
	end)

	describe("le chrono de l'ascension n'est classé que s'il est honnête", function()
		local function tentative(modif: { [string]: any }?)
			local t: { [string]: any } = { debut = 100, teleportations = 0, alertes = 0 }
			for cle, valeur in modif or {} do
				t[cle] = valeur
			end
			if t.debut == false then
				t.debut = nil
			end
			return t
		end

		it("classe une ascension sans téléportation ni alerte", function()
			expect(Ascension.estClassable(tentative())).to.equal(true)
		end)

		it("une téléportation vers un palier rend la tentative non classée", function()
			expect(Ascension.estClassable(tentative({ teleportations = 1 }))).to.equal(false)
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
	end)

	describe(
		"l'aura après une téléportation : les étages au-dessus du palier d'arrivée paient, ceux d'en dessous non",
		function()
			-- Étages tous les 15 studs (17 étages jusqu'au sommet) et paliers aux étages 4, 8, 12 et 16 (60, 120, 180, 240).
			local MARGE = 2 -- Reglages.ASCENSION_MARGE_PALIER
			local function hauteurEtage(numero: number): number
				return numero * 15 + 0.95 -- le dessus de la plaque est un peu au-dessus de la dalle
			end
			local function tentative(modif: { [string]: any }?)
				local t: { [string]: any } = { debut = 100, teleportations = 0, alertes = 0 }
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

			it("sans téléportation, tous les étages paient", function()
				expect(Ascension.etagePaye(tentative(), hauteurEtage(1))).to.equal(true)
				expect(Ascension.etagePaye(tentative(), hauteurEtage(17))).to.equal(true)
				expect(auraTotale(tentative())).to.equal(Ascension.auraAscension(17, BAREME))
			end)

			it("le seuil après une téléportation est la hauteur du palier plus la marge", function()
				expect(Ascension.hauteurMinimumPayante(180, MARGE)).to.equal(182)
			end)

			it(
				"après une téléportation au palier 3 (180 studs), les étages au-dessus paient normalement",
				function()
					local t = tentative({
						teleportations = 1,
						hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
					})
					expect(Ascension.etagePaye(t, hauteurEtage(13))).to.equal(true)
					expect(Ascension.etagePaye(t, hauteurEtage(17))).to.equal(true)
				end
			)

			it("après une téléportation au palier 3, les étages en dessous ne paient rien", function()
				local t = tentative({
					teleportations = 1,
					hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
				})
				expect(Ascension.etagePaye(t, hauteurEtage(1))).to.equal(false)
				expect(Ascension.etagePaye(t, hauteurEtage(11))).to.equal(false)
			end)

			it("l'étage posé sur la dalle même du palier d'arrivée ne paie pas", function()
				local t = tentative({
					teleportations = 1,
					hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
				})
				expect(Ascension.etagePaye(t, hauteurEtage(12))).to.equal(false) -- 180,95 : la dalle du palier
			end)

			it("exemple chiffré : au palier 3, seuls les étages 13 à 17 paient, soit 3 300 d'aura", function()
				local t = tentative({
					teleportations = 1,
					hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
				})
				-- 580 + 620 + 660 + 700 + 740
				expect(auraTotale(t)).to.equal(3300)
				-- contre 7 140 pour les 17 étages grimpés depuis le pied.
				expect(Ascension.auraAscension(17, BAREME)).to.equal(7140)
			end)

			it("une téléportation ne rapporte jamais plus que de grimper : un palier plus haut paie moins", function()
				local function aura(hauteurPalier: number)
					return auraTotale(tentative({
						teleportations = 1,
						hauteurMinimumPayante = Ascension.hauteurMinimumPayante(hauteurPalier, MARGE),
					}))
				end
				expect(aura(60) > aura(120)).to.equal(true)
				expect(aura(120) > aura(180)).to.equal(true)
				expect(aura(180) > aura(240)).to.equal(true)
				expect(aura(60) < Ascension.auraAscension(17, BAREME)).to.equal(true)
			end)

			it("une alerte de la surveillance : plus rien ne paie, même au-dessus du palier", function()
				local t = tentative({
					teleportations = 1,
					alertes = 1,
					hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
				})
				expect(Ascension.etagePaye(t, hauteurEtage(17))).to.equal(false)
				expect(Ascension.etagePaye(tentative({ alertes = 1 }), hauteurEtage(1))).to.equal(false)
				expect(auraTotale(t)).to.equal(0)
			end)

			it("sans chrono (après le sommet), plus rien ne paie", function()
				local t = tentative()
				t.debut = nil
				expect(Ascension.etagePaye(t, hauteurEtage(5))).to.equal(false)
			end)

			it("une hauteur d'étage abîmée ne paie pas", function()
				local t = tentative({ hauteurMinimumPayante = 100 })
				expect(Ascension.etagePaye(t, 0 / 0)).to.equal(false)
				expect(Ascension.etagePaye(tentative(), 0 / 0)).to.equal(false)
			end)

			it("une téléportation rend toujours la tentative non classée, aura payée ou non", function()
				local t = tentative({
					teleportations = 1,
					hauteurMinimumPayante = Ascension.hauteurMinimumPayante(180, MARGE),
				})
				expect(Ascension.estClassable(t)).to.equal(false)
				expect(Ascension.etagePaye(t, hauteurEtage(15))).to.equal(true)
			end)
		end
	)

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
	end)

	describe("la téléportation ne marche que vers un palier réellement débloqué", function()
		local function entree(modif: { [string]: any }?)
			local e: { [string]: any } = {
				numero = 2,
				enAscension = true,
				paliersCarte = { 60, 120, 180, 240, 300 },
				paliersDebloques = { 1, 2 },
			}
			for cle, valeur in modif or {} do
				e[cle] = valeur
			end
			return e
		end

		local function valider(modif: { [string]: any }?)
			local ok, pourquoi = Ascension.validerTeleport(entree(modif))
			return ok, pourquoi
		end

		it("accepte un palier débloqué", function()
			local ok, pourquoi = valider()
			expect(ok).to.equal(true)
			expect(pourquoi).never.to.be.ok()
		end)

		it("refuse un numéro qui n'est pas un nombre entier (mauvais type)", function()
			local ok, pourquoi = valider({ numero = "2" })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("mauvais_type")
			expect(select(2, valider({ numero = true }))).to.equal("mauvais_type")
			expect(select(2, valider({ numero = 1.5 }))).to.equal("mauvais_type")
			expect(select(2, valider({ numero = 0 / 0 }))).to.equal("mauvais_type")
			expect(select(2, valider({ numero = math.huge }))).to.equal("mauvais_type")
		end)

		it("refuse une demande sans numéro du tout", function()
			local ok, pourquoi = Ascension.validerTeleport({
				numero = nil,
				enAscension = true,
				paliersCarte = { 60 },
				paliersDebloques = { 1 },
			})
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("mauvais_type")
		end)

		it("refuse un palier qui n'existe pas dans la carte", function()
			expect(select(2, valider({ numero = 0 }))).to.equal("palier_inconnu")
			expect(select(2, valider({ numero = -3 }))).to.equal("palier_inconnu")
			expect(select(2, valider({ numero = 9 }))).to.equal("palier_inconnu")
		end)

		it("refuse un palier jamais atteint, même s'il existe dans la carte", function()
			local ok, pourquoi = valider({ numero = 4 })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("palier_non_debloque")
		end)

		it("refuse un joueur qui n'est pas dans l'ascension", function()
			local ok, pourquoi = valider({ enAscension = false })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("pas_en_ascension")
		end)
	end)

	describe("traiterTeleport (cadence + validation, comme le service)", function()
		local DELAI = 2 -- Reglages.PALIER_DELAI_TELEPORT
		local function entree(modif: { [string]: any }?)
			local e: { [string]: any } = {
				numero = 2,
				enAscension = true,
				paliersCarte = { 60, 120, 180 },
				paliersDebloques = { 1, 2 },
			}
			for cle, valeur in modif or {} do
				e[cle] = valeur
			end
			return e
		end

		local function traiter(derniers: { [any]: number }, cle: any, instant: number, modif: { [string]: any }?)
			local ok, pourquoi = Ascension.traiterTeleport(derniers, cle, instant, DELAI, function()
				return entree(modif)
			end)
			return ok, pourquoi
		end

		it("accepte la première demande (la cadence ne se refuse pas elle-même)", function()
			local derniers = {}
			local ok, pourquoi = traiter(derniers, "A", 100)
			expect(ok).to.equal(true)
			expect(pourquoi).never.to.be.ok()
		end)

		it("refuse une seconde téléportation dans les 2 secondes", function()
			local derniers = {}
			expect(traiter(derniers, "A", 100)).to.equal(true)
			local ok, pourquoi = traiter(derniers, "A", 101.5)
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("trop_souvent")
		end)

		it("accepte à nouveau une fois les 2 secondes écoulées", function()
			local derniers = {}
			expect(traiter(derniers, "A", 100)).to.equal(true)
			expect(traiter(derniers, "A", 102)).to.equal(true)
		end)

		it("un joueur n'en gêne pas un autre", function()
			local derniers = {}
			expect(traiter(derniers, "A", 100)).to.equal(true)
			expect(traiter(derniers, "B", 100.1)).to.equal(true)
		end)

		it("note l'heure même quand la validation refuse (un spam invalide reste limité)", function()
			local derniers = {}
			local ok, pourquoi = traiter(derniers, "A", 100, { numero = 3 })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("palier_non_debloque")
			expect(derniers.A).to.equal(100)
			expect(select(2, traiter(derniers, "A", 101))).to.equal("trop_souvent")
		end)

		it("un refus de cadence ne repousse pas l'heure notée", function()
			local derniers = {}
			traiter(derniers, "A", 100)
			traiter(derniers, "A", 101) -- refusé : la fenêtre reste calée sur 100
			expect(derniers.A).to.equal(100)
			expect(traiter(derniers, "A", 102)).to.equal(true)
		end)

		it(
			"n'évalue pas l'entrée quand la cadence refuse (les rafales sont écartées avant de rassembler)",
			function()
				local derniers = {}
				traiter(derniers, "A", 100)
				local appels = 0
				Ascension.traiterTeleport(derniers, "A", 100.5, DELAI, function()
					appels += 1
					return entree()
				end)
				expect(appels).to.equal(0)
			end
		)
	end)
end
