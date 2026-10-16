/**
 * Mobile-budgeted physical jelly lighting. No tracking or device fingerprinting.
 * A small synthetic studio environment gives glossy sweets bright softbox
 * reflections without requesting an HDR image or running a frame loop.
 */
export const GEL_OPTICS = Object.freeze({
  roughness: 0.13,
  metalness: 0,
  clearcoat: 1,
  clearcoatRoughness: 0.07,
  ior: 1.38,
  thickness: 0.52,
  transmission: 0.18,
  attenuationDistance: 1.7,
  emissiveIntensity: 0.035
});

export function studioProfile({
  mobile = false, deviceMemory = 4, dpr = 1
} = {}) {
  const constrained = Number.isFinite(deviceMemory) && deviceMemory > 0 &&
    deviceMemory <= 2;
  const safeDpr = Number.isFinite(dpr) && dpr > 0 ? dpr : 1;
  return {
    pixelRatio: Math.min(safeDpr, constrained ? 1 : mobile ? 1.25 : 1.5),
    // 64px PMREM is adequate for a 4–7-cell board on a mobile screen.
    // The most constrained GPUs use punctual lights and no IBL texture.
    reflectionSize: constrained ? 0 : mobile ? 64 : 128,
    environmentIntensity: mobile ? .72 : .85,
    shadowOpacity: constrained ? .25 : .35,
    contactScale: 1.085
  };
}
