import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, rotate } from "../src/game.js";
import { jellyImpact, jellyPivot } from "../src/jelly-physics.js";

test("gel spring always returns to the exact resting position", () => {
  const start = jellyImpact(0);
  assert.deepEqual(
    { sx: start.scaleX, sy: start.scaleY, sz: start.scaleZ, lift: start.lift },
    { sx: 1, sy: 1, sz: 1, lift: .28 }
  );
  const end = jellyImpact(1);
  assert.deepEqual(end, {
    scaleX: 1, scaleY: 1, scaleZ: 1, lift: 0, bend: 0, phase: 0
  });
  assert.deepEqual(jellyImpact(20), end);
  assert.deepEqual(jellyImpact(NaN), end);
});

test("gel surface deforms temporarily but never collapses or exceeds safety bounds", () => {
  let bent = false;
  let stretched = false;
  for (let frame = 0; frame <= 120; frame++) {
    const f = jellyImpact(frame / 120);
    for (const v of [f.scaleX, f.scaleY, f.scaleZ, f.lift, f.bend, f.phase]) {
      assert.ok(Number.isFinite(v));
    }
    assert.ok(f.scaleX > .85 && f.scaleX < 1.15);
    assert.ok(f.scaleZ > .80 && f.scaleZ < 1.20);
    assert.ok(f.lift >= 0 && f.lift <= .28);
    assert.ok(Math.abs(f.bend) < .085);
    if (Math.abs(f.bend) > .01) bent = true;
    if (Math.abs(f.scaleX - 1) > .02) stretched = true;
  }
  assert.equal(bent, true);
  assert.equal(stretched, true);
});

test("every authored piece and rotation has a finite piece-centered pivot", () => {
  for (const level of LEVELS) {
    for (const piece of level.pieces) {
      for (let rotation = 0; rotation < 4; rotation++) {
        const cells = rotate(piece.cells, rotation);
        const pivot = jellyPivot(cells, piece.solution.row,
          piece.solution.col, level.size, 1 / Math.cos(Math.atan(.33)));
        assert.ok(Number.isFinite(pivot.x) && Number.isFinite(pivot.y));
        const worldX = cells.map(([, col]) =>
          piece.solution.col + col - (level.size - 1) / 2);
        const worldY = cells.map(([row]) =>
          ((level.size - 1) / 2 - piece.solution.row - row) /
            Math.cos(Math.atan(.33)));
        assert.equal(pivot.x, (Math.min(...worldX) + Math.max(...worldX)) / 2);
        assert.ok(Math.abs(pivot.y - (Math.min(...worldY) +
          Math.max(...worldY)) / 2) < 1e-10);
      }
    }
  }
});

test("single cube squeeze remains anchored at its exact physical center", () => {
  assert.deepEqual(jellyPivot([[0, 0]], 2, 3, 7),
    { x: 0, y: 1 });
  assert.throws(() => jellyPivot([], 0, 0, 4), RangeError);
});
