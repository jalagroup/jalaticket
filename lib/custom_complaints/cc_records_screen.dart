// ═══════════════════════════════════════════════════════════════════════
//  cc_records_screen.dart  — Creator submissions dashboard
// ═══════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show AppColors;
import 'cc_models.dart';
import 'cc_service.dart';
import '_web_preview.dart' if (dart.library.io) '_web_preview_stub.dart';

enum _ViewMode { cards, table }

// ── Per-form view config ──────────────────────────────────────────────
// headerFieldIds: shown in compact card header (short-value types only)
// bodyFieldIds:   shown in expanded card body
// tableColIds:    shown as table columns
class _ViewConfig {
  List<String> headerFieldIds;
  List<String> bodyFieldIds;
  List<String> tableColIds;
  bool showStatusButtons;
  bool showDetailButton;
  bool allowNotes;

  _ViewConfig({
    required this.headerFieldIds,
    required this.bodyFieldIds,
    required this.tableColIds,
    this.showStatusButtons = true,
    this.showDetailButton  = true,
    this.allowNotes        = true,
  });

  static const _kPrefix = 'cc_view_cfg2_';
  static const _sys = ['submitter', 'status', 'date'];

  static bool _isHeaderCompatible(CcFieldType t) => const {
    CcFieldType.shortText,  CcFieldType.phone,      CcFieldType.yesNo,
    CcFieldType.singleSelect, CcFieldType.styledSelect,
    CcFieldType.rating,     CcFieldType.slider,
  }.contains(t);

  factory _ViewConfig.defaultFor(List<CcFormField> fields) {
    final headerCandidates = fields
        .where((f) => _isHeaderCompatible(f.fieldType))
        .take(3)
        .map((f) => f.id)
        .toList();
    final bodyCandidates = fields
        .where((f) => !headerCandidates.contains(f.id))
        .take(6)
        .map((f) => f.id)
        .toList();
    return _ViewConfig(
      headerFieldIds: headerCandidates,
      bodyFieldIds:   bodyCandidates,
      tableColIds:    ['submitter', ...headerCandidates.take(3), 'status', 'date'],
    );
  }

  factory _ViewConfig.fromJson(Map<String, dynamic> j) => _ViewConfig(
        headerFieldIds:    List<String>.from(j['headerFieldIds'] ?? j['cardFieldIds'] ?? []),
        bodyFieldIds:      List<String>.from(j['bodyFieldIds'] ?? []),
        tableColIds:       List<String>.from(j['tableColIds'] ?? []),
        showStatusButtons: j['showStatusButtons'] as bool? ?? true,
        showDetailButton:  j['showDetailButton']  as bool? ?? true,
        allowNotes:        j['allowNotes']        as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'headerFieldIds':    headerFieldIds,
        'bodyFieldIds':      bodyFieldIds,
        'tableColIds':       tableColIds,
        'showStatusButtons': showStatusButtons,
        'showDetailButton':  showDetailButton,
        'allowNotes':        allowNotes,
      };

  static Future<_ViewConfig> load(
      String formId, List<CcFormField> fields) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kPrefix + formId);
      if (raw != null) {
        final cfg =
            _ViewConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final ids = fields.map((f) => f.id).toSet();
        cfg.headerFieldIds =
            cfg.headerFieldIds.where((id) => ids.contains(id)).toList();
        cfg.bodyFieldIds =
            cfg.bodyFieldIds.where((id) => ids.contains(id)).toList();
        cfg.tableColIds = cfg.tableColIds
            .where((id) => ids.contains(id) || _sys.contains(id))
            .toList();
        if (cfg.headerFieldIds.isEmpty && fields.isNotEmpty) {
          cfg.headerFieldIds =
              _ViewConfig.defaultFor(fields).headerFieldIds;
        }
        if (cfg.tableColIds.isEmpty) {
          cfg.tableColIds = _ViewConfig.defaultFor(fields).tableColIds;
        }
        return cfg;
      }
    } catch (_) {}
    return _ViewConfig.defaultFor(fields);
  }

  Future<void> save(String formId) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPrefix + formId, jsonEncode(toJson()));
    } catch (_) {}
  }
}

// ── Status helpers ────────────────────────────────────────────────────
Color _statusClr(CcSubmissionStatus s) {
  switch (s) {
    case CcSubmissionStatus.pending:    return const Color(0xFFFF9800);
    case CcSubmissionStatus.resolved:   return const Color(0xFF4CAF50);
    case CcSubmissionStatus.misleading: return const Color(0xFFF44336);
  }
}

String _statusLbl(CcSubmissionStatus s, bool isAr) {
  switch (s) {
    case CcSubmissionStatus.pending:    return isAr ? 'انتظار'  : 'Pending';
    case CcSubmissionStatus.resolved:   return isAr ? 'محلول'   : 'Resolved';
    case CcSubmissionStatus.misleading: return isAr ? 'مضلل'    : 'Misleading';
  }
}

// ── Field-type icon ───────────────────────────────────────────────────
IconData _fieldIcon(CcFieldType t) {
  switch (t) {
    case CcFieldType.shortText:       return Icons.short_text_rounded;
    case CcFieldType.longText:        return Icons.notes_rounded;
    case CcFieldType.attachment:      return Icons.attach_file_rounded;
    case CcFieldType.imageAttachment: return Icons.image_outlined;
    case CcFieldType.singleSelect:    return Icons.arrow_drop_down_circle_outlined;
    case CcFieldType.multiSelect:     return Icons.checklist_rounded;
    case CcFieldType.checkboxGroup:   return Icons.check_box_outlined;
    case CcFieldType.radio:           return Icons.radio_button_checked_outlined;
    case CcFieldType.ranking:         return Icons.format_list_numbered_rounded;
    case CcFieldType.rating:          return Icons.star_outline_rounded;
    case CcFieldType.slider:          return Icons.tune_rounded;
    case CcFieldType.datePicker:      return Icons.calendar_today_outlined;
    case CcFieldType.timePicker:      return Icons.access_time_outlined;
    case CcFieldType.dateTimePicker:  return Icons.event_outlined;
    case CcFieldType.yesNo:           return Icons.thumbs_up_down_outlined;
    case CcFieldType.phone:           return Icons.phone_outlined;
    case CcFieldType.signature:       return Icons.draw_outlined;
    case CcFieldType.imageChoice:     return Icons.photo_library_outlined;
    case CcFieldType.styledSelect:    return Icons.label_rounded;
    default:                          return Icons.text_fields_rounded;
  }
}

// ── Display value (human-readable string for a field value) ───────────
String _displayVal(dynamic raw, CcFormField f, {bool isAr = false}) {
  if (raw == null) return '';
  switch (f.fieldType) {
    case CcFieldType.signature:
      final list = raw is List ? raw : null;
      if (list == null || list.isEmpty) return '';
      return isAr ? '✍ موقَّع' : '✍ Signed';
    case CcFieldType.yesNo:
      final b = raw is bool ? raw : raw.toString() == 'true';
      return b ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No');
    case CcFieldType.rating:
      return '$raw / ${f.config.ratingMax}';
    case CcFieldType.slider:
      final u = f.config.sliderUnit.isNotEmpty ? ' ${f.config.sliderUnit}' : '';
      return '$raw$u';
    case CcFieldType.attachment:
    case CcFieldType.imageAttachment:
      return '';
    case CcFieldType.datePicker:
      try {
        return _fmtDate(DateTime.parse(raw.toString()), isAr: isAr);
      } catch (_) { return raw.toString(); }
    case CcFieldType.timePicker:
      return raw.toString();
    case CcFieldType.dateTimePicker:
      try {
        return _fmtDateTime(DateTime.parse(raw.toString()), isAr: isAr);
      } catch (_) { return raw.toString(); }
    case CcFieldType.styledSelect:
      if (raw is! String || raw.isEmpty) return '';
      final match = f.config.styledSelectOptions
          .where((o) => o.id == raw)
          .toList();
      return match.isNotEmpty ? match.first.label : raw.toString();
    default:
      if (raw is List) return raw.join(', ');
      return raw.toString();
  }
}

// ── Locale-aware date helpers ─────────────────────────────────────────
const _kArMonths = [
  'يناير','فبراير','مارس','أبريل','مايو','يونيو',
  'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
];

String _fmtDate(DateTime dt, {bool isAr = false}) {
  final local = dt.toLocal();
  if (!isAr) return DateFormat('d MMM yyyy').format(local);
  return '${local.day} ${_kArMonths[local.month - 1]} ${local.year}';
}

String _fmtDateTime(DateTime dt, {bool isAr = false}) {
  final local = dt.toLocal();
  if (!isAr) return DateFormat('d MMM yyyy، HH:mm').format(local);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_kArMonths[local.month - 1]} ${local.year}، $h:$m';
}

String _fmtShortDateTime(DateTime dt, {bool isAr = false}) {
  final local = dt.toLocal();
  if (!isAr) return DateFormat('d MMM، HH:mm').format(local);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_kArMonths[local.month - 1]}، $h:$m';
}

// Short value for card/table cells
String _shortVal(CcSubmission s, CcFormField f, {bool isAr = false}) {
  final match = s.values.where((v) => v.fieldId == f.id);
  if (match.isEmpty) return '';
  return _displayVal(match.first.value, f, isAr: isAr);
}

// ── Signature helpers ─────────────────────────────────────────────────
List<List<Offset>> _parseSignature(dynamic raw) {
  if (raw is! List || raw.isEmpty) return [];
  try {
    final first = raw.first;
    if (first is! List || first.isEmpty) return [];
    final firstItem = first.first;

    if (firstItem is List) {
      // Nested [[x,y],[x,y],...] format — each stroke is a list of [x,y] pairs
      return raw.map<List<Offset>>((stroke) {
        if (stroke is! List) return <Offset>[];
        return stroke.map<Offset>((pt) {
          if (pt is! List || pt.length < 2) return Offset.zero;
          return Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }).toList();
      }).toList();
    } else if (firstItem is num) {
      // Flat [x1,y1,x2,y2,...] format — each stroke is an array of alternating x/y numbers
      return raw.map<List<Offset>>((stroke) {
        if (stroke is! List) return <Offset>[];
        final pts = <Offset>[];
        for (int i = 0; i + 1 < stroke.length; i += 2) {
          pts.add(Offset(
            (stroke[i] as num).toDouble(),
            (stroke[i + 1] as num).toDouble(),
          ));
        }
        return pts;
      }).toList();
    }
  } catch (_) {}
  return [];
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final stroke in strokes) {
      for (final pt in stroke) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }
    if (minX == double.infinity) return;
    const pad = 8.0;
    final dw = maxX - minX;
    final dh = maxY - minY;
    final sx = dw > 0 ? (size.width  - pad * 2) / dw : 1.0;
    final sy = dh > 0 ? (size.height - pad * 2) / dh : 1.0;
    final sc = sx < sy ? sx : sy;
    final ox = pad + (size.width  - pad * 2 - dw * sc) / 2 - minX * sc;
    final oy = pad + (size.height - pad * 2 - dh * sc) / 2 - minY * sc;

    final paint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(stroke[0].dx * sc + ox, stroke[0].dy * sc + oy),
          1.2, paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()
        ..moveTo(stroke[0].dx * sc + ox, stroke[0].dy * sc + oy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx * sc + ox, stroke[i].dy * sc + oy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.strokes != strokes;
}

// ═══════════════════════════════════════════════════════════════════════
//  Advanced filter model
// ═══════════════════════════════════════════════════════════════════════
enum _FilterOp {
  contains,
  equals,
  notEquals,
  greaterThan,
  lessThan,
  isIn,
  isEmpty,
  isNotEmpty,
}

class _FieldFilter {
  final String   fieldId; // 'status' | form-field id
  final _FilterOp op;
  final dynamic  value;   // String | num | Set<String> for isIn

  const _FieldFilter({required this.fieldId, required this.op, this.value});

  String chipLabel(List<CcFormField> fields, bool isAr) {
    final fieldName = _systemFieldName(fieldId, isAr) ??
        fields.firstWhere((f) => f.id == fieldId,
                orElse: () => fields.first)
            .label;
    final opLabel = _opLabel(op, isAr);
    final valLabel = switch (op) {
      _FilterOp.isEmpty     => '',
      _FilterOp.isNotEmpty  => '',
      _FilterOp.isIn        =>
          (value as Set<String>).take(2).join(', ') +
          ((value as Set<String>).length > 2 ? '…' : ''),
      _                     => value?.toString() ?? '',
    };
    return valLabel.isEmpty ? '$fieldName $opLabel' : '$fieldName $opLabel "$valLabel"';
  }

  static String? _systemFieldName(String id, bool isAr) => switch (id) {
    'status'    => isAr ? 'الحالة'   : 'Status',
    'submitter' => isAr ? 'المرسل'   : 'Submitter',
    'date'      => isAr ? 'التاريخ'  : 'Date',
    _           => null,
  };

