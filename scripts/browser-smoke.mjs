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

const ROOT = process.cwd();
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
    assert.ok(coords.start.y > 0 && coords.start.y < coords.height, "tray visible for touch");
    assert.ok(coords.end.y > 0 && coords.end.y < coords.height, "board visible for touch");

    await page.touch(coords.start.x, coords.start.y, "touchStart");
    for (let i = 1; i <= 8; i++) {
      const fraction = i / 8;
      await page.touch(coords.start.x + fraction * (coords.end.x - coords.start.x),
        coords.start.y + fraction * (coords.end.y - coords.start.y), "touchMove");
    }
    await page.touch(coords.end.x, coords.end.y, "touchEnd");
    await waitFor(() => page.eval(
      '!!document.querySelector(\'.placed-piece[data-piece-id="A"]\')'),
    "touch-dragged jelly brick");
    console.log("PASS: touch dragging keeps the grabbed jelly cell aligned");

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
    }
    await waitFor(() => page.eval("document.querySelector('#win-dialog').open"), "win dialog");
    const stats = await page.eval(`({
      stars: document.querySelector('#win-stars').textContent,
      nextUnlocked: JSON.parse(localStorage.getItem('jelly-bricks-progress-v1')).unlocked
    })`);
    assert.equal(stats.stars, "★★★");
    assert.equal(stats.nextUnlocked, 2);
    console.log("PASS: first level solved, perfect score, progression saved");

    await page.eval("document.querySelector('#next-btn').click()");
    assert.equal(await page.eval(
      "document.querySelectorAll('#piece-tray .piece-card').length"), 5);
    await page.eval("document.querySelector('#hint-btn').click()");
    assert.ok(await page.eval("document.querySelectorAll('.slot.is-hint').length") > 0);
    console.log("PASS: next level loads and hint highlights cells");

    assert.deepEqual(page.exceptions, [], "JavaScript must not throw uncaught runtime errors");
    console.log("PASS: no browser JavaScript exceptions");
  } finally {
    socket?.close();
    browser?.processHandle.kill();
    server?.close();
    if (browser?.dir) rmSync(browser.dir, { recursive: true, force: true });
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
