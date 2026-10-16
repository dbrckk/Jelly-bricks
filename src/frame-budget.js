/**
 * Realtime *frame-cadence* controller for short landing animations.
 * RequestAnimationFrame timestamps include main-thread/GPU/browser delays,
 * unlike timing renderer.render() on a command-queued graphics API.
 * No background work, device identifiers, or permanent animation loop.
 */
export function createFrameBudget({
  mode = "auto", mobile = false, baseRatio = 1.25,
  minimumRatio = .8
} = {}) {
  const enabled = mode === "auto" && mobile;
  const base = Number.isFinite(baseRatio) && baseRatio > 0 ? baseRatio : 1;
  const floor = Math.min(base, Math.max(.6, minimumRatio));
  let current = base;
  let slowFrames = 0;
  let fastFrames = 0;
  let adjustments = 0;
  return {
    get ratio() { return current; },
    get adjustments() { return adjustments; },
    observeFrame(intervalMs) {
      if (!enabled || !Number.isFinite(intervalMs) ||
          intervalMs <= 0 || intervalMs >= 190) return current;
      if (intervalMs > 30) {
        slowFrames++;
        fastFrames = 0;
      } else if (intervalMs <= 18.5) {
        fastFrames++;
        slowFrames = Math.max(0, slowFrames - 1);
      } else {
        slowFrames = Math.max(0, slowFrames - 1);
        fastFrames = 0;
      }
      if (slowFrames >= 6 && current > floor + .01) {
        current = Math.max(floor, Math.round((current - .2) * 100) / 100);
        slowFrames = 0;
        fastFrames = 0;
        adjustments++;
      } else if (fastFrames >= 48 && current < base - .01) {
        current = Math.min(base, Math.round((current + .1) * 100) / 100);
        fastFrames = 0;
        slowFrames = 0;
        adjustments++;
      }
      return current;
    }
  };
}
