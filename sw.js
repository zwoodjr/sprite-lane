/* Spirit Lane — cache shell for offline replay after first online visit. */
const CACHE = "spirit-lane-v27";
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
  "./assets/hero/hero-quirling-endgame.png",
  "./assets/hero/hero-multifist-endgame.png",
  "./assets/hero/hero-floatdrone-endgame.png",
  "./assets/hero/hero-sparkgrub-endgame.png",
  "./assets/hero/hero-crest-map-endgame.png",
  "./assets/hero/models/bakugo-atk0.png",
  "./assets/hero/models/bakugo-atk1.png",
  "./assets/hero/models/bakugo-idle0.png",
  "./assets/hero/models/bakugo-idle1.png",
  "./assets/hero/models/blastcrown-atk0.png",
  "./assets/hero/models/blastcrown-atk1.png",
  "./assets/hero/models/blastcrown-idle0.png",
  "./assets/hero/models/blastcrown-idle1.png",
  "./assets/hero/models/floatdrone-walk0.png",
  "./assets/hero/models/floatdrone-walk1.png",
  "./assets/hero/models/floatdrone-walk2.png",
  "./assets/hero/models/floatdrone-walk3.png",
  "./assets/hero/models/halfcold-atk0.png",
  "./assets/hero/models/halfcold-atk1.png",
  "./assets/hero/models/halfcold-idle0.png",
  "./assets/hero/models/halfcold-idle1.png",
  "./assets/hero/models/hoverbind-atk0.png",
  "./assets/hero/models/hoverbind-atk1.png",
  "./assets/hero/models/hoverbind-idle0.png",
  "./assets/hero/models/hoverbind-idle1.png",
  "./assets/hero/models/howitzer-atk0.png",
  "./assets/hero/models/howitzer-atk1.png",
  "./assets/hero/models/howitzer-idle0.png",
  "./assets/hero/models/howitzer-idle1.png",
  "./assets/hero/models/multifist-walk0.png",
  "./assets/hero/models/multifist-walk1.png",
  "./assets/hero/models/multifist-walk2.png",
  "./assets/hero/models/multifist-walk3.png",
  "./assets/hero/models/quirling-walk0.png",
  "./assets/hero/models/quirling-walk1.png",
  "./assets/hero/models/quirling-walk2.png",
  "./assets/hero/models/quirling-walk3.png",
  "./assets/hero/models/sparkfist-atk0.png",
  "./assets/hero/models/sparkfist-atk1.png",
  "./assets/hero/models/sparkfist-idle0.png",
  "./assets/hero/models/sparkfist-idle1.png",
  "./assets/hero/models/sparkgrub-walk0.png",
  "./assets/hero/models/sparkgrub-walk1.png",
  "./assets/hero/models/sparkgrub-walk2.png",
  "./assets/hero/models/sparkgrub-walk3.png",
  "./assets/hero/models/todoroki-atk0.png",
  "./assets/hero/models/todoroki-atk1.png",
  "./assets/hero/models/todoroki-idle0.png",
  "./assets/hero/models/todoroki-idle1.png",
  "./assets/hero/models/zerofield-atk0.png",
  "./assets/hero/models/zerofield-atk1.png",
  "./assets/hero/models/zerofield-idle0.png",
  "./assets/hero/models/zerofield-idle1.png",
  "./fonts/PressStart2P.woff2",
  "./manifest.webmanifest",
  "./icon.svg",
  "./icon-180.png",
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
  const url = new URL(req.url);
  const isCode =
    /\.(js|css|html?)$/i.test(url.pathname) ||
    url.pathname.endsWith("/") ||
    url.pathname.endsWith("/index.html");

  // Prefer network for code so map/shop art updates are not stuck on old SW caches.
  if (isCode) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy)).catch(() => {});
          return res;
        })
        .catch(() => caches.match(req))
    );
    return;
  }

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
