// Core mechanics intentionally independent from the browser, allowing deterministic tests.
export const PALETTE = Object.freeze({
  A: "#ff6d8b", B: "#64b7ff", C: "#5de4bb", D: "#ffd36d",
  E: "#ae8cff", F: "#ff95d4", G: "#ffae6d", H: "#72e3e2",
  I: "#9acaff", J: "#cf8dff", K: "#f58b76"
});

const DESIGNS = [
  { name: "Premiers bonbons", size: 4, rows: [".AA.", "BBAC", ".BCC", "...."] },
  { name: "Le carré magique", size: 4, rows: ["AABB", "ACCB", "DDCE", "DDEE"] },
  { name: "Bouquet de gelées", size: 5, rows: [".AABB", "CAADB", "CCDDB", "FFDEE", "F.GGE"] },
  { name: "Arc-en-ciel", size: 5, rows: ["AABBC", "ADBBC", "ADDEC", "FFDEE", "FF.GG"] },
  { name: "Confiserie", size: 6, rows: [".AABBC", "DAEBBC", "DDEFF.", "GGEFHH", "GIIJHH", ".IJJ.."] },
  { name: "Maître des briques", size: 6, rows: ["AABBCC", "ADDECC", "AFFEGG", "HHFEGG", "HIJJKK", "IIJ.KK"] },
  // Pixel-art silhouettes built from contiguous jelly polyominoes.
  { name: "Cœur bonbon", size: 7, rows: [".AH.EC.", "AAHEECC", "AADDDGG", ".FFFDG.", "..FBB..", "...B...", "......."] },
  { name: "Fleur jelly", size: 7, rows: ["..EEE..", ".CCEHH.", "FCAAADD", ".CGGAD.", "..GGA..", "...G...", "..BBB.."] },
  { name: "Fusée sucrée", size: 7, rows: ["...B...", "..EBB..", "..EDD..", "..EDD..", ".AEFFF.", ".AA.CC.", ".A...C."] },
  { name: "Papillon", size: 7, rows: ["EA.G.BB", "EAAGHHB", "EAGGHHB", ".FFDDD.", "..FFI..", "..CCI..", "...C..."] },
  { name: "Couronne royale", size: 7, rows: ["A..D..E", "AA.D.EE", "AHHDFFB", "HHHCFBB", ".CCCGG.", ".......", "......."] },
  { name: "Poisson arc-en-ciel", size: 7, rows: [".......", ".DAAF..", "DDAAFF.", "DDEEECC", ".BBBE..", ".......", "......."] },
  { name: "Gâteau festif", size: 7, rows: ["..B.G..", "..B.G..", ".FFFGD.", ".FEEDD.", "CCHEDAA", "CHHEDAA", "......."] },
  { name: "Fantôme doux", size: 7, rows: ["..BBG..", ".FBEGD.", "FFFEHDA", "CFEEHDA", "CCEHHIA", "CC.H.II", "......."] },
  { name: "Champignon", size: 7, rows: ["..DDG..", ".IIDGC.", "AAHHGCC", "AAHFFFC", "..EFB..", "..EEB..", "..EBB.."] },
  { name: "Château jelly", size: 7, rows: ["C.H.K.B", "CCHDKKB", "CFHDDDB", ".FHIIE.", ".FFIIE.", "GGJAAEE", "GJJAAEE"] },
  { name: "Tortue des mers", size: 7, rows: [".......", "..DDFF.", "BBBGGA.", "BBCEEAA", ".CCEEA.", "..C.E..", "......."] },
  { name: "Diamant", size: 7, rows: ["...B...", "..BBE..", ".GGGEE.", "CCGFDDD", ".CCFAA.", "..FFA..", "...F..."] },
  { name: "Renard malin", size: 7, rows: ["C.....B", "CC...EB", "GGGAEEB", "GFFAAEB", ".FFDDE.", "..HDD..", "...D..."] },
  { name: "Maison sucrée", size: 7, rows: ["...B...", "..BBB..", ".DDFFF.", "GGDACCC", ".GDAEE.", ".GGAEE.", "......."] },
  { name: "Alien rigolo", size: 7, rows: [".AAFFF.", "JJAAIFC", "JJIIICC", "DDDGEEC", ".DHGBE.", "..HGB..", "..H.B.."] }
];

