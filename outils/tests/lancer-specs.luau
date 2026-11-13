-- Lance les specs de tests/partage dans Lune, sans Roblox : un mini TestEZ (describe / it / expect)
-- et un faux `game` fournissent ce que les specs attendent.
-- Usage (depuis la racine) : lune run outils/tests/lancer-specs.luau
-- Code de sortie : 0 si tout passe, 1 au moindre échec ou si aucun test n'a tourné.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox") -- Vector3 pour les specs qui en ont besoin

local jeu -- le faux `game`, défini plus bas

-- `require` des specs : charge un module Luau par son chemin, une seule fois.
local cache = {}
local function charger(chemin: string)
	if cache[chemin] == nil then
		-- Un module de partage peut lui aussi appeler `game:GetService("ReplicatedStorage")` et `require`.
		local env = { game = jeu, require = charger, Vector3 = roblox.Vector3 }
		cache[chemin] =
			luau.load(fs.readFile(chemin), { debugName = chemin, environment = setmetatable(env, { __index = _G }) })()
	end
	return cache[chemin]
end

-- Faux ReplicatedStorage.Partage : chaque module est représenté par son chemin dans src/partage/,
-- que le `require` ci-dessus sait charger.
local partage = setmetatable({}, {
	__index = function(_, nom)
		return "src/partage/" .. nom .. ".luau"
	end,
})
local faux = {
	GetService = function(_, nom)
		assert(nom == "ReplicatedStorage", nom)
		return { Partage = partage }
	end,
}

jeu = faux

-- Résultats, et pile des `describe` en cours (pour nommer les échecs).
local reussis, echecs = 0, {}
local pile = {}

-- Sous-ensemble de l'API expect de TestEZ : to.equal, to.be.ok, never.to.be.ok.
local function expect(valeur)
	local function equal(attendu)
		if valeur ~= attendu then
			error(`attendu {tostring(attendu)}, obtenu {tostring(valeur)}`, 3)
		end
	end
	local function ok()
		if valeur == nil then
			error("valeur attendue, obtenu nil", 3)
		end
	end
	local function nonOk()
		if valeur ~= nil then
			error(`nil attendu, obtenu {tostring(valeur)}`, 3)
		end
	end
	return { to = { equal = equal, be = { ok = ok } }, never = { to = { be = { ok = nonOk } } } }
end

local function describe(nom, corps)
	table.insert(pile, nom)
	corps()
	table.remove(pile)
end

-- Un `it` qui lève une erreur est un échec ; les autres continuent.
local function it(nom, corps)
	local complet = table.concat(pile, " > ") .. " > " .. nom
	local ok, err = pcall(corps)
	if ok then
		reussis += 1
	else
		table.insert(echecs, complet .. " : " .. tostring(err))
	end
end

-- Chaque spec est chargée avec son propre environnement, puis exécutée.
local fichiers = {}
for _, fichier in fs.readDir("tests/partage") do
	if string.match(fichier, "%.spec%.luau$") then
		table.insert(fichiers, fichier)
	end
end
table.sort(fichiers)

for _, fichier in fichiers do
	local chemin = "tests/partage/" .. fichier
	local env = setmetatable({
		game = faux,
		require = charger,
		Vector3 = roblox.Vector3,
		describe = describe,
		it = it,
		expect = expect,
	}, { __index = _G })
	local spec = luau.load(fs.readFile(chemin), { debugName = chemin, environment = env })()
	table.insert(pile, fichier)
	spec()
	table.remove(pile)
end

if reussis + #echecs == 0 then
	print("Aucun test n'a tourné")
	process.exit(1)
end

print(`{reussis} réussis, {#echecs} échecs`)
for _, e in echecs do
	print("  ✗ " .. e)
end
process.exit(if #echecs == 0 then 0 else 1)
