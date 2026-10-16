import test from "node:test";
import assert from "node:assert/strict";
import { GEL_OPTICS, studioProfile } from "../src/gel-lighting.js";

test("studio lighting uses physically bounded, transparent jelly material", () => {
  for (const key of ["roughness", "clearcoat", "clearcoatRoughness",
    "transmission", "emissiveIntensity", "metalness"]) {
    assert.ok(GEL_OPTICS[key] >= 0 && GEL_OPTICS[key] <= 1, key);
  }
  assert.ok(GEL_OPTICS.ior >= 1 && GEL_OPTICS.ior <= 1.6);
  assert.ok(GEL_OPTICS.thickness > 0);
  assert.ok(GEL_OPTICS.attenuationDistance > 0);
  assert.equal(Object.isFrozen(GEL_OPTICS), true);
});

test("mobile lighting limits device pixel ratio and environment resolution", () => {
  assert.deepEqual(studioProfile({ mobile: true, deviceMemory: 8, dpr: 3 }), {
    pixelRatio: 1.25, reflectionSize: 64, environmentIntensity: .72,
    shadowOpacity: .35, contactScale: 1.085,
    transmissionScale: .55, microBubbles: true
  });
  assert.deepEqual(studioProfile({ mobile: false, deviceMemory: 8, dpr: 3 }), {
    pixelRatio: 1.5, reflectionSize: 128, environmentIntensity: .85,
    shadowOpacity: .35, contactScale: 1.085,
    transmissionScale: .75, microBubbles: true
  });
});

test("very weak mobile devices avoid environment precomputation", () => {
  const result = studioProfile({ mobile: true, deviceMemory: 2, dpr: 3 });
  assert.equal(result.pixelRatio, 1);
  assert.equal(result.reflectionSize, 0);
  assert.equal(result.transmissionScale, .4);
  assert.equal(result.microBubbles, false);
  assert.ok(result.shadowOpacity < studioProfile({ mobile: true }).shadowOpacity);
  assert.equal(studioProfile({ mobile: true, deviceMemory: 0, dpr: 0 }).pixelRatio, 1);
  assert.equal(studioProfile({ mobile: true, deviceMemory: NaN, dpr: NaN }).pixelRatio, 1);
});

test("profile values remain well-defined for varied mobile screens", () => {
  for (const mobile of [true, false]) {
    for (const deviceMemory of [1, 2, 3, 4, 6, 12, undefined]) {
      for (const dpr of [1, 1.5, 2, 3, 4]) {
        const profile = studioProfile({ mobile, deviceMemory, dpr });
        assert.ok(profile.pixelRatio > 0 && profile.pixelRatio <= 1.5);
        assert.ok([0, 64, 128].includes(profile.reflectionSize));
        assert.ok(profile.shadowOpacity > 0 && profile.shadowOpacity < 1);
        assert.ok(profile.transmissionScale >= .4 && profile.transmissionScale <= .75);
        assert.equal(typeof profile.microBubbles, "boolean");
      }
    }
  }
});
