import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS } from "../src/game.js";
import { touchingGelNeighbors, gelNeighborRipple } from "../src/gel-reactions.js";

test("landing jelly nudges only adjacent already-placed pieces", () => {
  const level = LEVELS[0];
  const poses = Object.fromEntries(level.pieces.map(({ id, solution }) =>
    [id, solution]));
  assert.deepEqual(touchingGelNeighbors(level, {}, "A"), []);
  assert.deepEqual(touchingGelNeighbors(level, { A: poses.A }, "A"), []);
  const joined = touchingGelNeighbors(level, { A: poses.A, B: poses.B }, "B");
  assert.deepEqual(joined.map(({ id }) => id), ["A"]);
  assert.ok(joined[0].edges > 0);
  const all = touchingGelNeighbors(level, poses, "C");
  assert.deepEqual(new Set(all.map(x => x.id)), new Set(["A", "B"]));
});

test("edge contacts are symmetric throughout all 21 levels", () => {
  for (const level of LEVELS) {
    const placements = Object.fromEntries(level.pieces.map(({ id, solution }) =>
      [id, solution]));
    for (const piece of level.pieces) {
      const adjacent = touchingGelNeighbors(level, placements, piece.id);
      for (const contact of adjacent) {
        assert.ok(contact.edges > 0 && Number.isInteger(contact.edges));
        const reverse = touchingGelNeighbors(level, placements, contact.id)
          .find(entry => entry.id === piece.id);
        assert.equal(contact.edges, reverse?.edges, level.name + " " + piece.id);
      }
    }
  }
});

test("touching at a diagonal corner does not transmit a ripple", () => {
  const level = {
    size: 3, pieces: [{ id: "A", cells: [[0, 0]] },
      { id: "B", cells: [[0, 0]] }]
  };
  const poses = {
    A: { row: 0, col: 0, rotation: 0 },
    B: { row: 1, col: 1, rotation: 0 }
  };
  assert.deepEqual(touchingGelNeighbors(level, poses, "A"), []);
  poses.B.row = 0;
  assert.deepEqual(touchingGelNeighbors(level, poses, "A"),
    [{ id: "B", edges: 1 }]);
});

test("neighbor ripple is delayed, damped, bounded and returns to rest", () => {
  assert.deepEqual(gelNeighborRipple(0), { scale: 1, twist: 0 });
  assert.deepEqual(gelNeighborRipple(.1), { scale: 1, twist: 0 });
  assert.deepEqual(gelNeighborRipple(1), { scale: 1, twist: 0 });
  assert.deepEqual(gelNeighborRipple(Number.NaN), { scale: 1, twist: 0 });
  assert.deepEqual(gelNeighborRipple(.3, 0), { scale: 1, twist: 0 });
  let reacted = false;
  for (let i = 0; i <= 120; i++) {
    const result = gelNeighborRipple(i / 120, 3);
    assert.ok(result.scale >= .955 && result.scale <= 1.045);
    assert.ok(Math.abs(result.twist) <= .042);
    if (Math.abs(result.twist) > .001) reacted = true;
  }
  assert.ok(reacted, "Neighbor spring must actually move the jelly");
});
