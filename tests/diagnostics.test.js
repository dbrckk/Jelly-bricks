import test from "node:test";
import assert from "node:assert/strict";
import { OFFLINE_ASSETS, summarizeFrames, sampleFrames,
  checkOfflineCache, formatDeviceReport } from "../src/diagnostics.js";

test("frame cadence estimates median, p95 and long delays deterministically", () => {
  assert.equal(summarizeFrames([]), null);
  assert.equal(summarizeFrames([10]), null);
  assert.deepEqual(summarizeFrames([0, 10, 20, 30, 80]), {
    frames: 4, medianMs: 10, p95Ms: 50, cadenceHz: 100,
    delaysOver40Ms: 1
  });
  assert.equal(summarizeFrames([1, NaN, 0]), null);
});

test("sampling accepts an injected animation clock without timers", async () => {
  let next = 0;
  const result = await sampleFrames(4, (callback) => callback(next += 20));
  assert.deepEqual(result, {
    frames: 4, medianMs: 20, p95Ms: 20, cadenceHz: 50, delaysOver40Ms: 0
  });
  assert.equal(await sampleFrames(4, null), null);
});

test("offline status only claims readiness when both controller and assets exist", async () => {
  const storage = { async match() { return { ok: true }; } };
  const missingController = await checkOfflineCache({ storage, serviceWorker: {} });
  assert.equal(missingController.offlineReady, false);
  assert.equal(missingController.cached, OFFLINE_ASSETS.length);
  const good = await checkOfflineCache({
    storage, serviceWorker: { controller: {} }
  });
  assert.equal(good.offlineReady, true);
  const incomplete = await checkOfflineCache({
    storage: { async match(url) { return url !== "./src/diagnostics.js" ? {} : null; } },
    serviceWorker: { controller: {} }
  });
  assert.equal(incomplete.offlineReady, false);
  assert.deepEqual(incomplete.missing, ["./src/diagnostics.js"]);
  const restricted = await checkOfflineCache({
    storage: { async match() { throw new Error("not permitted"); } },
    serviceWorker: { controller: {} }
  });
  assert.equal(restricted.offlineReady, false);
});

test("report explicitly distinguishes callback cadence from in-game FPS", () => {
  const report = formatDeviceReport({
    width: 390, height: 844, dpr: 3, standalone: false, online: true,
    frames: { cadenceHz: 60, medianMs: 16.7, p95Ms: 18.2,
      delaysOver40Ms: 0, frames: 75 },
    offline: { controller: true, cached: 5, total: 5, missing: [],
      offlineReady: true }
  });
  assert.match(report, /390 × 844/);
  assert.match(report, /60 Hz/);
  assert.match(report, /ne mesure pas les FPS pendant une partie/);
  assert.match(report, /aucun envoi automatique/);
  assert.doesNotMatch(report, /androidId|userAgent|adresse IP/);
});
