-- Les effets du dash et du double saut : le choix de ce qui se joue (et l'animation qui remplace la rotation
-- calculée), les durées, les profils d'angle, et la validation serveur du signalement d'effet (un refus par raison :
-- mauvais type, pas relayable, trop souvent, mort, pas débloquée), avec la cadence telle que le service l'appelle.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local EffetsCapacites = require(ReplicatedStorage.Partage.EffetsCapacites)
	local Reglages = require(ReplicatedStorage.Partage.Reglages)

	local function proche(valeur: number, attendu: number, ecart: number?): boolean
		return math.abs(valeur - attendu) <= (ecart or 1e-9)
	end

	describe("plan : ce qui se joue", function()
		it("dash : penché, traînée, lignes de vitesse et choc d'arrivée, sans vrille ni onde", function()
			local plan = EffetsCapacites.plan("dash", "")
			expect(plan).to.be.ok()
			expect(plan.inclinaison).to.equal(true)
			expect(plan.trainee).to.equal(true)
			expect(plan.lignes).to.equal(true)
			expect(plan.choc).to.equal(true)
			expect(plan.vrille).to.equal(false)
			expect(plan.onde).to.equal(false)
		end)

		it("double saut : vrille, onde de choc et traînée, sans lignes de vitesse ni penché", function()
			local plan = EffetsCapacites.plan("doubleSaut", "")
			expect(plan).to.be.ok()
			expect(plan.vrille).to.equal(true)
			expect(plan.onde).to.equal(true)
			expect(plan.trainee).to.equal(true)
			expect(plan.lignes).to.equal(false)
			expect(plan.choc).to.equal(false)
			expect(plan.inclinaison).to.equal(false)
		end)

		it("la course et un nom inconnu n'ont pas de plan (effet local, pas relayé)", function()
			expect(EffetsCapacites.plan("course", "")).never.to.be.ok()
			expect(EffetsCapacites.plan("teleportation", "")).never.to.be.ok()
		end)

		it("emplacement d'animation vide : la rotation calculée reste", function()
			expect(Reglages.ANIMATION_DASH).to.equal("")
			expect(Reglages.ANIMATION_DOUBLE_SAUT).to.equal("")
			local dash = EffetsCapacites.plan("dash", Reglages.ANIMATION_DASH)
			expect(dash.animation).never.to.be.ok()
			expect(dash.inclinaison).to.equal(true)
			local saut = EffetsCapacites.plan("doubleSaut", Reglages.ANIMATION_DOUBLE_SAUT)
			expect(saut.animation).never.to.be.ok()
			expect(saut.vrille).to.equal(true)
		end)

		it("animation du dash renseignée : elle remplace le penché, le reste ne change pas", function()
			local plan = EffetsCapacites.plan("dash", "rbxassetid://123456")
			expect(plan.animation).to.equal("rbxassetid://123456")
			expect(plan.inclinaison).to.equal(false)
			expect(plan.trainee).to.equal(true)
			expect(plan.lignes).to.equal(true)
			expect(plan.choc).to.equal(true)
		end)

		it("animation du double saut renseignée : elle remplace la vrille, onde et traînée restent", function()
			local plan = EffetsCapacites.plan("doubleSaut", "rbxassetid://987")
			expect(plan.animation).to.equal("rbxassetid://987")
			expect(plan.vrille).to.equal(false)
			expect(plan.onde).to.equal(true)
			expect(plan.trainee).to.equal(true)
		end)

		it("un identifiant d'animation invalide est ignoré (la rotation calculée reste)", function()
			expect(EffetsCapacites.animationValide("")).to.equal(false)
			expect(EffetsCapacites.animationValide("123456")).to.equal(false)
			expect(EffetsCapacites.animationValide("rbxassetid://")).to.equal(false)
			expect(EffetsCapacites.animationValide("rbxassetid://12ab")).to.equal(false)
			expect(EffetsCapacites.animationValide("http://exemple.fr/12")).to.equal(false)
			expect(EffetsCapacites.animationValide(12)).to.equal(false)
			expect(EffetsCapacites.animationValide(nil)).to.equal(false)
			expect(EffetsCapacites.animationValide("rbxassetid://4455667788")).to.equal(true)
			local plan = EffetsCapacites.plan("doubleSaut", "n'importe quoi")
			expect(plan.vrille).to.equal(true)
			expect(plan.animation).never.to.be.ok()
		end)
	end)

	describe("durées", function()
		it("le dash dure DASH_DUREE et la vrille VRILLE_DUREE", function()
			expect(EffetsCapacites.duree("dash")).to.equal(Reglages.DASH_DUREE)
			expect(EffetsCapacites.duree("doubleSaut")).to.equal(Reglages.VRILLE_DUREE)
			expect(EffetsCapacites.duree("course")).to.equal(0)
		end)

		it("la traînée du dash s'efface en DASH_TRAINEE_DUREE, celle de la vrille en VRILLE_TRAINEE_DUREE", function()
			expect(EffetsCapacites.dureeTrainee("dash")).to.equal(Reglages.DASH_TRAINEE_DUREE)
			expect(EffetsCapacites.dureeTrainee("doubleSaut")).to.equal(Reglages.VRILLE_TRAINEE_DUREE)
			expect(Reglages.DASH_TRAINEE_DUREE > 0).to.equal(true)
			expect(Reglages.VRILLE_ONDE_DUREE > 0).to.equal(true)
		end)
	end)

	describe("angles", function()
		it("la vrille fait un tour complet, régulièrement, et reste bornée", function()
			expect(EffetsCapacites.angleVrille(0)).to.equal(0)
			expect(proche(EffetsCapacites.angleVrille(0.5), math.pi)).to.equal(true)
			expect(proche(EffetsCapacites.angleVrille(1), 2 * math.pi)).to.equal(true)
			expect(EffetsCapacites.angleVrille(-3)).to.equal(0)
			expect(proche(EffetsCapacites.angleVrille(9), 2 * math.pi)).to.equal(true)
		end)

		it("le penché part de zéro, atteint le maximum au milieu et revient à zéro", function()
			local maximum = 55
			expect(EffetsCapacites.angleInclinaison(0, maximum)).to.equal(0)
			expect(proche(EffetsCapacites.angleInclinaison(0.5, maximum), math.rad(maximum))).to.equal(true)
			expect(proche(EffetsCapacites.angleInclinaison(1, maximum), 0)).to.equal(true)
		end)

		it("le penché ne dépasse jamais le maximum et reste positif (en avant)", function()
			for i = 0, 40 do
				local angle = EffetsCapacites.angleInclinaison(i / 40, 55)
				expect(angle >= 0).to.equal(true)
				expect(angle <= math.rad(55) + 1e-9).to.equal(true)
			end
			expect(EffetsCapacites.angleInclinaison(-1, 55)).to.equal(0)
			expect(proche(EffetsCapacites.angleInclinaison(5, 55), 0)).to.equal(true)
		end)

		it("le penché monte puis redescend : plus penché à 0,1 qu'à 0,02, et à 0,9 qu'à 0,99", function()
			expect(EffetsCapacites.angleInclinaison(0.1, 55) > EffetsCapacites.angleInclinaison(0.02, 55)).to.equal(
				true
			)
			expect(EffetsCapacites.angleInclinaison(0.9, 55) > EffetsCapacites.angleInclinaison(0.99, 55)).to.equal(
				true
			)
		end)

		it("l'anneau de l'onde grandit jusqu'au rayon demandé en restant une bande fine", function()
			local anneau = EffetsCapacites.anneau(9)
			expect(anneau.rayonFin).to.equal(9)
			expect(anneau.rayonFin > anneau.rayonDepart).to.equal(true)
			expect(anneau.interieurFin < anneau.rayonFin).to.equal(true)
			expect(anneau.interieurDepart < anneau.rayonDepart).to.equal(true)
			-- un rayon absurde reste utilisable
			expect(EffetsCapacites.anneau(0).rayonFin > EffetsCapacites.anneau(0).rayonDepart).to.equal(true)
		end)
	end)

	describe("estReplicable", function()
		it("le dash et le double saut se relaient aux autres joueurs", function()
			expect(EffetsCapacites.estReplicable("dash")).to.equal(true)
			expect(EffetsCapacites.estReplicable("doubleSaut")).to.equal(true)
		end)

		it("la course (effet local) et tout le reste non", function()
			expect(EffetsCapacites.estReplicable("course")).to.equal(false)
			expect(EffetsCapacites.estReplicable("Dash")).to.equal(false)
			expect(EffetsCapacites.estReplicable("")).to.equal(false)
			expect(EffetsCapacites.estReplicable(5)).to.equal(false)
			expect(EffetsCapacites.estReplicable(nil)).to.equal(false)
			expect(EffetsCapacites.estReplicable({ "dash" })).to.equal(false)
		end)

		it("on ne rejoue que les effets des joueurs proches", function()
			expect(EffetsCapacites.assezProche(10, Reglages.EFFET_DISTANCE_MAX)).to.equal(true)
			expect(EffetsCapacites.assezProche(Reglages.EFFET_DISTANCE_MAX, Reglages.EFFET_DISTANCE_MAX)).to.equal(true)
			expect(EffetsCapacites.assezProche(Reglages.EFFET_DISTANCE_MAX + 1, Reglages.EFFET_DISTANCE_MAX)).to.equal(
				false
			)
			expect(EffetsCapacites.assezProche(0 / 0, 100)).to.equal(false)
		end)
	end)

	-- La validation serveur, comme le service l'appelle : une table `derniers` qui vit entre les appels.
	describe("accepter (validation + cadence du signalement d'effet)", function()
		local DELAI = Reglages.EFFET_DELAI_MIN
		local TOUTES = { dash = true, doubleSaut = true, course = true }

		local function entree(modif: { [string]: any }?)
			local e: { [string]: any } = { vivant = true, debloquees = TOUTES }
			for cle, valeur in modif or {} do
				e[cle] = valeur
			end
			return e
		end

		local function traiter(
			derniers: { [string]: number },
			capacite: any,
			instant: number,
			modif: { [string]: any }?
		)
			local ok, pourquoi = EffetsCapacites.accepter(derniers, capacite, instant, DELAI, function()
				return entree(modif)
			end)
			return ok, pourquoi
		end

		it("la cadence est de 0,3 s", function()
			expect(DELAI).to.equal(0.3)
		end)

		it("accepte le premier signalement d'un joueur vivant qui a la capacité", function()
			local derniers = {}
			local ok, pourquoi = traiter(derniers, "dash", 100)
			expect(ok).to.equal(true)
			expect(pourquoi).never.to.be.ok()
		end)

		it("refuse un mauvais type (nombre, table, nil, booléen)", function()
			for _, mauvais in { 12, { "dash" }, true, Vector3.new(1, 2, 3) } do
				local ok, pourquoi = traiter({}, mauvais, 100)
				expect(ok).to.equal(false)
				expect(pourquoi).to.equal("mauvais_type")
			end
			local ok, pourquoi = traiter({}, nil, 100)
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("mauvais_type")
		end)

		it("refuse une capacité qui ne se relaie pas : course, nom inventé, chaîne vide", function()
			for _, nom in { "course", "teleportation", "", "DASH" } do
				local ok, pourquoi = traiter({}, nom, 100)
				expect(ok).to.equal(false)
				expect(pourquoi).to.equal("pas_replicable")
			end
		end)

		it("refuse un second signalement de la même capacité dans le délai (trop souvent)", function()
			local derniers = {}
			expect(traiter(derniers, "dash", 100)).to.equal(true)
			local ok, pourquoi = traiter(derniers, "dash", 100.2)
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("trop_souvent")
		end)

		it("accepte à nouveau une fois le délai écoulé", function()
			local derniers = {}
			expect(traiter(derniers, "dash", 100)).to.equal(true)
			expect(traiter(derniers, "dash", 100.5)).to.equal(true)
		end)

		it("un refus de cadence ne repousse pas l'heure notée (un spam ne verrouille pas le joueur)", function()
			local derniers = {}
			traiter(derniers, "dash", 100)
			traiter(derniers, "dash", 100.1)
			traiter(derniers, "dash", 100.25)
			expect(derniers.dash).to.equal(100)
			expect(traiter(derniers, "dash", 100.31)).to.equal(true)
		end)

		it("un dash puis un double saut en moins de 0,3 s sont tous deux relayés (cadence par capacité)", function()
			local derniers = {}
			expect(traiter(derniers, "dash", 100)).to.equal(true)
			expect(traiter(derniers, "doubleSaut", 100.1)).to.equal(true)
			local ok, pourquoi = traiter(derniers, "doubleSaut", 100.2)
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("trop_souvent")
		end)

		it("refuse un joueur mort", function()
			local ok, pourquoi = traiter({}, "dash", 100, { vivant = false })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("joueur_mort")
		end)

		it("refuse une capacité pas encore débloquée", function()
			local ok, pourquoi = traiter({}, "doubleSaut", 100, { debloquees = { dash = true } })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("pas_debloquee")
			ok, pourquoi = traiter({}, "dash", 100, { debloquees = {} })
			expect(ok).to.equal(false)
			expect(pourquoi).to.equal("pas_debloquee")
		end)

		it(
			"PIÈGE : un message refusé par la validation ne note pas l'heure (le suivant, légitime, passe)",
			function()
				local derniers = {}
				-- le joueur est mort (ou n'a pas la capacité) : refusé, rien n'est noté
				local ok, pourquoi = traiter(derniers, "dash", 100, { vivant = false })
				expect(ok).to.equal(false)
				expect(pourquoi).to.equal("joueur_mort")
				expect(derniers.dash).never.to.be.ok()
				-- 0,1 s plus tard le joueur est revenu : le signalement valide n'est pas pris pour du spam
				ok = traiter(derniers, "dash", 100.1)
				expect(ok).to.equal(true)
				expect(derniers.dash).to.equal(100.1)
			end
		)

		it(
			"n'évalue pas l'entrée tant que le type ou la cadence refusent (les rafales sont écartées avant)",
			function()
				local derniers = {}
				traiter(derniers, "dash", 100)
				local appels = 0
				local function compte()
					appels += 1
					return entree()
				end
				EffetsCapacites.accepter(derniers, "dash", 100.1, DELAI, compte)
				EffetsCapacites.accepter(derniers, 12, 100.5, DELAI, compte)
				EffetsCapacites.accepter(derniers, "course", 100.5, DELAI, compte)
				expect(appels).to.equal(0)
			end
		)

		it("une capacité valide hors cadence n'est pas bloquée par un autre joueur (tables séparées)", function()
			local a, b = {}, {}
			expect(traiter(a, "dash", 100)).to.equal(true)
			expect(traiter(b, "dash", 100.05)).to.equal(true)
		end)
	end)
end
