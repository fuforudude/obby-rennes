-- Les horaires des événements : même état pour tous les joueurs à un instant donné du serveur.
-- Cycle : Decalage est l'instant où le danger commence (phase 0) ; il dure `duree`, puis c'est l'attente, puis le
-- préavis pendant les `preavis` dernières secondes avant le danger suivant.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Horaires = require(ReplicatedStorage.Partage.Horaires)

	-- Période 10 s, décalage 2 s, préavis 1,5 s, danger 2 s. Phase = (t - 2) mod 10 :
	-- actif pour t de 2 à 4, attente de 4 à 10,5, préavis de 10,5 à 12 (c'est-à-dire de 0,5 à 2 modulo 10).
	local PERIODE, DECALAGE, PREAVIS, DUREE = 10, 2, 1.5, 2

	local function etat(t: number)
		return Horaires.etat(t, PERIODE, DECALAGE, PREAVIS, DUREE)
	end

	it("est actif pendant la fenêtre de danger, avec une progression de 0 à 1", function()
		local e, p = etat(2)
		expect(e).to.equal("actif")
		expect(p).to.equal(0)
		e, p = etat(3)
		expect(e).to.equal("actif")
		expect(p).to.equal(0.5)
	end)

	it("quitte l'état actif exactement à la fin de la fenêtre", function()
		local e = etat(4)
		expect(e).to.equal("attente")
		e = etat(3.999)
		expect(e).to.equal("actif")
	end)

	it("donne le préavis dans les dernières secondes avant le danger", function()
		local e, p = etat(0.5)
		expect(e).to.equal("preavis")
		expect(p).to.equal(0)
		e, p = etat(1.25)
		expect(e).to.equal("preavis")
		expect(p).to.equal(0.5)
		e = etat(0.499)
		expect(e).to.equal("attente")
	end)

	it("reste en attente le reste du temps, avec une progression nulle", function()
		local e, p = etat(7)
		expect(e).to.equal("attente")
		expect(p).to.equal(0)
	end)

	it("boucle : le même état une période plus tard, ou plus tôt", function()
		for _, t in { 0.7, 2.5, 5, 9.9 } do
			local e1, p1 = etat(t)
			local e2, p2 = etat(t + PERIODE * 37)
			local e3, p3 = etat(t - PERIODE * 5)
			expect(e2).to.equal(e1)
			expect(e3).to.equal(e1)
			expect(math.abs(p2 - p1) < 1e-6).to.equal(true)
			expect(math.abs(p3 - p1) < 1e-6).to.equal(true)
		end
	end)

	it("accepte un décalage négatif ou plus grand que la période", function()
		-- Décalage -8 ou 12 équivaut à 2 (période 10).
		local e1 = Horaires.etat(3, PERIODE, -8, PREAVIS, DUREE)
		local e2 = Horaires.etat(3, PERIODE, 12, PREAVIS, DUREE)
		expect(e1).to.equal("actif")
		expect(e2).to.equal("actif")
	end)

	it("accepte un instant négatif (avant l'origine)", function()
		local e = etat(-8) -- -8 + 10 = 2
		expect(e).to.equal("actif")
	end)

	it("fonctionne sans préavis", function()
		local e = Horaires.etat(1.9, 10, 2, 0, 2)
		expect(e).to.equal("attente")
		e = Horaires.etat(2, 10, 2, 0, 2)
		expect(e).to.equal("actif")
	end)

	it("garde un état valable avec un instant serveur très grand", function()
		local e = Horaires.etat(1.7e9 + 3, 10, 0, 1, 2)
		expect(e == "actif" or e == "attente" or e == "preavis").to.equal(true)
	end)

	it("refuse un préavis et une fenêtre qui dépassent la période", function()
		expect(Horaires.valide(10, 1, 2)).to.equal(true)
		expect(Horaires.valide(10, 8, 2)).to.equal(true) -- pile la période : pas d'attente, mais permis
		expect(Horaires.valide(10, 8.5, 2)).to.equal(false)
		local ok = pcall(Horaires.etat, 0, 10, 0, 9, 2)
		expect(ok).to.equal(false)
	end)

	it("refuse les paramètres absurdes (période nulle, durée nulle, négatifs, pas des nombres)", function()
		expect(Horaires.valide(0, 1, 1)).to.equal(false)
		expect(Horaires.valide(-5, 1, 1)).to.equal(false)
		expect(Horaires.valide(10, 1, 0)).to.equal(false)
		expect(Horaires.valide(10, -1, 2)).to.equal(false)
		expect(Horaires.valide(0 / 0, 1, 2)).to.equal(false)
		expect(Horaires.valide(math.huge, 1, 2)).to.equal(false)
		expect(Horaires.valide("10" :: any, 1, 2)).to.equal(false)
	end)

	describe("prochaineFenetreSure", function()
		it("trouve le premier instant où aucun danger n'est actif pendant la durée demandée", function()
			-- Un seul danger actif de 2 à 4 (+ 10 k). Depuis 3 : sûr à partir de 4.
			local t = Horaires.prochaineFenetreSure({ { periode = 10, decalage = 2, duree = 2 } }, 3, 2, 100)
			expect(t).to.equal(4)
		end)

		it("rend l'instant de départ s'il est déjà sûr", function()
			local t = Horaires.prochaineFenetreSure({ { periode = 10, decalage = 2, duree = 2 } }, 5, 2, 100)
			expect(t).to.equal(5)
		end)

		it("combine plusieurs dangers : la fenêtre libre doit être assez longue", function()
			-- A actif sur [0, 2) et B sur [3, 5) : le trou [2, 3) ne fait qu'une seconde.
			local horaires = {
				{ periode = 10, decalage = 0, duree = 2 },
				{ periode = 10, decalage = 3, duree = 2 },
			}
			expect(Horaires.prochaineFenetreSure(horaires, 0, 2, 100)).to.equal(5)
			expect(Horaires.prochaineFenetreSure(horaires, 0, 1, 100)).to.equal(2)
		end)

		it("rend nil quand le danger ne laisse jamais assez de temps", function()
			-- Danger de 9 s sur 10 s : il ne reste qu'une seconde libre.
			local t = Horaires.prochaineFenetreSure({ { periode = 10, decalage = 0, duree = 9 } }, 0, 2, 100)
			expect(t).never.to.be.ok()
		end)

		it("sait regarder avant l'origine (instant négatif, décalage négatif)", function()
			local t = Horaires.prochaineFenetreSure({ { periode = 10, decalage = -8, duree = 2 } }, -9, 2, 100)
			expect(t).to.equal(-6)
		end)
	end)

	describe("actifAutour", function()
		it("accepte un contact pendant la fenêtre, et un peu avant ou après (retard réseau)", function()
			expect(Horaires.actifAutour(3, 10, 2, 2, 0)).to.equal(true) -- pile dedans
			expect(Horaires.actifAutour(4.5, 10, 2, 2, 1)).to.equal(true) -- 0,5 s après la fin
			expect(Horaires.actifAutour(1.5, 10, 2, 2, 1)).to.equal(true) -- 0,5 s avant le début
		end)

		it("refuse un contact loin de la fenêtre", function()
			expect(Horaires.actifAutour(7, 10, 2, 2, 1)).to.equal(false)
			expect(Horaires.actifAutour(4.5, 10, 2, 2, 0)).to.equal(false)
		end)

		it("refuse des paramètres absurdes", function()
			expect(Horaires.actifAutour(3, 0, 2, 2, 1)).to.equal(false)
			expect(Horaires.actifAutour(0 / 0, 10, 2, 2, 1)).to.equal(false)
			expect(Horaires.actifAutour(3, 10, 2, 2, -1)).to.equal(false)
		end)
	end)

	describe("preavisAllume", function()
		it("clignote pendant le préavis", function()
			-- 4 Hz : allumé 0,125 s, éteint 0,125 s. Préavis de 2 s : au début (reste 2 s) allumé.
			expect(Horaires.preavisAllume(0, 2, 4)).to.equal(true)
			expect(Horaires.preavisAllume(0.05, 2, 4)).to.equal(false) -- reste 1,9 s
			expect(Horaires.preavisAllume(0.1, 2, 4)).to.equal(true) -- reste 1,8 s
		end)

		it("reste allumé en continu juste avant le danger", function()
			for _, p in { 0.83, 0.9, 0.95, 0.999 } do
				expect(Horaires.preavisAllume(p, 2, 4)).to.equal(true)
			end
		end)
	end)

	describe("angleBalancier", function()
		it("part de la position posée, monte jusqu'à l'amplitude, revient, descend de l'autre côté", function()
			local function angle(t: number)
				return Horaires.angleBalancier(t, 40, 4, 0)
			end
			expect(angle(0)).to.equal(0)
			expect(math.abs(angle(1) - 40) < 1e-9).to.equal(true)
			expect(math.abs(angle(2)) < 1e-9).to.equal(true)
			expect(math.abs(angle(3) + 40) < 1e-9).to.equal(true)
			expect(math.abs(angle(4)) < 1e-9).to.equal(true)
		end)

		it("tient compte du décalage", function()
			expect(Horaires.angleBalancier(1.5, 40, 4, 1.5)).to.equal(0)
			expect(math.abs(Horaires.angleBalancier(2.5, 40, 4, 1.5) - 40) < 1e-9).to.equal(true)
		end)
	end)

	describe("depuisAttributs", function()
		it("lit une chute valide", function()
			local p = Horaires.depuisAttributs({
				Type = "Chute",
				Periode = 8,
				Decalage = 1,
				Preavis = 1.5,
				Hauteur = 30,
				DureeChute = 0.8,
			})
			expect(p).to.be.ok()
			expect(p.type).to.equal("Chute")
			expect(p.duree).to.equal(0.8)
			expect(p.hauteur).to.equal(30)
			expect(p.periode).to.equal(8)
		end)

		it("refuse un type inconnu, des champs manquants, de mauvais types ou une période trop courte", function()
			expect(Horaires.depuisAttributs({ Type = "Vol", Periode = 8, Decalage = 0, Preavis = 1 })).never.to.be.ok()
			expect(Horaires.depuisAttributs({ Type = "Chute", Periode = 8, Decalage = 0 })).never.to.be.ok()
			local mauvais = { Type = "Chute", Periode = "8", Decalage = 0, Preavis = 1, Hauteur = 30, DureeChute = 1 }
			expect(Horaires.depuisAttributs(mauvais)).never.to.be.ok()
			local trop = { Type = "Chute", Periode = 3, Decalage = 0, Preavis = 2.5, Hauteur = 30, DureeChute = 1 }
			expect(Horaires.depuisAttributs(trop)).never.to.be.ok()
			local sansTrajet = { Type = "Passage", Periode = 8, Decalage = 0, Preavis = 1, DureePassage = 2 }
			expect(Horaires.depuisAttributs(sansTrajet)).never.to.be.ok()
		end)
	end)
end
