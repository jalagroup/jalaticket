import 'dart:typed_data';

Future<List<({String name, Uint8List bytes, String mimeType})>?> pickFilesNative({
  bool imageOnly = false,
  bool allowMultiple = false,
  List<String> allowedExtensions = const [],
}) async => null; // non-web: caller falls back to file_picker package
