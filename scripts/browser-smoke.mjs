// Dependency-free Chromium smoke test using the Chrome DevTools Protocol.
// Exercises real touch input on an Android-sized viewport, not only puzzle logic.
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync, mkdtempSync, rmSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve, extname, sep } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

const ROOT = resolve(process.cwd(), "dist");
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json"
};

function browserExecutable() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  for (const name of ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]) {
    const probe = spawnSync("which", [name], { encoding: "utf8" });
    if (probe.status === 0) return probe.stdout.trim();
  }
  throw new Error("Chrome/Chromium is required for this smoke test");
}

async function startServer() {
  const server = createServer(async (request, response) => {
    let requested;
    try {
      requested = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    } catch {
      response.writeHead(400).end();
      return;
    }
    const path = resolve(ROOT, "." + (requested === "/" ? "/index.html" : requested));
    if (!path.startsWith(ROOT + sep)) {
      response.writeHead(403).end();
      return;
    }
    try {
      const bytes = await readFile(path);
      response.writeHead(200, { "Content-Type": TYPES[extname(path)] || "application/octet-stream",
        "Cache-Control": "no-store" });
      response.end(bytes);
    } catch {
      response.writeHead(404).end("Not found");
    }
  });
  await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
  return { server, url: "http://127.0.0.1:" + server.address().port + "/" };
}

async function waitFor(task, label, timeoutMs = 15000) {
  const until = Date.now() + timeoutMs;
  let last;
  while (Date.now() < until) {
    try {
      const value = await task();
      if (value) return value;
    } catch (error) { last = error; }
    await sleep(120);
  }
  throw new Error("Timed out waiting for " + label + (last ? ": " + last.message : ""));
}

async function launchChrome() {
  const dir = mkdtempSync(join(tmpdir(), "jelly-chrome-"));
  const processHandle = spawn(browserExecutable(), [
    "--headless=new", "--disable-gpu", "--no-sandbox", "--disable-dev-shm-usage",
    "--enable-webgl", "--enable-unsafe-swiftshader",
    "--disable-background-networking", "--no-first-run",
    "--remote-allow-origins=*", "--remote-debugging-port=0",
    "--user-data-dir=" + dir, "about:blank"
  ], { stdio: "ignore" });
  try {
    const port = await waitFor(() => {
      const raw = readFileSync(join(dir, "DevToolsActivePort"), "utf8");
      return Number(raw.split("\n")[0]) || null;
    }, "Chrome debugging port");
    const tabs = await waitFor(async () => {
      const response = await fetch("http://127.0.0.1:" + port + "/json/list");
      if (!response.ok) return null;
      return (await response.json()).find((entry) => entry.type === "page");
    }, "browser tab");
    return { processHandle, dir, wsUrl: tabs.webSocketDebuggerUrl };
  } catch (error) {
    processHandle.kill();
    rmSync(dir, { recursive: true, force: true });
    throw error;
  }
}

class DevTools {
  constructor(socket) {
    this.socket = socket;
    this.serial = 0;
    this.pending = new Map();
    this.exceptions = [];
    socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (message.method === "Runtime.exceptionThrown") {
        this.exceptions.push(message.params.exceptionDetails.text);
      }
      if (!message.id) return;
      const entry = this.pending.get(message.id);
      if (!entry) return;
      this.pending.delete(message.id);
      clearTimeout(entry.timeout);
      if (message.error) entry.reject(new Error(message.error.message));
      else entry.resolve(message.result);
    });
  }
  call(method, params = {}) {
    const id = ++this.serial;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(method + " did not respond"));
      }, 15000);
      this.pending.set(id, { resolve, reject, timeout });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async eval(expression) {
    const reply = await this.call("Runtime.evaluate",
      { expression, awaitPromise: true, returnByValue: true });
    if (reply.exceptionDetails) {
      throw new Error("In-page exception: " +
        (reply.exceptionDetails.exception?.description || reply.exceptionDetails.text));
    }
    return reply.result?.value;
  }
  async touch(x, y, type, id = 1) {
    const touchPoints = type === "touchEnd" ? [] :
      [{ x: Math.round(x), y: Math.round(y), id, radiusX: 2, radiusY: 2, force: .8 }];
    await this.call("Input.dispatchTouchEvent", { type, touchPoints });
  }
}

