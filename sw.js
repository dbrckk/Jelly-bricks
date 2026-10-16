const CACHE = "jelly-bricks-static-v22";
const ASSETS = ["./", "./index.html", "./styles.css", "./src/game.js", "./src/interaction.js",
  "./src/session.js", "./src/feedback.js", "./src/material.js", "./src/coach.js", "./src/pwa.js", "./src/diagnostics.js", "./src/scene3d.js", "./src/magnet.js", "./src/jelly-physics.js", "./src/gel-contours.js", "./src/gel-lighting.js", "./src/gel-reactions.js", "./src/graphics-quality.js", "./src/frame-budget.js", "./src/gel-surface.js", "./src/main.js", "./app.js", "./manifest.webmanifest", "./icon.svg", "./icon-192.png", "./icon-512.png"];
self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS))
    .then(() => self.skipWaiting()));
});
self.addEventListener("activate", (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys
    .filter((key) => key.startsWith("jelly-bricks-static-") && key !== CACHE)
    .map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone();
        void caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    }).catch(async () => (await caches.match(request)) || caches.match("./index.html")));
    return;
  }
  event.respondWith(caches.match(request).then((cached) =>
    cached || fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone();
        void caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    })));
});
