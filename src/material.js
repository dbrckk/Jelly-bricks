/**
 * Shape-aware rendering: cells of the same polyomino share soft edges.
 * Pure geometry to keep visuals independent from input/collision logic.
 */
export function surfaceNeighbors(cells, row, col) {
  const coords = new Set(cells.map(([r, c]) => r + "," + c));
  return {
    top: coords.has((row - 1) + "," + col),
    right: coords.has(row + "," + (col + 1)),
    bottom: coords.has((row + 1) + "," + col),
    left: coords.has(row + "," + (col - 1))
  };
}

export function applySurfaceClasses(element, cells, row, col) {
  const edges = surfaceNeighbors(cells, row, col);
  for (const [side, joined] of Object.entries(edges)) {
    if (joined) element.classList.add("join-" + side);
  }
  return element;
}
