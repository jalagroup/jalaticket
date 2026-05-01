// download_helper_mobile.dart
// SOLUTION 2: Share/Save - Downloads and lets user save via share sheet

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation - Downloads file and opens share sheet
/// User can save to gallery, files, or other apps
Future<bool> downloadFileImplementation(String url, String fileName) async {
  try {
    // 1. Download the file to temporary directory
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('Failed to download file: ${response.statusCode}');
      return false;
    }

    // 2. Save to temporary directory
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    // 3. Share the file (user can save it from share sheet)
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Save image',
    );

    // 4. Clean up after a delay
    Future.delayed(const Duration(seconds: 5), () {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        print('Error cleaning up temp file: $e');
      }
    });

    return result.status == ShareResultStatus.success;
  } catch (e) {
    print('Error downloading/sharing file: $e');
    return false;
  }
}
