import * as THREE from "three";
import { RoundedBoxGeometry } from "three/addons/geometries/RoundedBoxGeometry.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { GEL_OPTICS } from "./gel-lighting.js";
import { injectGelSurface, gelProgramKey } from "./gel-surface.js";
import { graphicsProfile } from "./graphics-quality.js";
import { createFrameBudget } from "./frame-budget.js";
import { touchingGelNeighbors, gelNeighborRipple } from "./gel-reactions.js";
import { rotate } from "./game.js";
import { jellyImpact, jellyPivot } from "./jelly-physics.js";
import { gelContours } from "./gel-contours.js";

// A real volumetric Three.js renderer, independent of the existing puzzle rules.
// If WebGL is unavailable, the existing accessible CSS board remains playable.
const TILT = Math.atan(.33);
const CORRECTION = 1 / Math.cos(TILT);
const geometryCache = new Map();
const shadowCache = new Map();
const SHADOW_MATERIAL = new THREE.MeshBasicMaterial({
  color: 0x060d24, transparent: true, opacity: .35,
  depthWrite: false, polygonOffset: true, polygonOffsetFactor: -1
});

function contactGeometry(cells) {
  const id = cells.map(([r, c]) => r + ":" + c).sort().join("|");
  if (shadowCache.has(id)) return shadowCache.get(id);
  const minRow = Math.min(...cells.map(([r]) => r));
  const maxRow = Math.max(...cells.map(([r]) => r));
  const minCol = Math.min(...cells.map(([, c]) => c));
  const maxCol = Math.max(...cells.map(([, c]) => c));
  const shapes = gelContours(cells).map(({ outline, holes }) => {
    const shape = new THREE.Shape();
    shape.moveTo(...outline[0]);
    for (const [x, y] of outline.slice(1)) shape.lineTo(x, y);
    shape.closePath();
    for (const hole of holes) {
      const path = new THREE.Path();
      path.moveTo(...hole[0]);
      for (const [x, y] of hole.slice(1)) path.lineTo(x, y);
      path.closePath();
      shape.holes.push(path);
    }
    return shape;
  });
  const geometry = new THREE.ShapeGeometry(shapes);
  geometry.scale(1, CORRECTION, 1);
  geometry.translate(-(minCol + maxCol) / 2,
    ((minRow + maxRow) / 2) * CORRECTION, 0);
  shadowCache.set(id, geometry);
  return geometry;
}

function addContactShadow(view, cells, pivot) {
  const mesh = new THREE.Mesh(contactGeometry(cells), view.shadowMaterial);
  mesh.position.set(pivot.x, pivot.y, -.205);
  mesh.scale.setScalar(view.profile.contactScale);
  mesh.renderOrder = 0;
  view.objects.add(mesh);
  view.contactShadows++;
  return mesh;
}

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
  const material = candyMaterial(color, view).clone();
  const uniforms = { amplitude: { value: 0 }, phase: { value: 0 } };
  const fine = view.profile.microBubbles;
  const premium = view.profile.tier === "high";
  material.onBeforeCompile = (shader) => {
    injectGelSurface(shader, { fine, premium, elastic: true, uniforms });
    view.host.dataset.jellyVertexShader = "compiled";
    view.host.dataset.gelSurfaceShader = "compiled";
  };
  material.customProgramCacheKey = () => gelProgramKey({ fine, premium, elastic: true });
  return { material, uniforms };
}

function candyMaterial(color, view) {
  if (!view.materials.has(color)) {
    const fine = view.profile.microBubbles;
    const premium = view.profile.tier === "high";
    const material = new THREE.MeshPhysicalMaterial({
      color, ...GEL_OPTICS,
      transmission: view.profile.transmission,
      iridescence: view.profile.iridescence,
      iridescenceIOR: 1.3,
      iridescenceThicknessRange: [170, 380],
      attenuationColor: new THREE.Color(color),
      emissive: color
    });
    material.onBeforeCompile = (shader) => {
      injectGelSurface(shader, { fine, premium });
      view.host.dataset.gelSurfaceShader = "compiled";
    };
    material.customProgramCacheKey = () => gelProgramKey({ fine, premium });
    view.materials.set(color, material);
  }
  return view.materials.get(color);
}

