import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import 'cc_models.dart';
import 'cc_service.dart';

// ── Compact preview shown inside the builder canvas ───────

class CcFieldPreview extends StatelessWidget {
  final CcFormField field;
  const CcFieldPreview({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final c = field.config;
    switch (field.fieldType) {
      case CcFieldType.shortText:
        return _fakeInput(c.placeholder ?? 'Text input');
      case CcFieldType.longText:
        return _fakeBox(height: (16.0 * c.minRows).clamp(32.0, 320.0));
      case CcFieldType.attachment:
        return _fakeRow(Icons.upload_file_rounded, 'Upload file');
      case CcFieldType.imageAttachment:
        return _fakeRow(Icons.add_photo_alternate_outlined, 'Upload images');
      case CcFieldType.singleSelect:
        return _fakeRow(Icons.arrow_drop_down_rounded, c.options.isEmpty ? 'Select...' : c.options.first);
      case CcFieldType.multiSelect:
        return _chips(c.options);
      case CcFieldType.checkboxGroup:
        return _optionList(c.options, Icons.check_box_outline_blank_rounded);
      case CcFieldType.radio:
        return _optionList(c.options, Icons.radio_button_unchecked_rounded);
      case CcFieldType.ranking:
        return _optionList(c.options, Icons.drag_handle_rounded);
      case CcFieldType.rating:
        return Row(children: List.generate(c.ratingMax.clamp(1, 7),
            (i) => Icon(c.ratingStars ? Icons.star_border_rounded : Icons.circle_outlined,
                size: 16, color: Colors.amber[300])));
      case CcFieldType.slider:
        return Slider(value: 0.4, onChanged: null, activeColor: AppColors.primary.withOpacity(0.4));
      case CcFieldType.datePicker:
        return _fakeRow(Icons.calendar_today_rounded, 'YYYY-MM-DD');
      case CcFieldType.timePicker:
        return _fakeRow(Icons.access_time_rounded, '--:--');
      case CcFieldType.dateTimePicker:
        return _fakeRow(Icons.event_rounded, 'YYYY-MM-DD --:--');
      case CcFieldType.yesNo:
        return Row(children: [
          Switch(value: c.defaultYesNo, onChanged: null, activeColor: AppColors.primary),
        ]);
      case CcFieldType.phone:
        return _fakeRow(Icons.phone_outlined, '${c.defaultCountryCode} ...');
      case CcFieldType.imageChoice:
        return Row(children: List.generate(c.imageUrls.isEmpty ? 2 : c.imageUrls.length.clamp(0, 3),
            (i) => Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.image_outlined, size: 16, color: Colors.grey))));
      case CcFieldType.heading:
        return const Text('Heading text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
      case CcFieldType.divider:
        return Divider(color: Colors.grey[300]);
      case CcFieldType.signature:
        return _fakeBox(height: (16.0 * c.minRows).clamp(50.0, 320.0), icon: Icons.draw_outlined);
      case CcFieldType.styledSelect:
        if (c.styledSelectOptions.isEmpty) {
          return _fakeRow(Icons.label_rounded, 'Status option...');
        }
        final opt = c.styledSelectOptions.first;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: opt.bgColorValue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(opt.label,
              style: TextStyle(fontSize: 11, color: opt.textColorValue,
                  fontWeight: FontWeight.w600)),
        );
    }
  }

  Widget _fakeInput(String hint) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(6)),
        child: Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      );

  Widget _fakeBox({double height = 32, IconData? icon}) => Container(
        height: height,
        decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(6)),
        alignment: Alignment.center,
        child: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
      );

  Widget _fakeRow(IconData icon, String label) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ]),
      );

  Widget _chips(List<String> options) => Wrap(
        spacing: 4,
        children: (options.isEmpty ? ['Option 1', 'Option 2'] : options.take(3).toList())
            .map((o) => Chip(
                  label: Text(o, style: const TextStyle(fontSize: 10)),
                  backgroundColor: const Color(0xFFF0F1F5),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ))
            .toList(),
      );

  Widget _optionList(List<String> options, IconData icon) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: (options.isEmpty ? ['Option 1', 'Option 2'] : options.take(3).toList())
            .map((o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon(icon, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(o, style: const TextStyle(fontSize: 11)),
                  ]),
                ))
            .toList(),
      );
}

