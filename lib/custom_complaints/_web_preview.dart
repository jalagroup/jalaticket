// Web-only: iframe preview + download via anchor element
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerIframeView(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = web.HTMLIFrameElement();
    iframe.src = url;
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = '0';
    iframe.allowFullscreen = true;
    return iframe;
  });
}

void downloadFileWeb(String url, String fileName) {
  final a = web.HTMLAnchorElement();
  a.href = url;
  a.download = fileName;
  a.target = '_blank';
  a.click();
}

/// Fetches the file via the browser (honours cookies/auth), returns a blob: URL.
/// For PDF: can be loaded directly into an iframe (native browser PDF viewer).
Future<String> createBlobUrl(String fileUrl) async {
  final response =
      await web.window.fetch(fileUrl.toJS).toDart;
  final blob = await response.blob().toDart;
  return web.URL.createObjectURL(blob);
}

void revokeBlobUrl(String blobUrl) {
  web.URL.revokeObjectURL(blobUrl);
}

/// Fetches the file as plain text (for TXT, CSV, RTF).
Future<String> fetchText(String fileUrl) async {
  final response =
      await web.window.fetch(fileUrl.toJS).toDart;
  final jsText = await response.text().toDart;
  return jsText.toDart;
}
