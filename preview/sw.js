const CACHE_NAME = 'televault-personal-v2';
const ASSETS = [
  '/preview/index.html',
  '/preview/manifest.json',
  '/preview/icon.svg'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// Network-First strategy: Always fetch latest code from server so mobile app updates immediately!
self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('/api/v1/')) {
    return;
  }
  event.respondWith(
    fetch(event.request, { cache: 'no-store' })
      .then((response) => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});

