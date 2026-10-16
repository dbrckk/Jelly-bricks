import test from "node:test";
import assert from "node:assert/strict";
import { injectGelSurface, gelProgramKey, GEL_SURFACE_VERSION } from "../src/gel-surface.js";

function stubShader() {
  return {
    uniforms: {},
    vertexShader: "void main() {\n#include <common>\n#include <begin_vertex>\n}",
    fragmentShader: "void main() {\n#include <common>\n#include <color_fragment>\n}"
  };
}

test("static candy surface has pearly flecks and density swirls with no textures", () => {
  const shader = injectGelSurface(stubShader());
  assert.match(shader.vertexShader, /varying vec3 vGelLocal/);
  assert.match(shader.vertexShader, /vGelLocal = position/);
  assert.match(shader.fragmentShader, /gelBubble/);
  assert.match(shader.fragmentShader, /gelBand/);
  assert.match(shader.fragmentShader, /diffuseColor.rgb/);
  assert.doesNotMatch(shader.fragmentShader, /texture2D|sampler2D/);
  assert.equal(shader.vertexShader.includes("jellyAmplitude"), false);
  assert.match(gelProgramKey(), /pearl:static:mobile$/);
  assert.match(gelProgramKey(), new RegExp(GEL_SURFACE_VERSION));
});

test("elastic material retains procedural gel and uses the *same* spring uniforms", () => {
  const uniforms = {
    amplitude: { value: .1 },
    phase: { value: 2.3 }
  };
  const shader = injectGelSurface(stubShader(), { fine: true, elastic: true, uniforms });
  assert.equal(shader.uniforms.jellyAmplitude, uniforms.amplitude);
  assert.equal(shader.uniforms.jellyPhase, uniforms.phase);
  assert.match(shader.vertexShader, /gelWave/);
  assert.match(shader.fragmentShader, /gelBubble/);
  assert.match(gelProgramKey({ fine: true, elastic: true }), /pearl:elastic:mobile$/);
});

test("low-memory candy keeps soft swirl but omits expensive micro-bubbles", () => {
  const shader = injectGelSurface(stubShader(), { fine: false });
  assert.match(shader.fragmentShader, /gelBand/);
  assert.doesNotMatch(shader.fragmentShader, /gelBubble|gelSeed/);
  assert.match(gelProgramKey({ fine: false }), /basic:static:mobile$/);
  assert.notEqual(gelProgramKey({ fine: false }), gelProgramKey({ fine: true }));
});

test("shader API mismatch fails clearly rather than silently rendering flat jelly", () => {
  const shader = stubShader();
  shader.vertexShader = "void main(){}";
  assert.throws(() => injectGelSurface(shader), /Incompatible Three.js shader chunks/);
  assert.throws(() => injectGelSurface(stubShader(), { elastic: true }), /shared spring uniforms/);
});

test("jelly edges use angle-dependent Fresnel glow and depth tint without textures", () => {
  const shader = injectGelSurface(stubShader(), { fine: false });
  assert.match(shader.vertexShader, /vGelViewNormal = normalize\(normalMatrix \* normal\)/);
  assert.match(shader.fragmentShader, /gelFresnel/);
  assert.match(shader.fragmentShader, /gelThickness/);
  assert.match(shader.fragmentShader, /vViewPosition/);
  assert.doesNotMatch(shader.fragmentShader, /gelSoftbox|sampler2D|texture2D/);
});

test("premium softbox gloss uses separate shader cache and retains soft-body animation", () => {
  const uniforms = { amplitude: { value: .07 }, phase: { value: 1 } };
  const high = injectGelSurface(stubShader(), {
    fine: true, premium: true, elastic: true, uniforms
  });
  assert.match(high.fragmentShader, /gelSoftbox/);
  assert.match(high.fragmentShader, /gelBubble/);
  assert.match(high.vertexShader, /gelWave/);
  assert.equal(high.uniforms.jellyAmplitude, uniforms.amplitude);
  assert.notEqual(gelProgramKey({ premium: true }),
    gelProgramKey({ premium: false }));
  assert.match(gelProgramKey({ premium: true }), /:studio$/);
});
