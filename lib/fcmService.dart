// Enhanced FCMService.dart with navigation handling
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';

// Global navigation key for handling navigation from FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Enhanced FCMService with better navigation handling
class FCMService {
  static String? _currentToken;
  static bool _isSetup = false;
  static Function(RemoteMessage)? _onForegroundMessage;
  static Function(RemoteMessage)? _onMessageTap;
  static StreamSubscription<String>? _tokenRefreshSub;

  // Navigation callback for handling message tap navigation
  static Function(String?, String?)? _onNavigateToChat;
  static Function(String?)? _onNavigateToTicket;
  static Map<String, dynamic>? _pendingNavigation;

  // VAPID key for web push notifications.
  // Get this from Firebase Console → Project Settings → Cloud Messaging
  // → Web configuration → Generate key pair, then paste the value below.
  static const String _webVapidKey = 'BJKG1UZoHzn1p4mDzNBVDRG0TTNeMhWFtgDxFbXuUlys__657aG4GZykYU-Sr_OFwV1yeQ_sgSrp9Zs369jKRWQ';

  // Check if FCM is supported on current platform
  static bool get isSupported {
    return true; // Supported on mobile and web
  }

  // Setup FCM after login with user context
  static Future<void> setupForUser(UserModel user) async {
    try {
      if (kDebugMode) print('🔔 FCM: Setting up for user: ${user.email}');

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (kDebugMode) print('🔔 FCM: Permission = ${settings.authorizationStatus}');

      final isAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAllowed) {
        if (kDebugMode) print('🔔 FCM: Permission denied — cannot get token');
        return;
      }

      // Cancel any previous refresh listener (e.g. from a previous login)
      await _tokenRefreshSub?.cancel();

      // Register onTokenRefresh BEFORE calling getToken().
      // On iOS, APNs registration can complete seconds after getToken() returns null.
      // This stream fires the moment a token becomes available or rotates.
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        if (kDebugMode) print('🔔 FCM: onTokenRefresh fired → saving token');
        _currentToken = newToken;
        await _saveTokenForUser(user.id, newToken);
      });

      // Try to get the token immediately
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webVapidKey)
          : await messaging.getToken();

      if (kDebugMode) {
        print('🔔 FCM: getToken() = ${token != null ? "${token.substring(0, 20)}..." : "null"}');
      }

      if (token != null) {
        _currentToken = token;
        await _saveTokenForUser(user.id, token);
      } else {
        if (kDebugMode) print('🔔 FCM: token null now — onTokenRefresh will save it when APNs is ready');
      }

      // Set up message handlers and topics only once per session
      if (!_isSetup) {
        await _subscribeToUserTopics(user);
        _setupMessageHandlers();
        _isSetup = true;
      }

      if (kDebugMode) print('🔔 FCM: Setup complete for ${user.email}');
    } catch (e) {
      if (kDebugMode) print('🔔 FCM: Error in setupForUser: $e');
    }
  }

  // Set navigation callbacks
  static void setNavigationCallbacks({
    Function(String?, String?)? onNavigateToChat,
    Function(String?)? onNavigateToTicket,
  }) {
    _onNavigateToChat = onNavigateToChat;
    _onNavigateToTicket = onNavigateToTicket;
  }

  static Future<void> _saveTokenForUser(String userId, String token) async {
    try {
      if (kDebugMode) {
        print('Saving FCM token for user: $userId (web: $kIsWeb)');
      }

      // Each platform stores its token in its own column independently.
      await supabase.from('users').update(
        kIsWeb ? {'fcm_token_web': token} : {'fcm_token': token},
      ).eq('id', userId);

      if (kDebugMode) {
        print('FCM token saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
      throw e;
    }
  }

  static Future<void> _subscribeToUserTopics(UserModel user) async {
    // Topic subscriptions are not supported on web
    if (kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Subscribe to user-specific topic
      await messaging.subscribeToTopic('user_${user.id}');
      if (kDebugMode) {
        print('Subscribed to user topic: user_${user.id}');
      }

      // Subscribe to department topic if user has department
      if (user.departmentId != null) {
        await messaging.subscribeToTopic('department_${user.departmentId}');
        if (kDebugMode) {
          print(
              'Subscribed to department topic: department_${user.departmentId}');
        }
      }

      // Subscribe to place topic if user has place
      if (user.placeId != null) {
        await messaging.subscribeToTopic('place_${user.placeId}');
        if (kDebugMode) {
          print('Subscribed to place topic: place_${user.placeId}');
        }
      }

      // Subscribe to role-based topic
      await messaging.subscribeToTopic('role_${user.userType.value}');
      if (kDebugMode) {
        print('Subscribed to role topic: role_${user.userType.value}');
      }

      if (kDebugMode) {
        print('All topic subscriptions completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topics: $e');
      }
    }
  }

  static void _setupMessageHandlers() {
    // Skip on unsupported platforms
    if (!isSupported) return;

    try {
      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Foreground message received: ${message.notification?.title}');
          print('Message data: ${message.data}');
        }
        _handleForegroundMessage(message);
      });

      // Background/terminated app message handlers
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print(
              'Message opened app from background: ${message.notification?.title}');
        }
        _handleMessageNavigation(message);
      });

      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          if (kDebugMode) {
            print(
                'App opened from terminated state by message: ${message.notification?.title}');
          }
          // Delay navigation to ensure app is fully initialized
          Future.delayed(Duration(seconds: 2), () {
            _handleMessageNavigation(message);
          });
        }
      });

      if (kDebugMode) {
        print('Message handlers setup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up message handlers: $e');
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    // Skip on unsupported platforms
    if (!isSupported) return;

    try {
      if (kDebugMode) {
        print('Handling foreground message: ${message.notification?.body}');
      }

      // Call registered callback if available
      _onForegroundMessage?.call(message);

      // Update unread notification count if needed
      _updateNotificationBadge();
    } catch (e) {
      if (kDebugMode) {
        print('Error handling foreground message: $e');
      }
    }
  }

  static void _handleMessageNavigation(RemoteMessage message) {
    // Skip on unsupported platforms
    if (!isSupported) return;

    try {
      if (kDebugMode) {
        print('Handling message navigation: ${message.data}');
      }

      // Call registered callback if available
      _onMessageTap?.call(message);

      // Extract navigation data
      final ticketId = message.data['ticket_id'];
      final type = message.data['type'];
      final chatRoomId = message.data['chat_room_id'];

      if (kDebugMode) {
        print(
            'Navigation data - Ticket: $ticketId, Type: $type, ChatRoom: $chatRoomId');
      }

      if (ticketId != null) {
        // Handle navigation based on message type
        switch (type) {
          case 'new_message':
          case 'chat_mention':
            if (chatRoomId != null) {
              _navigateToChat(ticketId, chatRoomId);
            } else {
              _navigateToTicket(ticketId);
            }
            break;
          case 'ticket_created':
          case 'ticket_assigned':
          case 'ticket_status_changed':
          case 'ticket_approved':
          case 'ticket_rejected':
            _navigateToTicket(ticketId);
            break;
          case 'subticket_created':
            _navigateToTicket(ticketId);
            break;
          default:
            _navigateToTicket(ticketId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling message navigation: $e');
      }
    }
  }

  static void _navigateToChat(String ticketId, String chatRoomId) {
    if (kDebugMode) {
      print('Navigate to chat for ticket: $ticketId, room: $chatRoomId');
    }

    // Use the callback if available
    if (_onNavigateToChat != null) {
      _onNavigateToChat!(ticketId, chatRoomId);
      return;
    }

    // Fallback navigation using global navigator
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        // For mobile, navigate to chat screen with specific room
        Navigator.of(context).pushNamed(
          '/chat',
          arguments: {
            'chatRoomId': chatRoomId,
            'ticketId': ticketId,
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error navigating to chat: $e');
        }
      }
    }
  }

  static void _navigateToTicket(String ticketId) {
    if (kDebugMode) {
      print('Navigate to ticket: $ticketId');
    }

    // Use the callback if available
    if (_onNavigateToTicket != null) {
      _onNavigateToTicket!(ticketId);
      return;
    }

    // Fallback navigation using global navigator
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        Navigator.of(context).pushNamed(
          '/tickets',
          arguments: {'ticketId': ticketId},
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error navigating to ticket: $e');
        }
      }
    }
  }

  static void _updateNotificationBadge() {
    // Skip on unsupported platforms
    if (!isSupported) return;

    // Update app badge count if needed
    // This could query the unread notification count and update the badge
    // Implementation depends on platform and requirements
  }

  // Set callbacks for message handling from other parts of the app
  static void setMessageHandlers({
    Function(RemoteMessage)? onForegroundMessage,
    Function(RemoteMessage)? onMessageTap,
  }) {
    if (!isSupported) return;

    _onForegroundMessage = onForegroundMessage;
    _onMessageTap = onMessageTap;
  }

  // Clear FCM data on logout
  static Future<void> clearForLogout() async {
    // Skip on unsupported platforms
    if (!isSupported) {
      if (kDebugMode) {
        print('FCM not available on current platform - nothing to clear');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('Clearing FCM for logout');
      }

      if (_currentToken != null) {
        await FirebaseMessaging.instance.deleteToken();
        // Also clear the token from DB so no stale notifications are sent
        try {
          final user = await AuthService.getCurrentUser();
          if (user != null) {
            await supabase.from('users').update(
              kIsWeb ? {'fcm_token_web': null} : {'fcm_token': null},
            ).eq('id', user.id);
          }
        } catch (_) {}
        if (kDebugMode) {
          print('FCM token deleted');
        }
      }

      _currentToken = null;
      _isSetup = false;
      _onForegroundMessage = null;
      _onMessageTap = null;
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _onNavigateToChat = null;
      _onNavigateToTicket = null;

      if (kDebugMode) {
        print('FCM cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing FCM: $e');
      }
    }
  }

  // Get current token - returns null on unsupported platforms
  static String? get currentToken {
    if (!isSupported) return null;
    return _currentToken;
  }

  // Check if setup - always false on unsupported platforms
  static bool get isSetup {
    if (!isSupported) return false;
    return _isSetup;
  }

  // Method to manually refresh token if needed
  static Future<void> refreshToken() async {
    // Skip on unsupported platforms
    if (!isSupported) {
      if (kDebugMode) {
        print('Token refresh not supported on current platform');
      }
      return;
    }

    try {
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken != null && newToken != _currentToken) {
        _currentToken = newToken;
        if (kDebugMode) {
          print('Token refreshed manually: ${newToken.substring(0, 20)}...');
        }

        // Save to database if user is logged in
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          await _saveTokenForUser(user.id, newToken);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing token manually: $e');
      }
    }
  }

  /// Get and clear pending navigation
  static Map<String, dynamic>? consumePendingNavigation() {
    final data = _pendingNavigation;
    _pendingNavigation = null;
    return data;
  }

  /// Check if there's pending navigation
  static bool hasPendingNavigation() {
    if (_pendingNavigation == null) return false;

    // Check if navigation is stale (older than 10 seconds)
    final timestamp = _pendingNavigation!['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 10000) {
      _pendingNavigation = null;
      return false;
    }

    return true;
  }

  /// Enhanced notification tap handler with chat room details
  static Future<void> handleNotificationTap(RemoteMessage message) async {
    print('📱 FCM: Handling notification tap');
    print('📱 Message data: ${message.data}');

    final type = message.data['type'];
    final ticketId = message.data['ticket_id'];
    final chatRoomId = message.data['chat_room_id'];

    // Store with timestamp for validity check
    _pendingNavigation = {
      'type': type,
      'ticket_id': ticketId,
      'chat_room_id': chatRoomId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'action': type == 'new_message' || type == 'chat_mention'
          ? 'open_chat'
          : 'open_ticket',
    };

    print('📱 Stored pending navigation: $_pendingNavigation');

    // Trigger callbacks
    if ((type == 'new_message' || type == 'chat_mention') &&
        chatRoomId != null) {
      _onNavigateToChat?.call(ticketId, chatRoomId);
    } else if (ticketId != null) {
      _onNavigateToTicket?.call(ticketId);
    }
  }

  /// Get pending navigation and keep it (don't consume)
  static Map<String, dynamic>? getPendingNavigation() {
    if (_pendingNavigation == null) return null;

    // Check if stale (older than 30 seconds)
    final timestamp = _pendingNavigation!['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 30000) {
      print('📱 Pending navigation is stale, clearing');
      _pendingNavigation = null;
      return null;
    }

    return _pendingNavigation;
  }

  static void clearPendingNavigation() {
    print('📱 Clearing pending navigation');
    _pendingNavigation = null;
  }

  // Get notification display data for foreground messages
  static Map<String, dynamic> getNotificationDisplayData(
      RemoteMessage message) {
    return {
      'title': message.notification?.title ?? 'New Notification',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'type': message.data['type'],
      'ticketId': message.data['ticket_id'],
      'chatRoomId': message.data['chat_room_id'],
    };
  }

  // Check if message is chat-related
  static bool isChatMessage(RemoteMessage message) {
    final type = message.data['type'];
    return type == 'new_message' || type == 'chat_mention';
  }

  // Check if message is ticket-related
  static bool isTicketMessage(RemoteMessage message) {
    final type = message.data['type'];
    return [
      'ticket_created',
      'ticket_assigned',
      'ticket_status_changed',
      'ticket_approved',
      'ticket_rejected',
      'subticket_created'
    ].contains(type);
  }
}

