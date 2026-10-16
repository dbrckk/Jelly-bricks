import test from "node:test";
import assert from "node:assert/strict";
import {
  GRAPHICS_STORAGE_KEY, GRAPHICS_MODES, normalizeGraphicsMode,
  graphicsProfile, graphicsModeDescription
} from "../src/graphics-quality.js";

test("graphics controls use stable validated, locally stored mode names", () => {
  assert.equal(GRAPHICS_STORAGE_KEY, "jelly-bricks-graphics-v1");
  assert.deepEqual([...GRAPHICS_MODES], ["auto", "eco", "high"]);
  assert.equal(normalizeGraphicsMode("unknown"), "auto");
  assert.equal(normalizeGraphicsMode(null), "auto");
  for (const mode of GRAPHICS_MODES) {
    assert.equal(normalizeGraphicsMode(mode), mode);
    assert.ok(graphicsModeDescription(mode).length > 15);
  }
});

test("Android auto stays within safe framebuffer budgets", () => {
  const auto = graphicsProfile("auto", { mobile: true, deviceMemory: 8, dpr: 3 });
  assert.equal(auto.tier, "balanced");
  assert.equal(auto.pixelRatio, 1.25);
  assert.equal(auto.reflectionSize, 64);
  assert.equal(auto.antialias, true);
  assert.equal(auto.transmission, .18);
  assert.equal(auto.iridescence, 0);
});

test("low-memory or data-saver Android automatically uses a cheap rendering path", () => {
  for (const hints of [{ deviceMemory: 1 }, { deviceMemory: 2 }, { saveData: true }]) {
    const tier = graphicsProfile("auto", { mobile: true, dpr: 3, ...hints });
    assert.equal(tier.tier, "eco");
    assert.equal(tier.pixelRatio, 1);
    assert.equal(tier.reflectionSize, 0);
    assert.equal(tier.transmission, 0);
    assert.equal(tier.antialias, false);
    assert.equal(tier.shadowOpacity, .28);
  }
});

test("explicit graphic quality overrides auto but keeps sensible pixel ratio bounds", () => {
  const eco = graphicsProfile("eco", { mobile: true, dpr: 3 });
  assert.equal(eco.pixelRatio, 1);
  assert.equal(eco.reflectionSize, 0);
  const high = graphicsProfile("high", { mobile: true, deviceMemory: 2, dpr: 3 });
  assert.equal(high.tier, "high");
  assert.equal(high.pixelRatio, 1.75);
  assert.equal(high.reflectionSize, 128);
  assert.ok(high.iridescence > 0);
  assert.ok(high.transmission > eco.transmission);
  const desktop = graphicsProfile("high", { mobile: false, dpr: 3 });
  assert.equal(desktop.pixelRatio, 2);
  assert.equal(desktop.reflectionSize, 256);
});

test("invalid device pixel ratios cannot produce unsafe or NaN canvas sizes", () => {
  for (const dpr of [-5, 0, Infinity, NaN, undefined, 1, 1.5, 4]) {
    for (const mode of GRAPHICS_MODES) {
      const p = graphicsProfile(mode, { mobile: true, dpr });
      assert.ok(Number.isFinite(p.pixelRatio));
      assert.ok(p.pixelRatio > 0 && p.pixelRatio <= 1.75);
    }
  }
});
