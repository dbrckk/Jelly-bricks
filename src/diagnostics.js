/**
 * Private, on-device PWA diagnostic. No network calls, identifiers, analytics
 * or access to the contents of the player's saved progress.
 */
export const OFFLINE_ASSETS = Object.freeze([
  "./index.html", "./styles.css", "./src/main.js", "./src/game.js",
  "./src/diagnostics.js"
]);

export function summarizeFrames(timestamps) {
  const intervals = [];
  for (let i = 1; i < timestamps.length; i++) {
    const delta = timestamps[i] - timestamps[i - 1];
    if (Number.isFinite(delta) && delta > 0) intervals.push(delta);
  }
  if (!intervals.length) return null;
  const sorted = [...intervals].sort((a, b) => a - b);
  const percentile = (p) => sorted[Math.min(sorted.length - 1, Math.ceil(p * sorted.length) - 1)];
  const medianMs = (sorted.length % 2)
    ? sorted[Math.floor(sorted.length / 2)]
    : (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2;
  return {
    frames: intervals.length,
    medianMs: Math.round(medianMs * 10) / 10,
    p95Ms: Math.round(percentile(.95) * 10) / 10,
    cadenceHz: Math.round(1000 / medianMs),
    delaysOver40Ms: intervals.filter((delta) => delta > 40).length
  };
}

/**
 * Measures animation callback cadence while the *existing* board remains
 * visible. This is not a benchmark of actual gameplay frame rate.
 */
export function sampleFrames(count = 75, raf = globalThis.requestAnimationFrame) {
  if (typeof raf !== "function") return Promise.resolve(null);
  return new Promise((resolve) => {
    const stamps = [];
    function frame(now) {
      stamps.push(now);
      if (stamps.length < count + 1) raf(frame);
      else resolve(summarizeFrames(stamps));
    }
    raf(frame);
  });
}

export async function checkOfflineCache({
  storage = globalThis.caches,
  serviceWorker = globalThis.navigator?.serviceWorker
} = {}) {
  let missing = [...OFFLINE_ASSETS];
  let controller = Boolean(serviceWorker?.controller);
  try {
    if (storage?.match) {
      const found = await Promise.all(OFFLINE_ASSETS.map(async (url) =>
        Boolean(await storage.match(url))));
      missing = OFFLINE_ASSETS.filter((_, i) => !found[i]);
    }
  } catch {
    // A restricted browser can reject CacheStorage access.
  }
  return {
    controller,
    total: OFFLINE_ASSETS.length,
    cached: OFFLINE_ASSETS.length - missing.length,
    missing,
    offlineReady: controller && missing.length === 0
  };
}

export function formatDeviceReport({ width, height, dpr, standalone, online, frames, offline }) {
  const lines = [
    "Jelly Bricks — Diagnostic local v0.6.1",
    "Affichage : " + width + " × " + height + " pixels CSS ; densité " + dpr,
    "Mode installé : " + (standalone ? "oui" : "non"),
    "Connexion signalée : " + (online ? "en ligne" : "hors ligne"),
    "Service worker : " + (offline.controller ? "actif" : "non actif"),
    "Fichiers disponibles en cache : " + offline.cached + "/" + offline.total,
    "Redémarrage hors connexion : " + (offline.offlineReady ? "prêt selon le cache" : "non confirmé"),
    "Rythme des images (écran statique) : " +
      (frames ? frames.cadenceHz + " Hz estimés, médiane " + frames.medianMs +
        " ms, p95 " + frames.p95Ms + " ms, retards >40 ms : " +
        frames.delaysOver40Ms + "/" + frames.frames : "indisponible"),
    "Attention : ce rythme ne mesure pas les FPS pendant une partie.",
    "Données calculées sur cet appareil ; aucun envoi automatique."
  ];
  if (offline.missing.length) lines.splice(7, 0,
    "Fichiers absents du cache : " + offline.missing.join(", "));
  return lines.join("\n");
}

export async function runDeviceDiagnostics() {
  const metrics = await Promise.all([
    sampleFrames(),
    checkOfflineCache()
  ]);
  return formatDeviceReport({
    width: globalThis.innerWidth,
    height: globalThis.innerHeight,
    dpr: globalThis.devicePixelRatio || 1,
    standalone: Boolean(globalThis.matchMedia?.("(display-mode: standalone)").matches ||
      globalThis.navigator?.standalone),
    online: globalThis.navigator?.onLine !== false,
    frames: metrics[0],
    offline: metrics[1]
  });
}
