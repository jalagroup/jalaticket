import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Local notifications plugin (for showing notifications when app is in foreground)
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize FCM + Local Notifications
  Future<void> initNotifications() async {
    // Request permissions (iOS only really needs this)
    await _firebaseMessaging.requestPermission();

    // Get FCM token
    final fCMToken = await _firebaseMessaging.getToken();
    print('📲 FCM Token: $fCMToken');

    // Initialize foreground notification handling
    await initLocalNotifications();

    // Handle messages while the app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });

    // Handle messages when user taps notification (background / terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📩 Notification clicked: ${message.data}');
      // TODO: Navigate user to specific screen
    });
  }

  /// Setup local notifications for foreground
  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);
  }
}
