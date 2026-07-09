import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'main.dart' show AppColors, supabase;
import 'models.dart';
import 'web_download.dart';

// ── Permission helpers ────────────────────────────────────────────────────────

List<UserType> _allowedTypes(UserType creator) {
  switch (creator) {
    case UserType.systemAdmin:
      return [UserType.superAdmin, UserType.admin, UserType.branchAdmin, UserType.superUser, UserType.user];
    case UserType.superAdmin:
      return [UserType.admin];
    case UserType.superUser:
      return [UserType.user];
    default:
      return [];
  }
}

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

// ── Row data model ────────────────────────────────────────────────────────────

class _ImportRow {
  final int excelRow;
  String fullName;
  String? email;
  String? phone;
  String? password;
  UserType? userType;
  String? rawPlace;
  String? rawDepartment;
  List<String> rawBranchPlaces;

  String? placeId;
  String? departmentId;
  List<String> branchPlaceIds = [];

  List<String> errors = [];
  bool get isValid => errors.isEmpty;

  bool imported = false;
  bool failed   = false;
  String? importError;

  _ImportRow({
    required this.excelRow,
    required this.fullName,
    this.email,
    this.phone,
    this.password,
    this.userType,
    this.rawPlace,
    this.rawDepartment,
    this.rawBranchPlaces = const [],
  });
}

// ── Main dialog ───────────────────────────────────────────────────────────────

class BulkImportUsersDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onUsersImported;

  const BulkImportUsersDialog({
    super.key,
    required this.currentUser,
    required this.onUsersImported,
  });

  @override
  State<BulkImportUsersDialog> createState() => _BulkImportUsersDialogState();
}

enum _Stage { download, preview, importing, done }

class _BulkImportUsersDialogState extends State<BulkImportUsersDialog> {
  _Stage _stage = _Stage.download;
  bool _includeExamples = true;

  List<PlaceModel>      _places      = [];
  List<DepartmentModel> _departments = [];
  bool _loadingRefs = true;

  List<_ImportRow> _rows = [];
  String? _parseError;

  int _importTotal = 0;
  int _importDone  = 0;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final ps = await supabase.from('places').select().order('name');
      final ds = await supabase.from('departments').select().order('name');
      if (mounted) {
        setState(() {
          _places      = ps.map<PlaceModel>((j) => PlaceModel.fromJson(j)).toList();
          _departments = ds.map<DepartmentModel>((j) => DepartmentModel.fromJson(j)).toList();
          _loadingRefs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRefs = false);
    }
  }

  // ── Template ────────────────────────────────────────────────────────────────

  void _downloadTemplate() {
    if (_loadingRefs) return;
    final wb = _buildWorkbook();
    final raw = wb.encode();
    if (raw == null) return;

    // Use the web download utility
    _triggerDownload(Uint8List.fromList(raw), 'user_import_template.xlsx');
  }

