/**
 * Deterministic damped spring for jelly gel impacts.
 * Designed for the short on-demand render loop, not a persistent physics engine.
 * Parameter "progress" is clamped to 0..1 so animations never drift.
 */
export function jellyImpact(progress) {
  const t = Math.max(0, Math.min(1, Number.isFinite(progress) ? progress : 1));
  if (t >= 1) return { scaleX: 1, scaleY: 1, scaleZ: 1, lift: 0, bend: 0, phase: 0 };
  const decay = Math.exp(-4.7 * t) * (1 - t);
  const oscillation = Math.sin(21 * t);
  const spring = decay * oscillation;
  return {
    scaleX: 1 + spring * .11,
    scaleY: 1 + spring * .11,
    scaleZ: 1 - spring * .19,
    lift: .28 * (1 - t) ** 2,
    bend: .085 * decay * Math.sin(29 * t),
    phase: 24 * t
  };
}

/** World pivot for a multi-cube jelly piece. Keeps squash centered on the
 * brick itself rather than the origin of the entire puzzle board. */
export function jellyPivot(cells, row, col, size, yCorrection = 1) {
  if (!cells.length) throw new RangeError("A jelly brick must have cells");
  const rs = cells.map(([r]) => r);
  const cs = cells.map(([, c]) => c);
  const midRow = row + (Math.min(...rs) + Math.max(...rs)) / 2;
  const midCol = col + (Math.min(...cs) + Math.max(...cs)) / 2;
  return {
    x: midCol - (size - 1) / 2,
    y: ((size - 1) / 2 - midRow) * yCorrection
  };
}
