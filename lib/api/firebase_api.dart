import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show notifications while app is in foreground on iOS
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final fCMToken = await _firebaseMessaging.getToken();
    if (kDebugMode) print('📲 FCM Token: $fCMToken');

    await initLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('🔔 Foreground message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null && !kIsWeb) {
        // On iOS, setForegroundNotificationPresentationOptions handles display.
        // Local notifications are used as a fallback for custom UI.
        if (defaultTargetPlatform == TargetPlatform.android) {
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
      }
    });
  }

  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotifications.initialize(settings);
  }
}
