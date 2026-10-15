import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";

const root = new URL("../", import.meta.url);
function file(path) { return readFileSync(new URL(path, root), "utf8"); }

test("all static application assets exist", () => {
  for (const path of ["index.html", "styles.css", "src/main.js",
    "src/game.js", "sw.js", "icon.svg", "manifest.webmanifest"]) {
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
    if (path !== "./") assert.ok(existsSync(new URL(path, root)), path + " missing");
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
