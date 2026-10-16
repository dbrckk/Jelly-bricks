/**
 * On-device PWA diagnostics: no upload, trackers, tokens or external services.
 * All checks are read-only except a temporary localStorage write immediately
 * restored to its previous value. The report is generated on this device.
 */
export const DIAGNOSTIC_ASSETS = Object.freeze([
  "./index.html", "./styles.css", "./src/main.js",
  "./src/game.js", "./src/pwa.js", "./src/diagnostics.js"
]);

export function checkStorage(storage) {
  if (!storage) return false;
  const key = "jelly-bricks-diagnostic-probe";
  try {
    const previous = storage.getItem(key);
    storage.setItem(key, "ok");
    const working = storage.getItem(key) === "ok";
    if (previous === null) storage.removeItem(key);
    else storage.setItem(key, previous);
    return working;
  } catch {
    return false;
  }
}

export async function checkOfflineCache(cacheStorage, baseUrl) {
  const total = DIAGNOSTIC_ASSETS.length;
  const empty = { version: null, found: 0, total };
  if (!cacheStorage) return empty;
  try {
    const versions = (await cacheStorage.keys())
      .map((name) => ({ name, revision: Number(name.match(/^jelly-bricks-static-v(\d+)$/)?.[1]) }))
      .filter(({ revision }) => Number.isSafeInteger(revision) && revision > 0)
      .sort((a, b) => b.revision - a.revision);
    if (!versions.length) return empty;
    const version = versions[0].name;
    const cache = await cacheStorage.open(version);
    const matched = await Promise.all(DIAGNOSTIC_ASSETS.map(async (path) =>
      Boolean(await cache.match(new URL(path, baseUrl).href))));
    return { version, found: matched.filter(Boolean).length, total };
  } catch {
    return empty;
  }
}

/** A short, active-tab refresh estimate; not a benchmark of game FPS. */
export function measureRefresh(requestFrame, durationMs = 1250) {
  return new Promise((resolve, reject) => {
    if (typeof requestFrame !== "function") return reject(new Error("Animation indisponible"));
    let start = null;
    let count = 0;
    function sample(now) {
      if (start === null) start = now;
      const elapsed = now - start;
      if (elapsed >= durationMs) {
        resolve(elapsed > 0 ? Math.round(count * 1000 / elapsed) : 0);
        return;
      }
      count++;
      requestFrame(sample);
    }
    requestFrame(sample);
  });
}

export function formatDiagnostic({
  viewport, scale, touch, standalone, storageOk, cache, online, refresh
}) {
  const cacheLine = cache.version ?
    cache.found + "/" + cache.total + " fichiers (" + cache.version + ")" :
    "Cache non détecté";
  return [
    "JELLY BRICKS — DIAGNOSTIC LOCAL",
    "Écran : " + viewport + " pixels CSS (échelle " + scale + ")",
    "Commandes tactiles : " + (touch ? "oui" : "non détectées"),
    "Mode application installée : " + (standalone ? "oui" : "non"),
    "Stockage des parties : " + (storageOk ? "opérationnel" : "indisponible"),
    "Fichiers préparés hors ligne : " + cacheLine,
    "État réseau indiqué : " + (online ? "connecté" : "hors connexion"),
    "Rafraîchissement estimé : " + (refresh === null ? "non mesuré" : refresh + " images/s"),
    "",
    "La mesure d'affichage est indicative, ce n'est pas une mesure des FPS du jeu.",
    "Pour valider le mode hors ligne : lancer une partie, activer le mode avion,",
    "fermer complètement puis rouvrir l'application et vérifier la reprise.",
    "Aucune donnée de ce rapport n'est envoyée automatiquement."
  ].join("\n");
}
