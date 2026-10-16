/**
 * Extract the actual outer boundary of connected, axis-aligned polyominoes.
 * Internal edges are never emitted, so adjacent gel cubes become one volume.
 * Works for rotated pieces, disjoint islands and enclosed holes.
 */
export function gelContours(cells) {
  if (!Array.isArray(cells) || !cells.length) return [];
  const occupied = new Set(cells.map(([r, c]) => r + "," + c));
  const edges = [];
  function add(a, b) {
    edges.push({ a, b, used: false, direction: [b[0] - a[0], b[1] - a[1]] });
  }
  for (const [r, c] of cells) {
    const tl = [c - .5, -r + .5];
    const tr = [c + .5, -r + .5];
    const br = [c + .5, -r - .5];
    const bl = [c - .5, -r - .5];
    if (!occupied.has((r - 1) + "," + c)) add(tl, tr);
    if (!occupied.has(r + "," + (c + 1))) add(tr, br);
    if (!occupied.has((r + 1) + "," + c)) add(br, bl);
    if (!occupied.has(r + "," + (c - 1))) add(bl, tl);
  }
  const key = ([x, y]) => x + "," + y;
  const nextByPoint = new Map();
  for (const edge of edges) {
    const name = key(edge.a);
    if (!nextByPoint.has(name)) nextByPoint.set(name, []);
    nextByPoint.get(name).push(edge);
  }
  const polygons = [];
  for (const first of edges) {
    if (first.used) continue;
    const ring = [];
    let current = first;
    let loops = 0;
    while (current && !current.used && loops++ <= edges.length) {
      current.used = true;
      ring.push(current.a);
      if (key(current.b) === key(first.a)) break;
      const outgoing = (nextByPoint.get(key(current.b)) || [])
        .filter((edge) => !edge.used);
      // At a shared diagonal corner, keep the material to our right.
      // This avoids stitching separate islands together at a single point.
      const [dx, dy] = current.direction;
      const preferences = [[dy, -dx], [dx, dy], [-dy, dx], [-dx, -dy]];
      outgoing.sort((left, right) => {
        const rank = (edge) => preferences.findIndex(([x, y]) =>
          x === edge.direction[0] && y === edge.direction[1]);
        return rank(left) - rank(right);
      });
      current = outgoing[0];
    }
    if (!ring.length || loops > edges.length) {
      throw new Error("Unable to trace jelly shape perimeter");
    }
    const simple = ring.filter((point, index) => {
      const before = ring[(index - 1 + ring.length) % ring.length];
      const after = ring[(index + 1) % ring.length];
      const cross = (point[0] - before[0]) * (after[1] - point[1]) -
        (point[1] - before[1]) * (after[0] - point[0]);
      return cross !== 0;
    });
    if (simple.length < 4) throw new Error("Degenerate jelly outline");
    polygons.push(simple);
  }

  const area = (poly) => poly.reduce((sum, [x, y], i) => {
    const [x2, y2] = poly[(i + 1) % poly.length];
    return sum + x * y2 - x2 * y;
  }, 0) / 2;
  const contains = (poly, point) => {
    let inside = false;
    for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      const a = poly[i], b = poly[j];
      const crossY = (a[1] > point[1]) !== (b[1] > point[1]);
      if (crossY && point[0] < (b[0] - a[0]) *
        (point[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    return inside;
  };
  const outlines = polygons.filter((poly) => area(poly) < 0)
    .map((outline) => ({ outline, holes: [] }));
  for (const hole of polygons.filter((poly) => area(poly) > 0)) {
    const container = outlines.find(({ outline }) => contains(outline, hole[0]));
    if (container) container.holes.push(hole);
    else throw new Error("Jelly hole has no surrounding contour");
  }
  return outlines;
}
