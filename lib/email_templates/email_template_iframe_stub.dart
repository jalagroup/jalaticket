import 'package:flutter/material.dart';

Widget buildHtmlIframePreview(String html) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Live HTML preview is available in the web app.\nUse "Send test email" to verify it here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
    ),
  );
}