  static String _opLabel(_FilterOp op, bool isAr) => switch (op) {
    _FilterOp.contains    => isAr ? 'يحتوي' : 'contains',
    _FilterOp.equals      => isAr ? '='     : '=',
    _FilterOp.notEquals   => isAr ? '≠'     : '≠',
    _FilterOp.greaterThan => '>',
    _FilterOp.lessThan    => '<',
    _FilterOp.isIn        => isAr ? 'ضمن'   : 'in',
    _FilterOp.isEmpty     => isAr ? 'فارغ'  : 'empty',
    _FilterOp.isNotEmpty  => isAr ? 'غير فارغ' : 'not empty',
  };
}

// ═══════════════════════════════════════════════════════════════════════
//  Main screen
// ═══════════════════════════════════════════════════════════════════════
class CcRecordsScreen extends StatefulWidget {
  final String formId;
  const CcRecordsScreen({super.key, required this.formId});

  @override
  State<CcRecordsScreen> createState() => _CcRecordsScreenState();
}

class _CcRecordsScreenState extends State<CcRecordsScreen> {
  CcForm?                _form;
  List<CcSubmission>     _submissions  = [];
  bool                   _loading      = true;
  bool                   _loadingMore  = false;
  _ViewMode              _viewMode     = _ViewMode.cards;
  CcSubmissionStatus?    _statusFilter;
  String?                _searchFieldId;
  final _searchCtrl      = TextEditingController();
  Timer?                 _searchDebounce;
  Timer?                 _autoRefreshTimer;
  final Set<String>      _selectedIds  = {};
  int                    _page         = 0;
  static const _pageSize = 50;
  bool                   _hasMore      = true;
  _ViewConfig?           _viewConfig;
  bool                   _showConfig   = false;
  String?                _detailSubId;
  String?                _sortCol;
  bool                   _sortAsc      = false;
  List<_FieldFilter>     _activeFilters = [];
  String?                _qfFieldId;   // quick-filter field
  String?                _qfValue;     // quick-filter value

  List<CcFormField> get _allFields => (_form?.steps ?? [])
      .expand((s) => s.sections.expand((sec) => sec.fields))
      .where((f) => !f.fieldType.isDisplayOnly)
      .toList();

  Color get _themeColor {
    try {
      final hex = _form!.themeColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) { return AppColors.primary; }
  }

  // Cached sorted+filtered list — updated by _recompute(), never in build()
  List<CcSubmission> _filteredCache = [];

  void _recompute() {
    // Sort
    List<CcSubmission> sorted;
    if (_sortCol == null) {
      sorted = _submissions;
    } else {
      sorted = List<CcSubmission>.from(_submissions);
      final fm = {for (final f in _allFields) f.id: f};
      sorted.sort((a, b) {
        int cmp;
        switch (_sortCol) {
          case 'date':
            cmp = a.createdAt.compareTo(b.createdAt);
          case 'status':
            cmp = a.status.value.compareTo(b.status.value);
          case 'submitter':
            cmp = (a.submitterFullName ?? '')
                .compareTo(b.submitterFullName ?? '');
          default:
            final f = fm[_sortCol!];
            if (f == null) { cmp = 0; break; }
            cmp = _shortVal(a, f).compareTo(_shortVal(b, f));
        }
        return _sortAsc ? cmp : -cmp;
      });
    }
    // Filter
    List<CcSubmission> filtered = sorted;
    if (_activeFilters.isNotEmpty) {
      final fm = {for (final f in _allFields) f.id: f};
      filtered = filtered
          .where((s) => _activeFilters.every((f) => _matchFilter(s, f, fm)))
          .toList();
    }
    if (_qfFieldId != null && _qfValue != null && _qfValue!.isNotEmpty) {
      final fm = {for (final f in _allFields) f.id: f};
      filtered = filtered.where((s) => _matchFilter(
        s,
        _FieldFilter(fieldId: _qfFieldId!, op: _FilterOp.equals, value: _qfValue),
        fm,
      )).toList();
    }
    _filteredCache = filtered;
  }

  bool _matchFilter(CcSubmission s, _FieldFilter filter, Map<String, CcFormField> fm) {
    // ── system fields ──────────────────────────────────────
    if (filter.fieldId == 'status') {
      final sv = s.status.value;
      return switch (filter.op) {
        _FilterOp.isIn      => (filter.value as Set<String>).contains(sv),
        _FilterOp.equals    => sv == filter.value,
        _FilterOp.notEquals => sv != filter.value,
        _                   => true,
      };
    }
    if (filter.fieldId == 'submitter') {
      final sv = s.isAnonymous ? 'Anonymous' : (s.submitterFullName ?? '');
      return switch (filter.op) {
        _FilterOp.contains    => sv.toLowerCase().contains((filter.value as String).toLowerCase()),
        _FilterOp.equals      => sv == filter.value,
        _FilterOp.notEquals   => sv != filter.value,
        _FilterOp.isEmpty     => sv.isEmpty,
        _FilterOp.isNotEmpty  => sv.isNotEmpty,
        _                     => true,
      };
    }
    // ── form fields ────────────────────────────────────────
    final field = fm[filter.fieldId];
    if (field == null) return true;
    final raw    = s.values.where((v) => v.fieldId == filter.fieldId).firstOrNull?.value;
    final strVal = raw == null ? '' : _displayVal(raw, field);
    switch (filter.op) {
      case _FilterOp.contains:
        return strVal.toLowerCase().contains((filter.value as String).toLowerCase());
      case _FilterOp.equals:
        return strVal == filter.value?.toString();
      case _FilterOp.notEquals:
        return strVal != filter.value?.toString();
      case _FilterOp.greaterThan:
        final n  = double.tryParse(strVal);
        final fv = double.tryParse(filter.value?.toString() ?? '');
        return n != null && fv != null && n > fv;
      case _FilterOp.lessThan:
        final n  = double.tryParse(strVal);
        final fv = double.tryParse(filter.value?.toString() ?? '');
        return n != null && fv != null && n < fv;
      case _FilterOp.isIn:
        return (filter.value as Set<String>).contains(strVal);
      case _FilterOp.isEmpty:
        return strVal.isEmpty;
      case _FilterOp.isNotEmpty:
        return strVal.isNotEmpty;
    }
  }

  // Unique display values for a field across all loaded submissions
  Set<String> _uniqueValues(String fieldId) {
    final fm = {for (final f in _allFields) f.id: f};
    if (fieldId == 'status') return _submissions.map((s) => s.status.value).toSet();
    final field = fm[fieldId];
    if (field == null) return {};
    return _submissions
        .map((s) {
          final raw = s.values.where((v) => v.fieldId == fieldId).firstOrNull?.value;
          return raw == null ? '' : _displayVal(raw, field);
        })
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  void _openFilterDialog() async {
    final result = await showDialog<List<_FieldFilter>>(
      context: context,
      builder: (_) => _AdvancedFilterDialog(
        fields: _allFields,
        submissions: _submissions,
        current: List.from(_activeFilters),
        isAr: Localizations.localeOf(context).languageCode == 'ar',
        themeColor: _themeColor,
        uniqueValues: _uniqueValues,
      ),
    );
    if (result != null) setState(() { _activeFilters = result; _recompute(); });
  }

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_onSearch);
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_loading && !_loadingMore) {
        _loadSubmissions(reset: true, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _onSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420),
        () => _loadSubmissions(reset: true));
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final form = await CcService.getFullForm(widget.formId);
    if (!mounted) return;
    setState(() => _form = form);
    if (form != null) {
      final cfg = await _ViewConfig.load(widget.formId, _allFields);
      if (mounted) setState(() => _viewConfig = cfg);
    }
    await _loadSubmissions(reset: true);
  }

  Future<void> _loadSubmissions(
      {bool reset = false, bool silent = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
      // Keep old rows visible during silent refresh — avoids the blink/null flash
      if (!silent && mounted) setState(() { _submissions = []; _recompute(); });
    }
    if (mounted && !silent) setState(() => _loading = true);
    final rows = await CcService.getSubmissionsForForm(
      widget.formId,
      page: _page,
      pageSize: _pageSize,
      statusFilter: _statusFilter?.value,
      searchQuery: _searchCtrl.text.trim().isEmpty
          ? null
          : _searchCtrl.text.trim(),
      searchFieldId: _searchFieldId,
    );
    if (rows.isNotEmpty) await CcService.loadValuesForSubmissions(rows);
    if (!mounted) return;
    setState(() {
      if (reset) { _submissions = rows; } else { _submissions.addAll(rows); }
      _hasMore      = rows.length == _pageSize;
      _loading      = false;
      _loadingMore  = false;
      _recompute();
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading || _loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    await _loadSubmissions();
  }

  Future<void> _bulkUpdate(CcSubmissionStatus status) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    setState(() => _selectedIds.clear());
    await CcService.bulkUpdateStatus(ids, status);
    await _loadSubmissions(reset: true);
  }

  void _openDetail(CcSubmission s) =>
      setState(() { _showConfig = false; _detailSubId = s.id; });

  void _closeDetail() => setState(() => _detailSubId = null);

  Future<void> _onDetailStatusChanged() => _loadSubmissions(reset: true);

  void _saveConfig() => _viewConfig?.save(widget.formId);

  void _setSort(String col) {
    setState(() {
      if (_sortCol == col) { _sortAsc = !_sortAsc; }
      else { _sortCol = col; _sortAsc = false; }
      _recompute();
    });
  }

  void _clearSort() => setState(() { _sortCol = null; _sortAsc = false; _recompute(); });

  @override
  Widget build(BuildContext context) {
    final isAr       = Localizations.localeOf(context).languageCode == 'ar';
    final tc         = _themeColor;
    final allFields  = _allFields;
    final cfg        = _viewConfig ?? _ViewConfig.defaultFor(allFields);
    final sideOpen   = _showConfig || _detailSubId != null;
    final w          = MediaQuery.of(context).size.width;
    final sideW      = w < 700 ? w * 0.92 : 400.0;
    final sorted     = _filteredCache;

    if (_form == null && _loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade800,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _form?.title ?? (isAr ? 'السجلات' : 'Records'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            if (_submissions.isNotEmpty)
              Text(
                '${_submissions.length}${_hasMore ? '+' : ''} '
                    '${isAr ? 'سجل' : 'records'}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          // Refresh
          Tooltip(
            message: isAr ? 'تحديث' : 'Refresh',
            child: IconButton(
              onPressed: _loading ? null : () => _loadSubmissions(reset: true),
              icon: _loading
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: tc))
                  : Icon(Icons.refresh_rounded,
                      size: 18, color: Colors.grey.shade600),
            ),
          ),
          // View toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _viewBtn(Icons.grid_view_rounded, _ViewMode.cards,
                  isAr ? 'بطاقات' : 'Cards'),
              _viewBtn(Icons.table_rows_rounded, _ViewMode.table,
                  isAr ? 'جدول' : 'Table'),
            ]),
          ),
          // Customize
          Tooltip(
            message: isAr ? 'تخصيص العرض' : 'Customize view',
            child: InkWell(
              onTap: () => setState(() {
                _showConfig = !_showConfig;
                if (_showConfig) _detailSubId = null;
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _showConfig
                      ? tc.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                      color: _showConfig
                          ? tc.withValues(alpha: 0.3)
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.tune_rounded,
                      size: 15,
                      color: _showConfig ? tc : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(isAr ? 'تخصيص' : 'Customize',
                      style: TextStyle(
                          fontSize: 12,
                          color: _showConfig ? tc : Colors.grey.shade600,
                          fontWeight: _showConfig
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        _FilterBar(
          isAr: isAr,
          searchCtrl: _searchCtrl,
          statusFilter: _statusFilter,
          fields: allFields,
          searchFieldId: _searchFieldId,
          themeColor: tc,
          sortCol: _sortCol,
          sortAsc: _sortAsc,
          activeFilterCount: _activeFilters.length,
          onStatusChanged: (s) {
            setState(() { _statusFilter = s; _selectedIds.clear(); });
            _loadSubmissions(reset: true);
          },
          onFieldChanged: (id) {
            setState(() => _searchFieldId = id);
            _loadSubmissions(reset: true);
          },
          onSort: _setSort,
          onClearSort: _clearSort,
          onOpenFilters: _openFilterDialog,
        ),
        // Quick-filter row (field + value dropdowns)
        _QuickFilterBar(
          fields: allFields,
          isAr: isAr,
          themeColor: tc,
          selectedFieldId: _qfFieldId,
          selectedValue: _qfValue,
          uniqueValues: _uniqueValues,
          onChanged: (fid, val) =>
              setState(() { _qfFieldId = fid; _qfValue = val; _recompute(); }),
          onClear: () =>
              setState(() { _qfFieldId = null; _qfValue = null; _recompute(); }),
        ),
        if (_selectedIds.isNotEmpty)
          _BulkBar(
            count: _selectedIds.length,
            isAr: isAr,
            themeColor: tc,
            onStatus: _bulkUpdate,
            onClear: () => setState(() => _selectedIds.clear()),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _loading && _submissions.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : sorted.isEmpty
                        ? _emptyState(isAr)
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 300) {
                                _loadMore();
                              }
                              return false;
                            },
                            child: _viewMode == _ViewMode.table
                                ? _TableArea(
                                    submissions: sorted,
                                    fields: allFields,
                                    cfg: cfg,
                                    selectedIds: _selectedIds,
                                    isAr: isAr,
                                    themeColor: tc,
                                    loadingMore: _loadingMore,
                                    sortCol: _sortCol,
                                    sortAsc: _sortAsc,
                                    allSelected: sorted.isNotEmpty &&
                                        sorted.every((s) =>
                                            _selectedIds.contains(s.id)),
                                    onToggle: _toggle,
                                    onOpen: _openDetail,
                                    onSort: _setSort,
                                    onToggleAll: () {
                                      setState(() {
                                        if (sorted.every((s) =>
                                            _selectedIds.contains(s.id))) {
                                          _selectedIds.removeAll(
                                              sorted.map((s) => s.id));
                                        } else {
                                          _selectedIds.addAll(
                                              sorted.map((s) => s.id));
                                        }
                                      });
                                    },
                                    onStatusChange: (id, st) async {
                                      await CcService.updateSubmissionStatus(id, st);
                                      _loadSubmissions(reset: true);
                                    },
                                  )
                                : _CardGrid(
                                    submissions: sorted,
                                    fields: allFields,
                                    cfg: cfg,
                                    selectedIds: _selectedIds,
                                    isAr: isAr,
                                    themeColor: tc,
                                    loadingMore: _loadingMore,
                                    allSelected: sorted.isNotEmpty &&
                                        sorted.every((s) => _selectedIds.contains(s.id)),
                                    onToggle: _toggle,
                                    onOpen: _openDetail,
                                    onToggleAll: () {
                                      setState(() {
                                        if (sorted.every((s) => _selectedIds.contains(s.id))) {
                                          _selectedIds.removeAll(sorted.map((s) => s.id));
                                        } else {
                                          _selectedIds.addAll(sorted.map((s) => s.id));
                                        }
                                      });
                                    },
                                  ),
                          ),
              ),
              if (sideOpen)
                Container(
                  width: sideW,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        left: BorderSide(color: Colors.grey.shade200)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(-2, 0))
                    ],
                  ),
                  child: _showConfig
                      ? _ConfigPanel(
                          fields: allFields,
                          cfg: cfg,
                          isAr: isAr,
                          themeColor: tc,
                          onClose: () => setState(() => _showConfig = false),
                          onChanged: () {
                            setState(() {});
                            _saveConfig();
                          },
                        )
                      : _DetailPanel(
                          key: ValueKey(_detailSubId),
                          submissionId: _detailSubId!,
                          fields: allFields,
                          isAr: isAr,
                          themeColor: tc,
                          onClose: _closeDetail,
                          onStatusChanged: _onDetailStatusChanged,
                        ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  void _toggle(String id) => setState(() {
        if (_selectedIds.contains(id)) { _selectedIds.remove(id); }
        else { _selectedIds.add(id); }
      });

  Widget _viewBtn(IconData icon, _ViewMode mode, String tip) {
    final active = _viewMode == mode;
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4)]
                : null,
          ),
          child: Icon(icon,
              size: 16,
              color: active ? Colors.grey.shade800 : Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _emptyState(bool isAr) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(isAr ? 'لا توجد سجلات' : 'No submissions yet',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          if (_statusFilter != null || _searchCtrl.text.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _statusFilter = null; _searchFieldId = null; });
                _loadSubmissions(reset: true);
              },
              child: Text(isAr ? 'مسح الفلاتر' : 'Clear filters',
                  style: const TextStyle(fontSize: 13)),
            ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  Filter bar  (search + status + sort)