export function normalize(cells) {
  const minRow = Math.min(...cells.map(([row]) => row));
  const minCol = Math.min(...cells.map(([, col]) => col));
  return cells.map(([row, col]) => [row - minRow, col - minCol])
    .sort(([ar, ac], [br, bc]) => ar - br || ac - bc);
}

export function rotate(cells, turns = 0) {
  let transformed = cells.map(([row, col]) => [row, col]);
  for (let i = 0; i < ((turns % 4) + 4) % 4; i++) {
    transformed = transformed.map(([row, col]) => [col, -row]);
  }
  return normalize(transformed);
}

export function bounds(cells) {
  return {
    rows: Math.max(...cells.map(([row]) => row)) + 1,
    cols: Math.max(...cells.map(([, col]) => col)) + 1
  };
}

function parseDesign(design, index) {
  const origins = new Map();
  const target = new Map();

  design.rows.forEach((line, row) => {
    if (line.length !== design.size) throw new Error("Invalid level width: " + design.name);
    [...line].forEach((id, col) => {
      if (id === ".") return;
      if (!PALETTE[id]) throw new Error("Unknown brick color: " + id);
      if (!origins.has(id)) origins.set(id, []);
      origins.get(id).push([row, col]);
      target.set(row + "," + col, { id, color: PALETTE[id] });
    });
  });

  const pieces = [...origins.entries()].map(([id, cells]) => {
    const top = Math.min(...cells.map(([row]) => row));
    const left = Math.min(...cells.map(([, col]) => col));
    return {
      id, color: PALETTE[id], cells: normalize(cells),
      solution: { row: top, col: left, rotation: 0 }
    };
  });

  return { id: index + 1, name: design.name, size: design.size,
    pieces, target, total: target.size };
}

export const LEVELS = DESIGNS.map(parseDesign);

export function findPiece(level, id) {
  return level.pieces.find((piece) => piece.id === id);
}

export function absoluteCells(piece, placement) {
  return rotate(piece.cells, placement.rotation)
    .map(([row, col]) => [row + placement.row, col + placement.col]);
}

export function attemptPlacement(level, placements, id, row, col, rotation = 0) {
  const piece = findPiece(level, id);
  if (!piece || !Number.isInteger(row) || !Number.isInteger(col)) return null;
  const nextPlacement = { row, col, rotation: ((rotation % 4) + 4) % 4 };
  const occupied = new Set();

  for (const other of level.pieces) {
    if (other.id === id || !placements[other.id]) continue;
    for (const [r, c] of absoluteCells(other, placements[other.id])) {
      occupied.add(r + "," + c);
    }
  }

  for (const [r, c] of absoluteCells(piece, nextPlacement)) {
    const key = r + "," + c;
    if (r < 0 || c < 0 || r >= level.size || c >= level.size ||
        !level.target.has(key) || occupied.has(key)) return null;
  }

  return { ...placements, [id]: nextPlacement };
}

export function evaluate(level, placements) {
  let correct = 0;
  let filled = 0;
  for (const piece of level.pieces) {
    if (!placements[piece.id]) continue;
    for (const [row, col] of absoluteCells(piece, placements[piece.id])) {
      filled++;
      if (level.target.get(row + "," + col)?.color === piece.color) correct++;
    }
  }
  return { correct, filled, total: level.total,
    won: correct === level.total && filled === level.total };
}

export function pieceAt(level, placements, row, col) {
  for (const piece of level.pieces) {
    if (!placements[piece.id]) continue;
    if (absoluteCells(piece, placements[piece.id])
      .some(([r, c]) => r === row && c === col)) return piece.id;
  }
  return null;
}

export function solvedPlacement(level) {
  const placed = {};
  for (const piece of level.pieces) {
    const next = attemptPlacement(level, placed, piece.id,
      piece.solution.row, piece.solution.col, 0);
    if (!next) throw new Error("Invalid level design " + level.name);
    Object.assign(placed, next);
  }
  return placed;
}
