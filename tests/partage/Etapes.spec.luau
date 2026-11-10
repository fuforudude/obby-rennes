-- Chaque checkpoint du parcours a sa zone et son anecdote.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Etapes = require(ReplicatedStorage.Partage.Etapes)
	local Reglages = require(ReplicatedStorage.Partage.Reglages)

	it("décrit chaque checkpoint, du départ à l'arrivée", function()
		expect(Etapes.nombre()).to.equal(Reglages.NB_ETAPES + 1)
		for numero = 0, Reglages.NB_ETAPES do
			local etape = Etapes.obtenir(numero)
			expect(etape).to.be.ok()
			expect(etape.numero).to.equal(numero)
			expect(#etape.zone > 0).to.equal(true)
			expect(#etape.anecdote > 0).to.equal(true)
			expect(#etape.blague > 0).to.equal(true)
		end
	end)

	it("n'invente pas d'étape au-delà de l'arrivée", function()
		expect(Etapes.obtenir(Reglages.NB_ETAPES + 1)).never.to.be.ok()
	end)
end
