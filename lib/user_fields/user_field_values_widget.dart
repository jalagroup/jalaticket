import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'user_field_models.dart';
import 'user_field_service.dart';

class UserFieldValuesWidget extends StatefulWidget {
  final String targetUserId;
  final String currentUserId;
  final bool isAdmin;
  final bool compactMode;
  final VoidCallback? onSaved;

  const UserFieldValuesWidget({
    super.key,
    required this.targetUserId,
    required this.currentUserId,
    required this.isAdmin,
    this.compactMode = false,
    this.onSaved,
  });

  @override
  State<UserFieldValuesWidget> createState() => _UserFieldValuesWidgetState();
}

class _UserFieldValuesWidgetState extends State<UserFieldValuesWidget> {
  List<UserFieldDefinition> _defs = [];
  Map<String, dynamic> _editing = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _disposeControllers() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _controllers.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final defs = await UserFieldService.getDefinitions(activeOnly: true);
      final values = await UserFieldService.getValuesForUser(widget.targetUserId);

      final visibleDefs = defs.where((d) {
        if (widget.isAdmin) return d.fillMode != UserFieldFillMode.userOnly;
        return d.fillMode == UserFieldFillMode.userOnly || d.fillMode == UserFieldFillMode.both;
      }).toList();

      final valueMap = <String, UserFieldValue>{};
      for (final v in values) {
        valueMap[v.fieldId] = v;
      }

      final editingMap = <String, dynamic>{};
      for (final d in visibleDefs) {
        editingMap[d.id] = valueMap[d.id]?.value;
      }

      _disposeControllers();
      for (final d in visibleDefs) {
        if (d.fieldType != UserFieldType.boolean && d.fieldType != UserFieldType.dropdown) {
          _controllers[d.id] = TextEditingController(text: editingMap[d.id]?.toString() ?? '');
        }
      }

      if (mounted) {
        setState(() {
          _defs = visibleDefs;
          _editing = editingMap;
          _loading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    // Sync text controller values into _editing before saving
    for (final d in _defs) {
      if (_controllers.containsKey(d.id)) {
        final text = _controllers[d.id]!.text;
        _editing[d.id] = text.isEmpty ? null : text;
      }
    }

    setState(() => _saving = true);
    try {
      await Future.wait(_defs.map((d) async {
        await UserFieldService.upsertValue(
          userId: widget.targetUserId,
          fieldId: d.id,
          value: _editing[d.id],
          filledByUserId: widget.currentUserId,
        );
      }));
      setState(() { _saving = false; _hasChanges = false; });
      widget.onSaved?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fields saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_defs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._defs.map((def) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInput(def),
            )),
        if (_hasChanges) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Fields'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInput(UserFieldDefinition def) {
    switch (def.fieldType) {
      case UserFieldType.boolean:
        return Row(
          children: [
            Checkbox(
              value: _editing[def.id] == true || _editing[def.id] == 'true',
              onChanged: (v) => setState(() { _editing[def.id] = v; _hasChanges = true; }),
              activeColor: AppColors.primary,
            ),
            Flexible(child: Text(def.label, style: const TextStyle(fontSize: 14))),
          ],
        );
      case UserFieldType.dropdown:
        final opts = def.fieldOptions;
        final currentVal = _editing[def.id]?.toString();
        final validVal = opts.any((o) => o.value == currentVal) ? currentVal : null;
        return DropdownButtonFormField<String>(
          key: ValueKey('${def.id}_$validVal'),
          initialValue: validVal,
          decoration: InputDecoration(labelText: def.label, border: const OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('— not set —')),
            ...opts.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))),
          ],
          onChanged: (v) => setState(() { _editing[def.id] = v; _hasChanges = true; }),
        );
      case UserFieldType.textarea:
        return TextField(
          controller: _controllers[def.id],
          maxLines: 3,
          decoration: InputDecoration(labelText: def.label, border: const OutlineInputBorder(), isDense: true),
          onChanged: (_) { if (!_hasChanges) setState(() => _hasChanges = true); },
        );
      default:
        return TextField(
          controller: _controllers[def.id],
          keyboardType: def.fieldType == UserFieldType.number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: def.label, border: const OutlineInputBorder(), isDense: true),
          onChanged: (_) { if (!_hasChanges) setState(() => _hasChanges = true); },
        );
    }
  }
}
