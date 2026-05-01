// download_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_mobile.dart';

/// Platform-agnostic download helper
class DownloadHelper {
  /// Downloads a file with the given URL and filename
  /// Returns true if successful, false otherwise
  static Future<bool> downloadFile(String url, String fileName) async {
    return downloadFileImplementation(url, fileName);
  }

  /// Checks if download is supported on current platform
  static bool isDownloadSupported() {
    return kIsWeb; // Currently only web is supported
  }
}
