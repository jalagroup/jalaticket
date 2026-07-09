import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:uuid/uuid.dart';
import '../main.dart' show AppColors;
import 'cc_models.dart';
import 'cc_service.dart';

const _uuid = Uuid();

const Map<String, IconData> ccIconCatalog = {
  'info': Icons.info_outline_rounded,
  'warning': Icons.warning_amber_rounded,
  'check': Icons.check_circle_outline_rounded,
  'error': Icons.error_outline_rounded,
  'star': Icons.star_outline_rounded,
  'heart': Icons.favorite_outline_rounded,
  'celebration': Icons.celebration_outlined,
  'thumb_up': Icons.thumb_up_outlined,
  'thumb_down': Icons.thumb_down_outlined,
  'shield': Icons.shield_outlined,
  'lock': Icons.lock_outline_rounded,
  'email': Icons.email_outlined,
  'phone': Icons.phone_outlined,
  'person': Icons.person_outline_rounded,
  'people': Icons.people_outline_rounded,
  'location': Icons.location_on_outlined,
  'calendar': Icons.calendar_today_rounded,
  'clock': Icons.access_time_rounded,
  'home': Icons.home_outlined,
  'settings': Icons.settings_outlined,
  'search': Icons.search_rounded,
  'edit': Icons.edit_outlined,
  'delete': Icons.delete_outline_rounded,
  'add': Icons.add_circle_outline_rounded,
  'close': Icons.close_rounded,
  'done': Icons.done_rounded,
  'arrow_forward': Icons.arrow_forward_rounded,
  'arrow_back': Icons.arrow_back_rounded,
  'upload': Icons.upload_outlined,
  'download': Icons.download_outlined,
  'share': Icons.share_outlined,
  'bookmark': Icons.bookmark_outline_rounded,
  'flag': Icons.flag_outlined,
  'build': Icons.build_outlined,
  'lightbulb': Icons.lightbulb_outline_rounded,
  'chat': Icons.chat_bubble_outline_rounded,
  'notification': Icons.notifications_outlined,
  'badge': Icons.badge_outlined,
  'fingerprint': Icons.fingerprint_rounded,
  'verified': Icons.verified_outlined,
  'help': Icons.help_outline_rounded,
  'support': Icons.support_agent_rounded,
  'trending_up': Icons.trending_up_rounded,
  'bar_chart': Icons.bar_chart_rounded,
  'attach': Icons.attach_file_rounded,
  'image': Icons.image_outlined,
  'document': Icons.description_outlined,
  'folder': Icons.folder_outlined,
  'cloud': Icons.cloud_outlined,
  'wifi': Icons.wifi_rounded,
  'security': Icons.security_rounded,
  'access_time': Icons.access_time_filled_rounded,
  'face': Icons.face_rounded,
  'grade': Icons.grade_outlined,
};

enum _PreviewDevice { mobile, tablet, desktop }

enum CcScreenType { welcome, closing }

const double _canvasMinHeight = 620;

class CcScreenDesigner extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialConfig;
  final String formId;
  final CcScreenType screenType;

  const CcScreenDesigner({
    super.key,
    required this.title,
    required this.initialConfig,
    required this.formId,
    this.screenType = CcScreenType.welcome,
  });

  @override
  State<CcScreenDesigner> createState() => _CcScreenDesignerState();
}

