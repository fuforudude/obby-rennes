-- Les vannes de chute tournent sans jamais manquer.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Vannes = require(ReplicatedStorage.Partage.Vannes)

	it("donne une vanne à chaque chute, même après avoir fait le tour de la liste", function()
		local total = Vannes.nombreDeChutes()
		for n = 1, total * 2 + 1 do
			expect(#Vannes.chute(n) > 0).to.equal(true)
		end
		expect(Vannes.chute(1)).to.equal(Vannes.chute(total + 1))
	end)

	it("ne répète pas deux fois de suite la même vanne", function()
		for n = 1, Vannes.nombreDeChutes() * 2 do
			expect(Vannes.chute(n) ~= Vannes.chute(n + 1)).to.equal(true)
		end
	end)

	it("n'a aucune vanne en double dans la liste", function()
		local vues: { [string]: boolean } = {}
		for n = 1, Vannes.nombreDeChutes() do
			local texte = Vannes.chute(n)
			expect(vues[texte]).never.to.be.ok()
			vues[texte] = true
		end
	end)

	it("ne se moque pas des étudiants (notes, dossiers, Parcoursup) et ne fait pas la leçon", function()
		local interdits = { "parcoursup", "moyenne", "dossier", "%f[%w]s1%f[%W]", "remontée" }
		for n = 1, Vannes.nombreDeChutes() do
			local texte = string.lower(Vannes.chute(n))
			for _, motif in interdits do
				expect(string.find(texte, motif) == nil).to.equal(true)
			end
		end
	end)

	it("reste courte : une ou deux lignes de panneau, quelques secondes d'affichage", function()
		for n = 1, Vannes.nombreDeChutes() do
			expect(#Vannes.chute(n) <= 70).to.equal(true)
		end
	end)
end
