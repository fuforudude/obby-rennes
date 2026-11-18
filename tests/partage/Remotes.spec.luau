-- La forme des charges envoyées par les remotes serveur -> client. C'est un contrat : un champ oublié ne casse
-- aucun test de règle, mais rend une information invisible côté client (c'est comme ça que `capacites` avait
-- disparu d'EtatCourse, laissant un joueur de retour avec des capacités sauvegardées mais inutilisables).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Remotes = require(ReplicatedStorage.Partage.Remotes)

	local DONNEES = { etape = 4, meilleurTemps = 93.5, aura = 1200 }
	local COURSE = { debut = 10.25, passages = 1, reprise = true, serie = 3 }
	local ARRETEE = { debut = nil, passages = 0, reprise = false, serie = 0 }

	--- Les noms des champs présents dans la table, triés : de quoi comparer une forme à un contrat.
	local function champs(valeur: { [string]: any }): string
		local noms = {}
		for nom in valeur do
			table.insert(noms, nom)
		end
		table.sort(noms)
		return table.concat(noms, ",")
	end

	describe("etatCourse", function()
		it("porte les huit champs du contrat EtatCourse, et rien d'autre", function()
			expect(champs(Remotes.etatCourse(DONNEES, COURSE, {}))).to.equal(
				"aura,capacites,debut,etape,meilleurTemps,passages,reprise,serie"
			)
		end)

		it("recopie l'étape, le meilleur temps et l'aura des données du joueur", function()
			local etat = Remotes.etatCourse(DONNEES, COURSE, {})
			expect(etat.etape).to.equal(4)
			expect(etat.meilleurTemps).to.equal(93.5)
			expect(etat.aura).to.equal(1200)
		end)

		it("recopie le chrono, les passages, la reprise et la série de la course", function()
			local etat = Remotes.etatCourse(DONNEES, COURSE, {})
			expect(etat.debut).to.equal(10.25)
			expect(etat.passages).to.equal(1)
			expect(etat.reprise).to.equal(true)
			expect(etat.serie).to.equal(3)
		end)

		it(
			"porte les capacités débloquées, dans une copie (le client ne reçoit pas la table du serveur)",
			function()
				local debloquees = { course = true, doubleSaut = true }
				local etat = Remotes.etatCourse(DONNEES, COURSE, debloquees)
				expect(etat.capacites.course).to.equal(true)
				expect(etat.capacites.doubleSaut).to.equal(true)
				expect(etat.capacites == debloquees).to.equal(false)
			end
		)

		it("ne recopie que les capacités vraiment débloquées", function()
			local etat = Remotes.etatCourse(DONNEES, COURSE, { course = true, dash = false, vol = true })
			expect(etat.capacites.course).to.equal(true)
			expect(etat.capacites.dash).to.equal(nil)
			expect(etat.capacites.vol).to.equal(nil) -- un nom inconnu n'arrive jamais au client
		end)

		it("rend une table capacites vide, jamais nil, sans capacité ni données chargées", function()
			expect(typeof(Remotes.etatCourse(DONNEES, COURSE, nil).capacites)).to.equal("table")
			expect(champs(Remotes.etatCourse(DONNEES, COURSE, nil).capacites)).to.equal("")
			expect(typeof(Remotes.etatCourse(DONNEES, COURSE, 12 :: any).capacites)).to.equal("table")
		end)

		it("chrono arrêté (debut nil) : les sept autres champs du contrat sont là", function()
			local etat = Remotes.etatCourse(DONNEES, ARRETEE, {})
			expect(champs(etat)).to.equal("aura,capacites,etape,meilleurTemps,passages,reprise,serie")
			expect(etat.reprise).to.equal(false) -- false, pas absent
		end)
	end)
end
