import test from "node:test";
import assert from "node:assert/strict";
import { DIAGNOSTIC_ASSETS, checkStorage, checkOfflineCache,
  measureRefresh, formatDiagnostic } from "../src/diagnostics.js";

test("storage probe preserves existing values and detects unavailable storage", () => {
  const values = new Map([["jelly-bricks-diagnostic-probe", "previous"]]);
  const store = {
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, value); },
    removeItem(key) { values.delete(key); }
  };
  assert.equal(checkStorage(store), true);
  assert.equal(values.get("jelly-bricks-diagnostic-probe"), "previous");
  values.delete("jelly-bricks-diagnostic-probe");
  assert.equal(checkStorage(store), true);
  assert.equal(values.has("jelly-bricks-diagnostic-probe"), false);
  assert.equal(checkStorage(null), false);
  assert.equal(checkStorage({ getItem() { throw Error("blocked"); } }), false);
});

test("offline check picks latest numbered Jelly Bricks cache and verifies real URLs", async () => {
  const requests = [];
  const results = await checkOfflineCache({
    async keys() { return ["another-app", "jelly-bricks-static-v7",
      "jelly-bricks-static-v12", "jelly-bricks-static-v9"]; },
    async open(name) {
      assert.equal(name, "jelly-bricks-static-v12");
      return { async match(url) { requests.push(url); return { status: 200 }; } };
    }
  }, "https://test.example/Jelly-bricks/");
  assert.deepEqual(results, {
    version: "jelly-bricks-static-v12",
    found: DIAGNOSTIC_ASSETS.length, total: DIAGNOSTIC_ASSETS.length
  });
  assert.ok(requests.every(url => url.startsWith("https://test.example/Jelly-bricks/")));
});

test("offline check fails closed for missing or restricted caches", async () => {
  const empty = { version: null, found: 0, total: DIAGNOSTIC_ASSETS.length };
  assert.deepEqual(await checkOfflineCache(null, "https://test.example/app/"), empty);
  assert.deepEqual(await checkOfflineCache({ async keys() { return ["some-app"]; } },
    "https://test.example/app/"), empty);
  assert.deepEqual(await checkOfflineCache({
    async keys() { throw new Error("cache disabled"); }
  }, "https://test.example/app/"), empty);
});

test("refresh sample counts callbacks without a fixed device FPS assumption", async () => {
  let time = 0;
  const fps = await measureRefresh((callback) =>
    queueMicrotask(() => callback(time += 1000 / 60)), 1000);
  assert.ok(fps >= 55 && fps <= 65, String(fps));
  await assert.rejects(measureRefresh(null), /indisponible/);
});

test("diagnostic report is readable, private and doesn't claim game FPS", () => {
  const report = formatDiagnostic({
    viewport: "390 × 844", scale: 3, touch: true,
    standalone: false, storageOk: true, online: false,
    cache: { version: "jelly-bricks-static-v12", found: 6, total: 6 },
    refresh: 60
  });
  assert.match(report, /390 × 844/);
  assert.match(report, /6\/6 fichiers/);
  assert.match(report, /60 images\/s/);
  assert.match(report, /hors connexion/);
  assert.match(report, /pas une mesure des FPS du jeu/);
  assert.match(report, /Aucune donnée.*envoyée automatiquement/);
});
