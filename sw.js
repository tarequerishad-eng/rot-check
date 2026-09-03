/* Rot Check service worker.
   Cache-first for the shell so the game opens instantly and plays
   with no connection. Bump CACHE on every release or users keep
   the old build. */
const CACHE = "rotcheck-v1";

const SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon.svg"
];

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE)
      // addAll rejects the whole batch on one 404, which would leave the
      // SW uninstalled; add individually so a missing icon isn't fatal.
      .then((c) => Promise.all(SHELL.map((u) => c.add(u).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // Never cache ad or analytics traffic — it must always hit the network.
  if (/googlesyndication|doubleclick|google-analytics|googletagmanager|posthog/.test(url.hostname)) return;

  // Fonts: cache after first fetch (stale-while-revalidate).
  if (/fonts\.(googleapis|gstatic)\.com/.test(url.hostname)) {
    e.respondWith(
      caches.open(CACHE).then((c) =>
        c.match(req).then((hit) => {
          const net = fetch(req).then((res) => { c.put(req, res.clone()); return res; }).catch(() => hit);
          return hit || net;
        })
      )
    );
    return;
  }

  // HTML documents: network-first, so a new deploy is picked up on the next
  // launch instead of users being stuck on a cached build. Falls back to the
  // cache (then to index.html) when offline.
  const isDoc = req.mode === "navigate" || /\.html?$/.test(url.pathname) || url.pathname.endsWith("/");
  if (isDoc) {
    e.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req).then((hit) => hit || caches.match("./index.html")))
    );
    return;
  }

  // Everything else (icons, manifest): cache-first, it rarely changes.
  e.respondWith(
    caches.match(req).then((hit) =>
      hit || fetch(req).catch(() => caches.match("./index.html"))
    )
  );
});
