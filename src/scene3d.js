import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { rotate } from "./game.js";
import { jellyImpact, jellyPivot } from "./jelly-physics.js";
import { gelContours } from "./gel-contours.js";

// A real volumetric Three.js renderer, independent of the existing puzzle rules.
// If WebGL is unavailable, the existing accessible CSS board remains playable.
const TILT = Math.atan(.33);
const CORRECTION = 1 / Math.cos(TILT);
const materialCache = new Map();
const geometryCache = new Map();

/** One continuous bevelled volume per connected cluster, no internal
 * edges at cell seams. Cached shapes are reused across levels and rotations. */
function gelGeometries(cells) {
  const id = cells.map(([r, c]) => r + ":" + c).sort().join("|");
  if (geometryCache.has(id)) return geometryCache.get(id);
  const midRow = (Math.min(...cells.map(([r]) => r)) +
    Math.max(...cells.map(([r]) => r))) / 2;
  const midCol = (Math.min(...cells.map(([, c]) => c)) +
    Math.max(...cells.map(([, c]) => c))) / 2;
  const geometries = gelContours(cells).map(({ outline, holes }) => {
    const shape = new THREE.Shape();
    shape.moveTo(...outline[0]);
    for (const [x, y] of outline.slice(1)) shape.lineTo(x, y);
    shape.closePath();
    for (const ring of holes) {
      const cutout = new THREE.Path();
      cutout.moveTo(...ring[0]);
      for (const [x, y] of ring.slice(1)) cutout.lineTo(x, y);
      cutout.closePath();
      shape.holes.push(cutout);
    }
    const geometry = new THREE.ExtrudeGeometry(shape, {
      depth: .48, steps: 1, bevelEnabled: true,
      bevelThickness: .09, bevelSize: .075, bevelSegments: 3,
      curveSegments: 2
    });
    geometry.scale(1, CORRECTION, 1);
    geometry.translate(-midCol, midRow * CORRECTION, -.18);
    return geometry;
  });
  geometryCache.set(id, geometries);
  return geometries;
}

/** The shader bends rounded-box vertices *on the GPU*, leaving static pieces
 * on a shared material. Only an impacting piece receives a temporary copy. */
function elasticMaterial(color, view) {
  const material = candyMaterial(color).clone();
  const uniforms = {
    amplitude: { value: 0 },
    phase: { value: 0 }
  };
  material.onBeforeCompile = (shader) => {
    shader.uniforms.jellyAmplitude = uniforms.amplitude;
    shader.uniforms.jellyPhase = uniforms.phase;
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>",
        "#include <common>\nuniform float jellyAmplitude;\nuniform float jellyPhase;")
      .replace("#include <begin_vertex>", `#include <begin_vertex>
        float gelWave = sin(position.x * 8.1 + position.y * 5.8 + jellyPhase);
        transformed.x += gelWave * jellyAmplitude * (0.55 + abs(position.z));
        transformed.y += cos(position.y * 9.3 - position.x * 4.6 + jellyPhase * 0.85)
          * jellyAmplitude * 0.8;
        transformed.z += sin(position.x * 7.4 + position.y * 5.1 + jellyPhase)
          * jellyAmplitude * 1.1;`);
    view.host.dataset.jellyVertexShader = "compiled";
  };
  material.customProgramCacheKey = () => "jelly-vertex-spring-v1";
  return { material, uniforms };
}

function candyMaterial(color) {
  if (!materialCache.has(color)) {
    materialCache.set(color, new THREE.MeshPhysicalMaterial({
      color, roughness: .18, metalness: 0,
      clearcoat: 1, clearcoatRoughness: .11,
      ior: 1.35, thickness: .42, transmission: .15,
      attenuationDistance: 1.4, attenuationColor: new THREE.Color(color),
      emissive: color, emissiveIntensity: .065
    }));
  }
  return materialCache.get(color);
}

