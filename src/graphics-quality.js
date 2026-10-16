import { studioProfile } from "./gel-lighting.js";

export const GRAPHICS_STORAGE_KEY = "jelly-bricks-graphics-v1";
export const GRAPHICS_MODES = Object.freeze(["auto", "eco", "high"]);

export function normalizeGraphicsMode(mode) {
  return GRAPHICS_MODES.includes(mode) ? mode : "auto";
}

/**
 * Small, deterministic WebGL budget for Android. "Auto" uses capability and
 * data-saver hints, not a claimed FPS measurement or GPU fingerprint.
 * A player can explicitly override it at any point without losing progress.
 */
export function graphicsProfile(mode = "auto", {
  mobile = false, deviceMemory = 4, dpr = 1, saveData = false
} = {}) {
  const selectedMode = normalizeGraphicsMode(mode);
  const constrained = (Number.isFinite(deviceMemory) && deviceMemory > 0 &&
    deviceMemory <= 2) || saveData === true;
  const tier = selectedMode === "auto" ?
    (constrained ? "eco" : "balanced") :
    selectedMode;
  const requestedDpr = Number.isFinite(dpr) && dpr > 0 ? dpr : 1;
  const base = studioProfile({
    mobile, deviceMemory, dpr: requestedDpr
  });
  const cap = tier === "eco" ? (mobile ? 1 : 1.1) :
    tier === "high" ? (mobile ? 1.75 : 2) :
    (mobile ? 1.25 : 1.5);
  return {
    ...base,
    selectedMode,
    tier,
    pixelRatio: Math.min(requestedDpr, cap),
    reflectionSize: tier === "eco" ? 0 : tier === "high" ?
      (mobile ? 128 : 256) : base.reflectionSize,
    antialias: tier !== "eco",
    transmission: tier === "eco" ? 0 : tier === "high" ? .24 : .18,
    // Refraction has its own render target. Keep the gel sharply modelled
    // while reducing its secondary framebuffer cost for Android.
    transmissionScale: tier === "eco" ? .4 :
      tier === "high" ? (mobile ? .8 : 1) : base.transmissionScale,
    microBubbles: tier !== "eco",
    iridescence: tier === "high" ? .16 : 0,
    environmentIntensity: tier === "high" ? 1.02 : base.environmentIntensity,
    shadowOpacity: tier === "eco" ? .28 : base.shadowOpacity
  };
}

export function graphicsModeDescription(mode) {
  const names = {
    auto: "Auto · adapte les effets aux capacités indiquées par le navigateur",
    eco: "Fluide · réduit la résolution, supprime les reflets coûteux",
    high: "Détaillé · reflets renforcés et rendu haute définition"
  };
  return names[normalizeGraphicsMode(mode)];
}
