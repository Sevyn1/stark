"""Disable old Flutter offline caching for the local, emulator-backed preview."""
from pathlib import Path
root = Path(__file__).resolve().parent.parent
worker = root / 'build/web/flutter_service_worker.js'
worker.write_text('''// Local preview cleanup: only this Flutter app's generated offline caches.
self.addEventListener('install', event => { self.skipWaiting(); });
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    await Promise.all(['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'].map(name => caches.delete(name)));
    await self.clients.claim();
    await self.registration.unregister();
  })());
});
''')
