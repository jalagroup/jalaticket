import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'main.dart' show AppColors, supabase;
import 'models.dart';
import 'user_fields/user_field_models.dart';
import 'user_fields/user_field_service.dart';
import 'web_download.dart';

// ── Small helpers (kept in sync by hand with bulk_import_users_dialog.dart —
// both files are library-private, so these can't be shared via import) ────────

String _typeLabel(UserType t) {
  switch (t) {
    case UserType.systemAdmin: return 'System Admin';
    case UserType.superAdmin:  return 'Super Admin';
    case UserType.admin:       return 'Admin';
    case UserType.branchAdmin: return 'Branch Admin';
    case UserType.superUser:   return 'Super User';
    case UserType.user:        return 'User';
  }
}

UserType? _parseTypeLabel(String? s) {
  if (s == null) return null;
  const map = {
    'system admin': UserType.systemAdmin,
    'super admin':  UserType.superAdmin,
    'admin':        UserType.admin,
    'branch admin': UserType.branchAdmin,
    'super user':   UserType.superUser,
    'user':         UserType.user,
  };
  return map[s.trim().toLowerCase()];
}

String _normalizePhone(String raw) {
  final t = raw.trim();
  if (t.startsWith('+')) return t;
  if (RegExp(r'^0\d{9}$').hasMatch(t)) return '+972${t.substring(1)}';
  if (RegExp(r'^\d{9}$').hasMatch(t)) return '+972$t';
  return t;
}

bool? _parseBool(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final v = s.trim().toLowerCase();
  if (['true', 'yes', '1', 'active', 'نشط'].contains(v)) return true;
  if (['false', 'no', '0', 'inactive', 'غير نشط', 'معطل'].contains(v)) return false;
  return null;
}

bool _needsPlace(UserType t) =>
    t == UserType.superUser || t == UserType.user || t == UserType.branchAdmin;

bool _needsDepartment(UserType t) =>
    t == UserType.superAdmin || t == UserType.admin;

/// Mirrors UsersManagement._canEditUser — who the current admin is allowed
/// to touch at all. [superAdminDepartmentIds] is the full set of departments
/// a super admin manages (admin_departments), not just the legacy single
/// department field, so a super admin managing multiple departments can
/// still only ever be matched against those they actually manage.
bool _canEditUser(UserModel currentUser, UserModel target, Set<String> superAdminDepartmentIds) {
  if (currentUser.userType == UserType.systemAdmin) return true;
  if (currentUser.userType == UserType.superAdmin) {
    return target.userType == UserType.admin &&
        target.departmentId != null &&
        superAdminDepartmentIds.contains(target.departmentId);
  }
  if (currentUser.userType == UserType.superUser) {
    return target.userType == UserType.user && target.placeId == currentUser.placeId;
  }
  return false;
}

// ── Row data model ────────────────────────────────────────────────────────────

class _EditRow {
  final int excelRow;
  final String id;
  String fullName;
  String? phone;
  UserType? userType;
  String? rawPlace;
  String? rawDepartment;
  String? rawDepartments;
  List<String> rawBranchPlaces;
  bool? isActive;

  String? placeId;
  String? departmentId;
  List<String> departmentIds = [];
  List<String> branchPlaceIds = [];

  UserModel? original;

  List<String> errors = [];
  bool get isValid => errors.isEmpty;

  bool updated = false;
  bool failed = false;
  String? updateError;

  Map<String, String> customFieldValues = {};

  _EditRow({
    required this.excelRow,
    required this.id,
    required this.fullName,
    this.phone,
    this.userType,
    this.rawPlace,
    this.rawDepartment,
    this.rawDepartments,
    this.rawBranchPlaces = const [],
    this.isActive,
  });
}

// ── Main dialog ───────────────────────────────────────────────────────────────

class BulkEditUsersDialog extends StatefulWidget {
  final UserModel currentUser;
  final List<UserModel> users;
  final List<Map<String, String>> places;
  final List<Map<String, String>> departments;
  final List<UserFieldDefinition> customFieldDefs;
  final Map<String, List<UserFieldValue>> userFieldValues;
  final Set<String> superAdminDepartmentIds;
  final VoidCallback onUsersUpdated;

  const BulkEditUsersDialog({
    super.key,
    required this.currentUser,
    required this.users,
    required this.places,
    required this.departments,
    required this.customFieldDefs,
    required this.userFieldValues,
    required this.superAdminDepartmentIds,
    required this.onUsersUpdated,
  });

  @override
  State<BulkEditUsersDialog> createState() => _BulkEditUsersDialogState();
}

enum _Stage { download, preview, updating, done }