async function main() {
  let server, browser, socket;
  try {
    const hosted = await startServer();
    server = hosted.server;
    browser = await launchChrome();
    socket = new WebSocket(browser.wsUrl);
    await new Promise((ok, fail) => {
      socket.addEventListener("open", ok, { once: true });
      socket.addEventListener("error", fail, { once: true });
    });
    const page = new DevTools(socket);
    await page.call("Page.enable");
    await page.call("Runtime.enable");
    await page.call("Emulation.setDeviceMetricsOverride",
      { width: 390, height: 844, deviceScaleFactor: 3, mobile: true });
    await page.call("Emulation.setTouchEmulationEnabled",
      { enabled: true, maxTouchPoints: 1 });
    await page.call("Page.navigate", { url: hosted.url });
    await waitFor(() => page.eval(
      "document.querySelectorAll('#piece-tray .piece-card').length === 3"),
    "gameplay initialization");

    const onboarding = await page.eval(`({
      visible: !document.querySelector('#coach-banner').hidden,
      step: document.querySelector('#coach-banner').dataset.step,
      expanded: document.querySelector('#coach-toggle').getAttribute('aria-expanded')
    })`);
    assert.deepEqual(onboarding, { visible: true, step: "choose", expanded: "true" });
    console.log("PASS: unobtrusive first-play guide is immediately visible");

    // The mobile player sees the target and active board together.
    const modelUi = await page.eval(`({
      levels: document.querySelectorAll('#level-select option').length,
      thumbnailCells: document.querySelectorAll('#mini-model-board .model-cell').length,
      thumbnailVisible: getComputedStyle(document.querySelector('.mini-reference')).display !== 'none',
      desktopReferenceHidden: getComputedStyle(document.querySelector('.model-panel')).display === 'none'
    })`);
    assert.deepEqual(modelUi, {
      levels: 21, thumbnailCells: 16,
      thumbnailVisible: true, desktopReferenceHidden: true
    });
    await page.eval("document.querySelector('#expand-model').click()");
    assert.equal(await page.eval("document.querySelector('#reference-dialog').open"), true);
    assert.equal(await page.eval("document.querySelectorAll('#zoom-model-board .model-cell').length"), 16);
    await page.eval("document.querySelector('#close-reference').click()");
    assert.equal(await page.eval("document.querySelector('#reference-dialog').open"), false);
    console.log("PASS: 21 levels and mobile target thumbnail with accessible zoom");
    // A compatible WebGL implementation should actually draw volumetric geometry,
    // not merely apply a '3D' CSS class to the old pixel art.
    const visual = await page.eval(`({
      boardMode: document.querySelector('#build-board').dataset.visualMode || 'fallback',
      modelMode: document.querySelector('#mini-model-board').dataset.visualMode || 'fallback',
      boardCanvas: document.querySelectorAll('#build-board canvas').length,
      referenceCanvas: document.querySelectorAll('#mini-model-board canvas').length
    })`);
    if (visual.boardMode === "threejs") {
      assert.equal(visual.modelMode, "threejs");
      assert.equal(visual.boardCanvas, 1);
      assert.equal(visual.referenceCanvas, 1);
      console.log("PASS: real Three.js WebGL canvases mounted on board and mobile model");
      const lighting = await page.eval(`({
        modelStudio: document.querySelector('#mini-model-board').dataset.studioLighting,
        boardStudio: document.querySelector('#build-board').dataset.studioLighting,
        referenceShadows: Number(document.querySelector('#mini-model-board').dataset.contactShadows),
        initialShadows: Number(document.querySelector('#build-board').dataset.contactShadows)
      })`);
      assert.equal(lighting.referenceShadows, 3,
        "Three complete polyomino silhouettes should cast contact shadows");
      assert.equal(lighting.initialShadows, 0);
      assert.equal(lighting.modelStudio, "enabled");
      assert.equal(lighting.boardStudio, "enabled");
      console.log("PASS: physically based studio reflections and 3 mobile model contact shadows");
    } else {
      console.log("SKIP: software Chromium cannot initialize WebGL; DOM fallback remains active");
    }


    // Change graphics modes on the same mobile puzzle: no level reset,
    // no extra live WebGL contexts, and settings persist across reload.
    const beforeGraphics = await page.eval(`({
      pieces: document.querySelectorAll('#piece-tray .piece-card').length,
      level: document.querySelector('#level-select').value
    })`);
    assert.equal(await page.eval(
      "document.querySelector('#graphics-quality').value"), "auto");
    if (visual.boardMode === "threejs") {
      const setMode = async (mode) => {
        await page.eval(`(() => {
          const select = document.querySelector('#graphics-quality');
          select.value = '${mode}';
          select.dispatchEvent(new Event('change', { bubbles: true }));
        })()`);
        await waitFor(() => page.eval(
          "document.querySelector('#build-board').dataset.graphicsTier === '" +
            (mode === "auto" ? "balanced" : mode) + "'"),
          "graphics mode " + mode);
      };
      await setMode("eco");
      assert.deepEqual(await page.eval(`({
        model: document.querySelector('#mini-model-board').dataset.studioLighting,
        ratio: Number(document.querySelector('#build-board').dataset.renderPixelRatio),
        canvas: document.querySelectorAll('#build-board canvas').length
      })`), {model: "fallback", ratio: 1, canvas: 1});
      await setMode("high");
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.renderPixelRatio)"), 1.75);
      assert.equal(await page.eval(
        "document.querySelector('#mini-model-board').dataset.studioLighting"), "enabled");
      await setMode("auto");
      console.log("PASS: Android Auto, Fluide and Détaillé switch live without extra canvases");
    }
    assert.deepEqual(await page.eval(`({
      pieces: document.querySelectorAll('#piece-tray .piece-card').length,
      level: document.querySelector('#level-select').value
    })`), beforeGraphics);
    assert.equal(await page.eval(
      "localStorage.getItem('jelly-bricks-graphics-v1')"),
      visual.boardMode === "threejs" ? "auto" : null);
    console.log("PASS: graphics profile changes preserve puzzle and local save state");

    // The new mobile dock must stay actionable without returning to the toolbox.
    const quickState = await page.eval(`({
      visible: getComputedStyle(document.querySelector('#quick-tray')).display !== 'none',
      pieces: document.querySelectorAll('#quick-pieces .quick-piece').length,
      rotateDisabled: document.querySelector('#quick-rotate').disabled
    })`);
    assert.deepEqual(quickState, { visible: true, pieces: 3, rotateDisabled: true });
    await page.eval('document.querySelector(\'#quick-pieces .quick-piece[data-piece-id="A"]\').click()');
    assert.equal(await page.eval("document.querySelector('#quick-rotate').disabled"), false);
    assert.equal(await page.eval(
      "document.querySelector('#coach-banner').dataset.step"), "place");
    assert.equal(await page.eval(
      'document.querySelector(\'#quick-pieces .quick-piece[data-piece-id="A"]\').getAttribute("aria-pressed")'), "true");
    for (let i = 0; i < 4; i++) {
      await page.eval("document.querySelector('#quick-rotate').click()");
    }
    await page.eval("document.querySelector('#quick-toggle').click()");
    assert.equal(await page.eval("document.querySelector('#quick-content').hidden"), true);
    assert.equal(await page.eval(
      "document.querySelector('#quick-toggle').getAttribute('aria-expanded')"), "false");
    await page.eval("document.querySelector('#quick-toggle').click()");
    assert.equal(await page.eval("document.querySelector('#quick-content').hidden"), false);
    console.log("PASS: mobile quick tray selection, rotation and collapse");



    // Rotate the first pink shape from its shuffled orientation into place.
    await page.eval("document.querySelector('.piece-card[data-piece-id=\"A\"]').click()");
    await page.eval("for (let i = 0; i < 3; i++) document.querySelector('#rotate-btn').click()");
    await sleep(500); // smooth-scroll initiated by the mobile selection
    const coords = await page.eval(`(() => {
      document.querySelector('#piece-tray').scrollIntoView({block:'end', behavior:'instant'});
      const source = document.querySelector('.piece-card[data-piece-id="A"] .jelly').getBoundingClientRect();
      const dest = document.querySelector('.slot[data-row="0"][data-col="1"]').getBoundingClientRect();
      return { start: { x: source.left + source.width / 2, y: source.top + source.height / 2 },
        end: { x: dest.left + dest.width / 2, y: dest.top + dest.height / 2 },
        height: innerHeight };
    })()`);
    await waitFor(() => page.eval(
      "getComputedStyle(document.querySelector('#quick-tray')).display === 'none'"),
    "quick dock hidden while full toolbox is visible");
    assert.ok(coords.start.y > 0 && coords.start.y < coords.height, "tray visible for touch");
    assert.ok(coords.end.y > 0 && coords.end.y < coords.height, "board visible for touch");

    await page.touch(coords.start.x, coords.start.y, "touchStart");
    for (let i = 1; i <= 8; i++) {
      const fraction = i / 8;
      await page.touch(coords.start.x + fraction * (coords.end.x - coords.start.x),
        coords.start.y + fraction * (coords.end.y - coords.start.y), "touchMove");
    }
    if (visual.boardMode === "threejs") {
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.ghostMeshes)"), 1,
        "A valid touch drag should preview one continuous 3D jelly shape");
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.ghostCells)"), 3);
      console.log("PASS: seamless 3D gel ghost follows the touching finger");
    }
    await page.touch(coords.end.x, coords.end.y, "touchEnd");
    if (visual.boardMode === "threejs") {
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.ghostMeshes)"), 0,
        "Ghost must disappear after releasing the piece");
    }
    await waitFor(() => page.eval(
      '!!document.querySelector(\'.placed-piece[data-piece-id="A"]\')'),
    "touch-dragged jelly brick");
    console.log("PASS: touch dragging keeps the grabbed jelly cell aligned");
    if (visual.boardMode === "threejs") {
      await waitFor(() => page.eval(
        "document.querySelector('#build-board').dataset.jellyVertexShader === 'compiled'"),
        "dynamic jelly vertex shader on the landed 3D piece");
      console.log("PASS: GPU vertex-deformed jelly shader compiles for landing pieces");
    }

    assert.equal(await page.eval(
      "document.querySelector('#coach-banner').dataset.step"), "continue");
    // Joined A cells must share one seamless material surface on both boards.
    const material = await page.eval(`(() => {
      const reference = [...document.querySelectorAll('#mini-model-board .jelly')];
      const placed = [...document.querySelectorAll('.placed-piece[data-piece-id="A"] .jelly')];
      return {
        referenceJoin: reference.filter(cell => [...cell.classList].some(c => c.startsWith('join-'))).length,
        placedJoin: placed.filter(cell => [...cell.classList].some(c => c.startsWith('join-'))).length,
        joinedRadius: getComputedStyle(placed.find(c => c.classList.contains('join-right'))).borderTopRightRadius,
        tiles: placed.length,
        animated: document.querySelectorAll('.placed-piece.is-settling').length
      };
    })()`);
    assert.ok(material.referenceJoin >= 2);
    assert.equal(material.placedJoin, 3);
    assert.equal(material.joinedRadius, "0px");
    assert.equal(material.tiles, 3);
    assert.equal(material.animated, 1);
    // Ignore the synthetic click immediately after a real touch drag.
    await sleep(450);
    await page.eval('document.querySelector(\'.placed-piece[data-piece-id="A"]\').click()');
    assert.equal(await page.eval(
      "document.querySelectorAll('.placed-piece.is-settling').length"), 0);
    console.log("PASS: seamless jelly joins and settle animation limited to changed piece");


    console.log("BOARD after drag:", await page.eval("JSON.stringify({progress: document.querySelector('#progress-label').textContent,placed:[...document.querySelectorAll('.placed-piece')].map(x=>x.dataset.pieceId)})"));
    // A genuine drag suppresses its trailing synthetic click for 350 ms.
    // Wait before sending a *new* interaction, as a person naturally would.
    await sleep(450);

    // Finish the first level through the actual rendered buttons and inspect victory.
    const remaining = await page.eval(`(async () => {
      const {LEVELS} = await import('./src/game.js');
      return LEVELS[0].pieces.slice(1).map((piece, i) => ({
        id: piece.id, row: piece.solution.row, col: piece.solution.col,
        turns: (4 - (((i + 1) * 3 + 1) % 4)) % 4
      }));
    })()`);
    for (const piece of remaining) {
      const id = JSON.stringify(piece.id);
      await page.eval(`document.querySelector('.piece-card[data-piece-id=' + ${id} + ']').click()`);
      for (let n = 0; n < piece.turns; n++) {
        await page.eval("document.querySelector('#rotate-btn').click()");
      }
      await page.eval(`document.querySelector('.slot[data-row="${piece.row}"][data-col="${piece.col}"]').click()`);
      console.log("BOARD after " + piece.id + ":", await page.eval("JSON.stringify({progress: document.querySelector('#progress-label').textContent,placed:[...document.querySelectorAll('.placed-piece')].map(x=>x.dataset.pieceId),toast:document.querySelector('#toast').textContent})"));
      if (piece.id === "B" && visual.boardMode === "threejs") {
        const reaction = await page.eval(
          "Number(document.querySelector('#build-board').dataset.reactedNeighbors)");
        assert.equal(reaction, 1,
          "Touching the first placed piece should trigger one secondary gel wobble");
        console.log("PASS: WebGL landing triggers adjacent jelly reaction without extra animation loop");
      }
    }
    const learnedGuide = await page.eval(`({
      hidden: document.querySelector('#coach-banner').hidden,
      completed: localStorage.getItem('jelly-bricks-guide-v1')
    })`);
    assert.deepEqual(learnedGuide, { hidden: true, completed: "done" });
    await page.eval("document.querySelector('#coach-toggle').click()");
    assert.equal(await page.eval("document.querySelector('#coach-banner').hidden"), false);
    await page.eval("document.querySelector('#coach-dismiss').click()");
    assert.equal(await page.eval("document.querySelector('#coach-banner').hidden"), true);
    console.log("PASS: guide completes, can be reopened and dismissed");

    try {
      await waitFor(() => page.eval("document.querySelector('#win-dialog').open"), "win dialog", 5000);
    } catch (error) {
      const diagnostics = await page.eval("JSON.stringify({progress: document.querySelector('#progress-label').textContent,placed:[...document.querySelectorAll('.placed-piece')].map(x=>({id:x.dataset.pieceId,left:x.style.left,top:x.style.top})),toast:document.querySelector('#toast').textContent})");
      throw new Error(error.message + " - DOM: " + diagnostics);
    }
    const stats = await page.eval(`({
      stars: document.querySelector('#win-stars').textContent,
      nextUnlocked: JSON.parse(localStorage.getItem('jelly-bricks-progress-v1')).unlocked
    })`);
    assert.equal(stats.stars, "★★★");
    assert.equal(stats.nextUnlocked, 2);
    assert.equal(await page.eval(
      "document.querySelectorAll('#win-particles .win-particle').length"), 32);
    console.log("PASS: first level solved, perfect score, progression saved");
    if (visual.boardMode === "threejs") {
      const meshes = await page.eval(
        "Number(document.querySelector('#build-board').dataset.meshCount)");
      assert.equal(meshes, 3, "Three continuous 3D jelly pieces should be rendered");
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.cellCount)"), 9);
      console.log("PASS: nine puzzle cells are represented by three seamless 3D jelly volumes");
      assert.equal(await page.eval(
        "Number(document.querySelector('#build-board').dataset.contactShadows)"), 3);
      console.log("PASS: finished puzzle keeps independent soft contact shadows below each gel piece");
    }


    await page.eval("document.querySelector('#next-btn').click()");
    assert.equal(await page.eval(
      "document.querySelectorAll('#piece-tray .piece-card').length"), 5);
    await page.eval("document.querySelector('#hint-btn').click()");
    assert.ok(await page.eval("document.querySelectorAll('.slot.is-hint').length") > 0);
    console.log("PASS: next level loads and hint highlights cells");

    // Test that a partially played new level (including hints and placements)
    // survives a full browser navigation on the same origin.
    await page.eval("document.querySelector('#rotate-btn').click()");
    await page.eval("document.querySelector('#rotate-btn').click()");
    await page.eval("document.querySelector('.slot[data-row=\"0\"][data-col=\"0\"]').click()");
    assert.equal(await page.eval(
      "document.querySelectorAll('.placed-piece').length"), 1);
    await page.call("Page.reload", { ignoreCache: true });
    await waitFor(() => page.eval(`document.readyState === 'complete' &&
      document.querySelector('#level-select')?.value === '1' &&
      document.querySelectorAll('.placed-piece').length === 1 &&
      document.querySelector('#hints-label')?.textContent === '1'`),
    "interrupted puzzle restored after reload", 15000);
    console.log("PASS: incomplete level, elapsed session and hint restored on reload");

    // Benchmark the busiest authored 7x7 level without depending on device-specific
    // CPU timing thresholds. The invariant is *retained DOM* during each action.
    await page.eval(`localStorage.setItem('jelly-bricks-progress-v1',
      JSON.stringify({unlocked:21,best:{}}))`);
    await page.call("Page.reload", { ignoreCache: true });
    await waitFor(() => page.eval(
      "document.querySelector('#level-select')?.options.length === 21"),
    "performance run initialized");
    await page.eval(`(() => {
      const picker = document.querySelector('#level-select');
      picker.value = '20';
      picker.dispatchEvent(new Event('change', { bubbles: true }));
    })()`);
    assert.equal(await page.eval(
      "document.querySelectorAll('#build-board .slot').length"), 49);
    const perf = await page.eval(`(() => {
      const firstModel = document.querySelector('#mini-model-board .model-cell');
      const firstLargeModel = document.querySelector('#model-board .model-cell');
      const firstZoomModel = document.querySelector('#zoom-model-board .model-cell');
      const firstSlot = document.querySelector('#build-board .slot');
      const firstCard = document.querySelector('#piece-tray .piece-card');
      const firstQuickCard = document.querySelector('#quick-pieces .quick-piece');
      const firstId = firstQuickCard.dataset.pieceId;
      const start = performance.now();
      for (let i = 0; i < 48; i++) {
        document.querySelector('#quick-pieces .quick-piece[data-piece-id="' + firstId + '"]').click();
        document.querySelector('#quick-rotate').click();
      }
      const elapsed = performance.now() - start;
      return {
        elapsedMs: Math.round(elapsed),
        modelStable: firstModel === document.querySelector('#mini-model-board .model-cell'),
        desktopModelStable: firstLargeModel === document.querySelector('#model-board .model-cell'),
        zoomModelStable: firstZoomModel === document.querySelector('#zoom-model-board .model-cell'),
        slotStable: firstSlot === document.querySelector('#build-board .slot'),
        cardStable: firstCard === document.querySelector('#piece-tray .piece-card'),
        quickStable: firstQuickCard === document.querySelector('#quick-pieces .quick-piece'),
        squares: document.querySelectorAll('#build-board .slot').length,
        selected: document.querySelectorAll('#quick-pieces .quick-piece.is-selected').length,
        referenceSquares: document.querySelectorAll('#mini-model-board .model-cell').length
      };
    })()`);
    assert.equal(perf.modelStable, true);
    assert.equal(perf.desktopModelStable, true);
    assert.equal(perf.zoomModelStable, true);
    assert.equal(perf.slotStable, true);
    assert.equal(perf.cardStable, true);
    assert.equal(perf.quickStable, true);
    assert.equal(perf.squares, 49);
    assert.equal(perf.referenceSquares, 49);
    assert.equal(perf.selected, 1);
    assert.ok(perf.elapsedMs < 5000, "48 render-and-rotate cycles should finish in 5 s on hosted Chromium");
    console.log("PERF Chromium mobile emulation 390x844, 7x7 / 48 interactions: " + perf.elapsedMs + " ms; DOM retained");
    console.log("PASS: maximum-size puzzle keeps model, grid and tray nodes across actions");

    // Install action must be useful even if beforeinstallprompt is unsupported.
    const installVisible = await page.eval(`({
      available: !!document.querySelector('#install-btn'),
      onlineStatus: document.querySelector('#connection-indicator').textContent
    })`);
    assert.equal(installVisible.available, true);
    assert.equal(installVisible.onlineStatus, "Connexion détectée");
    await page.eval("document.querySelector('#install-btn').click()");
    if (await page.eval("document.querySelector('#install-dialog').open")) {
      assert.match(await page.eval(
        "document.querySelector('#install-instructions').textContent"), /Installer|écran/);
      await page.eval("document.querySelector('#install-close').click()");
    }
    console.log("PASS: Android install action with browser fallback");

    // A second navigation after first install gives the page a SW controller.
    await waitFor(() => page.eval(
      "navigator.serviceWorker?.ready.then(() => true)"),
    "service worker registration and offline cache", 20000);
    await page.call("Page.reload", { ignoreCache: false });
    await waitFor(() => page.eval(
      "navigator.serviceWorker?.controller !== null && document.querySelectorAll('#build-board .slot').length === 49"),
    "service worker control", 15000);
    const offlineAssets = await page.eval(`(async () => {
      const worker = await fetch('./sw.js').then(response => response.text());
      const cacheVersion = worker.match(/const CACHE = "([^"]+)"/)?.[1];
      if (!cacheVersion) return [false, false, false, false];
      const cache = await caches.open(cacheVersion);
      return Promise.all(['./index.html', './src/game.js', './src/pwa.js', './styles.css']
        .map(async url => Boolean(await cache.match(url))));
    })()`);
    assert.deepEqual(offlineAssets, [true, true, true, true]);
    await page.call("Network.enable");
    await page.call("Network.emulateNetworkConditions",
      { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 });
    await page.call("Page.reload", { ignoreCache: false });
    await waitFor(() => page.eval(
      "document.querySelectorAll('#build-board .slot').length === 49 && document.querySelector('#level-select')?.value === '20'"),
    "offline restart of level 21", 20000);
    assert.ok(await page.eval(
      "document.querySelector('#connection-indicator').textContent.includes('Hors connexion')"));
    assert.equal(await page.eval(
      "document.querySelectorAll('#piece-tray .piece-card').length"), 10);
    console.log("PASS: PWA fully reloads offline with saved final level and cached assets");
    await page.call("Network.emulateNetworkConditions",
      { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });

    // On-device diagnostic: browser real frame callbacks, storage, PWA assets.
    await page.eval("document.querySelector('#diagnose-btn').click()");
    assert.equal(await page.eval("document.querySelector('#diagnose-dialog').open"), true);
    await page.eval("document.querySelector('#diagnose-run').click()");
    await waitFor(() => page.eval(
      "document.querySelector('#diagnose-status').textContent.includes('terminé')"),
    "Android diagnostic completed", 15000);
    const diagnosticReport = await page.eval(
      "document.querySelector('#diagnose-output').textContent");
    assert.match(diagnosticReport, /Stockage des parties : opérationnel/);
    assert.match(diagnosticReport, /6\/6 fichiers \(jelly-bricks-static-v\d+\)/);
    assert.match(diagnosticReport, /Rafraîchissement estimé : \d+ images\/s/);
    assert.match(diagnosticReport, /Aucune donnée.*envoyée automatiquement/);
    assert.equal(await page.eval(
      "document.querySelector('#diagnose-copy').disabled"), false);
    await page.eval("document.querySelector('#diagnose-close').click()");
    assert.equal(await page.eval("document.querySelector('#diagnose-dialog').open"), false);
    console.log("PASS: real-browser Android diagnostics, offline cache, storage and FPS estimate");

    assert.deepEqual(page.exceptions, [], "JavaScript must not throw uncaught runtime errors");
    console.log("PASS: no browser JavaScript exceptions");
  } finally {
    socket?.close();
    if (browser) {
      browser.processHandle.kill();
      await Promise.race([
        new Promise((done) => browser.processHandle.once("exit", done)),
        sleep(1500)
      ]);
    }
    server?.close();
    if (browser?.dir) {
      try {
        rmSync(browser.dir, { recursive: true, force: true,
          maxRetries: 8, retryDelay: 150 });
      } catch (error) {
        console.warn("Chrome temp cleanup warning:", error.message);
      }
    }
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
