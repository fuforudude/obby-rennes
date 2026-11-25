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
const DELAI_MAX_COMMANDE = 5 * 60; // secondes : au-delà, la commande est arrêtée (la plus longue prend ~40 s)

function lancer(commande, args) {
  const r = spawnSync(commande, args, {
    cwd: racine,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: DELAI_MAX_COMMANDE * 1000,
  });
  if (r.error?.code === "ETIMEDOUT") {
    return {
      code: 124,
      sortie:
        `${r.stdout ?? ""}${r.stderr ?? ""}\n${commande} ${args.join(" ")} arrêté après ${DELAI_MAX_COMMANDE / 60} min ` +
        "sans finir : sans doute bloqué (boucle infinie ?), voir la sortie ci-dessus.",
    };
  }
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
reussir("Contrôle des bords (ce qui paraît solide porte le joueur)", ...lune("outils/monde/verifier-bords.luau"));
// Registre des cartes (outils/monde/monde.json, lu aussi par generer.luau et verifier-contrats.luau) : chaque carte
// nomme son contrôle de carte (« controle »), lancé ici sans argument (il lit ses cartes par défaut). Une carte sans
// contrôle, ou dont le contrôle n'existe pas, est refusée : ajouter une carte, c'est aussi la contrôler.
const registre = JSON.parse(readFileSync(join(racine, "outils/monde/monde.json"), "utf8"));
for (const [nom, entree] of Object.entries(registre)) {
  if (typeof entree.controle !== "string" || !existsSync(join(racine, entree.controle))) {
    echouer(
      "registre des cartes",
      "",
      `outils/monde/monde.json : la carte ${nom} n'a pas de « controle » existant (${entree.controle ?? "absent"})`,
    );
  }
  reussir(`Contrôle de la carte ${nom} (${entree.controle})`, ...lune(entree.controle));
}

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
  ["casser-contrats", "table-courte", "verifier-contrats", ["la table des checkpoints a", "NB_ETAPES + 1"]],
  ["casser-contrats", "nom-de-zone", "verifier-contrats", ["zone n°3 : « Zone trafiquée »"]],
  ["casser-contrats", "lecteur-absent", "verifier-contrats", ["le lecteur du tag « Laser »", "LaserDisparu.luau"]],
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
  ["casser-ascension", "bouts", "verifier-ascension", ["BoutTournant : dépasse de la barre"]],
  ["casser-ascension", "tag-sans-simulateur", "verifier-ascension", ["tag « Fragile » sans simulateur"]],
  ["casser-bords", "bord", "verifier-bords", ["Lisere prolonge Ascension.Pied.PiedAscension"]],
  ["casser-bords", "traverse", "verifier-bords", ["GardeCorps, posée sur Parcours.4_LaTour.Balcon, se traverse"]],
  ["casser-bords", "invisible", "verifier-bords", ["GardeCorps : solide et invisible"]],
  ["casser-bords", "aplomb", "verifier-bords", ["Facade : habillage solide hors de l'aplomb"]],
  ["casser-bords", "penche", "verifier-bords", ["Cale : habillage solide penché"], "seul"],
  ["casser-bords", "rebord", "verifier-bords", ["Facade : on tient debout sur cet habillage"]],
  ["casser-bords", "maillage", "verifier-bords", ["GardeCorps : Part solide, sa collision peut s'écarter"], "seul"],
  ["casser-bords", "mobile", "verifier-bords", ["Lisere prolonge Ascension.Pied.PiedAscension"]],
  ["casser-bords", "toit", "verifier-bords", ["EclatVerriere prolonge Parcours.9_SupDeVinci.Encadrement"], "seul"],
  ["casser-bords", "exception", "verifier-bords", ["FaisceauEtage$ » inutile"], "seul"],
  ["casser-bords", "mur", "verifier-sauts", ["checkpoints inatteignables : 9, 10"]],
  ["casser-bords", "balcon", "verifier-sauts", ["checkpoints inatteignables : 8, 9"]],
  ["casser-bords", "passage", "verifier-evenements", ["sa trajectoire traverse Evenements.Decor.Chaussee"]],
  [
    "casser-bords",
    "balancier",
    "verifier-evenements",
    ["PortillonValidation touche Evenements.Decor.PortiqueStation.Valideur"],
  ],
  ["casser-ascension", "mur", "verifier-ascension", ["saut PiedAscension -> Pas1_1 barré"]],
  ["casser-ascension", "mur-acces", "verifier-ascension", ["saut ArmoireDeLaVerriere -> PanneauDuToit barré"]],
  ["casser-ascension", "passager", "verifier-ascension", ["PoutreDeTriche, elle ou son passager"]],
  ["casser-ascension", "laser-habillage", "verifier-ascension", ["traverse la dalle Ascension.Chemin."]],
  // Contrôle null : c'est la fabrique elle-même (la génération trafiquée) qui doit échouer avec le message.
  ["casser-ascension", "famille-inconnue", null, ["famille d'obstacle inconnue « Ascenseur »"]],
];
rmSync(dossierCasse, { recursive: true, force: true });
mkdirSync(dossierCasse, { recursive: true });
// « seul » : la panne ne doit produire que ce défaut-là.
for (const [fabrique, panne, controle, attendus, seul] of cassees) {
  etape(`Carte cassée ${fabrique} ${panne} refusée par ${controle ?? "la génération"}`, () => {
    const fichier = join("build", "cartes-cassees", `${fabrique}-${panne}.rbxm`);
    const f = lancer(...lune(`outils/monde/${fabrique}.luau`, panne, fichier));
    if (controle === null) {
      if (f.code === 0) {
        echouer(`générateur cassé ${fabrique} ${panne}`, f.sortie, "la génération l'accepte : elle ne prouve plus rien");
      }
      const manquants = attendus.filter((m) => !f.sortie.includes(m));
      if (manquants.length > 0) {
        echouer(
          `générateur cassé ${fabrique} ${panne}`,
          f.sortie,
          `la génération échoue, mais sans le message attendu : ${manquants.map((m) => `« ${m} »`).join(", ")}`,
        );
      }
      return;
    }
    if (f.code !== 0) {
      echouer(`fabrication de ${fabrique} ${panne}`, f.sortie, `code ${f.code}`);
    }
    // verifier-ascension lit le tuto en second argument (la salle de partiel) ; les autres n'en prennent qu'un.
    // Une panne peut aussi trafiquer la table du parcours (à côté de la carte, en .luau) ou les lecteurs de tags
    // (en .tags.luau).
    const args = controle === "verifier-ascension" ? [fichier, PARCOURS] : [fichier];
    const table = fichier.replace(/\.rbxm$/, ".luau");
    if (existsSync(join(racine, table))) {
      args.push(`parcours=${table}`);
    }
    const tags = fichier.replace(/\.rbxm$/, ".tags.luau");
    if (existsSync(join(racine, tags))) {
      args.push(`tags=${tags}`);
    }
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
    const nbDefauts = c.sortie.split("\n").filter((l) => l.includes("DÉFAUT :")).length;
    if (seul && nbDefauts !== 1) {
      echouer(`carte cassée ${fabrique} ${panne}`, c.sortie, `${nbDefauts} défauts, un seul attendu`);
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
