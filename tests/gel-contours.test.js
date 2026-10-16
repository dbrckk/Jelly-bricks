import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, rotate } from "../src/game.js";
import { gelContours } from "../src/gel-contours.js";

const polygonArea = (points) => Math.abs(points.reduce((sum, p, i) => {
  const q = points[(i + 1) % points.length];
  return sum + p[0] * q[1] - q[0] * p[1];
}, 0) / 2);
const totalArea = (contours) => contours.reduce((sum, { outline, holes }) =>
  sum + polygonArea(outline) -
    holes.reduce((acc, hole) => acc + polygonArea(hole), 0), 0);

test("joined gel cells form one silhouette with no interior seams", () => {
  const contours = gelContours([[0, 0], [0, 1], [1, 0]]);
  assert.equal(contours.length, 1);
  assert.equal(contours[0].holes.length, 0);
  assert.equal(totalArea(contours), 3);
  assert.equal(contours[0].outline.length, 6);
});

test("each level's bricks retain the exact surface area across all rotations", () => {
  for (const level of LEVELS) {
    for (const piece of level.pieces) {
      for (let rotation = 0; rotation < 4; rotation++) {
        const cells = rotate(piece.cells, rotation);
        const outlines = gelContours(cells);
        assert.ok(outlines.length >= 1, level.name + " " + piece.id);
        assert.equal(totalArea(outlines), cells.length,
          level.name + " " + piece.id + " rotation " + rotation);
        for (const {outline, holes} of outlines) {
          assert.ok(outline.length >= 4);
          assert.ok(holes.every((hole) => hole.length >= 4));
        }
      }
    }
  }
});

test("a ring has a genuine hole rather than being filled solid", () => {
  const ring = [];
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 3; c++) {
      if (r !== 1 || c !== 1) ring.push([r, c]);
    }
  }
  const contours = gelContours(ring);
  assert.equal(contours.length, 1);
  assert.equal(contours[0].holes.length, 1);
  assert.equal(totalArea(contours), 8);
});

test("touching corners and separated islands never weld incorrectly", () => {
  const pieces = gelContours([[0, 0], [1, 1]]);
  assert.equal(pieces.length, 2);
  assert.equal(totalArea(pieces), 2);
  assert.deepEqual(gelContours([]), []);
});
