-- Régénère les fichiers de monde/ à partir des constructions listées dans outils/monde/monde.json.
--   lune run outils/monde/generer.luau            toutes les constructions dont Claude est l'auteur
--   lune run outils/monde/generer.luau Carte      une seule
-- Une entrée « auteur » : « utilisateur » (retouchée à la main dans Studio puis enregistrée en .rbxm)
-- n'est jamais régénérée : on écraserait son travail.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local manifeste = serde.decode("json", fs.readFile("outils/monde/monde.json"))
local demande = process.args[1]
local faits = 0

for nom, entree in manifeste do
	if demande and nom ~= demande then
		continue
	end
	if entree.auteur == "utilisateur" then
		print(`{nom} : retouché par l'utilisateur, non régénéré ({entree.sortie} fait foi)`)
		continue
	end
	local construire = luau.load(fs.readFile(entree.generateur), { debugName = entree.generateur })()
	local modele = construire(roblox)
	fs.writeFile(entree.sortie, roblox.serializeModel({ modele }))
	print(`{nom} : {entree.sortie} écrit`)
	faits += 1
end

if demande and faits == 0 and not manifeste[demande] then
	print(`{demande} : absent de outils/monde/monde.json`)
	process.exit(1)
end
