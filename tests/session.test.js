import test from "node:test";
import assert from "node:assert/strict";
import { LEVELS, solvedPlacement } from "../src/game.js";
import { SESSION_VERSION, emptySessionBook, recoverSession,
  parseSessionBook, saveSession, discardSession } from "../src/session.js";

const level = LEVELS[0];
const rotations = Object.fromEntries(level.pieces.map((piece) => [piece.id, 0]));
const incomplete = { placements: {}, rotations, moves: 2,
  hints: 1, mistakes: 0, elapsedSeconds: 35 };

test("empty and broken local storage use a safe new book", () => {
  assert.deepEqual(parseSessionBook(null, LEVELS), emptySessionBook());
  assert.deepEqual(parseSessionBook("{broken", LEVELS), emptySessionBook());
  assert.deepEqual(parseSessionBook("x".repeat(101_000), LEVELS), emptySessionBook());
  assert.deepEqual(parseSessionBook(JSON.stringify({ version: 999, levels: {} }), LEVELS),
    emptySessionBook());
});

test("saving and restoring a partially assembled level survives JSON roundtrip", () => {
  const placements = solvedPlacement(level);
  delete placements[level.pieces[1].id];
  delete placements[level.pieces[2].id];
  const original = { ...incomplete, placements };
  const book = saveSession(emptySessionBook(), level, original, 59.8);
  assert.equal(book.version, SESSION_VERSION);
  const restored = parseSessionBook(JSON.stringify(book), LEVELS);
  assert.deepEqual(recoverSession(level, restored.levels[level.id]), {
    ...original, elapsedSeconds: 59
  });
});

test("sessions from separate levels persist when navigating between them", () => {
  const first = saveSession(emptySessionBook(), level, incomplete, 12);
  const second = saveSession(first, LEVELS[1], {
    ...incomplete, rotations: Object.fromEntries(LEVELS[1].pieces.map((piece) => [piece.id, 0]))
  }, 22);
  assert.equal(Object.keys(second.levels).length, 2);
  assert.equal(second.activeLevelId, 2);
  const loaded = parseSessionBook(JSON.stringify(second), LEVELS);
  assert.equal(loaded.levels[1].elapsedSeconds, 12);
  assert.equal(loaded.levels[2].elapsedSeconds, 22);
  const cleared = discardSession(loaded, 2, 1);
  assert.equal(cleared.levels[2], undefined);
  assert.deepEqual(cleared.levels[1], loaded.levels[1]);
});

test("colliding, tampered and out-of-bounds pieces are rejected", () => {
  const placed = solvedPlacement(level);
  const pieces = level.pieces;
  const bad = { ...incomplete, levelId: level.id,
    placements: { ...placed, [pieces[1].id]: placed[pieces[0].id] } };
  assert.equal(recoverSession(level, bad), null);
  assert.equal(recoverSession(level, {
    ...bad, placements: { [pieces[0].id]: {row: 999, col: 0, rotation: 0} }
  }), null);
  assert.equal(recoverSession(level, {
    ...bad, placements: { X: {row: 0, col: 0, rotation: 0} }
  }), null);
  assert.equal(recoverSession(level, { ...bad, moves: -1 }), null);
  assert.equal(recoverSession(level, { ...bad, moves: Infinity }), null);
  assert.equal(recoverSession(level, { ...bad, levelId: 123 }), null);
  assert.equal(recoverSession(level, { ...bad, rotations: { ...rotations, A: 6 } }), null);
  assert.equal(recoverSession(level, { ...bad, rotations: { ...rotations, A: 2.5 } }), null);
});

test("a previously completed level cannot be restored as an unfinished game", () => {
  assert.equal(recoverSession(level, {
    ...incomplete, levelId: level.id, placements: solvedPlacement(level)
  }), null);
});

test("invalid sessions are isolated so other levels still load", () => {
  const valid = saveSession(emptySessionBook(), level, incomplete, 100);
  const book = {
    ...valid, levels: { ...valid.levels, 2: { levelId: 2, placements: { Z: {} } } }
  };
  const result = parseSessionBook(JSON.stringify(book), LEVELS);
  assert.ok(result.levels[1]);
  assert.equal(result.levels[2], undefined);
});
