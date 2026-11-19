-- Le mode vol des testeurs : qui peut voler (le cas « hors liste » protège le jeu), la bascule, la cadence, le refus d'un
-- joueur mort, et le calcul de la vitesse. Le code et les tests passent par les MÊMES fonctions et la MÊME liste :
-- `Reglages.TESTEURS`, celle du jeu, jamais une copie construite à part (une liste abîmée doit faire échouer un test).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Reglages = require(ReplicatedStorage.Partage.Reglages)
	local Vol = require(ReplicatedStorage.Partage.Vol)

	local VIVANT = function()
		return { vivant = true, pret = true }
	end
	local MORT = function()
		return { vivant = false, pret = true }
	end
	local SANS_DONNEES = function()
		return { vivant = true, pret = false }
	end

	--- Un identifiant qui n'est PAS dans la liste du jeu, quelle que soit la liste (on la complètera avec des testeurs).
	local function identifiantAbsent(): number
		local plusGrand = 0
		for identifiant in Reglages.TESTEURS do
			plusGrand = math.max(plusGrand, identifiant)
		end
		return plusGrand + 1
	end

	local function proche(valeur: number, attendu: number): boolean
		return math.abs(valeur - attendu) < 1e-6
	end

	describe("la liste des testeurs du jeu (Reglages.TESTEURS)", function()
		it("est bien formée : { [identifiant entier] = true }", function()
			expect(Vol.listeValide(Reglages.TESTEURS)).to.equal(true)
		end)

		it(
			"le contrôle refuse une liste abîmée (nombres en vrac, faux, texte, identifiant décimal ou nul)",
			function()
				expect(Vol.listeValide({ 123, 456 })).to.equal(false)
				expect(Vol.listeValide({ [42] = false })).to.equal(false)
				expect(Vol.listeValide({ ["42"] = true })).to.equal(false)
				expect(Vol.listeValide({ [4.5] = true })).to.equal(false)
				expect(Vol.listeValide({ [0] = true })).to.equal(false)
				expect(Vol.listeValide("liste")).to.equal(false)
				expect(Vol.listeValide({ [42] = true })).to.equal(true)
			end
		)
	end)

	describe("estTesteur : hors liste, rien ne se passe", function()
		it("un identifiant absent de la liste du jeu ne vole pas", function()
			expect(Vol.estTesteur(Reglages.TESTEURS, identifiantAbsent())).to.equal(false)
		end)

		it("un identifiant listé vole", function()
			expect(Vol.estTesteur({ [42] = true }, 42)).to.equal(true)
		end)

		it("une entrée à false ne vole pas", function()
			expect(Vol.estTesteur({ [42] = false }, 42)).to.equal(false)
		end)

		it("mauvais type, NaN, nul, décimal, liste absente : jamais testeur", function()
			local liste = { [42] = true, [0] = true }
			expect(Vol.estTesteur(liste, "42")).to.equal(false)
			expect(Vol.estTesteur(liste, nil)).to.equal(false)
			expect(Vol.estTesteur(liste, 0 / 0)).to.equal(false)
			expect(Vol.estTesteur(liste, 0)).to.equal(false)
			expect(Vol.estTesteur(liste, 42.5)).to.equal(false)
			expect(Vol.estTesteur(liste, {})).to.equal(false)
			expect(Vol.estTesteur(nil, 42)).to.equal(false)
		end)
	end)

	describe("decider : la demande du client, jugée par le serveur", function()
		it("hors liste : refusée, avec la liste du jeu, même répétée en boucle", function()
			local derniers = {}
			local id = identifiantAbsent()
			for i = 1, 200 do
				local nouvel, raison =
					Vol.decider(Reglages.TESTEURS, derniers, "joueur", id, i * 0.01, 0.5, false, VIVANT)
				expect(nouvel).never.to.be.ok()
				expect(raison).to.equal("pas_testeur")
			end
			expect(next(derniers)).never.to.be.ok() -- rien n'est mémorisé pour un joueur hors liste
		end)

		it("hors liste : le personnage n'est même pas interrogé", function()
			local interroge = false
			Vol.decider(Reglages.TESTEURS, {}, "j", identifiantAbsent(), 0, 0.5, false, function()
				interroge = true
				return { vivant = true, pret = true }
			end)
			expect(interroge).to.equal(false)
		end)

		it("un testeur vivant qui ne vole pas : le vol s'active", function()
			local nouvel, raison = Vol.decider({ [42] = true }, {}, "j", 42, 10, 0.5, false, VIVANT)
			expect(nouvel).to.equal(true)
			expect(raison).never.to.be.ok()
		end)

		it("la bascule : un testeur qui vole et redemande cesse de voler", function()
			local derniers = {}
			local liste = { [42] = true }
			local nouvel = Vol.decider(liste, derniers, "j", 42, 10, 0.5, false, VIVANT)
			expect(nouvel).to.equal(true)
			nouvel = Vol.decider(liste, derniers, "j", 42, 11, 0.5, true, VIVANT)
			expect(nouvel).to.equal(false)
			expect(Vol.basculer(true)).to.equal(false)
			expect(Vol.basculer(false)).to.equal(true)
		end)

		it("trop souvent : une seconde demande dans le délai est refusée, sans repousser la suivante", function()
			local derniers = {}
			local liste = { [42] = true }
			expect(Vol.decider(liste, derniers, "j", 42, 10, 0.5, false, VIVANT)).to.equal(true)
			local nouvel, raison = Vol.decider(liste, derniers, "j", 42, 10.2, 0.5, true, VIVANT)
			expect(nouvel).never.to.be.ok()
			expect(raison).to.equal("trop_souvent")
			expect(Vol.decider(liste, derniers, "j", 42, 10.6, 0.5, true, VIVANT)).to.equal(false)
		end)

		it("joueur mort : il ne peut pas entrer en vol, et l'heure n'est pas notée", function()
			local derniers = {}
			local liste = { [42] = true }
			local nouvel, raison = Vol.decider(liste, derniers, "j", 42, 10, 0.5, false, MORT)
			expect(nouvel).never.to.be.ok()
			expect(raison).to.equal("joueur_mort")
			expect(Vol.decider(liste, derniers, "j", 42, 10.1, 0.5, false, VIVANT)).to.equal(true)
		end)

		it("données pas chargées : pas de vol (sa course ne serait pas suivie)", function()
			local nouvel, raison = Vol.decider({ [42] = true }, {}, "j", 42, 10, 0.5, false, SANS_DONNEES)
			expect(nouvel).never.to.be.ok()
			expect(raison).to.equal("donnees_absentes")
		end)

		it("sortir du vol est toujours permis, même sans personnage vivant", function()
			expect(Vol.decider({ [42] = true }, {}, "j", 42, 10, 0.5, true, MORT)).to.equal(false)
		end)

		it("chaque joueur a sa cadence", function()
			local derniers = {}
			local liste = { [42] = true, [43] = true }
			expect(Vol.decider(liste, derniers, "a", 42, 10, 0.5, false, VIVANT)).to.equal(true)
			expect(Vol.decider(liste, derniers, "b", 43, 10.1, 0.5, false, VIVANT)).to.equal(true)
		end)

		it("le délai du jeu est un nombre positif", function()
			expect(typeof(Reglages.VOL_DELAI_MIN)).to.equal("number")
			expect(Reglages.VOL_DELAI_MIN > 0).to.equal(true)
		end)
	end)

	describe("vitesse : trois dimensions, direction regardée", function()
		local V = Reglages.VOL_VITESSE

		it("aucune touche : immobile", function()
			local v = Vol.vitesse(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 0, V)
			expect(proche(v.Magnitude, 0)).to.equal(true)
		end)

		it("avancer en regardant droit devant : à plat, à la vitesse du vol", function()
			local v = Vol.vitesse(Vector3.new(0, 0, -1), Vector3.new(0, 0, -1), 0, V)
			expect(proche(v.Z, -V)).to.equal(true)
			expect(proche(v.Y, 0)).to.equal(true)
		end)

		it("avancer en regardant à 45 degrés vers le haut : on monte", function()
			local regard = Vector3.new(0, 1, -1).Unit
			local v = Vol.vitesse(Vector3.new(0, 0, -1), regard, 0, V)
			expect(proche(v.Y, V * math.sqrt(0.5))).to.equal(true)
			expect(proche(v.Z, -V * math.sqrt(0.5))).to.equal(true)
		end)

		it("avancer en regardant vers le bas : on descend", function()
			local regard = Vector3.new(0, -1, -1).Unit
			local v = Vol.vitesse(Vector3.new(0, 0, -1), regard, 0, V)
			expect(v.Y < 0).to.equal(true)
		end)

		it("pas de côté : à plat, à droite de la caméra", function()
			local v = Vol.vitesse(Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), 0, V)
			expect(proche(v.X, V)).to.equal(true)
			expect(proche(v.Y, 0)).to.equal(true)
		end)

		it("Espace monte, Ctrl descend, sans toucher au plan", function()
			local haut = Vol.vitesse(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 1, V)
			local bas = Vol.vitesse(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), -1, V)
			expect(proche(haut.Y, V)).to.equal(true)
			expect(proche(bas.Y, -V)).to.equal(true)
		end)

		it("jamais plus vite que la vitesse du vol, même en diagonale", function()
			local regard = Vector3.new(0, 1, -1).Unit
			local v = Vol.vitesse(Vector3.new(1, 0, -1).Unit, regard, 1, V)
			expect(v.Magnitude <= V + 1e-6).to.equal(true)
		end)

		it("regard à la verticale : pas de division par zéro", function()
			local v = Vol.vitesse(Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), 0, V)
			expect(v.Magnitude <= V + 1e-6).to.equal(true)
		end)
	end)
end
