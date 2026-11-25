-- Les règles des mesures : numéros de l'entonnoir « première partie », une étape envoyée une fois, morts regroupées.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Mesures = require(ReplicatedStorage.Partage.Mesures)
	local Regles = require(ReplicatedStorage.Partage.Regles)

	local NB = 15

	describe("entonnoir", function()
		it("arrivée en jeu, checkpoints 1 à 15, pied puis sommet : 18 étapes qui se suivent", function()
			expect(Mesures.ARRIVEE_EN_JEU).to.equal(1)
			for numero = 1, NB do
				expect(Mesures.etapeCheckpoint(numero)).to.equal(numero + 1)
			end
			expect(Mesures.etapePied(NB)).to.equal(17)
			expect(Mesures.etapeSommet(NB)).to.equal(18)
		end)

		it("une étape n'est envoyée qu'une fois par joueur et par session (« Recommencer » compris)", function()
			local suivi = Mesures.nouveauSuivi()
			expect(Mesures.franchir(suivi, 2)).to.equal(true)
			expect(Mesures.franchir(suivi, 3)).to.equal(true)
			expect(Mesures.franchir(suivi, 2)).to.equal(false)
			expect(Mesures.franchir(suivi, 3)).to.equal(false)
		end)

		it("deux joueurs ont chacun leur suivi", function()
			Mesures.franchir(Mesures.nouveauSuivi(), 2)
			expect(Mesures.franchir(Mesures.nouveauSuivi(), 2)).to.equal(true)
		end)
	end)

	describe("joueur déjà avancé", function()
		local function donnees(champs: { [string]: any })
			local d = Regles.donneesNeuves() :: any
			for nom, valeur in champs do
				d[nom] = valeur
			end
			return d
		end

		it("un joueur neuf n'a que l'arrivée en jeu", function()
			expect(Mesures.dejaAtteinte(donnees({}), NB)).to.equal(1)
		end)

		it("un joueur au checkpoint 8 reprend à l'étape du checkpoint 8", function()
			expect(Mesures.dejaAtteinte(donnees({ etape = 8 }), NB)).to.equal(Mesures.etapeCheckpoint(8))
		end)

		it("un joueur qui a fini puis recommencé reste à l'arrivée du parcours", function()
			expect(Mesures.dejaAtteinte(donnees({ etape = 0, tutoFini = true }), NB)).to.equal(
				Mesures.etapeCheckpoint(NB)
			)
		end)

		it("la tour déjà montée ou finie compte", function()
			expect(Mesures.dejaAtteinte(donnees({ tutoFini = true, meilleureHauteur = 40 }), NB)).to.equal(17)
			expect(
				Mesures.dejaAtteinte(
					donnees({ tutoFini = true, meilleureHauteur = 258, meilleurTempsAscension = 60 }),
					NB
				)
			).to.equal(18)
		end)

		it("ne modifie jamais la sauvegarde", function()
			local d = donnees({ etape = 8, aura = 12 })
			Mesures.dejaAtteinte(d, NB)
			expect(d.etape).to.equal(8)
			expect(d.aura).to.equal(12)
			expect(d.tutoFini).to.equal(false)
		end)
	end)

	describe("morts regroupées", function()
		it("rien n'est envoyé tant que le joueur meurt à la même étape", function()
			local suivi = Mesures.nouveauSuivi()
			for _ = 1, 50 do
				expect(Mesures.mort(suivi, 3)).never.to.be.ok()
			end
		end)

		it("un seul envoi, avec le total, quand il passe à l'étape suivante", function()
			local suivi = Mesures.nouveauSuivi()
			Mesures.mort(suivi, 3)
			Mesures.mort(suivi, 3)
			local envoi = Mesures.changerEtape(suivi, 4)
			expect(envoi.etape).to.equal(3)
			expect(envoi.morts).to.equal(2)
			expect(Mesures.changerEtape(suivi, 5)).never.to.be.ok()
			expect(Mesures.partir(suivi)).never.to.be.ok()
		end)

		it("aucun envoi sans mort", function()
			local suivi = Mesures.nouveauSuivi()
			expect(Mesures.changerEtape(suivi, 1)).never.to.be.ok()
			expect(Mesures.changerEtape(suivi, 2)).never.to.be.ok()
			expect(Mesures.partir(suivi)).never.to.be.ok()
		end)

		it("le reste part au départ du joueur, une seule fois", function()
			local suivi = Mesures.nouveauSuivi()
			Mesures.mort(suivi, 6)
			local envoi = Mesures.partir(suivi)
			expect(envoi.etape).to.equal(6)
			expect(envoi.morts).to.equal(1)
			expect(Mesures.partir(suivi)).never.to.be.ok()
		end)

		it("mourir à une autre étape (Recommencer, étape achetée) solde la précédente", function()
			local suivi = Mesures.nouveauSuivi()
			Mesures.mort(suivi, 5)
			local envoi = Mesures.mort(suivi, 0)
			expect(envoi.etape).to.equal(5)
			expect(envoi.morts).to.equal(1)
			expect(Mesures.partir(suivi).etape).to.equal(0)
		end)

		it("au plus un envoi par étape, même en recommençant dix fois, plus un au départ", function()
			local suivi = Mesures.nouveauSuivi()
			local envois: { [number]: number } = {}
			local function noter(envoi)
				if envoi then
					envois[envoi.etape] = (envois[envoi.etape] or 0) + 1
				end
			end
			for _ = 1, 10 do
				for etape = 0, NB - 1 do
					noter(Mesures.mort(suivi, etape))
					noter(Mesures.mort(suivi, etape))
					noter(Mesures.changerEtape(suivi, etape + 1))
				end
			end
			for etape = 0, NB - 1 do
				expect(envois[etape]).to.equal(1)
			end
			Mesures.mort(suivi, 2)
			expect(Mesures.partir(suivi).etape).to.equal(2)
		end)
	end)

	describe("qui est mesuré", function()
		local TESTEURS = { [42] = true, [43] = false } :: { [number]: boolean }

		it("un joueur à pied, hors liste, est mesuré", function()
			expect(Mesures.estMesure(TESTEURS, 7, false)).to.equal(true)
			expect(Mesures.estMesure({}, 42, false)).to.equal(true)
		end)

		it("un testeur ne l'est jamais, même à pied : son étape a pu être atteinte en vol", function()
			expect(Mesures.estMesure(TESTEURS, 42, false)).to.equal(false)
			expect(Mesures.estMesure(TESTEURS, 42, true)).to.equal(false)
		end)

		it("une partie où l'on a volé ne l'est jamais, même hors liste", function()
			expect(Mesures.estMesure(TESTEURS, 7, true)).to.equal(false)
		end)

		it("une entrée à false dans la liste n'est pas un testeur", function()
			expect(Mesures.estMesure(TESTEURS, 43, false)).to.equal(true)
		end)
	end)

	describe("libellés", function()
		it("l'étape d'une mort s'écrit sur deux chiffres, sans rien d'autre", function()
			expect(Mesures.libelleEtape(3)).to.equal("Etape 03")
			expect(Mesures.libelleEtape(14)).to.equal("Etape 14")
		end)
	end)
end
