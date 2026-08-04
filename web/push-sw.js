/* Tujh Web Push service worker — works when the tab is closed/backgrounded. */

self.addEventListener('push', (event) => {
  event.waitUntil(handlePush(event));
});

async function handlePush(event) {
  let payload = { title: 'Tujh', body: 'Новое сообщение', conversationId: '' };
  try {
    if (event.data) {
      payload = { ...payload, ...event.data.json() };
    }
  } catch (_) {
    try {
      payload.body = event.data ? event.data.text() : payload.body;
    } catch (_) {}
  }

  // App still open (even unfocused): realtime + local Notification handle it.
  const clientsList = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  if (clientsList.length > 0) return;

  await self.registration.showNotification(payload.title || 'Tujh', {
    body: payload.body || '',
    tag: payload.conversationId || 'tujh',
    data: { conversationId: payload.conversationId || '' },
    renotify: true,
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const conversationId = event.notification.data?.conversationId || '';
  const targetUrl = conversationId
    ? `/?chat=${encodeURIComponent(conversationId)}`
    : '/';

  event.waitUntil(
    (async () => {
      const clientsList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      for (const client of clientsList) {
        if ('focus' in client) {
          await client.focus();
          client.postMessage({ type: 'open_chat', conversationId });
          return;
        }
      }
      await self.clients.openWindow(targetUrl);
    })(),
  );
});
