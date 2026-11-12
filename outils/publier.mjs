// Publie un fichier .rbxl sur l'expérience Roblox « test » ou « prod » (API Open Cloud).
// Usage : node outils/publier.mjs <test|prod> <fichier.rbxl>
// La clé est lue dans la variable d'environnement ROBLOX_API_KEY (jamais affichée).
import { execSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

/** Renvoie { universeId, placeId } de la cible, ou lève une erreur claire. */
export function lireCible(config, cible) {
  const place = ["test", "prod"].includes(cible) ? config?.places?.[cible] : undefined;
  if (!place) {
    throw new Error(`Cible inconnue : ${cible} (attendu : test ou prod)`);
  }
  const { universeId, placeId } = place;
  const valide = (id) => Number.isSafeInteger(id) && id > 0;
  if (!valide(universeId) || !valide(placeId)) {
    throw new Error(`Identifiants de l'expérience ${cible} absents de .claude/roblox.json`);
  }
  return { universeId, placeId };
}

/** Extrait le numéro de version de la réponse de l'API, ou lève une erreur claire. */
export function lireVersion(corps) {
  let donnees;
  try {
    donnees = JSON.parse(corps);
  } catch {
    throw new Error(`Réponse inattendue de l'API Roblox (JSON invalide) : ${corps}`);
  }
  if (!Number.isSafeInteger(donnees?.versionNumber)) {
    throw new Error(`Réponse inattendue de l'API Roblox (pas de versionNumber entier) : ${corps}`);
  }
  return donnees.versionNumber;
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
  let reponse;
  try {
    reponse = await fetch(url, {
      method: "POST",
      headers: { "x-api-key": cle, "Content-Type": "application/octet-stream" },
      body: readFileSync(fichier),
    });
  } catch (erreur) {
    throw new Error(`Échec réseau : ${erreur.message}${erreur.cause?.message ? ` (${erreur.cause.message})` : ""}`);
  }
  const corps = await reponse.text();
  if (!reponse.ok) {
    throw new Error(`Échec de la publication : HTTP ${reponse.status} ${corps}`);
  }
  const versionNumber = lireVersion(corps);

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