class _CcScreenDesignerState extends State<CcScreenDesigner> {
  late CcScreenConfig _config;
  int? _selectedIndex;
  _PreviewDevice _device = _PreviewDevice.desktop;
  bool _isDirty = false;
  int _leftTab = 0;
  CcCanvasItem? _clipboard;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.initialConfig != null) {
      _config = CcScreenConfig.fromJson(widget.initialConfig!);
    } else {
      _config = CcScreenConfig(backgroundColor: '#FFFFFF', items: []);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyDefaultTemplate();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _applyDefaultTemplate() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isClosing = widget.screenType == CcScreenType.closing;
    final items = isClosing
        ? _TemplateLibrary.successEnhanced(isAr)
        : _TemplateLibrary.classicWelcome(isAr);
    final bg = isClosing ? '#FFFFFF' : '#FFFFFF';
    setState(() {
      _config.items..clear()..addAll(items);
      _config.backgroundColor = bg;
      _selectedIndex = null;
      _isDirty = false;
    });
  }

  Future<void> _handleBack() async {
    if (!_isDirty) { Navigator.pop(context); return; }
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isAr ? 'تجاهل التغييرات؟' : 'Discard changes?'),
        content: Text(isAr
            ? 'لديك تغييرات غير محفوظة. هل تريد المغادرة دون حفظ؟'
            : 'You have unsaved changes. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isAr ? 'تجاهل' : 'Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  void _duplicateItem(int idx) {
    final src = _config.items[idx];
    final dup = CcCanvasItem(
      id: _uuid.v4(),
      type: src.type,
      text: src.text,
      iconName: src.iconName,
      imageUrl: src.imageUrl,
      fontSize: src.fontSize,
      bold: src.bold,
      italic: src.italic,
      textAlign: src.textAlign,
      textColor: src.textColor,
      spacerHeight: src.spacerHeight,
      x: (src.x + 14).clamp(0, _designWidth - 40),
      y: (src.y + 14),
      width: src.width,
      height: src.height,
      opacity: src.opacity,
      bgFill: src.bgFill,
      itemBorderRadius: src.itemBorderRadius,
      borderWidth: src.borderWidth,
      borderColor: src.borderColor,
      letterSpacing: src.letterSpacing,
    );
    setState(() {
      _config.items.add(dup);
      _selectedIndex = _config.items.length - 1;
      _isDirty = true;
    });
  }

  void _deleteItem(int idx) {
    setState(() {
      _config.items.removeAt(idx);
      _selectedIndex = null;
      _isDirty = true;
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (_selectedIndex != null && key == LogicalKeyboardKey.delete) {
      _deleteItem(_selectedIndex!);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyC && _selectedIndex != null) {
      final src = _config.items[_selectedIndex!];
      _clipboard = CcCanvasItem(
        id: _uuid.v4(), type: src.type, text: src.text, iconName: src.iconName,
        imageUrl: src.imageUrl, fontSize: src.fontSize, bold: src.bold,
        italic: src.italic, textAlign: src.textAlign, textColor: src.textColor,
        spacerHeight: src.spacerHeight, x: src.x, y: src.y,
        width: src.width, height: src.height,
        opacity: src.opacity, bgFill: src.bgFill,
        itemBorderRadius: src.itemBorderRadius, borderWidth: src.borderWidth,
        borderColor: src.borderColor, letterSpacing: src.letterSpacing,
      );
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyX && _selectedIndex != null) {
      final src = _config.items[_selectedIndex!];
      setState(() {
        _clipboard = CcCanvasItem(
          id: _uuid.v4(), type: src.type, text: src.text, iconName: src.iconName,
          imageUrl: src.imageUrl, fontSize: src.fontSize, bold: src.bold,
          italic: src.italic, textAlign: src.textAlign, textColor: src.textColor,
          spacerHeight: src.spacerHeight, x: src.x, y: src.y,
          width: src.width, height: src.height,
          opacity: src.opacity, bgFill: src.bgFill,
          itemBorderRadius: src.itemBorderRadius, borderWidth: src.borderWidth,
          borderColor: src.borderColor, letterSpacing: src.letterSpacing,
        );
        _config.items.removeAt(_selectedIndex!);
        _selectedIndex = null;
        _isDirty = true;
      });
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyV && _clipboard != null) {
      final c = _clipboard!;
      final pasted = CcCanvasItem(
        id: _uuid.v4(), type: c.type, text: c.text, iconName: c.iconName,
        imageUrl: c.imageUrl, fontSize: c.fontSize, bold: c.bold,
        italic: c.italic, textAlign: c.textAlign, textColor: c.textColor,
        spacerHeight: c.spacerHeight, x: c.x + 14, y: c.y + 14,
        width: c.width, height: c.height,
        opacity: c.opacity, bgFill: c.bgFill,
        itemBorderRadius: c.itemBorderRadius, borderWidth: c.borderWidth,
        borderColor: c.borderColor, letterSpacing: c.letterSpacing,
      );
      setState(() {
        _config.items.add(pasted);
        _selectedIndex = _config.items.length - 1;
        _isDirty = true;
      });
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyD && _selectedIndex != null) {
      _duplicateItem(_selectedIndex!);
      return KeyEventResult.handled;
    }
    if (_selectedIndex != null) {
      final step = shift ? 10.0 : 1.0;
      double dx = 0, dy = 0;
      if (key == LogicalKeyboardKey.arrowLeft) dx = -step;
      else if (key == LogicalKeyboardKey.arrowRight) dx = step;
      else if (key == LogicalKeyboardKey.arrowUp) dy = -step;
      else if (key == LogicalKeyboardKey.arrowDown) dy = step;
      if (dx != 0 || dy != 0) {
        setState(() {
          final item = _config.items[_selectedIndex!];
          item.x = (item.x + dx).clamp(0.0, _designWidth - 40.0);
          item.y = (item.y + dy).clamp(0.0, _canvasHeight / _deviceScale - 20.0);
          _isDirty = true;
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  double get _previewWidth {
    switch (_device) {
      case _PreviewDevice.mobile:
        return 380;
      case _PreviewDevice.tablet:
        return 560;
      case _PreviewDevice.desktop:
        return 760;
    }
  }

  double get _canvasHeight {
    if (_config.items.isEmpty) return _canvasMinHeight;
    final maxBottom = _config.items
        .map((i) => i.y + i.height)
        .fold(0.0, (a, b) => a > b ? a : b);
    return (maxBottom + 80).clamp(_canvasMinHeight, 3000);
  }

  static const double _designWidth = 760.0;

  double get _deviceScale => _previewWidth / _designWidth;

  CcCanvasItem _buildDefaultItem(CcCanvasItemType type, {double? x, double? y}) {
    double defaultW, defaultH;
    switch (type) {
      case CcCanvasItemType.heading:
        defaultW = 400; defaultH = 48; break;
      case CcCanvasItemType.body:
        defaultW = 440; defaultH = 64; break;
      case CcCanvasItemType.icon:
        defaultW = 72; defaultH = 72; break;
      case CcCanvasItemType.image:
        defaultW = _designWidth - 80; defaultH = 140; break;
      case CcCanvasItemType.spacer:
        defaultW = _designWidth - 80; defaultH = 24; break;
      case CcCanvasItemType.bullets:
        defaultW = 420; defaultH = 100; break;
      case CcCanvasItemType.divider:
        defaultW = _designWidth - 80; defaultH = 20; break;
      case CcCanvasItemType.button:
        defaultW = 200; defaultH = 50; break;
      case CcCanvasItemType.numberedList:
        defaultW = 420; defaultH = 100; break;
    }
    final defaultY = 20.0 + _config.items.length * 90.0;
    return CcCanvasItem(
      id: _uuid.v4(),
      type: type,
      text: type == CcCanvasItemType.heading
          ? 'Heading'
          : type == CcCanvasItemType.body
              ? 'Body text goes here'
              : type == CcCanvasItemType.bullets || type == CcCanvasItemType.numberedList
                  ? 'First point\nSecond point\nThird point'
                  : type == CcCanvasItemType.button
                      ? 'Button'
                      : null,
      iconName: type == CcCanvasItemType.icon ? 'info' : null,
      x: x ?? (type == CcCanvasItemType.icon ? (_designWidth / 2 - 36) : 20),
      y: y ?? defaultY.clamp(0, 1200),
      width: defaultW,
      height: defaultH,
    );
  }

  void _addItem(CcCanvasItemType type) {
    setState(() {
      _config.items.add(_buildDefaultItem(type));
      _selectedIndex = _config.items.length - 1;
      _isDirty = true;
    });
  }

  void _toggleLock(int idx) {
    setState(() {
      _config.items[idx].locked = !_config.items[idx].locked;
      _isDirty = true;
    });
  }

  void _toggleVisible(int idx) {
    setState(() {
      _config.items[idx].visible = !_config.items[idx].visible;
      _isDirty = true;
    });
  }

  void _applyTemplate(List<CcCanvasItem> items, String bgColor) {
    setState(() {
      _config.items
        ..clear()
        ..addAll(items);
      _config.backgroundColor = bgColor;
      _selectedIndex = null;
      _isDirty = true;
    });
  }

  Future<void> _showTemplates(bool isAr) async {
    final result = await showDialog<_TemplateData>(
      context: context,
      builder: (_) => _TemplateDialog(isAr: isAr),
    );
    if (result != null) _applyTemplate(result.items, result.bgColor);
  }

  Future<void> _pickImage(int index) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final url = await CcService.uploadScreenImage(widget.formId, bytes, file.name);
    if (url != null) {
      setState(() => _config.items[index].imageUrl = url);
    }
  }

  Future<void> _pickBgImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final url = await CcService.uploadScreenImage(widget.formId, bytes, 'bg_${file.name}');
    if (url != null) {
      setState(() => _config.backgroundImageUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: isAr ? 'رجوع' : 'Back',
            onPressed: _handleBack,
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isDirty = false);
                Navigator.pop(context, _config.toJson());
              },
              child: Text(
                isAr ? 'حفظ' : 'Save',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            _LeftPanel(
              leftTab: _leftTab,
              onTabChanged: (t) => setState(() => _leftTab = t),
              onAdd: _addItem,
              config: _config,
              selectedIndex: _selectedIndex,
              onSelect: (i) => setState(() => _selectedIndex = i),
              onToggleLock: _toggleLock,
              onToggleVisible: _toggleVisible,
              onDelete: _deleteItem,
              isAr: isAr,
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF3F4F6),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DeviceSwitcher(
                            device: _device,
                            onChanged: (d) => setState(() => _device = d),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showTemplates(isAr),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                            label: Text(isAr ? 'قوالب' : 'Templates',
                                style: const TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                          if (_selectedIndex != null) ...[
                            const SizedBox(width: 8),
                            _KeyboardHintChip(isAr: isAr),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Container(
                            width: _previewWidth,
                            height: _canvasHeight,
                            decoration: BoxDecoration(
                              color: _hexToColor(_config.backgroundColor),
                              image: (_config.backgroundImageUrl ?? '').isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_config.backgroundImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: DragTarget<CcCanvasItemType>(
                                onWillAcceptWithDetails: (_) => true,
                                onAcceptWithDetails: (details) {
                                  final box = context.findRenderObject() as RenderBox?;
                                  if (box == null) { _addItem(details.data); return; }
                                  final canvasTopLeft = box.localToGlobal(Offset.zero);
                                  final local = details.offset - canvasTopLeft;
                                  final scale = _deviceScale;
                                  final dropX = (local.dx / scale).clamp(0.0, _designWidth - 40.0);
                                  final dropY = (local.dy / scale).clamp(0.0, _canvasHeight / scale - 20.0);
                                  setState(() {
                                    _config.items.add(_buildDefaultItem(details.data, x: dropX, y: dropY));
                                    _selectedIndex = _config.items.length - 1;
                                    _isDirty = true;
                                  });
                                },
                                builder: (ctx, candidates, _) {
                                  final isDragOver = candidates.isNotEmpty;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => setState(() => _selectedIndex = null),
                                    child: Container(
                                      decoration: isDragOver
                                          ? BoxDecoration(
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                                              borderRadius: BorderRadius.circular(14),
                                            )
                                          : null,
                                      child: Stack(
                                        children: [
                                          if (_config.items.isEmpty)
                                            Center(
                                              child: Text(
                                                isAr
                                                    ? 'أضف عناصر من اللوحة الجانبية'
                                                    : 'Add items from the side panel',
                                                style: TextStyle(color: Colors.grey[400]),
                                              ),
                                            ),
                                          ..._config.items.asMap().entries.map((e) {
                                            final idx = e.key;
                                            final item = e.value;
                                            final isSelected = _selectedIndex == idx;
                                            final scale = _deviceScale;
                                            return _CanvasItemView(
                                              key: ValueKey(item.id),
                                              item: item,
                                              selected: isSelected,
                                              scale: scale,
                                              canvasWidth: _previewWidth,
                                              canvasHeight: _canvasHeight,
                                              onTap: () {
                                                setState(() => _selectedIndex = idx);
                                                _focusNode.requestFocus();
                                              },
                                              onPickImage: () => _pickImage(idx),
                                              onMoved: (dx, dy) => setState(() {
                                                item.x = (item.x + dx / scale).clamp(0, _designWidth - 40);
                                                item.y = (item.y + dy / scale).clamp(0, _canvasHeight / scale - 20);
                                                _isDirty = true;
                                              }),
                                              onResized: (handle, dx, dy) => setState(() {
                                                _applyResize(item, handle, dx / scale, dy / scale);
                                                _isDirty = true;
                                              }),
                                              onDuplicate: () => _duplicateItem(idx),
                                              onDelete: () => _deleteItem(idx),
                                              onTextChanged: () => setState(() { _isDirty = true; }),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _PropertiesPanel(
              config: _config,
              selectedIndex: _selectedIndex,
              isAr: isAr,
              onChanged: () => setState(() { _isDirty = true; }),
              onDelete: () => setState(() {
                if (_selectedIndex != null) {
                  _config.items.removeAt(_selectedIndex!);
                  _selectedIndex = null;
                  _isDirty = true;
                }
              }),
              onPickImage: _selectedIndex != null ? () => _pickImage(_selectedIndex!) : null,
              onPickBgImage: _pickBgImage,
            ),
          ],
        ),
      ),
    );
  }

  void _applyResize(CcCanvasItem item, _ResizeHandle handle, double dx, double dy) {
    const minW = 40.0;
    const minH = 20.0;
    switch (handle) {
      case _ResizeHandle.nw:
        final newX = (item.x + dx).clamp(0.0, item.x + item.width - minW);
        final newY = (item.y + dy).clamp(0.0, item.y + item.height - minH);
        item.width += item.x - newX;
        item.height += item.y - newY;
        item.x = newX;
        item.y = newY;
        break;
      case _ResizeHandle.n:
        final newY = (item.y + dy).clamp(0.0, item.y + item.height - minH);
        item.height += item.y - newY;
        item.y = newY;
        break;
      case _ResizeHandle.ne:
        final newY = (item.y + dy).clamp(0.0, item.y + item.height - minH);
        item.height += item.y - newY;
        item.y = newY;
        item.width = (item.width + dx).clamp(minW, _previewWidth - item.x);
        break;
      case _ResizeHandle.e:
        item.width = (item.width + dx).clamp(minW, _previewWidth - item.x);
        break;
      case _ResizeHandle.se:
        item.width = (item.width + dx).clamp(minW, _previewWidth - item.x);
        item.height = (item.height + dy).clamp(minH, double.infinity);
        break;
      case _ResizeHandle.s:
        item.height = (item.height + dy).clamp(minH, double.infinity);
        break;
      case _ResizeHandle.sw:
        final newX = (item.x + dx).clamp(0.0, item.x + item.width - minW);
        item.width += item.x - newX;
        item.x = newX;
        item.height = (item.height + dy).clamp(minH, double.infinity);
        break;
      case _ResizeHandle.w:
        final newX = (item.x + dx).clamp(0.0, item.x + item.width - minW);
        item.width += item.x - newX;
        item.x = newX;
        break;
    }
  }
}

// ── Resize handle enum ────────────────────────────────────────

enum _ResizeHandle { nw, n, ne, e, se, s, sw, w }

// ── Helpers ───────────────────────────────────────────────────

TextAlign _textAlignFromString(String value) {
  switch (value) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.center;
  }
}

String _textAlignToString(TextAlign align) {
  switch (align) {
    case TextAlign.left:
      return 'left';
    case TextAlign.right:
      return 'right';
    default:
      return 'center';
  }
}

Color _hexToColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}


// ── Device switcher ───────────────────────────────────────────

class _DeviceSwitcher extends StatelessWidget {
  final _PreviewDevice device;
  final ValueChanged<_PreviewDevice> onChanged;
  const _DeviceSwitcher({required this.device, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.smartphone_rounded, _PreviewDevice.mobile),
          _btn(Icons.tablet_mac_rounded, _PreviewDevice.tablet),
          _btn(Icons.desktop_windows_rounded, _PreviewDevice.desktop),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, _PreviewDevice d) {
    final selected = d == device;
    return InkWell(
      onTap: () => onChanged(d),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey[600]),
      ),
    );
  }
}

// ── Keyboard hint chip ────────────────────────────────────────

class _KeyboardHintChip extends StatelessWidget {
  final bool isAr;
  const _KeyboardHintChip({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.keyboard_rounded, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            isAr ? 'Del حذف | ←↑↓→ تحريك | Ctrl+D نسخ' : 'Del delete | ←↑↓→ move | Ctrl+D dup',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ── Left panel (tabs: Elements + Layers) ──────────────────────

class _LeftPanel extends StatelessWidget {
  final int leftTab;
  final ValueChanged<int> onTabChanged;
  final void Function(CcCanvasItemType) onAdd;
  final CcScreenConfig config;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int) onToggleLock;
  final void Function(int) onToggleVisible;
  final void Function(int) onDelete;
  final bool isAr;

  const _LeftPanel({
    required this.leftTab,
    required this.onTabChanged,
    required this.onAdd,
    required this.config,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggleLock,
    required this.onToggleVisible,
    required this.onDelete,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                _tab(context, 0, isAr ? 'العناصر' : 'Elements'),
                _tab(context, 1, isAr ? 'الطبقات' : 'Layers'),
              ],
            ),
          ),
          Expanded(
            child: leftTab == 0
                ? _PalettePanel(onAdd: onAdd, isAr: isAr)
                : _LayersPanel(
                    config: config,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    onToggleLock: onToggleLock,
                    onToggleVisible: onToggleVisible,
                    onDelete: onDelete,
                    isAr: isAr,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label) {
    final selected = leftTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Layers panel ──────────────────────────────────────────────

class _LayersPanel extends StatelessWidget {
  final CcScreenConfig config;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int) onToggleLock;
  final void Function(int) onToggleVisible;
  final void Function(int) onDelete;
  final bool isAr;

  const _LayersPanel({
    required this.config,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggleLock,
    required this.onToggleVisible,
    required this.onDelete,
    required this.isAr,
  });

  static (IconData, Color) _typeIcon(CcCanvasItemType t) {
    switch (t) {
      case CcCanvasItemType.heading:
        return (Icons.title_rounded, Colors.purple);
      case CcCanvasItemType.body:
        return (Icons.notes_rounded, Colors.blue);
      case CcCanvasItemType.icon:
        return (Icons.emoji_emotions_outlined, Colors.orange);
      case CcCanvasItemType.image:
        return (Icons.image_outlined, Colors.teal);
      case CcCanvasItemType.spacer:
        return (Icons.height_rounded, Colors.grey);
      case CcCanvasItemType.bullets:
        return (Icons.format_list_bulleted_rounded, Colors.green);
      case CcCanvasItemType.divider:
        return (Icons.horizontal_rule_rounded, Colors.blueGrey);
      case CcCanvasItemType.button:
        return (Icons.smart_button_rounded, Colors.red);
      case CcCanvasItemType.numberedList:
        return (Icons.format_list_numbered_rounded, Colors.indigo);
    }
  }

  String _itemLabel(CcCanvasItem item, bool isAr) {
    switch (item.type) {
      case CcCanvasItemType.heading:
        return item.text?.isNotEmpty == true
            ? item.text!.length > 16 ? '${item.text!.substring(0, 16)}…' : item.text!
            : (isAr ? 'عنوان' : 'Heading');
      case CcCanvasItemType.body:
        return item.text?.isNotEmpty == true
            ? item.text!.length > 16 ? '${item.text!.substring(0, 16)}…' : item.text!
            : (isAr ? 'نص' : 'Body');
      case CcCanvasItemType.icon:
        return item.iconName ?? (isAr ? 'أيقونة' : 'Icon');
      case CcCanvasItemType.image:
        return isAr ? 'صورة' : 'Image';
      case CcCanvasItemType.spacer:
        return isAr ? 'تباعد' : 'Spacer';
      case CcCanvasItemType.bullets:
        return isAr ? 'نقاط' : 'Bullets';
      case CcCanvasItemType.divider:
        return isAr ? 'فاصل' : 'Divider';
      case CcCanvasItemType.button:
        return item.text?.isNotEmpty == true ? item.text! : (isAr ? 'زر' : 'Button');
      case CcCanvasItemType.numberedList:
        return isAr ? 'قائمة مرقمة' : 'Numbered list';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = config.items;
    if (items.isEmpty) {
      return Center(
        child: Text(
          isAr ? 'لا توجد طبقات' : 'No layers',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      );
    }
    // Show in reverse z-order (top layer first)
    final reversedIndices = List.generate(items.length, (i) => items.length - 1 - i);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: reversedIndices.length,
      itemBuilder: (ctx, listIdx) {
        final idx = reversedIndices[listIdx];
        final item = items[idx];
        final isSelected = selectedIndex == idx;
        final (typeIcon, typeColor) = _typeIcon(item.type);
        return GestureDetector(
          onTap: () => onSelect(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Icon(typeIcon, size: 14, color: typeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _itemLabel(item, isAr),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggleVisible(idx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      item.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 14,
                      color: item.visible ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggleLock(idx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      item.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 14,
                      color: item.locked ? Colors.orange : Colors.grey[400],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onDelete(idx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[300]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Palette panel ─────────────────────────────────────────────

class _PalettePanel extends StatelessWidget {
  final void Function(CcCanvasItemType) onAdd;
  final bool isAr;
  const _PalettePanel({required this.onAdd, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final items = [
      (CcCanvasItemType.heading, Icons.title_rounded, isAr ? 'عنوان' : 'Heading'),
      (CcCanvasItemType.body, Icons.notes_rounded, isAr ? 'نص' : 'Body text'),
      (CcCanvasItemType.icon, Icons.emoji_emotions_outlined, isAr ? 'أيقونة' : 'Icon'),
      (CcCanvasItemType.image, Icons.image_outlined, isAr ? 'صورة' : 'Image'),
      (CcCanvasItemType.spacer, Icons.height_rounded, isAr ? 'تباعد' : 'Spacer'),
      (CcCanvasItemType.bullets, Icons.format_list_bulleted_rounded, isAr ? 'نقاط' : 'Bullets'),
      (CcCanvasItemType.divider, Icons.horizontal_rule_rounded, isAr ? 'فاصل' : 'Divider'),
      (CcCanvasItemType.button, Icons.smart_button_rounded, isAr ? 'زر' : 'Button'),
      (CcCanvasItemType.numberedList, Icons.format_list_numbered_rounded, isAr ? 'قائمة مرقمة' : 'Numbered list'),
    ];
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            isAr ? 'العناصر' : 'Elements',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          isAr ? 'اضغط أو اسحب للإضافة' : 'Tap or drag to add',
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
        const SizedBox(height: 8),
        ...items.map((it) => _DraggablePaletteItem(
              type: it.$1,
              icon: it.$2,
              label: it.$3,
              onAdd: onAdd,
            )),
      ],
    );
  }
}

class _DraggablePaletteItem extends StatelessWidget {
  final CcCanvasItemType type;
  final IconData icon;
  final String label;
  final void Function(CcCanvasItemType) onAdd;

  const _DraggablePaletteItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: const Color(0xFFF7F7F9),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        onTap: () => onAdd(type),
      ),
    );

    return Draggable<CcCanvasItemType>(
      data: type,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}

// ── Canvas item view (free-form positioned) ───────────────────

class _CanvasItemView extends StatefulWidget {
  final CcCanvasItem item;
  final bool selected;
  final double scale;
  final double canvasWidth;
  final double canvasHeight;
  final VoidCallback onTap;
  final VoidCallback onPickImage;
  final void Function(double dx, double dy) onMoved;
  final void Function(_ResizeHandle handle, double dx, double dy) onResized;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onTextChanged;

  const _CanvasItemView({
    super.key,
    required this.item,
    required this.selected,
    required this.scale,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onTap,
    required this.onPickImage,
    required this.onMoved,
    required this.onResized,
    this.onDuplicate,
    this.onDelete,
    this.onTextChanged,
  });

  @override
  State<_CanvasItemView> createState() => _CanvasItemViewState();
}

class _CanvasItemViewState extends State<_CanvasItemView> {
  bool _isDragging = false;
  bool _isEditing = false;
  late TextEditingController _editCtrl;
  late FocusNode _editFocus;

  static bool _isTextEditable(CcCanvasItemType t) =>
      t == CcCanvasItemType.heading ||
      t == CcCanvasItemType.body ||
      t == CcCanvasItemType.bullets ||
      t == CcCanvasItemType.numberedList ||
      t == CcCanvasItemType.button;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.item.text ?? '');
    _editFocus = FocusNode();
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus && _isEditing) _commitEdit();
    });
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _commitEdit() {
    widget.item.text = _editCtrl.text;
    setState(() => _isEditing = false);
    widget.onTextChanged?.call();
  }

  Widget _buildContent() {
    final item = widget.item;
    if (_isEditing && _isTextEditable(item.type)) {
      return TextField(
        controller: _editCtrl,
        focusNode: _editFocus,
        maxLines: null,
        style: TextStyle(
          fontSize: item.fontSize,
          fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
          color: _hexToColor(item.textColor),
          letterSpacing: item.letterSpacing,
        ),
        textAlign: _textAlignFromString(item.textAlign),
        decoration: const InputDecoration.collapsed(hintText: ''),
        onSubmitted: (_) => _commitEdit(),
        keyboardType: TextInputType.multiline,
      );
    }
    switch (item.type) {
      case CcCanvasItemType.heading:
      case CcCanvasItemType.body:
        return Text(
          item.text ?? '',
          textAlign: _textAlignFromString(item.textAlign),
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: item.fontSize,
            fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
            color: _hexToColor(item.textColor),
            letterSpacing: item.letterSpacing,
          ),
        );
      case CcCanvasItemType.icon:
        return Center(
          child: Icon(
            ccIconCatalog[item.iconName] ?? Icons.info_outline_rounded,
            size: (item.height * 0.7).clamp(24.0, 96.0),
            color: _hexToColor(item.textColor),
          ),
        );
      case CcCanvasItemType.image:
        return item.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(item.itemBorderRadius > 0 ? item.itemBorderRadius : 8),
                child: Image.network(
                  item.imageUrl!,
                  width: item.width,
                  height: item.height,
                  fit: BoxFit.contain,
                ),
              )
            : GestureDetector(
                onTap: widget.onPickImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 32),
                  ),
                ),
              );
      case CcCanvasItemType.spacer:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.selected ? AppColors.primary.withValues(alpha: 0.4) : Colors.grey[200]!,
              style: BorderStyle.solid,
            ),
          ),
        );
      case CcCanvasItemType.bullets:
        final lines = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor))),
                  Expanded(child: Text(line, overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: item.fontSize,
                      fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
                      color: _hexToColor(item.textColor),
                      letterSpacing: item.letterSpacing,
                    ))),
                ],
              ),
            )).toList(),
          ),
        );
      case CcCanvasItemType.divider:
        return SizedBox(
          height: item.height,
          child: Center(
            child: Container(
              height: item.borderWidth > 0 ? item.borderWidth : 2,
              color: _hexToColor(item.textColor),
            ),
          ),
        );
      case CcCanvasItemType.button:
        return Container(
          decoration: BoxDecoration(
            color: item.bgFill != null ? _hexToColor(item.bgFill!) : _hexToColor('#F16936'),
            borderRadius: BorderRadius.circular(item.itemBorderRadius > 0 ? item.itemBorderRadius : 8),
            border: item.borderWidth > 0 ? Border.all(color: _hexToColor(item.borderColor), width: item.borderWidth) : null,
          ),
          child: Center(
            child: Text(
              item.text ?? 'Button',
              textAlign: _textAlignFromString(item.textAlign),
              style: TextStyle(
                fontSize: item.fontSize,
                fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
                color: _hexToColor(item.textColor),
                letterSpacing: item.letterSpacing,
              ),
            ),
          ),
        );
      case CcCanvasItemType.numberedList:
        final nLines = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: nLines.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key + 1}. ', style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor), fontWeight: FontWeight.bold)),
                  Expanded(child: Text(e.value, overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: item.fontSize,
                      fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
                      color: _hexToColor(item.textColor),
                      letterSpacing: item.letterSpacing,
                    ))),
                ],
              ),
            )).toList(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final s = widget.scale;
    const handleSize = 10.0;
    const handleHalf = handleSize / 2;
    final sw = item.width * s;
    final sh = item.height * s;
    final isTextType = item.type == CcCanvasItemType.heading ||
        item.type == CcCanvasItemType.body ||
        item.type == CcCanvasItemType.bullets ||
        item.type == CcCanvasItemType.numberedList ||
        item.type == CcCanvasItemType.button;
    final isLocked = item.locked;
    final isHidden = !item.visible;

    // Build the core content with bg/border decoration
    Widget content = Container(
      width: sw,
      height: isTextType ? null : sh,
      decoration: BoxDecoration(
        color: item.bgFill != null ? _hexToColor(item.bgFill!) : null,
        border: Border.all(
          color: item.borderWidth > 0
              ? _hexToColor(item.borderColor)
              : (widget.selected
                  ? AppColors.primary
                  : (_isDragging ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent)),
          width: item.borderWidth > 0 ? item.borderWidth : 1.5,
        ),
        borderRadius: BorderRadius.circular(
            item.itemBorderRadius > 0 ? item.itemBorderRadius : 4),
      ),
      child: item.itemBorderRadius > 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(item.itemBorderRadius),
              child: _buildContent(),
            )
          : _buildContent(),
    );

    // Apply selection outline on top when item has a border
    if (widget.selected && item.borderWidth > 0) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(item.itemBorderRadius > 0 ? item.itemBorderRadius : 4),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Apply opacity
    if (item.opacity < 1.0) {
      content = Opacity(opacity: item.opacity, child: content);
    }

    // Hidden items render at 30% opacity in editor
    if (isHidden) {
      content = Opacity(opacity: 0.3, child: content);
    }

    return Positioned(
      left: item.x * s,
      top: item.y * s,
      width: sw,
      height: isTextType ? null : sh,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _isTextEditable(item.type) && !isLocked
            ? () {
                setState(() => _isEditing = true);
                _editCtrl.text = item.text ?? '';
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) _editFocus.requestFocus();
                });
              }
            : null,
        onPanStart: isLocked
            ? null
            : (_) {
                setState(() => _isDragging = true);
                widget.onTap();
              },
        onPanUpdate: isLocked ? null : (d) => widget.onMoved(d.delta.dx, d.delta.dy),
        onPanEnd: isLocked ? null : (_) => setState(() => _isDragging = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            // Resize handles + action toolbar (only when selected and not locked)
            if (widget.selected && !isLocked) ...[
              _handle(_ResizeHandle.nw, -handleHalf, -handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.n, sw / 2 - handleHalf, -handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.ne, sw - handleHalf, -handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.e, sw - handleHalf, sh / 2 - handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.se, sw - handleHalf, sh - handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.s, sw / 2 - handleHalf, sh - handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.sw, -handleHalf, sh - handleHalf, handleSize, handleSize),
              _handle(_ResizeHandle.w, -handleHalf, sh / 2 - handleHalf, handleSize, handleSize),
            ],
            if (widget.selected) ...[
              // Action toolbar — inside bounds (top-right corner) so hit-testing works
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () {}, // absorb taps so they don't bubble to the move GestureDetector
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionBtn(Icons.copy_rounded, Colors.white.withValues(alpha: 0.9), widget.onDuplicate),
                        _actionBtn(Icons.delete_rounded, Colors.red[300]!, widget.onDelete),
                      ],
                    ),
                  ),
                ),
              ),
              // Lock indicator
              if (isLocked)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _handle(_ResizeHandle h, double l, double t, double w, double ht) {
    MouseCursor cursor;
    switch (h) {
      case _ResizeHandle.nw:
      case _ResizeHandle.se:
        cursor = SystemMouseCursors.resizeUpLeftDownRight;
        break;
      case _ResizeHandle.ne:
      case _ResizeHandle.sw:
        cursor = SystemMouseCursors.resizeUpRightDownLeft;
        break;
      case _ResizeHandle.n:
      case _ResizeHandle.s:
        cursor = SystemMouseCursors.resizeUpDown;
        break;
      case _ResizeHandle.e:
      case _ResizeHandle.w:
        cursor = SystemMouseCursors.resizeLeftRight;
        break;
    }
    return Positioned(
      left: l,
      top: t,
      width: w,
      height: ht,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: (d) => widget.onResized(h, d.delta.dx, d.delta.dy),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ── Properties panel ──────────────────────────────────────────

class _PropertiesPanel extends StatefulWidget {
  final CcScreenConfig config;
  final int? selectedIndex;
  final bool isAr;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onPickImage;
  final Future<void> Function()? onPickBgImage;

  const _PropertiesPanel({
    required this.config,
    required this.selectedIndex,
    required this.isAr,
    required this.onChanged,
    required this.onDelete,
    this.onPickImage,
    this.onPickBgImage,
  });

  @override
  State<_PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<_PropertiesPanel> {
  late TextEditingController _bgImageCtrl;

  @override
  void initState() {
    super.initState();
    _bgImageCtrl = TextEditingController(text: widget.config.backgroundImageUrl ?? '');
  }

  @override
  void didUpdateWidget(_PropertiesPanel old) {
    super.didUpdateWidget(old);
    final newUrl = widget.config.backgroundImageUrl ?? '';
    if (_bgImageCtrl.text != newUrl) _bgImageCtrl.text = newUrl;
  }

  @override
  void dispose() {
    _bgImageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isAr = widget.isAr;
    final hasImage = (config.backgroundImageUrl ?? '').isNotEmpty;
    return Container(
      width: 240,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            isAr ? 'خلفية الشاشة' : 'Screen background',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          _ColorPicker(
            label: isAr ? 'لون الخلفية' : 'Background color',
            colors: const ['#FFFFFF', '#F7F7F9', '#FFF3E9', '#EAF4F1', '#102A3A', '#1E293B', '#F0F4FF'],
            selected: config.backgroundColor,
            onPick: (hex) {
              config.backgroundColor = hex;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 12),
          Text(
            isAr ? 'صورة الخلفية' : 'Background image',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bgImageCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isAr ? 'رابط الصورة...' : 'Image URL...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onChanged: (v) {
                    config.backgroundImageUrl = v.trim().isEmpty ? null : v.trim();
                    widget.onChanged();
                  },
                ),
              ),
              if (widget.onPickBgImage != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  tooltip: isAr ? 'رفع صورة' : 'Upload',
                  onPressed: () async {
                    await widget.onPickBgImage!();
                    setState(() => _bgImageCtrl.text = config.backgroundImageUrl ?? '');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
              if (hasImage)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                  tooltip: isAr ? 'إزالة' : 'Remove',
                  onPressed: () {
                    setState(() => _bgImageCtrl.clear());
                    config.backgroundImageUrl = null;
                    widget.onChanged();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  config.backgroundImageUrl!,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 40,
                    color: Colors.grey[100],
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          const Divider(height: 28),
          if (widget.selectedIndex == null)
            Text(
              isAr ? 'اختر عنصراً لتحريره' : 'Select an item to edit',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          else
            _ItemEditor(
              item: config.items[widget.selectedIndex!],
              isAr: isAr,
              onChanged: widget.onChanged,
              onDelete: widget.onDelete,
              onPickImage: widget.onPickImage,
            ),
        ],
      ),
    );
  }
}

// ── Item editor ───────────────────────────────────────────────

class _ItemEditor extends StatelessWidget {
  final CcCanvasItem item;
  final bool isAr;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onPickImage;

  const _ItemEditor({
    required this.item,
    required this.isAr,
    required this.onChanged,
    required this.onDelete,
    this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final isText =
        item.type == CcCanvasItemType.heading || item.type == CcCanvasItemType.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? 'تعديل العنصر' : 'Edit item',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Position & size
        _SectionLabel(isAr ? 'الموضع والحجم' : 'Position & Size'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _NumField(label: 'X', value: item.x, onChanged: (v) { item.x = v; onChanged(); })),
          const SizedBox(width: 6),
          Expanded(child: _NumField(label: 'Y', value: item.y, onChanged: (v) { item.y = v; onChanged(); })),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _NumField(label: isAr ? 'ع' : 'W', value: item.width, onChanged: (v) { item.width = v.clamp(40, 2000); onChanged(); })),
          const SizedBox(width: 6),
          Expanded(child: _NumField(label: isAr ? 'ط' : 'H', value: item.height, onChanged: (v) { item.height = v.clamp(20, 2000); onChanged(); })),
        ]),
        const Divider(height: 20),

        if (isText) ...[
          _SectionLabel(isAr ? 'النص' : 'Text'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: item.text,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (v) { item.text = v; onChanged(); },
          ),
          const SizedBox(height: 10),
          Text(
            isAr ? 'حجم الخط: ${item.fontSize.round()}' : 'Font size: ${item.fontSize.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.fontSize,
            min: 10,
            max: 48,
            onChanged: (v) { item.fontSize = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
          Row(children: [
            Expanded(
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(isAr ? 'عريض' : 'Bold', style: const TextStyle(fontSize: 11)),
                value: item.bold,
                activeThumbColor: AppColors.primary,
                onChanged: (v) { item.bold = v; onChanged(); },
              ),
            ),
          ]),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isAr ? 'مائل' : 'Italic', style: const TextStyle(fontSize: 11)),
            value: item.italic,
            activeThumbColor: AppColors.primary,
            onChanged: (v) { item.italic = v; onChanged(); },
          ),
          const SizedBox(height: 4),
          Text(isAr ? 'المحاذاة' : 'Alignment', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [TextAlign.left, TextAlign.center, TextAlign.right].map((align) {
              final selected = item.textAlign == _textAlignToString(align);
              final icon = align == TextAlign.left
                  ? Icons.format_align_left_rounded
                  : align == TextAlign.center
                      ? Icons.format_align_center_rounded
                      : Icons.format_align_right_rounded;
              return Expanded(
                child: InkWell(
                  onTap: () { item.textAlign = _textAlignToString(align); onChanged(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _ColorPicker(
            label: isAr ? 'لون النص' : 'Text color',
            colors: const ['#102A3A', '#f16936', '#135467', '#6B7280', '#FFFFFF', '#1A1A1A'],
            selected: item.textColor,
            onPick: (hex) { item.textColor = hex; onChanged(); },
          ),
        ],

        if (item.type == CcCanvasItemType.icon) ...[
          _SectionLabel(isAr ? 'الأيقونة' : 'Icon'),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await _showIconPicker(context, item.iconName);
              if (picked != null) { item.iconName = picked; onChanged(); }
            },
            icon: Icon(ccIconCatalog[item.iconName] ?? Icons.emoji_emotions_outlined, size: 18),
            label: Text(isAr ? 'تغيير الأيقونة' : 'Change icon', style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          _ColorPicker(
            label: isAr ? 'لون الأيقونة' : 'Icon color',
            colors: const ['#f16936', '#135467', '#6B7280', '#16A34A', '#DC2626', '#1A1A1A'],
            selected: item.textColor,
            onPick: (hex) { item.textColor = hex; onChanged(); },
          ),
        ],

        if (item.type == CcCanvasItemType.image) ...[
          _SectionLabel(isAr ? 'الصورة' : 'Image'),
          const SizedBox(height: 6),
          if (onPickImage != null)
            OutlinedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: Text(
                item.imageUrl != null
                    ? (isAr ? 'تغيير الصورة' : 'Change image')
                    : (isAr ? 'رفع صورة' : 'Upload image'),
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
        ],

        if (item.type == CcCanvasItemType.spacer) ...[
          Text(
            isAr ? 'الارتفاع: ${item.spacerHeight.round()}' : 'Height: ${item.spacerHeight.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.spacerHeight,
            min: 4,
            max: 120,
            onChanged: (v) { item.spacerHeight = v; item.height = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
        ],

        if (item.type == CcCanvasItemType.bullets) ...[
          _SectionLabel(isAr ? 'النقاط' : 'Bullet points'),
          const SizedBox(height: 4),
          Text(
            isAr ? 'سطر واحد لكل نقطة' : 'One line per bullet',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: item.text,
            maxLines: 6,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: isAr ? 'النقطة الأولى\nالنقطة الثانية' : 'First point\nSecond point',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (v) { item.text = v; onChanged(); },
          ),
          const SizedBox(height: 10),
          Text(
            isAr ? 'حجم الخط: ${item.fontSize.round()}' : 'Font size: ${item.fontSize.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.fontSize,
            min: 10,
            max: 32,
            onChanged: (v) { item.fontSize = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
          _ColorPicker(
            label: isAr ? 'لون النص' : 'Text color',
            colors: const ['#102A3A', '#f16936', '#135467', '#6B7280', '#FFFFFF', '#1A1A1A'],
            selected: item.textColor,
            onPick: (hex) { item.textColor = hex; onChanged(); },
          ),
        ],

        if (item.type == CcCanvasItemType.numberedList) ...[
          _SectionLabel(isAr ? 'القائمة المرقمة' : 'Numbered list'),
          const SizedBox(height: 4),
          Text(
            isAr ? 'سطر واحد لكل عنصر' : 'One line per item',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: item.text,
            maxLines: 6,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: isAr ? 'العنصر الأول\nالعنصر الثاني' : 'First item\nSecond item',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (v) { item.text = v; onChanged(); },
          ),
          const SizedBox(height: 10),
          Text(
            isAr ? 'حجم الخط: ${item.fontSize.round()}' : 'Font size: ${item.fontSize.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.fontSize,
            min: 10,
            max: 32,
            onChanged: (v) { item.fontSize = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
          _ColorPicker(
            label: isAr ? 'لون النص' : 'Text color',
            colors: const ['#102A3A', '#f16936', '#135467', '#6B7280', '#FFFFFF', '#1A1A1A'],
            selected: item.textColor,
            onPick: (hex) { item.textColor = hex; onChanged(); },
          ),
        ],

        if (item.type == CcCanvasItemType.button) ...[
          _SectionLabel(isAr ? 'الزر' : 'Button'),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: item.text,
            maxLines: 1,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: isAr ? 'نص الزر' : 'Button text',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (v) { item.text = v; onChanged(); },
          ),
          const SizedBox(height: 10),
          Text(
            isAr ? 'حجم الخط: ${item.fontSize.round()}' : 'Font size: ${item.fontSize.round()}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.fontSize,
            min: 10,
            max: 32,
            onChanged: (v) { item.fontSize = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
          _ColorPicker(
            label: isAr ? 'لون النص' : 'Text color',
            colors: const ['#FFFFFF', '#102A3A', '#f16936', '#135467', '#6B7280', '#1A1A1A'],
            selected: item.textColor,
            onPick: (hex) { item.textColor = hex; onChanged(); },
          ),
        ],

        // ── Layer section (always shown) ──────────────────────────
        const Divider(height: 20),
        _SectionLabel(isAr ? 'الطبقة' : 'Layer'),
        const SizedBox(height: 8),
        Text(
          isAr ? 'الشفافية: ${(item.opacity * 100).round()}%' : 'Opacity: ${(item.opacity * 100).round()}%',
          style: const TextStyle(fontSize: 11),
        ),
        Slider(
          value: item.opacity,
          min: 0,
          max: 1,
          onChanged: (v) { item.opacity = v; onChanged(); },
          activeColor: AppColors.primary,
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () { item.locked = !item.locked; onChanged(); },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  backgroundColor: item.locked ? Colors.orange[100] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(item.locked ? (isAr ? 'مقفل' : 'Locked') : (isAr ? 'قفل' : 'Lock'), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () { item.visible = !item.visible; onChanged(); },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  backgroundColor: !item.visible ? Colors.grey[200] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(item.visible ? (isAr ? 'مرئي' : 'Visible') : (isAr ? 'مخفي' : 'Hidden'), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Background fill (not for spacer/divider) ───────────────
        if (item.type != CcCanvasItemType.spacer && item.type != CcCanvasItemType.divider) ...[
          const Divider(height: 20),
          _SectionLabel(isAr ? 'خلفية العنصر' : 'Element background'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.bgFill != null ? item.bgFill!.toUpperCase() : (isAr ? 'بدون' : 'None'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (item.bgFill != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                  tooltip: isAr ? 'إزالة' : 'Remove',
                  onPressed: () { item.bgFill = null; onChanged(); },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
            ],
          ),
          _ColorPicker(
            label: isAr ? 'لون الخلفية' : 'Fill color',
            colors: const ['#FFFFFF', '#F7F7F9', '#FFF3E9', '#EAF4F1', '#102A3A', '#F16936', '#1E293B'],
            selected: item.bgFill ?? '#FFFFFF',
            onPick: (hex) { item.bgFill = hex; onChanged(); },
          ),
        ],

        // ── Border section ─────────────────────────────────────────
        const Divider(height: 20),
        _SectionLabel(isAr ? 'الإطار' : 'Border'),
        const SizedBox(height: 6),
        Text(
          isAr ? 'سُمك الإطار: ${item.borderWidth.round()}' : 'Border width: ${item.borderWidth.round()}',
          style: const TextStyle(fontSize: 11),
        ),
        Slider(
          value: item.borderWidth,
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) { item.borderWidth = v; onChanged(); },
          activeColor: AppColors.primary,
        ),
        if (item.borderWidth > 0) ...[
          _ColorPicker(
            label: isAr ? 'لون الإطار' : 'Border color',
            colors: const ['#CCCCCC', '#102A3A', '#F16936', '#135467', '#6B7280', '#FFFFFF', '#1A1A1A'],
            selected: item.borderColor,
            onPick: (hex) { item.borderColor = hex; onChanged(); },
          ),
          const SizedBox(height: 8),
        ],
        Text(
          isAr ? 'نصف قطر الزاوية: ${item.itemBorderRadius.round()}' : 'Corner radius: ${item.itemBorderRadius.round()}',
          style: const TextStyle(fontSize: 11),
        ),
        Slider(
          value: item.itemBorderRadius,
          min: 0,
          max: 40,
          onChanged: (v) { item.itemBorderRadius = v; onChanged(); },
          activeColor: AppColors.primary,
        ),

        // ── Letter spacing (for text types) ───────────────────────
        if (item.type == CcCanvasItemType.heading ||
            item.type == CcCanvasItemType.body ||
            item.type == CcCanvasItemType.bullets ||
            item.type == CcCanvasItemType.numberedList ||
            item.type == CcCanvasItemType.button) ...[
          const Divider(height: 20),
          Text(
            isAr ? 'تباعد الأحرف: ${item.letterSpacing.toStringAsFixed(1)}' : 'Letter spacing: ${item.letterSpacing.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11),
          ),
          Slider(
            value: item.letterSpacing,
            min: -2,
            max: 10,
            onChanged: (v) { item.letterSpacing = v; onChanged(); },
            activeColor: AppColors.primary,
          ),
        ],
      ],
    );
  }

  static Future<String?> _showIconPicker(BuildContext context, String? current) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _IconPickerDialog(current: current),
    );
  }
}

// ── Icon picker dialog ────────────────────────────────────────

class _IconPickerDialog extends StatefulWidget {
  final String? current;
  const _IconPickerDialog({this.current});

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = ccIconCatalog.entries
        .where((e) => _query.isEmpty || e.key.contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr ? 'اختر أيقونة' : 'Choose an icon',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: isAr ? 'بحث...' : 'Search...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final entry = filtered[i];
                  final isSel = entry.key == widget.current;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Tooltip(
                        message: entry.key,
                        child: Icon(
                          entry.value,
                          size: 24,
                          color: isSel ? AppColors.primary : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Template data ─────────────────────────────────────────────

class _TemplateData {
  final String nameAr;
  final String nameEn;
  final String tagAr;
  final String tagEn;
  final Color tagColor;
  final String bgColor;
  final List<CcCanvasItem> items;

  const _TemplateData({
    required this.nameAr,
    required this.nameEn,
    required this.tagAr,
    required this.tagEn,
    required this.tagColor,
    required this.bgColor,
    required this.items,
  });

  String name(bool isAr) => isAr ? nameAr : nameEn;
  String tag(bool isAr) => isAr ? tagAr : tagEn;
}

// ── Template library ──────────────────────────────────────────

class _TemplateLibrary {
  static List<CcCanvasItem> classicWelcome(bool isAr) => [
    CcCanvasItem(id: 'tw_icon', type: CcCanvasItemType.icon, iconName: 'star', textColor: '#F16936', x: 330, y: 40, width: 100, height: 100),
    CcCanvasItem(id: 'tw_h', type: CcCanvasItemType.heading, text: isAr ? 'مرحباً بك' : 'Welcome', textColor: '#102A3A', bold: true, fontSize: 30, textAlign: 'center', x: 160, y: 160, width: 440, height: 56),
    CcCanvasItem(id: 'tw_b', type: CcCanvasItemType.body, text: isAr ? 'يرجى ملء النموذج أدناه للمتابعة' : 'Please fill in the form below to continue', textColor: '#6B7280', fontSize: 16, textAlign: 'center', x: 160, y: 228, width: 440, height: 40),
  ];

  static List<CcCanvasItem> successEnhanced(bool isAr) => [
    CcCanvasItem(id: 'ts_icon', type: CcCanvasItemType.icon, iconName: 'verified', textColor: '#16A34A', x: 330, y: 40, width: 100, height: 100),
    CcCanvasItem(id: 'ts_h', type: CcCanvasItemType.heading, text: isAr ? 'تم الإرسال بنجاح' : 'Submitted Successfully', textColor: '#102A3A', bold: true, fontSize: 28, textAlign: 'center', x: 160, y: 162, width: 440, height: 52),
    CcCanvasItem(id: 'ts_b', type: CcCanvasItemType.body, text: isAr ? 'شكراً لك، سيتم التواصل معك قريباً' : 'Thank you! We will get back to you soon.', textColor: '#6B7280', fontSize: 15, textAlign: 'center', x: 160, y: 226, width: 440, height: 40),
  ];

  static List<_TemplateData> all(bool isAr) => [
    // 1 – Classic Welcome
    _TemplateData(
      nameAr: 'ترحيب كلاسيكي', nameEn: 'Classic Welcome',
      tagAr: 'ترحيب', tagEn: 'Welcome', tagColor: Colors.orange,
      bgColor: '#FFFFFF',
      items: classicWelcome(isAr),
    ),
    // 2 – Corporate Dark
    _TemplateData(
      nameAr: 'احترافي داكن', nameEn: 'Corporate Dark',
      tagAr: 'ترحيب', tagEn: 'Welcome', tagColor: Colors.blueGrey,
      bgColor: '#102A3A',
      items: [
        CcCanvasItem(id: 'cd_sp', type: CcCanvasItemType.spacer, x: 180, y: 60, width: 400, height: 3, textColor: '#F16936'),
        CcCanvasItem(id: 'cd_h', type: CcCanvasItemType.heading, text: isAr ? 'مرحباً بك في بوابتنا' : 'Welcome to Our Portal', textColor: '#FFFFFF', bold: true, fontSize: 30, textAlign: 'center', x: 100, y: 100, width: 560, height: 56),
        CcCanvasItem(id: 'cd_b', type: CcCanvasItemType.body, text: isAr ? 'يرجى تعبئة جميع الحقول بعناية' : 'Please fill in all required fields carefully', textColor: '#A0B8C8', fontSize: 16, textAlign: 'center', x: 130, y: 170, width: 500, height: 40),
        CcCanvasItem(id: 'cd_sp2', type: CcCanvasItemType.spacer, x: 180, y: 228, width: 400, height: 3, textColor: '#F16936'),
        CcCanvasItem(id: 'cd_sub', type: CcCanvasItemType.body, text: isAr ? 'سيتم معالجة طلبك في أقرب وقت' : 'Your request will be processed shortly', textColor: '#6B8FA3', fontSize: 13, textAlign: 'center', x: 160, y: 250, width: 440, height: 36),
      ],
    ),
    // 3 – Sky Blue
    _TemplateData(
      nameAr: 'أزرق سماوي', nameEn: 'Sky Blue',
      tagAr: 'ترحيب', tagEn: 'Welcome', tagColor: Colors.blue,
      bgColor: '#EFF6FF',
      items: [
        CcCanvasItem(id: 'sb_icon', type: CcCanvasItemType.icon, iconName: 'notification', textColor: '#3B82F6', x: 330, y: 30, width: 100, height: 100),
        CcCanvasItem(id: 'sb_h', type: CcCanvasItemType.heading, text: isAr ? 'أرسل طلبك' : 'Submit Your Request', textColor: '#1E40AF', bold: true, fontSize: 26, textAlign: 'center', x: 160, y: 148, width: 440, height: 50),
        CcCanvasItem(id: 'sb_b', type: CcCanvasItemType.body, text: isAr ? 'رأيك يهمنا، أخبرنا بما تفكر فيه' : 'Your voice matters. Let us know your thoughts.', textColor: '#3B82F6', fontSize: 15, textAlign: 'center', x: 140, y: 210, width: 480, height: 40),
      ],
    ),
    // 4 – Minimal Clean
    _TemplateData(
      nameAr: 'بسيط ونظيف', nameEn: 'Minimal Clean',
      tagAr: 'بسيط', tagEn: 'Minimal', tagColor: Colors.grey,
      bgColor: '#FAFAFA',
      items: [
        CcCanvasItem(id: 'mc_h', type: CcCanvasItemType.heading, text: isAr ? 'مرحباً!' : 'Hello!', textColor: '#102A3A', bold: true, fontSize: 40, textAlign: 'center', x: 200, y: 160, width: 360, height: 64),
        CcCanvasItem(id: 'mc_b', type: CcCanvasItemType.body, text: isAr ? 'نحن هنا لمساعدتك' : 'We are here to help you', textColor: '#9CA3AF', fontSize: 18, textAlign: 'center', x: 180, y: 238, width: 400, height: 44),
      ],
    ),
    // 5 – Success
    _TemplateData(
      nameAr: 'إرسال ناجح', nameEn: 'Success',
      tagAr: 'نهاية', tagEn: 'Closing', tagColor: Colors.green,
      bgColor: '#FFFFFF',
      items: successEnhanced(isAr),
    ),
    // 6 – Dark Success
    _TemplateData(
      nameAr: 'نجاح داكن', nameEn: 'Dark Success',
      tagAr: 'نهاية', tagEn: 'Closing', tagColor: Color(0xFF166534),
      bgColor: '#102A3A',
      items: [
        CcCanvasItem(id: 'ds_icon', type: CcCanvasItemType.icon, iconName: 'verified', textColor: '#4ADE80', x: 330, y: 40, width: 100, height: 100),
        CcCanvasItem(id: 'ds_h', type: CcCanvasItemType.heading, text: isAr ? 'تم بنجاح!' : 'Done!', textColor: '#FFFFFF', bold: true, fontSize: 36, textAlign: 'center', x: 200, y: 162, width: 360, height: 60),
        CcCanvasItem(id: 'ds_b', type: CcCanvasItemType.body, text: isAr ? 'تم استلام طلبك بنجاح' : 'Your request has been received', textColor: '#7DD3B0', fontSize: 16, textAlign: 'center', x: 180, y: 236, width: 400, height: 40),
      ],
    ),
    // 7 – Thank You
    _TemplateData(
      nameAr: 'شكر وتقدير', nameEn: 'Thank You',
      tagAr: 'نهاية', tagEn: 'Closing', tagColor: Colors.pink,
      bgColor: '#FFF0F7',
      items: [
        CcCanvasItem(id: 'ty_icon', type: CcCanvasItemType.icon, iconName: 'heart', textColor: '#DB2777', x: 330, y: 40, width: 100, height: 100),
        CcCanvasItem(id: 'ty_h', type: CcCanvasItemType.heading, text: isAr ? 'شكراً جزيلاً!' : 'Thank You!', textColor: '#9D174D', bold: true, fontSize: 30, textAlign: 'center', x: 160, y: 160, width: 440, height: 54),
        CcCanvasItem(id: 'ty_b', type: CcCanvasItemType.body, text: isAr ? 'نقدر وقتك ومساهمتك معنا' : 'We truly appreciate your time and feedback', textColor: '#BE185D', fontSize: 15, textAlign: 'center', x: 160, y: 226, width: 440, height: 40),
      ],
    ),
    // 8 – Celebration
    _TemplateData(
      nameAr: 'احتفالي', nameEn: 'Celebration',
      tagAr: 'نهاية', tagEn: 'Closing', tagColor: Colors.amber,
      bgColor: '#FFFBEB',
      items: [
        CcCanvasItem(id: 'cl_icon', type: CcCanvasItemType.icon, iconName: 'celebration', textColor: '#D97706', x: 330, y: 30, width: 100, height: 100),
        CcCanvasItem(id: 'cl_h', type: CcCanvasItemType.heading, text: isAr ? 'تهانينا!' : 'Congratulations!', textColor: '#92400E', bold: true, fontSize: 28, textAlign: 'center', x: 160, y: 150, width: 440, height: 52),
        CcCanvasItem(id: 'cl_b', type: CcCanvasItemType.body, text: isAr ? 'تم استلام طلبك وسيتم مراجعته' : 'Your application has been received and is under review', textColor: '#78350F', fontSize: 14, textAlign: 'center', x: 120, y: 214, width: 520, height: 40),
      ],
    ),
    // 9 – Instructions
    _TemplateData(
      nameAr: 'تعليمات مهمة', nameEn: 'Instructions',
      tagAr: 'معلومات', tagEn: 'Info', tagColor: Colors.blue,
      bgColor: '#EFF6FF',
      items: [
        CcCanvasItem(id: 'in_icon', type: CcCanvasItemType.icon, iconName: 'info', textColor: '#2563EB', x: 330, y: 20, width: 100, height: 100),
        CcCanvasItem(id: 'in_h', type: CcCanvasItemType.heading, text: isAr ? 'تعليمات مهمة' : 'Important Instructions', textColor: '#1E3A8A', bold: true, fontSize: 22, textAlign: 'center', x: 160, y: 136, width: 440, height: 44),
        CcCanvasItem(id: 'in_bl', type: CcCanvasItemType.bullets,
          text: isAr
            ? 'تأكد من صحة جميع البيانات\nأرفق المستندات المطلوبة\nسيصلك رد خلال 3 أيام عمل'
            : 'Verify all your information is correct\nAttach all required documents\nExpect a reply within 3 business days',
          textColor: '#1E3A8A', fontSize: 14, x: 100, y: 196, width: 560, height: 120),
      ],
    ),
    // 10 – Privacy Notice
    _TemplateData(
      nameAr: 'إشعار الخصوصية', nameEn: 'Privacy Notice',
      tagAr: 'معلومات', tagEn: 'Info', tagColor: Colors.green,
      bgColor: '#F0FDF4',
      items: [
        CcCanvasItem(id: 'pn_icon', type: CcCanvasItemType.icon, iconName: 'shield', textColor: '#16A34A', x: 330, y: 20, width: 100, height: 100),
        CcCanvasItem(id: 'pn_h', type: CcCanvasItemType.heading, text: isAr ? 'إشعار الخصوصية' : 'Privacy Notice', textColor: '#14532D', bold: true, fontSize: 24, textAlign: 'center', x: 160, y: 136, width: 440, height: 48),
        CcCanvasItem(id: 'pn_bl', type: CcCanvasItemType.bullets,
          text: isAr
            ? 'بياناتك محمية ولن تُشارك مع أطراف خارجية\nنستخدم بياناتك فقط لمعالجة طلبك\nيمكنك طلب حذف بياناتك في أي وقت'
            : 'Your data is protected and never shared externally\nWe only use your data to process your request\nYou may request data deletion at any time',
          textColor: '#166534', fontSize: 14, x: 100, y: 198, width: 560, height: 120),
      ],
    ),
    // 11 – Warning Notice
    _TemplateData(
      nameAr: 'تنبيه مهم', nameEn: 'Warning Notice',
      tagAr: 'تنبيه', tagEn: 'Warning', tagColor: Colors.orange,
      bgColor: '#FFFBEB',
      items: [
        CcCanvasItem(id: 'wn_icon', type: CcCanvasItemType.icon, iconName: 'warning', textColor: '#D97706', x: 330, y: 20, width: 100, height: 100),
        CcCanvasItem(id: 'wn_h', type: CcCanvasItemType.heading, text: isAr ? 'انتبه قبل المتابعة' : 'Attention Required', textColor: '#92400E', bold: true, fontSize: 24, textAlign: 'center', x: 160, y: 136, width: 440, height: 48),
        CcCanvasItem(id: 'wn_b', type: CcCanvasItemType.body, text: isAr ? 'يرجى قراءة التعليمات التالية بعناية قبل المتابعة' : 'Please read the following carefully before proceeding', textColor: '#78350F', fontSize: 14, textAlign: 'center', x: 130, y: 196, width: 500, height: 44),
        CcCanvasItem(id: 'wn_bl', type: CcCanvasItemType.bullets,
          text: isAr
            ? 'لا يمكن التراجع عن الطلب بعد إرساله\nتأكد من دقة المعلومات المقدمة'
            : 'Requests cannot be withdrawn after submission\nEnsure all provided information is accurate',
          textColor: '#92400E', fontSize: 14, x: 120, y: 252, width: 520, height: 80),
      ],
    ),
    // 12 – Confirmation + Reference
    _TemplateData(
      nameAr: 'تأكيد الطلب', nameEn: 'Confirmation',
      tagAr: 'نهاية', tagEn: 'Closing', tagColor: Color(0xFF4F46E5),
      bgColor: '#F0F4FF',
      items: [
        CcCanvasItem(id: 'cf_icon', type: CcCanvasItemType.icon, iconName: 'check', textColor: '#6366F1', x: 330, y: 30, width: 100, height: 100),
        CcCanvasItem(id: 'cf_h', type: CcCanvasItemType.heading, text: isAr ? 'تم استلام طلبك' : 'Request Received', textColor: '#312E81', bold: true, fontSize: 26, textAlign: 'center', x: 160, y: 148, width: 440, height: 50),
        CcCanvasItem(id: 'cf_b', type: CcCanvasItemType.body, text: isAr ? 'سيتم إرسال رقم مرجعي إلى بريدك الإلكتروني' : 'A reference number will be sent to your email', textColor: '#4338CA', fontSize: 14, textAlign: 'center', x: 120, y: 210, width: 520, height: 44),
        CcCanvasItem(id: 'cf_sub', type: CcCanvasItemType.body, text: isAr ? 'الرجاء الاحتفاظ بالرقم للمتابعة' : 'Please keep your reference number for follow-up', textColor: '#6366F1', fontSize: 13, textAlign: 'center', x: 160, y: 266, width: 440, height: 36),
      ],
    ),
    // 13 – Blank
    _TemplateData(
      nameAr: 'فارغ', nameEn: 'Blank',
      tagAr: 'عام', tagEn: 'General', tagColor: Colors.grey,
      bgColor: '#FFFFFF',
      items: [],
    ),
  ];
}

// ── Template miniature renderer ───────────────────────────────

class _TemplateMiniature extends StatelessWidget {
  final List<CcCanvasItem> items;
  final String bgColor;

  const _TemplateMiniature({required this.items, required this.bgColor});

  static const double _previewW = 160.0;
  static const double _previewH = 200.0;
  static const double _designW = 760.0;
  static const double _designH = 380.0;
  static const double _scale = _previewW / _designW;

  Widget _buildMiniItem(CcCanvasItem item) {
    switch (item.type) {
      case CcCanvasItemType.icon:
        return Center(child: Icon(
          ccIconCatalog[item.iconName] ?? Icons.info_outline_rounded,
          size: (item.height * 0.7).clamp(12.0, 80.0),
          color: _hexToColor(item.textColor),
        ));
      case CcCanvasItemType.heading:
      case CcCanvasItemType.body:
        return Text(
          item.text ?? '',
          textAlign: _textAlignFromString(item.textAlign),
          overflow: TextOverflow.clip,
          maxLines: 2,
          style: TextStyle(
            fontSize: item.fontSize,
            fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
            color: _hexToColor(item.textColor),
          ),
        );
      case CcCanvasItemType.bullets:
        final lines = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: lines.map((line) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor))),
              Expanded(child: Text(line, overflow: TextOverflow.clip, maxLines: 1,
                style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor)))),
            ],
          )).toList(),
        );
      case CcCanvasItemType.spacer:
        return Container(color: _hexToColor(item.textColor).withValues(alpha: 0.5));
      case CcCanvasItemType.image:
        return Container(
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
          child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 20)),
        );
      case CcCanvasItemType.divider:
        return Center(child: Container(height: 2, color: _hexToColor(item.textColor)));
      case CcCanvasItemType.button:
        return Container(
          decoration: BoxDecoration(
            color: item.bgFill != null ? _hexToColor(item.bgFill!) : const Color(0xFFF16936),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              item.text ?? 'Button',
              overflow: TextOverflow.clip,
              maxLines: 1,
              style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor)),
            ),
          ),
        );
      case CcCanvasItemType.numberedList:
        final nLines2 = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: nLines2.asMap().entries.map((e) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.key + 1}. ', style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor), fontWeight: FontWeight.bold)),
              Expanded(child: Text(e.value, overflow: TextOverflow.clip, maxLines: 1,
                style: TextStyle(fontSize: item.fontSize, color: _hexToColor(item.textColor)))),
            ],
          )).toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        width: _previewW,
        height: _previewH,
        color: _hexToColor(bgColor),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: _designW,
          maxHeight: _designH,
          child: Transform.scale(
            scale: _scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _designW,
              height: _designH,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: items.map((item) => Positioned(
                  left: item.x,
                  top: item.y,
                  width: item.width,
                  child: _buildMiniItem(item),
                )).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template card ─────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final _TemplateData data;
  final bool isAr;
  final VoidCallback onTap;
  const _TemplateCard({required this.data, required this.isAr, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? AppColors.primary : Colors.grey[200]!,
              width: _hovered ? 2 : 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TemplateMiniature(items: widget.data.items, bgColor: widget.data.bgColor),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.data.name(widget.isAr),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.data.tagColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.data.tag(widget.isAr),
                          style: TextStyle(fontSize: 9, color: widget.data.tagColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template dialog ───────────────────────────────────────────

class _TemplateDialog extends StatelessWidget {
  final bool isAr;
  const _TemplateDialog({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final templates = _TemplateLibrary.all(isAr);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'اختر قالباً' : 'Choose a template',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          isAr ? 'اختر نقطة البداية وقم بتخصيصها' : 'Pick a starting point and customize it',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Grid
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 160 / 232,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (_, i) => _TemplateCard(
                    data: templates[i],
                    isAr: isAr,
                    onTap: () => Navigator.pop(context, templates[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.3,
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label${value.round()}'),
      initialValue: value.round().toString(),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onFieldSubmitted: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String label;
  final List<String> colors;
  final String selected;
  final ValueChanged<String> onPick;

  const _ColorPicker({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  Future<void> _openPicker(BuildContext context) async {
    Color current = _hexToColor(selected);
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initial: current),
    );
    if (result != null) {
      final r = (result.r * 255).round().toRadixString(16).padLeft(2, '0');
      final g = (result.g * 255).round().toRadixString(16).padLeft(2, '0');
      final b = (result.b * 255).round().toRadixString(16).padLeft(2, '0');
      onPick('#$r$g$b'.toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: [
            ...colors.map((hex) => GestureDetector(
              onTap: () => onPick(hex),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _hexToColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected.toUpperCase() == hex.toUpperCase() ? AppColors.primary : Colors.grey[300]!,
                    width: selected.toUpperCase() == hex.toUpperCase() ? 2 : 1,
                  ),
                ),
              ),
            )),
            GestureDetector(
              onTap: () => _openPicker(context),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                ),
                child: const Center(child: Icon(Icons.colorize_rounded, size: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _hexToColor(selected),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                const SizedBox(width: 6),
                Text(selected.toUpperCase(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(width: 4),
                Icon(Icons.edit_rounded, size: 11, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(isAr ? 'اختر لوناً' : 'Pick a color', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ColorPicker(
                color: _color,
                onColorChanged: (c) => setState(() => _color = c),
                width: 36,
                height: 36,
                borderRadius: 22,
                spacing: 5,
                runSpacing: 5,
                wheelDiameter: 200,
                heading: null,
                subheading: null,
                wheelSubheading: null,
                showColorName: false,
                showColorCode: true,
                colorCodeHasColor: true,
                pickersEnabled: const {
                  ColorPickerType.wheel: true,
                  ColorPickerType.primary: false,
                  ColorPickerType.accent: false,
                  ColorPickerType.bw: false,
                  ColorPickerType.both: false,
                  ColorPickerType.custom: false,
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _color),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    child: Text(isAr ? 'تطبيق' : 'Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
