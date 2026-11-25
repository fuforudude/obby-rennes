-- Les règles des sons : quelle musique où, la hauteur du son de checkpoint, arrivée ou record, et la forme des
-- catalogues (chaque action a un identifiant).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Etapes = require(ReplicatedStorage.Partage.Etapes)
	local Reglages = require(ReplicatedStorage.Partage.Reglages)
	local Sons = require(ReplicatedStorage.Partage.Sons)

	local NB = Reglages.NB_ETAPES
	local MAX = Reglages.AURA_SERIE_MAX

	local function proche(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("musique", function()
		it("chaque zone du parcours a une musique du catalogue", function()
			for numero = 0, Etapes.nombre() - 1 do
				local nom = Sons.musique(numero, false)
				expect(nom).to.be.ok()
				expect(Sons.MUSIQUES[nom]).to.be.ok()
			end
		end)

		it("la tour a la sienne, quelle que soit l'étape, différente de celles du parcours", function()
			expect(Sons.musique(NB, true)).to.equal("tour")
			expect(Sons.musique(0, true)).to.equal("tour")
			expect(Sons.MUSIQUES.tour).to.be.ok()
			for numero = 0, NB do
				expect(Sons.musique(numero, false) == "tour").to.equal(false)
			end
		end)

		it("rejouer la même étape donne la même musique (réapparaître ne relance rien)", function()
			expect(Sons.musique(7, false)).to.equal(Sons.musique(7, false))
		end)

		it("change au moins une fois le long du parcours", function()
			expect(Sons.musique(0, false) == Sons.musique(8, false)).to.equal(false)
			expect(Sons.musique(8, false) == Sons.musique(14, false)).to.equal(false)
		end)

		it("pas de musique tant que l'étape est inconnue", function()
			expect(Sons.musique(nil, false)).never.to.be.ok()
			expect(Sons.musique(-1, false)).never.to.be.ok()
		end)

		it("le fondu dure 1,5 s", function()
			expect(Sons.FONDU).to.equal(1.5)
		end)
	end)

	describe("son du checkpoint", function()
		it("le premier de la série est à la hauteur normale", function()
			expect(Sons.vitesseCheckpoint(1, MAX)).to.equal(1)
		end)

		it("monte d'un ton (deux demi-tons) à chaque checkpoint de la série", function()
			for serie = 2, MAX do
				local rapport = Sons.vitesseCheckpoint(serie, MAX) / Sons.vitesseCheckpoint(serie - 1, MAX)
				expect(proche(rapport, 2 ^ (2 / 12))).to.equal(true)
			end
		end)

		it("ne monte plus après ×10", function()
			expect(Sons.vitesseCheckpoint(MAX + 1, MAX)).to.equal(Sons.vitesseCheckpoint(MAX, MAX))
			expect(Sons.vitesseCheckpoint(15, MAX)).to.equal(Sons.vitesseCheckpoint(10, MAX))
		end)

		it("redescend après une chute (série remise à zéro)", function()
			expect(Sons.vitesseCheckpoint(0, MAX)).to.equal(1)
		end)

		it("joue quand l'étape avance", function()
			expect(Sons.joueCheckpoint(3, 4, NB)).to.equal(true)
		end)

		it("ne joue pas à la première réception, à étape égale (chute, aura) ni quand on recommence", function()
			expect(Sons.joueCheckpoint(nil, 4, NB)).to.equal(false)
			expect(Sons.joueCheckpoint(4, 4, NB)).to.equal(false)
			expect(Sons.joueCheckpoint(4, 0, NB)).to.equal(false)
		end)

		it("ne joue pas à l'arrivée : seul le son d'arrivée ou de record joue", function()
			expect(Sons.joueCheckpoint(NB - 1, NB, NB)).to.equal(false)
		end)
	end)

	describe("arrivée ou record", function()
		it("sans record, le son d'arrivée", function()
			expect(Sons.arrivee(false)).to.equal("arrivee")
		end)

		it("avec record, seul le son de record", function()
			expect(Sons.arrivee(true)).to.equal("record")
		end)
	end)

	describe("sommet de la tour", function()
		local EN_COURS = { recordSommet = nil }
		local ARRIVE = { recordSommet = false }
		local RECORD = { recordSommet = true }

		it("au sommet, le son de record si le temps est battu, sinon celui d'arrivée", function()
			expect(Sons.sommet(EN_COURS, RECORD)).to.equal("record")
			expect(Sons.sommet(EN_COURS, ARRIVE)).to.equal("arrivee")
		end)

		it("une seule fois par montée : les états répétés ne rejouent rien", function()
			expect(Sons.sommet(RECORD, RECORD)).never.to.be.ok()
			expect(Sons.sommet(ARRIVE, ARRIVE)).never.to.be.ok()
		end)

		it("rien pendant la montée, ni en repartant du pied", function()
			expect(Sons.sommet(EN_COURS, EN_COURS)).never.to.be.ok()
			expect(Sons.sommet(RECORD, EN_COURS)).never.to.be.ok()
		end)

		it("la montée suivante joue de nouveau", function()
			expect(Sons.sommet(RECORD, EN_COURS)).never.to.be.ok()
			expect(Sons.sommet(EN_COURS, ARRIVE)).to.equal("arrivee")
		end)

		it("un premier message reçu déjà au sommet (file, rappel) ne joue rien", function()
			expect(Sons.sommet(nil, RECORD)).never.to.be.ok()
			expect(Sons.sommet(nil, ARRIVE)).never.to.be.ok()
			expect(Sons.sommet(nil, EN_COURS)).never.to.be.ok()
		end)
	end)

	describe("catalogues", function()
		it("chaque action a son effet, et deux actions n'ont pas le même son", function()
			local vus = {}
			for _, nom in { "saut", "doubleSaut", "dash", "checkpoint", "mort", "capacite", "arrivee", "record" } do
				local son = Sons.EFFETS[nom]
				expect(son).to.be.ok()
				expect(son.id == "").to.equal(false)
				expect(vus[son.id]).never.to.be.ok()
				vus[son.id] = nom
			end
		end)

		it("identifiants non vides et bien formés, volumes entre 0 et 1, musique plus douce que 0,5", function()
			for _, catalogue in { Sons.EFFETS, Sons.MUSIQUES } do
				for _, son in catalogue do
					local forme = string.match(son.id, "^rbxassetid://%d+$") ~= nil
						or string.match(son.id, "^rbxasset://sounds/[%w_]+%.%w+$") ~= nil
					expect(forme).to.equal(true)
					expect(son.volume > 0 and son.volume <= 1).to.equal(true)
				end
			end
			for _, son in Sons.MUSIQUES do
				expect(son.volume < 0.5).to.equal(true)
			end
		end)
	end)
end
