-- Texte des SurfaceGui : la règle de taille, pure (bibliothèque commune des générateurs, outils/monde/biblio.luau).
-- TOUJOURS une taille fixe calculée, jamais TextScaled (en jeu, TextScaled rend un texte minuscule sur ces panneaux ;
-- la taille fixe est la seule qui a été vue lisible). Seul exemplaire : les générateurs la reçoivent par
-- outils/monde/generer.luau (biblio.calibrerSurfaces), verifier-evenements.luau et verifier-ascension.luau la
-- chargent pour contrôler les textes écrits à l'exécution, et refusent tout TextScaled ou TextSize < 12.
local TAILLE_MIN, TAILLE_MAX = 12, 100 -- TextSize : Roblox le borne à 100
local REMPLISSAGE_LARGEUR = 0.95 -- marge d'erreur sur la largeur estimée des caractères

-- Par police : largeur moyenne (en fraction de la taille) d'une minuscule, d'une majuscule, d'un chiffre, d'une
-- espace et d'un autre signe ; puis hauteur d'une ligne (en fraction de la taille). Estimations prudentes ; la
-- police Code est à chasse fixe (0,6).
local METRIQUES = {
	Gotham = { 0.54, 0.70, 0.62, 0.27, 0.42, 1.2 },
	GothamBold = { 0.57, 0.73, 0.64, 0.27, 0.44, 1.2 },
	GothamBlack = { 0.61, 0.78, 0.68, 0.28, 0.46, 1.2 },
	Code = { 0.6, 0.6, 0.6, 0.6, 0.6, 1.1 },
}

local function largeurCaractere(c: number, m): number
	if (c >= 97 and c <= 122) or (c >= 0xDF and c <= 0xFF) then
		return m[1]
	elseif (c >= 65 and c <= 90) or (c >= 0xC0 and c <= 0xDE) then
		return m[2]
	elseif c >= 48 and c <= 57 then
		return m[3]
	elseif c == 32 then
		return m[4]
	end
	return m[5]
end

-- Le texte en paragraphes (séparés par \n), chacun une liste de largeurs de mots (en fraction de la taille).
local function decouperTexte(contenu: string, m)
	local paragraphes = {}
	for ligne in string.gmatch(contenu .. "\n", "([^\n]*)\n") do
		local mots = {}
		for mot in string.gmatch(ligne, "%S+") do
			local w = 0
			for _, c in utf8.codes(mot) do
				w += largeurCaractere(c, m)
			end
			table.insert(mots, w)
		end
		table.insert(paragraphes, mots)
	end
	return paragraphes
end

-- Nombre de lignes après retour à la ligne glouton, `capacite` étant la largeur de ligne en fraction de la taille.
local function compterLignes(paragraphes, espace: number, capacite: number): number
	local n = 0
	for _, mots in paragraphes do
		n += 1
		local courante = 0
		for i, w in mots do
			if i > 1 and courante + espace + w <= capacite then
				courante += espace + w
			else
				if i > 1 then
					n += 1
				end
				if w > capacite then -- mot plus long qu'une ligne : coupé
					local en_plus = math.ceil(w / capacite) - 1
					n += en_plus
					courante = w - en_plus * capacite
				else
					courante = w
				end
			end
		end
	end
	return n
end

-- La plus grande taille entière (12 à `plafond`, 100 par défaut) pour laquelle `contenu` tient dans largeur ×
-- hauteur pixels, à la ligne ; rend la taille et le nombre de lignes. 12 si rien ne tient.
local function ajusterTexte(contenu: string, police: string, largeur: number, hauteur: number, plafond: number?)
	local m = METRIQUES[police] or METRIQUES.GothamBold
	local paragraphes = decouperTexte(contenu, m)
	local utile = largeur * REMPLISSAGE_LARGEUR
	local function lignesA(s: number): number
		return compterLignes(paragraphes, m[4], utile / s)
	end
	local function tient(s: number): boolean
		return lignesA(s) * m[6] * s <= hauteur
	end
	local bas, haut = TAILLE_MIN, math.max(TAILLE_MIN, math.floor(plafond or TAILLE_MAX))
	while bas < haut and tient(bas) do
		local milieu = (bas + haut + 1) // 2
		if tient(milieu) then
			bas = milieu
		else
			haut = milieu - 1
		end
	end
	return bas, lignesA(bas)
end

-- La seule règle de taille de texte : fixe, à la ligne, texte brut, entier entre 12 et 100.
local function reglerTexte(label, largeur: number, hauteur: number, contenu: string, plafond: number?)
	local taille, lignes = ajusterTexte(contenu, label.Font.Name, largeur, hauteur, plafond)
	label.TextScaled = false
	label.TextWrapped = true
	label.RichText = false
	label.TextSize = taille
	return taille, lignes
end

return {
	TAILLE_MIN = TAILLE_MIN,
	TAILLE_MAX = TAILLE_MAX,
	METRIQUES = METRIQUES,
	ajusterTexte = ajusterTexte,
	reglerTexte = reglerTexte,
}
