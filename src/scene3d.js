import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { rotate } from "./game.js";

// A real volumetric Three.js renderer, independent of the existing puzzle rules.
// If WebGL is unavailable, the existing accessible CSS board remains playable.
const TILT = Math.atan(.33);
const CORRECTION = 1 / Math.cos(TILT);
const TILE = new RoundedBoxGeometry(.95, .95, .54, 3, .19);
const materialCache = new Map();

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
    meshes: 0, signature: null, pulse: null, raf: 0, disposed: false
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

function addJelly(view, size, row, col, color, group = view.objects) {
  const mesh = new THREE.Mesh(TILE, candyMaterial(color));
  mesh.position.set(col - (size - 1) / 2,
    ((size - 1) / 2 - row) * CORRECTION, .07);
  group.add(mesh);
  view.meshes++;
  return mesh;
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
}

function fillReference(view, level) {
  clearObjects(view.objects);
  view.meshes = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  for (const [position, target] of level.target) {
    const [row, col] = position.split(",").map(Number);
    addJelly(view, level.size, row, col, target.color);
  }
  fitAndRender(view);
}

function fillBoard(view, level, placements, selected, settleId, reducedMotion) {
  clearObjects(view.objects);
  view.meshes = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  let landing = null;
  for (const piece of level.pieces) {
    const placement = placements[piece.id];
    if (!placement) continue;
    const group = new THREE.Group();
    for (const [row, col] of rotate(piece.cells, placement.rotation)) {
      addJelly(view, level.size, placement.row + row, placement.col + col,
        piece.color, group);
    }
    if (piece.id === selected) {
      group.scale.setScalar(1.04);
    }
    view.objects.add(group);
    if (piece.id === settleId && !reducedMotion) landing = group;
  }
  const start = performance.now();
  cancelAnimationFrame(view.raf);
  view.pulse = landing;
  const paint = (now) => {
    if (view.disposed || document.hidden) return;
    if (landing) {
      const progress = Math.min(1, (now - start) / 520);
      const bounce = Math.exp(-5 * progress) * Math.sin(progress * 21);
      landing.scale.set(1 + bounce * .085, 1 - bounce * .075, 1 + bounce * .13);
      landing.position.z = Math.max(0, (1 - progress) ** 2 * .26);
      fitAndRender(view);
      if (progress < 1) view.raf = requestAnimationFrame(paint);
      else { landing.scale.setScalar(1); landing.position.z = 0; fitAndRender(view); }
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
    return { supported: false, update() {}, resize() {} };
  }
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
