/**
 * Deterministic, inexpensive 3D jelly impact VFX.
 * The existing 590 ms landing animation advances these values; there is
 * no permanent render loop, randomness, timer or additional WebGL context.
 */
export function impactParticleCount(tier = "balanced", reducedMotion = false) {
  if (reducedMotion || tier === "eco") return 0;
  return tier === "high" ? 12 : 7;
}

export function impactSample(progress, index, count) {
  const t = Number.isFinite(progress) ?
    Math.max(0, Math.min(1, progress)) : 1;
  const total = Math.max(1, count);
  const angle = (index + .5) * Math.PI * 2 / total + .22;
  const speed = .76 + (index % 3) * .15;
  const radius = (.15 + speed * t) * (1 - .1 * t);
  const lift = .14 + .65 * Math.sin(Math.PI * t) * (1 - .22 * t);
  const fade = Math.max(0, (1 - t) ** 1.6);
  const scale = Math.max(.001, (1 - .65 * t) * Math.min(1, t * 9 + .22));
  return {
    x: Math.cos(angle) * radius,
    y: Math.sin(angle) * radius,
    z: lift,
    scale,
    fade,
    ringScale: .32 + 1.15 * t,
    ringFade: Math.max(0, (1 - t) ** 2)
  };
}
