import 'dart:convert' show base64Encode;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'cc_models.dart';
import 'cc_service.dart';
import 'cc_field_widgets.dart';
import 'cc_screen_designer.dart';
import 'cc_audience_panel.dart';
import 'cc_submission_flow_screen.dart' show CcFormFillView;
import '_web_preview_stub.dart'
    if (dart.library.js_interop) '_web_preview.dart';

class CcFormBuilderScreen extends StatefulWidget {
  final UserModel currentUser;
  final String? editFormId;

  const CcFormBuilderScreen({
    super.key,
    required this.currentUser,
    this.editFormId,
  });

  @override
  State<CcFormBuilderScreen> createState() => _CcFormBuilderScreenState();
}

class _CcFormBuilderScreenState extends State<CcFormBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  CcForm? _form;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Which step is currently being edited
  int _activeStepIndex = 0;
  // Which field is selected for property editing
  CcFormField? _selectedField;
  // Right panel mode: 'form' | 'field'
  String _rightPanel = 'form';

  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initForm();
  }

  Future<void> _initForm() async {
    try {
      if (widget.editFormId != null) {
        final f = await CcService.getFullForm(widget.editFormId!);
        if (f == null) throw Exception('Form not found');
        setState(() {
          _form = f;
          _titleCtrl.text = f.title;
          _loading = false;
        });
      } else {
        final f = await CcService.createForm(widget.currentUser.id);
        setState(() {
          _form = f;
          _titleCtrl.text = '';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_form == null) return;
    setState(() => _saving = true);
    try {
      await CcService.updateFormSettings(_form!.id, {
        'title': _titleCtrl.text.trim(),
        'theme_color': _form!.themeColor,
        'identity_mode': _form!.identityMode.value,
        'external_apply_enabled': _form!.externalApplyEnabled,
        'show_onboarding': _form!.showOnboarding,
        'onboarding_config': _form!.onboardingConfig,
        'show_closing': _form!.showClosing,
        'closing_config': _form!.closingConfig,
        'progress_style': _form!.progressStyle.value,
        'logo_url': _form!.logoUrl,
        'is_active': _form!.isActive,
        'notify_creator_on_submit': _form!.notifyCreatorOnSubmit,
        'notify_email': _form!.notifyEmail,
        'notify_additional_emails': _form!.notifyAdditionalEmails,
        'notify_additional_user_ids': _form!.notifyAdditionalUserIds,
        'notify_custom_message': _form!.notifyCustomMessage,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null || _form == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Form Builder')),
        body: Center(child: Text(_error ?? 'Unknown error')),
      );
    }

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: SizedBox(
          width: 260,
          child: TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: isAr ? 'اسم النموذج...' : 'Form title...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.onBackground,
            ),
            onChanged: (v) => _form!.title = v,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: isAr ? 'البناء' : 'Build'),
            Tab(text: isAr ? 'الإعدادات' : 'Settings'),
            Tab(text: isAr ? 'الجمهور' : 'Audience'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _FormPreviewWrapper(
                  form: _form!,
                  currentUser: widget.currentUser,
                ),
              ),
            ),
            icon: const Icon(Icons.preview_rounded, size: 18),
            label: Text(isAr ? 'معاينة' : 'Preview'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(isAr ? 'حفظ' : 'Save'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _BuildTab(
            form: _form!,
            activeStepIndex: _activeStepIndex,
            selectedField: _selectedField,
            rightPanel: _rightPanel,
            onStepChanged: (i) => setState(() { _activeStepIndex = i; _selectedField = null; }),
            onFieldSelected: (f) => setState(() { _selectedField = f; _rightPanel = 'field'; }),
            onFieldDeselect: () => setState(() { _selectedField = null; _rightPanel = 'form'; }),
            onFormChanged: () => setState(() {}),
            currentUser: widget.currentUser,
          ),
          _SettingsTab(
            form: _form!,
            onChanged: () => setState(() {}),
            currentUser: widget.currentUser,
          ),
          CcAudiencePanel(
            form: _form!,
            currentUser: widget.currentUser,
          ),
        ],
      ),
    );
  }
}

// ── Build Tab ─────────────────────────────────────────────

class _BuildTab extends StatelessWidget {
  final CcForm form;
  final int activeStepIndex;
  final CcFormField? selectedField;
  final String rightPanel;
  final ValueChanged<int> onStepChanged;
  final ValueChanged<CcFormField> onFieldSelected;
  final VoidCallback onFieldDeselect;
  final VoidCallback onFormChanged;
  final UserModel currentUser;

  const _BuildTab({
    required this.form,
    required this.activeStepIndex,
    required this.selectedField,
    required this.rightPanel,
    required this.onStepChanged,
    required this.onFieldSelected,
    required this.onFieldDeselect,
    required this.onFormChanged,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: steps + field palette
        _LeftPanel(
          form: form,
          activeStepIndex: activeStepIndex,
          onStepChanged: onStepChanged,
          onFormChanged: onFormChanged,
        ),
        // Center: canvas
        Expanded(
          child: _Canvas(
            form: form,
            selectedField: selectedField,
            onFieldSelected: onFieldSelected,
            onFormChanged: onFormChanged,
          ),
        ),
        // Right: properties
        _RightPanel(
          form: form,
          selectedField: selectedField,
          onChanged: onFormChanged,
          onDeselect: onFieldDeselect,
        ),
      ],
    );
  }
}

// ── Left Panel: Steps + Field Palette ─────────────────────

class _LeftPanel extends StatefulWidget {
  final CcForm form;
  final int activeStepIndex;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onFormChanged;

  const _LeftPanel({
    required this.form,
    required this.activeStepIndex,
    required this.onStepChanged,
    required this.onFormChanged,
  });

