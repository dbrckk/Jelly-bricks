/**
 * Tiny accessible onboarding state machine, independent of browser APIs.
 * A new player gets guidance without locking or autoplaying the puzzle.
 */
export const COACH_KEY = "jelly-bricks-guide-v1";

export function guideStep({ selected = null, placedPieces = 0, won = false, showHint = false }) {
  if (won || placedPieces >= 2) return "learned";
  if (showHint) return "hint";
  if (placedPieces > 0) return "continue";
  if (selected) return "place";
  return "choose";
}

export const GUIDE_COPY = Object.freeze({
  choose: {
    title: "1/3 · Choisis une brique",
    message: "Touche une brique colorée dans la barre du bas ou dans ta boîte à briques."
  },
  place: {
    title: "2/3 · Place la brique",
    message: "Touche une case du plateau pour poser la brique. Tu peux la tourner avec ↻ ou la faire glisser."
  },
  hint: {
    title: "2/3 · Suis les cases lumineuses",
    message: "Les cases éclairées indiquent l'emplacement de ta brique. Tourne-la si nécessaire."
  },
  continue: {
    title: "3/3 · Termine ton modèle",
    message: "Bien joué ! Continue avec les autres briques. Annuler et Indice restent disponibles."
  },
  learned: {
    title: "Rappel · Commandes du jeu",
    message: "Choisis une brique, tourne-la avec ↻, puis touche la grille. Utilise Annuler, Retirer ou Indice si besoin."
  }
});
