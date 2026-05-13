import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects phone shake and fires [onShake] callback.
/// Uses a 2-shake-in-1.5s window to avoid accidental triggers.
class ShakeService {
  static const double _threshold = 14.0; // m/s² net (gravity removed)
  static const int _minMsBetweenShakes = 400;
  static const int _shakesRequired = 2;
  static const int _resetWindowMs = 1500;

  static StreamSubscription<AccelerometerEvent>? _sub;
  static int _shakeCount = 0;
  static DateTime _windowStart = DateTime.now();
  static DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  static void start(VoidCallback onShake) {
    if (kIsWeb) return;
    _sub?.cancel();
    _shakeCount = 0;
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      // Remove approximate gravity (assume device ~vertical for simplicity)
      final net = sqrt(e.x * e.x + e.y * e.y + e.z * e.z) - 9.8;
      if (net < _threshold) return;

      final now = DateTime.now();
      final msSinceLast = now.difference(_lastShake).inMilliseconds;
      if (msSinceLast < _minMsBetweenShakes) return;

      _lastShake = now;

      // Reset window if too old
      if (now.difference(_windowStart).inMilliseconds > _resetWindowMs) {
        _shakeCount = 0;
        _windowStart = now;
      }

      _shakeCount++;
      if (_shakeCount >= _shakesRequired) {
        _shakeCount = 0;
        onShake();
      }
    });
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<void> showReportDialog(BuildContext context,
      {required VoidCallback onReport}) async {
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                color: Color(0xFFf16936),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.bug_report_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isRtl ? 'هل تريد الإبلاغ عن مشكلة؟' : 'Report a Problem?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                isRtl
                    ? 'يبدو أنك هززت هاتفك. هل تواجه مشكلة وتريد الإبلاغ عنها؟'
                    : 'Looks like you shook your phone. Are you experiencing an issue you\'d like to report?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(_),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(isRtl ? 'لا، شكراً' : 'No, thanks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(_);
                        onReport();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFf16936),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        isRtl ? 'نعم، أبلّغ' : 'Yes, report',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
