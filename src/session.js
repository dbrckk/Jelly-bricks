import { attemptPlacement, evaluate } from "./game.js";

export const SESSION_KEY = "jelly-bricks-sessions-v1";
export const SESSION_VERSION = 1;

function record(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
function count(value, max = 1_000_000_000) {
  return Number.isSafeInteger(value) && value >= 0 && value <= max;
}

export function emptySessionBook() {
  return { version: SESSION_VERSION, activeLevelId: 1, levels: {} };
}

/**
 * Treat localStorage as untrusted, potentially stale input.
 * Recreate every placement via the same collision/bounds rules as the game.
 */
export function recoverSession(level, input) {
  if (!record(input) || input.levelId !== level.id ||
      !record(input.placements) || !record(input.rotations) ||
      !count(input.moves) || !count(input.hints) ||
      !count(input.mistakes) || !count(input.elapsedSeconds)) return null;

  const ids = new Set(level.pieces.map((piece) => piece.id));
  if (Object.keys(input.placements).some((id) => !ids.has(id)) ||
      Object.keys(input.rotations).some((id) => !ids.has(id))) return null;

  const rotations = {};
  let placements = {};
  for (const piece of level.pieces) {
    const turn = input.rotations[piece.id];
    if (!Number.isInteger(turn) || turn < 0 || turn > 3) return null;
    rotations[piece.id] = turn;
    if (!Object.hasOwn(input.placements, piece.id)) continue;
    const place = input.placements[piece.id];
    if (!record(place) || !Number.isInteger(place.row) || !Number.isInteger(place.col) ||
        place.rotation !== turn) return null;
    const next = attemptPlacement(level, placements, piece.id,
      place.row, place.col, place.rotation);
    if (!next) return null;
    placements = next;
  }

  // Completed games are handled by the reward path and never resumed mid-dialog.
  if (evaluate(level, placements).won) return null;

  return {
    placements, rotations,
    moves: input.moves, hints: input.hints,
    mistakes: input.mistakes, elapsedSeconds: input.elapsedSeconds
  };
}

export function parseSessionBook(raw, levels) {
  const clean = emptySessionBook();
  if (typeof raw !== "string" || raw.length > 100_000) return clean;
  try {
    const data = JSON.parse(raw);
    if (!record(data) || data.version !== SESSION_VERSION || !record(data.levels)) return clean;
    for (const level of levels) {
      const recovered = recoverSession(level, data.levels[level.id]);
      if (recovered) clean.levels[level.id] = {
        levelId: level.id, ...recovered
      };
    }
    if (count(data.activeLevelId, levels.length) && data.activeLevelId > 0)
      clean.activeLevelId = data.activeLevelId;
  } catch { /* Corrupted storage must never prevent the game from loading. */ }
  return clean;
}

export function saveSession(book, level, state, elapsedSeconds) {
  const session = {
    levelId: level.id,
    placements: state.placements,
    rotations: state.rotations,
    moves: state.moves,
    hints: state.hints,
    mistakes: state.mistakes,
    elapsedSeconds: Math.floor(elapsedSeconds)
  };
  // Round-trip validation ensures only recoverable snapshots reach storage.
  const valid = recoverSession(level, session);
  const next = { version: SESSION_VERSION, activeLevelId: level.id,
    levels: { ...book.levels } };
  if (valid) next.levels[level.id] = { levelId: level.id, ...valid };
  else delete next.levels[level.id];
  return next;
}

export function discardSession(book, levelId, nextActiveId = levelId) {
  const next = { version: SESSION_VERSION, activeLevelId: nextActiveId,
    levels: { ...book.levels } };
  delete next.levels[levelId];
  return next;
}
