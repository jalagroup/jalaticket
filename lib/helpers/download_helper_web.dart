// download_helper_web.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using dart:html
Future<bool> downloadFileImplementation(String url, String fileName) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = fileName;

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    return true;
  } catch (e) {
    print('Error downloading file on web: $e');
    return false;
  }
}