// ═══════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final bool isAr;
  final TextEditingController searchCtrl;
  final CcSubmissionStatus?   statusFilter;
  final List<CcFormField>     fields;
  final String?               searchFieldId;
  final Color                 themeColor;
  final String?               sortCol;
  final bool                  sortAsc;
  final int                   activeFilterCount;
  final ValueChanged<CcSubmissionStatus?> onStatusChanged;
  final ValueChanged<String?>             onFieldChanged;
  final ValueChanged<String>              onSort;
  final VoidCallback                      onClearSort;
  final VoidCallback                      onOpenFilters;

  const _FilterBar({
    required this.isAr,
    required this.searchCtrl,
    required this.statusFilter,
    required this.fields,
    required this.searchFieldId,
    required this.themeColor,
    required this.sortCol,
    required this.sortAsc,
    required this.activeFilterCount,
    required this.onStatusChanged,
    required this.onFieldChanged,
    required this.onSort,
    required this.onClearSort,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final tc = themeColor;
    // Build sortable columns list
    final sortCols = <MapEntry<String, String>>[
      MapEntry('date',      isAr ? 'التاريخ'  : 'Date'),
      MapEntry('submitter', isAr ? 'المرسل'   : 'Submitter'),
      MapEntry('status',    isAr ? 'الحالة'   : 'Status'),
      ...fields.map((f) => MapEntry(f.id, f.label)),
    ];
    final currentSortLabel = sortCol == null
        ? (isAr ? 'الترتيب' : 'Sort')
        : sortCols.firstWhere((e) => e.key == sortCol,
              orElse: () => MapEntry(sortCol!, sortCol!))
            .value;

    return Container(
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Row 1: search + field filter + status chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            // Search
            Flexible(
              flex: 4,
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isAr ? 'بحث في السجلات...' : 'Search records...',
                    hintStyle: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: Colors.grey.shade400),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 14, color: Colors.grey.shade400),
                            onPressed: searchCtrl.clear,
                            padding: EdgeInsets.zero)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tc, width: 1.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Field selector
            if (fields.isNotEmpty)
              Flexible(
                flex: 2,
                child: SizedBox(
                  height: 34,
                  child: DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String?>(
                        value: searchFieldId,
                        isExpanded: true,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                        hint: Text(isAr ? 'كل الحقول' : 'All fields',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Colors.grey.shade400),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text(
                                  isAr ? 'كل الحقول' : 'All fields',
                                  style: const TextStyle(fontSize: 12))),
                          ...fields.map((f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(f.label,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: onFieldChanged,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        // ── Row 2: status chips + sort ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(children: [
            // Status chips
            _SChip(
                label: isAr ? 'الكل' : 'All',
                selected: statusFilter == null,
                color: Colors.grey.shade700,
                onTap: () => onStatusChanged(null)),
            const SizedBox(width: 4),
            for (final s in CcSubmissionStatus.values) ...[
              _SChip(
                  label: _statusLbl(s, isAr),
                  selected: statusFilter == s,
                  color: _statusClr(s),
                  onTap: () => onStatusChanged(s)),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 8),
            // Divider
            Container(width: 1, height: 18, color: Colors.grey.shade200),
            const SizedBox(width: 8),
            // Sort dropdown
            PopupMenuButton<String>(
              tooltip: isAr ? 'ترتيب حسب' : 'Sort by',
              offset: const Offset(0, 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sortCol != null
                      ? tc.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sortCol != null
                          ? tc.withValues(alpha: 0.3)
                          : Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sort_rounded,
                      size: 13,
                      color: sortCol != null ? tc : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(currentSortLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              sortCol != null ? tc : Colors.grey.shade600,
                          fontWeight: sortCol != null
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  if (sortCol != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: tc,
                    ),
                  ] else ...[
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 13, color: Colors.grey.shade400),
                  ],
                ]),
              ),
              itemBuilder: (_) => [
                if (sortCol != null)
                  PopupMenuItem(
                    value: '__clear__',
                    child: Row(children: [
                      Icon(Icons.clear_rounded,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(isAr ? 'إلغاء الترتيب' : 'Clear sort',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ]),
                  ),
                for (final col in sortCols)
                  PopupMenuItem(
                    value: col.key,
                    child: Row(children: [
                      Icon(
                        sortCol == col.key
                            ? (sortAsc
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded)
                            : Icons.remove_rounded,
                        size: 13,
                        color: sortCol == col.key
                            ? tc
                            : Colors.grey.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(col.value,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: sortCol == col.key
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: sortCol == col.key
                                  ? tc
                                  : Colors.black87)),
                    ]),
                  ),
              ],
              onSelected: (v) {
                if (v == '__clear__') {
                  onClearSort();
                } else {
                  onSort(v);
                }
              },
            ),
            const SizedBox(width: 8),
            // Advanced filters button
            GestureDetector(
              onTap: onOpenFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: activeFilterCount > 0
                      ? tc.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: activeFilterCount > 0
                          ? tc.withValues(alpha: 0.3)
                          : Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_list_rounded,
                      size: 13,
                      color: activeFilterCount > 0 ? tc : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(isAr ? 'فلاتر' : 'Filters',
                      style: TextStyle(
                          fontSize: 11,
                          color: activeFilterCount > 0 ? tc : Colors.grey.shade600,
                          fontWeight: activeFilterCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  if (activeFilterCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: tc, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('$activeFilterCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;
  const _SChip({required this.label, required this.selected,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.4)
                    : Colors.grey.shade300,
                width: selected ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : Colors.grey.shade600)),
        ),
      );
}

// ── Bulk bar ──────────────────────────────────────────────────────────
class _BulkBar extends StatelessWidget {
  final int    count;
  final bool   isAr;
  final Color  themeColor;
  final void Function(CcSubmissionStatus) onStatus;
  final VoidCallback onClear;
  const _BulkBar({required this.count, required this.isAr,
      required this.themeColor, required this.onStatus,
      required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
        color: themeColor.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(isAr ? 'محدد' : 'selected',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 10),
          _bb(Icons.check_circle_outline_rounded,
              isAr ? 'محلول' : 'Resolved', const Color(0xFF4CAF50),
              () => onStatus(CcSubmissionStatus.resolved)),
          _bb(Icons.flag_outlined,
              isAr ? 'مضلل' : 'Misleading', const Color(0xFFF44336),
              () => onStatus(CcSubmissionStatus.misleading)),
          _bb(Icons.hourglass_empty_rounded,
              isAr ? 'انتظار' : 'Pending', const Color(0xFFFF9800),
              () => onStatus(CcSubmissionStatus.pending)),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero),
            child: Text(isAr ? 'إلغاء' : 'Clear',
                style: const TextStyle(fontSize: 12)),
          ),
        ]),
      );

  Widget _bb(IconData icon, String label, Color color, VoidCallback onTap) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      );
}

// ── Status badge ──────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final CcSubmissionStatus status;
  final bool isAr;
  const _StatusBadge({required this.status, required this.isAr});

  static IconData _icon(CcSubmissionStatus s) {
    switch (s) {
      case CcSubmissionStatus.pending:    return Icons.hourglass_empty_rounded;
      case CcSubmissionStatus.resolved:   return Icons.check_circle_outline_rounded;
      case CcSubmissionStatus.misleading: return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _statusClr(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon(status), size: 10, color: c),
        const SizedBox(width: 4),
        Text(_statusLbl(status, isAr),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Advanced filter dialog
// ═══════════════════════════════════════════════════════════════════════
class _AdvancedFilterDialog extends StatefulWidget {
  final List<CcFormField>   fields;
  final List<CcSubmission>  submissions;
  final List<_FieldFilter>  current;
  final bool                isAr;
  final Color               themeColor;
  final Set<String> Function(String fieldId) uniqueValues;

  const _AdvancedFilterDialog({
    required this.fields,
    required this.submissions,
    required this.current,
    required this.isAr,
    required this.themeColor,
    required this.uniqueValues,
  });

  @override
  State<_AdvancedFilterDialog> createState() => _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends State<_AdvancedFilterDialog> {
  late List<_FieldFilter> _filters;

  // "add filter" form state
  String?   _addFieldId;
  _FilterOp _addOp       = _FilterOp.contains;
  String    _addText     = '';
  final Set<String> _addSelected = {};
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = List.from(widget.current);
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  // ── field type helpers ──────────────────────────────────
  bool _isMultiSelect(String? fieldId) {
    if (fieldId == 'status') return true;
    final f = widget.fields.firstWhere((f) => f.id == fieldId,
        orElse: () => widget.fields.first);
    return const {
      CcFieldType.singleSelect, CcFieldType.styledSelect,
      CcFieldType.radio, CcFieldType.yesNo,
    }.contains(f.fieldType);
  }

  bool _isNumeric(String? fieldId) {
    if (fieldId == null || fieldId == 'status' || fieldId == 'submitter') return false;
    final f = widget.fields.firstWhere((f) => f.id == fieldId,
        orElse: () => widget.fields.first);
    return const {
      CcFieldType.rating, CcFieldType.slider,
    }.contains(f.fieldType) ||
        (f.fieldType == CcFieldType.shortText && f.config.subtype == 'number');
  }

  List<_FilterOp> _opsFor(String? fieldId) {
    if (fieldId == null) return [_FilterOp.contains];
    if (_isMultiSelect(fieldId)) return [_FilterOp.isIn, _FilterOp.isEmpty, _FilterOp.isNotEmpty];
    if (_isNumeric(fieldId))     return [_FilterOp.equals, _FilterOp.notEquals, _FilterOp.greaterThan, _FilterOp.lessThan, _FilterOp.isEmpty, _FilterOp.isNotEmpty];
    return [_FilterOp.contains, _FilterOp.equals, _FilterOp.notEquals, _FilterOp.isEmpty, _FilterOp.isNotEmpty];
  }

  String _opName(_FilterOp op) => switch (op) {
    _FilterOp.contains    => widget.isAr ? 'يحتوي على' : 'contains',
    _FilterOp.equals      => widget.isAr ? 'يساوي' : 'equals',
    _FilterOp.notEquals   => widget.isAr ? 'لا يساوي' : 'not equals',
    _FilterOp.greaterThan => widget.isAr ? 'أكبر من' : 'greater than',
    _FilterOp.lessThan    => widget.isAr ? 'أصغر من' : 'less than',
    _FilterOp.isIn        => widget.isAr ? 'ضمن الاختيارات' : 'is one of',
    _FilterOp.isEmpty     => widget.isAr ? 'فارغ' : 'is empty',
    _FilterOp.isNotEmpty  => widget.isAr ? 'غير فارغ' : 'is not empty',
  };

  String _fieldName(String fieldId) {
    if (fieldId == 'status')    return widget.isAr ? 'الحالة'  : 'Status';
    if (fieldId == 'submitter') return widget.isAr ? 'المرسل'  : 'Submitter';
    return widget.fields.firstWhere((f) => f.id == fieldId,
        orElse: () => widget.fields.first).label;
  }

  void _onFieldChanged(String? id) {
    setState(() {
      _addFieldId = id;
      _addSelected.clear();
      _textCtrl.clear();
      _addText = '';
      final ops = _opsFor(id);
      _addOp = ops.first;
    });
  }

  void _addFilter() {
    if (_addFieldId == null) return;
    dynamic val;
    if (_addOp == _FilterOp.isIn) {
      if (_addSelected.isEmpty) return;
      val = Set<String>.from(_addSelected);
    } else if (_addOp == _FilterOp.isEmpty || _addOp == _FilterOp.isNotEmpty) {
      val = null;
    } else {
      if (_addText.trim().isEmpty) return;
      val = _addText.trim();
    }
    setState(() {
      _filters.add(_FieldFilter(fieldId: _addFieldId!, op: _addOp, value: val));
      _addFieldId = null;
      _addSelected.clear();
      _textCtrl.clear();
      _addText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc   = widget.themeColor;
    final isAr = widget.isAr;
    final sz   = MediaQuery.of(context).size;

    // Available fields for filtering
    final filterFields = <MapEntry<String, String>>[
      MapEntry('status',    isAr ? 'الحالة'  : 'Status'),
      MapEntry('submitter', isAr ? 'المرسل'  : 'Submitter'),
      ...widget.fields.map((f) => MapEntry(f.id, f.label)),
    ];

    final ops = _opsFor(_addFieldId);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: sz.width < 600 ? 16 : sz.width * 0.2,
          vertical: sz.height * 0.1),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── title bar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Icon(Icons.filter_list_rounded, size: 16, color: tc),
              const SizedBox(width: 8),
              Text(isAr ? 'فلاتر متقدمة' : 'Advanced Filters',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_filters.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _filters.clear()),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero),
                  child: Text(isAr ? 'مسح الكل' : 'Clear all',
                      style: const TextStyle(fontSize: 11)),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context, _filters),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.grey.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── active filters ────────────────────────────
                if (_filters.isNotEmpty) ...[
                  Text(isAr ? 'الفلاتر النشطة' : 'Active filters',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 5, children: [
                    for (int i = 0; i < _filters.length; i++)
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                        decoration: BoxDecoration(
                          color: tc.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tc.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_filters[i].chipLabel(widget.fields, isAr),
                              style: TextStyle(fontSize: 11, color: tc,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _filters.removeAt(i)),
                            child: Icon(Icons.close_rounded,
                                size: 13, color: tc.withValues(alpha: 0.7)),
                          ),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 14),
                ],

                // ── add filter form ───────────────────────────
                Text(isAr ? 'إضافة فلتر' : 'Add filter',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 8),

                // Field picker
                _dropRow(
                  hint: isAr ? 'اختر حقلاً' : 'Select field',
                  value: _addFieldId,
                  items: filterFields.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _onFieldChanged,
                  tc: tc,
                ),

                if (_addFieldId != null) ...[
                  const SizedBox(height: 8),
                  // Operator picker
                  _dropRow(
                    hint: isAr ? 'الشرط' : 'Condition',
                    value: _addOp,
                    items: ops.map((op) =>
                        DropdownMenuItem(value: op, child: Text(_opName(op),
                            style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _addOp = v); },
                    tc: tc,
                  ),
                  const SizedBox(height: 8),

                  // Value input
                  if (_addOp != _FilterOp.isEmpty && _addOp != _FilterOp.isNotEmpty)
                    _isMultiSelect(_addFieldId) && _addOp == _FilterOp.isIn
                        ? _MultiSelectPicker(
                            fieldId: _addFieldId!,
                            unique: widget.uniqueValues(_addFieldId!),
                            selected: _addSelected,
                            isAr: isAr,
                            themeColor: tc,
                            fieldName: _fieldName(_addFieldId!),
                            onChanged: (v) => setState(() {
                              _addSelected.clear();
                              _addSelected.addAll(v);
                            }),
                          )
                        : TextField(
                            controller: _textCtrl,
                            style: const TextStyle(fontSize: 12),
                            keyboardType: _isNumeric(_addFieldId)
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: isAr ? 'أدخل القيمة...' : 'Enter value...',
                              hintStyle: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade400),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: tc, width: 1.5)),
                            ),
                            onChanged: (v) => setState(() => _addText = v),
                          ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tc,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(isAr ? 'إضافة الفلتر' : 'Add Filter',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ]),
            ),
          ),

          // ── footer ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isAr ? 'إغلاق' : 'Close',
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tc,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _filters.isEmpty
                        ? (isAr ? 'تطبيق' : 'Apply')
                        : (isAr ? 'تطبيق (${_filters.length})' : 'Apply (${_filters.length})'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dropRow<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color tc,
  }) =>
      DropdownButtonHideUnderline(
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: Text(hint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Colors.grey.shade400),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );
}

// Multi-select picker for filter values (unique values from records)
class _MultiSelectPicker extends StatelessWidget {
  final String      fieldId;
  final Set<String> unique;
  final Set<String> selected;
  final bool        isAr;
  final Color       themeColor;
  final String      fieldName;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectPicker({
    required this.fieldId, required this.unique, required this.selected,
    required this.isAr, required this.themeColor, required this.fieldName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = themeColor;
    if (unique.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(isAr ? 'لا توجد قيم متاحة في السجلات الحالية'
            : 'No values found in current records',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400,
                fontStyle: FontStyle.italic)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 5, runSpacing: 5,
        children: unique.map((v) {
          final on = selected.contains(v);
          return GestureDetector(
            onTap: () {
              final ns = Set<String>.from(selected);
              if (on) { ns.remove(v); } else { ns.add(v); }
              onChanged(ns);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: on ? tc.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: on ? tc.withValues(alpha: 0.4) : Colors.grey.shade300,
                    width: on ? 1.5 : 1),
              ),
              child: Text(v,
                  style: TextStyle(
                      fontSize: 11,
                      color: on ? tc : Colors.grey.shade700,
                      fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Card grid
// ═══════════════════════════════════════════════════════════════════════
class _CardGrid extends StatelessWidget {
  final List<CcSubmission>  submissions;
  final List<CcFormField>   fields;
  final _ViewConfig         cfg;
  final Set<String>         selectedIds;
  final bool                isAr;
  final Color               themeColor;
  final bool                loadingMore;
  final bool                allSelected;
  final ValueChanged<String>       onToggle;
  final ValueChanged<CcSubmission> onOpen;
  final VoidCallback               onToggleAll;

  const _CardGrid({
    required this.submissions, required this.fields, required this.cfg,
    required this.selectedIds, required this.isAr, required this.themeColor,
    required this.loadingMore, required this.allSelected,
    required this.onToggle, required this.onOpen, required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final headerFields = fields
        .where((f) => cfg.headerFieldIds.contains(f.id))
        .toList()
      ..sort((a, b) => cfg.headerFieldIds.indexOf(a.id)
          .compareTo(cfg.headerFieldIds.indexOf(b.id)));
    final bodyFields = fields
        .where((f) => cfg.bodyFieldIds.contains(f.id))
        .toList()
      ..sort((a, b) => cfg.bodyFieldIds.indexOf(a.id)
          .compareTo(cfg.bodyFieldIds.indexOf(b.id)));

    return CustomScrollView(
      slivers: [
        // ── Select-all bar ────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(children: [
              SizedBox(
                width: 16, height: 16,
                child: Checkbox(
                  value: allSelected,
                  onChanged: (_) => onToggleAll(),
                  activeColor: themeColor,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(width: 1.5, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isAr
                    ? (allSelected
                        ? 'إلغاء تحديد الكل (${submissions.length})'
                        : 'تحديد الكل (${submissions.length})')
                    : (allSelected
                        ? 'Deselect all (${submissions.length})'
                        : 'Select all (${submissions.length})'),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              if (selectedIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${selectedIds.length} ${isAr ? 'محدد' : 'selected'}',
                    style: TextStyle(
                        fontSize: 10,
                        color: themeColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ]),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final screenW = MediaQuery.of(ctx).size.width;
                final maxW    = (screenW * 0.96).clamp(320.0, 1400.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: maxW,
                        child: _SubCard(
                          submission: submissions[i],
                          headerFields: headerFields,
                          bodyFields: bodyFields,
                          selected: selectedIds.contains(submissions[i].id),
                          isAr: isAr,
                          themeColor: themeColor,
                          showStatusButtons: cfg.showStatusButtons,
                          showDetailButton: cfg.showDetailButton,
                          allowNotes: cfg.allowNotes,
                          onToggle: () => onToggle(submissions[i].id),
                          onOpen: () => onOpen(submissions[i]),
                          onStatusChange: (st) async {
                            await CcService.updateSubmissionStatus(
                                submissions[i].id, st);
                            onOpen(submissions[i]);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: submissions.length,
            ),
          ),
        ),
        if (loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubCard extends StatefulWidget {
  final CcSubmission      submission;
  final List<CcFormField> headerFields;
  final List<CcFormField> bodyFields;
  final bool              selected;
  final bool              isAr;
  final Color             themeColor;
  final bool              showStatusButtons;
  final bool              showDetailButton;
  final bool              allowNotes;
  final VoidCallback                        onToggle;
  final VoidCallback                        onOpen;
  final Future<void> Function(CcSubmissionStatus) onStatusChange;

  const _SubCard({
    required this.submission,
    required this.headerFields,
    required this.bodyFields,
    required this.selected,
    required this.isAr,
    required this.themeColor,
    required this.showStatusButtons,
    required this.showDetailButton,
    required this.allowNotes,
    required this.onToggle,
    required this.onOpen,
    required this.onStatusChange,
  });

  @override
  State<_SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<_SubCard> {
  bool _expanded = false;

  // Notes state (lazy-loaded when card first expands)
  List<CcSubmissionNote>? _notes;
  bool _notesLoading = false;
  final _noteCtrl = TextEditingController();
  bool _posting   = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (_notesLoading) return;
    setState(() => _notesLoading = true);
    final notes = await CcService.getSubmissionNotes(widget.submission.id);
    if (mounted) setState(() { _notes = notes; _notesLoading = false; });
  }

  Future<void> _postNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    await CcService.addSubmissionNote(widget.submission.id, text);
    _noteCtrl.clear();
    await _loadNotes();
    if (mounted) setState(() => _posting = false);
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
      CcSubmissionStatus cur, bool isAr) {
    final entries = <PopupMenuEntry<String>>[];
    if (cur == CcSubmissionStatus.pending) {
      entries.add(_menuItem('resolved',
          isAr ? 'تغيير إلى: محلول' : 'Mark as Resolved',
          Icons.check_circle_outline_rounded,
          const Color(0xFF4CAF50)));
      entries.add(_menuItem('misleading',
          isAr ? 'تغيير إلى: مضلل' : 'Mark as Misleading',
          Icons.flag_outlined,
          const Color(0xFFF44336)));
    } else {
      entries.add(_menuItem('pending',
          isAr ? 'إعادة إلى: انتظار' : 'Move to Pending',
          Icons.hourglass_empty_rounded,
          const Color(0xFFFF9800)));
    }
    entries.add(const PopupMenuDivider(height: 6));
    entries.add(_menuItem('select',
        isAr ? 'تحديد / إلغاء تحديد' : 'Select / Deselect',
        Icons.check_box_outlined,
        Colors.grey));
    return entries;
  }

  PopupMenuItem<String> _menuItem(
          String val, String label, IconData icon, Color color) =>
      PopupMenuItem<String>(
        value: val,
        height: 40,
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color == Colors.grey ? Colors.black87 : color,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Future<void> _confirmStatus(CcSubmissionStatus st) async {
    final isAr = widget.isAr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isAr ? 'تأكيد تغيير الحالة' : 'Confirm Status Change',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          isAr
              ? 'هل تريد تغيير الحالة إلى "${_statusLbl(st, true)}"؟'
              : 'Change status to "${_statusLbl(st, false)}"?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _statusClr(st),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onStatusChange(st);
  }

  @override
  Widget build(BuildContext context) {
    final s           = widget.submission;
    final tc          = widget.themeColor;
    final isAr        = widget.isAr;
    final statusColor = _statusClr(s.status);
    final name        = s.isAnonymous
        ? (isAr ? 'مجهول' : 'Anonymous')
        : (s.submitterFullName ?? '-');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Filter header fields (exclude attachments)
    final displayHeaderFields = widget.headerFields
        .where((f) =>
            f.fieldType != CcFieldType.attachment &&
            f.fieldType != CcFieldType.imageAttachment)
        .take(4)
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: widget.selected
                ? tc.withValues(alpha: 0.5)
                : const Color(0xFFE8EAF0),
            width: widget.selected ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.selected ? 0.07 : 0.04),
              blurRadius: widget.selected ? 14 : 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header strip (tappable — toggles expand) ─────────
              GestureDetector(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                  if (_expanded && widget.allowNotes && _notes == null) {
                    _loadNotes();
                  }
                },
                onLongPress: widget.onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 7, 10, 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Accent bar — slim
                      Container(
                        width: 4,
                        height: 26,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                        ),
                      ),
                      // Avatar — compact
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: s.isAnonymous
                              ? Colors.grey.shade100
                              : statusColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(initial,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: s.isAnonymous
                                    ? Colors.grey.shade400
                                    : statusColor)),
                      ),
                      const SizedBox(width: 8),
                      // Name + date
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E)),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              _fmtShortDateTime(s.createdAt, isAr: isAr),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge — right next to the name
                      _StatusBadge(status: s.status, isAr: isAr),
                      // Field chips — natural width, no expansion
                      if (displayHeaderFields.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        for (int i = 0;
                            i < displayHeaderFields.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: _HeaderFieldCell(
                              field: displayHeaderFields[i],
                              submission: s,
                              isAr: isAr,
                            ),
                          ),
                        ],
                      ],
                      const Spacer(),
                      // Three-dots action menu
                      if (widget.showStatusButtons)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.more_vert_rounded,
                              size: 16, color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          itemBuilder: (_) => _buildMenuItems(s.status, isAr),
                          onSelected: (v) {
                            if (v == 'select') {
                              widget.onToggle();
                            } else {
                              final st = CcSubmissionStatus.fromString(v);
                              _confirmStatus(st);
                            }
                          },
                        ),
                      // Checkbox
                      SizedBox(
                        width: 14, height: 14,
                        child: Checkbox(
                          value: widget.selected,
                          onChanged: (_) => widget.onToggle(),
                          activeColor: tc,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                              width: 1.5, color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Expand arrow
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expandable body — height-animate, only built when open ──
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: _expanded
                    ? _buildBody(context, s, isAr, tc)
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CcSubmission s, bool isAr, Color tc) {
    // Exclude any field already displayed in the header
    final headerIds = widget.headerFields.map((f) => f.id).toSet();
    final effectiveBody =
        widget.bodyFields.where((f) => !headerIds.contains(f.id)).toList();

    final attFields = effectiveBody
        .where((f) =>
            f.fieldType == CcFieldType.attachment ||
            f.fieldType == CcFieldType.imageAttachment)
        .toList();
    final textFields = effectiveBody
        .where((f) =>
            f.fieldType != CcFieldType.attachment &&
            f.fieldType != CcFieldType.imageAttachment &&
            f.fieldType != CcFieldType.signature)
        .toList();
    final sigFields = effectiveBody
        .where((f) => f.fieldType == CcFieldType.signature)
        .toList();

    // Gather all images and files for quick preview
    final allImgs  = s.attachments.where((a) => a.isImage).toList();
    final allFiles = s.attachments.where((a) => !a.isImage).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        color: const Color(0xFFFAFBFC),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text body fields
          if (textFields.isNotEmpty) ...[
            for (final f in textFields)
              _BodyFieldRow(field: f, submission: s, isAr: isAr),
            const SizedBox(height: 6),
          ],

          // Signature fields
          for (final f in sigFields) ...[
            _SigRow(field: f, submission: s, isAr: isAr),
            const SizedBox(height: 6),
          ],

          // Per-field attachment rows
          for (final f in attFields) ...[
            _AttachmentFieldRow(
              label: f.label,
              icon: _fieldIcon(f.fieldType),
              atts: s.attachments.where((a) => a.fieldId == f.id).toList(),
            ),
            const SizedBox(height: 4),
          ],

          // Fallback image thumbnails (if no att fields configured)
          if (attFields.isEmpty && allImgs.isNotEmpty) ...[
            _ThumbnailStrip(images: allImgs, files: allFiles),
            const SizedBox(height: 8),
          ],

          // Open full details button
          if (widget.showDetailButton)
            GestureDetector(
              onTap: widget.onOpen,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tc.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 13, color: tc),
                    const SizedBox(width: 6),
                    Text(isAr ? 'عرض كامل التفاصيل' : 'Open full details',
                        style: TextStyle(
                            fontSize: 12,
                            color: tc,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // ── Notes section ────────────────────────────────
          if (widget.allowNotes) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Text(isAr ? 'ملاحظات' : 'Notes',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500)),
                    if (_notes != null && _notes!.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${_notes!.length}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),

                  // Notes timeline
                  if (_notesLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  else if (_notes == null || _notes!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          isAr ? 'لا توجد ملاحظات بعد' : 'No notes yet',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic)),
                    )
                  else
                    for (int ni = 0; ni < _notes!.length; ni++)
                      _CardNoteItem(note: _notes![ni], isLast: ni == _notes!.length - 1, isAr: isAr),

                  // Add note input
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _noteCtrl,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2, minLines: 1,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: isAr ? 'أضف ملاحظة...' : 'Add a note...',
                          hintStyle: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tc, width: 1.5)),
                        ),
                        onSubmitted: (_) => _postNote(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: tc,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _posting ? null : _postNote,
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(
                            width: 32, height: 32,
                            child: Icon(Icons.send_rounded,
                                size: 13, color: Colors.white)),
                      ),
                    ),
                  ]),

                  // ── Status action buttons (compact, below note input) ──
                  if (widget.showStatusButtons) ...[
                    const SizedBox(height: 8),
                    _StatusActionBar(
                        status: s.status, isAr: isAr, onConfirm: _confirmStatus),
                  ],
                ],
              ),
            ),
          ],

          // ── Status action buttons when notes are hidden ──────────
          if (!widget.allowNotes && widget.showStatusButtons) ...[
            const SizedBox(height: 8),
            _StatusActionBar(
                status: s.status, isAr: isAr, onConfirm: _confirmStatus),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

// ── Smart status action bar ───────────────────────────────────────────
// Shows 1-2 buttons based on the current status (with icons)
class _StatusActionBar extends StatelessWidget {
  final CcSubmissionStatus status;
  final bool isAr;
  final Future<void> Function(CcSubmissionStatus) onConfirm;
  const _StatusActionBar(
      {required this.status, required this.isAr, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final buttons = <({CcSubmissionStatus st, IconData icon, String label})>[];
    if (status == CcSubmissionStatus.pending) {
      buttons.add((
        st: CcSubmissionStatus.resolved,
        icon: Icons.check_circle_outline_rounded,
        label: isAr ? 'تغيير إلى محلول' : 'Mark Resolved',
      ));
      buttons.add((
        st: CcSubmissionStatus.misleading,
        icon: Icons.flag_outlined,
        label: isAr ? 'تغيير إلى مضلل' : 'Mark Misleading',
      ));
    } else {
      buttons.add((
        st: CcSubmissionStatus.pending,
        icon: Icons.hourglass_empty_rounded,
        label: isAr ? 'إعادة إلى انتظار' : 'Back to Pending',
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: buttons.map((b) {
        final c = _statusClr(b.st);
        return GestureDetector(
          onTap: () => onConfirm(b.st),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(b.icon, size: 12, color: c),
                const SizedBox(width: 5),
                Text(b.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Quick filter bar (field + value dropdowns) ────────────────────────
class _QuickFilterBar extends StatelessWidget {
  final List<CcFormField>         fields;
  final bool                      isAr;
  final Color                     themeColor;
  final String?                   selectedFieldId;
  final String?                   selectedValue;
  final Set<String> Function(String) uniqueValues;
  final void Function(String? fid, String? val) onChanged;
  final VoidCallback              onClear;

  const _QuickFilterBar({
    required this.fields, required this.isAr, required this.themeColor,
    required this.selectedFieldId, required this.selectedValue,
    required this.uniqueValues, required this.onChanged, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    final tc = themeColor;
    final isActive = selectedFieldId != null && selectedValue != null;

    // Unique values for currently selected field
    final vals = <String>[];
    if (selectedFieldId != null) {
      vals.addAll(uniqueValues(selectedFieldId!));
      vals.sort();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        // Field picker
        Flexible(
          flex: 3,
          child: _qDrop<String?>(
            context: context,
            hint: isAr ? 'فلتر حسب الحقل' : 'Filter by field',
            value: selectedFieldId,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(isAr ? 'اختر حقلاً' : 'Choose field',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),
              ...fields.map((f) => DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(f.label,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => onChanged(v, null),
            tc: tc,
            active: selectedFieldId != null,
          ),
        ),
        if (selectedFieldId != null) ...[
          const SizedBox(width: 6),
          // Value picker
          Flexible(
            flex: 3,
            child: _qDrop<String?>(
              context: context,
              hint: isAr ? 'اختر قيمة' : 'Select value',
              value: vals.contains(selectedValue) ? selectedValue : null,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(isAr ? 'كل القيم' : 'All values',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ),
                ...vals.map((v) => DropdownMenuItem<String?>(
                      value: v,
                      child: Text(v,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => onChanged(selectedFieldId, v),
              tc: tc,
              active: selectedValue != null,
            ),
          ),
        ],
        if (isActive) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close_rounded,
                  size: 13, color: Colors.grey.shade500),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _qDrop<T>({
    required BuildContext context,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color tc,
    required bool active,
  }) =>
      DropdownButtonHideUnderline(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? tc.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? tc.withValues(alpha: 0.3)
                    : Colors.grey.shade200),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: Text(hint,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            style: TextStyle(
                fontSize: 12,
                color: active ? tc : Colors.black87),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: active ? tc : Colors.grey.shade400),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );
}

// ── Card note item (timeline style) ──────────────────────────────────
class _CardNoteItem extends StatelessWidget {
  final CcSubmissionNote note;
  final bool             isLast;
  final bool             isAr;
  const _CardNoteItem({required this.note, required this.isLast, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final initial = (note.authorFullName?.isNotEmpty == true)
        ? note.authorFullName![0].toUpperCase()
        : '?';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          Column(children: [
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(
                  color: Color(0xFFEEEFF2), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF888888))),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.grey.shade200,
                ),
              ),
          ]),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(note.authorFullName ?? '-',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ),
                    Text(
                      _fmtShortDateTime(note.createdAt, isAr: isAr),
                      style: TextStyle(
                          fontSize: 9, color: Colors.grey.shade400),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(note.note,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header field cell: label (small gray) + value (bold) ─────────────
class _HeaderFieldCell extends StatelessWidget {
  final CcFormField  field;
  final CcSubmission submission;
  final bool         isAr;
  const _HeaderFieldCell(
      {required this.field, required this.submission, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final label = field.label;

    // styledSelect: label text + colored badge, no gray container
    if (field.fieldType == CcFieldType.styledSelect) {
      final raw = submission.values
          .where((v) => v.fieldId == field.id)
          .map((v) => v.value)
          .firstOrNull;
      final opt = (raw is String && raw.isNotEmpty)
          ? field.config.styledSelectOptions.where((o) => o.id == raw).toList()
          : <StyledSelectOption>[];
      return Container(
        padding: const EdgeInsets.only(left: 7),
        decoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            if (opt.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: opt.first.bgColorValue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(opt.first.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: opt.first.textColorValue),
                    overflow: TextOverflow.ellipsis),
              )
            else
              Text('—',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade300)),
          ],
        ),
      );
    }

    // Normal field: left border separator + label + value, no gray container
    final val = _shortVal(submission, field, isAr: isAr);
    return Container(
      padding: const EdgeInsets.only(left: 7),
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: Colors.grey.shade200, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            val.isEmpty ? '—' : val,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: val.isEmpty
                    ? Colors.grey.shade300
                    : const Color(0xFF1A1A2E)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Body field row (label + value, expanded) ──────────────────────────
class _BodyFieldRow extends StatelessWidget {
  final CcFormField  field;
  final CcSubmission submission;
  final bool         isAr;
  const _BodyFieldRow(
      {required this.field, required this.submission, required this.isAr});

  @override
  Widget build(BuildContext context) {
    // styledSelect: label + colored badge in container
    if (field.fieldType == CcFieldType.styledSelect) {
      final raw = submission.values
          .where((v) => v.fieldId == field.id)
          .map((v) => v.value)
          .firstOrNull;
      final opt = (raw is String && raw.isNotEmpty)
          ? field.config.styledSelectOptions
              .where((o) => o.id == raw)
              .toList()
          : <StyledSelectOption>[];
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(field.label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: opt.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: opt.first.bgColorValue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(opt.first.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: opt.first.textColorValue,
                              fontWeight: FontWeight.w700)),
                    )
                  : Text('—',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
            ),
          ],
        ),
      );
    }

    final val = _shortVal(submission, field, isAr: isAr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(field.label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              val.isEmpty ? '—' : val,
              style: TextStyle(
                  fontSize: 12,
                  color: val.isEmpty
                      ? Colors.grey.shade400
                      : const Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signature row (renders drawn strokes) ─────────────────────────────
class _SigRow extends StatelessWidget {
  final CcFormField  field;
  final CcSubmission submission;
  final bool         isAr;
  const _SigRow(
      {required this.field, required this.submission, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final raw = submission.values
        .where((v) => v.fieldId == field.id)
        .map((v) => v.value)
        .firstOrNull;
    final strokes = _parseSignature(raw);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.draw_outlined, size: 11, color: Colors.grey.shade400),
        const SizedBox(width: 5),
        Text('${field.label}:',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      if (strokes.isNotEmpty)
        Container(
          width: double.infinity, height: 70,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              CustomPaint(painter: _SignaturePainter(strokes: strokes)),
        )
      else
        Text(isAr ? 'لم يُوقَّع' : 'Not signed',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic)),
    ]);
  }
}

class _AttachmentFieldRow extends StatelessWidget {
  final String                       label;
  final IconData                     icon;
  final List<CcSubmissionAttachment> atts;
  const _AttachmentFieldRow(
      {required this.label, required this.icon, required this.atts});

  @override
  Widget build(BuildContext context) {
    if (atts.isEmpty) return const SizedBox.shrink();
    final imgs  = atts.where((a) => a.isImage).toList();
    final files = atts.where((a) => !a.isImage).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row
          Row(children: [
            Icon(icon, size: 10, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('$label:',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
          ]),
          if (imgs.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ImageGrid(images: imgs, context: context),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: files.map((a) => _FileChip(attachment: a)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final List<CcSubmissionAttachment> images;
  final List<CcSubmissionAttachment> files;
  const _ThumbnailStrip({required this.images, required this.files});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (images.isNotEmpty) _ImageGrid(images: images, context: context),
          if (files.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: files.map((a) => _FileChip(attachment: a)).toList(),
            ),
          ],
        ],
      );
}

// ── Interactive file chip — preview or download on tap ────────────────
class _FileChip extends StatefulWidget {
  final CcSubmissionAttachment attachment;
  const _FileChip({required this.attachment});
  @override
  State<_FileChip> createState() => _FileChipState();
}

class _FileChipState extends State<_FileChip> {
  bool _hovered = false;

  static const _previewExts = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'rtf', 'odt', 'ods', 'odp',
  };

  bool get _canPreview {
    final ext = widget.attachment.fileName.split('.').last.toLowerCase();
    return _previewExts.contains(ext);
  }

  void _open(BuildContext ctx) {
    if (_canPreview) {
      showDialog(
          context: ctx,
          builder: (_) => _FilePreviewDialog(attachment: widget.attachment));
    } else {
      final uri = Uri.tryParse(widget.attachment.fileUrl);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static IconData _iconFor(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'pdf':               return Icons.picture_as_pdf_outlined;
      case 'doc': case 'docx': return Icons.description_outlined;
      case 'xls': case 'xlsx':
      case 'csv':               return Icons.table_chart_outlined;
      case 'ppt': case 'pptx': return Icons.slideshow_outlined;
      case 'txt': case 'rtf':  return Icons.article_outlined;
      case 'zip': case 'rar':
      case '7z':                return Icons.folder_zip_outlined;
      default:                  return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4A5FCC);
    const bg     = Color(0xFFEEF2FF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _open(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? bg : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: _hovered ? accent : Colors.grey.shade200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_iconFor(widget.attachment.fileName),
                size: 12,
                color: _hovered ? accent : Colors.grey.shade500),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                widget.attachment.fileName,
                style: TextStyle(
                    fontSize: 11,
                    color: _hovered ? const Color(0xFF2D3A8C) : Colors.grey.shade700,
                    fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _canPreview ? Icons.visibility_outlined : Icons.download_outlined,
              size: 10,
              color: _hovered ? accent : Colors.grey.shade400,
            ),
          ]),
        ),
      ),
    );
  }
}

// ── File preview dialog (PDF / Office / TXT via Google Docs Viewer) ────
// ── File preview type classification ─────────────────────────────────
enum _PreviewType { pdf, text, office, unsupported }

class _FilePreviewDialog extends StatefulWidget {
  final CcSubmissionAttachment attachment;
  const _FilePreviewDialog({required this.attachment});
  @override
  State<_FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<_FilePreviewDialog> {
  // Web iframe view id (registered once blob URL is ready for PDF)
  late final String _viewId;

  bool    _loading = true;
  String? _error;
  String? _blobUrl;     // PDF via browser blob fetch
  String? _textContent; // TXT / CSV content

  static const _pdfExts    = {'pdf'};
  static const _textExts   = {'txt', 'csv', 'rtf'};
  static const _officeExts = {
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp'
  };

  String get _ext =>
      widget.attachment.fileName.split('.').last.toLowerCase();

  _PreviewType get _type {
    if (_pdfExts.contains(_ext))    return _PreviewType.pdf;
    if (_textExts.contains(_ext))   return _PreviewType.text;
    if (_officeExts.contains(_ext)) return _PreviewType.office;
    return _PreviewType.unsupported;
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'fp-${DateTime.now().microsecondsSinceEpoch}';
    if (kIsWeb) {
      _loadContent();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadContent() async {
    try {
      switch (_type) {
        case _PreviewType.pdf:
          final blob = await createBlobUrl(widget.attachment.fileUrl);
          if (!mounted) return;
          registerIframeView(_viewId, blob);
          setState(() { _blobUrl = blob; _loading = false; });
          break;
        case _PreviewType.text:
          final text = await fetchText(widget.attachment.fileUrl);
          if (!mounted) return;
          setState(() { _textContent = text; _loading = false; });
          break;
        default:
          if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load file';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null) revokeBlobUrl(_blobUrl!);
    super.dispose();
  }

  void _download() async {
    if (kIsWeb) {
      downloadFileWeb(widget.attachment.fileUrl, widget.attachment.fileName);
    } else {
      final uri = Uri.tryParse(widget.attachment.fileUrl);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static IconData _iconFor(String fileName) => _FileChipState._iconFor(fileName);

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
          horizontal: sz.width * 0.05, vertical: sz.height * 0.06),
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.28), blurRadius: 40)
          ],
        ),
        child: Column(
          children: [
            // ── Title bar ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(children: [
                Icon(_iconFor(widget.attachment.fileName),
                    size: 18, color: const Color(0xFF555577)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.attachment.fileName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E)),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Download'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A5FCC),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.grey.shade500,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            // ── Content ──────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 12),
          Text('Loading…', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded,
              size: 40, color: Colors.red.shade300),
          const SizedBox(height: 10),
          Text(_error!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _downloadButton(),
        ]),
      );
    }

    switch (_type) {
      // ── PDF: blob URL → native browser PDF viewer ──────────────
      case _PreviewType.pdf:
        if (kIsWeb && _blobUrl != null) {
          return HtmlElementView(viewType: _viewId);
        }
        return _downloadFallback();

      // ── Plain text / CSV ──────────────────────────────────────
      case _PreviewType.text:
        if (_textContent != null) {
          return Container(
            color: const Color(0xFFF8F9FB),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                _textContent!,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13, height: 1.5),
              ),
            ),
          );
        }
        return _downloadFallback();

      // ── Office files (xlsx, docx, ppt…) ───────────────────────
      case _PreviewType.office:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(_iconFor(widget.attachment.fileName),
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(widget.attachment.fileName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Browser preview is not available for ${_ext.toUpperCase()} files.\n'
                'Download the file to open it in the appropriate application.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _downloadButton(),
            ]),
          ),
        );

      default:
        return _downloadFallback();
    }
  }

  Widget _downloadFallback() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Preview not available.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          _downloadButton(),
        ]),
      );

  Widget _downloadButton() => ElevatedButton.icon(
        onPressed: _download,
        icon: const Icon(Icons.download_rounded, size: 16),
        label: const Text('Download File'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A5FCC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  Table view
// ═══════════════════════════════════════════════════════════════════════
class _TableArea extends StatelessWidget {
  final List<CcSubmission>  submissions;
  final List<CcFormField>   fields;
  final _ViewConfig         cfg;
  final Set<String>         selectedIds;
  final bool                isAr;
  final Color               themeColor;
  final bool                loadingMore;
  final String?             sortCol;
  final bool                sortAsc;
  final bool                allSelected;
  final ValueChanged<String>       onToggle;
  final ValueChanged<CcSubmission> onOpen;
  final ValueChanged<String>       onSort;
  final VoidCallback               onToggleAll;
  final Future<void> Function(String id, CcSubmissionStatus) onStatusChange;

  const _TableArea({
    required this.submissions, required this.fields, required this.cfg,
    required this.selectedIds, required this.isAr, required this.themeColor,
    required this.loadingMore, required this.sortCol, required this.sortAsc,
    required this.allSelected, required this.onToggle, required this.onOpen,
    required this.onSort, required this.onToggleAll, required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final cols      = cfg.tableColIds;
      final fm        = {for (final f in fields) f.id: f};
      final showActions = cfg.showStatusButtons;
      final computedW = 36.0 + cols.length * 180.0 + (showActions ? 56.0 : 0);
      final tableW    = computedW < box.maxWidth ? box.maxWidth : computedW;

      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  color: const Color(0xFFF5F6F8),
                  child: Row(children: [
                    SizedBox(
                      width: 36, height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 14, height: 14,
                          child: Checkbox(
                            value: allSelected,
                            onChanged: (_) => onToggleAll(),
                            activeColor: themeColor,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(
                                width: 1.5, color: Color(0xFFCCCCCC)),
                          ),
                        ),
                      ),
                    ),
                    for (final col in cols) _sortHeader(col, fm),
                    if (showActions)
                      Container(
                        width: 56, height: 36,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(isAr ? 'إجراء' : 'Action',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF999999))),
                      ),
                  ]),
                ),
                Divider(height: 1, thickness: 1,
                    color: Colors.grey.shade200),
                // Rows
                for (int i = 0; i < submissions.length; i++) ...[
                  _TRow(
                    submission: submissions[i],
                    cols: cols,
                    fm: fm,
                    selected: selectedIds.contains(submissions[i].id),
                    even: i.isEven,
                    isAr: isAr,
                    themeColor: themeColor,
                    showActions: showActions,
                    onToggle: () => onToggle(submissions[i].id),
                    onOpen: () => onOpen(submissions[i]),
                    onStatusChange: (st) =>
                        onStatusChange(submissions[i].id, st),
                  ),
                  const Divider(height: 1, thickness: 1,
                      color: Color(0xFFF3F3F3)),
                ],
                if (loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _sortHeader(String col, Map<String, CcFormField> fm) {
    final label    = _colLabel(col, fm);
    final isActive = sortCol == col;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSort(col),
      child: Container(
        width: 180, height: 36,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? themeColor : const Color(0xFF999999))),
          ),
          Icon(
            isActive
                ? (sortAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: isActive ? themeColor : Colors.grey.shade400,
          ),
        ]),
      ),
    );
  }

  String _colLabel(String col, Map<String, CcFormField> fm) {
    switch (col) {
      case 'submitter': return isAr ? 'المرسل'  : 'Submitter';
      case 'status':    return isAr ? 'الحالة'  : 'Status';
      case 'date':      return isAr ? 'التاريخ' : 'Date';
      default:          return fm[col]?.label ?? col;
    }
  }
}

class _TRow extends StatelessWidget {
  final CcSubmission             submission;
  final List<String>             cols;
  final Map<String, CcFormField> fm;
  final bool                     selected;
  final bool                     even;
  final bool                     isAr;
  final Color                    themeColor;
  final bool                     showActions;
  final VoidCallback             onToggle;
  final VoidCallback             onOpen;
  final Future<void> Function(CcSubmissionStatus) onStatusChange;

  const _TRow({
    required this.submission, required this.cols, required this.fm,
    required this.selected, required this.even, required this.isAr,
    required this.themeColor, required this.showActions,
    required this.onToggle, required this.onOpen, required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Material(
      color: selected
          ? themeColor.withValues(alpha: 0.05)
          : (even ? Colors.white : const Color(0xFFFAFAFC)),
      child: InkWell(
        onTap: onOpen,
        hoverColor: const Color(0xFFF0F2FF),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Center(
                child: SizedBox(
                  width: 14, height: 14,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    activeColor: themeColor,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(width: 1.5, color: Color(0xFFCCCCCC)),
                  ),
                ),
              ),
            ),
            for (final col in cols)
              Container(
                width: 180,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _cell(col, s)),
              ),
            if (showActions)
              Container(
                width: 56,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                child: Center(
                  child: _RowActionMenu(
                    submission: s,
                    isAr: isAr,
                    themeColor: themeColor,
                    onStatusChange: onStatusChange,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _cell(String col, CcSubmission s) {
    switch (col) {
      case 'submitter':
        return Text(
          s.isAnonymous
              ? (isAr ? 'مجهول' : 'Anonymous')
              : (s.submitterFullName ?? '-'),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: Colors.black87),
        );
      case 'status':
        return _StatusBadge(status: s.status, isAr: isAr);
      case 'date':
        return Text(
          _fmtShortDateTime(s.createdAt, isAr: isAr),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        );
      default:
        final f = fm[col];
        if (f == null) return const SizedBox.shrink();
        // Show attachment count for attachment fields
        if (f.fieldType == CcFieldType.attachment ||
            f.fieldType == CcFieldType.imageAttachment) {
          final fieldAtts = s.attachments.where((a) => a.fieldId == f.id).toList();
          final count = fieldAtts.length;
          if (count == 0) {
            return Text('—',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade300));
          }
          final imgs  = fieldAtts.where((a) => a.isImage).length;
          final files = fieldAtts.where((a) => !a.isImage).length;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (imgs > 0) ...[
              Icon(Icons.image_outlined, size: 11, color: Colors.blue.shade300),
              const SizedBox(width: 2),
              Text('$imgs',
                  style: TextStyle(
                      fontSize: 11, color: Colors.blue.shade400)),
              const SizedBox(width: 6),
            ],
            if (files > 0) ...[
              Icon(Icons.attach_file_rounded,
                  size: 11, color: Colors.grey.shade500),
              const SizedBox(width: 2),
              Text('$files',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ]);
        }
        final v = _shortVal(s, f, isAr: isAr);
        return Text(
          v.isEmpty ? '—' : v,
          style: TextStyle(
              fontSize: 12,
              color: v.isEmpty ? Colors.grey.shade300 : Colors.grey.shade800),
        );
    }
  }
}

// ── Row action popup menu (table view) ───────────────────────────────
class _RowActionMenu extends StatelessWidget {
  final CcSubmission submission;
  final bool         isAr;
  final Color        themeColor;
  final Future<void> Function(CcSubmissionStatus) onStatusChange;

  const _RowActionMenu({
    required this.submission, required this.isAr,
    required this.themeColor, required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final s = submission.status;
    final items = <PopupMenuEntry<CcSubmissionStatus>>[];
    if (s == CcSubmissionStatus.pending) {
      items.add(PopupMenuItem(
        value: CcSubmissionStatus.resolved,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 14, color: _statusClr(CcSubmissionStatus.resolved)),
          const SizedBox(width: 8),
          Text(isAr ? 'تغيير إلى محلول' : 'Mark Resolved',
              style: const TextStyle(fontSize: 12)),
        ]),
      ));
      items.add(PopupMenuItem(
        value: CcSubmissionStatus.misleading,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.flag_outlined,
              size: 14, color: _statusClr(CcSubmissionStatus.misleading)),
          const SizedBox(width: 8),
          Text(isAr ? 'تغيير إلى مضلل' : 'Mark Misleading',
              style: const TextStyle(fontSize: 12)),
        ]),
      ));
    } else {
      items.add(PopupMenuItem(
        value: CcSubmissionStatus.pending,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 14, color: _statusClr(CcSubmissionStatus.pending)),
          const SizedBox(width: 8),
          Text(isAr ? 'إعادة إلى انتظار' : 'Back to Pending',
              style: const TextStyle(fontSize: 12)),
        ]),
      ));
    }

    return PopupMenuButton<CcSubmissionStatus>(
      icon: Icon(Icons.more_vert_rounded,
          size: 16, color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => items,
      onSelected: (st) => onStatusChange(st),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Config panel
// ═══════════════════════════════════════════════════════════════════════
class _ConfigPanel extends StatelessWidget {
  final List<CcFormField> fields;
  final _ViewConfig       cfg;
  final bool              isAr;
  final Color             themeColor;
  final VoidCallback      onClose;
  final VoidCallback      onChanged;

  const _ConfigPanel({
    required this.fields, required this.cfg, required this.isAr,
    required this.themeColor, required this.onClose, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = themeColor;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade200))),
        child: Row(children: [
          Icon(Icons.tune_rounded, size: 15, color: tc),
          const SizedBox(width: 8),
          Text(isAr ? 'تخصيص العرض' : 'Customize View',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 17),
            color: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ── Card: header section ──
            _secLbl(
              isAr ? 'حقول رأس البطاقة' : 'Card header fields',
              isAr ? 'تظهر دائماً — يفضل الحقول القصيرة (max 3)'
                   : 'Always visible — prefer short-value fields (max 3)',
            ),
            const SizedBox(height: 8),
            for (final f in fields
                .where((f) => _ViewConfig._isHeaderCompatible(f.fieldType)))
              _Toggle(
                label: f.label,
                sub: isAr ? f.fieldType.displayNameAr : f.fieldType.displayName,
                value: cfg.headerFieldIds.contains(f.id),
                tc: tc,
                onChanged: (v) {
                  if (v) {
                    if (cfg.headerFieldIds.length < 3) {
                      cfg.headerFieldIds.add(f.id);
                    }
                  } else {
                    cfg.headerFieldIds.remove(f.id);
                  }
                  onChanged();
                },
              ),
            const SizedBox(height: 16),

            // ── Card: body section ──
            _secLbl(
              isAr ? 'حقول جسم البطاقة' : 'Card body fields',
              isAr ? 'تظهر عند توسيع البطاقة'
                   : 'Shown when the card is expanded',
            ),
            const SizedBox(height: 8),
            for (final f in fields)
              _Toggle(
                label: f.label,
                sub: isAr ? f.fieldType.displayNameAr : f.fieldType.displayName,
                value: cfg.bodyFieldIds.contains(f.id),
                tc: tc,
                onChanged: (v) {
                  if (v) { cfg.bodyFieldIds.add(f.id); }
                  else   { cfg.bodyFieldIds.remove(f.id); }
                  onChanged();
                },
              ),
            const SizedBox(height: 8),
            // Card options
            _secLbl(
              isAr ? 'خيارات البطاقة' : 'Card options',
              isAr ? 'ما يظهر في القسم الموسَّع' : 'What appears in expanded section',
            ),
            const SizedBox(height: 6),
            _Toggle(
              label: isAr ? 'أزرار تغيير الحالة' : 'Status change buttons',
              sub: isAr ? 'تغيير الحالة من البطاقة مباشرة'
                        : 'Change status directly from card',
              value: cfg.showStatusButtons,
              tc: tc,
              onChanged: (v) { cfg.showStatusButtons = v; onChanged(); },
            ),
            _Toggle(
              label: isAr ? 'زر عرض التفاصيل الكاملة' : 'Open full details button',
              sub: isAr ? 'فتح اللوحة الجانبية' : 'Opens the side panel',
              value: cfg.showDetailButton,
              tc: tc,
              onChanged: (v) { cfg.showDetailButton = v; onChanged(); },
            ),
            _Toggle(
              label: isAr ? 'قسم الملاحظات الداخلية' : 'Internal notes section',
              sub: isAr ? 'إضافة وعرض الملاحظات في البطاقة'
                        : 'Add & view notes directly on the card',
              value: cfg.allowNotes,
              tc: tc,
              onChanged: (v) { cfg.allowNotes = v; onChanged(); },
            ),
            const SizedBox(height: 16),

            // ── Table columns ──
            _secLbl(isAr ? 'أعمدة الجدول' : 'Table columns',
                isAr ? 'الأعمدة المرئية في عرض الجدول'
                     : 'Visible columns in table view'),
            const SizedBox(height: 8),
            for (final pair in [
              ['submitter', isAr ? 'المرسل' : 'Submitter',
                isAr ? 'عمود ثابت' : 'System column'],
              ...fields.map((f) => [
                f.id, f.label,
                isAr ? f.fieldType.displayNameAr : f.fieldType.displayName,
              ]),
              ['status', isAr ? 'الحالة' : 'Status',
                isAr ? 'عمود ثابت' : 'System column'],
              ['date', isAr ? 'التاريخ' : 'Date',
                isAr ? 'عمود ثابت' : 'System column'],
            ])
              _Toggle(
                label: pair[1],
                sub: pair[2],
                value: cfg.tableColIds.contains(pair[0]),
                tc: tc,
                onChanged: (v) {
                  if (v) { cfg.tableColIds.add(pair[0]); }
                  else   { cfg.tableColIds.remove(pair[0]); }
                  onChanged();
                },
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _secLbl(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      );
}

class _Toggle extends StatelessWidget {
  final String           label;
  final String           sub;
  final bool             value;
  final Color            tc;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.label, required this.sub, required this.value,
      required this.tc, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: value ? tc.withValues(alpha: 0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: value
                  ? tc.withValues(alpha: 0.2)
                  : Colors.grey.shade200),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: tc,
          dense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          title: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          subtitle: Text(sub,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
//  Detail panel
// ═══════════════════════════════════════════════════════════════════════
class _DetailPanel extends StatefulWidget {
  final String            submissionId;
  final List<CcFormField> fields;
  final bool              isAr;
  final Color             themeColor;
  final VoidCallback      onClose;
  final VoidCallback      onStatusChanged;

  const _DetailPanel({
    super.key,
    required this.submissionId, required this.fields, required this.isAr,
    required this.themeColor, required this.onClose, required this.onStatusChanged,
  });

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  CcSubmission? _s;
  bool          _loading = true;
  final         _noteCtrl = TextEditingController();
  bool          _posting  = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final s = await CcService.getSubmissionDetail(widget.submissionId);
    if (mounted) setState(() { _s = s; _loading = false; });
  }

  Future<void> _setStatus(CcSubmissionStatus st) async {
    await CcService.updateSubmissionStatus(widget.submissionId, st);
    widget.onStatusChanged();
    await _load();
  }

  Future<void> _postNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    await CcService.addSubmissionNote(widget.submissionId, text);
    _noteCtrl.clear();
    await _load();
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final tc   = widget.themeColor;

    if (_loading || _s == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final s = _s!;
    final name    = s.isAnonymous
        ? (isAr ? 'مجهول' : 'Anonymous')
        : (s.submitterFullName ?? '-');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fm      = {for (final f in widget.fields) f.id: f};

    // Group attachments per form field, then gather unclaimed ones
    final attFields = widget.fields
        .where((f) =>
            f.fieldType == CcFieldType.attachment ||
            f.fieldType == CcFieldType.imageAttachment)
        .toList();
    // Build per-field groups
    final attGroups = <({CcFormField field, List<CcSubmissionAttachment> atts})>[];
    for (final f in attFields) {
      final fieldAtts =
          s.attachments.where((a) => a.fieldId == f.id).toList();
      if (fieldAtts.isNotEmpty) {
        attGroups.add((field: f, atts: fieldAtts));
      }
    }
    // Orphans: attachments not claimed by any named field
    final orphanAtts = s.attachments.where((a) {
      if (a.fieldId == null) return true;
      return !attFields.any((f) => f.id == a.fieldId);
    }).toList();
    final orphanImages = orphanAtts.where((a) => a.isImage).toList();
    final orphanFiles  = orphanAtts.where((a) => !a.isImage).toList();
    // Fallback: if nothing was claimed by any field, show all atts as orphans
    final allUnclaimed = attGroups.isEmpty && attFields.isNotEmpty;
    final fallbackImages = allUnclaimed
        ? s.attachments.where((a) => a.isImage).toList()
        : orphanImages;
    final fallbackFiles = allUnclaimed
        ? s.attachments.where((a) => !a.isImage).toList()
        : orphanFiles;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Header ──
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade200))),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: s.isAnonymous
                  ? Colors.grey.shade100
                  : tc.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: s.isAnonymous ? Colors.grey.shade500 : tc)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis),
              Text(_fmtDateTime(s.createdAt, isAr: isAr),
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ),
          _StatusBadge(status: s.status, isAr: isAr),
          const SizedBox(width: 6),
          InkWell(
            onTap: widget.onClose,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 17, color: Colors.grey.shade400),
            ),
          ),
        ]),
      ),
      // ── Status picker ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: Colors.grey.shade50,
        child: Row(children: [
          Text(isAr ? 'الحالة:' : 'Status:',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(width: 8),
          ...CcSubmissionStatus.values.map((st) => Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => _setStatus(st),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.status == st
                          ? _statusClr(st).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: s.status == st
                              ? _statusClr(st).withValues(alpha: 0.4)
                              : Colors.grey.shade300),
                    ),
                    child: Text(_statusLbl(st, isAr),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: s.status == st
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: s.status == st
                                ? _statusClr(st)
                                : Colors.grey.shade500)),
                  ),
                ),
              )),
        ]),
      ),
      // ── Scrollable body ──
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            // Field values (attachment fields are skipped here)
            for (final v in s.values)
              if (fm[v.fieldId] != null)
                _buildFieldTile(v, fm[v.fieldId]!, isAr, tc),

            // ── Per-field attachment sections ──
            for (final group in attGroups) ...[
              const SizedBox(height: 10),
              _secLabel(group.field.label, count: group.atts.length),
              const SizedBox(height: 6),
              if (group.atts.any((a) => a.isImage))
                _ImageGrid(
                    images: group.atts.where((a) => a.isImage).toList(),
                    context: context),
              if (group.atts.any((a) => !a.isImage)) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: group.atts
                      .where((a) => !a.isImage)
                      .map((a) => _FileTile(a: a))
                      .toList(),
                ),
              ],
            ],

            // ── Fallback: orphan images not matched to any field ──
            if (fallbackImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              _secLabel(isAr ? '🖼 صور المرفقات' : '🖼 Image Attachments',
                  count: fallbackImages.length),
              const SizedBox(height: 8),
              _ImageGrid(images: fallbackImages, context: context),
            ],

            // ── Fallback: orphan files ──
            if (fallbackFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              _secLabel(isAr ? '📎 ملفات مرفقة' : '📎 File Attachments',
                  count: fallbackFiles.length),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: fallbackFiles.map((a) => _FileTile(a: a)).toList(),
              ),
            ],

            // ── Notes ──
            const SizedBox(height: 12),
            _secLabel(isAr ? '💬 ملاحظات داخلية' : '💬 Internal notes'),
            const SizedBox(height: 6),
            if (s.notes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    isAr ? 'لا توجد ملاحظات بعد' : 'No notes yet',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic)),
              )
            else
              for (final n in s.notes) _NoteItem(note: n, isAr: isAr),
            const SizedBox(height: 8),
          ],
        ),
      ),
      // ── Bottom area: status actions + note input ──
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusActionBar(
                status: s.status, isAr: isAr, onConfirm: _setStatus),
            const SizedBox(height: 8),
            Row(children: [
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              style: const TextStyle(fontSize: 13),
              maxLines: 2, minLines: 1,
              decoration: InputDecoration(
                isDense: true,
                hintText: isAr ? 'أضف ملاحظة...' : 'Add a note...',
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade400),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tc, width: 1.5)),
              ),
              onSubmitted: (_) => _postNote(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: tc,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _posting ? null : _postNote,
              borderRadius: BorderRadius.circular(8),
              child: const SizedBox(
                  width: 36, height: 36,
                  child: Icon(Icons.send_rounded,
                      size: 15, color: Colors.white)),
            ),
          ),
        ]),
            ],
          ),
        ),
    ]);
  }

  // Build a value tile for a single field.
  // Attachment/imageAttachment fields are skipped (displayed as sections above).
  Widget _buildFieldTile(
      CcSubmissionValue v, CcFormField f, bool isAr, Color tc) {
    // Skip attachment fields — shown in dedicated sections
    if (f.fieldType == CcFieldType.attachment ||
        f.fieldType == CcFieldType.imageAttachment) {
      return const SizedBox.shrink();
    }

    final raw = v.value;

    // Signature: render actual drawing
    if (f.fieldType == CcFieldType.signature) {
      final strokes = _parseSignature(raw);
      final hasSig  = strokes.isNotEmpty &&
          strokes.any((stroke) => stroke.isNotEmpty);
      return _ValTile(
        label: f.label,
        icon: _fieldIcon(f.fieldType),
        child: hasSig
            ? Container(
                width: double.infinity,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                    painter: _SignaturePainter(strokes: strokes)),
              )
            : Text(isAr ? 'لم يُوقَّع' : 'Not signed',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic)),
      );
    }

    final displayStr = _displayVal(raw, f, isAr: isAr);
    return _ValTile(
      label: f.label,
      icon: _fieldIcon(f.fieldType),
      child: Text(
        displayStr.isEmpty ? '—' : displayStr,
        style: TextStyle(
            fontSize: 12,
            color: displayStr.isEmpty
                ? Colors.grey.shade300
                : Colors.grey.shade800),
      ),
    );
  }

  Widget _secLabel(String text, {int? count}) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF999999))),
          if (count != null) ...[
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEEFF2),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      );
}

