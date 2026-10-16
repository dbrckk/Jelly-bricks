import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, evaluate } from "../src/game.js";
import { resolveMagneticPlacement } from "../src/magnet.js";

test("exact user choice always takes priority over nearby valid alternatives", () => {
  const level = LEVELS[0];
  const piece = level.pieces[0];
  const { row, col } = piece.solution;
  const result = resolveMagneticPlacement(level, {}, piece.id, row, col, 0);
  assert.ok(result);
  assert.equal(result.snapped, false);
  assert.deepEqual(result.position, {row, col});
});

test("a touch dropped one column off snaps back to the nearest valid spot", () => {
  const level = LEVELS[0];
  const piece = level.pieces[0];
  const { row, col } = piece.solution;
  const result = resolveMagneticPlacement(level, {}, piece.id, row, col + 1, 0);
  assert.ok(result);
  assert.equal(result.snapped, true);
  assert.deepEqual(result.position, {row, col});
  assert.deepEqual(result.placements[piece.id], {row, col, rotation: 0});
});

test("invalid or distant drops cannot teleport bricks around a puzzle", () => {
  const level = LEVELS[0];
  const piece = level.pieces[0];
  assert.equal(resolveMagneticPlacement(level, {}, piece.id, -8, 9, 0), null);
  assert.equal(resolveMagneticPlacement(level, {}, piece.id, 1.5, 2, 0), null);
  assert.equal(resolveMagneticPlacement(level, {}, piece.id, 0, 3, 0), null);
});

test("magnetic support retains all existing collision and scoring rules", () => {
  for (const level of LEVELS) {
    let placements = {};
    for (const piece of level.pieces) {
      const { row, col } = piece.solution;
      const next = resolveMagneticPlacement(level, placements, piece.id, row, col, 0);
      assert.ok(next, level.name + " " + piece.id);
      assert.equal(next.snapped, false);
      placements = next.placements;
    }
    assert.equal(evaluate(level, placements).won, true, level.name);
  }
});
