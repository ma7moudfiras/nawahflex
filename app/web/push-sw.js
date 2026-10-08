// عامل إشعارات Push — مستقلّ عن Flutter (الذي لا يسجّل عاملاً: انظر
// flutter_bootstrap.js). عمله اثنان فقط: عرض الإشعار حين يصل، وفتح البوابة
// على الصفحة المعنية حين يُنقر. يسجّله التطبيق من lib/core/push_web.dart.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'أكاديمية نواة', {
      body: data.body || '',
      icon: '/app/icons/Icon-192.png',
      badge: '/app/icons/Icon-192.png',
      tag: data.tag,
      lang: 'ar',
      dir: 'rtl',
      data: { url: data.url || '/app/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/app/';
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        if (new URL(client.url).pathname.startsWith('/app')) {
          if ('navigate' in client) await client.navigate(url).catch(() => {});
          return client.focus();
        }
      }
      return self.clients.openWindow(url);
    })(),
  );
});