// ── Properties panel (right sidebar in builder) ───────────

class CcFieldPropertiesPanel extends StatefulWidget {
  final CcFormField field;
  final List<CcFormField> allFields;
  final List<CcFormStep> allSteps;
  final VoidCallback onChanged;
  final VoidCallback onDeselect;

  const CcFieldPropertiesPanel({
    super.key,
    required this.field,
    required this.allFields,
    required this.allSteps,
    required this.onChanged,
    required this.onDeselect,
  });

  @override
  State<CcFieldPropertiesPanel> createState() => _CcFieldPropertiesPanelState();
}

class _CcFieldPropertiesPanelState extends State<CcFieldPropertiesPanel> {
  late TextEditingController _labelCtrl;
  late TextEditingController _placeholderCtrl;
  late TextEditingController _helperCtrl;
  late TextEditingController _extCtrl;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _placeholderCtrl = TextEditingController(text: widget.field.config.placeholder ?? '');
    _helperCtrl = TextEditingController(text: widget.field.config.helperText ?? '');
    _extCtrl = TextEditingController(text: widget.field.config.allowedExtensions.join(', '));
  }

  @override
  void didUpdateWidget(covariant CcFieldPropertiesPanel old) {
    super.didUpdateWidget(old);
    if (old.field.id != widget.field.id) {
      _labelCtrl.text = widget.field.label;
      _placeholderCtrl.text = widget.field.config.placeholder ?? '';
      _helperCtrl.text = widget.field.config.helperText ?? '';
      _extCtrl.text = widget.field.config.allowedExtensions.join(', ');
    }
  }

  @override
  void dispose() {
    final hadPending = _saveTimer?.isActive ?? false;
    _saveTimer?.cancel();
    if (hadPending) _persistNow(); // flush any unsaved keystroke
    _labelCtrl.dispose();
    _placeholderCtrl.dispose();
    _helperCtrl.dispose();
    _extCtrl.dispose();
    super.dispose();
  }

  // Debounced: waits 600 ms after the last change before writing to DB.
  // Prevents concurrent saves when the user types quickly in a text field.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _persistNow);
  }

  Future<void> _persistNow() async {
    try {
      await CcService.updateField(widget.field.id, {
        'label': widget.field.label,
        'config': widget.field.config.toJson(),
      });
    } catch (e) {
      debugPrint('[BUILDER] save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'ar'
                ? 'فشل حفظ التغييرات'
                : 'Failed to save changes'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final field = widget.field;
    final c = field.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
          child: Row(
            children: [
              Expanded(
                child: Text(isAr ? field.fieldType.displayNameAr : field.fieldType.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: widget.onDeselect,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (!field.fieldType.isDisplayOnly || field.fieldType == CcFieldType.heading) ...[
                _label(isAr ? 'النص / العنوان' : 'Label'),
                TextField(
                  controller: _labelCtrl,
                  decoration: _dec(),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _update(() => field.label = v),
                ),
                const SizedBox(height: 10),
              ],

              if (!field.fieldType.isDisplayOnly) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(isAr ? 'مطلوب' : 'Required', style: const TextStyle(fontSize: 12)),
                  value: c.required,
                  onChanged: (v) => _update(() => c.required = v),
                ),
                const SizedBox(height: 6),
              ],

              if (field.fieldType == CcFieldType.shortText || field.fieldType == CcFieldType.longText) ...[
                _label(isAr ? 'نص توضيحي' : 'Placeholder'),
                TextField(
                  controller: _placeholderCtrl,
                  decoration: _dec(),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _update(() => c.placeholder = v),
                ),
                const SizedBox(height: 10),
              ],

              if (field.fieldType == CcFieldType.shortText) ...[
                _label(isAr ? 'النوع' : 'Subtype'),
                _segmented(
                  options: const ['text', 'number', 'percentage'],
                  labels: isAr ? const ['نص', 'رقم', 'نسبة'] : const ['Text', 'Number', '%'],
                  value: c.subtype,
                  onChanged: (v) => _update(() => c.subtype = v),
                ),
                const SizedBox(height: 10),
              ],

              if (field.fieldType == CcFieldType.longText) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(isAr ? 'تنسيق نص غني' : 'Rich text formatting', style: const TextStyle(fontSize: 12)),
                  value: c.richText,
                  onChanged: (v) => _update(() => c.richText = v),
                ),
                _label(isAr ? 'الحد الأدنى للصفوف' : 'Min rows'),
                _stepperRow(c.minRows, (v) => _update(() => c.minRows = v), min: 1, max: 20),
                _label(isAr ? 'الحد الأقصى للصفوف' : 'Max rows'),
                _stepperRow(c.maxRows, (v) => _update(() => c.maxRows = v), min: 1, max: 40),
              ],

              if (field.fieldType == CcFieldType.attachment ||
                  field.fieldType == CcFieldType.imageAttachment) ...[
                _label(isAr ? 'الحد الأقصى لعدد الملفات' : 'Max file count'),
                _stepperRow(c.maxFileCount, (v) => _update(() => c.maxFileCount = v), min: 1, max: 50),
                _label(isAr ? 'الحد الأقصى للحجم (MB)' : 'Max size (MB)'),
                _stepperRow(c.maxFileSizeMb.round(), (v) => _update(() => c.maxFileSizeMb = v.toDouble()), min: 1, max: 200),
                if (field.fieldType == CcFieldType.attachment) ...[
                  _label(isAr ? 'الامتدادات المسموحة (مفصولة بفاصلة)' : 'Allowed extensions (comma sep)'),
                  TextFormField(
                    controller: _extCtrl,
                    decoration: _dec(hint: 'jpg, png, pdf'),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => _update(() => c.allowedExtensions =
                        v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
                  ),
                ],
                const SizedBox(height: 10),
              ],

              if (field.fieldType == CcFieldType.styledSelect) ...[
                _label(isAr ? 'خيارات الحالة' : 'Status Options'),
                Text(
                  isAr
                      ? 'سيختار المستخدم من هذه الخيارات'
                      : 'User will pick from these options',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                _StyledOptionsEditor(
                  options: c.styledSelectOptions,
                  onChanged: (opts) => _update(() => c.styledSelectOptions = opts),
                ),
                const SizedBox(height: 10),
              ],

              if ([CcFieldType.singleSelect, CcFieldType.multiSelect, CcFieldType.checkboxGroup,
                   CcFieldType.radio, CcFieldType.ranking].contains(field.fieldType)) ...[
                _label(isAr ? 'الخيارات' : 'Options'),
                _OptionsEditor(
                  options: c.options,
                  onChanged: (opts) => _update(() => c.options = opts),
                ),
                if (field.fieldType == CcFieldType.multiSelect) ...[
                  const SizedBox(height: 8),
                  _label(isAr ? 'الحد الأدنى للاختيار' : 'Min selections'),
                  _stepperRow(c.minSelections ?? 0, (v) => _update(() => c.minSelections = v), min: 0, max: c.options.length),
                  _label(isAr ? 'الحد الأقصى للاختيار' : 'Max selections'),
                  _stepperRow(c.maxSelections ?? c.options.length, (v) => _update(() => c.maxSelections = v), min: 1, max: c.options.length.clamp(1, 999)),
                ],
              ],

              if (field.fieldType == CcFieldType.rating) ...[
                _label(isAr ? 'الحد الأقصى للتقييم' : 'Max rating'),
                _stepperRow(c.ratingMax, (v) => _update(() => c.ratingMax = v), min: 2, max: 10),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(isAr ? 'نجوم' : 'Use stars', style: const TextStyle(fontSize: 12)),
                  value: c.ratingStars,
                  onChanged: (v) => _update(() => c.ratingStars = v),
                ),
              ],

              if (field.fieldType == CcFieldType.slider) ...[
                _label(isAr ? 'الحد الأدنى' : 'Min'),
                _numField(c.sliderMin, (v) => _update(() => c.sliderMin = v)),
                _label(isAr ? 'الحد الأقصى' : 'Max'),
                _numField(c.sliderMax, (v) => _update(() => c.sliderMax = v)),
                _label(isAr ? 'الخطوة' : 'Step'),
                _numField(c.sliderStep, (v) => _update(() => c.sliderStep = v)),
                _label(isAr ? 'الوحدة' : 'Unit label'),
                TextFormField(
                  initialValue: c.sliderUnit,
                  decoration: _dec(),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _update(() => c.sliderUnit = v),
                ),
                const SizedBox(height: 10),
              ],

              if (field.fieldType == CcFieldType.phone) ...[
                _label(isAr ? 'رمز الدولة الافتراضي' : 'Default country code'),
                TextFormField(
                  initialValue: c.defaultCountryCode,
                  decoration: _dec(),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _update(() => c.defaultCountryCode = v),
                ),
                const SizedBox(height: 10),
              ],

              if (field.fieldType == CcFieldType.yesNo) ...[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(isAr ? 'القيمة الافتراضية' : 'Default value', style: const TextStyle(fontSize: 12)),
                  value: c.defaultYesNo,
                  onChanged: (v) => _update(() => c.defaultYesNo = v),
                ),
              ],

              const SizedBox(height: 8),
              _label(isAr ? 'نص مساعد' : 'Helper text'),
              TextField(
                controller: _helperCtrl,
                decoration: _dec(),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => _update(() => c.helperText = v),
              ),
              const SizedBox(height: 10),

              if (!field.fieldType.isAlwaysFullWidth) ...[
                _label(isAr ? 'العرض (من 16 عمود)' : 'Width (of 16 columns)'),
                Slider(
                  value: c.desktopColWidth.toDouble().clamp(field.fieldType.minDesktopCols.toDouble(), 16),
                  min: field.fieldType.minDesktopCols.toDouble(),
                  max: 16,
                  divisions: 16 - field.fieldType.minDesktopCols,
                  activeColor: AppColors.primary,
                  label: '${c.desktopColWidth}/16',
                  onChanged: (v) => _update(() => c.desktopColWidth = v.round()),
                ),
                const SizedBox(height: 8),
              ],

              const Divider(),
              const SizedBox(height: 4),
              _label(isAr ? 'منطق الشرط' : 'Conditional Logic'),
              Text(
                isAr
                    ? 'أظهر هذا الحقل فقط إذا تحققت الشروط أدناه'
                    : 'Show this field only when below conditions match',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              ...c.conditions.asMap().entries.map((e) {
                final matches = widget.allFields.where((f) => f.id == e.value.sourceFieldId);
                final srcField = matches.isEmpty ? null : matches.first;
                final srcLabel = srcField != null
                    ? (srcField.label.isNotEmpty ? srcField.label : (isAr ? srcField.fieldType.displayNameAr : srcField.fieldType.displayName))
                    : (e.value.sourceFieldId.isEmpty
                        ? (isAr ? '(حقل)' : '(field)')
                        : (isAr ? '(حقل محذوف)' : '(deleted field)'));
                return _ConditionRow(
                  condition: e.value,
                  sourceFieldLabel: srcLabel,
                  onRemove: () => _update(() => c.conditions.removeAt(e.key)),
                  onTap: () async {
                    final result = await showDialog<CcCondition>(
                      context: context,
                      builder: (dialogCtx) => _ConditionEditorDialog(
                        initial: e.value,
                        allFields: widget.allFields,
                        currentFieldId: field.id,
                        onSave: (cond) => Navigator.pop(dialogCtx, cond),
                      ),
                    );
                    if (result != null) {
                      _update(() => c.conditions[e.key] = result);
                    }
                  },
                );
              }),
              TextButton.icon(
                onPressed: () async {
                  final result = await showDialog<CcCondition>(
                    context: context,
                    builder: (dialogCtx) => _ConditionEditorDialog(
                      allFields: widget.allFields,
                      currentFieldId: field.id,
                      onSave: (cond) => Navigator.pop(dialogCtx, cond),
                    ),
                  );
                  if (result != null) {
                    _update(() => c.conditions.add(result));
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(isAr ? 'إضافة شرط' : 'Add condition',
                    style: const TextStyle(fontSize: 11)),
              ),

              if (widget.allSteps.length > 1 &&
                  [CcFieldType.singleSelect, CcFieldType.radio, CcFieldType.yesNo,
                   CcFieldType.styledSelect, CcFieldType.imageChoice].contains(field.fieldType)) ...[
                const Divider(),
                const SizedBox(height: 4),
                _label(isAr ? 'منطق الانتقال' : 'Jump Logic'),
                Text(
                  isAr
                      ? 'تحديد وجهة التنقل بعد اختيار كل خيار'
                      : 'Set where to go after each option is selected',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                ...() {
                  final List<String> optionValues;
                  final List<String> optionLabels;
                  if (field.fieldType == CcFieldType.yesNo) {
                    optionValues = ['true', 'false'];
                    optionLabels = isAr ? ['نعم', 'لا'] : ['Yes', 'No'];
                  } else if (field.fieldType == CcFieldType.styledSelect) {
                    optionValues = c.styledSelectOptions.map((o) => o.label).toList();
                    optionLabels = c.styledSelectOptions.map((o) => o.label).toList();
                  } else {
                    optionValues = c.options;
                    optionLabels = c.options;
                  }
                  return optionValues.asMap().entries.map((e) {
                    final optValue = e.value;
                    final optLabel = optionLabels[e.key];
                    final currentTarget = c.jumpLogic[optValue] ?? 'next';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              optLabel,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: currentTarget,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black87),
                              items: [
                                DropdownMenuItem(
                                  value: 'next',
                                  child: Text(
                                    isAr ? 'الخطوة التالية' : 'Next step',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'submit',
                                  child: Text(
                                    isAr ? 'إرسال النموذج' : 'Submit form',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...widget.allSteps.map((step) => DropdownMenuItem(
                                  value: 'step:${step.id}',
                                  child: Text(
                                    '→ ${step.title}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                _update(() {
                                  if (v == 'next') {
                                    c.jumpLogic.remove(optValue);
                                  } else {
                                    c.jumpLogic[optValue] = v;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 2),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      );

  InputDecoration _dec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
      );

  Widget _segmented({
    required List<String> options,
    required List<String> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) =>
      Row(
        children: List.generate(options.length, (i) {
          final selected = options[i] == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i]),
              child: Container(
                margin: EdgeInsets.only(right: i < options.length - 1 ? 4 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFF0F1F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(labels[i], textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.onBackground)),
              ),
            ),
          );
        }),
      );

  Widget _stepperRow(int value, ValueChanged<int> onChanged, {int min = 0, int max = 999}) => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.primary,
          ),
          SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.primary,
          ),
        ],
      );

  Widget _numField(double value, ValueChanged<double> onChanged) => TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        decoration: _dec(),
        style: const TextStyle(fontSize: 12),
        onChanged: (v) {
          final d = double.tryParse(v);
          if (d != null) onChanged(d);
        },
      );
}

class _OptionsEditor extends StatefulWidget {
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const _OptionsEditor({required this.options, required this.onChanged});

  @override
  State<_OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<_OptionsEditor> {
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _options = List.from(widget.options);
  }

  void _commit() => widget.onChanged(List.from(_options));

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        ..._options.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (v) {
                        _options[e.key] = v;
                        _commit();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14),
                    onPressed: () => setState(() { _options.removeAt(e.key); _commit(); }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            )),
        TextButton.icon(
          onPressed: () => setState(() {
            _options.add('${isAr ? "خيار" : "Option"} ${_options.length + 1}');
            _commit();
          }),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: Text(isAr ? 'إضافة خيار' : 'Add option', style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

// ── Styled select options editor ──────────────────────────

const _kPresets = [
  ('🟠 Pending',   '#FF9800', '#FFFFFF'),
  ('🟢 Done',      '#4CAF50', '#FFFFFF'),
  ('🔴 Rejected',  '#F44336', '#FFFFFF'),
  ('🔵 In Progress','#2196F3', '#FFFFFF'),
  ('⚫ Closed',    '#424242', '#FFFFFF'),
  ('🟡 Warning',   '#FFC107', '#212121'),
];

class _StyledOptionsEditor extends StatefulWidget {
  final List<StyledSelectOption> options;
  final ValueChanged<List<StyledSelectOption>> onChanged;

  const _StyledOptionsEditor({required this.options, required this.onChanged});

  @override
  State<_StyledOptionsEditor> createState() => _StyledOptionsEditorState();
}

class _StyledOptionsEditorState extends State<_StyledOptionsEditor> {
  late List<StyledSelectOption> _opts;

  @override
  void initState() {
    super.initState();
    _opts = List.from(widget.options);
  }

  void _commit() => widget.onChanged(List.from(_opts));

  void _addPreset((String, String, String) preset) {
    final id = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    _opts.add(StyledSelectOption(
      id: id, label: preset.$1,
      bgColor: preset.$2, textColor: preset.$3,
    ));
    _commit();
  }

  void _updateLabel(int i, String label) {
    _opts[i] = StyledSelectOption(
      id: _opts[i].id, label: label,
      bgColor: _opts[i].bgColor, bgOpacity: _opts[i].bgOpacity,
      textColor: _opts[i].textColor, textOpacity: _opts[i].textOpacity,
    );
    _commit();
  }

  void _updateColors(int i, String bg, String fg) {
    _opts[i] = StyledSelectOption(
      id: _opts[i].id, label: _opts[i].label,
      bgColor: bg, bgOpacity: _opts[i].bgOpacity,
      textColor: fg, textOpacity: _opts[i].textOpacity,
    );
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset quick-add chips
        Wrap(
          spacing: 4, runSpacing: 4,
          children: _kPresets.map((p) => ActionChip(
            label: Text(p.$1, style: const TextStyle(fontSize: 10)),
            onPressed: () => setState(() => _addPreset(p)),
            backgroundColor: const Color(0xFFF0F1F5),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
        const SizedBox(height: 8),
        // Option rows
        ..._opts.asMap().entries.map((e) {
          final opt = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEEEFF2)),
            ),
            child: Row(children: [
              // Preview badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: opt.bgColorValue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  opt.label.isEmpty ? (isAr ? 'خيار' : 'Option') : opt.label,
                  style: TextStyle(fontSize: 10, color: opt.textColorValue,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              // Label field
              Expanded(
                child: TextFormField(
                  initialValue: opt.label,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isAr ? 'اسم الخيار' : 'Option name',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: (v) => setState(() => _updateLabel(e.key, v)),
                ),
              ),
              const SizedBox(width: 4),
              // Color preset picker
              PopupMenuButton<(String, String)>(
                tooltip: isAr ? 'لون' : 'Color',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.palette_outlined, size: 14),
                itemBuilder: (_) => _kPresets.map((p) => PopupMenuItem(
                  value: (p.$2, p.$3),
                  height: 32,
                  child: Row(children: [
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: Color(int.parse('FF${p.$2.replaceFirst("#", "")}', radix: 16)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(p.$1, style: const TextStyle(fontSize: 11)),
                  ]),
                )).toList(),
                onSelected: (pair) => setState(() => _updateColors(e.key, pair.$1, pair.$2)),
              ),
              // Remove button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 13),
                onPressed: () => setState(() { _opts.removeAt(e.key); _commit(); }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() {
            _opts.add(StyledSelectOption(
              id: 'opt_${DateTime.now().millisecondsSinceEpoch}',
              label: isAr ? 'خيار ${_opts.length + 1}' : 'Option ${_opts.length + 1}',
            ));
            _commit();
          }),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: Text(isAr ? 'إضافة خيار' : 'Add option',
              style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final CcCondition condition;
  final String sourceFieldLabel;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ConditionRow({
    required this.condition,
    required this.sourceFieldLabel,
    required this.onRemove,
    required this.onTap,
  });

  String _ruleLabel(CcConditionRule rule, bool isAr) {
    if (isAr) {
      switch (rule) {
        case CcConditionRule.equals:      return 'يساوي';
        case CcConditionRule.notEquals:   return 'لا يساوي';
        case CcConditionRule.contains:    return 'يحتوي على';
        case CcConditionRule.notContains: return 'لا يحتوي على';
        case CcConditionRule.greaterThan: return 'أكبر من';
        case CcConditionRule.lessThan:    return 'أصغر من';
        case CcConditionRule.isEmpty:     return 'فارغ';
        case CcConditionRule.isNotEmpty:  return 'غير فارغ';
      }
    } else {
      switch (rule) {
        case CcConditionRule.equals:      return 'equals';
        case CcConditionRule.notEquals:   return 'not equals';
        case CcConditionRule.contains:    return 'contains';
        case CcConditionRule.notContains: return 'does not contain';
        case CcConditionRule.greaterThan: return 'greater than';
        case CcConditionRule.lessThan:    return 'less than';
        case CcConditionRule.isEmpty:     return 'is empty';
        case CcConditionRule.isNotEmpty:  return 'is not empty';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final needsValue = condition.rule != CcConditionRule.isEmpty &&
        condition.rule != CcConditionRule.isNotEmpty;
    final valueStr = needsValue && condition.value != null ? ' ${condition.value}' : '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$sourceFieldLabel ${_ruleLabel(condition.rule, isAr)}$valueStr',
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 12),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Condition editor dialog ────────────────────────────────

class _ConditionEditorDialog extends StatefulWidget {
  final CcCondition? initial;
  final List<CcFormField> allFields;
  final String currentFieldId;
  final ValueChanged<CcCondition> onSave;

  const _ConditionEditorDialog({
    this.initial,
    required this.allFields,
    required this.currentFieldId,
    required this.onSave,
  });

  @override
  State<_ConditionEditorDialog> createState() => _ConditionEditorDialogState();
}

class _ConditionEditorDialogState extends State<_ConditionEditorDialog> {
  String? _sourceFieldId;
  CcConditionRule _rule = CcConditionRule.equals;
  String _value = '';

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null && init.sourceFieldId.isNotEmpty) {
      _sourceFieldId = init.sourceFieldId;
      _rule = init.rule;
      _value = init.value?.toString() ?? '';
    }
  }

  String _ruleLabel(CcConditionRule rule, bool isAr) {
    if (isAr) {
      switch (rule) {
        case CcConditionRule.equals:      return 'يساوي';
        case CcConditionRule.notEquals:   return 'لا يساوي';
        case CcConditionRule.contains:    return 'يحتوي على';
        case CcConditionRule.notContains: return 'لا يحتوي على';
        case CcConditionRule.greaterThan: return 'أكبر من';
        case CcConditionRule.lessThan:    return 'أصغر من';
        case CcConditionRule.isEmpty:     return 'فارغ';
        case CcConditionRule.isNotEmpty:  return 'غير فارغ';
      }
    } else {
      switch (rule) {
        case CcConditionRule.equals:      return 'equals';
        case CcConditionRule.notEquals:   return 'not equals';
        case CcConditionRule.contains:    return 'contains';
        case CcConditionRule.notContains: return 'does not contain';
        case CcConditionRule.greaterThan: return 'greater than';
        case CcConditionRule.lessThan:    return 'less than';
        case CcConditionRule.isEmpty:     return 'is empty';
        case CcConditionRule.isNotEmpty:  return 'is not empty';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final validSourceFields = widget.allFields
        .where((f) => f.id != widget.currentFieldId && !f.fieldType.isDisplayOnly)
        .toList();

    final srcMatches = _sourceFieldId == null
        ? <CcFormField>[]
        : validSourceFields.where((f) => f.id == _sourceFieldId).toList();
    final selectedField = srcMatches.isEmpty ? null : srcMatches.first;

    final needsValue = _rule != CcConditionRule.isEmpty &&
        _rule != CcConditionRule.isNotEmpty;

    // Build value widget based on selected field type
    Widget? valueWidget;
    if (needsValue && selectedField != null) {
      if (selectedField.fieldType == CcFieldType.yesNo) {
        final yesNoVal = _value.isEmpty ? 'true' : _value;
        valueWidget = DropdownButtonFormField<String>(
          value: yesNoVal == 'true' || yesNoVal == 'false' ? yesNoVal : 'true',
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          items: [
            DropdownMenuItem(value: 'true',  child: Text(isAr ? 'نعم' : 'Yes')),
            DropdownMenuItem(value: 'false', child: Text(isAr ? 'لا'  : 'No')),
          ],
          onChanged: (v) => setState(() => _value = v ?? 'true'),
        );
      } else if ([
        CcFieldType.singleSelect,
        CcFieldType.multiSelect,
        CcFieldType.checkboxGroup,
        CcFieldType.radio,
        CcFieldType.imageChoice,
        CcFieldType.styledSelect,
      ].contains(selectedField.fieldType)) {
        final options = selectedField.fieldType == CcFieldType.styledSelect
            ? selectedField.config.styledSelectOptions.map((o) => o.label).toList()
            : selectedField.config.options;
        if (options.isNotEmpty) {
          valueWidget = DropdownButtonFormField<String>(
            value: options.contains(_value) ? _value : null,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            hint: Text(isAr ? 'اختر قيمة' : 'Select a value',
                style: const TextStyle(fontSize: 12)),
            items: options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _value = v ?? ''),
          );
        } else {
          valueWidget = TextFormField(
            initialValue: _value,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) => setState(() => _value = v),
          );
        }
      } else {
        valueWidget = TextFormField(
          initialValue: _value,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          style: const TextStyle(fontSize: 12),
          onChanged: (v) => setState(() => _value = v),
        );
      }
    }

    return AlertDialog(
      title: Text(
        widget.initial != null
            ? (isAr ? 'تعديل الشرط' : 'Edit condition')
            : (isAr ? 'إضافة شرط' : 'Add condition'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAr ? 'الحقل المصدر' : 'Source field',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.secondary)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _sourceFieldId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              hint: Text(isAr ? 'اختر حقل' : 'Select field',
                  style: const TextStyle(fontSize: 12)),
              items: validSourceFields
                  .map((f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.label.isNotEmpty
                              ? f.label
                              : (isAr ? f.fieldType.displayNameAr : f.fieldType.displayName),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _sourceFieldId = v;
                _value = '';
              }),
            ),
            const SizedBox(height: 12),
            Text(isAr ? 'القاعدة' : 'Rule',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.secondary)),
            const SizedBox(height: 4),
            DropdownButtonFormField<CcConditionRule>(
              value: _rule,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              items: CcConditionRule.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_ruleLabel(r, isAr),
                            style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _rule = v ?? CcConditionRule.equals),
            ),
            if (needsValue && valueWidget != null) ...[
              const SizedBox(height: 12),
              Text(isAr ? 'القيمة' : 'Value',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.secondary)),
              const SizedBox(height: 4),
              valueWidget,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? 'إلغاء' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _sourceFieldId == null
              ? null
              : () => widget.onSave(CcCondition(
                    sourceFieldId: _sourceFieldId!,
                    rule: _rule,
                    value: needsValue ? _value : null,
                  )),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(isAr ? 'حفظ' : 'Save'),
        ),
      ],
    );
  }
}
