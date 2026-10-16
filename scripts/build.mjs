import { build } from "esbuild";
import { cpSync, copyFileSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";

// One self-contained, same-origin application bundle. No runtime CDN, key or
// remote shader/image requests; GitHub Pages and offline mode share this build.
rmSync("dist", { recursive: true, force: true });
mkdirSync("dist/src", { recursive: true });
for (const asset of ["styles.css", "icon.svg", "icon-192.png", "icon-512.png",
  "manifest.webmanifest", "sw.js"]) {
  copyFileSync(asset, join("dist", asset));
}
// The source puzzle modules are retained for offline checks and browser-smoke's
// deterministic puzzle solution imports. The HTML loads only the app bundle.
cpSync("src", "dist/src", { recursive: true });
const html = readFileSync("index.html", "utf8");
const sourceTag = '<script type="module" src="./src/main.js"></script>';
if (!html.includes(sourceTag)) throw new Error("Missing script tag for release build");
writeFileSync("dist/index.html",
  html.replace(sourceTag, '<script type="module" src="./app.js"></script>'));
writeFileSync("dist/.nojekyll", "");
await build({
  entryPoints: ["src/main.js"],
  outfile: "dist/app.js",
  bundle: true,
  format: "esm",
  platform: "browser",
  target: ["chrome100", "safari16", "firefox115"],
  minify: true,
  legalComments: "inline",
  logLevel: "info"
});
console.log("Offline-ready Three.js WebGL bundle built in dist/");
