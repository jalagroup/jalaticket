// Firebase Cloud Messaging Service Worker
// Required for background push notifications on web browsers

importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA_Q9O8IjJZic-87u8HWP5dcqxL0uEnmRQ',
  appId: '1:532032178313:web:7dc2298d4b54f00517de58',
  messagingSenderId: '532032178313',
  projectId: 'jalaticketing',
  authDomain: 'jalaticketing.firebaseapp.com',
  storageBucket: 'jalaticketing.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages (when app tab is not focused or browser is closed)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);

  // If the app tab is open and focused, Flutter handles the notification via
  // onMessage — skip the browser notification to avoid duplicates.
  return clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((windowClients) => {
      for (const client of windowClients) {
        if (client.focused) {
          console.log('[firebase-messaging-sw.js] App is in foreground, skipping browser notification.');
          return;
        }
      }

      const title = payload.notification?.title || 'New Notification';
      const options = {
        body: payload.notification?.body || '',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        data: payload.data || {},
        requireInteraction: false,
      };

      return self.registration.showNotification(title, options);
    });
});

// Handle notification click — focus existing tab or open new one
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus an existing tab if available
      for (const client of windowClients) {
        if ('focus' in client) {
          client.focus();
          // Send navigation data to the Flutter app
          client.postMessage({ type: 'NOTIFICATION_CLICK', data });
          return;
        }
      }
      // No open tab — open a new one
      return clients.openWindow('/');
    })
  );
});
