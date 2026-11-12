// Publie un fichier .rbxl sur l'expérience Roblox « test » ou « prod » (API Open Cloud).
// Usage : node outils/publier.mjs <test|prod> <fichier.rbxl>
// La clé est lue dans la variable d'environnement ROBLOX_API_KEY (jamais affichée).
import { execSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

/** Renvoie { universeId, placeId } de la cible, ou lève une erreur claire. */
export function lireCible(config, cible) {
  const place = config?.places?.[cible];
  if (!place) {
    throw new Error(`Cible inconnue : ${cible} (attendu : test ou prod)`);
  }
  const { universeId, placeId } = place;
  if (!universeId || !placeId) {
    throw new Error(`Identifiants de l'expérience ${cible} absents de .claude/roblox.json`);
  }
  return { universeId, placeId };
}

/** Ligne affichée (et ajoutée au résumé GitHub) après une publication réussie. */
export function messageSucces(cible, version, commit) {
  return `Publié sur ${cible} : version ${version} (commit ${commit})`;
}

async function principal(argv, env) {
  const [cible, fichier] = argv;
  if (!cible || !fichier) {
    throw new Error("Usage : node outils/publier.mjs <test|prod> <fichier.rbxl>");
  }
  const config = JSON.parse(readFileSync(".claude/roblox.json", "utf8"));
  const { universeId, placeId } = lireCible(config, cible);

  const cle = env.ROBLOX_API_KEY;
  if (!cle) {
    throw new Error("Variable d'environnement ROBLOX_API_KEY absente");
  }

  const url = `https://apis.roblox.com/universes/v1/${universeId}/places/${placeId}/versions?versionType=Published`;
  const reponse = await fetch(url, {
    method: "POST",
    headers: { "x-api-key": cle, "Content-Type": "application/octet-stream" },
    body: readFileSync(fichier),
  });
  const corps = await reponse.text();
  if (!reponse.ok) {
    throw new Error(`Échec de la publication : HTTP ${reponse.status} ${corps}`);
  }
  const { versionNumber } = JSON.parse(corps);

  const commit = env.GITHUB_SHA ?? execSync("git rev-parse --short HEAD").toString().trim();
  const message = messageSucces(cible, versionNumber, commit);
  console.log(message);
  if (env.GITHUB_STEP_SUMMARY) {
    appendFileSync(env.GITHUB_STEP_SUMMARY, `${message}\n`);
  }
}

// Lancé seulement si le fichier est exécuté directement (pas importé par les tests).
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  principal(process.argv.slice(2), process.env).catch((erreur) => {
    console.error(erreur.message);
    process.exit(1);
  });
}
