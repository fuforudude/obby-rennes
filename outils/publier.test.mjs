import assert from "node:assert/strict";
import { test } from "node:test";
import { lireCible, lireVersion, messageSucces } from "./publier.mjs";

const config = {
  places: {
    test: { universeId: 11, placeId: 22 },
    prod: { universeId: 0, placeId: 0 },
  },
};

test("identifiants valides : renvoie l'univers et la place", () => {
  assert.deepEqual(lireCible(config, "test"), { universeId: 11, placeId: 22 });
});

test("identifiants à 0 : erreur claire", () => {
  assert.throws(
    () => lireCible(config, "prod"),
    /Identifiants de l'expérience prod absents de \.claude\/roblox\.json/,
  );
});

test("identifiants manquants : erreur claire", () => {
  assert.throws(() => lireCible({ places: { test: {} } }, "test"), /Identifiants de l'expérience test absents/);
});

test("cible inconnue : erreur", () => {
  assert.throws(() => lireCible(config, "staging"), /Cible inconnue : staging/);
});

test("message de succès", () => {
  assert.equal(messageSucces("test", 7, "abc1234"), "Publié sur test : version 7 (commit abc1234)");
});

test("cible héritée de Object (constructor) : erreur", () => {
  assert.throws(() => lireCible(config, "constructor"), /Cible inconnue : constructor/);
});

test("identifiant en texte : erreur claire", () => {
  assert.throws(
    () => lireCible({ places: { test: { universeId: "0", placeId: 22 } } }, "test"),
    /Identifiants de l'expérience test absents/,
  );
  assert.throws(
    () => lireCible({ places: { test: { universeId: "11", placeId: 22 } } }, "test"),
    /Identifiants de l'expérience test absents/,
  );
});

test("réponse valide : renvoie le numéro de version", () => {
  assert.equal(lireVersion('{"versionNumber": 12}'), 12);
});

test("réponse sans versionNumber entier : erreur claire", () => {
  assert.throws(() => lireVersion("{}"), /pas de versionNumber entier/);
  assert.throws(() => lireVersion('{"versionNumber": "12"}'), /pas de versionNumber entier/);
  assert.throws(() => lireVersion("pas du json"), /JSON invalide/);
});
