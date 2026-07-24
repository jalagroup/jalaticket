import 'package:flutter/material.dart';
import 'email_template_iframe.dart';
import 'email_template_models.dart';

class EmailTemplatePreview extends StatelessWidget {
  final EmailTemplateMode mode;
  final List<EmailTemplateBlock> blocks;
  final String htmlSource;

  const EmailTemplatePreview({
    super.key,
    required this.mode,
    required this.blocks,
    required this.htmlSource,
  });

  Color _hexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return value != null ? Color(value) : fallback;
  }

  TextAlign _align(String? a) {
    switch (a) {
      case 'center': return TextAlign.center;
      case 'left': return TextAlign.left;
      default: return TextAlign.right;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Email content is always Arabic/RTL for this app's audience, regardless
    // of the current admin UI's own locale — force RTL for the preview so it
    // matches what recipients will actually see.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF2F4F5),
        child: mode == EmailTemplateMode.html
            ? buildHtmlIframePreview(htmlSource)
            : _visualPreview(),
      ),
    );
  }

  Widget _visualPreview() {
    if (blocks.isEmpty) {
      return Center(
        child: Text('No blocks yet', style: TextStyle(color: Colors.grey[500])),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks.map(_renderBlock).toList(),
          ),
        ),
      ),
    );
  }

  Widget _renderBlock(EmailTemplateBlock b) {
    switch (b.type) {
      case EmailBlockType.logo:
        if (b.imageUrl == null || b.imageUrl!.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Image.network(
              b.imageUrl!,
              height: 48,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      case EmailBlockType.heading:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            b.text ?? '',
            textAlign: _align(b.textAlign),
            style: TextStyle(
              fontSize: b.fontSize,
              fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
              color: _hexColor(b.textColor, const Color(0xFF1A1A1A)),
            ),
          ),
        );
      case EmailBlockType.text:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            b.text ?? '',
            textAlign: _align(b.textAlign),
            style: TextStyle(
              fontSize: b.fontSize,
              fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
              color: _hexColor(b.textColor, const Color(0xFF1A1A1A)),
            ),
          ),
        );
      case EmailBlockType.button:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Align(
            alignment: b.textAlign == 'left'
                ? Alignment.centerLeft
                : b.textAlign == 'right'
                    ? Alignment.centerRight
                    : Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF16936),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                b.text ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        );
      case EmailBlockType.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 20, thickness: 1, color: Color(0xFFE5E5E5)),
        );
      case EmailBlockType.spacer:
        return SizedBox(height: b.spacerHeight);
      case EmailBlockType.footer:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            b.text ?? '',
            textAlign: _align(b.textAlign),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
    }
  }
}