// ── Value tile ────────────────────────────────────────────────────────
class _ValTile extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Widget   child;

  const _ValTile(
      {required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEEEFF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 10, color: const Color(0xFFAAAAAA)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: Color(0xFFAAAAAA))),
          ]),
          const SizedBox(height: 4),
          child,
        ]),
      );
}

// ── Image thumbnail grid ──────────────────────────────────────────────
class _ImageGrid extends StatelessWidget {
  final List<CcSubmissionAttachment> images;
  final BuildContext                 context;

  const _ImageGrid({required this.images, required this.context});

  @override
  Widget build(BuildContext _) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(images.length, (i) =>
            _ImageThumb(
              attachment: images[i],
              onTap: () => _openGallery(i),
            )),
      );

  void _openGallery(int initial) => showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _ImageGallery(images: images, initialIndex: initial),
      );
}

class _ImageThumb extends StatefulWidget {
  final CcSubmissionAttachment attachment;
  final VoidCallback           onTap;
  const _ImageThumb({required this.attachment, required this.onTap});

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 72, height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF4A90D9)
                  : Colors.grey.shade200,
              width: _hovered ? 2 : 1,
            ),
            color: Colors.grey.shade100,
            boxShadow: _hovered
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3))]
                : [],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(fit: StackFit.expand, children: [
            AnimatedScale(
              scale: _hovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Image.network(
                widget.attachment.fileUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: Colors.grey.shade400),
              ),
            ),
            if (_hovered)
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                alignment: Alignment.center,
                child: const Icon(Icons.zoom_in_rounded,
                    color: Colors.white, size: 22),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                color: Colors.black.withValues(alpha: 0.4),
                child: Text(widget.attachment.fileName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 8),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── File attachment chip ──────────────────────────────────────────────
class _FileTile extends StatelessWidget {
  final CcSubmissionAttachment a;
  const _FileTile({required this.a});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(a.fileUrl);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 3)
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(a.fileName,
                style: const TextStyle(fontSize: 11, color: Colors.black87)),
            if (a.fileSize != null) ...[
              const SizedBox(width: 4),
              Text(a.fileSizeLabel,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400)),
            ],
          ]),
        ),
      );
}

