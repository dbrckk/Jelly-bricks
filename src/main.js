import { LEVELS, bounds, rotate, findPiece, attemptPlacement, evaluate, absoluteCells } from "./game.js";
import { gridCellAt, anchoredDrop } from "./interaction.js";
import { SESSION_KEY, parseSessionBook, recoverSession, saveSession, discardSession } from "./session.js";
import { gentleHaptic, victoryBurst } from "./feedback.js";
import { applySurfaceClasses } from "./material.js";

const $ = (id) => document.getElementById(id);
const ui = {
  model: $("model-board"), miniModel: $("mini-model-board"), zoomModel: $("zoom-model-board"),
  referenceDialog: $("reference-dialog"), expandModel: $("expand-model"),
  closeReference: $("close-reference"), board: $("build-board"), tray: $("piece-tray"),
  quickTray: $("quick-tray"), quickPieces: $("quick-pieces"),
  quickToggle: $("quick-toggle"), quickContent: $("quick-content"),
  quickRotate: $("quick-rotate"), quickRemove: $("quick-remove"),
  levelSelect: $("level-select"), levelName: $("level-name"), progress: $("progress-label"),
  completion: $("completion-track"), completionFill: $("completion-fill"),
  accuracy: $("accuracy-label"), moves: $("moves-label"), count: $("piece-count"),
  instruction: $("instruction"), time: $("time-label"), hints: $("hints-label"),
  stars: $("stars-label"), toast: $("toast"), sound: $("sound-toggle"),
  rotate: $("rotate-btn"), remove: $("remove-btn"), undo: $("undo-btn"),
  hint: $("hint-btn"), reset: $("reset-btn"), check: $("check-btn"),
  dialog: $("win-dialog"), winStars: $("win-stars"), winMoves: $("win-moves"),
  winTime: $("win-time"), winMessage: $("win-message"), next: $("next-btn"),
  replay: $("replay-btn")
};

const STORAGE_KEY = "jelly-bricks-progress-v1";
const SOUND_KEY = "jelly-bricks-sound-v1";
const COLOR_NAMES = {
  A: "rose", B: "bleue", C: "menthe", D: "jaune", E: "violette",
  F: "fuchsia", G: "orange", H: "turquoise", I: "azur", J: "mauve", K: "corail"
};

function getSaved(key) {
  try { return localStorage.getItem(key); } catch { return null; }
}
function setSaved(key, value) {
  try { localStorage.setItem(key, value); } catch { /* The game remains playable. */ }
}
function readProgress() {
  try {
    const raw = JSON.parse(getSaved(STORAGE_KEY));
    return { unlocked: Math.max(1, Math.min(LEVELS.length, Number(raw?.unlocked) || 1)),
      best: raw?.best && typeof raw.best === "object" ? raw.best : {} };
  } catch { return { unlocked: 1, best: {} }; }
}

const progress = readProgress();
let sessionBook = parseSessionBook(getSaved(SESSION_KEY), LEVELS);
let hasInitialized = false;
let soundOn = getSaved(SOUND_KEY) !== "off";
let audioContext = null;
let toastTimer = null;
let suppressClickUntil = 0;
let pointerDrag = null;
let pausedByVisibility = false;
let pendingSettleId = null;

const state = {
  levelIndex: 0, placements: {}, rotations: {}, selected: null,
  history: [], moves: 0, hints: 0, mistakes: 0,
  showHint: false, startedAt: null, elapsedSeconds: 0, won: false
};

const level = () => LEVELS[state.levelIndex];

function chime(type = "place") {
  if (type === "place" || type === "bad" || type === "win") gentleHaptic(type);
  if (!soundOn) return;
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    audioContext ||= new Ctx();
    if (audioContext.state === "suspended") void audioContext.resume();
    const sequence = type === "win" ? [440, 550, 660, 880] :
      type === "bad" ? [185] : type === "rotate" ? [390] : [340, 510];
    sequence.forEach((freq, index) => {
      const at = audioContext.currentTime + index * .07;
      const osc = audioContext.createOscillator();
      const gain = audioContext.createGain();
      osc.type = type === "bad" ? "triangle" : "sine";
      osc.frequency.setValueAtTime(freq, at);
      osc.frequency.exponentialRampToValueAtTime(freq * .96, at + .11);
      gain.gain.setValueAtTime(.0001, at);
      gain.gain.exponentialRampToValueAtTime(.06, at + .012);
      gain.gain.exponentialRampToValueAtTime(.0001, at + .16);
      osc.connect(gain).connect(audioContext.destination);
      osc.start(at);
      osc.stop(at + .17);
    });
  } catch { /* Audio is optional. */ }
}

