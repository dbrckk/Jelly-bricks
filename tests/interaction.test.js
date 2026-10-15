import test from "node:test";
import assert from "node:assert/strict";
import { gridCellAt, anchoredDrop } from "../src/interaction.js";

const rect = { left: 10, top: 20, width: 414, height: 414 };

test("pixel locations map to cells with equal size, excluding padding", () => {
  assert.deepEqual(gridCellAt(rect, 4, 17, 27), {row: 0, col: 0});
  assert.deepEqual(gridCellAt(rect, 4, 117, 127), {row: 1, col: 1});
  assert.deepEqual(gridCellAt(rect, 4, 416, 426), {row: 3, col: 3});
  assert.equal(gridCellAt(rect, 4, 16, 40), null);
  assert.equal(gridCellAt(rect, 4, 418, 40), null);
  assert.equal(gridCellAt(rect, 4, 50, 427), null);
});

test("anchor preserves the grabbed cube rather than snapping to top-left", () => {
  // User grabs the middle cell of a three-cube shape and drags to row 2, col 3.
  assert.deepEqual(anchoredDrop(rect, 4, 367, 277, 0, 1), {row: 2, col: 2});
  assert.deepEqual(anchoredDrop(rect, 4, 367, 277, 1, 0), {row: 1, col: 3});
  assert.deepEqual(anchoredDrop(rect, 4, 367, 277), {row: 2, col: 3});
});

test("invalid pointer and geometry never return a placement", () => {
  assert.equal(anchoredDrop(rect, 4, 0, 0, 0, 0), null);
  assert.equal(anchoredDrop(rect, 4, 50, 50, -1, 0), null);
  assert.equal(anchoredDrop(rect, 4, 50, 50, 0.5, 1), null);
  assert.equal(gridCellAt({ left: 0, top: 0, width: 10, height: 10 }, 4, 4, 4), null);
  assert.equal(gridCellAt(rect, 0, 20, 20), null);
});

test("non-square boards remain geometrically correct", () => {
  const wide = {left: 0, top: 0, width: 600, height: 200};
  assert.deepEqual(gridCellAt(wide, 5, 538, 168), {row: 4, col: 4});
});
