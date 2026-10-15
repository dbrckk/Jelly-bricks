/** Lightweight, offline visual and tactile effects with no extra dependencies. */
const CANDY = ["#ff789a", "#67e8cc", "#86adff", "#ffd16a", "#bf9aff", "#ff9dda"];

function reducedMotion() {
  try {
    return Boolean(globalThis.matchMedia?.("(prefers-reduced-motion: reduce)").matches);
  } catch { return false; }
}

export function gentleHaptic(kind = "place") {
  if (reducedMotion()) return;
  const pattern = kind === "win" ? [18, 42, 18, 55, 28] :
    kind === "bad" ? 14 : kind === "place" ? 8 : 0;
  if (!pattern) return;
  try {
    // Unsupported devices (including desktop Chromium) safely skip feedback.
    globalThis.navigator?.vibrate?.(pattern);
  } catch { /* Vibration is optional and should never interrupt gameplay. */ }
}

export function victoryBurst(container, count = 32) {
  container.replaceChildren();
  if (reducedMotion()) return 0;
  const total = Math.max(0, Math.min(48, Math.floor(count)));
  const fragment = document.createDocumentFragment();
  for (let i = 0; i < total; i++) {
    const element = document.createElement("span");
    element.className = "win-particle";
    const angle = (i / total) * Math.PI * 2;
    const radius = 95 + (i % 5) * 21;
    element.style.setProperty("--dx", Math.round(Math.cos(angle) * radius) + "px");
    element.style.setProperty("--dy", Math.round(Math.sin(angle) * radius) + "px");
    element.style.setProperty("--spin", (i % 2 ? -1 : 1) * (240 + i * 12) + "deg");
    element.style.setProperty("--delay", ((i % 6) * 23) + "ms");
    element.style.setProperty("--duration", (650 + (i % 5) * 95) + "ms");
    element.style.setProperty("--candy", CANDY[i % CANDY.length]);
    fragment.appendChild(element);
  }
  container.appendChild(fragment);
  return total;
}
