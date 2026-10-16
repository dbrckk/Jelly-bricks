import { absoluteCells, findPiece } from "./game.js";

/**
 * Physical contact graph between an arriving jelly piece and already placed
 * pieces. No diagonal or color-based shortcuts: only shared grid edges count.
 * Sorted output is deterministic for tests and stable frame-to-frame.
 */
export function touchingGelNeighbors(level, placements, landingId) {
  const landing = findPiece(level, landingId);
  const pose = placements?.[landingId];
  if (!landing || !pose) return [];

  const occupied = new Map();
  for (const piece of level.pieces) {
    if (piece.id === landingId || !placements[piece.id]) continue;
    for (const [row, col] of absoluteCells(piece, placements[piece.id])) {
      occupied.set(row + "," + col, piece.id);
    }
  }

  const counts = new Map();
  for (const [row, col] of absoluteCells(landing, pose)) {
    for (const [dr, dc] of [[-1, 0], [0, 1], [1, 0], [0, -1]]) {
      const adjacentId = occupied.get((row + dr) + "," + (col + dc));
      if (adjacentId) counts.set(adjacentId, (counts.get(adjacentId) || 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([id, edges]) => ({ id, edges }))
    .sort((a, b) => b.edges - a.edges || a.id.localeCompare(b.id));
}

/** Subtle secondary displacement. Does not launch a new animation loop:
 * adjacent bricks react during the original impact's existing 590ms loop. */
export function gelNeighborRipple(progress, contacts = 1) {
  const t = Number.isFinite(progress) ? Math.min(1, Math.max(0, progress)) : 1;
  if (t <= .1 || t >= 1 || contacts <= 0) return { scale: 1, twist: 0 };
  const u = (t - .1) / .9;
  const wave = Math.exp(-4.4 * u) * Math.sin(21 * u);
  const amplitude = Math.min(contacts, 3) / 3;
  return {
    scale: 1 + .045 * amplitude * wave,
    twist: .042 * amplitude * wave
  };
}
