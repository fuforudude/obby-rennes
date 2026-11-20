// Tout vérifier, d'une seule commande, dans l'ordre de la CI (.github/workflows/verifier.yml la lance telle quelle) :
// format, lint, types, tests, génération de la carte, carte commitée = carte générée, contrôles de carte, cartes
// cassées (chacune doit faire échouer son contrôle avec le bon message), construction Rojo.
// S'arrête au premier échec, dit lequel et affiche sa sortie ; code de sortie 1.
//   node outils/tout-verifier.mjs            tout (en local : lourd node outils/tout-verifier.mjs)
//   node outils/tout-verifier.mjs --cartes   seulement la génération, les contrôles de carte et les cartes cassées
//                                            (job « construire » de .github/workflows/publier.yml)
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const racine = join(dirname(fileURLToPath(import.meta.url)), "..");
const seulementCartes = process.argv.includes("--cartes");
const dossierCasse = join(racine, "build", "cartes-cassees");
const durees = [];

function lancer(commande, args) {
  const r = spawnSync(commande, args, { cwd: racine, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (r.error) {
    return { code: 127, sortie: `${commande} introuvable (${r.error.message}) : « rokit install » à la racine ?` };
  }
  return { code: r.status ?? 1, sortie: `${r.stdout}${r.stderr}` };
}

function echouer(nom, sortie, raison) {
  console.log(sortie.trimEnd());
  console.error(`\nÉCHEC : ${nom}${raison ? ` (${raison})` : ""}`);
  process.exit(1);
}

/** Une étape : `faire` rend un message d'échec, ou rien si c'est bon. */
function etape(nom, faire) {
  const debut = performance.now();
  process.stdout.write(`${nom} … `);
  faire();
  const secondes = (performance.now() - debut) / 1000;
  durees.push([nom, secondes]);
  console.log(`ok (${secondes.toFixed(1)} s)`);
}

/** Une commande qui doit réussir. */
function reussir(nom, commande, args) {
  etape(nom, () => {
    const { code, sortie } = lancer(commande, args);
    if (code !== 0) {
      echouer(nom, sortie, `code ${code}`);
    }
  });
}

const node = process.execPath;
const lune = (script, ...args) => ["lune", ["run", script, ...args]];

if (!seulementCartes) {
  // Dépendances non commitées, nécessaires aux types (sourcemap Rojo) et à la construction.
  if (!existsSync(join(racine, "ServerPackages"))) {
    reussir("Dépendances Wally", "wally", ["install"]);
  }
  reussir("Format (StyLua)", "stylua", ["--check", "src", "tests", "outils"]);
  reussir("Lint (Selene)", "selene", ["src"]);
  reussir("Types Luau (luau-lsp)", node, ["outils/analyser-types.mjs"]);
  reussir("Tests de l'outil de publication (Node)", node, ["--test", "outils/publier.test.mjs"]);
  reussir("Tests des règles (Lune)", ...lune("outils/tests/lancer-specs.luau"));
}

// Carte commitée = carte générée. La génération est déterministe (deux générations donnent les mêmes octets) : on
// garde les .rbxm présents, on régénère, et tout octet changé est un défaut. Seul repli : si les octets diffèrent mais
// que l'empreinte (outils/monde/empreinte.luau, nombres arrondis à 0,01) est identique, c'est un écart de calcul
// flottant entre machines (Windows / Linux), pas une carte oubliée : accepté, avec un avertissement.
etape("Génération de la carte, carte commitée = carte générée", () => {
  const monde = join(racine, "monde");
  const lire = () =>
    new Map(
      readdirSync(monde)
        .filter((f) => f.endsWith(".rbxm"))
        .map((f) => [f, readFileSync(join(monde, f))]),
    );
  const avant = lire();
  const generation = lancer(...lune("outils/monde/generer.luau"));
  if (generation.code !== 0) {
    echouer("génération de la carte", generation.sortie, `code ${generation.code}`);
  }
  const apres = lire();
  const changes = [...new Set([...avant.keys(), ...apres.keys()])].filter(
    (f) => !avant.has(f) || !apres.has(f) || !avant.get(f).equals(apres.get(f)),
  );
  if (changes.length === 0) {
    return;
  }
  const commitee = join(racine, "build", "carte-commitee");
  rmSync(commitee, { recursive: true, force: true });
  mkdirSync(commitee, { recursive: true });
  for (const [f, octets] of avant) {
    writeFileSync(join(commitee, f), octets);
  }
  const empreinte = (sortie, dossier) => lancer(...lune("outils/monde/empreinte.luau", sortie, dossier));
  const e1 = empreinte("build/empreinte-commitee.txt", "build/carte-commitee");
  const e2 = empreinte("build/empreinte-generee.txt", "monde");
  if (e1.code !== 0 || e2.code !== 0) {
    echouer("empreinte de la carte", e1.sortie + e2.sortie);
  }
  const a = readFileSync(join(racine, "build/empreinte-commitee.txt"), "utf8");
  const b = readFileSync(join(racine, "build/empreinte-generee.txt"), "utf8");
  if (a !== b) {
    const la = a.split("\n");
    const lb = b.split("\n");
    const ecarts = la.filter((l) => !lb.includes(l)).map((l) => `- ${l}`);
    ecarts.push(...lb.filter((l) => !la.includes(l)).map((l) => `+ ${l}`));
    echouer(
      "carte commitée = carte générée",
      `${ecarts.slice(0, 40).join("\n")}${ecarts.length > 40 ? `\n… ${ecarts.length - 40} lignes de plus` : ""}\n` +
        `Régénérée : ${changes.join(", ")}. Comparer : git diff --no-index build/empreinte-commitee.txt build/empreinte-generee.txt`,
      "la carte commitée n'est pas celle que produisent les générateurs : commiter monde/ après generer.luau",
    );
  }
  process.stdout.write(`(octets différents pour ${changes.join(", ")}, empreinte identique : accepté) `);
});

reussir("Contrôle des contrats (tags, checkpoints 0..NB_ETAPES)", ...lune("outils/monde/verifier-contrats.luau"));
reussir("Contrôle des sauts du tuto", ...lune("outils/monde/verifier-sauts.luau"));
reussir("Contrôle des événements", ...lune("outils/monde/verifier-evenements.luau"));
reussir("Contrôle de l'ascension", ...lune("outils/monde/verifier-ascension.luau"));

// Cartes cassées : chacune est fabriquée à partir de la carte générée, puis passée à son contrôle, qui doit échouer
// (code non nul) en affichant chacun des messages attendus. Un contrôle qui échoue pour une autre raison ne prouve
// rien : le message compte autant que le code.
const PARCOURS = "monde/Parcours.rbxm";
const cassees = [
  ["casser-parcours", "course", "verifier-sauts", ["un chemin mène au bout sans course"]],
  ["casser-parcours", "dash", "verifier-sauts", ["un chemin mène au bout sans dash"]],
  ["casser-parcours", "double-saut", "verifier-sauts", ["un chemin mène au bout sans doubleSaut"]],
  ["casser-contrats", "sans-checkpoint-7", "verifier-contrats", ["aucun checkpoint de Numero 7"]],
  ["casser-contrats", "tag-inconnu", "verifier-contrats", ["tag inconnu « PiegeInconnu »"]],
  ["casser-contrats", "zone-10", "verifier-sauts", ["inatteignable : 10_Test/Checkpoint"]],
  [
    "casser-ascension",
    "marches",
    "verifier-ascension",
    ["existe sans course", "existe sans doubleSaut", "existe sans dash"],
  ],
  ["casser-ascension", "lasers", "verifier-ascension", ["fenêtre de passage garantie"]],
  ["casser-ascension", "pieges", "verifier-ascension", ["attribut Repos 0.4"]],
  ["casser-ascension", "repos", "verifier-ascension", ["attribut Repos nil"]],
  ["casser-ascension", "poussee", "verifier-ascension", ["poussée 120 studs/s"]],
  ["casser-ascension", "balanciers", "verifier-ascension", ["couvre toute la dalle"]],
  ["casser-ascension", "mobiles", "verifier-ascension", ["par cycle"]],
  ["casser-ascension", "effondrables", "verifier-ascension", ["DelaiRetour 20 s"]],
  ["casser-ascension", "tournants", "verifier-ascension", ["pas plus rapide que le tuto"]],
];
rmSync(dossierCasse, { recursive: true, force: true });
mkdirSync(dossierCasse, { recursive: true });
for (const [fabrique, panne, controle, attendus] of cassees) {
  etape(`Carte cassée ${fabrique} ${panne} refusée par ${controle}`, () => {
    const fichier = join("build", "cartes-cassees", `${fabrique}-${panne}.rbxm`);
    const f = lancer(...lune(`outils/monde/${fabrique}.luau`, panne, fichier));
    if (f.code !== 0) {
      echouer(`fabrication de ${fabrique} ${panne}`, f.sortie, `code ${f.code}`);
    }
    // verifier-ascension lit le tuto en second argument (la salle de partiel) ; les autres n'en prennent qu'un.
    const args = controle === "verifier-ascension" ? [fichier, PARCOURS] : [fichier];
    const c = lancer(...lune(`outils/monde/${controle}.luau`, ...args));
    if (c.code === 0) {
      echouer(`carte cassée ${fabrique} ${panne}`, c.sortie, `${controle} l'accepte : il ne prouve plus rien`);
    }
    const manquants = attendus.filter((m) => !c.sortie.includes(m));
    if (manquants.length > 0) {
      echouer(
        `carte cassée ${fabrique} ${panne}`,
        c.sortie,
        `${controle} échoue, mais sans le message attendu : ${manquants.map((m) => `« ${m} »`).join(", ")}`,
      );
    }
  });
}
rmSync(dossierCasse, { recursive: true, force: true });

if (!seulementCartes) {
  mkdirSync(join(racine, "build"), { recursive: true });
  reussir("Construction Rojo", "rojo", ["build", "default.project.json", "-o", "build/jeu.rbxl"]);
}

const total = durees.reduce((s, [, d]) => s + d, 0);
const casse = durees.filter(([n]) => n.startsWith("Carte cassée")).reduce((s, [, d]) => s + d, 0);
console.log(`\nTout est vert : ${durees.length} étapes en ${total.toFixed(1)} s (dont cartes cassées ${casse.toFixed(1)} s).`);
