import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, rotate, absoluteCells } from "../src/game.js";
import { surfaceNeighbors, applySurfaceClasses } from "../src/material.js";

test("adjacent jelly cells share exactly one internal edge", () => {
  const cells = [[0, 0], [0, 1], [1, 1]];
  assert.deepEqual(surfaceNeighbors(cells, 0, 0), {
    top: false, right: true, bottom: false, left: false
  });
  assert.deepEqual(surfaceNeighbors(cells, 0, 1), {
    top: false, right: false, bottom: true, left: true
  });
  assert.deepEqual(surfaceNeighbors(cells, 1, 1), {
    top: true, right: false, bottom: false, left: false
  });
});

test("edge geometry remains symmetric in all twenty-one authored levels", () => {
  for (const level of LEVELS) {
    for (const piece of level.pieces) {
      for (const quarterTurn of [0, 1, 2, 3]) {
        const cells = rotate(piece.cells, quarterTurn);
        const position = new Set(cells.map(([r, c]) => r + "," + c));
        for (const [r, c] of cells) {
          const sides = surfaceNeighbors(cells, r, c);
          assert.equal(sides.top, position.has((r - 1) + "," + c));
          assert.equal(sides.right, position.has(r + "," + (c + 1)));
          assert.equal(sides.bottom, position.has((r + 1) + "," + c));
          assert.equal(sides.left, position.has(r + "," + (c - 1)));
          if (sides.right) assert.equal(surfaceNeighbors(cells, r, c + 1).left, true);
          if (sides.bottom) assert.equal(surfaceNeighbors(cells, r + 1, c).top, true);
        }
      }
      const absolute = absoluteCells(piece, piece.solution);
      assert.equal(absolute.length, piece.cells.length);
    }
  }
});

test("class generation marks only joined edges and leaves unrelated classes intact", () => {
  const known = new Set(["jelly"]);
  const element = { classList: { add(name) { known.add(name); } } };
  const result = applySurfaceClasses(element, [[0, 0], [0, 1]], 0, 0);
  assert.equal(result, element);
  assert.deepEqual([...known].sort(), ["jelly", "join-right"]);
  const solo = new Set();
  applySurfaceClasses({ classList: { add(name) { solo.add(name); } } }, [[0, 0]], 0, 0);
  assert.equal(solo.size, 0);
});
