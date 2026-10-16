import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";

const root = new URL("../", import.meta.url);
function file(path) { return readFileSync(new URL(path, root), "utf8"); }

test("all static application assets exist", () => {
  for (const path of ["index.html", "styles.css", "src/main.js",
    "src/game.js", "src/pwa.js", "src/diagnostics.js", "sw.js", "icon.svg", "manifest.webmanifest"]) {
    assert.ok(existsSync(new URL(path, root)), path + " missing");
  }
});
test("installable manifest uses relative URLs for project pages hosting", () => {
  const manifest = JSON.parse(file("manifest.webmanifest"));
  assert.equal(manifest.display, "standalone");
  assert.equal(manifest.start_url, "./");
  assert.equal(manifest.scope, "./");
  assert.ok(manifest.icons.length > 0);
  assert.ok(manifest.icons.every((icon) => icon.src.startsWith("./")));
});
test("all service worker precache paths exist", () => {
  const worker = file("sw.js");
  const match = worker.match(/const ASSETS = \[([\s\S]*?)\];/);
  assert.ok(match, "precache array missing");
  const paths = [...match[1].matchAll(/"([^"]+)"/g)].map((entry) => entry[1]);
  assert.ok(paths.length >= 6);
  for (const path of paths) {
    assert.ok(path.startsWith("./"));
    if (path !== "./") {
      const source = path === "./app.js" ? "dist/app.js" : path;
      assert.ok(existsSync(new URL(source, root)), path + " missing");
    }
  }
});
test("all interactive DOM controls are present", () => {
  const html = file("index.html");
  const script = file("src/main.js");
  const ids = [...script.matchAll(/\$\("([^"]+)"\)/g)].map((item) => item[1]);
  assert.ok(ids.length > 20);
  for (const id of ids) {
    assert.ok(html.includes('id="' + id + '"'), "Missing control: " + id);
  }
});

test("Android PWA icons have valid PNG headers and declared dimensions", () => {
  for (const size of [192, 512]) {
    const path = "icon-" + size + ".png";
    const bytes = readFileSync(new URL(path, root));
    assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
    assert.equal(bytes.readUInt32BE(16), size);
    assert.equal(bytes.readUInt32BE(20), size);
    assert.equal(bytes[24], 2, "PNG must use 2-bit indexed color");
    assert.equal(bytes[25], 3, "PNG must use a palette");
  }
});

test("built 3D production entry is bundled and offline compatible", () => {
  const html = file("dist/index.html");
  const script = file("dist/app.js");
  assert.match(html, /src="\.\/app\.js"/);
  assert.doesNotMatch(html, /src="\.\/src\/main\.js"/);
  assert.ok(script.length > 100000, "3D engine should be bundled locally");
  assert.ok(script.includes("WebGL"), "Three.js WebGL renderer expected");
  assert.ok(!html.includes("cdn.jsdelivr") && !html.includes("unpkg.com"));
  const worker = file("sw.js");
  assert.ok(worker.includes('"./app.js"'));
  const releaseFile = new URL("dist/src/game.js", root);
  assert.ok(existsSync(releaseFile), "puzzle source must remain available for diagnostic");
});