  void _triggerDownload(Uint8List bytes, String filename) {
    triggerDownload(
      bytes,
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Excel _buildWorkbook() {
    final wb = Excel.createExcel();
    // Must create the target sheet FIRST before deleting Sheet1,
    // because delete() is a no-op when only one sheet exists.
    wb['Import Data'];
    wb.delete('Sheet1');

    // Real data names with fallbacks
    final place1  = _places.isNotEmpty      ? _places.first.name      : 'Main Branch';
    final place2  = _places.length > 1      ? _places[1].name         : place1;
    final place3  = _places.length > 2      ? _places[2].name         : place2;
    final dept1   = _departments.isNotEmpty ? _departments.first.name : 'IT Department';
    final dept2   = _departments.length > 1 ? _departments[1].name    : dept1;
    final myPlace = _myPlaceName(place1);
    final allowed = _allowedTypes(widget.currentUser.userType);

    // ── Styles (full 8-char ARGB hex required by excel v4) ───────────────────
    final hdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF135467'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sideHdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FFF16936'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    final sideSubHdStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FFFDE8DC'),
      fontColorHex: ExcelColor.fromHexString('FFB45309'),
    );
    final sideDataStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF111111'),
    );
    final secStyle = CellStyle(
      bold: true,
      italic: true,
      fontColorHex: ExcelColor.fromHexString('FFB45309'),
    );
    final exStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('FF666666'),
    );
    final noteStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('FF135467'),
    );

    // ── Helper: write a cell only when text is non-empty ─────────────────────
    final sheet = wb['Import Data'];
    void putCell(Sheet s, int r, int c, String text, CellStyle style) {
      if (text.isEmpty) return;
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = TextCellValue(text);
      cell.cellStyle = style;
    }

    // ── Side reference tables (columns J=9, L=11, N=13) ──────────────────────
    // These are ignored by the parser because it only reads columns 0-7.
    // Column 8 (I) is left empty as a visual gap.

    // User Types table at column 9 (J)
    putCell(sheet, 0, 9,  'User Types',       sideHdStyle);
    putCell(sheet, 1, 9,  'Copy name exactly',sideSubHdStyle);
    const allTypes = [
      UserType.superAdmin,
      UserType.admin,
      UserType.branchAdmin,
      UserType.superUser,
      UserType.user,
    ];
    for (int i = 0; i < allTypes.length; i++) {
      putCell(sheet, i + 2, 9, _typeLabel(allTypes[i]), sideDataStyle);
    }

    // Place Names table at column 11 (L); column 10 (K) is gap
    putCell(sheet, 0, 11, 'Place Names',      sideHdStyle);
    putCell(sheet, 1, 11, 'Copy name exactly',sideSubHdStyle);
    for (int i = 0; i < _places.length; i++) {
      putCell(sheet, i + 2, 11, _places[i].name, sideDataStyle);
    }

    // Department Names table at column 13 (N); column 12 (M) is gap
    putCell(sheet, 0, 13, 'Department Names', sideHdStyle);
    putCell(sheet, 1, 13, 'Copy name exactly',sideSubHdStyle);
    for (int i = 0; i < _departments.length; i++) {
      putCell(sheet, i + 2, 13, _departments[i].name, sideDataStyle);
    }

    // ── Main import table headers (columns A-H = 0-7) ────────────────────────
    const headers = [
      'Full Name *',
      'Email',
      'Phone',
      'Password *',
      'User Type *',
      'Place Name',
      'Department Name',
      'Branch Places (comma-separated)',
    ];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = hdStyle;
    }

    // ── Example rows ─────────────────────────────────────────────────────────
    int row = 1;

    void exRow(List<String> cols) {
      for (int c = 0; c < cols.length; c++) {
        if (cols[c].isEmpty) continue;
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = TextCellValue(cols[c]);
        cell.cellStyle = exStyle;
      }
      row++;
    }

    if (_includeExamples) {
      putCell(sheet, row, 0,
          '# EXAMPLES: rows starting with # are skipped on import - delete or keep them',
          noteStyle);
      row += 2;

      for (final t in allowed) {
        switch (t) {
          case UserType.superAdmin:
            putCell(sheet, row, 0, '# -- Super Admin --', secStyle); row++;
            exRow(['# Ahmed Al-Rashid', 'ahmed@company.com', '',           'Pass@1234', 'Super Admin', '', dept1, '']);
            exRow(['# Fatima Nasser',   '',                  '0591000001', 'Pass@1234', 'Super Admin', '', dept2, '']);
          case UserType.admin:
            putCell(sheet, row, 0, '# -- Admin --', secStyle); row++;
            exRow(['# Sara Hassan', 'sara@company.com', '',           'Pass@1234', 'Admin', '', dept1, '']);
            exRow(['# Omar Khalid', '',                '0592000002', 'Pass@1234', 'Admin', '', dept2, '']);
          case UserType.superUser:
            putCell(sheet, row, 0, '# -- Super User --', secStyle); row++;
            exRow(['# Mohammed Ali', 'mohammed@company.com', '',           'Pass@1234', 'Super User', place1, '', '']);
            exRow(['# Rana Salim',   '',                     '0593000003', 'Pass@1234', 'Super User', place2, '', '']);
          case UserType.branchAdmin:
            putCell(sheet, row, 0, '# -- Branch Admin --', secStyle); row++;
            exRow(['# Layla Saeed',   'layla@company.com', '',           'Pass@1234', 'Branch Admin', place1, '', '$place1, $place2']);
            exRow(['# Yousef Hamdan', '',                  '0594000004', 'Pass@1234', 'Branch Admin', place2, '', place2]);
          case UserType.user:
            putCell(sheet, row, 0, '# -- User (email / phone / both) --', secStyle); row++;
            exRow(['# Khalid Omar', 'khalid@company.com', '',            'Pass@1234', 'User', myPlace, '', '']);
            exRow(['# Nour Saleh',  '',                   '0597000005', 'Pass@1234', 'User', myPlace, '', '']);
            exRow(['# Hana Adel',   'hana@company.com',   '0596000006', 'Pass@1234', 'User', place3,  '', '']);
          default:
            break;
        }
        row++;
      }

      putCell(sheet, row, 0, '# -- Your real data starts here --', noteStyle);
      row += 2;
    }

    // ── Auto-fit all used columns ─────────────────────────────────────────────
    // Main data columns A-H (0-7)
    for (int c = 0; c <= 7; c++) {
      sheet.setColumnAutoFit(c);
    }
    // Side reference table columns J(9), L(11), N(13) + their label columns
    for (final c in [9, 10, 11, 12, 13, 14]) {
      sheet.setColumnAutoFit(c);
    }

    return wb;
  }

  String _myPlaceName(String fallback) {
    final id = widget.currentUser.placeId;
    if (id == null) return fallback;
    for (final p in _places) {
      if (p.id == id) return p.name;
    }
    return fallback;
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

      final parsed = <_ImportRow>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (_isRowEmpty(row)) continue;
        final name = _cell(row, 0);
        // Skip example rows (#) and rows where col A is empty (side reference tables only have data in cols J+)
        if (name.isEmpty || name.startsWith('#')) continue;

        parsed.add(_ImportRow(
          excelRow:        i + 1,
          fullName:        name,
          email:           _cellOrNull(row, 1),
          phone:           _cellOrNull(row, 2),
          password:        _cellOrNull(row, 3),
          userType:        _parseTypeLabel(_cellOrNull(row, 4)),
          rawPlace:        _cellOrNull(row, 5),
          rawDepartment:   _cellOrNull(row, 6),
          rawBranchPlaces: _cell(row, 7)
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        ));
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

  void _validateRows(List<_ImportRow> rows) {
    final allowed = _allowedTypes(widget.currentUser.userType).toSet();
    final placeByName = <String, String>{};
    for (final p in _places) placeByName[p.name.toLowerCase()] = p.id;
    final deptByName = <String, String>{};
    for (final d in _departments) deptByName[d.name.toLowerCase()] = d.id;

    for (final r in rows) {
      r.errors.clear();
      r.placeId = null;
      r.departmentId = null;
      r.branchPlaceIds = [];

      if (r.fullName.trim().isEmpty) r.errors.add('Full name required');

      if (r.email == null && r.phone == null) {
        r.errors.add('Email or phone required');
      }
      if (r.email != null && !r.email!.contains('@')) {
        r.errors.add('Invalid email');
      }
      if (r.phone != null) {
        final norm = _normalizePhone(r.phone!);
        if (!norm.startsWith('+')) {
          r.errors.add('Invalid phone (use +972XXXXXXXXX or 0XXXXXXXXX)');
        } else {
          r.phone = norm;
        }
      }
      if (r.password == null || r.password!.length < 6) {
        r.errors.add('Password required (≥6 chars)');
      }
      if (r.userType == null) {
        r.errors.add('Unknown user type');
      } else if (!allowed.contains(r.userType)) {
        r.errors.add('Cannot create "${_typeLabel(r.userType!)}"');
      }

      if (r.userType != null && r.errors.isEmpty) {
        if (_needsPlace(r.userType!)) {
          if (widget.currentUser.userType == UserType.superUser) {
            r.placeId = widget.currentUser.placeId;
            if (r.placeId == null) r.errors.add('Your account has no place');
          } else {
            final pid = r.rawPlace != null ? placeByName[r.rawPlace!.toLowerCase()] : null;
            if (pid == null) {
              r.errors.add(r.rawPlace == null ? 'Place required' : 'Place "${r.rawPlace}" not found');
            } else {
              r.placeId = pid;
            }
          }
        }

        if (_needsDepartment(r.userType!)) {
          if (widget.currentUser.userType == UserType.superAdmin) {
            r.departmentId = widget.currentUser.departmentId;
            if (r.departmentId == null) r.errors.add('Your account has no department');
          } else {
            final did = r.rawDepartment != null ? deptByName[r.rawDepartment!.toLowerCase()] : null;
            if (did == null) {
              r.errors.add(r.rawDepartment == null ? 'Department required' : 'Department "${r.rawDepartment}" not found');
            } else {
              r.departmentId = did;
            }
          }
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

  bool _needsPlace(UserType t) =>
      t == UserType.superUser || t == UserType.user || t == UserType.branchAdmin;

  bool _needsDepartment(UserType t) =>
      t == UserType.superAdmin || t == UserType.admin;

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _startImport() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    setState(() {
      _stage = _Stage.importing;
      _importTotal = validRows.length;
      _importDone  = 0;
    });

    for (final row in validRows) {
      if (!mounted) break;
      try {
        await _createOne(row);
        row.imported = true;
      } catch (e) {
        row.failed = true;
        row.importError = _friendlyError(e.toString());
      }
      if (mounted) setState(() => _importDone++);
    }

    if (mounted) {
      setState(() => _stage = _Stage.done);
      widget.onUsersImported();
    }
  }

  Future<void> _createOne(_ImportRow row) async {
    final userData = {
      'full_name':      row.fullName.trim(),
      'user_type':      row.userType!.value,
      'department_id':  row.departmentId,
      'place_id':       row.placeId,
      'is_active':      true,
      'language':       'en',
    };

    final body = row.phone != null
        ? {'phone': row.phone, 'password': row.password, 'userData': userData}
        : {'email': row.email, 'password': row.password, 'userData': userData};

    final res = await supabase.functions.invoke(
      'create-user-admin',
      body: body,
      headers: {'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}'},
    );

    final data = res.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['message'] ?? 'Failed to create user');
    }

    // Assign branch places for branch admin users
    if (row.userType == UserType.branchAdmin && row.branchPlaceIds.isNotEmpty) {
      final newId = (data['user'] as Map<String, dynamic>?)?['id'] as String?;
      if (newId != null) {
        for (final pid in row.branchPlaceIds) {
          await supabase.from('branch_admin_places').upsert({
            'admin_id':   newId,
            'place_id':   pid,
            'created_by': supabase.auth.currentUser?.id,
          });
        }
      }
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already') || raw.contains('duplicate')) return 'Email/phone already exists';
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 8)),
            ],
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
        color: AppColors.secondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAr ? 'استيراد المستخدمين من Excel' : 'Import Users from Excel',
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
      case _Stage.download:  return _buildDownloadStage(isAr);
      case _Stage.preview:   return _buildPreviewStage(isAr);
      case _Stage.importing: return _buildImportingStage(isAr);
      case _Stage.done:      return _buildDoneStage(isAr);
    }
  }

  // ── Stage 1: Download ───────────────────────────────────────────────────────

  Widget _buildDownloadStage(bool isAr) {
    final allowed = _allowedTypes(widget.currentUser.userType);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepLabel('1', isAr ? 'تنزيل القالب' : 'Download Template'),
          const SizedBox(height: 12),
          // Info box
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
                Row(
                  children: [
                    const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(isAr ? 'أعمدة القالب:' : 'Template columns:',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    'Full Name *', 'Email', 'Phone', 'Password *',
                    'User Type *', 'Place Name', 'Department', 'Branch Places',
                  ].map((col) {
                    final isReq = col.endsWith('*');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isReq ? AppColors.primary : Colors.grey[500]!).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(col,
                          style: TextStyle(
                            fontSize: 11,
                            color: isReq ? AppColors.primary : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          )),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? 'أنواع المستخدمين المسموح بها: ${allowed.map(_typeLabel).join("، ")}'
                      : 'Allowed user types: ${allowed.map(_typeLabel).join(", ")}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.blue[400]),
                  const SizedBox(width: 5),
                  Text(
                    isAr
                        ? 'يمكن دمج المستخدمين بالبريد والجوال في نفس الملف'
                        : 'Email & phone users can be mixed freely in the same sheet',
                    style: TextStyle(fontSize: 11, color: Colors.blue[600], fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Examples toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: SwitchListTile(
              dense: true,
              title: Text(isAr ? 'تضمين أمثلة في القالب' : 'Include example rows in template',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(
                isAr
                    ? 'يُظهر مثالاً لكل نوع مستخدم (بالبريد والجوال) — الصفوف التي تبدأ بـ # تُتجاهل تلقائياً'
                    : 'Shows one example per user type (both email & phone) — rows starting with # are auto-skipped on import',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              value: _includeExamples,
              onChanged: (v) => setState(() => _includeExamples = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingRefs ? null : _downloadTemplate,
              icon: _loadingRefs
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(isAr ? 'تنزيل القالب (.xlsx)' : 'Download Template (.xlsx)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
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

          _stepLabel('2', isAr ? 'رفع الملف بعد ملئه' : 'Upload the Filled File'),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_parseError!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                  ],
                ),
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
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 34, color: AppColors.primary.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'انقر لتحديد ملف .xlsx' : 'Click to choose .xlsx file',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr ? 'Excel 2007 أو أحدث' : 'Excel 2007+ (.xlsx) only',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage 2: Preview ────────────────────────────────────────────────────────

  Widget _buildPreviewStage(bool isAr) {
    final valid   = _rows.where((r) => r.isValid).length;
    final invalid = _rows.where((r) => !r.isValid).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          color: Colors.grey[50],
          child: Row(
            children: [
              if (valid > 0) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text('$valid ${isAr ? "جاهز" : "ready"}',
                    style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
              ],
              if (invalid > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text('$invalid ${isAr ? "به أخطاء (ستُتخطى)" : "with errors (skipped)"}',
                    style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() { _rows.clear(); _stage = _Stage.download; }),
                icon: const Icon(Icons.arrow_back, size: 14),
                label: Text(isAr ? 'تغيير الملف' : 'Change file', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
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
                  _col(isAr ? 'البريد/الجوال' : 'Email / Phone'),
                  _col(isAr ? 'النوع' : 'Type'),
                  _col(isAr ? 'المكان' : 'Place'),
                  _col(isAr ? 'القسم' : 'Dept'),
                  _col(isAr ? 'الحالة' : 'Status'),
                ],
                rows: _rows.map((r) => DataRow(
                  color: WidgetStateProperty.all(
                    r.isValid ? null : Colors.red.withValues(alpha: 0.04),
                  ),
                  cells: [
                    DataCell(Text('${r.excelRow}', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                    DataCell(Text(r.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    DataCell(Text(r.email ?? r.phone ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.userType != null ? _typeLabel(r.userType!) : '?',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.rawPlace ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.rawDepartment ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      r.isValid
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                          : Tooltip(
                              message: r.errors.join('\n'),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 15),
                                const SizedBox(width: 4),
                                Flexible(child: Text(r.errors.first,
                                    style: const TextStyle(fontSize: 10, color: Colors.red),
                                    overflow: TextOverflow.ellipsis)),
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: valid == 0 ? null : _startImport,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(isAr ? 'استيراد $valid مستخدم' : 'Import $valid Users'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 3: Importing ──────────────────────────────────────────────────────

  Widget _buildImportingStage(bool isAr) {
    final pct = _importTotal == 0 ? 0.0 : _importDone / _importTotal;
    final validRows = _rows.where((r) => r.isValid).toList();
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 44, color: AppColors.primary),
          const SizedBox(height: 14),
          Text(isAr ? 'جاري الاستيراد...' : 'Importing users…',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$_importDone / $_importTotal', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: pct, minHeight: 8,
                backgroundColor: Colors.grey[200], color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: validRows.length,
              itemBuilder: (_, i) => _logTile(validRows[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage 4: Done ───────────────────────────────────────────────────────────

  Widget _buildDoneStage(bool isAr) {
    final created = _rows.where((r) => r.imported).length;
    final failed  = _rows.where((r) => r.failed).length;
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
            decoration: BoxDecoration(
              color: created > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              created > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 36,
              color: created > 0 ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 14),
          Text(isAr ? 'اكتمل الاستيراد' : 'Import Complete',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statChip('$created', isAr ? 'تم إنشاؤهم' : 'Created', Colors.green),
              if (failed > 0) ...[const SizedBox(width: 10), _statChip('$failed', isAr ? 'فشل' : 'Failed', Colors.red)],
              if (skipped > 0) ...[const SizedBox(width: 10), _statChip('$skipped', isAr ? 'تخطى' : 'Skipped', Colors.grey)],
            ],
          ),
          if (failedRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: failedRows.length,
                itemBuilder: (_, i) => _logTile(failedRows[i]),
              ),
            ),
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

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _stepLabel(String num, String label) {
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  DataColumn _col(String label) =>
      DataColumn(label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)));

  Widget _logTile(_ImportRow r) {
    Widget icon;
    if (r.imported) {
      icon = const Icon(Icons.check_circle, color: Colors.green, size: 16);
    } else if (r.failed) {
      icon = const Icon(Icons.cancel, color: Colors.red, size: 16);
    } else {
      icon = const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(r.fullName, style: const TextStyle(fontSize: 12))),
        if (r.importError != null)
          Text(r.importError!, style: const TextStyle(fontSize: 10, color: Colors.red)),
      ]),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