// ── Note item ─────────────────────────────────────────────────────────
class _NoteItem extends StatelessWidget {
  final CcSubmissionNote note;
  final bool isAr;
  const _NoteItem({required this.note, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final initial = (note.authorFullName?.isNotEmpty == true)
        ? note.authorFullName![0].toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEEFF2))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
                color: Color(0xFFEEEFF2), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold,
                    color: Color(0xFF888888))),
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(note.authorFullName ?? '-',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.black87))),
          Text(_fmtShortDateTime(note.createdAt, isAr: isAr),
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 5),
        Text(note.note,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Image gallery overlay  (no PageView → mouse wheel zooms the image)
// ═══════════════════════════════════════════════════════════════════════
class _ImageGallery extends StatefulWidget {
  final List<CcSubmissionAttachment> images;
  final int                          initialIndex;

  const _ImageGallery(
      {required this.images, required this.initialIndex});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery>
    with TickerProviderStateMixin {
  late int               _index;
  final _transformCtrl = TransformationController();
  late AnimationController _zoomAnimCtrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _zoomAnimCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _index = i);
    _animateZoomTo(Matrix4.identity());
  }

  // Smoothly interpolate each matrix element
  void _animateZoomTo(Matrix4 target) {
    final begin = _transformCtrl.value.clone();
    _zoomAnimCtrl.reset();
    late VoidCallback listener;
    listener = () {
      final t = CurvedAnimation(
              parent: _zoomAnimCtrl, curve: Curves.easeOutCubic)
          .value;
      final m = Matrix4.zero();
      for (int i = 0; i < 16; i++) {
        m.storage[i] = lerpDouble(
                begin.storage[i], target.storage[i], t) ??
            0;
      }
      _transformCtrl.value = m;
      if (_zoomAnimCtrl.isCompleted) {
        _zoomAnimCtrl.removeListener(listener);
      }
    };
    _zoomAnimCtrl.addListener(listener);
    _zoomAnimCtrl.forward();
  }

  void _zoom(double factor) {
    final cur  = _transformCtrl.value.getMaxScaleOnAxis();
    final next = (cur * factor).clamp(0.5, 6.0);
    if ((cur - next).abs() < 0.001) return;
    _animateZoomTo(Matrix4.diagonal3Values(next, next, 1.0));
  }

  Offset? _doubleTapPos;

  void _handleDoubleTap() {
    final cur = _transformCtrl.value.getMaxScaleOnAxis();
    if (cur > 1.5) {
      _animateZoomTo(Matrix4.identity());
    } else {
      const target = 2.5;
      final pos = _doubleTapPos ?? Offset.zero;
      final dx = -(pos.dx * (target - 1));
      final dy = -(pos.dy * (target - 1));
      _animateZoomTo(
          Matrix4.translationValues(dx, dy, 0) *
          Matrix4.diagonal3Values(target, target, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.images[_index];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(children: [
          // ── Main image — Listener captures mouse scroll, GestureDetector double-tap zoom ──
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
              onDoubleTap: _handleDoubleTap,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoom(event.scrollDelta.dy > 0 ? 0.88 : 1.14);
                  }
                },
                child: InteractiveViewer(
                  transformationController: _transformCtrl,
                  minScale: 0.5,
                  maxScale: 6.0,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                          opacity: CurvedAnimation(
                              parent: anim, curve: Curves.easeInOut),
                          child: child),
                      child: Image.network(
                        a.fileUrl,
                        key: ValueKey(_index),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined,
                                size: 48, color: Colors.white54),
                            const SizedBox(height: 8),
                            Text(a.fileName,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Top bar ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ]),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(a.fileName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${_index + 1} / ${widget.images.length}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
                const SizedBox(width: 4),
                _topBtn(Icons.zoom_out_rounded,    () => _zoom(0.75)),
                _topBtn(Icons.zoom_in_rounded,     () => _zoom(1.33)),
                _topBtn(Icons.zoom_out_map_rounded,
                    () => _transformCtrl.value = Matrix4.identity()),
                const SizedBox(width: 4),
                _topBtn(Icons.download_rounded, () async {
                  final uri = Uri.tryParse(a.fileUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                }),
                _topBtn(Icons.close_rounded,
                    () => Navigator.pop(context)),
              ]),
            ),
          ),
          // ── Prev ──
          if (_index > 0)
            Positioned(
              left: 8, top: 0, bottom: 0,
              child: Center(
                  child: _navBtn(Icons.chevron_left_rounded,
                      () => _goTo(_index - 1))),
            ),
          // ── Next ──
          if (_index < widget.images.length - 1)
            Positioned(
              right: 8, top: 0, bottom: 0,
              child: Center(
                  child: _navBtn(Icons.chevron_right_rounded,
                      () => _goTo(_index + 1))),
            ),
          // ── Thumbnail strip ──
          if (widget.images.length > 1)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ]),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  itemCount: widget.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _goTo(i),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _index == i
                                ? Colors.white
                                : Colors.transparent,
                            width: 2),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.network(widget.images[i].fileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade800)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        splashRadius: 18,
      );

  Widget _navBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      );
}
