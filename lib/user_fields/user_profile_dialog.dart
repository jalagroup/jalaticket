import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart' show AppColors, supabase;
import 'package:jalasupport/models.dart';
import 'package:jalasupport/user_picker.dart';
import 'user_field_models.dart';
import 'user_field_service.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class UserProfileDialog extends StatefulWidget {
  final UserModel user;
  final UserModel currentUser;
  final List<UserFieldDefinition> customFieldDefs;
  /// Each entry: {'id': '...', 'name': '...'}
  final List<Map<String, String>> departments;
  /// Each entry: {'id': '...', 'name': '...'}
  final List<Map<String, String>> places;
  final VoidCallback onUpdated;

  const UserProfileDialog({
    super.key,
    required this.user,
    required this.currentUser,
    required this.customFieldDefs,
    required this.departments,
    required this.places,
    required this.onUpdated,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late UserModel _user;
  List<UserFieldValue> _fieldValues = [];
  bool _loadingValues = true;

  // Super-admin department assignments (many-to-many via admin_departments).
  Set<String> _assignedDeptIds = {};
  bool _loadingDeptAssignments = false;

  bool _editMode = false;
  bool _saving = false;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  late UserType _editUserType;
  String? _editDeptId;
  Set<String> _editDeptIds = {};
  String? _editPlaceId;
  UserModel? _editDirectManager;
  final Map<String, TextEditingController> _customTextCtrls = {};
  final Map<String, dynamic> _customValues = {};

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _editUserType = _user.userType;
    _loadValues();
    if (_user.userType == UserType.superAdmin) _loadDeptAssignments();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _customTextCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadValues() async {
    try {
      final vals = await UserFieldService.getValuesForUser(_user.id);
      if (mounted) setState(() { _fieldValues = vals; _loadingValues = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingValues = false);
    }
  }

  Future<void> _loadDeptAssignments() async {
    setState(() => _loadingDeptAssignments = true);
    try {
      final rows = await supabase
          .from('admin_departments')
          .select('department_id')
          .eq('admin_id', _user.id);
      if (mounted) {
        setState(() => _assignedDeptIds = rows.map<String>((r) => r['department_id'] as String).toSet());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDeptAssignments = false);
    }
  }

  bool get _canEdit {
    final ct = widget.currentUser.userType;
    return ct == UserType.systemAdmin || ct == UserType.superAdmin || ct == UserType.superUser;
  }

  bool _canEditUserField(String field) {
    if (!_canEdit) return false;
    final ct = widget.currentUser.userType;
    if (ct == UserType.systemAdmin) return true;
    if (field == 'userType') return false; // only sysAdmin changes type
    return true;
  }

  /// Multi-department assignment (super admin) is a system-admin-only edit,
  /// matching the same rule used for department color/permissions elsewhere.
  bool get _canEditDepartments => widget.currentUser.userType == UserType.systemAdmin;

  bool _canEditCustomField(UserFieldDefinition def) {
    if (def.isComputed) return false;
    return def.fillMode != UserFieldFillMode.userOnly;
  }

  bool _needsDept(UserType t) => t == UserType.superAdmin || t == UserType.admin;
  bool _needsPlace(UserType t) => t == UserType.superUser || t == UserType.user || t == UserType.branchAdmin;

  void _enterEditMode() {
    _fullNameCtrl.text = _user.fullName;
    _phoneCtrl.text = _user.phone ?? '';
    _editUserType = _user.userType;
    _editDeptId = _user.departmentId;
    _editDeptIds = Set.from(_assignedDeptIds);
    _editPlaceId = _user.placeId;
    _editDirectManager = _user.directManagerId != null
        ? UserModel(
            id: _user.directManagerId!,
            email: '',
            fullName: _user.directManagerName ?? '',
            userType: UserType.user,
            isActive: true,
            language: 'en',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : null;

    for (final c in _customTextCtrls.values) {
      c.dispose();
    }
    _customTextCtrls.clear();
    _customValues.clear();
    for (final def in widget.customFieldDefs.where((d) => d.isActive && !d.isComputed)) {
      final current = _fieldValues.where((v) => v.fieldId == def.id).firstOrNull;
      if (def.fieldType == UserFieldType.boolean) {
        _customValues[def.id] = current?.value == true || current?.value == 'true';
      } else if (def.fieldType == UserFieldType.dropdown) {
        final v = current?.displayValue;
        _customValues[def.id] = def.fieldOptions.any((o) => o.value == v) ? v : null;
      } else {
        _customTextCtrls[def.id] = TextEditingController(text: current?.displayValue ?? '');
      }
    }

    setState(() => _editMode = true);
  }

  void _cancelEdit() => setState(() => _editMode = false);

  void _onEditUserTypeChanged(UserType? v) {
    if (v == null) return;
    setState(() {
      _editUserType = v;
      _editDeptId = null;
      _editDeptIds = {};
      _editPlaceId = null;
    });
  }

  Future<void> _saveAll() async {
    if (_fullNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name is required')),
      );
      return;
    }
    if (_editUserType == UserType.superAdmin && _canEditDepartments && _editDeptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one department')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'full_name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'user_type': _editUserType.value,
        'department_id': _editUserType == UserType.admin ? _editDeptId : null,
        'place_id': _needsPlace(_editUserType) ? _editPlaceId : null,
        'direct_manager_id': _editDirectManager?.id,
      };
      final res = await supabase
          .from('users')
          .update(data)
          .eq('id', _user.id)
          .select('*, direct_manager:users!users_direct_manager_id_fkey(id, full_name)')
          .single();
      final updated = UserModel.fromJson(res);

      if (_editUserType == UserType.superAdmin && _canEditDepartments) {
        await supabase.from('admin_departments').delete().eq('admin_id', _user.id);
        if (_editDeptIds.isNotEmpty) {
          await supabase.from('admin_departments').insert(_editDeptIds
              .map((id) => {
                    'admin_id': _user.id,
                    'department_id': id,
                    'created_by': widget.currentUser.id,
                  })
              .toList());
        }
        _assignedDeptIds = Set.from(_editDeptIds);
      }

      for (final def in widget.customFieldDefs.where((d) => d.isActive && _canEditCustomField(d))) {
        dynamic value;
        if (def.fieldType == UserFieldType.boolean || def.fieldType == UserFieldType.dropdown) {
          value = _customValues[def.id];
        } else {
          final text = _customTextCtrls[def.id]?.text.trim() ?? '';
          value = text.isEmpty ? null : text;
        }
        await UserFieldService.upsertValue(
          userId: _user.id,
          fieldId: def.id,
          value: value,
          filledByUserId: widget.currentUser.id,
        );
      }

      await _loadValues();
      if (mounted) {
        setState(() {
          _user = updated;
          _editMode = false;
          _saving = false;
        });
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _typeLabel(UserType t) => switch (t) {
    UserType.systemAdmin => 'System Admin',
    UserType.superAdmin  => 'Super Admin',
    UserType.admin       => 'Admin',
    UserType.branchAdmin => 'Branch Admin',
    UserType.superUser   => 'Super User',
    UserType.user        => 'User',
  };

  Color _typeColor(UserType t) => switch (t) {
    UserType.systemAdmin => const Color(0xFF7C3AED),
    UserType.superAdmin  => const Color(0xFF2563EB),
    UserType.admin       => const Color(0xFFEA580C),
    UserType.superUser   => const Color(0xFF0D9488),
    UserType.branchAdmin => const Color(0xFF4F46E5),
    UserType.user        => const Color(0xFF6B7280),
  };

  String? _deptName(String? id) => id == null ? null
      : widget.departments.where((d) => d['id'] == id).firstOrNull?['name'];

  String? _placeName(String? id) => id == null ? null
      : widget.places.where((p) => p['id'] == id).firstOrNull?['name'];

  InputDecoration _decor({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final initials = _user.fullName.trim().isEmpty
        ? '?'
        : _user.fullName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    final typeColor = _typeColor(_user.userType);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Container(
        width: 760,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 32, offset: const Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(typeColor, initials),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final basicCard = _sectionCard(
                    icon: Icons.badge_outlined,
                    title: 'BASIC INFORMATION',
                    children: [
                      _fieldRow(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        child: _editMode
                            ? TextField(controller: _fullNameCtrl, style: const TextStyle(fontSize: 13.5), decoration: _decor())
                            : _valueText(_user.fullName),
                      ),
                      _fieldRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        child: _valueText(_user.email, muted: true),
                      ),
                      _fieldRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        child: _editMode
                            ? TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 13.5), decoration: _decor())
                            : _valueText(_user.phone?.isNotEmpty == true ? _user.phone! : '—'),
                      ),
                    ],
                  );

                  final roleCard = _sectionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'ROLE & ACCESS',
                    children: [
                      _fieldRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'User Type',
                        child: _editMode
                            ? DropdownButtonFormField<UserType>(
                                initialValue: _editUserType,
                                isDense: true,
                                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                                decoration: _decor(),
                                items: UserType.values
                                    .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                                    .toList(),
                                onChanged: _canEditUserField('userType') ? _onEditUserTypeChanged : null,
                              )
                            : _Badge(_typeLabel(_user.userType), typeColor),
                      ),
                      if (_needsDept(_editMode ? _editUserType : _user.userType) && (_editMode ? _editUserType : _user.userType) == UserType.admin)
                        _fieldRow(
                          icon: Icons.business_outlined,
                          label: 'Department',
                          child: _editMode
                              ? DropdownButtonFormField<String>(
                                  initialValue: _editDeptId,
                                  isDense: true,
                                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                                  decoration: _decor(hint: '— select —'),
                                  items: widget.departments.map((d) => DropdownMenuItem(value: d['id'], child: Text(d['name'] ?? ''))).toList(),
                                  onChanged: _canEditUserField('departmentId') ? (v) => setState(() => _editDeptId = v) : null,
                                )
                              : _valueText(_deptName(_user.departmentId) ?? '—'),
                        ),
                      if ((_editMode ? _editUserType : _user.userType) == UserType.superAdmin)
                        _fieldRow(
                          icon: Icons.corporate_fare_outlined,
                          label: 'Departments',
                          child: _buildDepartmentsField(),
                        ),
                      if (_needsPlace(_editMode ? _editUserType : _user.userType))
                        _fieldRow(
                          icon: Icons.location_on_outlined,
                          label: 'Place',
                          child: _editMode
                              ? DropdownButtonFormField<String>(
                                  initialValue: _editPlaceId,
                                  isDense: true,
                                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                                  decoration: _decor(hint: '— select —'),
                                  items: widget.places.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? ''))).toList(),
                                  onChanged: _canEditUserField('placeId') ? (v) => setState(() => _editPlaceId = v) : null,
                                )
                              : _valueText(_placeName(_user.placeId) ?? '—'),
                        ),
                      _fieldRow(
                        icon: Icons.supervisor_account_outlined,
                        label: 'Direct Manager',
                        child: _editMode
                            ? InkWell(
                                onTap: () async {
                                  final picked = await showUserPicker(
                                    context,
                                    title: 'Select direct manager',
                                    excludeUserId: _user.id,
                                  );
                                  if (picked != null) setState(() => _editDirectManager = picked);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: _decor(hint: 'No direct manager'),
                                  child: Row(children: [
                                    Expanded(
                                      child: Text(
                                        _editDirectManager?.fullName ?? 'No direct manager',
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                    if (_editDirectManager != null)
                                      InkWell(
                                        onTap: () => setState(() => _editDirectManager = null),
                                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                      ),
                                  ]),
                                ),
                              )
                            : _valueText(_user.directManagerName ?? '—'),
                      ),
                      _fieldRow(
                        icon: Icons.toggle_on_outlined,
                        label: 'Status',
                        child: _Badge(_user.isActive ? 'Active' : 'Inactive', _user.isActive ? const Color(0xFF16A34A) : Colors.grey),
                      ),
                    ],
                  );

                  final customCard = widget.customFieldDefs.where((d) => d.isActive).isEmpty
                      ? null
                      : _sectionCard(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'ADDITIONAL INFORMATION',
                          children: _loadingValues
                              ? [const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))]
                              : widget.customFieldDefs.where((d) => d.isActive).map(_buildCustomFieldRow).toList(),
                        );

                  final actionsCard = _canEdit
                      ? _sectionCard(
                          icon: Icons.bolt_outlined,
                          title: 'ACCOUNT ACTIONS',
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _actionChip(icon: Icons.lock_reset_outlined, label: 'Reset Password', color: const Color(0xFF7C3AED), onTap: _resetPassword),
                                if (!_user.isDeleted) ...[
                                  _actionChip(
                                    icon: _user.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                    label: _user.isActive ? 'Deactivate' : 'Activate',
                                    color: _user.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                    onTap: _toggleActive,
                                  ),
                                  _actionChip(icon: Icons.person_off_outlined, label: 'Remove User', color: const Color(0xFFDC2626), onTap: _removeUser),
                                ] else
                                  _actionChip(icon: Icons.restore_outlined, label: 'Restore User', color: const Color(0xFF16A34A), onTap: _restoreUser),
                              ],
                            ),
                          ],
                        )
                      : null;

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        basicCard,
                        const SizedBox(height: 14),
                        roleCard,
                        if (customCard != null) ...[const SizedBox(height: 14), customCard],
                        if (actionsCard != null) ...[const SizedBox(height: 14), actionsCard],
                        const SizedBox(height: 8),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: basicCard),
                            const SizedBox(width: 14),
                            Expanded(child: roleCard),
                          ],
                        ),
                      ),
                      if (customCard != null) ...[const SizedBox(height: 14), customCard],
                      if (actionsCard != null) ...[const SizedBox(height: 14), actionsCard],
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color typeColor, String initials) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(initials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: typeColor)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Badge(_typeLabel(_user.userType), typeColor),
                    const SizedBox(width: 6),
                    _Badge(_user.isActive ? 'Active' : 'Inactive', _user.isActive ? const Color(0xFF16A34A) : Colors.grey[600]!),
                  ],
                ),
              ],
            ),
          ),
          if (!_editMode && _canEdit)
            IconButton(
              onPressed: _enterEditMode,
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit profile',
              style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.08)),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.grey[500]),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: _editMode
            ? [
                TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600], padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  child: const Text('Close'),
                ),
                if (_canEdit) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _enterEditMode,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ],
      ),
    );
  }

  Widget _buildDepartmentsField() {
    if (!_editMode) {
      if (_loadingDeptAssignments) {
        return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_assignedDeptIds.isEmpty) return _valueText('—');
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _assignedDeptIds.map((id) {
          final name = _deptName(id) ?? id;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withValues(alpha: 0.25))),
            child: Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
          );
        }).toList(),
      );
    }

    // Edit mode: multi-select chip grid.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.departments.isEmpty
              ? Text('No departments available', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.departments.map((d) {
                    final id = d['id']!;
                    final isSelected = _editDeptIds.contains(id);
                    return FilterChip(
                      label: Text(d['name'] ?? '', style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade300),
                      ),
                      selectedColor: AppColors.primary.withValues(alpha: 0.14),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.black87, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                      onSelected: _canEditDepartments
                          ? (selected) {
                              setState(() {
                                if (selected) {
                                  _editDeptIds.add(id);
                                } else {
                                  _editDeptIds.remove(id);
                                }
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
        ),
        if (!_canEditDepartments) ...[
          const SizedBox(height: 4),
          Text('Only System Admin can change department assignments.', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ],
    );
  }

  Widget _buildCustomFieldRow(UserFieldDefinition def) {
    final current = _fieldValues.where((v) => v.fieldId == def.id).firstOrNull;

    String displayValue;
    if (def.isComputed && def.formula != null) {
      displayValue = UserFieldService.evaluateFormula(
        formula: def.formula!,
        user: _user,
        allDefs: widget.customFieldDefs,
        userValues: _fieldValues,
      );
      if (displayValue.isEmpty) displayValue = '—';
    } else {
      displayValue = current?.displayValue ?? '—';
    }

    final editable = _editMode && _canEditCustomField(def);

    return _fieldRow(
      icon: _fieldIcon(def.fieldType),
      label: def.label,
      trailing: def.isComputed
          ? Tooltip(message: 'Computed field', child: Icon(Icons.auto_awesome, size: 13, color: Colors.amber[600]))
          : null,
      child: editable ? _buildCustomFieldInput(def) : _valueText(displayValue),
    );
  }

  Widget _buildCustomFieldInput(UserFieldDefinition def) {
    switch (def.fieldType) {
      case UserFieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: _customValues[def.id] as String?,
          isDense: true,
          style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          decoration: _decor(hint: '— not set —'),
          items: def.fieldOptions.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(),
          onChanged: (v) => setState(() => _customValues[def.id] = v),
        );
      case UserFieldType.boolean:
        final val = _customValues[def.id] == true;
        return Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: val,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _customValues[def.id] = v),
          ),
        );
      case UserFieldType.date:
        final ctrl = _customTextCtrls[def.id]!;
        final current = DateTime.tryParse(ctrl.text);
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => ctrl.text = picked.toIso8601String().split('T').first);
            }
          },
          child: InputDecorator(
            decoration: _decor(hint: 'Not set').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16)),
            child: Text(
              ctrl.text.isEmpty ? '' : ctrl.text,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        );
      case UserFieldType.textarea:
        return TextField(
          controller: _customTextCtrls[def.id],
          maxLines: 3,
          style: const TextStyle(fontSize: 13.5),
          decoration: _decor(),
        );
      case UserFieldType.number:
        return TextField(
          controller: _customTextCtrls[def.id],
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13.5),
          decoration: _decor(),
        );
      case UserFieldType.text:
      case UserFieldType.email:
      case UserFieldType.phone:
        return TextField(
          controller: _customTextCtrls[def.id],
          keyboardType: def.fieldType == UserFieldType.email
              ? TextInputType.emailAddress
              : def.fieldType == UserFieldType.phone
                  ? TextInputType.phone
                  : TextInputType.text,
          style: const TextStyle(fontSize: 13.5),
          decoration: _decor(),
        );
    }
  }

  IconData _fieldIcon(UserFieldType t) => switch (t) {
    UserFieldType.text     => Icons.text_fields,
    UserFieldType.number   => Icons.numbers,
    UserFieldType.date     => Icons.calendar_today_outlined,
    UserFieldType.dropdown => Icons.arrow_drop_down_circle_outlined,
    UserFieldType.boolean  => Icons.toggle_on_outlined,
    UserFieldType.email    => Icons.email_outlined,
    UserFieldType.phone    => Icons.phone_outlined,
    UserFieldType.textarea => Icons.notes_outlined,
  };

  // ── Reusable layout helpers ────────────────────────────────────────────────

  Widget _sectionCard({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6)),
          ]),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldRow({required IconData icon, required String label, required Widget child, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 9), child: Icon(icon, size: 15, color: Colors.grey[400])),
          const SizedBox(width: 9),
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: child)),
          if (trailing != null) Padding(padding: const EdgeInsets.only(top: 10, left: 4), child: trailing),
        ],
      ),
    );
  }

  Widget _valueText(String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: muted || value == '—' ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }

  Widget _actionChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.06),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    try {
      await supabase.functions.invoke('reset-user-password', body: {'user_id': _user.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset to default'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleActive() async {
    try {
      final res = await supabase
          .from('users')
          .update({'is_active': !_user.isActive})
          .eq('id', _user.id)
          .select()
          .single();
      if (mounted) {
        setState(() => _user = UserModel.fromJson(res));
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _removeUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove User?'),
        content: Text('Remove ${_user.fullName} from the system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await supabase.from('users').update({'is_deleted': true}).eq('id', _user.id);
      if (mounted) { widget.onUpdated(); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _restoreUser() async {
    try {
      await supabase.from('users').update({'is_deleted': false}).eq('id', _user.id);
      if (mounted) { widget.onUpdated(); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}
