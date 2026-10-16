import { attemptPlacement } from "./game.js";

/**
 * Forgive the one-cell imprecision common when dropping a thick 3D block on
 * small touch screens. Exact valid placements always win over magnetic snaps.
 * Pure game logic: no DOM, timers or changes to the puzzle's target.
 */
export function resolveMagneticPlacement(level, placements, id, row, col, rotation = 0) {
  const exact = attemptPlacement(level, placements, id, row, col, rotation);
  if (exact) return {
    placements: exact, position: { row, col }, snapped: false
  };
  if (!Number.isInteger(row) || !Number.isInteger(col) ||
      row < -1 || col < -1 || row > level.size || col > level.size) return null;
  // Cardinal neighbours only: diagonal or longer-range help would make
  // intentional puzzle placement ambiguous.
  for (const [dr, dc] of [[-1, 0], [0, -1], [0, 1], [1, 0]]) {
    const candidateRow = row + dr;
    const candidateCol = col + dc;
    const candidate = attemptPlacement(level, placements, id,
      candidateRow, candidateCol, rotation);
    if (candidate) {
      return {
        placements: candidate,
        position: { row: candidateRow, col: candidateCol },
        snapped: true
      };
    }
  }
  return null;
}
