import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildHtmlIframePreview(String html) => _HtmlIframePreview(html: html);

class _HtmlIframePreview extends StatefulWidget {
  final String html;
  const _HtmlIframePreview({required this.html});

  @override
  State<_HtmlIframePreview> createState() => _HtmlIframePreviewState();
}

class _HtmlIframePreviewState extends State<_HtmlIframePreview> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _viewType = 'email-template-iframe-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..setAttribute('style', 'width:100%;height:100%;border:none;display:block;background:#ffffff;')
        ..srcdoc = widget.html.toJS;
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(covariant _HtmlIframePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _iframe?.srcdoc = widget.html.toJS;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
