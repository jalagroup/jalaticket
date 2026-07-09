import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void triggerDownload(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob(
    <JSAny>[bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
