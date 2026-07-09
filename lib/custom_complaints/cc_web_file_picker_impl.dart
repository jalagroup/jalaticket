// Web-only implementation — imported only on dart.library.html platforms.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

Future<List<({String name, Uint8List bytes, String mimeType})>?> pickFilesNative({
  bool imageOnly = false,
  bool allowMultiple = false,
  List<String> allowedExtensions = const [],
}) async {
  final completer = Completer<List<({String name, Uint8List bytes, String mimeType})>?>();

  final input = web.HTMLInputElement();
  input.type = 'file';
  input.multiple = allowMultiple;

  if (imageOnly) {
    input.accept = 'image/*';
  } else if (allowedExtensions.isNotEmpty) {
    input.accept = allowedExtensions.map((e) => '.$e').join(',');
  }

  web.document.body!.append(input);

  void complete(List<({String name, Uint8List bytes, String mimeType})>? value) {
    if (completer.isCompleted) return;
    try { input.remove(); } catch (_) {}
    completer.complete(value);
  }

  // ── User selected files ───────────────────────────────────
  input.addEventListener(
    'change',
    (web.Event _) {
      () async {
        final files = input.files;
        debugPrint('[WEB-PICK] onChange — files: ${files?.length ?? 0}');
        if (files == null || files.length == 0) { complete(null); return; }

        final result = <({String name, Uint8List bytes, String mimeType})>[];
        for (int i = 0; i < files.length; i++) {
          final file = files.item(i);
          if (file == null) continue;
          try {
            final arrayBuffer = await file.arrayBuffer().toDart;
            final bytes = arrayBuffer.toDart.asUint8List();
            debugPrint('[WEB-PICK] read ${file.name} — ${bytes.length} bytes');
            result.add((
              name: file.name,
              bytes: bytes,
              mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
            ));
          } catch (e) {
            debugPrint('[WEB-PICK] failed to read ${file.name}: $e');
          }
        }
        complete(result.isEmpty ? null : result);
      }();
    }.toJS,
  );

  // ── User clicked Cancel (Chrome 113+, Firefox 91+, Safari 16.4+) ──
  input.addEventListener(
    'cancel',
    (web.Event _) {
      debugPrint('[WEB-PICK] cancel event');
      complete(null);
    }.toJS,
  );

  // ── Safety timeout — 5 min fallback for browsers without cancel event ──
  Timer(const Duration(minutes: 5), () {
    if (!completer.isCompleted) {
      debugPrint('[WEB-PICK] safety timeout');
      complete(null);
    }
  });

  input.click();
  return completer.future;
}