function createView(host, kind) {
  const renderer = new THREE.WebGLRenderer({
    alpha: true, antialias: true, powerPreference: "low-power"
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.42;
  renderer.setClearColor(0x000000, 0);
  renderer.domElement.className = "jelly-3d-canvas";
  renderer.domElement.setAttribute("aria-hidden", "true");
  renderer.domElement.style.pointerEvents = "none";

  const scene = new THREE.Scene();
  const objects = new THREE.Group();
  scene.add(objects);
  scene.add(new THREE.HemisphereLight(0xeefaff, 0x3f397b, 2.35));
  const key = new THREE.DirectionalLight(0xffffff, 3.1);
  key.position.set(-3, 4, 7);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x8bdaff, 1.4);
  rim.position.set(4, -4, 3);
  scene.add(rim);

  const camera = new THREE.OrthographicCamera(-2, 2, 2, -2, .01, 100);
  const view = {
    host, kind, renderer, scene, objects, camera,
    meshes: 0, cells: 0, signature: null, pulse: null, raf: 0, disposed: false
  };
  const lost = (event) => {
    event.preventDefault();
    host.classList.remove("has-jelly-3d");
    host.removeAttribute("data-visual-mode");
    view.disposed = true;
    cancelAnimationFrame(view.raf);
  };
  renderer.domElement.addEventListener("webglcontextlost", lost, { once: true });
  host.appendChild(renderer.domElement);
  return view;
}

function clearObjects(group) {
  // All geometries and materials are reused. Dispose only unique temporary
  // geometries created for the board platform and line grid.
  for (const child of [...group.children]) {
    group.remove(child);
    // Group children share static geometry/materials. Only dispose the
    // temporary GPU material allocated for an actively landing piece.
    child.userData.elasticMaterial?.dispose();
    if (child.userData.ownedGeometry) child.geometry.dispose();
    if (child.userData.ownedMaterial) child.material.dispose();
  }
}

function setupCamera(view, size) {
  const half = size / 2 + .12;
  view.camera.left = -half;
  view.camera.right = half;
  view.camera.top = half;
  view.camera.bottom = -half;
  view.camera.position.set(0, -size * .33, size * 1.0);
  view.camera.lookAt(0, 0, 0);
  view.camera.updateProjectionMatrix();
}

function addPlatform(view, size) {
  const base = new THREE.Mesh(
    new RoundedBoxGeometry(size + .18, size * CORRECTION + .18, .16, 2, .08),
    new THREE.MeshStandardMaterial({ color: 0x172343, roughness: .76, metalness: .05 })
  );
  base.position.z = -.35;
  base.userData.ownedGeometry = true;
  base.userData.ownedMaterial = true;
  view.objects.add(base);

  const strokes = [];
  for (let k = 0; k <= size; k++) {
    const line = k - size / 2;
    strokes.push(-size / 2, line * CORRECTION, -.24,
      size / 2, line * CORRECTION, -.24);
    strokes.push(line, -size / 2 * CORRECTION, -.24,
      line, size / 2 * CORRECTION, -.24);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.Float32BufferAttribute(strokes, 3));
  const grid = new THREE.LineSegments(geometry, new THREE.LineBasicMaterial({
    color: 0x94a4dc, transparent: true, opacity: .23
  }));
  grid.userData.ownedGeometry = true;
  grid.userData.ownedMaterial = true;
  view.objects.add(grid);
}

function addGelPiece(view, cells, color, group, material = candyMaterial(color)) {
  for (const geometry of gelGeometries(cells)) {
    group.add(new THREE.Mesh(geometry, material));
    view.meshes++;
  }
  view.cells += cells.length;
}

function fitAndRender(view) {
  if (view.disposed) return;
  if (view.renderer.domElement.parentElement !== view.host) {
    view.host.appendChild(view.renderer.domElement);
  }
  const rect = view.host.getBoundingClientRect();
  const width = Math.max(1, Math.round(rect.width - 14));
  const height = Math.max(1, Math.round(rect.height - 14));
  if (view.lastWidth !== width || view.lastHeight !== height) {
    view.renderer.setSize(width, height, false);
    view.lastWidth = width;
    view.lastHeight = height;
  }
  view.renderer.render(view.scene, view.camera);
  view.host.classList.add("has-jelly-3d");
  view.host.dataset.visualMode = "threejs";
  view.host.dataset.meshCount = String(view.meshes);
  view.host.dataset.cellCount = String(view.cells);
}

function fillReference(view, level) {
  clearObjects(view.objects);
  view.meshes = 0;
  view.cells = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  for (const piece of level.pieces) {
    const { row, col, rotation } = piece.solution;
    const cells = rotate(piece.cells, rotation);
    const pivot = jellyPivot(cells, row, col, level.size, CORRECTION);
    const group = new THREE.Group();
    group.position.set(pivot.x, pivot.y, 0);
    addGelPiece(view, cells, piece.color, group);
    view.objects.add(group);
  }
  fitAndRender(view);
}

function fillBoard(view, level, placements, selected, settleId, reducedMotion) {
  clearObjects(view.objects);
  view.meshes = 0;
  view.cells = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  let landing = null;
  let landingEffect = null;
  for (const piece of level.pieces) {
    const placement = placements[piece.id];
    if (!placement) continue;
    const cells = rotate(piece.cells, placement.rotation);
    const pivot = jellyPivot(cells, placement.row, placement.col,
      level.size, CORRECTION);
    const group = new THREE.Group();
    group.position.set(pivot.x, pivot.y, 0);
    const animate = piece.id === settleId && !reducedMotion;
    const elastic = animate ? elasticMaterial(piece.color, view) : null;
    addGelPiece(view, cells, piece.color, group, elastic?.material);
    if (elastic) {
      group.userData.elasticMaterial = elastic.material;
      landingEffect = elastic.uniforms;
    }
    if (piece.id === selected) {
      group.scale.setScalar(1.04);
    }
    view.objects.add(group);
    if (animate) landing = group;
  }
  const start = performance.now();
  cancelAnimationFrame(view.raf);
  view.pulse = landing;
  const paint = (now) => {
    if (view.disposed || document.hidden) return;
    if (landing) {
      const progress = Math.min(1, (now - start) / 590);
      const impact = jellyImpact(progress);
      landing.scale.set(impact.scaleX, impact.scaleY, impact.scaleZ);
      landing.position.z = impact.lift;
      landingEffect.amplitude.value = impact.bend;
      landingEffect.phase.value = impact.phase;
      fitAndRender(view);
      if (progress < 1) view.raf = requestAnimationFrame(paint);
      else {
        landing.scale.setScalar(1);
        landing.position.z = 0;
        landingEffect.amplitude.value = 0;
        fitAndRender(view);
      }
    } else fitAndRender(view);
  };
  paint(start);
}

/** Create two GPU views maximum: playable board and the currently visible model. */
export function createJelly3D({ board, model, miniModel }) {
  let boardView;
  try {
    boardView = createView(board, "board");
  } catch {
    return { supported: false, update() {}, resize() {}, preview() {} };
  }
  const ghostLayer = new THREE.Group();
  boardView.scene.add(ghostLayer);
  const ghostValid = new THREE.MeshPhysicalMaterial({
    color: 0x76ffdb, transparent: true, opacity: .57,
    depthWrite: false, depthTest: false, roughness: .16,
    clearcoat: 1, emissive: 0x116f5f, emissiveIntensity: .25
  });
  const ghostInvalid = new THREE.MeshPhysicalMaterial({
    color: 0xff6b91, transparent: true, opacity: .5,
    depthWrite: false, depthTest: false, roughness: .2,
    clearcoat: 1, emissive: 0x6e1634, emissiveIntensity: .25
  });
  let reference = null;
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const mobile = window.matchMedia("(max-width: 760px)");
  let lastState = "";
  let lastLevel = "";
  let lastReferenceHost = null;

  function useReference(host) {
    if (reference?.host === host) return;
    if (reference) {
      cancelAnimationFrame(reference.raf);
      reference.host.classList.remove("has-jelly-3d");
      reference.renderer.dispose();
      reference.renderer.domElement.remove();
    }
    reference = null;
    try { reference = createView(host, "reference"); }
    catch { /* Board still renders in 3D. */ }
    lastLevel = "";
    lastReferenceHost = host;
  }

  const api = {
    supported: true,
    preview(input) {
      ghostLayer.clear();
      if (boardView.disposed) return;
      if (input) {
        const { level, piece, position, rotation, valid } = input;
        const material = valid ? ghostValid : ghostInvalid;
        const cells = rotate(piece.cells, rotation);
        const pivot = jellyPivot(cells, position.row, position.col,
          level.size, CORRECTION);
        const group = new THREE.Group();
        group.position.set(pivot.x, pivot.y, .5);
        for (const geometry of gelGeometries(cells)) {
          const mesh = new THREE.Mesh(geometry, material);
          mesh.renderOrder = 10;
          group.add(mesh);
        }
        ghostLayer.add(group);
        boardView.host.dataset.ghostCells = String(cells.length);
      }
      if (!input) boardView.host.dataset.ghostCells = "0";
      boardView.host.dataset.ghostMeshes = String(
        ghostLayer.children.reduce((sum, group) => sum + group.children.length, 0)
      );
      fitAndRender(boardView);
    },
    update({ level, placements, selected, settleId }) {
      if (boardView.disposed) return;
      const target = mobile.matches ? miniModel : model;
      useReference(target);
      if (lastLevel !== level.id) {
        if (reference) fillReference(reference, level);
        lastLevel = level.id;
      }
      const signature = JSON.stringify([level.id, placements, selected]);
      if (signature !== lastState || settleId) {
        fillBoard(boardView, level, placements, selected, settleId, reducedMotion.matches);
        lastState = signature;
      } else {
        fitAndRender(boardView);
      }
    },
    resize() {
      fitAndRender(boardView);
      if (reference && !reference.disposed) fitAndRender(reference);
    }
  };
  return api;
}
