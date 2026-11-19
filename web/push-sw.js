// Lovel – Service Worker nur für Push-Benachrichtigungen.
// Inhalt kommt vom Server (Edge Function push-send):
//   { title, body, url, tag }   url ist eine App-Route, z. B. /chats/<id>

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { title: 'Lovel', body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Lovel', {
      body: data.body || '',
      tag: data.tag || undefined,
      renotify: Boolean(data.tag),
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: data.url || '/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = (event.notification.data && event.notification.data.url) || '/';
  // Die App nutzt Hash-Routen: <scope>#/chats/<id>
  const target = new URL(self.registration.scope + '#' + route).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (client.url.startsWith(self.registration.scope)) {
        await client.focus();
        try {
          return await client.navigate(target);
        } catch (_) {
          // Seite wird (noch) nicht von diesem Worker gesteuert.
          return self.clients.openWindow(target);
        }
      }
    }
    return self.clients.openWindow(target);
  })());
});
