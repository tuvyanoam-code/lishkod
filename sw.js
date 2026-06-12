/* Service Worker — caches the app shell for true offline launch.
   HTML is served NETWORK-FIRST so new deploys appear immediately;
   other local assets are cache-first (refreshed in the background).
   API responses (Sefaria/Hebcal/Google) are cross-origin and handled
   separately by the in-app localStorage cache (jfetch). */
const CACHE = 'lishkod-v13';
// Precache only the shell + the DEFAULT font (Keter YG). The other 5 fonts are
// large and only used if the reader picks them in settings, so they're cached
// lazily on first use by the cache-first fetch handler below — this cuts the
// first-visit download from ~783KB of fonts to ~29KB.
const ASSETS = [
  './',
  'index.html',
  'manifest.json',
  'logo.png',
  'apple-touch-icon.png',
  'icon-192.png',
  'icon-512.png',
  'icon-maskable-512.png',
  'fonts/KeterYG-Medium.woff2',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      // cache each asset individually so one 404 doesn't abort the whole install
      .then(c => Promise.all(ASSETS.map(a => c.add(a).catch(() => {}))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// ── Daily reminder push ──
// Phase 1: the push carries no payload; show a fixed reminder.
// (Phase 2 will read local study progress here to personalise the text.)
self.addEventListener('push', e => {
  let data = {};
  try { data = e.data ? e.data.json() : {}; } catch (_) {}
  const title = data.title || 'לימוד יומי';
  const body  = data.body  || 'הגיע זמן לִשְׁקֹד 📖';
  e.waitUntil(self.registration.showNotification(title, {
    body, icon: 'icon-192.png', badge: 'icon-192.png',
    dir: 'rtl', lang: 'he', tag: 'daily-reminder', renotify: true,
    data: { url: './' }
  }));
});
// Tapping the notification focuses an open tab or opens the app.
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || './';
  e.waitUntil((async () => {
    const all = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if ('focus' in c) { try { await c.focus(); } catch (_) {} return; }
    }
    if (clients.openWindow) return clients.openWindow(url);
  })());
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return; // let API calls pass through

  // HTML / navigations → network-first, so a fresh deploy shows up at once.
  const isHTML = req.mode === 'navigate' ||
                 (req.headers.get('accept') || '').includes('text/html');
  if (isHTML) {
    e.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        return res;
      }).catch(() => caches.match(req).then(c => c || caches.match('index.html')))
    );
    return;
  }

  // Other same-origin assets → cache-first, refresh in the background.
  e.respondWith(
    caches.match(req).then(cached =>
      cached ||
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        return res;
      }).catch(() => cached)
    )
  );
});