function createView(host, kind, graphicsMode) {
  const mobile = window.matchMedia("(max-width: 760px)").matches;
  const profile = graphicsProfile(graphicsMode, {
    mobile,
    deviceMemory: navigator.deviceMemory,
    saveData: navigator.connection?.saveData || false,
    dpr: window.devicePixelRatio || 1
  });
  const renderer = new THREE.WebGLRenderer({
    alpha: true, antialias: profile.antialias,
    powerPreference: profile.tier === "eco" ? "low-power" : "default"
  });
  renderer.setPixelRatio(profile.pixelRatio);
  renderer.transmissionResolutionScale = profile.transmissionScale;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.42;
  renderer.setClearColor(0x000000, 0);
  renderer.domElement.className = "jelly-3d-canvas";
  renderer.domElement.setAttribute("aria-hidden", "true");
  renderer.domElement.style.pointerEvents = "none";

  const scene = new THREE.Scene();
  let studioTarget = null;
  if (profile.reflectionSize) {
    const room = new RoomEnvironment();
    const pmrem = new THREE.PMREMGenerator(renderer);
    try {
      studioTarget = pmrem.fromScene(room, .045, .1, 100,
        { size: profile.reflectionSize });
      scene.environment = studioTarget.texture;
      scene.environmentIntensity = profile.environmentIntensity;
    } catch {
      // PMREM can fail on restricted GPUs: direct lights and 2D backup remain.
      studioTarget?.dispose();
      studioTarget = null;
    } finally {
      room.dispose();
      pmrem.dispose();
    }
  }
  host.dataset.studioLighting = studioTarget ? "enabled" : "fallback";
  host.dataset.transmissionScale = String(profile.transmissionScale);
  host.dataset.gelDetails = profile.microBubbles ? "pearls" : "basic";
  host.dataset.gelOptics = profile.tier === "high" ? "studio" : "fresnel";
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
    host, kind, renderer, scene, objects, camera, studioTarget, profile,
    frameBudget: createFrameBudget({ mode: graphicsMode, mobile, baseRatio: profile.pixelRatio }),
    materials: new Map(), shadowMaterial: SHADOW_MATERIAL.clone(),
    meshes: 0, cells: 0, contactShadows: 0, signature: null,
    pulse: null, raf: 0, disposed: false
  };
  view.shadowMaterial.opacity = profile.shadowOpacity;
  const lost = (event) => {
    event.preventDefault();
    // A deliberately retired renderer must not hide its replacement canvas.
    if (view.disposed) return;
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

function addGelPiece(view, cells, color, group, material = null) {
  const gelMaterial = material ?? candyMaterial(color, view);
  for (const geometry of gelGeometries(cells)) {
    group.add(new THREE.Mesh(geometry, gelMaterial));
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
  view.host.dataset.graphicsTier = view.profile.tier;
  view.host.dataset.renderPixelRatio = String(view.renderer.getPixelRatio());
  view.host.dataset.adaptiveSteps = String(view.frameBudget.adjustments);
  view.host.dataset.contactShadows = String(view.contactShadows);
}

function fillReference(view, level) {
  clearObjects(view.objects);
  view.meshes = 0;
  view.cells = 0;
  view.contactShadows = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  for (const piece of level.pieces) {
    const { row, col, rotation } = piece.solution;
    const cells = rotate(piece.cells, rotation);
    const pivot = jellyPivot(cells, row, col, level.size, CORRECTION);
    const group = new THREE.Group();
    group.position.set(pivot.x, pivot.y, 0);
    addContactShadow(view, cells, pivot);
    addGelPiece(view, cells, piece.color, group);
    view.objects.add(group);
  }
  fitAndRender(view);
}

function fillBoard(view, level, placements, selected, settleId, reducedMotion) {
  clearObjects(view.objects);
  view.meshes = 0;
  view.cells = 0;
  view.contactShadows = 0;
  setupCamera(view, level.size);
  addPlatform(view, level.size);
  let landing = null;
  let landingShadow = null;
  let landingEffect = null;
  const touching = new Map((settleId && !reducedMotion ?
    touchingGelNeighbors(level, placements, settleId) : [])
    .map(({ id, edges }) => [id, edges]));
  const reactingGroups = [];
  for (const piece of level.pieces) {
    const placement = placements[piece.id];
    if (!placement) continue;
    const cells = rotate(piece.cells, placement.rotation);
    const pivot = jellyPivot(cells, placement.row, placement.col,
      level.size, CORRECTION);
    const group = new THREE.Group();
    group.position.set(pivot.x, pivot.y, 0);
    const shadow = addContactShadow(view, cells, pivot);
    const animate = piece.id === settleId && !reducedMotion;
    if (animate) landingShadow = shadow;
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
    if (touching.has(piece.id)) {
      reactingGroups.push({ group, edges: touching.get(piece.id) });
    }
    if (animate) landing = group;
  }
  view.host.dataset.reactedNeighbors = String(reactingGroups.length);
  const start = performance.now();
  let lastFrameTime = null;
  cancelAnimationFrame(view.raf);
  view.pulse = landing;
  const paint = (now) => {
    if (view.disposed || document.hidden) return;
    if (landing) {
      if (lastFrameTime !== null) {
        const ratio = view.frameBudget.observeFrame(now - lastFrameTime);
        if (Math.abs(ratio - view.renderer.getPixelRatio()) > .001) {
          view.renderer.setPixelRatio(ratio);
          // Force the next render to apply the correct canvas backing size.
          view.lastWidth = 0;
          view.lastHeight = 0;
        }
      }
      lastFrameTime = now;
      const progress = Math.min(1, (now - start) / 590);
      const impact = jellyImpact(progress);
      landing.scale.set(impact.scaleX, impact.scaleY, impact.scaleZ);
      landing.position.z = impact.lift;
      landingShadow.scale.setScalar(view.profile.contactScale +
        impact.lift * .13);
      landingEffect.amplitude.value = impact.bend;
      landingEffect.phase.value = impact.phase;
      for (const { group, edges } of reactingGroups) {
        const reaction = gelNeighborRipple(progress, edges);
        group.scale.setScalar(reaction.scale);
        group.rotation.z = reaction.twist;
      }
      fitAndRender(view);
      if (progress < 1) view.raf = requestAnimationFrame(paint);
      else {
        landing.scale.setScalar(1);
        landing.position.z = 0;
        landingShadow.scale.setScalar(view.profile.contactScale);
        landingEffect.amplitude.value = 0;
        for (const { group } of reactingGroups) {
          group.scale.setScalar(1);
          group.rotation.z = 0;
        }
        fitAndRender(view);
      }
    } else fitAndRender(view);
  };
  paint(start);
}

/** Release per-context resources after changing quality or switching views.
 * Shared polyomino geometry/material caches stay alive for later frames. */
function disposeView(view) {
  if (!view) return;
  view.disposed = true;
  cancelAnimationFrame(view.raf);
  clearObjects(view.objects);
  view.studioTarget?.dispose();
  view.shadowMaterial.dispose();
  for (const material of view.materials.values()) material.dispose();
  view.materials.clear();
  view.renderer.dispose();
  view.renderer.forceContextLoss();
  view.renderer.domElement.remove();
  view.host.classList.remove("has-jelly-3d");
  view.host.removeAttribute("data-visual-mode");
}

/** Create two GPU views maximum: playable board and the currently visible model. */
export function createJelly3D({ board, model, miniModel, graphicsMode = "auto" }) {
  let boardView;
  try {
    boardView = createView(board, "board", graphicsMode);
  } catch {
    return { supported: false, update() {}, resize() {}, preview() {}, dispose() {} };
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
    if (reference) disposeView(reference);
    reference = null;
    try { reference = createView(host, "reference", graphicsMode); }
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
    },
    dispose() {
      ghostLayer.clear();
      ghostValid.dispose();
      ghostInvalid.dispose();
      disposeView(reference);
      disposeView(boardView);
      reference = null;
    }
  };
  return api;
}
