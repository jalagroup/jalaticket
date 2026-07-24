import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import 'email_template_models.dart';

class EmailTemplateEditorPanel extends StatefulWidget {
  final EmailTemplateMode mode;
  final List<EmailTemplateBlock> blocks;
  final TextEditingController htmlController;
  final List<String> mergeFields;
  final ValueChanged<EmailTemplateMode> onModeChanged;
  final VoidCallback onChanged;

  const EmailTemplateEditorPanel({
    super.key,
    required this.mode,
    required this.blocks,
    required this.htmlController,
    required this.mergeFields,
    required this.onModeChanged,
    required this.onChanged,
  });

  @override
  State<EmailTemplateEditorPanel> createState() => _EmailTemplateEditorPanelState();
}

class _EmailTemplateEditorPanelState extends State<EmailTemplateEditorPanel> {
  final Map<String, TextEditingController> _blockCtrls = {};

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void dispose() {
    for (final c in _blockCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(EmailTemplateBlock b) {
    return _blockCtrls.putIfAbsent(b.id, () {
      final c = TextEditingController(text: b.text ?? '');
      c.addListener(() {
        b.text = c.text;
        widget.onChanged();
      });
      return c;
    });
  }

  void _insertToken(TextEditingController ctrl, String field) {
    final insert = '{{$field}}';
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (sel.isValid && !sel.isCollapsed) {
      final newText = text.replaceRange(sel.start, sel.end, insert);
      ctrl.text = newText;
      ctrl.selection = TextSelection.collapsed(offset: sel.start + insert.length);
    } else if (sel.isValid) {
      final pos = sel.baseOffset;
      ctrl.text = text.substring(0, pos) + insert + text.substring(pos);
      ctrl.selection = TextSelection.collapsed(offset: pos + insert.length);
    } else {
      ctrl.text = text + insert;
    }
  }

  Widget _mergeFieldChips(TextEditingController target) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.mergeFields.map((f) => ActionChip(
            label: Text('{{$f}}', style: const TextStyle(fontSize: 11)),
            backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
            labelStyle: const TextStyle(color: AppColors.secondary),
            onPressed: () => setState(() => _insertToken(target, f)),
          )).toList(),
    );
  }

  void _addBlock(EmailBlockType type) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final block = EmailTemplateBlock(id: id, type: type);
    setState(() => widget.blocks.add(block));
    widget.onChanged();
  }

  void _removeBlock(EmailTemplateBlock b) {
    setState(() {
      widget.blocks.remove(b);
      _blockCtrls.remove(b.id)?.dispose();
    });
    widget.onChanged();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = widget.blocks.removeAt(oldIndex);
      widget.blocks.insert(newIndex, item);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<EmailTemplateMode>(
            segments: [
              ButtonSegment(value: EmailTemplateMode.visual, label: Text(_isAr ? 'تصميم مرئي' : 'Visual'), icon: const Icon(Icons.dashboard_customize_outlined, size: 16)),
              ButtonSegment(value: EmailTemplateMode.html, label: Text(_isAr ? 'كود HTML' : 'HTML code'), icon: const Icon(Icons.code, size: 16)),
            ],
            selected: {widget.mode},
            onSelectionChanged: (s) => widget.onModeChanged(s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.mode == EmailTemplateMode.visual ? _visualEditor() : _htmlEditor(),
        ),
      ],
    );
  }

  Widget _visualEditor() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isAr ? 'أضف عنصراً' : 'Add block', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                const SizedBox(height: 8),
                for (final type in EmailBlockType.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton.icon(
                      onPressed: () => _addBlock(type),
                      icon: Icon(_blockIcon(type), size: 15),
                      label: Text(_blockLabel(type), style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(double.infinity, 34),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: widget.blocks.isEmpty
              ? Center(child: Text(_isAr ? 'أضف عناصر من القائمة' : 'Add blocks from the palette', style: TextStyle(color: Colors.grey[500])))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                  itemCount: widget.blocks.length,
                  onReorder: _reorder,
                  itemBuilder: (context, i) => _blockCard(widget.blocks[i], key: ValueKey(widget.blocks[i].id)),
                ),
        ),
      ],
    );
  }

  IconData _blockIcon(EmailBlockType type) {
    switch (type) {
      case EmailBlockType.logo: return Icons.image_outlined;
      case EmailBlockType.heading: return Icons.title;
      case EmailBlockType.text: return Icons.notes;
      case EmailBlockType.button: return Icons.smart_button_outlined;
      case EmailBlockType.divider: return Icons.horizontal_rule;
      case EmailBlockType.spacer: return Icons.space_bar;
      case EmailBlockType.footer: return Icons.text_fields;
    }
  }

  String _blockLabel(EmailBlockType type) {
    if (!_isAr) {
      switch (type) {
        case EmailBlockType.logo: return 'Logo';
        case EmailBlockType.heading: return 'Heading';
        case EmailBlockType.text: return 'Text';
        case EmailBlockType.button: return 'Button';
        case EmailBlockType.divider: return 'Divider';
        case EmailBlockType.spacer: return 'Spacer';
        case EmailBlockType.footer: return 'Footer';
      }
    }
    switch (type) {
      case EmailBlockType.logo: return 'شعار';
      case EmailBlockType.heading: return 'عنوان';
      case EmailBlockType.text: return 'نص';
      case EmailBlockType.button: return 'زر';
      case EmailBlockType.divider: return 'خط فاصل';
      case EmailBlockType.spacer: return 'مسافة';
      case EmailBlockType.footer: return 'تذييل';
    }
  }

  Widget _blockCard(EmailTemplateBlock b, {required Key key}) {
    final needsText = b.type == EmailBlockType.heading || b.type == EmailBlockType.text || b.type == EmailBlockType.button || b.type == EmailBlockType.footer;
    final ctrl = _ctrlFor(b);
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_blockIcon(b.type), size: 15, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(_blockLabel(b.type), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17, color: Colors.grey),
                  onPressed: () => _removeBlock(b),
                  visualDensity: VisualDensity.compact,
                ),
                const Icon(Icons.drag_handle, size: 17, color: Colors.grey),
              ],
            ),
            if (needsText) ...[
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                maxLines: b.type == EmailBlockType.text ? 3 : 1,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  hintText: b.type == EmailBlockType.button ? (_isAr ? 'نص الزر' : 'Button label') : (_isAr ? 'النص' : 'Text'),
                ),
              ),
              const SizedBox(height: 6),
              _mergeFieldChips(ctrl),
            ],
            if (b.type == EmailBlockType.button) ...[
              const SizedBox(height: 6),
              TextField(
                onChanged: (v) {
                  b.buttonUrl = v;
                  widget.onChanged();
                },
                controller: TextEditingController(text: b.buttonUrl ?? ''),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  hintText: _isAr ? 'رابط الزر (اختياري)' : 'Button URL (optional)',
                ),
              ),
            ],
            if (b.type == EmailBlockType.logo) ...[
              const SizedBox(height: 6),
              TextField(
                onChanged: (v) {
                  b.imageUrl = v;
                  widget.onChanged();
                },
                controller: TextEditingController(text: b.imageUrl ?? ''),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  hintText: _isAr ? 'رابط الصورة' : 'Image URL',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _htmlEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mergeFieldChips(widget.htmlController),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: widget.htmlController,
              onChanged: (_) => widget.onChanged(),
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: '<div>{{title}}</div>\n<p>{{message}}</p>',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
