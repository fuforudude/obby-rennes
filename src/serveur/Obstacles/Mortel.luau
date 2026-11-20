--!strict
-- Mortel : tue au toucher.
local Commun = require(script.Parent.Commun)

local famille: Commun.Famille = {
	tag = "Mortel",
	classe = "BasePart",
	preparer = function(objet: Instance): Commun.Maj?
		Commun.tuerAuContact(objet :: BasePart)
		return nil
	end,
}

return famille
