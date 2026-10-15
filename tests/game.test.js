import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, normalize, rotate, bounds, attemptPlacement,
  evaluate, absoluteCells, pieceAt, solvedPlacement } from "../src/game.js";

test("twenty-one progressive, solvable levels are available", () => {
  assert.equal(LEVELS.length, 21);
  for (const level of LEVELS) {
    assert.ok(level.total > 0);
    assert.equal(level.pieces.reduce((sum, piece) => sum + piece.cells.length, 0), level.total);
    for (const piece of level.pieces) {
      const queue = [piece.cells[0]];
      const visited = new Set();
      const occupied = new Set(piece.cells.map(([r, c]) => r + "," + c));
      while (queue.length) {
        const [r, c] = queue.pop();
        const key = r + "," + c;
        if (visited.has(key)) continue;
        visited.add(key);
        for (const [nr, nc] of [[r - 1, c], [r + 1, c], [r, c - 1], [r, c + 1]]) {
          if (occupied.has(nr + "," + nc) && !visited.has(nr + "," + nc)) queue.push([nr, nc]);
        }
      }
      assert.equal(visited.size, piece.cells.length, level.name + ": " + piece.id + " is disconnected");
    }
  }
});

test("rotations conserve shapes and four turns return to their origin", () => {
  for (const level of LEVELS) {
    for (const piece of level.pieces) {
      assert.deepEqual(rotate(piece.cells, 4), normalize(piece.cells));
      for (let turns = 0; turns < 4; turns++) {
        const transformed = rotate(piece.cells, turns);
        assert.equal(transformed.length, piece.cells.length);
        assert.equal(new Set(transformed.map((cell) => cell.join(","))).size, piece.cells.length);
        assert.ok(bounds(transformed).rows <= level.size);
        assert.ok(bounds(transformed).cols <= level.size);
      }
    }
  }
});

test("the authored solution can be placed and wins every level", () => {
  for (const level of LEVELS) {
    const placements = solvedPlacement(level);
    assert.equal(Object.keys(placements).length, level.pieces.length);
    assert.deepEqual(evaluate(level, placements),
      { correct: level.total, filled: level.total, total: level.total, won: true });
    for (const piece of level.pieces) {
      for (const [row, col] of absoluteCells(piece, placements[piece.id])) {
        assert.equal(pieceAt(level, placements, row, col), piece.id);
      }
    }
  }
});

test("placement rejects collisions, out-of-bounds moves and holes", () => {
  const level = LEVELS[0];
  const first = level.pieces[0];
  const correct = attemptPlacement(level, {}, first.id,
    first.solution.row, first.solution.col, 0);
  assert.ok(correct);
  assert.equal(attemptPlacement(level, correct, first.id, -1, 0, 0), null);
  assert.equal(attemptPlacement(level, correct, first.id, 0, level.size, 0), null);
  assert.equal(attemptPlacement(level, correct, first.id, 0.5, 1, 0), null);
  assert.equal(attemptPlacement(level, correct, "unknown", 0, 0, 0), null);
  const nextPiece = level.pieces[1];
  assert.equal(attemptPlacement(level, correct, nextPiece.id,
    first.solution.row, first.solution.col, 0), null);
});

test("moving a piece does not collide with itself and does not mutate history", () => {
  const level = LEVELS[0];
  const first = level.pieces[0];
  const original = attemptPlacement(level, {}, first.id,
    first.solution.row, first.solution.col, 0);
  const duplicated = attemptPlacement(level, original, first.id,
    first.solution.row, first.solution.col, 0);
  assert.deepEqual(duplicated, original);
  assert.notEqual(duplicated, original);
  assert.deepEqual(Object.keys(original), [first.id]);
});

test("a partially filled grid never wins", () => {
  const level = LEVELS[1];
  const piece = level.pieces[0];
  const placed = attemptPlacement(level, {}, piece.id,
    piece.solution.row, piece.solution.col, 0);
  const result = evaluate(level, placed);
  assert.equal(result.filled, piece.cells.length);
  assert.equal(result.correct, piece.cells.length);
  assert.equal(result.won, false);
});

test("the original six levels and their stable identifiers remain unchanged", () => {
  assert.deepEqual(LEVELS.slice(0, 6).map((l) => l.name), [
    "Premiers bonbons", "Le carré magique", "Bouquet de gelées",
    "Arc-en-ciel", "Confiserie", "Maître des briques"
  ]);
  assert.deepEqual(LEVELS.map((l) => l.id), Array.from({length: 21}, (_, i) => i + 1));
});

test("new pictogram levels have unique continuous color pieces", () => {
  for (const l of LEVELS.slice(6)) {
    assert.equal(l.size, 7, l.name);
    assert.ok(l.pieces.length >= 5 && l.pieces.length <= 11, l.name);
    assert.equal(new Set(l.pieces.map((p) => p.color)).size, l.pieces.length, l.name);
    assert.ok(l.total >= 18, l.name);
  }
});
