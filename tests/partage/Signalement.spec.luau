-- La validation serveur d'un « j'ai été touché » : un refus par raison (mauvais type, pas un événement, attributs
-- invalides, joueur mort, danger pas actif, trop loin, trop souvent) et le cas accepté.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Signalement = require(ReplicatedStorage.Partage.Signalement)

	-- Une chute : période 10 s, danger de 2 s à partir de t = 2 (donc actif pour t de 2 à 4, 12 à 14...), 20 studs de
	-- haut, posée en (0, 5, 0). Son trajet va donc de (0, 5, 0) à (0, 25, 0).
	local ATTRIBUTS_CHUTE = {
		Type = "Chute",
		Periode = 10,
		Decalage = 2,
		Preavis = 1.5,
		DureeChute = 2,
		Hauteur = 20,
	}
	-- Un passage de (0, 5, 0) à (100, 5, 0), même cycle.
	local ATTRIBUTS_PASSAGE = {
		Type = "Passage",
		Periode = 10,
		Decalage = 2,
		Preavis = 1.5,
		DureePassage = 2,
		Depart = Vector3.new(0, 5, 0),
		Arrivee = Vector3.new(100, 5, 0),
	}

	-- Une entrée valide : joueur vivant au pied de la chute, danger actif, premier signalement.
	local function entree(modif: { [string]: any }?)
		local e: { [string]: any } = {
			instant = 100,
			dernierSignalement = nil,
			delaiMin = 0.5,
			objetValide = true,
			avecTag = true,
			attributs = ATTRIBUTS_CHUTE,
			heureServeur = 3, -- danger actif (phase 1 sur 2 s)
			tolerance = 1,
			vivant = true,
			position = Vector3.new(5, 6, 0),
			posee = Vector3.new(0, 5, 0),
			demiTaille = 2,
			distanceMax = 40,
		}
		for cle, valeur in modif or {} do
			e[cle] = valeur
		end
		if e.position == false then
			e.position = nil -- « pas de personnage »
		end
		return e
	end

	local function raison(modif: { [string]: any }?)
		local ok, pourquoi = Signalement.valider(entree(modif))
		return ok, pourquoi
	end

	it("accepte un joueur vivant, près de la trajectoire, pendant le danger", function()
		local ok, pourquoi = raison()
		expect(ok).to.equal(true)
		expect(pourquoi).never.to.be.ok()
	end)

	it("accepte aussi un passage, en n'importe quel point de son segment", function()
		local ok =
			raison({ attributs = ATTRIBUTS_PASSAGE, posee = Vector3.new(0, 5, 0), position = Vector3.new(80, 6, 0) })
		expect(ok).to.equal(true)
	end)

	it("refuse un objet qui n'est pas une Instance de la carte (mauvais type)", function()
		local ok, pourquoi = raison({ objetValide = false })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("objet_invalide")
	end)

	it("refuse un objet sans le tag Evenement", function()
		local ok, pourquoi = raison({ avecTag = false })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("pas_un_evenement")
	end)

	it("refuse un objet aux attributs invalides", function()
		local ok, pourquoi = raison({ attributs = { Type = "Chute", Periode = 10 } })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("attributs_invalides")
		ok, pourquoi = raison({ attributs = { Type = "Tornade" } })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("attributs_invalides")
	end)

	it("refuse un joueur mort ou sans personnage", function()
		local ok, pourquoi = raison({ vivant = false })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("joueur_mort")
		ok, pourquoi = raison({ position = false })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("joueur_mort")
	end)

	it("refuse quand le danger n'est pas actif, même à la tolérance près", function()
		-- t = 8 : phase 6, en pleine attente (fin du danger à 4, plus la tolérance de 1 s : 5).
		local ok, pourquoi = raison({ heureServeur = 8 })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("danger_inactif")
	end)

	it("accepte juste hors de la fenêtre si c'est dans la tolérance réseau", function()
		-- t = 4,5 : le danger a fini il y a 0,5 s ; t = 1,5 : il commence dans 0,5 s.
		local ok = raison({ heureServeur = 4.5 })
		expect(ok).to.equal(true)
		ok = raison({ heureServeur = 1.5 })
		expect(ok).to.equal(true)
		local refus = raison({ heureServeur = 5.5 })
		expect(refus).to.equal(false)
	end)

	it("refuse un joueur trop loin de la trajectoire", function()
		-- Distance max 40 + demi-taille 2 : à 100 studs de la chute, c'est trop loin.
		local ok, pourquoi = raison({ position = Vector3.new(100, 6, 0) })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("trop_loin")
	end)

	it("mesure la distance au segment du passage, pas à son point de départ", function()
		-- À 80 studs du départ mais sur le trajet : accepté ; à 30 studs au-dessus du trajet : au-delà de 42.
		local passage = { attributs = ATTRIBUTS_PASSAGE, posee = Vector3.new(0, 5, 0) }
		local ok = raison({
			attributs = passage.attributs,
			posee = passage.posee,
			position = Vector3.new(80, 6, 0),
			distanceMax = 10,
			demiTaille = 0,
		})
		expect(ok).to.equal(true)
		local refus, pourquoi = raison({
			attributs = passage.attributs,
			posee = passage.posee,
			position = Vector3.new(80, 36, 0),
			distanceMax = 10,
			demiTaille = 0,
		})
		expect(refus).to.equal(false)
		expect(pourquoi).to.equal("trop_loin")
	end)

	it("refuse un signalement trop rapproché du précédent", function()
		local ok, pourquoi = raison({ dernierSignalement = 99.8 })
		expect(ok).to.equal(false)
		expect(pourquoi).to.equal("trop_souvent")
	end)

	it("accepte un signalement assez espacé du précédent", function()
		local ok = raison({ dernierSignalement = 99 })
		expect(ok).to.equal(true)
	end)

	it("tropSouvent ne refuse jamais le premier signalement", function()
		expect(Signalement.tropSouvent(0, nil, 0.5)).to.equal(false)
		expect(Signalement.tropSouvent(1, 0.6, 0.5)).to.equal(true)
		expect(Signalement.tropSouvent(1, 0.5, 0.5)).to.equal(false)
	end)
end
