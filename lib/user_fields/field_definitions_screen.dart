import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'user_field_models.dart';
import 'user_field_service.dart';

class FieldDefinitionsScreen extends StatefulWidget {
  const FieldDefinitionsScreen({super.key});

  @override
  State<FieldDefinitionsScreen> createState() => _FieldDefinitionsScreenState();
}

class _FieldDefinitionsScreenState extends State<FieldDefinitionsScreen> {
  List<UserFieldDefinition> _defs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final defs = await UserFieldService.getDefinitions();
      if (mounted) {
        setState(() { _defs = defs; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text('Custom User Fields', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
                onPressed: () => _showEditor(null),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_defs.isEmpty)
          const Expanded(child: Center(child: Text('No custom fields yet. Add one to get started.')))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _defs.length,
                onReorder: _onReorder,
                itemBuilder: (ctx, i) {
                  final def = _defs[i];
                  return _FieldDefCard(
                    key: ValueKey(def.id),
                    def: def,
                    onEdit: () => _showEditor(def),
                    onToggle: () => _toggleActive(def),
                    onDelete: () => _delete(def),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<UserFieldDefinition>.from(_defs);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _defs = updated);
    await UserFieldService.reorderDefinitions(updated.map((d) => d.id).toList());
  }

  Future<void> _toggleActive(UserFieldDefinition def) async {
    try {
      final updated = await UserFieldService.updateDefinition(def.id, {'is_active': !def.isActive});
      if (mounted) setState(() {
        final idx = _defs.indexWhere((d) => d.id == def.id);
        if (idx >= 0) _defs[idx] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(UserFieldDefinition def) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Field?'),
        content: Text('Delete "${def.label}" and all its values? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await UserFieldService.deleteDefinition(def.id);
      if (mounted) setState(() => _defs.removeWhere((d) => d.id == def.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showEditor(UserFieldDefinition? existing) async {
    final result = await showDialog<UserFieldDefinition>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FieldDefEditor(existing: existing, nextOrder: _defs.length),
    );
    if (result != null && mounted) {
      if (existing == null) {
        setState(() => _defs.add(result));
      } else {
        setState(() {
          final idx = _defs.indexWhere((d) => d.id == result.id);
          if (idx >= 0) _defs[idx] = result;
        });
      }
    }
  }
}

// ─── Field Definition Card ──────────────────────────────────────────────────

class _FieldDefCard extends StatelessWidget {
  final UserFieldDefinition def;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _FieldDefCard({
    super.key,
    required this.def,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: def.isActive ? Colors.grey.shade200 : Colors.grey.shade100),
      ),
      color: def.isActive ? Colors.white : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(def.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (def.labelAr != null) ...[
                        const SizedBox(width: 6),
                        Text('(${def.labelAr})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _FieldChip(def.fieldType.label, Colors.blue),
                      _FieldChip(def.fillMode.label, _fillModeColor(def.fillMode)),
                      if (def.blocksUserUntilFilled) const _FieldChip('Blocks Login', Colors.red),
                      if (!def.isNullable) const _FieldChip('Has Default', Colors.orange),
                      if (!def.isActive) const _FieldChip('Inactive', Colors.grey),
                      if (def.isShownInProfile) const _FieldChip('In Profile', Colors.green),
                      if (def.isComputed) const _FieldChip('Computed', Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  color: AppColors.primary,
                ),
                IconButton(
                  icon: Icon(
                    def.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: onToggle,
                  tooltip: def.isActive ? 'Deactivate' : 'Activate',
                  color: Colors.orange,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _fillModeColor(UserFieldFillMode mode) => switch (mode) {
    UserFieldFillMode.optional => Colors.grey,
    UserFieldFillMode.adminOnly => Colors.purple,
    UserFieldFillMode.userOnly => Colors.teal,
    UserFieldFillMode.both => Colors.indigo,
  };
}

class _FieldChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FieldChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Editor Dialog ───────────────────────────────────────────────────────────

class _FieldDefEditor extends StatefulWidget {
  final UserFieldDefinition? existing;
  final int nextOrder;
  const _FieldDefEditor({this.existing, required this.nextOrder});

  @override
  State<_FieldDefEditor> createState() => _FieldDefEditorState();
}

class _FieldDefEditorState extends State<_FieldDefEditor> {
  final _labelCtrl = TextEditingController();
  final _labelArCtrl = TextEditingController();
  final _formulaCtrl = TextEditingController();
  final _defaultValueCtrl = TextEditingController();
  UserFieldType _fieldType = UserFieldType.text;
  UserFieldFillMode _fillMode = UserFieldFillMode.optional;
  bool _blocksUser = false;
  bool _shownInProfile = true;
  bool _isActive = true;
  bool _isComputed = false;
  List<UserFieldOption> _options = [];
  List<UserFieldDefinition> _otherDefs = [];
  bool _isNullable = true;
  bool _saving = false;
  // Tracks cursor position so variable chips insert at the right spot
  int _formulaCursor = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelCtrl.text = e.label;
      _labelArCtrl.text = e.labelAr ?? '';
      _fieldType = e.fieldType;
      _fillMode = e.fillMode;
      _blocksUser = e.blocksUserUntilFilled;
      _shownInProfile = e.isShownInProfile;
      _isActive = e.isActive;
      _isComputed = e.isComputed;
      _formulaCtrl.text = e.formula ?? '';
      _options = List.from(e.fieldOptions);
      _isNullable = e.isNullable;
      _defaultValueCtrl.text = e.defaultValue ?? '';
    }
    _loadOtherDefs();
  }

  Future<void> _loadOtherDefs() async {
    try {
      final defs = await UserFieldService.getDefinitions(activeOnly: true);
      if (mounted) {
        setState(() => _otherDefs = defs.where((d) => !d.isComputed && d.id != (widget.existing?.id ?? '')).toList());
      }
    } catch (_) {}
  }

  void _insertVariable(String variable) {
    final text = _formulaCtrl.text;
    final pos = _formulaCursor.clamp(0, text.length);
    final newText = text.substring(0, pos) + variable + text.substring(pos);
    _formulaCtrl.text = newText;
    _formulaCtrl.selection = TextSelection.collapsed(offset: pos + variable.length);
    _formulaCursor = pos + variable.length;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _labelArCtrl.dispose();
    _formulaCtrl.dispose();
    _defaultValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Field' : 'New Custom Field',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Field Label (English) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _labelArCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Field Label (Arabic)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserFieldType>(
                      value: _fieldType,
                      decoration: const InputDecoration(labelText: 'Field Type', border: OutlineInputBorder()),
                      items: UserFieldType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) { if (v != null) setState(() => _fieldType = v); },
                    ),
                    if (_fieldType == UserFieldType.dropdown) ...[
                      const SizedBox(height: 12),
                      _OptionsEditor(
                        options: _options,
                        onChanged: (opts) => setState(() => _options = opts),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserFieldFillMode>(
                      value: _fillMode,
                      decoration: const InputDecoration(
                        labelText: 'Who can fill this field?',
                        border: OutlineInputBorder(),
                      ),
                      items: UserFieldFillMode.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _fillMode = v;
                            if (v == UserFieldFillMode.adminOnly) _blocksUser = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_fillMode != UserFieldFillMode.adminOnly) ...[
                      CheckboxListTile(
                        value: _blocksUser,
                        onChanged: (v) => setState(() => _blocksUser = v ?? false),
                        title: const Text('Block user login until filled', style: TextStyle(fontSize: 14)),
                        subtitle: const Text(
                          'User cannot navigate the app until this field has a value',
                          style: TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    CheckboxListTile(
                      value: _shownInProfile,
                      onChanged: (v) => setState(() => _shownInProfile = v ?? true),
                      title: const Text('Show in user profile', style: TextStyle(fontSize: 14)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v ?? true),
                        title: const Text('Active', style: TextStyle(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],

                    // ── Nullable / Default ────────────────────────────────
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: _isNullable,
                      onChanged: _isComputed
                          ? null
                          : (v) => setState(() => _isNullable = v ?? true),
                      title: const Text('Allow empty (nullable)', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Uncheck to require a default value when none is set',
                          style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (!_isNullable) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _defaultValueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Default value *',
                          hintText: 'Shown when no value has been set',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    // ── Computed / Formula ─────────────────────────────────
                    const Divider(height: 20),
                    CheckboxListTile(
                      value: _isComputed,
                      onChanged: (v) => setState(() {
                        _isComputed = v ?? false;
                        if (_isComputed) {
                          // computed fields can't block login (they are read-only)
                          _blocksUser = false;
                          _fillMode = UserFieldFillMode.optional;
                        }
                      }),
                      title: Row(
                        children: [
                          const Text('Computed field', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Icon(Icons.auto_awesome, size: 14, color: Colors.amber[600]),
                        ],
                      ),
                      subtitle: const Text('Value is generated automatically from a formula',
                          style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_isComputed) ...[
                      const SizedBox(height: 10),
                      // Formula textarea
                      TextField(
                        controller: _formulaCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Formula',
                          hintText: 'e.g.  {{user.name}} — License: {{field.License No.}}',
                          border: OutlineInputBorder(),
                          helperText: 'Use {{variable}} syntax. Tap chips below to insert.',
                        ),
                        onTap: () => _formulaCursor = _formulaCtrl.selection.baseOffset,
                        onChanged: (_) => _formulaCursor = _formulaCtrl.selection.baseOffset,
                      ),
                      const SizedBox(height: 8),
                      // Variable chip picker
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available Variables', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                            const SizedBox(height: 8),
                            const Text('User Fields', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final v in ['{{user.name}}', '{{user.email}}', '{{user.phone}}', '{{user.type}}'])
                                  _VarChip(label: v, onTap: () => _insertVariable(v)),
                              ],
                            ),
                            if (_otherDefs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Other Custom Fields', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _otherDefs.map((d) {
                                  final v = '{{field.${d.label}}}';
                                  return _VarChip(label: d.label, onTap: () => _insertVariable(v));
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Field'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field label is required')),
      );
      return;
    }
    if (!_isNullable && _defaultValueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default value is required for non-nullable fields')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'label': label,
        'label_ar': _labelArCtrl.text.trim().isEmpty ? null : _labelArCtrl.text.trim(),
        'field_type': _fieldType.name,
        'field_options': _fieldType == UserFieldType.dropdown
            ? _options.map((o) => o.toJson()).toList()
            : [],
        'fill_mode': _fillMode.value,
        'blocks_user_until_filled': _blocksUser,
        'is_shown_in_profile': _shownInProfile,
        'is_active': _isActive,
        'order_index': widget.existing?.orderIndex ?? widget.nextOrder,
        'is_computed': _isComputed,
        'formula': _isComputed && _formulaCtrl.text.trim().isNotEmpty ? _formulaCtrl.text.trim() : null,
        'is_nullable': _isNullable,
        'default_value': !_isNullable ? _defaultValueCtrl.text.trim() : null,
      };

      UserFieldDefinition result;
      if (widget.existing != null) {
        result = await UserFieldService.updateDefinition(widget.existing!.id, data);
      } else {
        result = await UserFieldService.createDefinition(data);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Options Editor ──────────────────────────────────────────────────────────

class _OptionsEditor extends StatefulWidget {
  final List<UserFieldOption> options;
  final ValueChanged<List<UserFieldOption>> onChanged;

  const _OptionsEditor({required this.options, required this.onChanged});

  @override
  State<_OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<_OptionsEditor> {
  late List<UserFieldOption> _options;

  @override
  void initState() {
    super.initState();
    _options = List.from(widget.options);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Option', style: TextStyle(fontSize: 13)),
              onPressed: _addOption,
            ),
          ],
        ),
        ..._options.asMap().entries.map((e) => _OptionRow(
              key: ValueKey(e.key),
              option: e.value,
              onChanged: (opt) {
                _options[e.key] = opt;
                widget.onChanged(_options);
              },
              onRemove: () {
                setState(() => _options.removeAt(e.key));
                widget.onChanged(_options);
              },
            )),
      ],
    );
  }

  void _addOption() {
    setState(() => _options.add(const UserFieldOption(value: '', label: '')));
    widget.onChanged(_options);
  }
}

class _OptionRow extends StatefulWidget {
  final UserFieldOption option;
  final ValueChanged<UserFieldOption> onChanged;
  final VoidCallback onRemove;

  const _OptionRow({super.key, required this.option, required this.onChanged, required this.onRemove});

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.option.label);
    _valueCtrl = TextEditingController(text: widget.option.value);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                hintText: 'Label',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.onChanged(UserFieldOption(value: _valueCtrl.text, label: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _valueCtrl,
              decoration: const InputDecoration(
                hintText: 'Value (key)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.onChanged(UserFieldOption(value: v, label: _labelCtrl.text)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Variable Chip ───────────────────────────────────────────────────────────

class _VarChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _VarChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
