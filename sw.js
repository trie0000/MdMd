// MdMd service worker.
// Strategy: pre-cache every asset on install. After activation, serve
// every same-origin request from cache. The PWA must work fully offline.
// Bump CACHE_VERSION whenever any asset under PRECACHE changes.

const CACHE_VERSION = 'mdmd-v1';

const PRECACHE = [
  './',
  './index.html',
  './styles.css',
  './app.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',

  './vendor/react.production.min.js',
  './vendor/react-dom.production.min.js',
  './vendor/markdown-it.min.js',
  './vendor/purify.min.js',

  './vendor/codemirror/codemirror.min.js',
  './vendor/codemirror/codemirror.min.css',
  './vendor/codemirror/theme/dracula.min.css',
  './vendor/codemirror/addon/overlay.min.js',
  './vendor/codemirror/addon/continuelist.min.js',
  './vendor/codemirror/mode/xml.min.js',
  './vendor/codemirror/mode/javascript.min.js',
  './vendor/codemirror/mode/css.min.js',
  './vendor/codemirror/mode/markdown.min.js',
  './vendor/codemirror/mode/gfm.min.js',

  './vendor/highlight/highlight.min.js',
  './vendor/highlight/default.min.css',

  './vendor/fonts/fonts.css',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa0ZL7SUc.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa1ZL7.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa1pL7SUc.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa25L7SUc.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa2JL7SUc.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa2ZL7SUc.woff2',
  './vendor/fonts/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa2pL7SUc.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPx3cwhsk.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPx7cwhsk.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPxDcwg.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPxPcwhsk.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPxTcwhsk.woff2',
  './vendor/fonts/tDbv2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKwBNntkaToggR7BYRbKPx_cwhsk.woff2',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Only handle same-origin requests. Anything cross-origin would be a bug
  // (this build intentionally has zero external references) — pass through
  // unmodified so it surfaces as a network error rather than a silent fail.
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      // Not in cache (e.g. a navigation to a sub-path). Fall back to the
      // root document, which is precached.
      if (req.mode === 'navigate') {
        return caches.match('./index.html');
      }
      return fetch(req);
    })
  );
});
