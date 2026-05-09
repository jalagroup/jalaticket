import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jalasupport/main.dart';

class FcmDebugDialog extends StatefulWidget {
  const FcmDebugDialog({super.key});

  @override
  State<FcmDebugDialog> createState() => _FcmDebugDialogState();
}

class _FcmDebugDialogState extends State<FcmDebugDialog> {
  final List<String> _logs = [];
  bool _isLoading = false;
  String? _currentToken;
  final _scrollController = ScrollController();

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _getFcmToken() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _log('--- Starting FCM token fetch ---');

    try {
      final messaging = FirebaseMessaging.instance;

      // Check auth user
      final authUser = supabase.auth.currentUser;
      if (authUser == null) {
        _log('❌ No authenticated user found');
        return;
      }
      _log('✅ Auth user: ${authUser.email} (auth_id=${authUser.id})');

      // Request permission
      _log('Requesting notification permission...');
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _log('Permission status: ${settings.authorizationStatus}');

      final isAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAllowed) {
        _log('❌ Notifications NOT allowed — enable in iOS Settings');
        return;
      }

      // ── iOS: APNs token check (extended retry, non-blocking) ──────────────
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        _log('Checking APNs token — retrying up to 15x (30s)...');
        String? apnsToken;
        for (int attempt = 1; attempt <= 15; attempt++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) {
            _log('✅ APNs token (attempt $attempt): ${apnsToken.substring(0, 20)}...');
            break;
          }
          _log('⚠️ Attempt $attempt/15: APNs null — waiting 2s...');
          await Future.delayed(const Duration(seconds: 2));
        }

        if (apnsToken == null) {
          // APNs still null — log diagnostic info but continue anyway.
          // Firebase may still return a token internally on some devices.
          _log('⚠️ APNs token still null after 30s — attempting getToken() anyway...');
          _log('ℹ️ Device: ${defaultTargetPlatform.name}, Web: $kIsWeb');
          _log('ℹ️ If getToken() also fails, check:');
          _log('   • Firebase Console → APNs Auth Key Team ID matches yours');
          _log('   • Try on a different iOS device');
          _log('   • Force-close app, reopen, then retry');
        }
      }

      // ── Try getToken() — set up onTokenRefresh listener as fallback ───────
      _log('Calling getToken() (60s timeout)...');

      // Listen for async token in case iOS delivers it after getToken() returns
      String? refreshedToken;
      final refreshSub = messaging.onTokenRefresh.listen((t) {
        refreshedToken = t;
        _log('🔄 onTokenRefresh fired: ${t.substring(0, 30)}...');
      });

      String? token;
      try {
        final tokenFuture = kIsWeb
            ? messaging.getToken(
                vapidKey:
                    'BJKG1UZoHzn1p4mDzNBVDRG0TTNeMhWFtgDxFbXuUlys__657aG4GZykYU-Sr_OFwV1yeQ_sgSrp9Zs369jKRWQ',
              )
            : messaging.getToken();
        token = await tokenFuture.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            _log('⏱ getToken() timed out after 60s');
            return null;
          },
        );
      } catch (e) {
        _log('❌ getToken() threw: $e');
      }

      // If getToken() returned null, wait a bit longer for onTokenRefresh
      if (token == null && refreshedToken == null) {
        _log('⏳ Waiting 10s for onTokenRefresh fallback...');
        await Future.delayed(const Duration(seconds: 10));
      }
      await refreshSub.cancel();

      final finalToken = token ?? refreshedToken;

      if (finalToken == null) {
        _log('❌ No FCM token received from any method');
        _log('ℹ️ Check: Firebase Console → Cloud Messaging → Apple app');
        _log('ℹ️ Verify APNs Auth Key Team ID = your Apple Team ID');
        _log('ℹ️ Verify APNs Key ID matches your .p8 key file');
        return;
      }

      if (refreshedToken != null && token == null) {
        _log('✅ FCM token via onTokenRefresh: ${finalToken.substring(0, 30)}...');
      } else {
        _log('✅ FCM token via getToken(): ${finalToken.substring(0, 30)}...');
      }
      setState(() => _currentToken = finalToken);

      // Save to Supabase
      _log('Saving token to Supabase...');
      const column = kIsWeb ? 'fcm_token_web' : 'fcm_token';
      final updated = await supabase
          .from('users')
          .update({column: finalToken})
          .eq('auth_id', authUser.id)
          .select('id');

      if (updated.isEmpty) {
        _log('⚠️ Updated 0 rows — check if auth_id matches in users table');
        _log('   auth_id used: ${authUser.id}');
        final rows = await supabase
            .from('users')
            .select('id, auth_id, $column')
            .eq('auth_id', authUser.id);
        if (rows.isEmpty) {
          _log('❌ No user row found with auth_id=${authUser.id}');
        } else {
          _log('ℹ️ User row exists: ${rows.first}');
        }
      } else {
        _log('✅ Token saved — updated ${updated.length} row(s)');
        _log('--- Done ✅ ---');
      }
    } catch (e) {
      _log('❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyLogs() {
    final text = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyToken() {
    if (_currentToken == null) return;
    Clipboard.setData(ClipboardData(text: _currentToken!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FCM token copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'FCM Debug',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Current token display
            if (_currentToken != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_currentToken!.substring(0, 30)}...',
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: _copyToken,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy full token',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Log area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Tap "Get FCM Token" to start',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _logs.length,
                        itemBuilder: (context, i) {
                          final line = _logs[i];
                          Color color = Colors.grey.shade300;
                          if (line.contains('✅')) color = Colors.greenAccent;
                          if (line.contains('❌')) color = Colors.redAccent;
                          if (line.contains('⚠️')) color = Colors.orange;
                          if (line.contains('ℹ️')) color = Colors.lightBlueAccent;
                          if (line.startsWith('[') && line.contains('---')) {
                            color = Colors.yellow;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getFcmToken,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _isLoading ? 'Working...' : 'Get FCM Token',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _logs.isEmpty ? null : _copyLogs,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _logs.isEmpty
                      ? null
                      : () => setState(() => _logs.clear()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showFcmDebugDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const FcmDebugDialog(),
  );
}
