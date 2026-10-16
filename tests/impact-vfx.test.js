import test from "node:test";
import assert from "node:assert/strict";
import { impactParticleCount, impactSample } from "../src/impact-vfx.js";

test("mobile effects respect GPU quality and reduced motion", () => {
  assert.equal(impactParticleCount("eco"), 0);
  assert.equal(impactParticleCount("balanced"), 7);
  assert.equal(impactParticleCount("high"), 12);
  for (const tier of ["eco", "balanced", "high"]) {
    assert.equal(impactParticleCount(tier, true), 0);
  }
});

test("every animated bead follows a finite trajectory and shrinks away", () => {
  for (const count of [1, 7, 12]) {
    for (let index = 0; index < count; index++) {
      for (let step = 0; step <= 50; step++) {
        const p = impactSample(step / 50, index, count);
        assert.ok(Object.values(p).every(Number.isFinite));
        assert.ok(p.scale > 0 && p.scale <= 1);
        assert.ok(p.fade >= 0 && p.fade <= 1);
        assert.ok(p.ringFade >= 0 && p.ringFade <= 1);
        assert.ok(p.ringScale >= .32 && p.ringScale <= 1.47 + 1e-9);
        assert.ok(p.z >= .14 && p.z <= .8);
      }
    }
  }
});

test("impact sparkle spreads radially and terminates without a permanent loop", () => {
  const start = impactSample(0, 0, 7);
  const mid = impactSample(.45, 0, 7);
  const end = impactSample(1, 0, 7);
  assert.ok(Math.hypot(mid.x, mid.y) > Math.hypot(start.x, start.y));
  assert.ok(Math.hypot(end.x, end.y) > Math.hypot(start.x, start.y));
  assert.equal(end.fade, 0);
  assert.equal(end.ringFade, 0);
  assert.deepEqual(impactSample(3, 0, 7), end);
  assert.deepEqual(impactSample(Number.NaN, 0, 7), end);
});

test("different beads form a radial burst instead of following one line", () => {
  const points = Array.from({ length: 12 }, (_, i) => impactSample(.4, i, 12));
  assert.equal(new Set(points.map(p => Math.round(Math.atan2(p.y, p.x) * 100))).size, 12);
});