  @override
  State<_LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<_LeftPanel> {
  bool _showPalette = true;

  Future<void> _addStep() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final idx = widget.form.steps.length;
    final title = '${isAr ? "خطوة" : "Step"} ${idx + 1}';
    try {
      final step = await CcService.addStep(widget.form.id, idx, title);
      widget.form.steps.add(step);
      widget.onFormChanged();
      widget.onStepChanged(idx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _renameStep(int index) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final ctrl = TextEditingController(text: widget.form.steps[index].title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تعديل اسم الخطوة' : 'Rename Step'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isAr ? 'اسم الخطوة' : 'Step name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      widget.form.steps[index].title = result;
      await CcService.updateStep(widget.form.steps[index].id, {'title': result});
      widget.onFormChanged();
    }
  }

  Future<void> _deleteStep(int index) async {
    if (widget.form.steps.length <= 1) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'حذف الخطوة؟' : 'Delete step?'),
        content: Text(isAr ? 'سيتم حذف جميع حقول هذه الخطوة.' : 'All fields in this step will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await CcService.deleteStep(widget.form.steps[index].id);
      widget.form.steps.removeAt(index);
      widget.onFormChanged();
      if (widget.activeStepIndex >= widget.form.steps.length) {
        widget.onStepChanged(widget.form.steps.length - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Steps header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Row(
              children: [
                Text(isAr ? 'الخطوات' : 'Steps',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  color: AppColors.primary,
                  tooltip: isAr ? 'إضافة خطوة' : 'Add step',
                  onPressed: _addStep,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Steps list
          ...widget.form.steps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final selected = i == widget.activeStepIndex;
            return GestureDetector(
              onTap: () => widget.onStepChanged(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? Border.all(color: AppColors.primary.withOpacity(0.4))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : Colors.grey[700])),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step.title,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? AppColors.primary : AppColors.onBackground),
                          overflow: TextOverflow.ellipsis),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 14, color: Colors.grey[400]),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'rename') _renameStep(i);
                        if (v == 'delete') _deleteStep(i);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(isAr ? 'تعديل الاسم' : 'Rename')),
                        if (widget.form.steps.length > 1)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(isAr ? 'حذف' : 'Delete',
                                style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 16),

          // Palette toggle
          InkWell(
            onTap: () => setState(() => _showPalette = !_showPalette),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: [
                  Text(isAr ? 'الحقول' : 'Fields',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary)),
                  const Spacer(),
                  Icon(_showPalette ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          if (_showPalette)
            Expanded(
              child: _FieldPalette(
                form: widget.form,
                activeStepIndex: widget.activeStepIndex,
                onFormChanged: widget.onFormChanged,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Field Palette ─────────────────────────────────────────

class _FieldPalette extends StatelessWidget {
  final CcForm form;
  final int activeStepIndex;
  final VoidCallback onFormChanged;

  const _FieldPalette({
    required this.form,
    required this.activeStepIndex,
    required this.onFormChanged,
  });

  static const _groups = [
    {
      'label': 'Text',
      'labelAr': 'نصوص',
      'types': [CcFieldType.shortText, CcFieldType.longText, CcFieldType.phone],
    },
    {
      'label': 'Choice',
      'labelAr': 'اختيار',
      'types': [
        CcFieldType.singleSelect, CcFieldType.multiSelect,
        CcFieldType.checkboxGroup, CcFieldType.radio, CcFieldType.yesNo,
        CcFieldType.imageChoice, CcFieldType.styledSelect,
      ],
    },
    {
      'label': 'Scale',
      'labelAr': 'مقياس',
      'types': [CcFieldType.rating, CcFieldType.slider, CcFieldType.ranking],
    },
    {
      'label': 'Date & Time',
      'labelAr': 'تاريخ ووقت',
      'types': [CcFieldType.datePicker, CcFieldType.timePicker, CcFieldType.dateTimePicker],
    },
    {
      'label': 'Media',
      'labelAr': 'وسائط',
      'types': [CcFieldType.attachment, CcFieldType.imageAttachment, CcFieldType.signature],
    },
    {
      'label': 'Layout',
      'labelAr': 'تنسيق',
      'types': [CcFieldType.heading, CcFieldType.divider],
    },
  ];

  Future<void> _addField(BuildContext context, CcFieldType type) async {
    if (form.steps.isEmpty) return;
    final step = form.steps[activeStepIndex];
    if (step.sections.isEmpty) return;
    final section = step.sections.last;
    final orderIndex = section.fields.length;
    try {
      final field = await CcService.addField(section.id, type, orderIndex);
      section.fields.add(field);
      onFormChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: _groups.map((group) {
        final types = group['types'] as List<CcFieldType>;
        final label = isAr ? group['labelAr'] as String : group['label'] as String;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.grey[500], letterSpacing: 0.5)),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: types.map((type) {
                return _PaletteChip(
                  type: type,
                  isAr: isAr,
                  onTap: () => _addField(context, type),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final CcFieldType type;
  final bool isAr;
  final VoidCallback onTap;

  const _PaletteChip({required this.type, required this.isAr, required this.onTap});

  static IconData _iconFor(CcFieldType t) {
    switch (t) {
      case CcFieldType.shortText: return Icons.short_text_rounded;
      case CcFieldType.longText: return Icons.notes_rounded;
      case CcFieldType.attachment: return Icons.attach_file_rounded;
      case CcFieldType.imageAttachment: return Icons.add_photo_alternate_outlined;
      case CcFieldType.singleSelect: return Icons.arrow_drop_down_circle_outlined;
      case CcFieldType.multiSelect: return Icons.checklist_rounded;
      case CcFieldType.checkboxGroup: return Icons.check_box_outlined;
      case CcFieldType.radio: return Icons.radio_button_checked_rounded;
      case CcFieldType.ranking: return Icons.sort_rounded;
      case CcFieldType.rating: return Icons.star_outline_rounded;
      case CcFieldType.slider: return Icons.tune_rounded;
      case CcFieldType.datePicker: return Icons.calendar_today_rounded;
      case CcFieldType.timePicker: return Icons.access_time_rounded;
      case CcFieldType.dateTimePicker: return Icons.event_rounded;
      case CcFieldType.yesNo: return Icons.toggle_on_outlined;
      case CcFieldType.phone: return Icons.phone_outlined;
      case CcFieldType.imageChoice: return Icons.image_outlined;
      case CcFieldType.heading: return Icons.title_rounded;
      case CcFieldType.divider: return Icons.horizontal_rule_rounded;
      case CcFieldType.signature: return Icons.draw_outlined;
      case CcFieldType.styledSelect: return Icons.label_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(type), size: 12, color: AppColors.secondary),
            const SizedBox(width: 4),
            Text(
              isAr ? type.displayNameAr : type.displayName,
              style: const TextStyle(fontSize: 10, color: AppColors.onBackground),
            ),
          ],
        ),
      ),
    );

    return Draggable<CcFieldType>(
      data: type,
      feedback: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(type), size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                isAr ? type.displayNameAr : type.displayName,
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}

// ── Canvas ────────────────────────────────────────────────

class _Canvas extends StatefulWidget {
  final CcForm form;
  final CcFormField? selectedField;
  final ValueChanged<CcFormField> onFieldSelected;
  final VoidCallback onFormChanged;

  const _Canvas({
    required this.form,
    required this.selectedField,
    required this.onFieldSelected,
    required this.onFormChanged,
  });

  @override
  State<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<_Canvas> {
  Future<void> _addSection(CcFormStep step) async {
    final idx = step.sections.length;
    try {
      final sec = await CcService.addSection(step.id, idx, '');
      step.sections.add(sec);
      widget.onFormChanged();
    } catch (_) {}
  }

  Future<void> _deleteSection(CcFormStep step, CcFormSection section) async {
    await CcService.deleteSection(section.id);
    step.sections.remove(section);
    widget.onFormChanged();
  }

  Future<void> _deleteField(CcFormSection section, CcFormField field) async {
    await CcService.deleteField(field.id);
    section.fields.remove(field);
    widget.onFormChanged();
  }

  Future<void> _insertFromPalette(
      CcFormSection section, CcFieldType type, int position, [int? targetWidth]) async {
    try {
      final field = await CcService.addField(section.id, type, position);
      section.fields.insert(position.clamp(0, section.fields.length), field);
      if (targetWidth != null) {
        field.config.desktopColWidth = targetWidth.clamp(field.fieldType.minDesktopCols, 16);
        CcService.updateField(field.id, {'config': field.config.toJson()});
      }
      widget.onFormChanged();
    } catch (_) {}
  }

  void _changeFieldWidth(CcFormSection section, CcFormField field, int newColWidth) {
    field.config.desktopColWidth = newColWidth.clamp(field.fieldType.minDesktopCols, 16);
    widget.onFormChanged();
    CcService.updateField(field.id, {'config': field.config.toJson()});
  }

  void _changeFieldHeight(CcFormField field) {
    widget.onFormChanged();
    CcService.updateField(field.id, {'config': field.config.toJson()});
  }

  // Move a field from one section/step to another (or reorder within same section).
  // targetWidth: if provided, snaps the field's desktopColWidth to that value (used
  //   when dropping into a partial row via _RowEndDropZone).
  Future<void> _moveField(
      String fieldId, String srcSectionId, String tgtSectionId, int insertIdx,
      [int? targetWidth]) async {
    CcFormSection? srcSec;
    CcFormField? field;
    CcFormSection? tgtSec;

    for (final step in widget.form.steps) {
      for (final sec in step.sections) {
        if (sec.id == srcSectionId) {
          srcSec = sec;
          try { field = sec.fields.firstWhere((f) => f.id == fieldId); } catch (_) {}
        }
        if (sec.id == tgtSectionId) tgtSec = sec;
      }
    }
    if (srcSec == null || field == null || tgtSec == null) return;

    final fromIdx = srcSec.fields.indexOf(field);
    srcSec.fields.removeAt(fromIdx);

    var targetIdx = insertIdx.clamp(0, tgtSec.fields.length);
    // When reordering within the same section, removal shifts later indices down.
    if (srcSectionId == tgtSectionId && fromIdx < insertIdx) {
      targetIdx = (targetIdx - 1).clamp(0, tgtSec.fields.length);
    }
    tgtSec.fields.insert(targetIdx, field);

    if (targetWidth != null) {
      field.config.desktopColWidth = targetWidth.clamp(field.fieldType.minDesktopCols, 16);
    }

    widget.onFormChanged();

    if (srcSectionId != tgtSectionId) {
      await CcService.updateField(fieldId, {'section_id': tgtSectionId});
    }
    await CcService.reorderFields(srcSec.fields);
    if (srcSectionId != tgtSectionId) {
      await CcService.reorderFields(tgtSec.fields);
    }
    if (targetWidth != null) {
      await CcService.updateField(fieldId, {'config': field.config.toJson()});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.form.steps.isEmpty) {
      return const Center(child: Text('No steps'));
    }

    return Container(
      color: const Color(0xFFF5F6FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...widget.form.steps.asMap().entries.map((stepEntry) {
                  final stepIdx = stepEntry.key;
                  final step = stepEntry.value;
                  return _StepBlock(
                    step: step,
                    stepIndex: stepIdx,
                    totalSteps: widget.form.steps.length,
                    selectedField: widget.selectedField,
                    onFieldSelected: widget.onFieldSelected,
                    onMoveField: _moveField,
                    onFieldDeleted: _deleteField,
                    onInsertFromPalette: _insertFromPalette,
                    onWidthChanged: _changeFieldWidth,
                    onHeightChanged: _changeFieldHeight,
                    onAddSection: () => _addSection(step),
                    onDeleteSection: (sec) => _deleteSection(step, sec),
                    onSectionTitleChanged: (sec, title) async {
                      sec.title = title;
                      await CcService.updateSection(sec.id, {'title': title});
                    },
                  );
                }),
                const SizedBox(height: 60),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step Block: one step's header + sections ───────────────

class _StepBlock extends StatelessWidget {
  final CcFormStep step;
  final int stepIndex;
  final int totalSteps;
  final CcFormField? selectedField;
  final ValueChanged<CcFormField> onFieldSelected;
  final Future<void> Function(String fieldId, String srcSecId, String tgtSecId, int insertIdx, [int?]) onMoveField;
  final Future<void> Function(CcFormSection, CcFormField) onFieldDeleted;
  final Future<void> Function(CcFormSection, CcFieldType, int, [int?]) onInsertFromPalette;
  final void Function(CcFormSection, CcFormField, int) onWidthChanged;
  final void Function(CcFormField) onHeightChanged;
  final VoidCallback onAddSection;
  final Future<void> Function(CcFormSection) onDeleteSection;
  final Future<void> Function(CcFormSection, String) onSectionTitleChanged;

  const _StepBlock({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.selectedField,
    required this.onFieldSelected,
    required this.onMoveField,
    required this.onFieldDeleted,
    required this.onInsertFromPalette,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onAddSection,
    required this.onDeleteSection,
    required this.onSectionTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step header
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Text(
                  '${stepIndex + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        // Sections
        ...step.sections.map((section) => _SectionWidget(
          section: section,
          selectedField: selectedField,
          onFieldSelected: onFieldSelected,
          onFieldDeleted: (f) => onFieldDeleted(section, f),
          onMoveField: (fieldId, srcSecId, tgtSecId, insertIdx, [w]) =>
              onMoveField(fieldId, srcSecId, tgtSecId, insertIdx, w),
          onSectionTitleChanged: (title) => onSectionTitleChanged(section, title),
          onDeleteSection: step.sections.length > 1 ? () => onDeleteSection(section) : null,
          onDropFromPalette: (type, pos, [w]) => onInsertFromPalette(section, type, pos, w),
          onWidthChanged: (field, newW) => onWidthChanged(section, field, newW),
          onHeightChanged: (field) => onHeightChanged(field),
        )),
        // Add Section button
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: OutlinedButton.icon(
            onPressed: onAddSection,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(isAr ? 'إضافة قسم' : 'Add Section'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Spacing / divider between steps
        if (stepIndex < totalSteps - 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    isAr ? 'الخطوة التالية' : 'Next Step',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionWidget extends StatefulWidget {
  final CcFormSection section;
  final CcFormField? selectedField;
  final ValueChanged<CcFormField> onFieldSelected;
  final ValueChanged<CcFormField> onFieldDeleted;
  final Future<void> Function(String fieldId, String srcSecId, String tgtSecId, int insertIdx, [int?]) onMoveField;
  final ValueChanged<String> onSectionTitleChanged;
  final VoidCallback? onDeleteSection;
  final Future<void> Function(CcFieldType, int, [int?])? onDropFromPalette;
  final void Function(CcFormField, int)? onWidthChanged;
  final void Function(CcFormField)? onHeightChanged;

  const _SectionWidget({
    required this.section,
    required this.selectedField,
    required this.onFieldSelected,
    required this.onFieldDeleted,
    required this.onMoveField,
    required this.onSectionTitleChanged,
    this.onDeleteSection,
    this.onDropFromPalette,
    this.onWidthChanged,
    this.onHeightChanged,
  });

  @override
  State<_SectionWidget> createState() => _SectionWidgetState();
}

class _SectionWidgetState extends State<_SectionWidget> {
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section.title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final fields = widget.section.fields;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      hintText: isAr ? 'اسم القسم (اختياري)' : 'Section title (optional)',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                    onChanged: widget.onSectionTitleChanged,
                  ),
                ),
                if (widget.onDeleteSection != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: Colors.red[300],
                    onPressed: widget.onDeleteSection,
                    tooltip: isAr ? 'حذف القسم' : 'Delete section',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FieldGrid(
                fields: fields,
                sectionId: widget.section.id,
                selectedField: widget.selectedField,
                onFieldSelected: widget.onFieldSelected,
                onFieldDeleted: widget.onFieldDeleted,
                onMoveField: (fieldId, srcSecId, insertIdx, [w]) =>
                    widget.onMoveField(fieldId, srcSecId, widget.section.id, insertIdx, w),
                onDropFromPalette: widget.onDropFromPalette,
                onWidthChanged: widget.onWidthChanged,
                onHeightChanged: widget.onHeightChanged,
              ),
            ] else
              DragTarget<Object>(
                onWillAcceptWithDetails: (d) => d.data is CcFieldType || d.data is _FieldDragData,
                onAcceptWithDetails: (d) {
                  if (d.data is CcFieldType) {
                    widget.onDropFromPalette?.call(d.data as CcFieldType, 0);
                  } else if (d.data is _FieldDragData) {
                    final drag = d.data as _FieldDragData;
                    widget.onMoveField(drag.fieldId, drag.sectionId, widget.section.id, 0);
                  }
                },
                builder: (ctx, candidates, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: candidates.isNotEmpty
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            style: BorderStyle.solid)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      isAr
                          ? 'اسحب حقلاً من القائمة أو انقر لإضافته'
                          : 'Drag a field here or click palette to add',
                      style: TextStyle(
                        color: candidates.isNotEmpty
                            ? AppColors.primary
                            : Colors.grey[400],
                        fontSize: 13,
                      ),
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

// Payload for dragging a field card between sections/steps.
class _FieldDragData {
  final String fieldId;
  final String sectionId;
  const _FieldDragData({required this.fieldId, required this.sectionId});
}

class _FieldGrid extends StatelessWidget {
  final List<CcFormField> fields;
  final String sectionId;
  final CcFormField? selectedField;
  final ValueChanged<CcFormField> onFieldSelected;
  final ValueChanged<CcFormField> onFieldDeleted;
  final void Function(String fieldId, String srcSectionId, int insertIdx, [int?]) onMoveField;
  final Future<void> Function(CcFieldType, int, [int?])? onDropFromPalette;
  final void Function(CcFormField, int)? onWidthChanged;
  final void Function(CcFormField)? onHeightChanged;

  const _FieldGrid({
    required this.fields,
    required this.sectionId,
    required this.selectedField,
    required this.onFieldSelected,
    required this.onFieldDeleted,
    required this.onMoveField,
    this.onDropFromPalette,
    this.onWidthChanged,
    this.onHeightChanged,
  });

  // Group the flat field list into 16-column rows.
  List<List<int>> _groupIntoRows() {
    final rows = <List<int>>[];
    var row = <int>[];
    var units = 0;
    for (var i = 0; i < fields.length; i++) {
      final w = fields[i].config.desktopColWidth.clamp(fields[i].fieldType.minDesktopCols, 16);
      if (units + w > 16 && row.isNotEmpty) {
        rows.add(List.of(row));
        row = [i];
        units = w;
      } else {
        row.add(i);
        units += w;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget _buildCard(int idx, double containerWidth) {
    final field = fields[idx];
    final colW = field.config.desktopColWidth.clamp(field.fieldType.minDesktopCols, 16);
    return _FieldCard(
      key: ValueKey(field.id),
      field: field,
      sectionId: sectionId,
      index: idx,
      selected: selectedField?.id == field.id,
      colWidth: colW,
      containerWidth: containerWidth,
      onTap: () => onFieldSelected(field),
      onDelete: () => onFieldDeleted(field),
      onWidthChanged: onWidthChanged != null
          ? (delta) => onWidthChanged!(field, (colW + delta).clamp(field.fieldType.minDesktopCols, 16))
          : null,
      onHeightChanged: onHeightChanged != null ? () => onHeightChanged!(field) : null,
    );
  }

  int _rowUsedCols(List<int> rowIndices) => rowIndices.fold(
      0, (s, i) => s + fields[i].config.desktopColWidth.clamp(fields[i].fieldType.minDesktopCols, 16));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final containerWidth = constraints.maxWidth;
      final rows = _groupIntoRows();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DropZone(
            insertIndex: 0,
            onDropFromPalette: onDropFromPalette,
            onMoveField: (fId, secId, [w]) => onMoveField(fId, secId, 0, w),
          ),
          for (final rowIndices in rows) ...[
            Builder(builder: (_) {
              final usedCols = _rowUsedCols(rowIndices);
              final remainingCols = 16 - usedCols;

              // Single full-width field — keep original fixed-width behaviour
              if (rowIndices.length == 1 && remainingCols == 0) {
                final w = fields[rowIndices[0]].config.desktopColWidth
                    .clamp(fields[rowIndices[0]].fieldType.minDesktopCols, 16);
                return SizedBox(
                  width: containerWidth * w / 16,
                  child: _buildCard(rowIndices[0], containerWidth),
                );
              }

              // Build flex children (Expanded absorbs the 6px gaps so no overflow)
              final rowChildren = <Widget>[];
              if (rowIndices.length == 1) {
                final w = fields[rowIndices[0]].config.desktopColWidth
                    .clamp(fields[rowIndices[0]].fieldType.minDesktopCols, 16);
                rowChildren.add(Expanded(
                  flex: w,
                  child: _buildCard(rowIndices[0], containerWidth),
                ));
              } else {
                for (var pos = 0; pos < rowIndices.length; pos++) {
                  if (pos > 0) rowChildren.add(const SizedBox(width: 6));
                  rowChildren.add(Expanded(
                    flex: fields[rowIndices[pos]].config.desktopColWidth
                        .clamp(fields[rowIndices[pos]].fieldType.minDesktopCols, 16),
                    child: _buildCard(rowIndices[pos], containerWidth),
                  ));
                }
              }

              if (remainingCols > 0) {
                rowChildren.add(const SizedBox(width: 6));
                rowChildren.add(Expanded(
                  flex: remainingCols,
                  child: _RowEndDropZone(
                    insertIndex: rowIndices.last + 1,
                    remainingCols: remainingCols,
                    onDropFromPalette: onDropFromPalette,
                    onMoveField: (fId, secId, [w]) => onMoveField(fId, secId, rowIndices.last + 1, w),
                  ),
                ));
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rowChildren,
              );
            }),
            _DropZone(
              insertIndex: rowIndices.last + 1,
              onDropFromPalette: onDropFromPalette,
              onMoveField: (fId, secId, [w]) => onMoveField(fId, secId, rowIndices.last + 1, w),
            ),
          ],
        ],
      );
    });
  }
}

class _DropZone extends StatelessWidget {
  final int insertIndex;
  final Future<void> Function(CcFieldType, int, [int?])? onDropFromPalette;
  final void Function(String fieldId, String srcSectionId, [int?]) onMoveField;

  const _DropZone({required this.insertIndex, required this.onDropFromPalette, required this.onMoveField});

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is CcFieldType || d.data is _FieldDragData,
      onAcceptWithDetails: (d) {
        if (d.data is CcFieldType) {
          onDropFromPalette?.call(d.data as CcFieldType, insertIndex);
        } else if (d.data is _FieldDragData) {
          final drag = d.data as _FieldDragData;
          onMoveField(drag.fieldId, drag.sectionId);
        }
      },
      builder: (ctx, candidates, _) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 44 : 10,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
          ),
          child: active
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Drop here', style: TextStyle(fontSize: 11, color: AppColors.primary.withValues(alpha: 0.8))),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _RowEndDropZone extends StatelessWidget {
  final int insertIndex;
  final int remainingCols;
  final Future<void> Function(CcFieldType, int, [int?])? onDropFromPalette;
  final void Function(String fieldId, String srcSectionId, [int?]) onMoveField;

  const _RowEndDropZone({
    required this.insertIndex,
    required this.remainingCols,
    required this.onDropFromPalette,
    required this.onMoveField,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is CcFieldType || d.data is _FieldDragData,
      onAcceptWithDetails: (d) {
        if (d.data is CcFieldType) {
          onDropFromPalette?.call(d.data as CcFieldType, insertIndex, remainingCols);
        } else if (d.data is _FieldDragData) {
          final drag = d.data as _FieldDragData;
          onMoveField(drag.fieldId, drag.sectionId, remainingCols);
        }
      },
      builder: (ctx, candidates, _) {
        final active = candidates.isNotEmpty;
        // Width comes from Expanded in the parent Row — no explicit width here
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: active ? 72 : 52,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: active ? 18 : 14,
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.8)
                      : Colors.grey.withValues(alpha: 0.4),
                ),
                if (active) ...[
                  const SizedBox(height: 3),
                  Text(
                    isAr ? '$remainingCols عمود' : '$remainingCols cols',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FieldCard extends StatefulWidget {
  final CcFormField field;
  final String sectionId;
  final int index;
  final bool selected;
  final int colWidth;
  final double containerWidth;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(int delta)? onWidthChanged;
  final VoidCallback? onHeightChanged;

  const _FieldCard({
    super.key,
    required this.field,
    required this.sectionId,
    required this.index,
    required this.selected,
    required this.colWidth,
    required this.containerWidth,
    required this.onTap,
    required this.onDelete,
    this.onWidthChanged,
    this.onHeightChanged,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  double _wAcc = 0;
  double _hAcc = 0;
  bool _isDragging = false;
  bool _isResizingW = false;

  bool get _canResizeH {
    final t = widget.field.fieldType;
    return t == CcFieldType.longText || t == CcFieldType.attachment ||
        t == CcFieldType.imageAttachment || t == CcFieldType.signature;
  }

  void _handleWidthDrag(DragUpdateDetails d, {bool negate = false}) {
    _wAcc += negate ? -d.delta.dx : d.delta.dx;
    final colPx = widget.containerWidth / 16;
    final delta = (_wAcc / colPx).round();
    if (delta != 0) {
      widget.onWidthChanged?.call(delta);
      _wAcc -= delta * colPx;
    }
  }

  void _handleHeightDrag(DragUpdateDetails d) {
    if (!_canResizeH) return;
    _hAcc += d.delta.dy;
    const rowPx = 20.0;
    final delta = (_hAcc / rowPx).round();
    if (delta != 0) {
      final c = widget.field.config;
      final newMin = (c.minRows + delta).clamp(1, 20);
      c.minRows = newMin;
      // maxRows must always be >= minRows so the submission form renders correctly.
      c.maxRows = c.maxRows.clamp(newMin, 20);
      _hAcc -= delta * rowPx;
      setState(() {});
      widget.onHeightChanged?.call();
    }
  }

  // A pill-shaped resize handle tab
  Widget _pillHandle({
    required double? left,
    required double? right,
    required double? top,
    required double? bottom,
    required double width,
    required double height,
    required MouseCursor cursor,
    required VoidCallback onStart,
    required GestureDragUpdateCallback onUpdate,
    VoidCallback? onEnd,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onStart(),
          onPanUpdate: onUpdate,
          onPanEnd: onEnd != null ? (_) => onEnd() : null,
          child: Center(
            child: Container(
              width: width * 0.5,
              height: height * 0.5,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, spreadRadius: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Flat visual used as Draggable feedback — contains NO Draggable to avoid recursion.
  Widget _buildDragFeedback(bool isAr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 4),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.field.label.isEmpty
                      ? (isAr ? widget.field.fieldType.displayNameAr : widget.field.fieldType.displayName)
                      : widget.field.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          CcFieldPreview(field: widget.field),
        ],
      ),
    );
  }

  Widget _buildCardVisual(BuildContext context, bool isAr, {bool dimmed = false}) {
    final showHandles = widget.selected && widget.onWidthChanged != null && !dimmed;
    return AnimatedOpacity(
      opacity: dimmed ? 0.28 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10, right: 4),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: widget.selected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.selected ? AppColors.primary : Colors.grey[200]!,
            width: widget.selected ? 1.5 : 1,
          ),
          boxShadow: widget.selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.10), blurRadius: 8, spreadRadius: 0)]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // ── Drag handle (only this part starts a drag) ──
                    Draggable<_FieldDragData>(
                      data: _FieldDragData(fieldId: widget.field.id, sectionId: widget.sectionId),
                      onDragStarted: () => setState(() => _isDragging = true),
                      onDragEnd: (_) => setState(() => _isDragging = false),
                      onDraggableCanceled: (_, __) => setState(() => _isDragging = false),
                      // LTR: handle on LEFT  → small negative offset keeps cursor near left edge.
                      // RTL: handle on RIGHT → positive offset = (cardWidth - handleArea) to align cursor with right handle.
                      feedbackOffset: isAr
                          ? Offset(widget.containerWidth * widget.colWidth / 16 - 20, -10)
                          : const Offset(-10, -10),
                      feedback: Directionality(
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: widget.containerWidth * widget.colWidth / 16 - 4,
                            child: _buildDragFeedback(isAr),
                          ),
                        ),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.field.label.isEmpty
                            ? (isAr ? widget.field.fieldType.displayNameAr : widget.field.fieldType.displayName)
                            : widget.field.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.selected ? AppColors.primary : AppColors.onBackground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.field.config.required)
                      const Text(' *', style: TextStyle(color: Colors.red, fontSize: 11)),
                    // Width badge during resize
                    if (_isResizingW)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.colWidth}/16',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                CcFieldPreview(field: widget.field),
              ],
            ),
            // ── Resize handles ──
            if (showHandles) ...[
              // Right edge → width
              _pillHandle(
                right: -8, top: null, bottom: null, left: null,
                width: 16, height: 36,
                cursor: SystemMouseCursors.resizeLeftRight,
                onStart: () { _wAcc = 0; setState(() => _isResizingW = true); },
                onUpdate: (d) { _handleWidthDrag(d); setState(() {}); },
                onEnd: () => setState(() => _isResizingW = false),
              ),
              // Left edge → width (shrink)
              _pillHandle(
                left: -8, top: null, bottom: null, right: null,
                width: 16, height: 36,
                cursor: SystemMouseCursors.resizeLeftRight,
                onStart: () { _wAcc = 0; setState(() => _isResizingW = true); },
                onUpdate: (d) { _handleWidthDrag(d, negate: true); setState(() {}); },
                onEnd: () => setState(() => _isResizingW = false),
              ),
              // Bottom edge → height (only for resizable types)
              if (_canResizeH)
                _pillHandle(
                  bottom: -8, left: null, right: null, top: null,
                  width: 40, height: 16,
                  cursor: SystemMouseCursors.resizeUpDown,
                  onStart: () => _hAcc = 0,
                  onUpdate: _handleHeightDrag,
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // Sizing is provided by the parent _FieldGrid (SizedBox or Expanded).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: _buildCardVisual(context, isAr, dimmed: _isDragging),
        ),
        if (widget.selected)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        isAr ? 'حذف' : 'Delete',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Right Panel: Properties ───────────────────────────────

class _RightPanel extends StatelessWidget {
  final CcForm form;
  final CcFormField? selectedField;
  final VoidCallback onChanged;
  final VoidCallback onDeselect;

  const _RightPanel({
    required this.form,
    required this.selectedField,
    required this.onChanged,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.white,
      child: selectedField != null
          ? CcFieldPropertiesPanel(
              field: selectedField!,
              allFields: form.steps
                  .expand((s) => s.sections.expand((sec) => sec.fields))
                  .toList(),
              allSteps: form.steps,
              onChanged: onChanged,
              onDeselect: onDeselect,
            )
          : const _EmptyPropertiesHint(),
    );
  }
}

class _EmptyPropertiesHint extends StatelessWidget {
  const _EmptyPropertiesHint();

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            isAr ? 'انقر على حقل لتعديل خصائصه' : 'Click a field to edit its properties',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Settings Tab ──────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final CcForm form;
  final VoidCallback onChanged;
  final UserModel currentUser;

  const _SettingsTab({
    required this.form,
    required this.onChanged,
    required this.currentUser,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _uploadingLogo = false;
  bool _qrExporting = false;
  final _qrKey = GlobalKey();
  late TextEditingController _customMsgCtrl;

  @override
  void initState() {
    super.initState();
    _customMsgCtrl = TextEditingController(
        text: widget.form.notifyCustomMessage ?? '');
  }

  @override
  void dispose() {
    _customMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddEmailDialog(bool isAr) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'إضافة بريد إلكتروني' : 'Add email'),
        content: TextFormField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'example@domain.com',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = ctrl.text.trim();
              if (email.contains('@') && email.contains('.')) {
                Navigator.pop(ctx, email);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && mounted) {
      setState(() {
        if (!widget.form.notifyAdditionalEmails.contains(result)) {
          widget.form.notifyAdditionalEmails.add(result);
          widget.onChanged();
        }
      });
    }
  }

  Future<void> _pickLogo(bool isAr) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await CcService.uploadFormLogo(widget.form.id, file.bytes!, file.name);
      widget.form.logoUrl = url;
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'فشل رفع الشعار' : 'Logo upload failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _exportQr(bool isAr) async {
    setState(() => _qrExporting = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      if (kIsWeb) {
        final b64 = base64Encode(bytes);
        downloadFileWeb('data:image/png;base64,$b64', 'qr_code.png');
      } else {
        await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: 'qr_code.png', mimeType: 'image/png')]));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تعذر تصدير رمز QR' : 'Could not export QR code')),
        );
      }
    } finally {
      if (mounted) setState(() => _qrExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    const themeColors = [
      ('#f16936', Color(0xFFf16936)),
      ('#135467', Color(0xFF135467)),
      ('#1E40AF', Color(0xFF1E40AF)),
      ('#16A34A', Color(0xFF16A34A)),
      ('#DC2626', Color(0xFFDC2626)),
      ('#7C3AED', Color(0xFF7C3AED)),
      ('#0891B2', Color(0xFF0891B2)),
      ('#D97706', Color(0xFFD97706)),
      ('#374151', Color(0xFF374151)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Branding ──────────────────────────────────────
            _SectionHeader(
              title: isAr ? 'العلامة التجارية' : 'Branding',
              icon: Icons.palette_outlined,
              color: const Color(0xFFf16936),
            ),
            const SizedBox(height: 14),
            _SettingCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo row
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: widget.form.logoUrl != null && widget.form.logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    widget.form.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                                  ),
                                )
                              : Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'شعار النموذج' : 'Form Logo',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAr ? 'يظهر في رأس النموذج ومركز رمز QR' : 'Appears in form header and QR code center',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _uploadingLogo ? null : () => _pickLogo(isAr),
                                icon: _uploadingLogo
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.upload_rounded, size: 15),
                                label: Text(
                                  widget.form.logoUrl != null ? (isAr ? 'تغيير الشعار' : 'Change Logo') : (isAr ? 'رفع شعار' : 'Upload Logo'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.secondary,
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // Theme color
                    Row(
                      children: [
                        const Icon(Icons.color_lens_outlined, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text(
                          isAr ? 'لون النموذج' : 'Theme Color',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: themeColors.map(((String, Color) c) {
                        final isSelected = widget.form.themeColor == c.$1;
                        return GestureDetector(
                          onTap: () { widget.form.themeColor = c.$1; widget.onChanged(); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.$2,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.$2.withValues(alpha: 0.55), blurRadius: 8, spreadRadius: 1)]
                                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3)],
                            ),
                            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 17) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            // ── Form Behavior ─────────────────────────────────
            _SectionHeader(
              title: isAr ? 'سلوك النموذج' : 'Form Behavior',
              icon: Icons.tune_rounded,
              color: const Color(0xFF1E40AF),
            ),
            const SizedBox(height: 14),

            _SettingCard(
              child: Column(
                children: [
                  // Identity mode
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(width: 10),
                        Text(isAr ? 'نمط التقديم' : 'Submission Identity',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                  ...CcIdentityMode.values.map((mode) {
                    final labels = {
                      CcIdentityMode.identified: isAr ? 'مُعرَّف — الاسم يظهر للمسؤول' : 'Identified — name visible to admin',
                      CcIdentityMode.anonymous: isAr ? 'مجهول — الاسم مخفي' : 'Anonymous — name hidden',
                      CcIdentityMode.choice: isAr ? 'اختيار المقدِّم' : "Applicant's choice",
                    };
                    return RadioListTile<CcIdentityMode>(
                      dense: true,
                      value: mode,
                      groupValue: widget.form.identityMode,
                      activeColor: AppColors.primary,
                      title: Text(labels[mode]!, style: const TextStyle(fontSize: 12.5)),
                      onChanged: (v) {
                        if (v != null) { widget.form.identityMode = v; widget.onChanged(); }
                      },
                    );
                  }),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Back button toggle
                  SwitchListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    secondary: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF1E40AF)),
                    ),
                    title: Text(isAr ? 'زر الرجوع بين الخطوات' : 'Back button between steps',
                        style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                      isAr ? 'يتيح للمقدِّم التنقل للخلف في النموذج متعدد الخطوات' : 'Lets applicants go back in multi-step forms',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    value: widget.form.allowBack,
                    onChanged: (v) { widget.form.allowBack = v; widget.onChanged(); },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Progress bar style
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.linear_scale_rounded, size: 16, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(width: 10),
                        Text(isAr ? 'شريط التقدم' : 'Progress Bar',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: CcProgressStyle.values.map((style) {
                        final labels = {
                          CcProgressStyle.numbered: isAr ? 'أرقام' : 'Numbered',
                          CcProgressStyle.percentage: isAr ? 'نسبة %' : 'Percentage',
                          CcProgressStyle.dotted: isAr ? 'نقاط' : 'Dots',
                        };
                        final selected = widget.form.progressStyle == style;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () { widget.form.progressStyle = style; widget.onChanged(); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFF1E40AF) : const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                labels[style]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            // ── External Access ───────────────────────────────
            _SectionHeader(
              title: isAr ? 'الوصول الخارجي' : 'External Access',
              icon: Icons.public_rounded,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 14),

            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    secondary: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF16A34A)),
                    ),
                    title: Text(isAr ? 'تفعيل رابط خارجي' : 'Enable external link',
                        style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                      isAr ? 'يتيح التقديم بدون حساب مسجل' : 'Allows submission without an account',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    value: widget.form.externalApplyEnabled,
                    onChanged: (v) { widget.form.externalApplyEnabled = v; widget.onChanged(); },
                  ),
                  if (widget.form.externalApplyEnabled) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Builder(builder: (ctx) {
                      final path = '/c/submit/${widget.form.id}';
                      final fullUrl = kIsWeb ? '${Uri.base.origin}$path' : 'https://your-app.com$path';
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // URL row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 15, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      fullUrl,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontFamily: 'monospace'),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: fullUrl));
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text(isAr ? 'تم نسخ الرابط' : 'Link copied!'), duration: const Duration(seconds: 2)),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // QR code
                            Row(
                              children: [
                                const Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Text(isAr ? 'رمز QR للرابط' : 'QR Code',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Column(
                                children: [
                                  RepaintBoundary(
                                    key: _qrKey,
                                    child: Container(
                                      color: Colors.white,
                                      padding: const EdgeInsets.all(14),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // QR image — no embedded image; center is
                                          // covered by the white overlay below.
                                          // Error correction H tolerates ~30% occlusion.
                                          QrImageView(
                                            data: fullUrl,
                                            version: QrVersions.auto,
                                            size: 190.0,
                                            backgroundColor: Colors.white,
                                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A2E)),
                                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A2E)),
                                          ),
                                          // White square in the center with logo inside
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            padding: const EdgeInsets.all(5),
                                            child: widget.form.logoUrl != null && widget.form.logoUrl!.isNotEmpty
                                                ? Image.network(
                                                    widget.form.logoUrl!,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    isAr ? 'امسح الرمز للوصول إلى نموذج التقديم' : 'Scan to open the submission form',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _qrExporting ? null : () => _exportQr(isAr),
                                    icon: _qrExporting
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.download_rounded, size: 15),
                                    label: Text(isAr ? 'تحميل رمز QR' : 'Download QR', style: const TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF16A34A),
                                      side: const BorderSide(color: Color(0xFF16A34A)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),
            // ── Notifications ─────────────────────────────────
            _SectionHeader(
              title: isAr ? 'الإشعارات' : 'Notifications',
              icon: Icons.notifications_outlined,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 14),

            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Toggle ───────────────────────────────────
                  SwitchListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    secondary: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF7C3AED)),
                    ),
                    title: Text(
                      isAr ? 'تلقّي إشعار عند كل تقديم' : 'Notify me on each submission',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    subtitle: Text(
                      isAr ? 'إشعار داخل التطبيق وبريد إلكتروني' : 'In-app and email notification',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    value: widget.form.notifyCreatorOnSubmit,
                    onChanged: (v) { widget.form.notifyCreatorOnSubmit = v; widget.onChanged(); },
                  ),
                  // ── Primary email ─────────────────────────────
                  if (widget.form.notifyCreatorOnSubmit) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: TextFormField(
                        initialValue: widget.form.notifyEmail ?? '',
                        decoration: InputDecoration(
                          hintText: isAr ? 'البريد الإلكتروني للإشعارات' : 'Notification email address',
                          isDense: true,
                          prefixIcon: const Icon(Icons.email_outlined, size: 16),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
                        ),
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => widget.form.notifyEmail = v.trim().isEmpty ? null : v.trim(),
                      ),
                    ),
                  ],
                  // ── Additional recipients ─────────────────────
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'مستلمون إضافيون' : 'Additional email recipients',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                isAr ? 'إرسال الإشعار إلى عناوين إضافية' : 'Also notify these addresses',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...widget.form.notifyAdditionalEmails.map((email) => Chip(
                          label: Text(email, style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          onDeleted: () => setState(() {
                            widget.form.notifyAdditionalEmails.remove(email);
                            widget.onChanged();
                          }),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )),
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 14),
                          label: Text(isAr ? 'إضافة بريد' : 'Add email',
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () => _showAddEmailDialog(isAr),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  // ── Custom message ────────────────────────────
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.message_outlined, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'رسالة مخصصة' : 'Custom notification message',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                isAr
                                    ? 'رسالة مخصصة في الإشعارات بدلاً من الرسالة الافتراضية'
                                    : 'Message sent in notifications instead of the default message',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: TextFormField(
                      controller: _customMsgCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isAr ? 'اكتب رسالتك هنا...' : 'Type your message here...',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        widget.form.notifyCustomMessage = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            // ── Screens ───────────────────────────────────────
            _SectionHeader(
              title: isAr ? 'شاشات النموذج' : 'Form Screens',
              icon: Icons.view_carousel_outlined,
              color: const Color(0xFF0891B2),
            ),
            const SizedBox(height: 14),

            _SettingCard(
              child: Column(
                children: [
                  // Welcome screen
                  SwitchListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    secondary: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.waving_hand_outlined, size: 16, color: Color(0xFF0891B2)),
                    ),
                    title: Text(isAr ? 'شاشة الترحيب' : 'Welcome Screen', style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                      isAr ? 'تظهر قبل أول خطوة في النموذج' : 'Shown before the first step',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    value: widget.form.showOnboarding,
                    onChanged: (v) { widget.form.showOnboarding = v; widget.onChanged(); },
                  ),
                  if (widget.form.showOnboarding) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final config = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(builder: (_) => CcScreenDesigner(
                              title: isAr ? 'تصميم شاشة الترحيب' : 'Design Welcome Screen',
                              initialConfig: widget.form.onboardingConfig,
                              formId: widget.form.id,
                              screenType: CcScreenType.welcome,
                            )),
                          );
                          if (config != null) { widget.form.onboardingConfig = config; widget.onChanged(); }
                        },
                        icon: const Icon(Icons.design_services_rounded, size: 15),
                        label: Text(isAr ? 'تصميم الشاشة' : 'Design Screen', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0891B2),
                          side: const BorderSide(color: Color(0xFF0891B2)),
                          minimumSize: const Size.fromHeight(38),
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Closing screen
                  SwitchListTile(
                    dense: true,
                    activeColor: AppColors.primary,
                    secondary: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0891B2)),
                    ),
                    title: Text(isAr ? 'شاشة النهاية' : 'Closing Screen', style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                      isAr ? 'تظهر بعد إرسال النموذج بنجاح' : 'Shown after successful submission',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    value: widget.form.showClosing,
                    onChanged: (v) { widget.form.showClosing = v; widget.onChanged(); },
                  ),
                  if (widget.form.showClosing) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final config = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(builder: (_) => CcScreenDesigner(
                              title: isAr ? 'تصميم شاشة النهاية' : 'Design Closing Screen',
                              initialConfig: widget.form.closingConfig,
                              formId: widget.form.id,
                              screenType: CcScreenType.closing,
                            )),
                          );
                          if (config != null) { widget.form.closingConfig = config; widget.onChanged(); }
                        },
                        icon: const Icon(Icons.design_services_rounded, size: 15),
                        label: Text(isAr ? 'تصميم الشاشة' : 'Design Screen', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0891B2),
                          side: const BorderSide(color: Color(0xFF0891B2)),
                          minimumSize: const Size.fromHeight(38),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Shared layout helpers ─────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

// ── Preview wrapper ───────────────────────────────────────

class _FormPreviewWrapper extends StatelessWidget {
  final CcForm form;
  final UserModel currentUser;

  const _FormPreviewWrapper({required this.form, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Stack(
      children: [
        CcFormFillView(
          form: form,
          currentUserId: currentUser.id,
          currentUserFullName: currentUser.fullName,
          isPreview: true,
          onCompleted: () => Navigator.pop(context),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.preview_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr ? 'وضع المعاينة — لن يتم حفظ أي بيانات' : 'Preview mode — no data will be saved',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
