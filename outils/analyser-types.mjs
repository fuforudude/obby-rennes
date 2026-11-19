// Analyse de types Luau (luau-lsp) : `--!strict` est en tête de chaque fichier, mais seul cet outil le vérifie
// (StyLua, Selene et « rojo build » ne regardent pas les types). Il attrape par exemple une table de défauts
// incomplète passée à une fonction typée (le champ `pousseeMax` oublié par src/serveur/Obstacles.luau).
// Usage (depuis n'importe où) : node outils/analyser-types.mjs   -> code de sortie 1 au moindre TypeError.
// Lancé par « roblox verifier » et par .github/workflows/verifier.yml.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const racine = join(dirname(fileURLToPath(import.meta.url)), "..");

// Périmètre analysé : le code des règles (partage) et le serveur. src/client n'est pas encore analysé.
const DOSSIERS = ["src/partage", "src/serveur"];

// À TRAITER : fichiers qui avaient déjà des erreurs de types avant la mise en place de cette analyse (leurs erreurs ne
// sont pas affichées). Corriger un fichier = le retirer de cette liste ; ne jamais y en ajouter un nouveau.
const A_TRAITER = [
	"src/partage/Affichage.luau", // 4 : littéraux de chaînes élargis en `string` (capacité, annonce)
	"src/partage/Capacites.luau", // 1 : liste de capacités typée `{ string }` au lieu de l'union de littéraux
	"src/serveur/Ascension.luau", // 3 : `local ok, erreur = pcall(f)` avec f sans valeur de retour
	"src/serveur/Capacites.luau", // 1 : même cause (pcall)
	"src/serveur/Parcours.luau", // 1 : même cause (pcall), plus un avertissement d'API obsolète (LoadCharacter)
	"src/serveur/Classement.luau", // 1 : un `nil` passé là où un nombre est attendu (ligne 139)
];

// Les définitions des types Roblox, à la version de luau-lsp épinglée dans rokit.toml.
const rokit = readFileSync(join(racine, "rokit.toml"), "utf8");
const version = /luau-lsp\s*=\s*"[^"@]+@([^"]+)"/.exec(rokit)?.[1];
if (!version) {
	console.error("luau-lsp absent de rokit.toml : rokit add JohnnyMorganz/luau-lsp");
	process.exit(2);
}
const dossierTypes = join(racine, ".types");
const definitions = join(dossierTypes, `globalTypes-${version}.d.luau`);
if (!existsSync(definitions)) {
	const url = `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${version}/scripts/globalTypes.d.luau`;
	const reponse = await fetch(url);
	if (!reponse.ok) {
		console.error(`Téléchargement des définitions impossible (${reponse.status}) : ${url}`);
		process.exit(2);
	}
	mkdirSync(dossierTypes, { recursive: true });
	writeFileSync(definitions, await reponse.text());
}

function lancer(outil, args) {
	const r = spawnSync(outil, args, { cwd: racine, stdio: "inherit" });
	if (r.error || r.status === null) {
		console.error(`${outil} introuvable : lancer « rokit install » à la racine du projet.`);
		process.exit(2);
	}
	return r.status;
}

if (lancer("rojo", ["sourcemap", "default.project.json", "--output", "sourcemap.json"]) !== 0) {
	process.exit(2);
}
const ignorer = A_TRAITER.flatMap((f) => ["--ignore", f]);
const statut = lancer("luau-lsp", [
	"analyze",
	`--definitions=${definitions}`,
	"--sourcemap=sourcemap.json",
	...ignorer,
	...DOSSIERS,
]);
if (statut !== 0) {
	console.error("Analyse de types en échec.");
}
console.log(`Analyse de types : ${DOSSIERS.join(", ")} (${A_TRAITER.length} fichiers encore à traiter, ignorés).`);
process.exit(statut);
