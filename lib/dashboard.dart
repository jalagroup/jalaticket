// Updated portions of dashboard.dart - only the FCM initialization parts

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _ticketCounts = {};
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _loadTicketCounts();
  }

  Future<void> _initializeFCM() async {
    // Skip FCM initialization on web
    if (kIsWeb) {
      print(
          'Web platform detected - FCM not supported, skipping initialization');
      return;
    }

    // Prevent multiple initialization
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    try {
      // Request permission only once
      final permission = await FirebaseMessaging.instance.requestPermission();

      if (permission.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _setFcmToken(fcmToken);
        }

        // Listen for token refresh (this happens rarely)
        FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
          await _setFcmToken(fcmToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleForegroundMessage(message);
        });

        // Handle messages when app is in background but not terminated
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleMessageOpened(message);
        });
      } else {
        print('FCM permission denied');
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  Future<void> _setFcmToken(String fcmToken) async {
    // Skip on web
    if (kIsWeb) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('users').update({
          'fcm_token': fcmToken,
        }).eq('id', userId);
        print('FCM token updated successfully');
      }
    } catch (e) {
      print('Error setting FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Skip on web
    if (kIsWeb) return;

    // Handle notification when app is in foreground
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.notification?.body ?? 'New notification'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _navigateToNotification(message),
          ),
        ),
      );
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    // Skip on web
    if (kIsWeb) return;

    // Navigate to appropriate screen when notification is tapped
    _navigateToNotification(message);
  }

  void _navigateToNotification(RemoteMessage message) {
    // Navigate based on notification data
    final ticketId = message.data['ticket_id'];
    if (ticketId != null) {
      // Navigate to ticket details or chat
      // You'll need to implement this navigation logic
      print('Navigate to ticket: $ticketId');
    }
  }

  Future<void> _loadTicketCounts() async {
    try {
      final response = await supabase
          .from('tickets')
          .select('status')
          .neq('status', 'deleted');

      final counts = <String, int>{};
      for (final ticket in response) {
        final status = ticket['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      if (mounted) {
        setState(() => _ticketCounts = counts);
      }
    } catch (e) {
      print('Error loading ticket counts: $e');
    }
  }

  @override
  void dispose() {
    // Clean up any listeners if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Show platform indicator in debug mode
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  kIsWeb ? 'WEB' : 'MOBILE',
                  style: TextStyle(
                    fontSize: 12,
                    color: kIsWeb ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.currentUser.fullName}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Show platform-specific notification status
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Push notifications are not available on web platform',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Ticket Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                      'Pending', _ticketCounts['pending'] ?? 0, Colors.orange),
                  _buildStatCard('In Progress',
                      _ticketCounts['inprogress'] ?? 0, Colors.blue),
                  _buildStatCard('Pre-finished',
                      _ticketCounts['prefinished'] ?? 0, Colors.amber),
                  _buildStatCard(
                      'Closed', _ticketCounts['closed'] ?? 0, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
