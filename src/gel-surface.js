/** Procedural candy surface for Three.js MeshPhysicalMaterial.
 * A tiny deterministic shader extension replaces downloaded textures:
 * pearly micro-bubbles and soft density bands live inside the same 3D volume.
 * One color/material is reused by every piece of that color.
 */
export const GEL_SURFACE_VERSION = "jelly-candy-surface-2";

const VERTEX_COMMON = `
varying vec3 vGelLocal;
varying vec3 vGelViewNormal;
`;

const FRAGMENT_COMMON = `
varying vec3 vGelLocal;
varying vec3 vGelViewNormal;
`;

// No texture fetches and only one sine hash per fragment. Fine details can be
// disabled by low-memory mobile profiles without changing gameplay.
const FINE_CANDY = `
  vec2 gelLattice = vGelLocal.xy * 8.0;
  vec2 gelTile = floor(gelLattice);
  vec2 gelCell = fract(gelLattice) - vec2(0.5);
  float gelSeed = fract(sin(dot(gelTile, vec2(12.9898, 78.233))) * 43758.5453);
  float gelBubble = 1.0 - smoothstep(0.075, 0.16,
    length(gelCell + vec2(gelSeed * 0.12, -gelSeed * 0.08)));
  float gelPearl = step(0.79, gelSeed) * gelBubble;
  diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.96, 0.97, 1.0), gelPearl * 0.26);
`;

const SOFT_DENSITY = `
  float gelBand = sin(vGelLocal.x * 5.7 + vGelLocal.y * 3.1)
    * sin(vGelLocal.y * 6.9 - vGelLocal.z * 4.8);
  diffuseColor.rgb *= 1.0 + gelBand * 0.045;
`;

// Fresnel edge glow and gentle light trapping reveal the candy's thickness.
// This works entirely in the physical material's normal lighting pipeline.
const CANDY_OPTICS = `
  vec3 gelEye = normalize(vViewPosition);
  vec3 gelNormal = normalize(vGelViewNormal);
  float gelFacing = clamp(abs(dot(gelEye, gelNormal)), 0.0, 1.0);
  float gelFresnel = pow(1.0 - gelFacing, 2.5);
  float gelThickness = smoothstep(-0.23, 0.42, vGelLocal.z);
  diffuseColor.rgb *= mix(0.88, 1.045, gelThickness);
  diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.97, 0.985, 1.0),
    gelFresnel * 0.16);
`;

// Additional softbox sheen is reserved for high-detail Android/desktop mode.
// Preserve the simpler shader for balanced and battery-saving rendering.
const PREMIUM_OPTICS = `
  float gelSoftbox = pow(max(dot(gelNormal,
    normalize(vec3(-0.35, 0.52, 0.78))), 0.0), 14.0);
  diffuseColor.rgb = mix(diffuseColor.rgb,
    vec3(1.0, 0.995, 0.985), gelSoftbox * 0.18);
`;

const IMPACT_VERTEX = `
  float gelWave = sin(position.x * 8.1 + position.y * 5.8 + jellyPhase);
  transformed.x += gelWave * jellyAmplitude * (0.55 + abs(position.z));
  transformed.y += cos(position.y * 9.3 - position.x * 4.6 + jellyPhase * 0.85)
    * jellyAmplitude * 0.8;
  transformed.z += sin(position.x * 7.4 + position.y * 5.1 + jellyPhase)
    * jellyAmplitude * 1.1;
`;

/**
 * Modifies Three.js shader chunks in-place, preserving its PBR lighting and
 * color-space conversion. Throws on API mismatch rather than silently rendering
 * a flat/unmodified surface.
 */
export function injectGelSurface(shader, {
  fine = true, elastic = false, premium = false, uniforms = null
} = {}) {
  for (const [source, chunks] of [
    ["vertexShader", ["#include <common>", "#include <begin_vertex>"]],
    ["fragmentShader", ["#include <common>", "#include <color_fragment>"]]
  ]) {
    if (typeof shader[source] !== "string" ||
        chunks.some((chunk) => !shader[source].includes(chunk))) {
      throw new Error("Incompatible Three.js shader chunks: " + source);
    }
  }
  if (elastic && (!uniforms?.amplitude || !uniforms?.phase)) {
    throw new Error("Elastic gel requires shared spring uniforms");
  }
  if (elastic) {
    shader.uniforms.jellyAmplitude = uniforms.amplitude;
    shader.uniforms.jellyPhase = uniforms.phase;
  }
  const declarations = elastic ?
    "uniform float jellyAmplitude;\nuniform float jellyPhase;" : "";
  shader.vertexShader = shader.vertexShader
    .replace("#include <common>",
      "#include <common>\n" + VERTEX_COMMON + declarations)
    .replace("#include <begin_vertex>",
      "#include <begin_vertex>\nvGelLocal = position;\n" +
        "vGelViewNormal = normalize(normalMatrix * normal);\n" +
        (elastic ? IMPACT_VERTEX : ""));
  shader.fragmentShader = shader.fragmentShader
    .replace("#include <common>", "#include <common>\n" + FRAGMENT_COMMON)
    .replace("#include <color_fragment>", "#include <color_fragment>\n" +
      SOFT_DENSITY + CANDY_OPTICS + (premium ? PREMIUM_OPTICS : "") +
      (fine ? FINE_CANDY : ""));
  return shader;
}

export function gelProgramKey({ fine = true, elastic = false, premium = false } = {}) {
  return GEL_SURFACE_VERSION + ":" + (fine ? "pearl" : "basic") +
    ":" + (elastic ? "elastic" : "static") +
    ":" + (premium ? "studio" : "mobile");
}