class _BulkEditUsersDialogState extends State<BulkEditUsersDialog> {
  _Stage _stage = _Stage.download;
  bool _loadingRefs = true;
  Map<String, List<String>> _adminDeptNamesById = {};

  List<_EditRow> _rows = [];
  String? _parseError;

  int _updateTotal = 0;
  int _updateDone = 0;

  List<UserModel> get _editableUsers => widget.users
      .where((u) =>
          !u.isDeleted &&
          u.id != widget.currentUser.id &&
          _canEditUser(widget.currentUser, u, widget.superAdminDepartmentIds))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadAdminDepartments();
  }

  Future<void> _loadAdminDepartments() async {
    try {
      final superAdminIds = _editableUsers.where((u) => u.userType == UserType.superAdmin).map((u) => u.id).toList();
      if (superAdminIds.isEmpty) {
        if (mounted) setState(() => _loadingRefs = false);
        return;
      }
      final rows = await supabase
          .from('admin_departments')
          .select('admin_id, department_id')
          .inFilter('admin_id', superAdminIds);
      final deptNameById = {for (final d in widget.departments) d['id']!: d['name'] ?? ''};
      final map = <String, List<String>>{};
      for (final r in rows) {
        final adminId = r['admin_id'] as String;
        final name = deptNameById[r['department_id']] ?? '';
        if (name.isEmpty) continue;
        map.putIfAbsent(adminId, () => []).add(name);
      }
      if (mounted) setState(() { _adminDeptNamesById = map; _loadingRefs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRefs = false);
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  void _downloadCurrentData() {
    if (_loadingRefs) return;
    final wb = _buildWorkbook();
    final raw = wb.encode();
    if (raw == null) return;
    triggerDownload(
      Uint8List.fromList(raw),
      'users_edit_export.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  String? _deptName(String? id) => id == null ? null : widget.departments.where((d) => d['id'] == id).firstOrNull?['name'];
  String? _placeName(String? id) => id == null ? null : widget.places.where((p) => p['id'] == id).firstOrNull?['name'];

  Excel _buildWorkbook() {
    final wb = Excel.createExcel();
    wb['Users'];
    wb.delete('Sheet1');
    final sheet = wb['Users'];

    final hdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF135467'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final refHdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF8A8A8A'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final customFieldHdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF1A6B45'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    const coreHeaders = [
      'ID (do not edit)',
      'Full Name *',
      'Email (reference only)',
      'Phone',
      'User Type *',
      'Place Name',
      'Department Name',
      'Departments (Super Admin, comma-separated)',
      'Branch Places (comma-separated)',
      'Is Active (TRUE/FALSE)',
    ];
    for (int c = 0; c < coreHeaders.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(coreHeaders[c]);
      cell.cellStyle = c == 0 || c == 2 ? refHdStyle : hdStyle;
    }
    for (int i = 0; i < widget.customFieldDefs.length; i++) {
      final def = widget.customFieldDefs[i];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: coreHeaders.length + i, rowIndex: 0));
      cell.value = TextCellValue(def.label);
      cell.cellStyle = customFieldHdStyle;
    }

    final users = _editableUsers;
    for (int r = 0; r < users.length; r++) {
      final u = users[r];
      final row = r + 1;
      void put(int col, String text) {
        if (text.isEmpty) return;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = TextCellValue(text);
      }
      put(0, u.id);
      put(1, u.fullName);
      put(2, u.email);
      put(3, u.phone ?? '');
      put(4, _typeLabel(u.userType));
      put(5, _placeName(u.placeId) ?? '');
      put(6, _deptName(u.departmentId) ?? '');
      put(7, (_adminDeptNamesById[u.id] ?? const []).join(', '));
      put(9, u.isActive ? 'TRUE' : 'FALSE');

      final values = widget.userFieldValues[u.id] ?? const [];
      for (int i = 0; i < widget.customFieldDefs.length; i++) {
        final def = widget.customFieldDefs[i];
        if (def.isComputed) continue;
        final v = values.where((x) => x.fieldId == def.id).firstOrNull?.displayValue;
        if (v != null) put(coreHeaders.length + i, v);
      }
    }

    for (int c = 0; c <= coreHeaders.length + widget.customFieldDefs.length - 1; c++) {
      sheet.setColumnAutoFit(c);
    }
    return wb;
  }

  // ── Parse ───────────────────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      _parseExcel(bytes);
    } catch (e) {
      if (mounted) setState(() => _parseError = 'Could not open file: $e');
    }
  }

  void _parseExcel(Uint8List bytes) {
    try {
      final wb = Excel.decodeBytes(bytes.toList());
      final sheet = wb.tables.values.first;
      final rows = sheet.rows;
      if (rows.length < 2) {
        setState(() => _parseError = 'No data rows found in the file.');
        return;
      }

      final coreCount = 10;
      final parsed = <_EditRow>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (_isRowEmpty(row)) continue;
        final id = _cell(row, 0);
        if (id.isEmpty) continue;

        final customVals = <String, String>{};
        for (int fi = 0; fi < widget.customFieldDefs.length; fi++) {
          final val = _cellOrNull(row, coreCount + fi);
          if (val != null) customVals[widget.customFieldDefs[fi].id] = val;
        }

        final editRow = _EditRow(
          excelRow: i + 1,
          id: id,
          fullName: _cell(row, 1),
          phone: _cellOrNull(row, 3),
          userType: _parseTypeLabel(_cellOrNull(row, 4)),
          rawPlace: _cellOrNull(row, 5),
          rawDepartment: _cellOrNull(row, 6),
          rawDepartments: _cellOrNull(row, 7),
          rawBranchPlaces: _cell(row, 8).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          isActive: _parseBool(_cellOrNull(row, 9)),
        );
        editRow.customFieldValues = customVals;
        parsed.add(editRow);
      }

      _validateRows(parsed);
      setState(() { _rows = parsed; _parseError = null; _stage = _Stage.preview; });
    } catch (e) {
      setState(() => _parseError = 'Failed to parse Excel file: $e');
    }
  }

  bool _isRowEmpty(List<Data?> row) =>
      row.every((c) => c == null || c.value == null || c.value.toString().trim().isEmpty);

  String _cell(List<Data?> row, int col) {
    if (col >= row.length || row[col] == null) return '';
    return (row[col]!.value?.toString() ?? '').trim();
  }

  String? _cellOrNull(List<Data?> row, int col) {
    final v = _cell(row, col);
    return v.isEmpty ? null : v;
  }

  // ── Validate ────────────────────────────────────────────────────────────────

  void _validateRows(List<_EditRow> rows) {
    final byId = {for (final u in widget.users) u.id: u};
    final placeByName = {for (final p in widget.places) (p['name'] ?? '').toLowerCase(): p['id']!};
    final deptByName = {for (final d in widget.departments) (d['name'] ?? '').toLowerCase(): d['id']!};
    final isSystemAdmin = widget.currentUser.userType == UserType.systemAdmin;

    for (final r in rows) {
      r.errors.clear();
      r.placeId = null;
      r.departmentId = null;
      r.departmentIds = [];
      r.branchPlaceIds = [];

      final original = byId[r.id];
      r.original = original;
      if (original == null) {
        r.errors.add('Unknown user ID (row not exported by this system)');
        continue;
      }
      if (!_canEditUser(widget.currentUser, original, widget.superAdminDepartmentIds)) {
        r.errors.add('You do not have permission to edit this user');
        continue;
      }

      if (r.fullName.trim().isEmpty) r.errors.add('Full name required');

      if (r.phone != null) {
        final norm = _normalizePhone(r.phone!);
        if (!norm.startsWith('+')) {
          r.errors.add('Invalid phone (use +972XXXXXXXXX or 0XXXXXXXXX)');
        } else {
          r.phone = norm;
        }
      }

      if (r.userType == null) {
        r.errors.add('Unknown user type');
      } else if (r.userType != original.userType && !isSystemAdmin) {
        r.errors.add('Only System Admin can change user type');
      }

      if (r.isActive == null) {
        r.errors.add('Invalid "Is Active" value');
      }

      if (r.userType != null && r.errors.isEmpty) {
        if (_needsPlace(r.userType!)) {
          final pid = r.rawPlace != null ? placeByName[r.rawPlace!.toLowerCase()] : null;
          if (pid == null) {
            r.errors.add(r.rawPlace == null ? 'Place required' : 'Place "${r.rawPlace}" not found');
          } else {
            r.placeId = pid;
          }
        }

        if (_needsDepartment(r.userType!)) {
          final did = r.rawDepartment != null ? deptByName[r.rawDepartment!.toLowerCase()] : null;
          if (did == null) {
            r.errors.add(r.rawDepartment == null ? 'Department required' : 'Department "${r.rawDepartment}" not found');
          } else {
            r.departmentId = did;
          }
        }

        if (r.userType == UserType.superAdmin && isSystemAdmin) {
          final names = (r.rawDepartments ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
          for (final n in names) {
            final did = deptByName[n.toLowerCase()];
            if (did == null) {
              r.errors.add('Department "$n" not found');
            } else {
              r.departmentIds.add(did);
            }
          }
          if (r.departmentIds.isEmpty) r.errors.add('At least one department required for Super Admin');
        }

        if (r.userType == UserType.branchAdmin) {
          for (final bp in r.rawBranchPlaces) {
            final pid = placeByName[bp.toLowerCase()];
            if (pid == null) {
              r.errors.add('Branch place "$bp" not found');
            } else {
              r.branchPlaceIds.add(pid);
            }
          }
        }
      }
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<void> _startUpdate() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    setState(() {
      _stage = _Stage.updating;
      _updateTotal = validRows.length;
      _updateDone = 0;
    });

    for (final row in validRows) {
      if (!mounted) break;
      try {
        await _updateOne(row);
        row.updated = true;
      } catch (e) {
        row.failed = true;
        row.updateError = _friendlyError(e.toString());
      }
      if (mounted) setState(() => _updateDone++);
    }

    if (mounted) {
      setState(() => _stage = _Stage.done);
      widget.onUsersUpdated();
    }
  }

  Future<void> _updateOne(_EditRow row) async {
    final data = <String, dynamic>{
      'full_name': row.fullName.trim(),
      'phone': row.phone,
      'user_type': row.userType!.value,
      'department_id': row.userType == UserType.admin ? row.departmentId : null,
      'place_id': _needsPlace(row.userType!) ? row.placeId : null,
      'is_active': row.isActive,
    };
    await supabase.from('users').update(data).eq('id', row.id);

    if (widget.currentUser.userType == UserType.systemAdmin && row.userType == UserType.superAdmin) {
      await supabase.from('admin_departments').delete().eq('admin_id', row.id);
      if (row.departmentIds.isNotEmpty) {
        await supabase.from('admin_departments').insert(row.departmentIds
            .map((d) => {'admin_id': row.id, 'department_id': d, 'created_by': widget.currentUser.id})
            .toList());
      }
    }

    if (row.userType == UserType.branchAdmin) {
      await supabase.from('branch_admin_places').delete().eq('admin_id', row.id);
      if (row.branchPlaceIds.isNotEmpty) {
        await supabase.from('branch_admin_places').insert(row.branchPlaceIds
            .map((p) => {'admin_id': row.id, 'place_id': p, 'created_by': widget.currentUser.id})
            .toList());
      }
    }

    if (row.customFieldValues.isNotEmpty) {
      await Future.wait(row.customFieldValues.entries.map((e) => UserFieldService.upsertValue(
            userId: row.id,
            fieldId: e.key,
            value: e.value,
            filledByUserId: widget.currentUser.id,
          )));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('permission')) return 'Permission denied';
    if (raw.length > 80) return '${raw.substring(0, 80)}…';
    return raw;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isAr),
              Flexible(child: _buildBody(isAr)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAr ? 'تعديل المستخدمين عبر Excel' : 'Edit Users via Excel',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isAr) {
    switch (_stage) {
      case _Stage.download: return _buildDownloadStage(isAr);
      case _Stage.preview:  return _buildPreviewStage(isAr);
      case _Stage.updating: return _buildUpdatingStage(isAr);
      case _Stage.done:     return _buildDoneStage(isAr);
    }
  }

  Widget _buildDownloadStage(bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepLabel('1', isAr ? 'تنزيل بيانات المستخدمين الحالية' : 'Download Current User Data'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'يحتوي الملف على ${_editableUsers.length} مستخدم يمكنك تعديلهم، مع معرّف (ID) لكل صف. لا تُعدّل أو تحذف عمود المعرّف — يُستخدم لمطابقة الصفوف عند الرفع.'
                          : 'The file includes ${_editableUsers.length} user(s) you can edit, each with an ID. Do not edit or remove the ID column — it is used to match rows on upload.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'عمود البريد الإلكتروني مرجعي فقط ولن يتم تحديثه. جميع الحقول الأخرى ستُحدَّث بما يطابق الملف تماماً.'
                      : 'The Email column is reference-only and will not be updated. Every other field will be updated to exactly match the file.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingRefs ? null : _downloadCurrentData,
              icon: _loadingRefs
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(isAr ? 'تنزيل بيانات المستخدمين (.xlsx)' : 'Download User Data (.xlsx)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          _stepLabel('2', isAr ? 'رفع الملف بعد التعديل' : 'Upload the Edited File'),
          const SizedBox(height: 12),
          if (_parseError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_parseError!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ]),
              ),
            ),
          InkWell(
            onTap: _pickAndParse,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withValues(alpha: 0.03),
              ),
              child: Column(children: [
                Icon(Icons.cloud_upload_outlined, size: 34, color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 8),
                Text(isAr ? 'انقر لتحديد ملف .xlsx' : 'Click to choose .xlsx file',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStage(bool isAr) {
    final valid = _rows.where((r) => r.isValid).length;
    final invalid = _rows.where((r) => !r.isValid).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          color: Colors.grey[50],
          child: Row(children: [
            if (valid > 0) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text('$valid ${isAr ? "جاهز للتحديث" : "ready to update"}',
                  style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
            ],
            if (invalid > 0) ...[
              const SizedBox(width: 12),
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text('$invalid ${isAr ? "به أخطاء (سيُتخطى)" : "with errors (skipped)"}',
                  style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() { _rows.clear(); _stage = _Stage.download; }),
              icon: const Icon(Icons.arrow_back, size: 14),
              label: Text(isAr ? 'تغيير الملف' : 'Change file', style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                columns: [
                  _col(isAr ? 'رقم' : 'Row'),
                  _col(isAr ? 'الاسم' : 'Name'),
                  _col(isAr ? 'النوع' : 'Type'),
                  _col(isAr ? 'المكان' : 'Place'),
                  _col(isAr ? 'القسم' : 'Dept'),
                  _col(isAr ? 'الحالة' : 'Active'),
                  _col(isAr ? 'النتيجة' : 'Status'),
                ],
                rows: _rows.map((r) => DataRow(
                  color: WidgetStateProperty.all(r.isValid ? null : Colors.red.withValues(alpha: 0.04)),
                  cells: [
                    DataCell(Text('${r.excelRow}', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    DataCell(Text(r.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    DataCell(Text(r.userType != null ? _typeLabel(r.userType!) : '?', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.rawPlace ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.rawDepartment ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.isActive == null ? '?' : (r.isActive! ? '✓' : '✗'), style: const TextStyle(fontSize: 12))),
                    DataCell(
                      r.isValid
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                          : Tooltip(
                              message: r.errors.join('\n'),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 15),
                                const SizedBox(width: 4),
                                Flexible(child: Text(r.errors.first, style: const TextStyle(fontSize: 10, color: Colors.red), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                    ),
                  ],
                )).toList(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إلغاء' : 'Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: valid == 0 ? null : _startUpdate,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(isAr ? 'تحديث $valid مستخدم' : 'Update $valid Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildUpdatingStage(bool isAr) {
    final pct = _updateTotal == 0 ? 0.0 : _updateDone / _updateTotal;
    final validRows = _rows.where((r) => r.isValid).toList();
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_sync_outlined, size: 44, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(isAr ? 'جاري التحديث...' : 'Updating users…', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$_updateDone / $_updateTotal', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey[200], color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Flexible(child: ListView.builder(shrinkWrap: true, itemCount: validRows.length, itemBuilder: (_, i) => _logTile(validRows[i]))),
        ],
      ),
    );
  }

  Widget _buildDoneStage(bool isAr) {
    final updated = _rows.where((r) => r.updated).length;
    final failed = _rows.where((r) => r.failed).length;
    final skipped = _rows.where((r) => !r.isValid).length;
    final failedRows = _rows.where((r) => r.failed).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: (updated > 0 ? Colors.green : Colors.orange).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(updated > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 36, color: updated > 0 ? Colors.green : Colors.orange),
          ),
          const SizedBox(height: 14),
          Text(isAr ? 'اكتمل التحديث' : 'Update Complete', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statChip('$updated', isAr ? 'تم تحديثهم' : 'Updated', Colors.green),
            if (failed > 0) ...[const SizedBox(width: 10), _statChip('$failed', isAr ? 'فشل' : 'Failed', Colors.red)],
            if (skipped > 0) ...[const SizedBox(width: 10), _statChip('$skipped', isAr ? 'تخطى' : 'Skipped', Colors.grey)],
          ]),
          if (failedRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: failedRows.length, itemBuilder: (_, i) => _logTile(failedRows[i]))),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(isAr ? 'إغلاق' : 'Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(String num, String label) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  DataColumn _col(String label) => DataColumn(label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)));

  Widget _logTile(_EditRow r) {
    Widget icon;
    if (r.updated) {
      icon = const Icon(Icons.check_circle, color: Colors.green, size: 16);
    } else if (r.failed) {
      icon = const Icon(Icons.cancel, color: Colors.red, size: 16);
    } else {
      icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(r.fullName, style: const TextStyle(fontSize: 12))),
        if (r.updateError != null) Text(r.updateError!, style: const TextStyle(fontSize: 10, color: Colors.red)),
      ]),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}
