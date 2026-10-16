import test from "node:test";
import assert from "node:assert/strict";
import { connectionMessage, installMessage, manualInstallInstructions, isStandalone } from "../src/pwa.js";

test("connection state never falsely guarantees network reachability", () => {
  assert.equal(connectionMessage(true), "Connexion détectée");
  assert.match(connectionMessage(false), /Hors connexion/);
});

test("Android and iOS install fallback instructions need no browser support", () => {
  assert.match(manualInstallInstructions(), /Installer l.application|écran d.accueil/);
  assert.match(manualInstallInstructions("ios"), /Safari/);
  assert.equal(installMessage(false), "Installer le jeu");
  assert.equal(installMessage(true), "Application installée");
});

test("standalone detection supports Chrome and installed Safari", () => {
  assert.equal(isStandalone(false, false), false);
  assert.equal(isStandalone(true, false), true);
  assert.equal(isStandalone(false, true), true);
});
