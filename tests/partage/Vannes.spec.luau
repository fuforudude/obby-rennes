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
end
