/* =====================================================================
 * SUBH PAPER COMPANY - Service Worker (PWA offline app shell)
 * ---------------------------------------------------------------------
 * Goal: the app itself (shell) opens instantly and even without internet,
 * while DATA always goes to the network (never cached) so realtime sync
 * and autosave keep working exactly as before.
 *
 * Strategy
 *   - /api/*            : NOT intercepted -> straight to server.py (sync)
 *   - app shell (HTML)  : NETWORK first (always fresh code), cache fallback
 *   - other same-origin : cache first (fast), refreshed in background
 *   - cross-origin (fonts): cache first, fallback network
 *
 * Bump CACHE when you ship a breaking shell change (or keep NETWORK-first
 * for HTML, which already delivers updates immediately when online).
 * ===================================================================== */

const CACHE = 'subh-orders-v2';
const SHELL = [
  './',
  './index.html',
  './manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(SHELL).catch(() => undefined))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;                    // never touch POST (saves)

  const url = new URL(req.url);
  const sameOrigin = (url.origin === self.location.origin);

  // ---- LIVE DATA: never intercept, always straight to the server ----
  // /api/*   -> server.py load/save/version (realtime sync)
  // /data/*  -> fallback database JSON (must stay fresh, never stale)
  if (url.pathname.indexOf('/api/') === 0) return;
  if (url.pathname.indexOf('/data/') === 0) return;

  // ---- Cross-origin: cache ONLY fonts. Anything else (notably the
  // Google Drive /exec JSON) must always hit the network so cloud sync
  // never serves a stale copy. ----
  const isFont = (req.destination === 'font') ||
                 /\.(woff2?|ttf|otf|eot)$/i.test(url.pathname);
  if (!sameOrigin && !isFont) return;

  const isShell = req.mode === 'navigate' ||
                  url.pathname.endsWith('.html') ||
                  url.pathname === '/' ||
                  url.pathname === '/index.html';

  if (sameOrigin && isShell) {
    // NETWORK first -> user always gets the newest code when online;
    // CACHE fallback -> app still opens with no internet.
    event.respondWith(
      fetch(req)
        .then((resp) => {
          if (resp && resp.ok) {
            const copy = resp.clone();
            caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => undefined);
          }
          return resp;
        })
        .catch(() =>
          caches.match(req).then((r) => r || caches.match('./index.html'))
        )
    );
    return;
  }

  // Static assets / fonts: CACHE first (fast + works offline),
  // then refresh the cache in the background.
  event.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req)
        .then((resp) => {
          if (resp && resp.ok) {
            const copy = resp.clone();
            caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => undefined);
          }
          return resp;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