// Helper class for navigation data
class NotificationNavigationData {
  final String? ticketId;
  final String? chatRoomId;
  final String type;
  final Map<String, dynamic> additionalData;

  NotificationNavigationData({
    this.ticketId,
    this.chatRoomId,
    required this.type,
    this.additionalData = const {},
  });

  factory NotificationNavigationData.fromMessage(RemoteMessage message) {
    return NotificationNavigationData(
      ticketId: message.data['ticket_id'],
      chatRoomId: message.data['chat_room_id'],
      type: message.data['type'] ?? 'unknown',
      additionalData: Map<String, dynamic>.from(message.data),
    );
  }

  bool get isChatNavigation => type == 'new_message' || type == 'chat_mention';
  bool get isTicketNavigation => [
        'ticket_created',
        'ticket_assigned',
        'ticket_status_changed',
        'ticket_approved',
        'ticket_rejected',
        'subticket_created'
      ].contains(type);
}

// Updated main.dart integration
/*
Add this to your main.dart file:

import 'package:jalasupport/enhanced_fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... other initializations
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add this line
      // ... rest of your app configuration
      
      // Add routes for navigation
      routes: {
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MobileChatScreen(
            currentUser: getCurrentUser(), // Your method to get current user
            initialChatRoomId: args?['chatRoomId'],
            initialTicketId: args?['ticketId'],
          );
        },
        '/tickets': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return TicketsScreen(
            currentUser: getCurrentUser(), // Your method to get current user
            initialTicketId: args?['ticketId'],
          );
        },
      },
    );
  }
}
*/

// Background message handler for terminated app state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');

  // You can perform background processing here
  // Note: UI operations are not allowed in background handlers
}
