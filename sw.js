/* Spirit Lane — cache shell for offline replay after first online visit. */
const CACHE = "spirit-lane-v16";
const ASSETS = [
  "./",
  "./index.html",
  "./styles.css",
  "./game.js",
  "./sprites.js",
  "./assets/hero/endgame-art.js",
  "./assets/hero/hero-sparkfist-endgame.png",
  "./assets/hero/hero-blastcrown-endgame.png",
  "./assets/hero/hero-bakugo-endgame.png",
  "./assets/hero/hero-howitzer-endgame.png",
  "./assets/hero/hero-hoverbind-endgame.png",
  "./assets/hero/hero-zerofield-endgame.png",
  "./assets/hero/hero-todoroki-endgame.png",
  "./assets/hero/hero-halfcold-endgame.png",
  "./assets/hero/hero-sparkfist-64.png",
  "./assets/hero/hero-blastcrown-64.png",
  "./assets/hero/hero-bakugo-64.png",
  "./assets/hero/hero-howitzer-64.png",
  "./assets/hero/hero-hoverbind-64.png",
  "./assets/hero/hero-zerofield-64.png",
  "./assets/hero/hero-todoroki-64.png",
  "./assets/hero/hero-halfcold-64.png",
  "./assets/hero/hero-quirling-endgame.png",
  "./assets/hero/hero-multifist-endgame.png",
  "./assets/hero/hero-floatdrone-endgame.png",
  "./assets/hero/hero-sparkgrub-endgame.png",
  "./assets/hero/hero-quirling-64.png",
  "./assets/hero/hero-multifist-64.png",
  "./assets/hero/hero-floatdrone-64.png",
  "./assets/hero/hero-sparkgrub-64.png",
  "./assets/hero/hero-crest-map-endgame.png",
  "./fonts/PressStart2P.woff2",
  "./manifest.webmanifest",
  "./icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy)).catch(() => {});
          return res;
        })
        .catch(() => cached);
    })
  );
});