function notify(message) {
  ui.toast.textContent = message;
  ui.toast.classList.add("is-visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => ui.toast.classList.remove("is-visible"), 2400);
}

function clock(seconds) {
  const s = Math.max(0, Math.floor(seconds));
  return String(Math.floor(s / 60)).padStart(2, "0") + ":" +
    String(s % 60).padStart(2, "0");
}
function currentSeconds() {
  return state.startedAt === null ? state.elapsedSeconds :
    state.elapsedSeconds + Math.floor((Date.now() - state.startedAt) / 1000);
}
function startClock() {
  if (state.startedAt === null && !state.won) state.startedAt = Date.now();
}
function persistSession() {
  if (state.won || !hasInitialized) return;
  sessionBook = saveSession(sessionBook, level(), state, currentSeconds());
  setSaved(SESSION_KEY, JSON.stringify(sessionBook));
}
function clearSavedSession(levelId, nextActiveId = levelId) {
  sessionBook = discardSession(sessionBook, levelId, nextActiveId);
  setSaved(SESSION_KEY, JSON.stringify(sessionBook));
}
function snapshot() {
  state.history.push({ placements: structuredClone(state.placements),
    rotations: { ...state.rotations }, moves: state.moves });
  if (state.history.length > 80) state.history.shift();
}
function resetLevel(index = state.levelIndex, fresh = false) {
  if (hasInitialized && !state.won) persistSession();
  pausedByVisibility = false;
  state.levelIndex = index;
  if (fresh) clearSavedSession(level().id);
  const resumed = recoverSession(level(), sessionBook.levels[level().id]);
  state.placements = resumed?.placements ?? {};
  state.rotations = resumed?.rotations ?? Object.fromEntries(level().pieces.map((piece, i) =>
    [piece.id, (i * 3 + index + 1) % 4]));
  state.selected = null;
  state.history = [];
  state.moves = resumed?.moves ?? 0;
  state.hints = resumed?.hints ?? 0;
  state.mistakes = resumed?.mistakes ?? 0;
  state.showHint = false;
  state.startedAt = null;
  state.elapsedSeconds = resumed?.elapsedSeconds ?? 0;
  state.won = false;
  pendingSettleId = null;
  hasInitialized = true;
  if (ui.dialog.open) ui.dialog.close();
  if (ui.referenceDialog.open) ui.referenceDialog.close();
  $("win-particles").replaceChildren();
  render();
  persistSession();
}

function tile(color, cells = null, row = 0, col = 0) {
  const element = document.createElement("span");
  element.className = "jelly";
  element.style.setProperty("--jelly", color);
  if (cells) applySurfaceClasses(element, cells, row, col);
  element.setAttribute("aria-hidden", "true");
  return element;
}
function preview(piece, rotation = 0) {
  const cells = rotate(piece.cells, rotation);
  const size = bounds(cells);
  const element = document.createElement("span");
  element.className = "piece-preview";
  element.style.setProperty("--cols", size.cols);
  element.style.setProperty("--rows", size.rows);
  for (const [row, col] of cells) {
    const cell = tile(piece.color, cells, row, col);
    cell.style.gridRow = row + 1;
    cell.style.gridColumn = col + 1;
    cell.dataset.localRow = row;
    cell.dataset.localCol = col;
    element.appendChild(cell);
  }
  return element;
}

function drawModel() {
  const l = level();
  const pieceCells = new Map(l.pieces.map((piece) => [
    piece.id, absoluteCells(piece, piece.solution)
  ]));
  // Keep all three views synchronized from one source of truth.
  for (const display of [ui.model, ui.miniModel, ui.zoomModel]) {
    display.replaceChildren();
    display.style.setProperty("--grid-size", l.size);
    const fragment = document.createDocumentFragment();
    for (let row = 0; row < l.size; row++) {
      for (let col = 0; col < l.size; col++) {
        const cell = document.createElement("span");
        cell.className = "model-cell";
        const target = l.target.get(row + "," + col);
        if (target) cell.appendChild(
          tile(target.color, pieceCells.get(target.id), row, col));
        fragment.appendChild(cell);
      }
    }
    display.appendChild(fragment);
  }
}

function drawBoard() {
  const l = level();
  ui.board.replaceChildren();
  ui.board.style.setProperty("--grid-size", l.size);
  const hint = state.showHint && state.selected ?
    findPiece(l, state.selected) : null;
  const hintCells = hint ? new Set(absoluteCells(hint, hint.solution)
    .map(([row, col]) => row + "," + col)) : new Set();

  for (let row = 0; row < l.size; row++) {
    for (let col = 0; col < l.size; col++) {
      const slot = document.createElement("button");
      slot.type = "button";
      const key = row + "," + col;
      const isTarget = l.target.has(key);
      slot.className = "slot" + (isTarget ? " is-target" : "") +
        (hintCells.has(key) ? " is-hint" : "");
      slot.dataset.row = row;
      slot.dataset.col = col;
      slot.setAttribute("aria-label", "Ligne " + (row + 1) + ", colonne " +
        (col + 1) + (isTarget ? ", à remplir" : ", hors du modèle"));
      slot.disabled = state.won;
      ui.board.appendChild(slot);
    }
  }

  for (const piece of l.pieces) {
    const placement = state.placements[piece.id];
    if (!placement) continue;
    const cells = rotate(piece.cells, placement.rotation);
    const size = bounds(cells);
    const element = document.createElement("button");
    element.type = "button";
    element.className = "placed-piece" +
      (state.selected === piece.id ? " is-selected" : "") +
      (pendingSettleId === piece.id ? " is-settling" : "");
    element.dataset.pieceId = piece.id;
    element.setAttribute("aria-label", "Brique " + COLOR_NAMES[piece.id] +
      " placée, sélectionner pour la déplacer ou la retirer");
    element.style.setProperty("--cols", size.cols);
    element.style.setProperty("--rows", size.rows);
    // The playable cells are inside the board's 7px padding.
    const position = (offset) => "calc(7px + (100% - 14px) * " +
      (offset / l.size) + ")";
    element.style.left = position(placement.col);
    element.style.top = position(placement.row);
    element.style.width = "calc((100% - 14px) * " + size.cols / l.size + ")";
    element.style.height = "calc((100% - 14px) * " + size.rows / l.size + ")";
    for (const [row, col] of cells) {
      const cell = tile(piece.color, cells, row, col);
      cell.style.left = col * 100 / size.cols + "%";
      cell.style.top = row * 100 / size.rows + "%";
      cell.dataset.localRow = row;
      cell.dataset.localCol = col;
      element.appendChild(cell);
    }
    element.disabled = state.won;
    ui.board.appendChild(element);
  }
}

function drawTray() {
  const l = level();
  ui.tray.replaceChildren();
  ui.quickPieces.replaceChildren();
  for (const piece of l.pieces) {
    if (state.placements[piece.id]) continue;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "piece-card" +
      (state.selected === piece.id ? " is-selected" : "");
    button.dataset.pieceId = piece.id;
    button.setAttribute("aria-pressed", String(state.selected === piece.id));
    button.setAttribute("aria-label", "Sélectionner brique " +
      COLOR_NAMES[piece.id] + ", " + piece.cells.length + " cubes");
    button.appendChild(preview(piece, state.rotations[piece.id]));
    const label = document.createElement("small");
    label.textContent = "Jelly " + COLOR_NAMES[piece.id];
    button.appendChild(label);
    ui.tray.appendChild(button);
    const fast = document.createElement("button");
    fast.type = "button";
    fast.className = "quick-piece" + (state.selected === piece.id ? " is-selected" : "");
    fast.dataset.pieceId = piece.id;
    fast.setAttribute("aria-pressed", String(state.selected === piece.id));
    fast.setAttribute("aria-label", "Brique " + COLOR_NAMES[piece.id] +
      ", " + piece.cells.length + " cubes");
    fast.appendChild(preview(piece, state.rotations[piece.id]));
    ui.quickPieces.appendChild(fast);
  }

  if (l.pieces.every((piece) => state.placements[piece.id])) {
    const message = document.createElement("p");
    message.className = "toolbox-help";
    message.textContent = "Toutes les briques sont placées. Vérifie leur emplacement !";
    ui.tray.appendChild(message);
    const done = document.createElement("span");
    done.className = "quick-done";
    done.textContent = "Toutes les briques sont posées";
    ui.quickPieces.appendChild(done);
  }
}

function drawHud() {
  const l = level();
  const check = evaluate(l, state.placements);
  const available = l.pieces.filter((piece) => !state.placements[piece.id]).length;
  ui.levelName.textContent = l.name;
  ui.progress.textContent = check.filled + " / " + check.total;
  ui.completion.setAttribute("aria-valuenow", String(
    Math.round(100 * check.filled / check.total)));
  ui.completionFill.style.width = 100 * check.filled / check.total + "%";
  ui.accuracy.textContent = check.filled === 0 ? "Place ta première brique" :
    check.correct + " cases correctes sur " + check.total;
  ui.moves.textContent = state.moves + " coup" + (state.moves !== 1 ? "s" : "");
  ui.count.textContent = available + " pièce" + (available !== 1 ? "s" : "") + " restante" + (available !== 1 ? "s" : "");
  ui.hints.textContent = state.hints;
  ui.time.textContent = clock(currentSeconds());
  const best = progress.best[l.id]?.stars || 0;
  ui.stars.textContent = "★".repeat(best) + "☆".repeat(3 - best);
  ui.rotate.disabled = !state.selected || state.won;
  ui.remove.disabled = !state.selected || !state.placements[state.selected] || state.won;
  ui.quickRotate.disabled = ui.rotate.disabled;
  ui.quickRemove.disabled = ui.remove.disabled;
  ui.undo.disabled = !state.history.length || state.won;
  ui.hint.disabled = state.won;
  ui.check.disabled = state.won;
  ui.instruction.textContent = state.selected ?
    "Brique " + COLOR_NAMES[state.selected] +
      " sélectionnée. Touche sa position de départ sur la grille, ou fais-la glisser. Rotation : bouton Tourner ou touche R." :
    "Sélectionne une brique, puis touche sa position de départ sur la grille. Tu peux aussi la faire glisser.";
  ui.sound.textContent = soundOn ? "♪" : "♩";
  ui.sound.classList.toggle("is-muted", !soundOn);
  ui.sound.setAttribute("aria-label", soundOn ? "Désactiver les sons" : "Activer les sons");
}

function drawLevelSelect() {
  ui.levelSelect.replaceChildren();
  LEVELS.forEach((l, index) => {
    const option = document.createElement("option");
    option.value = index;
    option.textContent = String(index + 1).padStart(2, "0") + " · " +
      l.name + (index + 1 > progress.unlocked ? " · verrouillé" : "");
    option.disabled = index + 1 > progress.unlocked;
    ui.levelSelect.appendChild(option);
  });
  ui.levelSelect.value = String(state.levelIndex);
}

function render() {
  drawLevelSelect();
  drawModel();
  drawBoard();
  pendingSettleId = null;
  drawTray();
  drawHud();
}

function selectPiece(id, scrollToBoard = false) {
  if (state.won || !findPiece(level(), id)) return;
  state.selected = id;
  state.showHint = false;
  chime("rotate");
  render();
  if (scrollToBoard && window.matchMedia("(max-width: 760px)").matches) {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    ui.board.scrollIntoView({ block: "center", behavior: reduced ? "instant" : "smooth" });
  }
}

function placePiece(id, row, col) {
  if (state.won) return;
  const rotation = state.rotations[id] ?? 0;
  const result = attemptPlacement(level(), state.placements, id, row, col, rotation);
  if (!result) {
    notify("Cette brique ne rentre pas ici. Essaie une autre position ou tourne-la.");
    chime("bad");
    return;
  }
  const old = state.placements[id];
  if (old && old.row === row && old.col === col && old.rotation === rotation) return;
  snapshot();
  startClock();
  state.placements = result;
  state.moves++;
  state.showHint = false;
  state.selected = null;
  pendingSettleId = id;
  chime();
  render();
  if (evaluate(level(), state.placements).won) win();
  else persistSession();
}

function rotateSelected() {
  if (!state.selected || state.won) return;
  const id = state.selected;
  const nextRotation = ((state.rotations[id] ?? 0) + 1) % 4;
  const existing = state.placements[id];
  if (existing) {
    const changed = attemptPlacement(level(), state.placements,
      id, existing.row, existing.col, nextRotation);
    if (!changed) {
      notify("Impossible de pivoter à cet endroit : retire ou déplace la brique.");
      chime("bad");
      return;
    }
    snapshot();
    state.placements = changed;
    state.moves++;
    startClock();
    pendingSettleId = id;
  } else {
    snapshot();
  }
  state.rotations[id] = nextRotation;
  state.showHint = false;
  chime("rotate");
  render();
  if (evaluate(level(), state.placements).won) win();
  else persistSession();
}

function removeSelected() {
  const id = state.selected;
  if (!id || !state.placements[id] || state.won) return;
  snapshot();
  delete state.placements[id];
  state.moves++;
  state.showHint = false;
  chime("rotate");
  render();
  persistSession();
}

function undo() {
  if (!state.history.length || state.won) return;
  const before = state.history.pop();
  state.placements = before.placements;
  state.rotations = before.rotations;
  state.moves = before.moves;
  state.showHint = false;
  chime("rotate");
  render();
  persistSession();
}

function showHint() {
  if (state.won) return;
  if (!state.selected) {
    const unsolved = level().pieces.find((piece) => {
      const actual = state.placements[piece.id];
      return !actual || actual.row !== piece.solution.row ||
        actual.col !== piece.solution.col ||
        JSON.stringify(rotate(piece.cells, actual.rotation)) !==
          JSON.stringify(piece.cells);
    });
    state.selected = unsolved?.id ?? level().pieces[0].id;
  }
  if (state.showHint) { notify("L'emplacement indiqué est celui de la brique sélectionnée."); return; }
  startClock();
  state.showHint = true;
  state.hints++;
  chime("rotate");
  render();
  persistSession();
  notify("Les cases lumineuses montrent l'emplacement de cette brique.");
}

function checkSolution() {
  if (state.won) return;
  const outcome = evaluate(level(), state.placements);
  if (outcome.won) return win();
  if (outcome.filled < outcome.total) {
    notify("Il reste " + (outcome.total - outcome.filled) + " cases à remplir.");
    return;
  }
  state.mistakes++;
  notify(outcome.correct + " / " + outcome.total + " cases correspondent au modèle. Ajuste les briques.");
  chime("bad");
  render();
}

function win() {
  if (state.won) return;
  state.won = true;
  state.elapsedSeconds = currentSeconds();
  state.startedAt = null;
  const pieces = level().pieces.length;
  const extraMoves = Math.max(0, state.moves - pieces - 2);
  const penalty = Math.min(2, (state.hints ? 1 : 0) +
    (state.mistakes ? 1 : 0) + (extraMoves >= 6 ? 1 : 0));
  const stars = 3 - penalty;
  const id = level().id;
  const old = progress.best[id];
  if (!old || stars > (old.stars || 0) ||
      (stars === old.stars && state.elapsedSeconds < old.time)) {
    progress.best[id] = { stars, time: state.elapsedSeconds };
  }
  progress.unlocked = Math.max(progress.unlocked, Math.min(LEVELS.length, id + 1));
  setSaved(STORAGE_KEY, JSON.stringify(progress));
  clearSavedSession(id, Math.min(LEVELS.length, id + 1));
  render();
  ui.winStars.textContent = "★".repeat(stars) + "☆".repeat(3 - stars);
  ui.winMoves.textContent = state.moves;
  ui.winTime.textContent = clock(state.elapsedSeconds);
  ui.winMessage.textContent = stars === 3 ?
    "Reproduction parfaite ! Tu maîtrises les briques." :
    "Modèle parfaitement reproduit. Rejoue avec moins d'indices pour gagner trois étoiles.";
  ui.next.textContent = id < LEVELS.length ? "Niveau suivant →" : "Rejouer le dernier niveau ↻";
  chime("win");
  ui.dialog.showModal();
  victoryBurst($("win-particles"));
}

ui.tray.addEventListener("click", (event) => {
  if (Date.now() < suppressClickUntil) return;
  const pieceButton = event.target.closest("[data-piece-id]");
  if (pieceButton) selectPiece(pieceButton.dataset.pieceId, true);
});
ui.quickPieces.addEventListener("click", (event) => {
  if (Date.now() < suppressClickUntil) return;
  const button = event.target.closest(".quick-piece[data-piece-id]");
  if (button) selectPiece(button.dataset.pieceId, true);
});
ui.quickRotate.addEventListener("click", rotateSelected);
ui.quickRemove.addEventListener("click", removeSelected);
// Avoid covering the original draggable pieces when the full toolbox is in view.
if ("IntersectionObserver" in window) {
  const visibility = new IntersectionObserver(([entry]) => {
    ui.quickTray.classList.toggle("is-obscured", entry.isIntersecting);
  }, { threshold: .08 });
  visibility.observe(ui.tray);
}
ui.quickToggle.addEventListener("click", () => {
  const collapsed = !ui.quickContent.hidden;
  ui.quickContent.hidden = collapsed;
  ui.quickTray.classList.toggle("is-collapsed", collapsed);
  ui.quickToggle.setAttribute("aria-expanded", String(!collapsed));
  ui.quickToggle.setAttribute("aria-label",
    collapsed ? "Afficher la barre de briques" : "Réduire la barre de briques");
  ui.quickToggle.textContent = collapsed ? "Afficher ▴" : "Réduire ▾";
});
ui.board.addEventListener("click", (event) => {
  if (Date.now() < suppressClickUntil || state.won) return;
  const placedButton = event.target.closest("[data-piece-id]");
  if (placedButton) return selectPiece(placedButton.dataset.pieceId);
  const slot = event.target.closest("[data-row][data-col]");
  if (!slot) return;
  if (!state.selected) return notify("Sélectionne d'abord une brique.");
  placePiece(state.selected, Number(slot.dataset.row), Number(slot.dataset.col));
});

function clearDragHover() {
  for (const slot of ui.board.querySelectorAll(".is-preview-valid, .is-preview-invalid")) {
    slot.classList.remove("is-preview-valid", "is-preview-invalid");
  }
}

function dragPlacement(drag, clientX, clientY) {
  return anchoredDrop(ui.board.getBoundingClientRect(), level().size,
    clientX, clientY, drag.anchorRow, drag.anchorCol);
}

function updateDragHover(drag, clientX, clientY) {
  const pointerCell = gridCellAt(ui.board.getBoundingClientRect(), level().size,
    clientX, clientY);
  const key = pointerCell?.row + ":" + pointerCell?.col;
  if (drag.lastHoverCell === key) return;
  drag.lastHoverCell = key;
  clearDragHover();
  if (!pointerCell) return;

  const position = dragPlacement(drag, clientX, clientY);
  const rotation = state.rotations[drag.id] ?? 0;
  const candidate = position && attemptPlacement(level(), state.placements,
    drag.id, position.row, position.col, rotation);
  const cells = candidate ? absoluteCells(findPiece(level(), drag.id), candidate[drag.id]) :
    [[pointerCell.row, pointerCell.col]];
  for (const [row, col] of cells) {
    const slot = ui.board.querySelector('[data-row="' + row + '"][data-col="' + col + '"]');
    slot?.classList.add(candidate ? "is-preview-valid" : "is-preview-invalid");
  }
}

document.addEventListener("pointerdown", (event) => {
  if (!event.isPrimary || event.button !== 0 || state.won) return;
  const source = event.target.closest(".piece-card, .placed-piece");
  if (!source?.dataset.pieceId) return;
  const touchedTile = event.target.closest(".jelly");
  pointerDrag = {
    id: source.dataset.pieceId, pointerId: event.pointerId,
    startX: event.clientX, startY: event.clientY,
    anchorRow: Number(touchedTile?.dataset.localRow ?? 0),
    anchorCol: Number(touchedTile?.dataset.localCol ?? 0),
    lastHoverCell: null, active: false, ghost: null
  };
});
document.addEventListener("pointermove", (event) => {
  if (!pointerDrag || pointerDrag.pointerId !== event.pointerId) return;
  const drag = pointerDrag;
  if (!drag.active && Math.hypot(event.clientX - drag.startX,
    event.clientY - drag.startY) < 9) return;
  if (!drag.active) {
    drag.active = true;
    const piece = findPiece(level(), drag.id);
    drag.ghost = document.createElement("div");
    drag.ghost.className = "drag-ghost";
    drag.ghost.appendChild(preview(piece, state.rotations[drag.id]));
    document.body.appendChild(drag.ghost);
    ui.board.classList.add("is-dragging");
  }
  event.preventDefault();
  drag.ghost.style.left = event.clientX + "px";
  drag.ghost.style.top = (event.clientY - 28) + "px";
  updateDragHover(drag, event.clientX, event.clientY);
}, { passive: false });

function finishDrag(event) {
  if (!pointerDrag || pointerDrag.pointerId !== event.pointerId) return;
  const drag = pointerDrag;
  pointerDrag = null;
  drag.ghost?.remove();
  clearDragHover();
  ui.board.classList.remove("is-dragging");
  if (!drag.active) return;
  suppressClickUntil = Date.now() + 350;
  if (event.type === "pointercancel") return;

  // A failed or off-board drop keeps the brick selected for tap-to-place.
  state.selected = drag.id;
  const position = dragPlacement(drag, event.clientX, event.clientY);
  if (position) placePiece(drag.id, position.row, position.col);
  else render();
  // placePiece leaves state unrendered when the target was invalid.
  if (state.selected && !state.won) render();
}
document.addEventListener("pointerup", finishDrag);
document.addEventListener("pointercancel", finishDrag);

ui.expandModel.addEventListener("click", () => {
  if (!ui.referenceDialog.open) ui.referenceDialog.showModal();
});
ui.closeReference.addEventListener("click", () => ui.referenceDialog.close());
ui.rotate.addEventListener("click", rotateSelected);
ui.remove.addEventListener("click", removeSelected);
ui.undo.addEventListener("click", undo);
ui.hint.addEventListener("click", showHint);
ui.check.addEventListener("click", checkSolution);
ui.reset.addEventListener("click", () => { resetLevel(state.levelIndex, true); notify("Niveau recommencé."); });
ui.levelSelect.addEventListener("change", () => {
  const requested = Number(ui.levelSelect.value);
  if (Number.isInteger(requested) && requested >= 0 && requested < progress.unlocked) resetLevel(requested);
});
ui.sound.addEventListener("click", () => {
  soundOn = !soundOn;
  setSaved(SOUND_KEY, soundOn ? "on" : "off");
  render();
  if (soundOn) chime();
});
ui.next.addEventListener("click", () => resetLevel(
  Math.min(state.levelIndex + 1, LEVELS.length - 1)));
ui.replay.addEventListener("click", () => resetLevel(state.levelIndex, true));
document.addEventListener("keydown", (event) => {
  if (ui.dialog.open || ["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement?.tagName)) return;
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "z") {
    event.preventDefault(); undo();
  } else if (!event.ctrlKey && !event.metaKey && event.key.toLowerCase() === "r") {
    event.preventDefault(); rotateSelected();
  } else if (event.key === "Escape") {
    state.selected = null; state.showHint = false; render();
  } else if (event.key === "Delete" || event.key === "Backspace") {
    if (state.selected) { event.preventDefault(); removeSelected(); }
  }
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    pausedByVisibility = state.startedAt !== null;
    if (pausedByVisibility) {
      state.elapsedSeconds = currentSeconds();
      state.startedAt = null;
    }
    persistSession();
  } else if (pausedByVisibility && !state.won) {
    state.startedAt = Date.now();
    pausedByVisibility = false;
  }
});
setInterval(() => {
  if (state.startedAt !== null && !state.won) ui.time.textContent = clock(currentSeconds());
}, 500);
setInterval(() => {
  if (state.startedAt !== null && !document.hidden) persistSession();
}, 5000);
window.addEventListener("pagehide", persistSession);
const resumeIndex = sessionBook.activeLevelId <= progress.unlocked ?
  sessionBook.activeLevelId - 1 : 0;
resetLevel(resumeIndex);
if ("serviceWorker" in navigator && location.protocol !== "file:") {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch(() => { /* Offline remains optional. */ });
  });
}
