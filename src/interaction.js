/**
 * Map a pointer to the same logical cell used by the CSS grid.
 * Points on the visual padding are outside the playable area.
 */
export function gridCellAt(rect, size, clientX, clientY, inset = 7) {
  if (!Number.isInteger(size) || size <= 0 || !Number.isFinite(inset) || inset < 0) return null;
  const width = rect.width - inset * 2;
  const height = rect.height - inset * 2;
  if (!(width > 0 && height > 0)) return null;
  const x = (clientX - rect.left - inset) / width;
  const y = (clientY - rect.top - inset) / height;
  if (x < 0 || y < 0 || x >= 1 || y >= 1) return null;
  return { row: Math.min(size - 1, Math.floor(y * size)),
    col: Math.min(size - 1, Math.floor(x * size)) };
}

/**
 * Preserve the exact cell the user grabbed during a drag.
 * Without this, a piece unexpectedly jumps to its top-left corner.
 */
export function anchoredDrop(rect, size, clientX, clientY, grabbedRow = 0, grabbedCol = 0, inset = 7) {
  const cell = gridCellAt(rect, size, clientX, clientY, inset);
  if (!cell || !Number.isInteger(grabbedRow) || !Number.isInteger(grabbedCol) ||
      grabbedRow < 0 || grabbedCol < 0) return null;
  return { row: cell.row - grabbedRow, col: cell.col - grabbedCol };
}
