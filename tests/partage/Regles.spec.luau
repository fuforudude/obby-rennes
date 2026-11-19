-- Règles du parcours : validation des checkpoints, classement, records, temps, données sauvegardées, achats.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Regles = require(ReplicatedStorage.Partage.Regles)

	describe("un checkpoint ne compte que s'il est le suivant", function()
		it("valide le checkpoint suivant", function()
			expect(Regles.peutValider(3, 4, 15)).to.equal(true)
		end)
		it("ignore un checkpoint déjà atteint", function()
			expect(Regles.peutValider(5, 5, 15)).to.equal(false)
			expect(Regles.peutValider(5, 2, 15)).to.equal(false)
		end)
		it("refuse de sauter des étapes en coupant", function()
			expect(Regles.peutValider(3, 6, 15)).to.equal(false)
		end)
		it("refuse un checkpoint au-delà de l'arrivée", function()
			expect(Regles.peutValider(15, 16, 15)).to.equal(false)
		end)
	end)

	describe("le classement ne retient que les parcours d'une traite", function()
		it("classe une course complète sans passage", function()
			expect(Regles.estClassable(Regles.nouvelleCourse(100), 200, 45)).to.equal(true)
		end)
		it("ne classe pas une course avec une étape passée en payant", function()
			local course = Regles.nouvelleCourse(100)
			course.passages = 1
			expect(Regles.estClassable(course, 200, 45)).to.equal(false)
		end)
		it("ne classe pas une course reprise d'une ancienne session", function()
			expect(Regles.estClassable(Regles.courseReprise(100), 200, 45)).to.equal(false)
		end)
		it("ne classe pas un temps impossible (trop rapide)", function()
			expect(Regles.estClassable(Regles.nouvelleCourse(100), 20, 45)).to.equal(false)
		end)
		it("ne classe pas une course où le joueur a volé (mode testeur)", function()
			local course = Regles.nouvelleCourse(100)
			course.vol = true
			expect(Regles.estClassable(course, 200, 45)).to.equal(false)
		end)
		it("« Recommencer » rend la course classable : la course neuve n'a pas volé", function()
			local volee = Regles.nouvelleCourse(100)
			volee.vol = true
			local neuve = Regles.nouvelleCourse(500)
			expect(neuve.vol).to.equal(false)
			expect(Regles.estClassable(neuve, 200, 45)).to.equal(true)
			expect(Regles.courseReprise(500).vol).to.equal(false)
		end)
	end)

	describe("l'aura d'une course où l'on a volé", function()
		it("compte tant que le joueur n'a pas volé", function()
			expect(Regles.auraCompte(Regles.nouvelleCourse(0))).to.equal(true)
		end)
		it("ne compte plus après un vol : ni gain ni perte, rien ne part au classement de l'aura", function()
			local course = Regles.nouvelleCourse(0)
			course.vol = true
			expect(Regles.auraCompte(course)).to.equal(false)
		end)
	end)

	describe("records", function()
		it("le premier temps est un record", function()
			expect(Regles.estRecord(0, 180)).to.equal(true)
		end)
		it("un temps plus rapide bat le record, un plus lent non", function()
			expect(Regles.estRecord(180, 170)).to.equal(true)
			expect(Regles.estRecord(180, 190)).to.equal(false)
		end)
	end)

	describe("affichage des temps", function()
		it("formate minutes, secondes et centièmes", function()
			expect(Regles.formaterTemps(247.25)).to.equal("4:07.25")
			expect(Regles.formaterTemps(0)).to.equal("0:00.00")
			expect(Regles.formaterTemps(59.999)).to.equal("1:00.00")
		end)
		it("convertit en millisecondes entières pour le classement", function()
			expect(Regles.versMillisecondes(12.3456)).to.equal(12346)
		end)
	end)

	describe("données sauvegardées", function()
		it("des données absentes donnent un joueur neuf au départ", function()
			local d = Regles.migrer(nil, 15)
			expect(d.etape).to.equal(0)
			expect(d.meilleurTemps).to.equal(0)
			expect(#d.achats).to.equal(0)
		end)
		it("garde l'étape et le record d'anciennes données", function()
			local d = Regles.migrer({ etape = 7, meilleurTemps = 312.5, achats = { "a1" } }, 15)
			expect(d.etape).to.equal(7)
			expect(d.meilleurTemps).to.equal(312.5)
			expect(d.achats[1]).to.equal("a1")
		end)
		it("ramène une étape abîmée dans les bornes", function()
			expect(Regles.migrer({ etape = 99 }, 15).etape).to.equal(15)
			expect(Regles.migrer({ etape = -3 }, 15).etape).to.equal(0)
			expect(Regles.migrer({ etape = 0 / 0 }, 15).etape).to.equal(0)
			expect(Regles.migrer({ etape = "7" }, 15).etape).to.equal(0)
		end)
	end)

	describe("aura : plus on va loin sans tomber, plus on en gagne", function()
		local bareme = {
			AURA_BASE = 100,
			AURA_SERIE_MAX = 10,
			AURA_PERTE_CHUTE = 50,
			AURA_ARRIVEE = 1000,
			AURA_SANS_CHUTE = 5000,
		}
		it("le premier checkpoint d'une série rapporte la base", function()
			expect(Regles.gainCheckpoint(1, bareme)).to.equal(100)
		end)
		it("chaque checkpoint enchaîné sans tomber rapporte plus que le précédent", function()
			expect(Regles.gainCheckpoint(3, bareme)).to.equal(300)
			expect(Regles.gainCheckpoint(4, bareme) > Regles.gainCheckpoint(3, bareme)).to.equal(true)
		end)
		it("le multiplicateur est plafonné", function()
			expect(Regles.gainCheckpoint(14, bareme)).to.equal(1000)
		end)
		it("une chute coûte un peu d'aura, jamais sous zéro", function()
			expect(Regles.auraApresChute(500, bareme)).to.equal(450)
			expect(Regles.auraApresChute(20, bareme)).to.equal(0)
		end)
		it("un parcours entier sans tomber rapporte le gros bonus", function()
			expect(Regles.gainArrivee(Regles.nouvelleCourse(0), bareme)).to.equal(6000)
		end)
		it("pas de gros bonus après une chute, un passage payant ou une reprise", function()
			local tombee = Regles.nouvelleCourse(0)
			tombee.chutes = 1
			local payee = Regles.nouvelleCourse(0)
			payee.passages = 1
			expect(Regles.gainArrivee(tombee, bareme)).to.equal(1000)
			expect(Regles.gainArrivee(payee, bareme)).to.equal(1000)
			expect(Regles.gainArrivee(Regles.courseReprise(0), bareme)).to.equal(1000)
		end)
		it("affiche l'aura avec des espaces entre les milliers", function()
			expect(Regles.formaterAura(0)).to.equal("0")
			expect(Regles.formaterAura(950)).to.equal("950")
			expect(Regles.formaterAura(12345)).to.equal("12 345")
			expect(Regles.formaterAura(123456)).to.equal("123 456")
		end)
		it("garde l'aura sauvegardée et écarte une valeur abîmée", function()
			expect(Regles.migrer({ aura = 4200 }, 15).aura).to.equal(4200)
			expect(Regles.migrer({ aura = -3 }, 15).aura).to.equal(0)
			expect(Regles.migrer({ aura = 0 / 0 }, 15).aura).to.equal(0)
			expect(Regles.migrer({}, 15).aura).to.equal(0)
		end)
	end)

	describe("capacités et ascension dans les données sauvegardées", function()
		it("un joueur neuf n'a aucune capacité et aucun record d'ascension", function()
			local d = Regles.donneesNeuves()
			expect(next(d.capacites)).never.to.be.ok()
			expect(d.paliers).never.to.be.ok() -- plus de paliers : le champ n'existe plus
			expect(d.meilleureHauteur).to.equal(0)
			expect(d.meilleurTempsAscension).to.equal(0)
		end)

		it("un joueur existant reçoit les nouveaux champs vides sans rien perdre", function()
			local d = Regles.migrer({ etape = 9, meilleurTemps = 300, aura = 4200, achats = { "a1" } }, 15)
			expect(d.etape).to.equal(9)
			expect(d.meilleurTemps).to.equal(300)
			expect(d.aura).to.equal(4200)
			expect(d.achats[1]).to.equal("a1")
			expect(next(d.capacites)).never.to.be.ok()
			expect(d.meilleureHauteur).to.equal(0)
			expect(d.meilleurTempsAscension).to.equal(0)
		end)

		it("garde les capacités débloquées", function()
			local d = Regles.migrer({ capacites = { course = true, dash = true } }, 15)
			expect(d.capacites.course).to.equal(true)
			expect(d.capacites.dash).to.equal(true)
			expect(d.capacites.doubleSaut).never.to.be.ok()
		end)

		it("n'invente pas une capacité à partir de données abîmées", function()
			local d = Regles.migrer({ capacites = { course = false, dash = "oui", [7] = true } }, 15)
			expect(next(d.capacites)).never.to.be.ok()
			expect(next(Regles.migrer({ capacites = "course" }, 15).capacites)).never.to.be.ok()
		end)

		it("accepte sans planter d'anciennes données qui contiennent des paliers, et les ignore", function()
			-- Les paliers ont disparu avec la tour exigeante : une sauvegarde d'avant se charge quand même, sans
			-- rien perdre du reste, et le champ ne revient pas dans les données actuelles.
			local d = Regles.migrer({
				etape = 15,
				tutoFini = true,
				aura = 4200,
				paliers = { 3, 1, 3 },
				meilleureHauteur = 190,
			}, 15)
			expect(d.paliers).never.to.be.ok()
			expect(d.etape).to.equal(15)
			expect(d.aura).to.equal(4200)
			expect(d.meilleureHauteur).to.equal(190)
		end)

		it("accepte aussi un champ paliers abîmé d'une vieille sauvegarde", function()
			expect(Regles.migrer({ paliers = "3", aura = 10 }, 15).aura).to.equal(10)
			expect(Regles.migrer({ paliers = { 0, -2, 0 / 0 } }, 15).paliers).never.to.be.ok()
			expect(Regles.migrer({ paliers = 7, etape = 4 }, 15).etape).to.equal(4)
		end)

		it("garde la meilleure hauteur et le meilleur temps d'ascension", function()
			local d = Regles.migrer({ meilleureHauteur = 182.7, meilleurTempsAscension = 73.5 }, 15)
			expect(d.meilleureHauteur).to.equal(182)
			expect(d.meilleurTempsAscension).to.equal(73.5)
		end)

		it("écarte une hauteur ou un temps d'ascension abîmés", function()
			expect(Regles.migrer({ meilleureHauteur = -40 }, 15).meilleureHauteur).to.equal(0)
			expect(Regles.migrer({ meilleureHauteur = 0 / 0 }, 15).meilleureHauteur).to.equal(0)
			expect(Regles.migrer({ meilleureHauteur = math.huge }, 15).meilleureHauteur).to.equal(0)
			expect(Regles.migrer({ meilleurTempsAscension = "73" }, 15).meilleurTempsAscension).to.equal(0)
			expect(Regles.migrer({ meilleurTempsAscension = -1 }, 15).meilleurTempsAscension).to.equal(0)
		end)
	end)

	describe("le tuto fini ouvre l'ascension, et « Recommencer » ne la referme pas (tutoFini)", function()
		it("un joueur neuf n'a pas fini le tuto", function()
			expect(Regles.donneesNeuves().tutoFini).to.equal(false)
		end)

		it("un joueur existant arrivé au bout du tuto le reçoit à true", function()
			expect(Regles.migrer({ etape = 15 }, 15).tutoFini).to.equal(true)
			expect(Regles.migrer({ etape = 99 }, 15).tutoFini).to.equal(true) -- étape abîmée, ramenée à 15
		end)

		it("un joueur existant en route le reçoit à false", function()
			expect(Regles.migrer({ etape = 14 }, 15).tutoFini).to.equal(false)
			expect(Regles.migrer({ etape = 0 }, 15).tutoFini).to.equal(false)
			expect(Regles.migrer({}, 15).tutoFini).to.equal(false)
			expect(Regles.migrer(nil, 15).tutoFini).to.equal(false)
		end)

		it("garde tutoFini quand l'étape est repartie à 0 après « Recommencer »", function()
			local d = Regles.migrer({ etape = 0, tutoFini = true }, 15)
			expect(d.tutoFini).to.equal(true)
			expect(d.etape).to.equal(0)
		end)

		it("n'invente pas tutoFini à partir d'une valeur abîmée", function()
			expect(Regles.migrer({ etape = 3, tutoFini = "oui" }, 15).tutoFini).to.equal(false)
			expect(Regles.migrer({ etape = 3, tutoFini = 1 }, 15).tutoFini).to.equal(false)
			expect(Regles.migrer({ etape = 3, tutoFini = {} }, 15).tutoFini).to.equal(false)
		end)

		it("un tutoFini à false ne referme pas l'ascension d'un joueur arrivé au bout", function()
			expect(Regles.migrer({ etape = 15, tutoFini = false }, 15).tutoFini).to.equal(true)
		end)

		it(
			"l'ascension est ouverte exactement quand tutoFini est vrai (une seule règle pour les deux services)",
			function()
				local fini = Regles.donneesNeuves()
				fini.tutoFini = true
				fini.etape = 0 -- « Recommencer » : l'étape repart à 0, l'ascension reste ouverte
				expect(Regles.ascensionOuverte(fini)).to.equal(true)
				local enRoute = Regles.donneesNeuves()
				enRoute.etape = 15 -- l'étape ne décide plus de rien
				expect(Regles.ascensionOuverte(enRoute)).to.equal(false)
			end
		)
	end)

	describe("« Recommencer » renvoie au tuto sans rien retirer au joueur", function()
		local function joueurAvance()
			local d = Regles.donneesNeuves()
			d.etape = 15
			d.tutoFini = true
			d.aura = 12345
			d.meilleurTemps = 250
			d.meilleureHauteur = 190
			d.meilleurTempsAscension = 95
			d.capacites = { course = true, doubleSaut = true }
			return d
		end

		it("remet l'étape à 0 et rien d'autre", function()
			local d = joueurAvance()
			Regles.recommencer(d)
			expect(d.etape).to.equal(0)
			expect(d.tutoFini).to.equal(true)
			expect(d.aura).to.equal(12345)
			expect(d.meilleurTemps).to.equal(250)
			expect(d.meilleureHauteur).to.equal(190)
			expect(d.meilleurTempsAscension).to.equal(95)
			expect(d.capacites.doubleSaut).to.equal(true)
		end)

		it("l'ascension reste ouverte après « Recommencer » : on peut se retéléporter", function()
			local d = joueurAvance()
			Regles.recommencer(d)
			expect(Regles.ascensionOuverte(d)).to.equal(true)
		end)

		it("un joueur qui n'a pas fini le tuto n'ouvre rien en recommençant", function()
			local d = Regles.donneesNeuves()
			d.etape = 7
			Regles.recommencer(d)
			expect(d.etape).to.equal(0)
			expect(Regles.ascensionOuverte(d)).to.equal(false)
		end)

		it("la réapparition est celle de l'ascension seulement pendant une tentative, tuto fini", function()
			local d = joueurAvance()
			expect(Regles.placeParAscension(true, d)).to.equal(true)
			-- Tentative abandonnée (attribut EnAscension à false) : Parcours replace au checkpoint 0.
			expect(Regles.placeParAscension(false, d)).to.equal(false)
			-- Tuto pas fini : jamais placé par l'ascension, même avec l'attribut.
			expect(Regles.placeParAscension(true, Regles.donneesNeuves())).to.equal(false)
		end)

		it(
			"après « Recommencer » depuis l'ascension, Parcours place au tuto (attribut retombé à false)",
			function()
				local d = joueurAvance()
				local enAscension = true
				expect(Regles.placeParAscension(enAscension, d)).to.equal(true)
				enAscension = false -- le service d'ascension a abandonné la tentative
				Regles.recommencer(d)
				expect(Regles.placeParAscension(enAscension, d)).to.equal(false)
				expect(d.etape).to.equal(0) -- le checkpoint 0 du tuto
			end
		)
	end)

	describe("un achat n'est jamais donné deux fois", function()
		it("reconnaît un achat déjà traité", function()
			local achats = {}
			Regles.memoriserAchat(achats, "x", 100)
			expect(Regles.achatDejaTraite(achats, "x")).to.equal(true)
			expect(Regles.achatDejaTraite(achats, "y")).to.equal(false)
		end)
		it("ne garde que les achats les plus récents", function()
			local achats = {}
			for i = 1, 5 do
				Regles.memoriserAchat(achats, tostring(i), 3)
			end
			expect(#achats).to.equal(3)
			expect(achats[1]).to.equal("3")
			expect(achats[3]).to.equal("5")
		end)
	end)
end
