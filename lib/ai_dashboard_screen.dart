import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';

// ─── palette ─────────────────────────────────────────────────────────────────
const _palette = [
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF10B981),
  Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFEF4444),
  Color(0xFFF97316), Color(0xFF06B6D4),
];
Color _color(int i) => _palette[i % _palette.length];
const _themes = [0, 2, 4, 6, 1]; // color-theme offset presets

// ─── dashboard item model ─────────────────────────────────────────────────────
enum _Kind { kpiGroup, chart, table }

class _DashItem {
  final String id;
  final _Kind kind;
  dynamic raw;
  String chartType;   // 'bar' | 'pie' | 'line' | 'area' | 'horizontal_bar'
  int heightLevel;    // 0-5 → XS/S/M/L/XL/XXL
  int colorTheme;     // index into _themes
  int colSpan;        // 1-32 (columns in a 32-column grid)
  int kpiPerRow;      // desktop KPI cards per row: 1..maxPerRow (colSpan/4)
  int kpiHeightMult;  // mobile KPI height index into _kpiMultHeights (0-5)
  int styleVariant;   // 0=Default 1=Gradient 2=Outlined 3=Minimal 4=TopBar 5=Filled
  bool deleted;

  _DashItem({
    required this.id,
    required this.kind,
    required this.raw,
    this.chartType = 'bar',
    this.heightLevel = 1,
    this.colorTheme = 0,
    this.colSpan = 4,
    this.kpiPerRow = 4,
    this.kpiHeightMult = 1,
    this.styleVariant = 0,
    this.deleted = false,
  });
}

const _heights = [100.0, 140.0, 180.0, 240.0, 320.0, 440.0]; // XS S M L XL XXL
const _kMinHeight         = 2;     // Medium — minimum height level for charts
const _kTableMinHeightLevel = 3;   // L     — minimum selectable level for tables
const _kTableMinHeightPx    = 270.0; // 1.5 × medium (180px) — pixel floor for tables

const _kStyleLabels   = ['Default', 'Gradient', 'Outlined', 'Minimal', 'Top Bar', 'Filled'];
const _kStyleLabelsAr = ['افتراضي', 'تدرج', 'محدد', 'بسيط', 'شريط علوي', 'مملوء'];

// Per-row heights for each KPI multiplier level (height of one row of KPI cards)
const _kpiRowHeights = [80.0, 110.0, 140.0, 180.0, 220.0, 270.0];
const _kpiMultLabels = ['0.5×', '1×', '1.5×', '2×', '2.5×', '3×'];

/// KPI component total height = numRows × rowHeight + row gaps.
/// Always overflow-safe: height adapts to both perRow and multiplier level.
double _kpiAutoHeight(int kpiCount, int effectivePerRow, int multIdx) {
  final numRows = kpiCount == 0
      ? 1
      : ((kpiCount + effectivePerRow - 1) ~/ effectivePerRow).clamp(1, 99);
  final rowH = _kpiRowHeights[multIdx.clamp(0, 5)];
  return numRows * rowH + (numRows - 1) * 8.0; // 8 px gap between rows
}

/// BoxDecoration for a chart/table card outer container, driven by styleVariant.
BoxDecoration _variantDecoration(int variant, Color col) {
  switch (variant) {
    case 1: // Gradient
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [col.withValues(alpha: 0.10), Colors.white],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      );
    case 2: // Outlined
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col, width: 1.5),
      );
    case 3: // Minimal
      return BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      );
    case 4: // Top Bar
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: col, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      );
    case 5: // Filled
      return BoxDecoration(
        color: col,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
      );
    default: // 0 — Default
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      );
  }
}

/// BoxDecoration for an individual KPI card, driven by styleVariant.
BoxDecoration _kpiCardVariantDecoration(int variant, Color col) {
  switch (variant) {
    case 1: // Gradient
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [col.withValues(alpha: 0.18), col.withValues(alpha: 0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      );
    case 2: // Outlined
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col, width: 1.5),
      );
    case 3: // Minimal
      return BoxDecoration(
        color: col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      );
    case 4: // Top Bar
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: col, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      );
    case 5: // Filled
      return BoxDecoration(
        color: col,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
      );
    default: // 0 — Left Border
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: col, width: 4)),
      );
  }
}

// ── translation helpers ────────────────────────────────────────────────────────
/// Returns Arabic value for [key] if [isAr] and a non-empty '_ar' version exists.
String _trStr(Map data, String key, bool isAr) {
  if (isAr) { final v = data['${key}_ar']; if (v is String && v.isNotEmpty) return v; }
  return data[key]?.toString() ?? '';
}

/// Returns Arabic list for [key] if [isAr] and a non-empty '_ar' list exists.
List<String> _trList(Map data, String key, bool isAr) {
  if (isAr) { final v = data['${key}_ar']; if (v is List && v.isNotEmpty) return v.cast<String>(); }
  return (data[key] as List?)?.cast<String>() ?? [];
}

List<_DashItem> _parseItems(Map<String, dynamic> data) {
  final layoutList = (data['_layout'] as List?)?.cast<Map>() ?? [];
  final layoutMap = <String, Map>{};
  for (final l in layoutList) {
    final id = l['id'] as String?;
    if (id != null) layoutMap[id] = l;
  }
  Map lOf(String id) => layoutMap[id] ?? const {};

  final items = <_DashItem>[];
  final kpis = (data['kpis'] as List?)?.cast<Map>() ?? [];
  if (kpis.isNotEmpty) {
    final l = lOf('kpis');
    items.add(_DashItem(
      id: 'kpis', kind: _Kind.kpiGroup, raw: kpis,
      colSpan:      (l['colSpan']      as int?) ?? 32,
      heightLevel:  ((l['heightLevel'] as int?) ?? _kMinHeight).clamp(_kMinHeight, 5),
      colorTheme:   (l['colorTheme']   as int?) ?? 0,
      kpiPerRow:    ((l['kpiPerRow']    as int?) ?? 4).clamp(1, 8),
      kpiHeightMult: ((l['kpiHeightMult'] as int?) ?? 1).clamp(0, 5),
      styleVariant: ((l['styleVariant'] as int?) ?? 0).clamp(0, 5),
    ));
  }
  final charts = (data['charts'] as List?)?.cast<Map>() ?? [];
  for (int i = 0; i < charts.length; i++) {
    final id = 'chart_$i';
    final l = lOf(id);
    final chartType = (l['chartType'] as String?) ?? (charts[i]['type'] as String? ?? 'bar').toLowerCase();
    items.add(_DashItem(
      id: id, kind: _Kind.chart, raw: charts[i],
      chartType:    chartType,
      colSpan:      (l['colSpan']      as int?) ?? 16,
      heightLevel:  ((l['heightLevel'] as int?) ?? _kMinHeight).clamp(_kMinHeight, 5),
      colorTheme:   (l['colorTheme']   as int?) ?? 0,
      styleVariant: ((l['styleVariant'] as int?) ?? 0).clamp(0, 5),
    ));
  }
  final tables = (data['tables'] as List?)?.cast<Map>() ?? [];
  for (int i = 0; i < tables.length; i++) {
    final id = 'table_$i';
    final l = lOf(id);
    items.add(_DashItem(
      id: id, kind: _Kind.table, raw: tables[i],
      colSpan:      (l['colSpan']      as int?) ?? 32,
      heightLevel:  ((l['heightLevel'] as int?) ?? _kTableMinHeightLevel).clamp(_kTableMinHeightLevel, 5),
      colorTheme:   (l['colorTheme']   as int?) ?? 0,
      styleVariant: ((l['styleVariant'] as int?) ?? 0).clamp(0, 5),
    ));
  }
  return items;
}

// ─── main screen — 3 tabs ────────────────────────────────────────────────────
class AiDashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  const AiDashboardScreen({super.key, required this.currentUser});

  @override
  State<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends State<AiDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _functionUrl =
      'https://wxibjgzemtfzkattbpue.supabase.co/functions/v1/ai-dashboard-builder';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4aWJqZ3plbXRmemthdHRicHVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5MTQwMTIsImV4cCI6MjA3MzQ5MDAxMn0.OUXZsVloijKMgFbHtAKIaT7e-c-rAWNKA2Mak1D7SJM';

  late final TabController _tabCtrl;
  final _promptCtrl = TextEditingController();
  final _dashKey = GlobalKey<_InteractiveDashboardState>();
  bool _generating = false;
  Map<String, dynamic>? _result;
  String? _error;
  bool _showTips = false;
  bool _showFilters = false;

  // ── data source filters ──────────────────────────────────────────────────────
  int _daysBack = 30;
  final Set<String> _statusFilter = {'pending','inprogress','prefinished','closed','resolved'};
  final Set<String> _priorityFilter = {'low','medium','high','critical','urgent'};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _gatherAggregatedData() async {
    // ── 1. Tickets ────────────────────────────────────────────────────────────
    final since = DateTime.now().subtract(Duration(days: _daysBack)).toIso8601String();
    var q = supabase.from('tickets').select(
        'id,status,priority,target_department_id,place_id,created_at,assigned_to,'
        'departments:target_department_id(name),places(name)');
    if (widget.currentUser.departmentId != null) {
      q = q.eq('target_department_id', widget.currentUser.departmentId!);
    }
    q = q.gte('created_at', since);
    if (_statusFilter.length < 5) {
      q = q.inFilter('status', _statusFilter.toList());
    }
    if (_priorityFilter.length < 5) {
      q = q.inFilter('priority', _priorityFilter.toList());
    }
    final rows = await q.order('created_at', ascending: false).limit(500);

    final ticketIds  = rows.map((r) => r['id'] as String?).whereType<String>().toList();
    final assigneeIds = rows
        .map((r) => r['assigned_to'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet().cast<String>().toList();

    // ── 2. Tracking points (chunked to stay within URL limits) ────────────────
    final trackingRows = <Map<String, dynamic>>[];
    for (var i = 0; i < ticketIds.length; i += 80) {
      final chunk = ticketIds.sublist(i, (i + 80).clamp(0, ticketIds.length));
      try {
        final batch = await supabase
            .from('ticket_tracking_points')
            .select('ticket_id,created_by,check_in_time,check_out_time,created_at')
            .inFilter('ticket_id', chunk)
            .limit(2000);
        trackingRows.addAll(List<Map<String, dynamic>>.from(batch));
      } catch (_) {}
    }

    // ── 3. User names (assignees + tracking creators) ─────────────────────────
    final trackingUserIds = trackingRows
        .map((r) => r['created_by'] as String?)
        .whereType<String>().toSet();
    final allUserIds = {...assigneeIds, ...trackingUserIds}.toList();
    final nameMap = <String, String>{};
    if (allUserIds.isNotEmpty) {
      try {
        final users = await supabase
            .from('users').select('id,full_name').inFilter('id', allUserIds);
        for (final u in users) {
          final id   = u['id']        as String? ?? '';
          final name = u['full_name'] as String? ?? '';
          if (id.isNotEmpty && name.isNotEmpty) nameMap[id] = name;
        }
      } catch (_) {}
    }

    // ── 4. Ticket-level aggregates ────────────────────────────────────────────
    final statusC     = <String, int>{};
    final deptC       = <String, int>{};
    final placeC      = <String, int>{};
    final priC        = <String, int>{};
    final dayC        = <String, int>{};
    final empTotal    = <String, int>{};
    final empResolved = <String, int>{};
    final empPending  = <String, int>{};
    final empInProg   = <String, int>{};
    int unassigned    = 0;

    for (final r in rows) {
      final s       = r['status']   as String? ?? 'unknown';
      final d       = (r['departments'] as Map?)?['name'] as String? ?? 'Unknown';
      final p       = (r['places']     as Map?)?['name'] as String? ?? 'Unknown';
      final pr      = r['priority'] as String? ?? 'medium';
      final c       = r['created_at'] as String? ?? '';
      final day     = c.length >= 10 ? c.substring(0, 10) : c;
      final empId   = r['assigned_to'] as String?;
      final empName = empId != null ? nameMap[empId] : null;

      statusC[s] = (statusC[s] ?? 0) + 1;
      deptC[d]   = (deptC[d]   ?? 0) + 1;
      placeC[p]  = (placeC[p]  ?? 0) + 1;
      priC[pr]   = (priC[pr]   ?? 0) + 1;
      dayC[day]  = (dayC[day]  ?? 0) + 1;

      if (empName != null && empName.isNotEmpty) {
        empTotal[empName]   = (empTotal[empName]   ?? 0) + 1;
        if (s == 'resolved' || s == 'closed') {
          empResolved[empName] = (empResolved[empName] ?? 0) + 1;
        } else if (s == 'pending') {
          empPending[empName]  = (empPending[empName]  ?? 0) + 1;
        } else if (s == 'inprogress') {
          empInProg[empName]   = (empInProg[empName]   ?? 0) + 1;
        }
      } else {
        unassigned++;
      }
    }

    // ── 5. Time-tracking analysis ─────────────────────────────────────────────
    // Official hours: 08:00 – 15:30 (in minutes from midnight)
    const workStart = 8 * 60;        // 480
    const workEnd   = 15 * 60 + 30;  // 930

    final empTotalMin   = <String, int>{};  // total minutes worked
    final empWorkMin    = <String, int>{};  // minutes inside work hours
    final empAfterMin   = <String, int>{};  // minutes outside work hours
    final empVisits     = <String, int>{};  // visit count
    final hourly        = List<int>.filled(24, 0);
    int workHourVisits  = 0;
    int afterHourVisits = 0;

    for (final t in trackingRows) {
      final empId       = t['created_by']    as String?;
      final checkInStr  = t['check_in_time'] as String?;
      final checkOutStr = t['check_out_time'] as String?;
      if (checkInStr == null) continue;

      final checkIn  = DateTime.tryParse(checkInStr);
      if (checkIn == null) continue;
      final checkOut = checkOutStr != null ? DateTime.tryParse(checkOutStr) : null;

      final empName  = empId != null ? nameMap[empId] : null;
      final hour     = checkIn.toLocal().hour;
      final minOfDay = hour * 60 + checkIn.toLocal().minute;
      final isWork   = minOfDay >= workStart && minOfDay < workEnd;

      hourly[hour]++;
      if (isWork) { workHourVisits++; } else { afterHourVisits++; }

      if (checkOut != null && checkOut.isAfter(checkIn)) {
        final dur = checkOut.difference(checkIn).inMinutes.clamp(0, 480);
        if (empName != null && empName.isNotEmpty) {
          empTotalMin[empName] = (empTotalMin[empName] ?? 0) + dur;
          empVisits[empName]   = (empVisits[empName]   ?? 0) + 1;
          if (isWork) {
            empWorkMin[empName]  = (empWorkMin[empName]  ?? 0) + dur;
          } else {
            empAfterMin[empName] = (empAfterMin[empName] ?? 0) + dur;
          }
        }
      } else if (empName != null && empName.isNotEmpty) {
        empVisits[empName] = (empVisits[empName] ?? 0) + 1;
      }
    }

    final allNames = {...empTotal.keys, ...empTotalMin.keys}.toList()
      ..sort((a, b) => (empTotalMin[b] ?? 0).compareTo(empTotalMin[a] ?? 0));

    final empTimeSummary = allNames.map((name) {
      final totalMin = empTotalMin[name] ?? 0;
      final workMin  = empWorkMin[name]  ?? 0;
      final afterMin = empAfterMin[name] ?? 0;
      final visits   = empVisits[name]   ?? 0;
      final avgMin   = visits > 0 ? totalMin ~/ visits : 0;
      return {
        'name': name,
        'total_hours': (totalMin / 60.0).toStringAsFixed(1),
        'official_hours': (workMin / 60.0).toStringAsFixed(1),
        'after_hours': (afterMin / 60.0).toStringAsFixed(1),
        'visits': visits,
        'avg_min_per_visit': avgMin,
      };
    }).toList();

    // Activity by hour (06:00 – 22:00)
    final hourlyMap = <String, int>{
      for (int h = 6; h <= 22; h++) '${h.toString().padLeft(2, '0')}:00': hourly[h],
    };

    // ── 6. Final output ───────────────────────────────────────────────────────
    final days = (dayC.keys.toList()..sort()).reversed.take(30).toList().reversed.toList();
    final topPlaces = (placeC.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5).map((e) => {'place': e.key, 'count': e.value}).toList();

    final empPerf = (empTotal.keys.toList()
          ..sort((a, b) => (empResolved[b] ?? 0).compareTo(empResolved[a] ?? 0)))
        .map((name) {
          final total    = empTotal[name]    ?? 0;
          final resolved = empResolved[name] ?? 0;
          final rate     = total > 0 ? (resolved / total * 100).round() : 0;
          return {
            'name': name, 'total': total,
            'resolved': empResolved[name] ?? 0,
            'in_progress': empInProg[name] ?? 0,
            'pending': empPending[name] ?? 0,
            'resolution_rate_pct': rate,
          };
        }).toList();

    return {
      'total': rows.length,
      'by_status': statusC,
      'by_department': deptC,
      'by_priority': priC,
      'daily_trend_30d': {for (final d in days) d: dayC[d] ?? 0},
      'top_5_places': topPlaces,
      'employee_performance': empPerf,
      'unassigned_tickets': unassigned,
      // Time tracking
      'employee_time_tracking': empTimeSummary,
      'hourly_activity_distribution': hourlyMap,
      'work_hour_visits': workHourVisits,
      'after_hour_visits': afterHourVisits,
      'total_tracking_visits': trackingRows.length,
    };
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() { _generating = true; _result = null; _error = null; });
    try {
      final data = await _gatherAggregatedData();
      final res = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_anonKey'},
        body: jsonEncode({
          'prompt': prompt, 'data': data, 'language': lang,
          'department_id': widget.currentUser.departmentId,
        }),
      );
      if (res.statusCode == 200) {
        setState(() => _result = jsonDecode(res.body) as Map<String, dynamic>);
      } else {
        setState(() => _error = 'HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showSaveDialog() async {
    if (_result == null) return;
    final l10n = AppLocalizations.safeOf(context);
    final titleCtrl = TextEditingController(text: _result?['dashboard_title'] as String? ?? '');
    String privacy = 'private';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.saveDashboard,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.dashboardTitle,
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('${l10n.dashboardPrivacy}:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'private', label: Text(l10n.privacyPrivate, style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'public',  label: Text(l10n.privacyPublic,  style: const TextStyle(fontSize: 11))),
                    ],
                    selected: {privacy},
                    onSelectionChanged: (s) => setSt(() => privacy = s.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((st) =>
                          st.contains(WidgetState.selected) ? const Color(0xFFf16936) : null),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                final currentData = _dashKey.currentState?.toJson() ?? _result!;
                Navigator.pop(ctx);
                await _saveDashboard(titleCtrl.text.trim(), privacy, currentData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936), foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDashboard(String title, String privacy, Map<String, dynamic> data) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      await supabase.from('saved_dashboards').insert({
        'title': title.isEmpty ? (data['dashboard_title'] ?? 'Dashboard') : title,
        'prompt': _promptCtrl.text.trim(),
        'result': data,
        'created_by': widget.currentUser.id,
        'privacy': privacy,
        'department_id': widget.currentUser.departmentId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.dashboardSaved),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFf16936),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFf16936),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.auto_awesome, size: 18), text: l10n.aiDashboardBuilder),
            Tab(icon: const Icon(Icons.insights, size: 18), text: isAr ? 'تحليل ذكي' : 'Smart Insights'),
            Tab(icon: const Icon(Icons.bookmarks_rounded, size: 18), text: l10n.savedDashboards),
            Tab(icon: const Icon(Icons.dashboard_customize_rounded, size: 18), text: isAr ? 'لوحات مخصصة' : 'Custom Dashboards'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _BuilderTab(
              promptCtrl: _promptCtrl,
              generating: _generating,
              result: _result,
              error: _error,
              showTips: _showTips,
              showFilters: _showFilters,
              daysBack: _daysBack,
              statusFilter: _statusFilter,
              priorityFilter: _priorityFilter,
              onToggleTips: () => setState(() => _showTips = !_showTips),
              onToggleFilters: () => setState(() => _showFilters = !_showFilters),
              onDaysChanged: (v) => setState(() => _daysBack = v),
              onStatusToggle: (s) => setState(() => _statusFilter.contains(s) ? _statusFilter.remove(s) : _statusFilter.add(s)),
              onPriorityToggle: (p) => setState(() => _priorityFilter.contains(p) ? _priorityFilter.remove(p) : _priorityFilter.add(p)),
              onGenerate: _generate,
              onSave: _showSaveDialog,
              dashKey: _dashKey,
            ),
            _LocalInsightsTab(currentUser: widget.currentUser),
            _SavedDashboardsTab(currentUser: widget.currentUser),
            _CustomDashboardsTab(currentUser: widget.currentUser),
          ],
        ),
      ),
    ]);
  }
}

// ─── builder tab ─────────────────────────────────────────────────────────────
class _BuilderTab extends StatelessWidget {
  final TextEditingController promptCtrl;
  final bool generating;
  final Map<String, dynamic>? result;
  final String? error;
  final bool showTips;
  final bool showFilters;
  final int daysBack;
  final Set<String> statusFilter;
  final Set<String> priorityFilter;
  final VoidCallback onToggleTips;
  final VoidCallback onToggleFilters;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onStatusToggle;
  final ValueChanged<String> onPriorityToggle;
  final VoidCallback onGenerate;
  final VoidCallback onSave;
  final GlobalKey<_InteractiveDashboardState> dashKey;

  const _BuilderTab({
    required this.promptCtrl,
    required this.generating,
    required this.result,
    required this.error,
    required this.showTips,
    required this.showFilters,
    required this.daysBack,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onToggleTips,
    required this.onToggleFilters,
    required this.onDaysChanged,
    required this.onStatusToggle,
    required this.onPriorityToggle,
    required this.onGenerate,
    required this.onSave,
    required this.dashKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TipsCard(l10n: l10n, expanded: showTips, onToggle: onToggleTips),
        const SizedBox(height: 10),
        // ── data source filter panel ──────────────────────────────────────────
        _FiltersPanel(
          expanded: showFilters,
          onToggle: onToggleFilters,
          daysBack: daysBack,
          statusFilter: statusFilter,
          priorityFilter: priorityFilter,
          onDaysChanged: onDaysChanged,
          onStatusToggle: onStatusToggle,
          onPriorityToggle: onPriorityToggle,
          isAr: isAr,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFf16936), size: 18),
              const SizedBox(width: 8),
              Text(l10n.aiDashboardBuilder,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: promptCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.aiDashboardPromptHint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(generating ? l10n.generatingDashboard : l10n.generateDashboard,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936), foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: const Color(0xFFf16936).withValues(alpha: 0.5),
              ),
            ),
          ]),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.failedToGenerateDashboard, style: const TextStyle(color: Colors.red, fontSize: 13))),
            ]),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 16),
          _InteractiveDashboard(key: dashKey, data: result!, l10n: l10n),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_add_rounded, size: 18),
              label: Text(l10n.saveDashboard, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ─── tips card ───────────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final bool expanded;
  final VoidCallback onToggle;

  const _TipsCard({required this.l10n, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: const Icon(Icons.lightbulb_outline_rounded, color: Colors.blue, size: 20),
          title: Text(
            isAr ? '📋 كيف تكتب برومبت صحيح؟' : '📋 How to write an effective prompt',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
          ),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.blue),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isAr ? _arContent() : _enContent(),
            ),
          ),
      ]),
    );
  }

  List<Widget> _enContent() => [
        _sectionHeader('📊 What data is available to the AI:'),
        _bullet('Status counts: pending, in-progress, resolved, closed'),
        _bullet('Ticket counts grouped by department'),
        _bullet('Ticket counts grouped by place / location'),
        _bullet('Priority breakdown: low, medium, high, critical'),
        _bullet('Daily ticket count for the last 30 days (trend)'),
        _bullet('Top 5 busiest places by ticket volume'),
        const SizedBox(height: 12),
        _sectionHeader('✍️  5 rules for writing the right prompt:'),
        _tipBlock(icon: '1️⃣', title: 'Be specific — say exactly what to show',
          good: '"Bar chart of open tickets per department + KPI for total resolved + table of top 5 places"',
          bad: '"Show me everything" — too vague, wastes tokens and produces poor output'),
        _tipBlock(icon: '2️⃣', title: 'Use the right action keywords',
          good: 'trend → line chart   •   compare/breakdown → bar or pie   •   top N → table   •   rate/percentage → KPI',
          bad: '"Give me some charts about tickets" — no direction for the AI'),
        _tipBlock(icon: '3️⃣', title: 'One clear goal per prompt',
          good: '"Which departments have the highest backlog of pending tickets? Show bar chart + summary table"',
          bad: '"Show everything about all departments, all statuses, all places, and all priorities at once"'),
        _tipBlock(icon: '4️⃣', title: 'Name the chart type when you know what you want',
          good: '"Pie chart of tickets by status + line chart of 30-day daily trend + KPI for resolution rate"',
          bad: '"Show me charts" — the AI will guess and may not match your needs'),
        _tipBlock(icon: '5️⃣', title: 'Only ask for what the data supports',
          good: '"30-day trend line + which departments have the most unresolved tickets + priority breakdown pie"',
          bad: '"Show tickets from last year" or "list each ticket by name" — only aggregated counts are available'),
        const SizedBox(height: 12),
        _sectionHeader('🚀  Ready-to-use example prompts (copy & paste):'),
        _examplePrompt('"Overview dashboard: KPI for total tickets, KPI for resolution rate, bar chart of tickets by department, pie chart by status, line chart of 30-day trend"'),
        _examplePrompt('"Which departments have the most pending tickets? Show as a bar chart sorted highest to lowest, and add a summary table with counts"'),
        _examplePrompt('"Performance dashboard: KPI for daily average tickets, KPI for critical ticket count, table of top 5 busiest places, line chart of 30-day trend, pie chart by priority"'),
        _examplePrompt('"Compare open vs closed tickets per department as a grouped bar chart, add a KPI for total open tickets and a KPI for the overall resolution rate"'),
        _examplePrompt('"Focus on backlog: bar chart of pending + in-progress tickets by department, KPI for pending count, table showing top 3 overloaded departments"'),
      ];

  List<Widget> _arContent() => [
        _sectionHeader('📊 البيانات المتاحة للذكاء الاصطناعي:'),
        _bullet('أعداد التذاكر حسب الحالة: معلق، قيد التنفيذ، تم الحل، مغلق'),
        _bullet('أعداد التذاكر مجمّعة حسب القسم'),
        _bullet('أعداد التذاكر مجمّعة حسب الموقع / المكان'),
        _bullet('تفصيل الأولوية: منخفض، متوسط، عالي، حرج'),
        _bullet('عدد التذاكر اليومي خلال آخر 30 يوم (الاتجاه الزمني)'),
        _bullet('أكثر 5 مواقع نشاطاً من حيث حجم التذاكر'),
        const SizedBox(height: 12),
        _sectionHeader('✍️  5 قواعد لكتابة برومبت صحيح:'),
        _tipBlock(icon: '1️⃣', title: 'كن محدداً — اذكر بالضبط ما تريد رؤيته',
          good: '"أعطني رسم بار للتذاكر المفتوحة لكل قسم، ومؤشر KPI لإجمالي المحلولة، وجدول لأكثر 5 مواقع نشاطاً"',
          bad: '"اعرض كل شيء" — غامض جداً ويهدر الرصيد ويعطي نتائج ضعيفة'),
        _tipBlock(icon: '2️⃣', title: 'استخدم الكلمات المفتاحية الصحيحة',
          good: 'اتجاه → خط زمني   •   مقارنة/تفصيل → بار أو دائري   •   أفضل N → جدول   •   نسبة/معدل → KPI',
          bad: '"أعطني بعض الرسوم عن التذاكر" — لا توجيه واضح للذكاء الاصطناعي'),
        _tipBlock(icon: '3️⃣', title: 'هدف واحد وواضح في كل برومبت',
          good: '"أريد معرفة أي الأقسام لديها أكبر تراكم من التذاكر المعلقة؟ بار + جدول ملخص"',
          bad: '"اعرض كل شيء عن كل الأقسام وكل الحالات وكل المواقع وكل الأولويات في آنٍ واحد"'),
        _tipBlock(icon: '4️⃣', title: 'حدد نوع الرسم إذا كنت تعرفه',
          good: '"دائري لتوزيع الحالات + خط زمني لاتجاه 30 يوم + KPI لنسبة الحل"',
          bad: '"اعرض لي رسوماً" — سيخمّن الذكاء الاصطناعي وقد لا يطابق احتياجك'),
        _tipBlock(icon: '5️⃣', title: 'اطلب فقط ما تدعمه البيانات',
          good: '"خط زمني 30 يوم والأقسام ذات أعلى تذاكر غير محلولة + دائري للأولويات"',
          bad: '"اعرض تذاكر السنة الماضية" أو "اسرد كل تذكرة بالاسم" — البيانات إحصائية مجمّعة فقط'),
        const SizedBox(height: 12),
        _sectionHeader('🚀  أمثلة جاهزة للنسخ والاستخدام:'),
        _examplePrompt('"لوحة نظرة عامة: KPI إجمالي التذاكر، KPI نسبة الحل، بار حسب القسم، دائري حسب الحالة، خط زمني لاتجاه 30 يوم"'),
        _examplePrompt('"أي الأقسام لديها أكثر التذاكر المعلقة؟ بار مرتب من الأعلى للأدنى + جدول ملخص بالأعداد"'),
        _examplePrompt('"لوحة الأداء: KPI متوسط التذاكر اليومي، KPI عدد التذاكر الحرجة، جدول أكثر 5 مواقع نشاطاً، خط 30 يوم، دائري حسب الأولوية"'),
        _examplePrompt('"قارن التذاكر المفتوحة والمغلقة لكل قسم كبار مجمّع، أضف KPI لإجمالي المفتوحة وKPI لنسبة الحل الكلية"'),
        _examplePrompt('"ركّز على التراكم: بار للتذاكر المعلقة وقيد التنفيذ حسب القسم، KPI لعدد المعلقة، جدول يُظهر أكثر 3 أقسام ضغطاً"'),
      ];

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1565C0))),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ]),
      );

  Widget _tipBlock({required String icon, required String title, required String good, required String bad}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$icon  $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          _exRow('✅', good, const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
          const SizedBox(height: 4),
          _exRow('❌', bad,  const Color(0xFFFFEBEE), const Color(0xFFC62828)),
        ]),
      );

  Widget _exRow(String emoji, String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$emoji ', style: const TextStyle(fontSize: 12)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, color: fg, fontStyle: FontStyle.italic))),
        ]),
      );

  Widget _examplePrompt(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: Colors.indigo.shade400, width: 3)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A237E), fontStyle: FontStyle.italic)),
      );
}

/// Public wrapper so main.dart can embed a saved dashboard on the home tab.
class AiDashboardView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool showTitle;
  final bool readOnly;
  const AiDashboardView({super.key, required this.data, this.showTitle = true, this.readOnly = false});

  @override
  Widget build(BuildContext context) => _InteractiveDashboard(
        data: data,
        l10n: AppLocalizations.safeOf(context),
        showTitle: showTitle,
        readOnly: readOnly,
      );
}

// ─── filters panel ────────────────────────────────────────────────────────────
class _FiltersPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final int daysBack;
  final Set<String> statusFilter;
  final Set<String> priorityFilter;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onStatusToggle;
  final ValueChanged<String> onPriorityToggle;
  final bool isAr;

  const _FiltersPanel({
    required this.expanded,
    required this.onToggle,
    required this.daysBack,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onDaysChanged,
    required this.onStatusToggle,
    required this.onPriorityToggle,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Icon(Icons.filter_list_rounded, color: Colors.teal.shade700, size: 20),
          title: Text(
            isAr ? '⚙️ مصدر البيانات والفلاتر' : '⚙️ Data Source & Filters',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade700),
          ),
          trailing: expanded
              ? Icon(Icons.expand_less, color: Colors.teal.shade600)
              : Icon(Icons.expand_more, color: Colors.teal.shade600),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Date range
              Text(isAr ? 'نطاق التاريخ:' : 'Date range:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [7, 30, 90, 180, 365].map((d) {
                final sel = daysBack == d;
                return GestureDetector(
                  onTap: () => onDaysChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? Colors.teal : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? Colors.teal : Colors.teal.shade200),
                    ),
                    child: Text(
                      isAr ? '$d يوم' : '${d}d',
                      style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.teal.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),
              // Status filter
              Text(isAr ? 'الحالة:' : 'Status:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: {
                'pending': isAr ? 'معلق' : 'Pending',
                'inprogress': isAr ? 'قيد التنفيذ' : 'In Progress',
                'prefinished': isAr ? 'شبه منتهي' : 'Pre-finished',
                'closed': isAr ? 'مغلق' : 'Closed',
                'resolved': isAr ? 'تم الحل' : 'Resolved',
              }.entries.map((e) {
                final sel = statusFilter.contains(e.key);
                return GestureDetector(
                  onTap: () => onStatusToggle(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? Colors.indigo.shade600 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? Colors.indigo.shade600 : Colors.grey.shade300),
                    ),
                    child: Text(e.value,
                        style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),
              // Priority filter
              Text(isAr ? 'الأولوية:' : 'Priority:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: {
                'low': isAr ? 'منخفضة' : 'Low',
                'medium': isAr ? 'متوسطة' : 'Medium',
                'high': isAr ? 'عالية' : 'High',
                'critical': isAr ? 'حرجة' : 'Critical',
                'urgent': isAr ? 'عاجل' : 'Urgent',
              }.entries.map((e) {
                final sel = priorityFilter.contains(e.key);
                final col = e.key == 'critical' || e.key == 'urgent' ? Colors.red.shade600
                    : e.key == 'high' ? Colors.orange.shade700 : Colors.green.shade700;
                return GestureDetector(
                  onTap: () => onPriorityToggle(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? col : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? col : Colors.grey.shade300),
                    ),
                    child: Text(e.value,
                        style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList()),
            ]),
          ),
      ]),
    );
  }
}

// ─── interactive dashboard ────────────────────────────────────────────────────
class _InteractiveDashboard extends StatefulWidget {
  final Map<String, dynamic> data;
  final AppLocalizations l10n;
  final bool showTitle;
  final bool readOnly;
  const _InteractiveDashboard({super.key, required this.data, required this.l10n, this.showTitle = true, this.readOnly = false});

  @override
  State<_InteractiveDashboard> createState() => _InteractiveDashboardState();
}

class _InteractiveDashboardState extends State<_InteractiveDashboard> {
  late List<_DashItem> _items;
  final _dragAccum   = <String, double>{};
  final _dragAccumH  = <String, double>{};
  final _resizingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _items = _parseItems(widget.data);
  }

  /// Serialise current (possibly edited) state back to AI-JSON format.
  Map<String, dynamic> toJson() {
    final vis = _items.where((i) => !i.deleted).toList();
    return {
      'dashboard_title': widget.data['dashboard_title'],
      '_layout': vis.map((i) => {
        'id': i.id,
        'kind': i.kind.name,
        'colSpan': i.colSpan,
        'heightLevel': i.heightLevel,
        'colorTheme': i.colorTheme,
        'chartType': i.chartType,
        'kpiPerRow': i.kpiPerRow,
        'kpiHeightMult': i.kpiHeightMult,
        'styleVariant': i.styleVariant,
      }).toList(),
      'kpis': vis
          .where((i) => i.kind == _Kind.kpiGroup)
          .expand((i) => (i.raw as List).cast<Map>())
          .toList(),
      'charts': vis.where((i) => i.kind == _Kind.chart).map((i) {
        final m = Map<String, dynamic>.from(i.raw as Map);
        m['type'] = i.chartType;
        return m;
      }).toList(),
      'tables': vis
          .where((i) => i.kind == _Kind.table)
          .map((i) => Map<String, dynamic>.from(i.raw as Map))
          .toList(),
    };
  }

  List<List<_DashItem>> _groupIntoRowsN(
      List<_DashItem> vis, int cols, int Function(_DashItem) eff) {
    final rows = <List<_DashItem>>[];
    var row = <_DashItem>[];
    var span = 0;
    for (final item in vis) {
      final cs = eff(item);
      if (span + cs > cols && row.isNotEmpty) {
        rows.add(row); row = []; span = 0;
      }
      row.add(item);
      span += cs;
      if (span >= cols) {
        rows.add(row); row = []; span = 0;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget _buildResizableCard(_DashItem item, List<_DashItem> vis, double totalWidth, int gridCols, bool isMobile) {
    final isResizingW = _resizingIds.contains('w_${item.id}');
    final isResizingH = _resizingIds.contains('h_${item.id}');
    final isResizing  = isResizingW || isResizingH;
    // min colSpan: desktop = 8 (¼); mobile KPI = 4 (½ of 8), mobile non-KPI = no resize
    final minSpan = isMobile
        ? (item.kind == _Kind.kpiGroup ? 4 : gridCols)
        : 8;
    final canResizeW = !isMobile || item.kind == _Kind.kpiGroup;
    // KPI height is always auto-computed from rows — height drag handles always hidden
    final isKpiGroup = item.kind == _Kind.kpiGroup;
    const minHLvl = _kMinHeight;

    Widget handle({
      double? left, double? right, double? top, double? bottom,
      double? width, double? height,
      required MouseCursor cursor,
      required void Function() onStart,
      required void Function(DragUpdateDetails) onUpdate,
      required void Function() onEnd,
      required bool active,
      bool vertical = false,
    }) {
      return Positioned(
        left: left, right: right, top: top, bottom: bottom,
        width: width, height: height,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onStart(),
            onPanUpdate: onUpdate,
            onPanEnd: (_) => onEnd(),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width:  vertical ? (active ? 40 : 28) : (active ? 5 : 4),
                height: vertical ? (active ? 5 : 4)   : (active ? 40 : 28),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFf16936)
                      : Colors.grey.shade400.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void wStart()  => setState(() => _resizingIds.add('w_${item.id}'));
    void wEnd()    => setState(() { _resizingIds.remove('w_${item.id}'); _dragAccum[item.id]  = 0; });
    void hStart()  => setState(() => _resizingIds.add('h_${item.id}'));
    void hEnd()    => setState(() { _resizingIds.remove('h_${item.id}'); _dragAccumH[item.id] = 0; });
    final unitPx = totalWidth / gridCols;
    const kHUnit  = 40.0;

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: isResizing
              ? BoxDecoration(
                  border: Border.all(color: const Color(0xFFf16936), width: 2),
                  borderRadius: BorderRadius.circular(16))
              : null,
          child: _buildDraggableCard(item, vis),
        ),
        // Right width handle (hidden when canResizeW is false)
        if (canResizeW) handle(
          right: 0, top: 0, bottom: 0, width: 18,
          cursor: SystemMouseCursors.resizeLeftRight,
          onStart: wStart, onEnd: wEnd, active: isResizingW, vertical: false,
          onUpdate: (d) {
            _dragAccum[item.id] = (_dragAccum[item.id] ?? 0) + d.delta.dx;
            if (_dragAccum[item.id]! > unitPx && item.colSpan < gridCols) {
              setState(() { item.colSpan = (item.colSpan + 1).clamp(minSpan, gridCols); _dragAccum[item.id] = 0; });
            } else if (_dragAccum[item.id]! < -unitPx && item.colSpan > minSpan) {
              setState(() {
                item.colSpan = (item.colSpan - 1).clamp(minSpan, gridCols);
                _dragAccum[item.id] = 0;
                if (isKpiGroup) item.kpiPerRow = item.kpiPerRow.clamp(1, (item.colSpan ~/ 4).clamp(1, 8));
              });
            }
          },
        ),
        // Left width handle
        if (canResizeW) handle(
          left: 0, top: 0, bottom: 0, width: 18,
          cursor: SystemMouseCursors.resizeLeftRight,
          onStart: wStart, onEnd: wEnd, active: isResizingW, vertical: false,
          onUpdate: (d) {
            _dragAccum[item.id] = (_dragAccum[item.id] ?? 0) - d.delta.dx;
            if (_dragAccum[item.id]! > unitPx && item.colSpan < gridCols) {
              setState(() { item.colSpan = (item.colSpan + 1).clamp(minSpan, gridCols); _dragAccum[item.id] = 0; });
            } else if (_dragAccum[item.id]! < -unitPx && item.colSpan > minSpan) {
              setState(() {
                item.colSpan = (item.colSpan - 1).clamp(minSpan, gridCols);
                _dragAccum[item.id] = 0;
                if (isKpiGroup) item.kpiPerRow = item.kpiPerRow.clamp(1, (item.colSpan ~/ 4).clamp(1, 8));
              });
            }
          },
        ),
        // Height handles — hidden for all KPI (height auto-computed from rows)
        if (!isKpiGroup) handle(
          left: 0, right: 0, bottom: 0, height: 18,
          cursor: SystemMouseCursors.resizeUpDown,
          onStart: hStart, onEnd: hEnd, active: isResizingH, vertical: true,
          onUpdate: (d) {
            _dragAccumH[item.id] = (_dragAccumH[item.id] ?? 0) + d.delta.dy;
            if (_dragAccumH[item.id]! > kHUnit && item.heightLevel < 5) {
              setState(() { item.heightLevel++; _dragAccumH[item.id] = 0; });
            } else if (_dragAccumH[item.id]! < -kHUnit && item.heightLevel > minHLvl) {
              setState(() { item.heightLevel--; _dragAccumH[item.id] = 0; });
            }
          },
        ),
        if (!isKpiGroup) handle(
          left: 0, right: 0, top: 0, height: 18,
          cursor: SystemMouseCursors.resizeUpDown,
          onStart: hStart, onEnd: hEnd, active: isResizingH, vertical: true,
          onUpdate: (d) {
            _dragAccumH[item.id] = (_dragAccumH[item.id] ?? 0) - d.delta.dy;
            if (_dragAccumH[item.id]! > kHUnit && item.heightLevel < 5) {
              setState(() { item.heightLevel++; _dragAccumH[item.id] = 0; });
            } else if (_dragAccumH[item.id]! < -kHUnit && item.heightLevel > minHLvl) {
              setState(() { item.heightLevel--; _dragAccumH[item.id] = 0; });
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = widget.data['dashboard_title'] as String? ?? widget.l10n.aiDashboard;
    final vis = _items.where((i) => !i.deleted).toList();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final gridCols = isMobile ? 8 : 32;

      // min ¼ desktop (8/32); KPI min ½ mobile (4/8), non-KPI always full on mobile
      int effSpan(_DashItem item) {
        if (isMobile) {
          if (item.kind == _Kind.kpiGroup) return item.colSpan.clamp(4, gridCols);
          return gridCols;
        }
        return item.colSpan.clamp(8, gridCols);
      }

      final rows = _groupIntoRowsN(vis, gridCols, effSpan);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.showTitle) ...[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
        if (!widget.readOnly)
          Padding(
            padding: EdgeInsets.only(top: widget.showTitle ? 4 : 0, bottom: 12),
            child: Text(
              isAr
                  ? 'اسحب المقبض للتحريك  •  اسحب الحافة اليمنى لتغيير العرض  •  ▲ ▼ للارتفاع  •  انقر للخصائص  •  ✕ للحذف'
                  : 'Drag handle to move  •  Drag right edge to resize  •  ▲ ▼ height  •  Tap card to edit  •  ✕ to remove',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          )
        else
          SizedBox(height: widget.showTitle ? 8 : 0),
        ...rows.map((rowItems) {
          final usedSpan = rowItems.fold<int>(0, (s, i) => s + effSpan(i));
          final remSpan  = gridCols - usedSpan;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...rowItems.asMap().entries.map((e) {
                  final item = e.value;
                  return Expanded(
                    flex: effSpan(item),
                    child: Padding(
                      padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
                      child: widget.readOnly
                          ? _buildReadOnlyCard(item, isMobile)
                          : _buildResizableCard(item, vis, constraints.maxWidth, gridCols, isMobile),
                    ),
                  );
                }),
                if (!widget.readOnly && remSpan > 0) Expanded(
                  flex: remSpan,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildEmptySlot(insertAfterId: rowItems.last.id),
                  ),
                ),
              ],
            ),
          );
        }),
      ]);
    });
  }

  Widget _buildReadOnlyCard(_DashItem item, bool isMobile) {
    final isKpi = item.kind == _Kind.kpiGroup;
    return Container(
      decoration: isKpi
          ? null
          : _variantDecoration(item.styleVariant, _color(_themes[item.colorTheme])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.kind != _Kind.kpiGroup)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(_label(item),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: item.styleVariant == 5 ? Colors.white : null),
                overflow: TextOverflow.ellipsis),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: _content(item),
        ),
      ]),
    );
  }

  Widget _buildDraggableCard(_DashItem item, List<_DashItem> vis) {
    return DragTarget<String>(
      key: ValueKey('tgt_${item.id}'),
      onWillAcceptWithDetails: (d) => d.data != item.id,
      onAcceptWithDetails: (d) {
        setState(() {
          final from = _items.indexWhere((i) => i.id == d.data);
          final to   = _items.indexWhere((i) => i.id == item.id);
          if (from < 0 || to < 0 || from == to) return;
          final moved = _items.removeAt(from);
          _items.insert(to, moved);
        });
      },
      builder: (ctx, candidates, _) {
        final over = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: over
              ? BoxDecoration(
                  border: Border.all(color: const Color(0xFFf16936), width: 2),
                  borderRadius: BorderRadius.circular(16))
              : null,
          child: _card(item, ctx),
        );
      },
    );
  }

  Widget _card(_DashItem item, BuildContext ctx) {
    // Ghost preview shown while dragging
    Widget ghostPreview() => Material(
      elevation: 8, borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 200, height: 60, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_label(item),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );

    final isMobileCtx = MediaQuery.of(ctx).size.width < 600;
    final filled = item.styleVariant == 5 && item.kind != _Kind.kpiGroup;
    final headerTxtColor = filled ? Colors.white : null;
    final dragIconColor  = filled ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade400;

    return Container(
      decoration: item.kind == _Kind.kpiGroup
          ? null
          : _variantDecoration(item.styleVariant, _color(_themes[item.colorTheme])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: drag handle + title + close ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            Draggable<String>(
              data: item.id,
              feedback: ghostPreview(),
              childWhenDragging: const Icon(Icons.drag_indicator_rounded, color: Color(0xFFf16936), size: 20),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.drag_indicator_rounded, color: dragIconColor, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(_label(item),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: headerTxtColor),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18,
                  color: filled ? Colors.white.withValues(alpha: 0.8) : Colors.red),
              padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
              onPressed: () => setState(() => item.deleted = true),
            ),
          ]),
        ),
        // ── Controls row ──────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: Row(children: [
            _ctrlBtn(Icons.chevron_left,  item.colSpan > 1 ? () => setState(() {
              item.colSpan--;
              if (item.kind == _Kind.kpiGroup) {
                final maxPR = (item.colSpan ~/ 4).clamp(1, 8);
                item.kpiPerRow = item.kpiPerRow.clamp(1, maxPR);
              }
            }) : null),
            GestureDetector(
              onTap: () => setState(() {
                final steps = [4,8,12,16,20,24,28,32];
                final idx = steps.indexWhere((s) => s >= item.colSpan);
                item.colSpan = idx >= 0 && idx < steps.length - 1 ? steps[idx + 1] : 4;
                if (item.kind == _Kind.kpiGroup) {
                  final maxPR = (item.colSpan ~/ 4).clamp(1, 8);
                  item.kpiPerRow = item.kpiPerRow.clamp(1, maxPR);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)),
                child: Text(_spanLabel(item.colSpan),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ),
            ),
            _ctrlBtn(Icons.chevron_right, item.colSpan < 32 ? () => setState(() {
              item.colSpan++;
            }) : null),
            const SizedBox(width: 4),
            // Height: KPI (all sizes) → row-height multiplier; non-KPI → discrete levels
            if (item.kind == _Kind.kpiGroup) ...[
              _ctrlBtn(Icons.expand_more, () {
                // Decrease row-height; when at minimum, increase perRow to compensate
                if (item.kpiHeightMult > 0) {
                  setState(() => item.kpiHeightMult--);
                  return;
                }
                final maxPR = isMobileCtx ? 2 : (item.colSpan ~/ 4).clamp(1, 8);
                if (item.kpiPerRow < maxPR) {
                  setState(() => item.kpiPerRow++);
                } else if (!isMobileCtx && item.colSpan < 32) {
                  setState(() {
                    item.colSpan = (item.colSpan + 4).clamp(4, 32);
                    final newMax = (item.colSpan ~/ 4).clamp(1, 8);
                    item.kpiPerRow = (item.kpiPerRow + 1).clamp(1, newMax);
                  });
                }
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)),
                child: Text(_kpiMultLabels[item.kpiHeightMult.clamp(0, 5)],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ),
              _ctrlBtn(Icons.expand_less,
                  item.kpiHeightMult < _kpiRowHeights.length - 1 ? () => setState(() => item.kpiHeightMult++) : null),
            ] else ...[
              _ctrlBtn(Icons.expand_more,
                  (item.kind == _Kind.table
                      ? item.heightLevel > _kTableMinHeightLevel
                      : item.heightLevel > _kMinHeight)
                  ? () => setState(() => item.heightLevel--) : null),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)),
                child: Text(_heightLabel(item.heightLevel),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ),
              _ctrlBtn(Icons.expand_less, item.heightLevel < 5 ? () => setState(() => item.heightLevel++) : null),
            ],
            // KPI per-row: mobile shows 1-2, desktop shows 1..colSpan÷4
            if (item.kind == _Kind.kpiGroup) ...[
              const SizedBox(width: 4),
              for (int n = 1; n <= (isMobileCtx ? 2 : (item.colSpan ~/ 4).clamp(1, 8)); n++)
                GestureDetector(
                  onTap: () => setState(() => item.kpiPerRow = n),
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.kpiPerRow == n ? Colors.indigo.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: item.kpiPerRow == n ? Colors.indigo : Colors.grey.shade300),
                    ),
                    child: Text('$n×',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: item.kpiPerRow == n ? Colors.indigo : Colors.grey[600])),
                  ),
                ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => item.colorTheme = (item.colorTheme + 1) % 5),
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: _color(_themes[item.colorTheme]), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
              ),
            ),
            if (item.kind == _Kind.chart) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  final types = ['bar', 'pie', 'line', 'area', 'horizontal_bar'];
                  final idx = types.indexOf(item.chartType);
                  item.chartType = types[(idx + 1) % types.length];
                }),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(5)),
                  child: Icon(_chartTypeIcon(item.chartType), size: 13, color: Colors.teal),
                ),
              ),
            ],
          ]),
        ),
        // ── Content — tap opens properties panel ─────────────────────────────
        InkWell(
          onTap: () => _openPropertiesPanel(ctx, item),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _content(item),
          ),
        ),
      ]),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 16, color: onTap == null ? Colors.grey[300] : Colors.grey[600]),
        ),
      );

  String _spanLabel(int cs) {
    const m = {4:'⅛',8:'¼',12:'⅜',16:'½',20:'⅝',24:'¾',28:'⅞',32:'■'};
    return m[cs] ?? '$cs';
  }
  String _heightLabel(int lvl) => const ['XS','S','M','L','XL','XXL'][lvl.clamp(0, 5)];
  IconData _chartTypeIcon(String t) => switch (t) {
        'pie' => Icons.pie_chart,
        'line' => Icons.show_chart,
        'area' => Icons.area_chart,
        'horizontal_bar' => Icons.bar_chart_outlined,
        _ => Icons.bar_chart,
      };

  void _openPropertiesPanel(BuildContext ctx, _DashItem item) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (__, ctrl) => _PropertiesSheet(
          item: item,
          onChanged: () => setState(() {}),
          scrollController: ctrl,
        ),
      ),
    );
  }

  Widget _buildEmptySlot({required String insertAfterId}) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != insertAfterId,
      onAcceptWithDetails: (d) {
        setState(() {
          final fromIdx = _items.indexWhere((i) => i.id == d.data);
          if (fromIdx < 0) return;
          final moved = _items.removeAt(fromIdx);
          final afterIdx = _items.indexWhere((i) => i.id == insertAfterId);
          if (afterIdx < 0) { _items.add(moved); return; }
          _items.insert(afterIdx + 1, moved);
        });
      },
      builder: (ctx, candidates, _) {
        final isOver = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: isOver ? const Color(0xFFf16936).withValues(alpha: 0.08) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOver ? const Color(0xFFf16936) : Colors.grey.shade300,
              width: isOver ? 2 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 28,
              color: isOver ? const Color(0xFFf16936) : Colors.grey[300],
            ),
          ),
        );
      },
    );
  }

  String _label(_DashItem item) {
    if (item.kind == _Kind.kpiGroup) return 'KPIs';
    final m = item.raw as Map;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (isAr) { final v = m['title_ar']; if (v is String && v.isNotEmpty) return v; }
    return m['title'] as String? ?? (item.kind == _Kind.chart ? 'Chart' : 'Table');
  }

  Widget _content(_DashItem item) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final h = _heights[item.heightLevel.clamp(0, 5)];
    switch (item.kind) {
      case _Kind.kpiGroup:
        final kpis = (item.raw as List).cast<Map>();
        final effectivePerRow = isMobile ? item.kpiPerRow.clamp(1, 2) : item.kpiPerRow;
        final kpiH = _kpiAutoHeight(kpis.length, effectivePerRow, item.kpiHeightMult);
        return SizedBox(
          height: kpiH,
          child: _KpiGrid(
            kpis: kpis,
            colorOffset: _themes[item.colorTheme],
            colSpan: item.colSpan,
            fixedHeight: kpiH,
            perRow: effectivePerRow,
            styleVariant: item.styleVariant,
          ),
        );
      case _Kind.chart:
        final d = Map<String, dynamic>.from(item.raw as Map)..['type'] = item.chartType;
        final isPie = item.chartType == 'pie' || item.chartType == 'donut';
        return SizedBox(
          height: h,
          child: ClipRect(
            child: _ChartCard(
              chart: d,
              height: isPie ? h : h - 26,
              colorOffset: _themes[item.colorTheme],
            ),
          ),
        );
      case _Kind.table:
        final tH = h.clamp(_kTableMinHeightPx, double.infinity);
        return SizedBox(
          height: tH,
          child: _TableCard(
            table: item.raw as Map,
            colorTheme: item.colorTheme,
            styleVariant: item.styleVariant,
          ),
        );
    }
  }
}

// ─── properties sheet ─────────────────────────────────────────────────────────
class _PropertiesSheet extends StatefulWidget {
  final _DashItem item;
  final VoidCallback onChanged;
  final ScrollController scrollController;
  const _PropertiesSheet({required this.item, required this.onChanged, required this.scrollController});

  @override
  State<_PropertiesSheet> createState() => _PropertiesSheetState();
}

class _PropertiesSheetState extends State<_PropertiesSheet> {
  late final TextEditingController _titleCtrl;
  final Map<String, TextEditingController> _arCtrls = {};

  TextEditingController _arCtrl(String key, String initial) =>
      _arCtrls.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _getTitle());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _arCtrls.values) c.dispose();
    super.dispose();
  }

  String _getTitle() {
    if (widget.item.kind == _Kind.kpiGroup) return 'KPIs';
    return (widget.item.raw as Map)['title'] as String? ?? '';
  }

  void _setTitle(String v) {
    if (widget.item.kind == _Kind.kpiGroup) return;
    final m = Map<String, dynamic>.from(widget.item.raw as Map);
    m['title'] = v;
    widget.item.raw = m;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final item  = widget.item;
    final col   = _color(_themes[item.colorTheme]);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // drag pill
        Center(child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        )),
        Text(isAr ? 'خصائص المكوّن' : 'Component Properties',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),

        // ── Title ────────────────────────────────────────────────────────────
        if (item.kind != _Kind.kpiGroup) ...[
          _sectionLabel(isAr ? 'العنوان' : 'Title'),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: _setTitle,
          ),
          const SizedBox(height: 20),
        ],

        // ── Layout ───────────────────────────────────────────────────────────
        _sectionLabel(isAr ? 'العرض (من 32 عمود)' : 'Width (of 32 columns)'),
        Row(children: [4,8,12,16,20,24,28,32].asMap().entries.map((e) {
          final cs = e.value;
          final labels = ['⅛','¼','⅜','½','⅝','¾','⅞','■'];
          final sel = item.colSpan == cs;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() {
              item.colSpan = cs;
              if (item.kind == _Kind.kpiGroup) {
                final maxPR = (cs ~/ 4).clamp(1, 8);
                item.kpiPerRow = item.kpiPerRow.clamp(1, maxPR);
              }
              widget.onChanged();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? col : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(labels[e.key],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        }).toList()),
        const SizedBox(height: 14),

        // Height picker — KPI (all sizes) uses row-height multipliers; others use levels
        _sectionLabel(isAr ? 'الارتفاع' : 'Height'),
        if (item.kind == _Kind.kpiGroup) ...[
          // KPI: 0.5× / 1× / 1.5× / 2× / 2.5× / 3× (per-row height)
          Row(children: List.generate(_kpiRowHeights.length, (i) {
            final sel = item.kpiHeightMult == i;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() { item.kpiHeightMult = i; widget.onChanged(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? col : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text(_kpiMultLabels[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : Colors.grey[600]))),
              ),
            ));
          })),
        ] else ...[
          // Desktop / non-KPI: XS / S / M / L / XL / XXL
          Row(children: List.generate(_heights.length, (i) {
            const labels = ['XS','S','M','L','XL','XXL'];
            final minLvl = item.kind == _Kind.table ? _kTableMinHeightLevel : _kMinHeight;
            final sel      = item.heightLevel == i;
            final disabled = i < minLvl;
            return Expanded(child: GestureDetector(
              onTap: disabled ? null : () => setState(() { item.heightLevel = i; widget.onChanged(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.grey.shade200
                      : sel ? col : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(labels[i],
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: disabled
                              ? Colors.grey.shade400
                              : sel ? Colors.white : Colors.grey[600])),
                  if (i == minLvl)
                    Text(isAr ? 'حد أدنى' : 'min',
                        style: TextStyle(fontSize: 8, color: disabled ? Colors.grey.shade400 : col)),
                ]),
              ),
            ));
          })),
        ],
        const SizedBox(height: 20),

        // ── KPI per-row (both mobile/desktop; mobile max 2, desktop max colSpan÷4) ──
        if (item.kind == _Kind.kpiGroup) ...[
          _sectionLabel(isAr ? 'عدد KPI في كل صف' : 'KPIs per Row'),
          Builder(builder: (context) {
            final isMob = MediaQuery.of(context).size.width < 600;
            final maxPR = isMob ? 2 : (item.colSpan ~/ 4).clamp(1, 8);
            return Row(children: [
              for (int n = 1; n <= maxPR; n++)
                Expanded(child: GestureDetector(
                  onTap: () => setState(() { item.kpiPerRow = n; widget.onChanged(); }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: item.kpiPerRow == n ? col : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('$n',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: item.kpiPerRow == n ? Colors.white : Colors.grey[600]))),
                  ),
                )),
            ]);
          }),
          const SizedBox(height: 20),
        ],

        // ── Color theme ──────────────────────────────────────────────────────
        _sectionLabel(isAr ? 'اللون' : 'Color Theme'),
        Row(children: List.generate(5, (i) {
          final c = _color(_themes[i]);
          final sel = item.colorTheme == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() { item.colorTheme = i; widget.onChanged(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: sel ? 34 : 28, height: sel ? 34 : 28,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: sel ? Colors.black54 : Colors.transparent, width: 2),
                  boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : null,
                ),
              ),
            ),
          );
        })),
        const SizedBox(height: 20),

        // ── Style variant ────────────────────────────────────────────────────
        _sectionLabel(isAr ? 'نمط التصميم' : 'Style'),
        Wrap(spacing: 8, runSpacing: 8,
          children: [
            for (int i = 0; i < _kStyleLabels.length; i++)
              _styleChip(i, item, isAr, col),
          ],
        ),
        const SizedBox(height: 20),

        // ── Chart type (charts only) ─────────────────────────────────────────
        if (item.kind == _Kind.chart) ...[
          _sectionLabel(isAr ? 'نوع الرسم البياني' : 'Chart Type'),
          Wrap(spacing: 8, runSpacing: 8,
            children: [
              for (final t in ['bar','horizontal_bar','pie','line','area'])
                _chartTypeChip(t, item, isAr),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ── KPI list (kpiGroup only) ─────────────────────────────────────────
        if (item.kind == _Kind.kpiGroup) ...[
          _sectionLabel(isAr ? 'مؤشرات KPI' : 'KPI Items'),
          ...((item.raw as List).cast<Map>().asMap().entries.map((e) {
            final kpi = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 4, height: 36,
                    decoration: BoxDecoration(
                      color: _color(e.key + _themes[item.colorTheme]),
                      borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kpi['label']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(kpi['value']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ])),
              ]),
            );
          })),
          const SizedBox(height: 20),
        ],

        // ── Table data info (tables only) ────────────────────────────────────
        if (item.kind == _Kind.table) ...[
          _sectionLabel(isAr ? 'بيانات الجدول' : 'Table Data'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: Text(
              isAr
                  ? 'الجدول يحتوي على ${((item.raw as Map)['rows'] as List?)?.length ?? 0} صف(ف) و ${((item.raw as Map)['columns'] as List?)?.length ?? 0} عمود(أعمدة).'
                  : 'Table has ${((item.raw as Map)['rows'] as List?)?.length ?? 0} row(s) across ${((item.raw as Map)['columns'] as List?)?.length ?? 0} column(s).',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Arabic Translations ───────────────────────────────────────────────
        const Divider(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(Icons.translate_rounded, size: 16, color: col),
            title: Text(isAr ? 'ترجمة عربية' : 'Arabic Translations',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            subtitle: Text(
              isAr ? 'يُعرض بدلاً من النص الإنجليزي في الوضع العربي'
                   : 'Shown instead of English text in Arabic mode',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            children: [
              // ── Title AR (chart / table) ──────────────────────────────────
              if (item.kind != _Kind.kpiGroup) ...[
                _sectionLabel(isAr ? 'العنوان (عربي)' : 'Title (Arabic)'),
                TextField(
                  controller: _arCtrl('title_ar',
                      (item.raw as Map)['title_ar']?.toString() ?? ''),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true, hintText: 'بالعربية...',
                  ),
                  textDirection: TextDirection.rtl,
                  onChanged: (v) {
                    final m = Map<String, dynamic>.from(item.raw as Map);
                    v.isEmpty ? m.remove('title_ar') : m['title_ar'] = v;
                    item.raw = m; widget.onChanged();
                  },
                ),
                const SizedBox(height: 12),
              ],
              // ── Series labels AR (chart) ──────────────────────────────────
              if (item.kind == _Kind.chart) ...[
                _sectionLabel(isAr ? 'تسميات السلاسل (عربي)' : 'Series Labels (Arabic)'),
                ...((item.raw as Map)['series'] as List? ?? []).cast<Map>().asMap().entries.map((e) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _arCtrl('sl_${e.key}', e.value['label_ar']?.toString() ?? ''),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        labelText: e.value['label']?.toString() ?? 'Series ${e.key + 1}',
                        hintText: 'بالعربية...',
                      ),
                      textDirection: TextDirection.rtl,
                      onChanged: (v) {
                        v.isEmpty ? e.value.remove('label_ar') : e.value['label_ar'] = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                ),
                // ── Axis labels AR (if ≤ 12) ─────────────────────────────
                Builder(builder: (_) {
                  final xl = ((item.raw as Map)['x_labels'] as List?)?.cast<String>() ?? [];
                  if (xl.isEmpty || xl.length > 12) return const SizedBox.shrink();
                  final xlAr = List<String>.from(
                      ((item.raw as Map)['x_labels_ar'] as List?)?.cast<String>() ??
                      List.filled(xl.length, ''));
                  while (xlAr.length < xl.length) { xlAr.add(''); }
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    _sectionLabel(isAr ? 'تسميات المحور (عربي)' : 'Axis Labels (Arabic)'),
                    ...xl.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _arCtrl('xl_${e.key}', xlAr[e.key]),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true, labelText: e.value, hintText: 'بالعربية...',
                        ),
                        textDirection: TextDirection.rtl,
                        onChanged: (v) {
                          final m = Map<String, dynamic>.from(item.raw as Map);
                          final cur = List<String>.from(
                              (m['x_labels_ar'] as List?)?.cast<String>() ??
                              List.filled(xl.length, ''));
                          while (cur.length < xl.length) { cur.add(''); }
                          cur[e.key] = v;
                          m['x_labels_ar'] = cur;
                          item.raw = m; widget.onChanged();
                        },
                      ),
                    )),
                  ]);
                }),
              ],
              // ── KPI labels AR ─────────────────────────────────────────────
              if (item.kind == _Kind.kpiGroup) ...[
                _sectionLabel(isAr ? 'تسميات KPI (عربي)' : 'KPI Labels (Arabic)'),
                ...((item.raw as List).cast<Map>().asMap().entries.map((e) {
                  final kpi = e.value;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(kpi['label']?.toString() ?? 'KPI ${e.key + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _arCtrl('kl_${e.key}', kpi['label_ar']?.toString() ?? ''),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          labelText: isAr ? 'التسمية' : 'Label',
                          hintText: 'بالعربية...',
                        ),
                        textDirection: TextDirection.rtl,
                        onChanged: (v) {
                          v.isEmpty ? kpi.remove('label_ar') : kpi['label_ar'] = v;
                          widget.onChanged();
                        },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: _arCtrl('ks_${e.key}', kpi['subtitle_ar']?.toString() ?? ''),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          labelText: isAr ? 'التفاصيل' : 'Subtitle',
                          hintText: 'بالعربية...',
                        ),
                        textDirection: TextDirection.rtl,
                        onChanged: (v) {
                          v.isEmpty ? kpi.remove('subtitle_ar') : kpi['subtitle_ar'] = v;
                          widget.onChanged();
                        },
                      )),
                    ]),
                    const SizedBox(height: 10),
                  ]);
                })),
              ],
              // ── Table column names AR ─────────────────────────────────────
              if (item.kind == _Kind.table) ...[
                _sectionLabel(isAr ? 'أسماء الأعمدة (عربي)' : 'Column Names (Arabic)'),
                Builder(builder: (_) {
                  final cols = ((item.raw as Map)['columns'] as List?)?.cast<String>() ?? [];
                  final colsAr = List<String>.from(
                      ((item.raw as Map)['columns_ar'] as List?)?.cast<String>() ??
                      List.filled(cols.length, ''));
                  while (colsAr.length < cols.length) { colsAr.add(''); }
                  return Column(children: cols.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _arCtrl('tc_${e.key}', colsAr[e.key]),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true, labelText: e.value, hintText: 'بالعربية...',
                      ),
                      textDirection: TextDirection.rtl,
                      onChanged: (v) {
                        final m = Map<String, dynamic>.from(item.raw as Map);
                        final cur = List<String>.from(
                            (m['columns_ar'] as List?)?.cast<String>() ??
                            List.filled(cols.length, ''));
                        while (cur.length < cols.length) { cur.add(''); }
                        cur[e.key] = v;
                        m['columns_ar'] = cur;
                        item.raw = m; widget.onChanged();
                      },
                    ),
                  )).toList());
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
  );

  Widget _chartTypeChip(String type, _DashItem item, bool isAr) {
    final labels = {
      'bar': isAr ? 'عمودي' : 'Bar',
      'horizontal_bar': isAr ? 'أفقي' : 'H-Bar',
      'pie': isAr ? 'دائري' : 'Pie',
      'line': isAr ? 'خطي' : 'Line',
      'area': isAr ? 'مساحة' : 'Area',
    };
    final icons = {
      'bar': Icons.bar_chart, 'horizontal_bar': Icons.bar_chart_outlined,
      'pie': Icons.pie_chart, 'line': Icons.show_chart, 'area': Icons.area_chart,
    };
    final sel = item.chartType == type;
    final col = _color(_themes[item.colorTheme]);
    return GestureDetector(
      onTap: () => setState(() { item.chartType = type; widget.onChanged(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? col : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? col : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icons[type], size: 16, color: sel ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 5),
          Text(labels[type]!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.grey[700])),
        ]),
      ),
    );
  }

  Widget _styleChip(int variant, _DashItem item, bool isAr, Color col) {
    final label = isAr ? _kStyleLabelsAr[variant] : _kStyleLabels[variant];
    final icons = [
      Icons.credit_card_outlined,    // Default
      Icons.gradient,                // Gradient
      Icons.check_box_outline_blank, // Outlined
      Icons.minimize_rounded,        // Minimal
      Icons.border_top_rounded,      // Top Bar
      Icons.color_lens_rounded,      // Filled
    ];
    final sel = item.styleVariant == variant;
    return GestureDetector(
      onTap: () => setState(() { item.styleVariant = variant; widget.onChanged(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? col : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? col : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icons[variant], size: 15, color: sel ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.grey[700])),
        ]),
      ),
    );
  }
}

// ─── kpi grid ─────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final List<Map> kpis;
  final int colorOffset;
  final int colSpan;
  final int perRow;        // desktop per-row count; mobile clamps to 1-2
  final int styleVariant;  // 0-4 card style
  /// When set, cards fill this exact height equally across rows.
  final double? fixedHeight;
  const _KpiGrid({
    required this.kpis,
    this.colorOffset = 0,
    this.colSpan = 4,
    this.fixedHeight,
    this.perRow = 4,
    this.styleVariant = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile    = constraints.maxWidth < 480;
      final effectivePR = isMobile ? perRow.clamp(1, 2) : perRow;

      final rows = <List<Map>>[];
      for (int i = 0; i < kpis.length; i += effectivePR) {
        rows.add(kpis.sublist(i, (i + effectivePR).clamp(i, kpis.length)));
      }
      if (rows.isEmpty) return const SizedBox.shrink();

      const rowGap = 8.0;

      // Build a single KPI card widget
      final isAr = Localizations.localeOf(context).languageCode == 'ar';

      Widget kpiCard(MapEntry<int, Map> ke, int rowIdx) {
        final kpi      = ke.value;
        final kpiIdx   = rowIdx * effectivePR + ke.key;
        final col      = _color(kpiIdx + colorOffset);
        final label    = (isAr ? kpi['label_ar']?.toString() : null) ?? kpi['label']?.toString() ?? '';
        final value    = kpi['value']?.toString() ?? '—';
        final subtitle = (isAr ? kpi['subtitle_ar']?.toString() : null) ?? kpi['subtitle'] as String?;
        final change   = kpi['change'] as String?;
        final filled   = styleVariant == 5;
        final labelColor  = filled ? Colors.white.withValues(alpha: 0.8) : Colors.grey[600];
        final valueColor  = filled ? Colors.white : col;
        final subColor    = filled ? Colors.white.withValues(alpha: 0.65) : Colors.grey[500];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: ke.key > 0 ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: _kpiCardVariantDecoration(styleVariant, col),
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 9, color: subColor), overflow: TextOverflow.ellipsis),
                    ],
                    if (change != null && change.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: filled
                              ? Colors.white.withValues(alpha: 0.25)
                              : (change.startsWith('+') ? Colors.green.shade50 : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(change, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                            color: filled
                                ? Colors.white
                                : (change.startsWith('+') ? Colors.green : Colors.red))),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Filler for incomplete last row
      List<Widget> fillers(int count) => List.generate(count,
          (i) => const Expanded(child: Padding(padding: EdgeInsets.only(left: 8), child: SizedBox.shrink())));

      if (fixedHeight != null) {
        // Each row gets an equal slice of the total height
        final totalGaps = rowGap * (rows.length - 1);
        final rowH = (fixedHeight! - totalGaps) / rows.length;
        return Column(
          children: rows.asMap().entries.map((re) {
            final rowIdx = re.key;
            final row    = re.value;
            return Container(
              height: rowH.clamp(40.0, double.infinity),
              margin: EdgeInsets.only(bottom: rowIdx < rows.length - 1 ? rowGap : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...row.asMap().entries.map((ke) => kpiCard(ke, rowIdx)),
                  ...fillers(effectivePR - row.length),
                ],
              ),
            );
          }).toList(),
        );
      }

      // No fixed height — use IntrinsicHeight so cards in each row share the tallest height
      return Column(
        children: rows.asMap().entries.map((re) {
          final rowIdx = re.key;
          final row    = re.value;
          return Padding(
            padding: EdgeInsets.only(bottom: rowIdx < rows.length - 1 ? rowGap : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...row.asMap().entries.map((ke) => kpiCard(ke, rowIdx)),
                  ...fillers(effectivePR - row.length),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// ─── chart card (no title — shown in action bar) ──────────────────────────────
class _ChartCard extends StatelessWidget {
  final Map chart;
  final double height;
  final int colorOffset;
  const _ChartCard({required this.chart, this.height = 220, this.colorOffset = 0});

  @override
  Widget build(BuildContext context) {
    final type   = (chart['type'] as String? ?? 'bar').toLowerCase();
    final series = (chart['series'] as List?)?.cast<Map>() ?? [];
    final isPie  = type == 'pie' || type == 'donut';
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: switch (type) {
              'pie' || 'donut'          => _PieChart(chart: chart, colorOffset: colorOffset),
              'line'                    => _LineChart(chart: chart, colorOffset: colorOffset, filled: false),
              'area'                    => _LineChart(chart: chart, colorOffset: colorOffset, filled: true),
              'horizontal_bar'          => _BarChart(chart: chart, colorOffset: colorOffset, horizontal: true),
              _                         => _BarChart(chart: chart, colorOffset: colorOffset),
            },
          ),
          if (!isPie && series.isNotEmpty) _Legend(series: series, colorOffset: colorOffset),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<Map> series;
  final int colorOffset;
  const _Legend({required this.series, this.colorOffset = 0});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 5,
        children: series.asMap().entries.map((e) {
          final label = (isAr
              ? e.value['label_ar']?.toString()
              : null) ?? e.value['label']?.toString() ?? 'Series ${e.key + 1}';
          final col = _color(e.key + colorOffset);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(label,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[700]),
                softWrap: true, maxLines: 2)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── bar chart ────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final Map chart;
  final int colorOffset;
  final bool horizontal;
  const _BarChart({required this.chart, this.colorOffset = 0, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final labels = _trList(chart, 'x_labels', isAr);
    final series = (chart['series'] as List?)?.cast<Map>() ?? [];
    if (labels.isEmpty || series.isEmpty) return const Center(child: Text('No data'));

    final groups = labels.asMap().entries.map((e) {
      final i = e.key;
      return BarChartGroupData(
        x: i,
        barRods: series.asMap().entries.map((se) {
          final data = (se.value['data'] as List?)?.cast<num>() ?? [];
          final val  = i < data.length ? data[i].toDouble() : 0.0;
          return BarChartRodData(
            toY: val, color: _color(se.key + colorOffset), width: horizontal ? 10 : 14,
            borderRadius: horizontal
                ? const BorderRadius.horizontal(right: Radius.circular(4))
                : const BorderRadius.vertical(top: Radius.circular(4)));
        }).toList(),
      );
    }).toList();

    final maxY = series
        .expand((s) => (s['data'] as List? ?? []).cast<num>())
        .fold<double>(0, (m, v) => v.toDouble() > m ? v.toDouble() : m);

    Widget labelWidget(double v, _) {
      final idx = v.toInt();
      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 52,
          child: Text(labels[idx],
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
              softWrap: true, maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return BarChart(BarChartData(
      barGroups: groups, maxY: maxY * 1.2,
      gridData: FlGridData(drawVerticalLine: !horizontal, drawHorizontalLine: horizontal),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: horizontal ? 90 : 32,
          getTitlesWidget: (v, meta) {
            if (!horizontal) return const SizedBox.shrink();
            final idx = v.toInt();
            if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 84,
                  child: Text(labels[idx],
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.right,
                      softWrap: true, maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ));
          },
        )),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: !horizontal, reservedSize: 40,
          getTitlesWidget: labelWidget,
        )),
      ),
    ));
  }
}

// ─── pie chart ────────────────────────────────────────────────────────────────
class _PieChart extends StatelessWidget {
  final Map chart;
  final int colorOffset;
  const _PieChart({required this.chart, this.colorOffset = 0});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    // x_labels = slice names; series[0].data = values
    var labels = _trList(chart, 'x_labels', isAr);
    final series  = (chart['series'] as List?)?.cast<Map>() ?? [];
    final rawData = series.isNotEmpty
        ? (series[0]['data'] as List?)?.cast<num>() ?? []
        : (chart['data'] as List?)?.cast<num>() ?? [];
    if (labels.isEmpty && rawData.isNotEmpty) {
      labels = List.generate(rawData.length, (i) => 'Item ${i + 1}');
    }
    if (labels.isEmpty || rawData.isEmpty) return const Center(child: Text('No data'));

    final total = rawData.fold<double>(0, (s, v) => s + v.toDouble());
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      // Decide layout: if very narrow, stack vertically
      final stackVertically = available < 300;
      // Radius scales with available space — kept small to stay within card bounds
      final radius = stackVertically
          ? (available / 2 * 0.58).clamp(26.0, 68.0)
          : (available * 0.24).clamp(26.0, 68.0);
      final centerR = (radius * 0.22).clamp(6.0, 20.0);

      final sections = rawData.asMap().entries.map((e) {
        final pct = total > 0 ? e.value.toDouble() / total * 100 : 0.0;
        // Only show label on slices large enough to fit text
        final showLabel = pct > 7.0;
        return PieChartSectionData(
          value: e.value.toDouble(), color: _color(e.key + colorOffset),
          title: showLabel ? '${pct.toStringAsFixed(1)}%' : '',
          titleStyle: TextStyle(
            fontSize: (radius * 0.15).clamp(8.0, 11.0),
            fontWeight: FontWeight.bold, color: Colors.white),
          radius: radius,
        );
      }).toList();

      final pieWidget = PieChart(PieChartData(
        sections: sections, sectionsSpace: 2, centerSpaceRadius: centerR));

      final legendItems = labels.asMap().entries.map((e) {
        final pct = total > 0 && e.key < rawData.length
            ? rawData[e.key].toDouble() / total * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(width: 9, height: 9,
                  decoration: BoxDecoration(color: _color(e.key + colorOffset), shape: BoxShape.circle)),
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(
              '${e.value}  ${pct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 9.5),
              softWrap: true, maxLines: 3,
              overflow: TextOverflow.ellipsis)),
          ]),
        );
      }).toList();

      if (stackVertically) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: radius * 2.05, child: pieWidget),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 4, children: legendItems),
          ],
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(flex: 3, child: pieWidget),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: legendItems,
          ),
        ),
      ]);
    });
  }
}

// ─── line chart ───────────────────────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final Map chart;
  final int colorOffset;
  final bool filled;
  const _LineChart({required this.chart, this.colorOffset = 0, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final isAr  = Localizations.localeOf(context).languageCode == 'ar';
    final labels = _trList(chart, 'x_labels', isAr);
    final series = (chart['series'] as List?)?.cast<Map>() ?? [];
    if (labels.isEmpty || series.isEmpty) return const Center(child: Text('No data'));

    final lineBars = series.asMap().entries.map((se) {
      final data = (se.value['data'] as List?)?.cast<num>() ?? [];
      final col  = _color(se.key + colorOffset);
      return LineChartBarData(
        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
        color: col, isCurved: true, barWidth: filled ? 2 : 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: col.withValues(alpha: filled ? 0.22 : 0.08),
        ),
      );
    }).toList();

    final maxY = series
        .expand((s) => (s['data'] as List? ?? []).cast<num>())
        .fold<double>(0, (m, v) => v.toDouble() > m ? v.toDouble() : m);

    return LineChart(LineChartData(
      lineBarsData: lineBars, maxY: maxY * 1.2,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 40,
          interval: (labels.length / 5).ceilToDouble(),
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx >= labels.length || idx < 0) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 52,
                  child: Text(labels[idx],
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                      softWrap: true, maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ));
          },
        )),
      ),
    ));
  }
}

// ─── table card ───────────────────────────────────────────────────────────────
class _TableCard extends StatefulWidget {
  final Map table;
  final int  colorTheme;
  final int  styleVariant;
  const _TableCard({
    required this.table,
    this.colorTheme  = 0,
    this.styleVariant = 0,
  });
  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  int?   _sortCol;
  bool   _sortAsc       = true;
  String _globalQ       = '';
  final  _colFilters    = <int, String>{};
  bool   _showColFilters = false;
  bool   _syncing       = false;
  late final ScrollController _hHdr;
  late final ScrollController _hBody;
  late final ScrollController _hScroll; // bottom visible scrollbar

  static const _kMinColW = 90.0;

  static const _valueColors = {
    'pending':     Color(0xFFFFF3E0), 'inprogress':  Color(0xFFE3F2FD),
    'prefinished': Color(0xFFF3E5F5), 'closed':      Color(0xFFE8F5E9),
    'resolved':    Color(0xFFE8F5E9), 'open':        Color(0xFFE3F2FD),
    'low':         Color(0xFFE8F5E9), 'medium':      Color(0xFFFFF9C4),
    'high':        Color(0xFFFFECB3), 'critical':    Color(0xFFFFEBEE),
    'urgent':      Color(0xFFFFCDD2),
  };
  static const _valueFgColors = {
    'pending':     Color(0xFFE65100), 'inprogress':  Color(0xFF1565C0),
    'prefinished': Color(0xFF6A1B9A), 'closed':      Color(0xFF2E7D32),
    'resolved':    Color(0xFF2E7D32), 'open':        Color(0xFF1565C0),
    'low':         Color(0xFF2E7D32), 'medium':      Color(0xFFF57F17),
    'high':        Color(0xFFE65100), 'critical':    Color(0xFFC62828),
    'urgent':      Color(0xFFB71C1C),
  };

  @override
  void initState() {
    super.initState();
    _hHdr    = ScrollController();
    _hBody   = ScrollController();
    _hScroll = ScrollController();
    _hHdr.addListener(_syncFromHdr);
    _hBody.addListener(_syncFromBody);
    _hScroll.addListener(_syncFromScroll);
  }

  void _syncAll(double offset, ScrollController skip) {
    for (final c in [_hHdr, _hBody, _hScroll]) {
      if (identical(c, skip)) continue;
      if (c.hasClients && c.offset != offset) c.jumpTo(offset);
    }
  }

  void _syncFromHdr()    { if (_syncing) return; _syncing = true; _syncAll(_hHdr.offset,    _hHdr);    _syncing = false; }
  void _syncFromBody()   { if (_syncing) return; _syncing = true; _syncAll(_hBody.offset,   _hBody);   _syncing = false; }
  void _syncFromScroll() { if (_syncing) return; _syncing = true; _syncAll(_hScroll.offset, _hScroll); _syncing = false; }

  @override
  void dispose() {
    _hHdr
      ..removeListener(_syncFromHdr)
      ..dispose();
    _hBody
      ..removeListener(_syncFromBody)
      ..dispose();
    _hScroll
      ..removeListener(_syncFromScroll)
      ..dispose();
    super.dispose();
  }

  // ── internal table style resolved from variant + colorTheme ──────────────
  ({Color hdrBg, Color hdrText, Color evenBg, Color oddBg,
    Color dividerColor, bool outerBorder}) _tStyle(Color col) {
    switch (widget.styleVariant) {
      case 1: // Gradient — theme-color header
        return (
          hdrBg: col.withValues(alpha: 0.12),
          hdrText: col,
          evenBg: Colors.white,
          oddBg:  col.withValues(alpha: 0.04),
          dividerColor: col.withValues(alpha: 0.15),
          outerBorder: false,
        );
      case 2: // Outlined — bordered cells
        return (
          hdrBg: Colors.grey.shade100,
          hdrText: Colors.grey.shade700,
          evenBg: Colors.white,
          oddBg:  Colors.white,
          dividerColor: Colors.grey.shade300,
          outerBorder: true,
        );
      case 3: // Minimal — no fills
        return (
          hdrBg: Colors.transparent,
          hdrText: Colors.grey.shade600,
          evenBg: Colors.transparent,
          oddBg:  Colors.transparent,
          dividerColor: Colors.grey.shade200,
          outerBorder: false,
        );
      case 4: // Top Bar — semi-dark header, white text
        return (
          hdrBg: col.withValues(alpha: 0.65),
          hdrText: Colors.white,
          evenBg: Colors.white,
          oddBg:  col.withValues(alpha: 0.05),
          dividerColor: Colors.grey.shade100,
          outerBorder: false,
        );
      case 5: // Filled — solid header, white text
        return (
          hdrBg: col,
          hdrText: Colors.white,
          evenBg: Colors.white,
          oddBg:  col.withValues(alpha: 0.07),
          dividerColor: Colors.grey.shade100,
          outerBorder: false,
        );
      default: // 0 — Default (orange accent)
        return (
          hdrBg: const Color(0xFFf16936).withValues(alpha: 0.10),
          hdrText: const Color(0xFF333333),
          evenBg: Colors.white,
          oddBg:  Colors.grey.shade50,
          dividerColor: Colors.grey.shade100,
          outerBorder: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr      = Localizations.localeOf(context).languageCode == 'ar';
    final rawColumns = (widget.table['columns'] as List?)?.cast<String>() ?? [];
    final arColumns  = isAr ? (widget.table['columns_ar'] as List?)?.cast<String>() : null;
    final columns    = (arColumns != null && arColumns.length == rawColumns.length)
        ? arColumns : rawColumns;
    var   allRows = (widget.table['rows'] as List?)
        ?.map((r) => (r as List).cast<String>()).toList() ?? [];
    if (columns.isEmpty) return const SizedBox.shrink();

    // ── Filter + sort ──────────────────────────────────────────────────────
    var rows = allRows;
    if (_globalQ.isNotEmpty) {
      final q = _globalQ.toLowerCase();
      rows = rows.where((r) => r.any((c) => c.toLowerCase().contains(q))).toList();
    }
    _colFilters.forEach((ci, fq) {
      if (fq.isEmpty) return;
      final q = fq.toLowerCase();
      rows = rows.where((r) => ci < r.length && r[ci].toLowerCase().contains(q)).toList();
    });
    if (_sortCol != null && _sortCol! < columns.length) {
      rows = List.from(rows)..sort((a, b) {
        final av = _sortCol! < a.length ? a[_sortCol!] : '';
        final bv = _sortCol! < b.length ? b[_sortCol!] : '';
        final na = double.tryParse(av.replaceAll(',', ''));
        final nb = double.tryParse(bv.replaceAll(',', ''));
        final cmp = (na != null && nb != null) ? na.compareTo(nb) : av.compareTo(bv);
        return _sortAsc ? cmp : -cmp;
      });
    }

    final activeFilters = _colFilters.values.where((v) => v.isNotEmpty).length;
    final accentCol     = _color(_themes[widget.colorTheme]);
    final style         = _tStyle(accentCol);

    return LayoutBuilder(builder: (ctx, constraints) {
      final availW  = constraints.maxWidth;
      // Each column at least _kMinColW; expand to fill if there's room
      final colW    = (availW / columns.length).clamp(_kMinColW, double.infinity);
      final tableW  = colW * columns.length;

      // ── Header row ───────────────────────────────────────────────────────
      Widget headerRow() => Container(
        color: style.hdrBg,
        child: Row(children: columns.asMap().entries.map((e) {
          final isSorted = _sortCol == e.key;
          return GestureDetector(
            onTap: () => setState(() {
              _sortCol == e.key ? _sortAsc = !_sortAsc : (() { _sortCol = e.key; _sortAsc = true; })();
            }),
            child: SizedBox(
              width: colW,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(e.value,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                          color: style.hdrText),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 3),
                  isSorted
                      ? Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10, color: style.hdrText.withValues(alpha: 0.9))
                      : Icon(Icons.unfold_more, size: 10,
                            color: style.hdrText.withValues(alpha: 0.35)),
                ]),
              ),
            ),
          );
        }).toList()),
      );

      // ── Data row ─────────────────────────────────────────────────────────
      Widget dataRow(int idx, List<String> row) => Container(
        decoration: BoxDecoration(
          color: idx.isEven ? style.evenBg : style.oddBg,
          border: Border(bottom: BorderSide(color: style.dividerColor, width: 0.8)),
        ),
        child: Row(children: List.generate(columns.length, (ci) {
          final cell    = ci < row.length ? row[ci] : '';
          final cellKey = cell.trim().toLowerCase();
          final bgColor = _valueColors[cellKey];
          final fgColor = _valueFgColors[cellKey];
          return SizedBox(
            width: colW,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: bgColor != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: bgColor, borderRadius: BorderRadius.circular(5)),
                      child: Text(cell,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgColor),
                          overflow: TextOverflow.ellipsis),
                    )
                  : Text(cell,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[800]),
                      overflow: TextOverflow.ellipsis),
            ),
          );
        })),
      );

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Toolbar ─────────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: SizedBox(
            height: 30,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: isAr ? 'بحث...' : 'Search...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, size: 15, color: Colors.grey[400]),
                prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                suffixIcon: _globalQ.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _globalQ = ''),
                        child: Icon(Icons.close_rounded, size: 13, color: Colors.grey[500]))
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide(color: accentCol, width: 1.5)),
              ),
              style: const TextStyle(fontSize: 11),
              onChanged: (v) => setState(() => _globalQ = v),
            ),
          )),
          const SizedBox(width: 5),
          // Filter toggle
          SizedBox(width: 30, height: 30, child: Stack(clipBehavior: Clip.none, children: [
            InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => setState(() => _showColFilters = !_showColFilters),
              child: Container(
                decoration: BoxDecoration(
                  color: _showColFilters ? accentCol.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: _showColFilters ? accentCol : Colors.grey.shade300),
                ),
                child: Center(child: Icon(Icons.filter_list_rounded, size: 15,
                    color: _showColFilters ? accentCol : Colors.grey[500])),
              ),
            ),
            if (activeFilters > 0)
              Positioned(right: -3, top: -3, child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(color: accentCol, shape: BoxShape.circle),
                child: Center(child: Text('$activeFilters',
                    style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
              )),
          ])),
          if (_globalQ.isNotEmpty || activeFilters > 0) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () => setState(() { _globalQ = ''; _colFilters.clear(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200)),
                child: Text(isAr ? 'مسح' : 'Clear',
                    style: TextStyle(fontSize: 10, color: Colors.red.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),

        // ── Column filters (collapsible, multi-row responsive grid) ────────────
        if (_showColFilters) ...[
          const SizedBox(height: 5),
          Builder(builder: (_) {
            final perRow = availW <= 400 ? 3 : availW <= 680 ? 4 : availW <= 960 ? 6 : 8;
            final entries = columns.asMap().entries.toList();
            final rowCount = (entries.length / perRow).ceil();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(rowCount, (ri) {
                final start = ri * perRow;
                final chunk = entries.sublist(
                    start, (start + perRow).clamp(0, entries.length));
                return Padding(
                  padding: EdgeInsets.only(bottom: ri < rowCount - 1 ? 4 : 0),
                  child: Row(children: chunk.asMap().entries.map((ce) {
                    final ci = ce.key;
                    final e  = ce.value;
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: ci < chunk.length - 1 ? 4 : 0),
                      child: SizedBox(
                        height: 30,
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: e.value,
                            hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.search_rounded, size: 15,
                                color: Colors.grey[400]),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 28, minHeight: 28),
                            suffixIcon: (_colFilters[e.key]?.isNotEmpty ?? false)
                                ? GestureDetector(
                                    onTap: () =>
                                        setState(() => _colFilters.remove(e.key)),
                                    child: Icon(Icons.close_rounded,
                                        size: 13, color: Colors.grey[500]))
                                : null,
                            suffixIconConstraints:
                                const BoxConstraints(minWidth: 24, minHeight: 24),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide:
                                    BorderSide(color: accentCol, width: 1.5)),
                          ),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (v) => setState(() => v.isEmpty
                              ? _colFilters.remove(e.key)
                              : _colFilters[e.key] = v),
                        ),
                      ),
                    ));
                  }).toList()),
                );
              }),
            );
          }),
        ],

        // ── Row count when filtering ─────────────────────────────────────────
        if (_globalQ.isNotEmpty || activeFilters > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              isAr ? '${rows.length} / ${allRows.length} صف' : '${rows.length} / ${allRows.length} rows',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ),

        const SizedBox(height: 8),

        // ── Table: sticky header + scrollable body ───────────────────────────
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: style.outerBorder
                  ? Border.all(color: style.dividerColor)
                  : Border.all(color: Colors.grey.shade200, width: 0.5),
            ),
            child: Column(children: [
              // Sticky header (horizontal scroll synced with body)
              SingleChildScrollView(
                controller: _hHdr,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(width: tableW, child: headerRow()),
              ),
              Container(height: 1, color: style.dividerColor),

              // Scrollable data area
              if (rows.isEmpty)
                Expanded(child: Center(
                  child: Text(isAr ? 'لا توجد نتائج' : 'No matching rows',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ))
              else
                Expanded(child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _hBody,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: tableW,
                      child: Column(children: rows.asMap().entries
                          .map((e) => dataRow(e.key, e.value))
                          .toList()),
                    ),
                  ),
                )),
            ]),
          ),
        )),

        // ── Bottom horizontal scrollbar (always visible on desktop) ──────────
        SizedBox(
          height: 14,
          child: Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: tableW, height: 1),
            ),
          ),
        ),
      ]);
    });
  }
}

// ─── smart insights tab (local analysis, no external AI) ─────────────────────
class _LocalInsightsTab extends StatefulWidget {
  final UserModel currentUser;
  const _LocalInsightsTab({required this.currentUser});

  @override
  State<_LocalInsightsTab> createState() => _LocalInsightsTabState();
}

class _LocalInsightsTabState extends State<_LocalInsightsTab> {
  bool _loading = true;
  String? _error;

  List<MapEntry<String, int>> _topKeywords   = [];
  List<Map<String, dynamic>> _stuckTickets   = [];
  List<MapEntry<String, int>> _repeatedTitles = [];
  int _priorityRisk = 0;
  List<Map<String, dynamic>> _deptRates = [];
  int _total = 0;

  static const _enStop = {
    'the','a','an','and','or','in','on','at','to','for','of','is','it','this',
    'that','was','are','be','with','from','by','not','have','has','had','he',
    'she','they','we','i','my','your','our','do','does','did','can','will',
    'would','should','could','may','might','no','new','please','hi','hello',
    'issue','problem','ticket','request','help','need','want','get','now',
    'just','also','but','so','if','then','very','been','all','one','its',
  };
  static const _arStop = {
    'في','من','على','إلى','هذا','هذه','التي','الذي','أن','كان','كانت','مع',
    'عن','لا','لم','لن','هل','قد','بعد','قبل','حتى','عند','لقد','ما','هو',
    'هي','هم','أنا','نحن','تذكرة','طلب','مشكلة','مساعدة','عاجل','يرجى',
    'جديد','جديدة','عندي','عندنا','نريد','أريد','الرجاء','خلال','حول',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      var q = supabase.from('tickets').select(
          'id,title,description,status,priority,created_at,updated_at,'
          'departments:target_department_id(name)');
      if (widget.currentUser.departmentId != null) {
        q = q.eq('target_department_id', widget.currentUser.departmentId!);
      }
      final rows = await q.order('created_at', ascending: false).limit(300);
      _analyze(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _analyze(List<Map<String, dynamic>> rows) {
    _total = rows.length;
    final now = DateTime.now();

    // 1. Keyword frequency from titles + descriptions
    final freq = <String, int>{};
    for (final r in rows) {
      final txt = '${r['title'] ?? ''} ${r['description'] ?? ''}'.toLowerCase();
      for (final raw in txt.split(RegExp(r'[\s\.,،؛:!\?؟\-_/\\]+'))) {
        final w = raw.replaceAll(RegExp(r'[^\w؀-ۿ]'), '').trim();
        if (w.length > 2 && !_enStop.contains(w) && !_arStop.contains(w)) {
          freq[w] = (freq[w] ?? 0) + 1;
        }
      }
    }
    _topKeywords = (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(12).toList();

    // 2. Stuck tickets (pending/inprogress, no update for 5+ days)
    _stuckTickets = rows.where((r) {
      final s  = r['status'] as String? ?? '';
      if (s != 'pending' && s != 'inprogress') return false;
      final up = DateTime.tryParse(r['updated_at'] as String? ?? '') ?? now;
      return now.difference(up).inDays >= 5;
    }).map((r) {
      final up = DateTime.tryParse(r['updated_at'] as String? ?? '') ?? now;
      return {
        'title':  r['title']  ?? '',
        'status': r['status'] ?? '',
        'dept':   (r['departments'] as Map?)?['name'] ?? 'Unknown',
        'days':   now.difference(up).inDays,
      };
    }).toList()
      ..sort((a, b) => (b['days'] as int).compareTo(a['days'] as int));

    // 3. Repeated issues (exact same normalized title, count > 1)
    final titleC = <String, int>{};
    for (final r in rows) {
      final t = (r['title'] as String? ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (t.length > 3) titleC[t] = (titleC[t] ?? 0) + 1;
    }
    _repeatedTitles = (titleC.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value))).take(8).toList();

    // 4. High/critical tickets still open
    _priorityRisk = rows.where((r) {
      final p = r['priority'] as String? ?? '';
      final s = r['status']   as String? ?? '';
      return (p == 'high' || p == 'critical') && (s == 'pending' || s == 'inprogress');
    }).length;

    // 5. Department resolution rates (sorted lowest first = most at risk)
    final dTotal = <String, int>{};
    final dRes   = <String, int>{};
    for (final r in rows) {
      final dept = (r['departments'] as Map?)?['name'] as String? ?? 'Unknown';
      final s    = r['status'] as String? ?? '';
      dTotal[dept] = (dTotal[dept] ?? 0) + 1;
      if (s == 'resolved' || s == 'closed') dRes[dept] = (dRes[dept] ?? 0) + 1;
    }
    _deptRates = dTotal.entries.map((e) {
      final tot = e.value, res = dRes[e.key] ?? 0;
      return {'dept': e.key, 'total': tot, 'resolved': res, 'rate': tot > 0 ? (res / tot * 100).round() : 0};
    }).toList()
      ..sort((a, b) => (a['rate'] as int).compareTo(b['rate'] as int));

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(20),
        child: Text(_error!, style: const TextStyle(color: Colors.red))));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        // Summary chip
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFf16936).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.analytics_rounded, color: Color(0xFFf16936), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isAr ? 'تحليل $_total تذكرة محلياً — بدون ذكاء اصطناعي خارجي'
                   : 'Analyzed $_total tickets locally — no external AI used',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFf16936)),
            )),
          ]),
        ),

        // Priority alert (shown first — most critical)
        if (_priorityRisk > 0)
          _insightCard(icon: Icons.warning_amber_rounded, color: Colors.red,
            title: isAr ? '⚠️ تنبيه أولوية عالية' : '⚠️ Priority Alert',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr
                  ? '$_priorityRisk تذكرة بأولوية (عالية / حرجة) لا تزال مفتوحة'
                  : '$_priorityRisk ticket(s) with HIGH or CRITICAL priority are still pending or in-progress',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: Text(isAr ? '$_priorityRisk تذكرة في خطر' : '$_priorityRisk ticket(s) at risk',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ]),
          ),

        // Top keywords (word cloud style)
        if (_topKeywords.isNotEmpty)
          _insightCard(icon: Icons.label_important_outline_rounded, color: Colors.indigo,
            title: isAr ? '🔑 أكثر الكلمات تكراراً في التذاكر' : '🔑 Top Keywords in Tickets',
            child: Wrap(spacing: 8, runSpacing: 6, children: _topKeywords.map((e) {
              final ratio   = e.value / (_topKeywords.first.value);
              final opacity = 0.35 + ratio * 0.65;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: opacity), borderRadius: BorderRadius.circular(20)),
                child: Text('${e.key}  ×${e.value}',
                    style: TextStyle(color: opacity > 0.65 ? Colors.white : Colors.indigo[800],
                        fontSize: 12, fontWeight: FontWeight.w600)),
              );
            }).toList()),
          ),

        // Stuck tickets
        if (_stuckTickets.isNotEmpty)
          _insightCard(icon: Icons.hourglass_empty_rounded, color: Colors.orange,
            title: isAr ? '⏳ تذاكر متوقفة (أكثر من 5 أيام بلا تحديث)' : '⏳ Stuck Tickets (5+ days without update)',
            child: Column(children: _stuckTickets.take(7).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (t['days'] as int) >= 10 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('${t['days']}d',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['title'] as String, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(t['dept'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(t['status'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                ),
              ]),
            )).toList()),
          ),

        // Recurring issues
        if (_repeatedTitles.isNotEmpty)
          _insightCard(icon: Icons.repeat_rounded, color: Colors.teal,
            title: isAr ? '🔁 مشاكل متكررة (نفس العنوان يتكرر)' : '🔁 Recurring Issues (same title repeated)',
            child: Column(children: _repeatedTitles.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 30, height: 30, alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                  child: Text('${e.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )).toList()),
          ),

        // Department resolution rates
        if (_deptRates.isNotEmpty)
          _insightCard(icon: Icons.bar_chart_rounded, color: Colors.blue,
            title: isAr ? '📊 نسبة حل التذاكر بالأقسام' : '📊 Resolution Rate by Department',
            child: Column(children: _deptRates.map((d) {
              final rate = d['rate'] as int;
              final col  = rate >= 70 ? Colors.green : rate >= 40 ? Colors.orange : Colors.red;
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(d['dept'] as String,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    Text('$rate%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col)),
                    const SizedBox(width: 6),
                    Text('(${d['resolved']}/${d['total']})', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: rate / 100,
                        backgroundColor: Colors.grey.shade200, color: col, minHeight: 6)),
                ]),
              );
            }).toList()),
          ),

        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _insightCard({required IconData icon, required Color color, required String title, required Widget child}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              Icon(icon, color: color, size: 18), const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
      );
}

// ─── saved dashboards tab ─────────────────────────────────────────────────────
class _SavedDashboardsTab extends StatefulWidget {
  final UserModel currentUser;
  const _SavedDashboardsTab({required this.currentUser});

  @override
  State<_SavedDashboardsTab> createState() => _SavedDashboardsTabState();
}

class _SavedDashboardsTabState extends State<_SavedDashboardsTab> {
  List<Map<String, dynamic>> _dashboards = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('saved_dashboards')
          .select('id,title,prompt,result,created_by,privacy,department_id,created_at')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _dashboards = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    final l10n = AppLocalizations.safeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(l10n.deleteDashboard),
        content: Text(l10n.confirmDeleteDashboard),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) { await supabase.from('saved_dashboards').delete().eq('id', id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_dashboards.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bookmarks_outlined, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(l10n.noSavedDashboards, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]));
    }
    final mine   = _dashboards.where((d) => d['created_by'] == widget.currentUser.id).toList();
    final shared = _dashboards.where((d) => d['created_by'] != widget.currentUser.id).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (mine.isNotEmpty) ...[
          _header(l10n.myDashboards, Icons.person_rounded),
          const SizedBox(height: 8),
          ...mine.map((d) => _DashboardCard(
            dashboard: d,
            allDashboards: _dashboards,
            selfIndex: _dashboards.indexOf(d),
            isOwner: true,
            onDelete: () => _delete(d['id'] as String),
          )),
          const SizedBox(height: 16),
        ],
        if (shared.isNotEmpty) ...[
          _header(l10n.sharedDashboards, Icons.group_rounded),
          const SizedBox(height: 8),
          ...shared.map((d) => _DashboardCard(
            dashboard: d,
            allDashboards: _dashboards,
            selfIndex: _dashboards.indexOf(d),
            isOwner: false,
            onDelete: null,
          )),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _header(String title, IconData icon) => Row(children: [
        Icon(icon, size: 16, color: const Color(0xFFf16936)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]);
}

// ─── custom dashboards tab ────────────────────────────────────────────────────
class _CustomDashboardsTab extends StatefulWidget {
  final UserModel currentUser;
  const _CustomDashboardsTab({required this.currentUser});
  @override
  State<_CustomDashboardsTab> createState() => _CustomDashboardsTabState();
}

class _CustomDashboardsTabState extends State<_CustomDashboardsTab> {
  List<Map<String, dynamic>> _dashboards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('custom_dashboards')
          .select('id,title,updated_at')
          .eq('user_id', widget.currentUser.id)
          .order('updated_at', ascending: false);
      if (mounted) setState(() { _dashboards = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(isAr ? 'حذف اللوحة' : 'Delete Dashboard'),
        content: Text(isAr ? 'هل أنت متأكد من الحذف؟' : 'Are you sure you want to delete this dashboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) { await supabase.from('custom_dashboards').delete().eq('id', id); _load(); }
  }

  void _openEditor({String? dashboardId}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CustomDashboardScreen(
        currentUser: widget.currentUser,
        dashboardId: dashboardId,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        // ── Create new button ──────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(isAr ? 'إنشاء لوحة مخصصة جديدة' : 'Create New Custom Dashboard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFf16936),
            side: const BorderSide(color: Color(0xFFf16936)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),
        if (_dashboards.isEmpty)
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 32),
            Icon(Icons.dashboard_customize_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isAr ? 'لا توجد لوحات مخصصة بعد' : 'No custom dashboards yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ]))
        else
          ..._dashboards.map((d) {
            final id      = d['id']    as String;
            final title   = d['title'] as String? ?? '';
            final updated = DateTime.tryParse(d['updated_at'] as String? ?? '') ?? DateTime.now();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0, color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openEditor(dashboardId: id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFf16936).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFFf16936), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '${isAr ? "آخر تعديل" : "Last edited"}: ${updated.day}/${updated.month}/${updated.year}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                      onPressed: () => _delete(id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),
              ),
            );
          }),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ─── dashboard card ───────────────────────────────────────────────────────────
class _DashboardCard extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> allDashboards;
  final int selfIndex;
  final bool isOwner;
  final VoidCallback? onDelete;
  const _DashboardCard({
    required this.dashboard,
    required this.allDashboards,
    required this.selfIndex,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.safeOf(context);
    final title   = dashboard['title']   as String? ?? '';
    final privacy = dashboard['privacy'] as String? ?? 'private';
    final prompt  = dashboard['prompt']  as String? ?? '';
    final created = DateTime.tryParse(dashboard['created_at'] as String? ?? '') ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0, color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (dashboard['result'] == null) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => _FullDashboardPage(
              dashboards: allDashboards,
              initialIndex: selfIndex,
              l10n: AppLocalizations.safeOf(context),
            ),
          ));
        },
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.dashboard_rounded, size: 16, color: Color(0xFFf16936)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: privacy == 'public' ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(privacy == 'public' ? Icons.public : Icons.lock_outline, size: 11,
                    color: privacy == 'public' ? Colors.green : Colors.grey),
                const SizedBox(width: 4),
                Text(privacy == 'public' ? l10n.privacyPublic : l10n.privacyPrivate,
                    style: TextStyle(fontSize: 10, color: privacy == 'public' ? Colors.green : Colors.grey[600])),
              ]),
            ),
            if (isOwner && onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ],
          ]),
          if (prompt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(prompt, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Text('${created.day}/${created.month}/${created.year}',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ])),
      ),
    );
  }
}

// ─── full dashboard page ──────────────────────────────────────────────────────
class _FullDashboardPage extends StatefulWidget {
  final List<Map<String, dynamic>> dashboards;
  final int initialIndex;
  final AppLocalizations l10n;
  const _FullDashboardPage({
    required this.dashboards,
    required this.initialIndex,
    required this.l10n,
  });

  @override
  State<_FullDashboardPage> createState() => _FullDashboardPageState();
}

class _FullDashboardPageState extends State<_FullDashboardPage> {
  late int _idx;
  bool _panelOpen = true;
  bool _saving    = false;
  GlobalKey<_InteractiveDashboardState> _dashKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
  }

  Map<String, dynamic> get _db => widget.dashboards[_idx];
  String get _title => _db['title'] as String? ?? '';
  Map<String, dynamic>? get _data {
    final r = _db['result'];
    if (r == null) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  void _switchTo(int i) => setState(() {
    _idx = i;
    _dashKey = GlobalKey(); // force _InteractiveDashboard to rebuild fresh
  });

  Future<void> _saveLayout() async {
    final id = _db['id'] as String?;
    if (id == null) return;
    final updated = _dashKey.currentState?.toJson() ?? _data;
    if (updated == null) return;
    setState(() => _saving = true);
    try {
      await supabase.from('saved_dashboards').update({'result': updated}).eq('id', id);
      widget.dashboards[_idx]['result'] = updated; // update local copy
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'ar'
              ? 'تم حفظ التخطيط' : 'Layout saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, foregroundColor: Colors.black87,
        elevation: 0, shadowColor: Colors.grey.withValues(alpha: 0.1),
        actions: [
          // Save layout button
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: isAr ? 'حفظ التخطيط' : 'Save layout',
              icon: const Icon(Icons.save_rounded, color: Color(0xFFf16936)),
              onPressed: _saveLayout,
            ),
          IconButton(
            tooltip: _panelOpen
                ? (isAr ? 'إخفاء القائمة' : 'Hide list')
                : (isAr ? 'إظهار القائمة' : 'Show list'),
            icon: Icon(_panelOpen ? Icons.chevron_right : Icons.view_sidebar_outlined),
            onPressed: () => setState(() => _panelOpen = !_panelOpen),
          ),
        ],
      ),
      body: Row(
        children: [
          // Main dashboard content
          Expanded(
            child: data == null
                ? const Center(child: Text('No data'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _InteractiveDashboard(
                      key: _dashKey,
                      data: data,
                      l10n: widget.l10n,
                    ),
                  ),
          ),
          // Collapsible side panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: _panelOpen ? 210 : 0,
            child: _panelOpen ? _buildPanel(isAr) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(bool isAr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(children: [
        // Panel header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            const Icon(Icons.bookmarks_rounded, size: 14, color: Color(0xFFf16936)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isAr ? 'اللوحات المحفوظة' : 'Saved Dashboards',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFf16936)),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _panelOpen = false),
              child: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ),
          ]),
        ),
        // Dashboard list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.dashboards.length,
            itemBuilder: (ctx, i) {
              final d        = widget.dashboards[i];
              final title    = d['title']   as String? ?? '';
              final privacy  = d['privacy'] as String? ?? 'private';
              final prompt   = d['prompt']  as String? ?? '';
              final selected = i == _idx;
              return InkWell(
                onTap: () => _switchTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFf16936).withValues(alpha: 0.07) : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected ? const Color(0xFFf16936) : Colors.transparent,
                        width: 3,
                      ),
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.dashboard_rounded, size: 14,
                        color: selected ? const Color(0xFFf16936) : Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            color: selected ? const Color(0xFFf16936) : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (prompt.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(prompt,
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(
                            privacy == 'public' ? Icons.public : Icons.lock_outline,
                            size: 9,
                            color: privacy == 'public' ? Colors.green : Colors.grey[400],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            privacy == 'public'
                                ? (isAr ? 'عام' : 'Public')
                                : (isAr ? 'خاص' : 'Private'),
                            style: TextStyle(
                              fontSize: 9,
                              color: privacy == 'public' ? Colors.green : Colors.grey[400],
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── custom dashboard screen ──────────────────────────────────────────────────
// Lets a super-admin build a dashboard from scratch with live Supabase data.

enum _CAggFn { count, sum, avg }
enum _CGroupBy { status, priority, department, place, month }

// ─── expression / column def constants ───────────────────────────────────────
const _kTableFields = {
  'id': 'ID', 'status': 'Status', 'priority': 'Priority',
  'department': 'Department', 'place': 'Place',
  'created_at': 'Created At', 'assigned_to': 'Assigned To',
  'full_name': 'Full Name', 'email': 'Email', 'role': 'Role',
  'name': 'Name',
};
const _kCondFields = ['status', 'priority', 'department', 'place', 'created_at'];
const _kCondOps = {'eq': '=', 'neq': '≠', 'contains': '∋', 'in': 'in', 'gt': '>', 'lt': '<'};

class _RowCondition {
  String field;
  String op;
  String value;
  _RowCondition({required this.field, required this.op, required this.value});
  Map<String, dynamic> toJson() => {'field': field, 'op': op, 'value': value};
  factory _RowCondition.fromJson(Map j) => _RowCondition(
    field: j['field'] as String? ?? 'status',
    op: j['op'] as String? ?? 'eq',
    value: j['value'] as String? ?? '',
  );
}

class _ColumnDef {
  String field;
  String label;
  String? labelAr;
  _ColumnDef({required this.field, required this.label, this.labelAr});
  Map<String, dynamic> toJson() => {
    'field': field, 'label': label,
    if (labelAr != null && labelAr!.isNotEmpty) 'labelAr': labelAr,
  };
  factory _ColumnDef.fromJson(Map j) => _ColumnDef(
    field: j['field'] as String? ?? 'status',
    label: j['label'] as String? ?? (j['field'] as String? ?? 'status'),
    labelAr: j['labelAr'] as String?,
  );
}

class _CDataSource {
  _CAggFn aggFn;
  String? aggField;
  _CGroupBy? groupBy;
  int daysBack;
  Set<String> statusFilter;
  Set<String> priorityFilter;
  String format; // 'number' | 'percent' | 'duration'
  String tableSource; // 'tickets' | 'users' | 'places' | 'departments'
  List<_RowCondition> conditions;
  List<_ColumnDef> tableColumns;

  _CDataSource({
    this.aggFn = _CAggFn.count,
    this.aggField,
    this.groupBy,
    this.daysBack = 30,
    Set<String>? statusFilter,
    Set<String>? priorityFilter,
    this.format = 'number',
    this.tableSource = 'tickets',
    List<_RowCondition>? conditions,
    List<_ColumnDef>? tableColumns,
  })  : statusFilter   = statusFilter  ?? {'pending','inprogress','prefinished','closed','resolved'},
        priorityFilter = priorityFilter ?? {'low','medium','high','critical','urgent'},
        conditions     = conditions  ?? [],
        tableColumns   = tableColumns ?? [];

  Map<String, dynamic> toJson() => {
    'aggFn': aggFn.name, 'aggField': aggField, 'groupBy': groupBy?.name,
    'daysBack': daysBack,
    'statusFilter':  statusFilter.toList(),
    'priorityFilter': priorityFilter.toList(),
    'format': format,
    'tableSource': tableSource,
    'conditions':   conditions.map((c) => c.toJson()).toList(),
    'tableColumns': tableColumns.map((c) => c.toJson()).toList(),
  };

  factory _CDataSource.fromJson(Map<String, dynamic> j) => _CDataSource(
    aggFn: _CAggFn.values.firstWhere((e) => e.name == j['aggFn'], orElse: () => _CAggFn.count),
    aggField: j['aggField'] as String?,
    groupBy: j['groupBy'] != null
        ? _CGroupBy.values.firstWhere((e) => e.name == j['groupBy'], orElse: () => _CGroupBy.status)
        : null,
    daysBack: (j['daysBack'] as int?) ?? 30,
    statusFilter:  Set<String>.from((j['statusFilter'] as List?) ?? []),
    priorityFilter: Set<String>.from((j['priorityFilter'] as List?) ?? []),
    format: j['format'] as String? ?? 'number',
    tableSource: j['tableSource'] as String? ?? 'tickets',
    conditions:   ((j['conditions'] as List?) ?? [])
        .map((c) => _RowCondition.fromJson(c as Map)).toList(),
    tableColumns: ((j['tableColumns'] as List?) ?? [])
        .map((c) => _ColumnDef.fromJson(c as Map)).toList(),
  );
}

class _CComponent {
  String id;
  String type; // 'kpi' | 'chart' | 'table'
  String title;
  String? titleAr; // Arabic translation of title
  String chartType;
  int colSpan;
  int heightLevel;
  int colorTheme;
  int styleVariant;   // 0-4 visual design variant
  int? accentColor;   // override palette color (Color.value int)
  int? fontColor;     // override font color
  double valueFontSize;
  double titleFontSize;
  _CDataSource datasource;
  dynamic _cachedData;
  bool _loading = false;

  _CComponent({
    required this.id,
    required this.type,
    required this.title,
    this.titleAr,
    this.chartType = 'bar',
    this.colSpan = 16,
    this.heightLevel = 2,
    this.colorTheme = 0,
    this.styleVariant = 0,
    this.accentColor,
    this.fontColor,
    this.valueFontSize = 26.0,
    this.titleFontSize = 11.0,
    _CDataSource? datasource,
  }) : datasource = datasource ?? _CDataSource();

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'title': title,
    if (titleAr != null && titleAr!.isNotEmpty) 'titleAr': titleAr,
    'chartType': chartType, 'colSpan': colSpan,
    'heightLevel': heightLevel, 'colorTheme': colorTheme,
    'styleVariant': styleVariant,
    if (accentColor != null) 'accentColor': accentColor,
    if (fontColor != null) 'fontColor': fontColor,
    'valueFontSize': valueFontSize,
    'titleFontSize': titleFontSize,
    'datasource': datasource.toJson(),
  };

  factory _CComponent.fromJson(Map<String, dynamic> j) => _CComponent(
    id: j['id'] as String? ?? UniqueKey().toString(),
    type: j['type'] as String? ?? 'kpi',
    title: j['title'] as String? ?? '',
    titleAr: j['titleAr'] as String?,
    chartType: j['chartType'] as String? ?? 'bar',
    colSpan: (j['colSpan'] as int?) ?? 4,
    heightLevel: ((j['heightLevel'] as int?) ?? _kMinHeight).clamp(_kMinHeight, 5),
    colorTheme: (j['colorTheme'] as int?) ?? 0,
    styleVariant: (j['styleVariant'] as int?) ?? 0,
    accentColor: j['accentColor'] as int?,
    fontColor: j['fontColor'] as int?,
    valueFontSize: (j['valueFontSize'] as num?)?.toDouble() ?? 26.0,
    titleFontSize: (j['titleFontSize'] as num?)?.toDouble() ?? 11.0,
    datasource: j['datasource'] != null
        ? _CDataSource.fromJson(Map<String, dynamic>.from(j['datasource'] as Map))
        : _CDataSource(),
  );
}

class CustomDashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  final String? dashboardId;
  final bool readOnly;
  const CustomDashboardScreen({super.key, required this.currentUser, this.dashboardId, this.readOnly = false});

  @override
  State<CustomDashboardScreen> createState() => _CustomDashboardScreenState();
}

class _CustomDashboardScreenState extends State<CustomDashboardScreen> {
  final _titleCtrl = TextEditingController(text: 'My Dashboard');
  List<_CComponent> _components = [];
  bool _loading = false;
  bool _saving  = false;
  String? _savedId;

  // Resize state (mirrors _InteractiveDashboard)
  final _dragAccum   = <String, double>{};
  final _dragAccumH  = <String, double>{};
  final _resizingIds = <String>{};

  List<List<_CComponent>> _groupCompsIntoRows(
      List<_CComponent> comps, int gridCols, int Function(_CComponent) eff) {
    final rows = <List<_CComponent>>[];
    var row = <_CComponent>[];
    var span = 0;
    for (final comp in comps) {
      final cs = eff(comp);
      if (span + cs > gridCols && row.isNotEmpty) {
        rows.add(row); row = []; span = 0;
      }
      row.add(comp);
      span += cs;
      if (span >= gridCols) {
        rows.add(row); row = []; span = 0;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  @override
  void initState() {
    super.initState();
    if (widget.dashboardId != null) _loadExisting();
  }

  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final row = await supabase
          .from('custom_dashboards')
          .select('title,components')
          .eq('id', widget.dashboardId!)
          .maybeSingle();
      if (row != null && mounted) {
        _titleCtrl.text = row['title'] as String? ?? '';
        final comps = (row['components'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _components = comps.map((c) => _CComponent.fromJson(c)).toList();
          _savedId = widget.dashboardId;
        });
        for (final c in _components) _fetchData(c);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchData(_CComponent comp) async {
    setState(() => comp._loading = true);
    try {
      final ds    = comp.datasource;
      final since = DateTime.now().subtract(Duration(days: ds.daysBack)).toIso8601String();
      List<Map> rows;
      switch (ds.tableSource) {
        case 'users':
          rows = List.from(await supabase
              .from('users')
              .select('id,full_name,email,role,created_at,departments(name),places(name)')
              .limit(500));
        case 'places':
          rows = List.from(await supabase
              .from('places')
              .select('id,name,created_at')
              .limit(500));
        case 'departments':
          rows = List.from(await supabase
              .from('departments')
              .select('id,name,created_at')
              .limit(500));
        default: // 'tickets'
          var q = supabase.from('tickets').select(
              'id,status,priority,assigned_to,created_at,'
              'departments:target_department_id(name),places(name)');
          if (widget.currentUser.departmentId != null) {
            q = q.eq('target_department_id', widget.currentUser.departmentId!);
          }
          q = q.gte('created_at', since);
          if (ds.statusFilter.length < 5) q = q.inFilter('status', ds.statusFilter.toList());
          if (ds.priorityFilter.length < 5) q = q.inFilter('priority', ds.priorityFilter.toList());
          rows = List.from(await q.limit(500));
      }

      // Apply row conditions (client-side expressions)
      for (final cond in ds.conditions) {
        if (cond.value.trim().isEmpty) continue;
        final v = cond.value.trim().toLowerCase();
        rows = rows.where((r) {
          final rv = _rawFieldValue(r, cond.field).toLowerCase();
          switch (cond.op) {
            case 'eq':       return rv == v;
            case 'neq':      return rv != v;
            case 'contains': return rv.contains(v);
            case 'in':       return v.split(',').map((s) => s.trim()).contains(rv);
            case 'gt':       return (double.tryParse(rv) ?? 0) > (double.tryParse(v) ?? 0);
            case 'lt':       return (double.tryParse(rv) ?? 0) < (double.tryParse(v) ?? 0);
            default:         return true;
          }
        }).toList();
      }

      // Table with explicit column defs → return raw rows
      if (comp.type == 'table' && ds.tableColumns.isNotEmpty) {
        final tableRows = rows
            .map((r) => ds.tableColumns.map((col) => _cellValue(r, col.field)).toList())
            .toList();
        if (mounted) setState(() { comp._cachedData = tableRows; comp._loading = false; });
        return;
      }

      if (comp.type == 'kpi') {
        num value = 0;
        if (ds.aggFn == _CAggFn.count) {
          value = rows.length;
        } else if (ds.aggField != null) {
          value = rows.fold<num>(0, (s, r) => s + ((r[ds.aggField!] as num?) ?? 0));
          if (ds.aggFn == _CAggFn.avg && rows.isNotEmpty) value = value / rows.length;
        }
        String formatted;
        if (ds.format == 'percent') {
          final total = rows.isNotEmpty ? rows.length : 1;
          formatted = '${(value / total * 100).toStringAsFixed(1)}%';
        } else if (ds.format == 'duration') {
          formatted = '${value.toStringAsFixed(1)}h';
        } else {
          formatted = value.toInt().toString();
        }
        if (mounted) setState(() { comp._cachedData = formatted; comp._loading = false; });
      } else {
        // Grouped data for charts / tables
        final grouped = <String, num>{};
        for (final r in rows) {
          final key = _groupKey(r, ds.groupBy);
          num val = 1;
          if (ds.aggFn != _CAggFn.count && ds.aggField != null) {
            val = (r[ds.aggField!] as num?) ?? 0;
          }
          grouped[key] = (grouped[key] ?? 0) + val;
        }
        if (mounted) setState(() { comp._cachedData = grouped; comp._loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { comp._loading = false; });
    }
  }

  String _groupKey(Map r, _CGroupBy? gb) {
    switch (gb) {
      case _CGroupBy.status:     return r['status'] as String? ?? 'unknown';
      case _CGroupBy.priority:   return r['priority'] as String? ?? 'unknown';
      case _CGroupBy.department: return (r['departments'] as Map?)?['name'] as String? ?? 'Unknown';
      case _CGroupBy.place:      return (r['places'] as Map?)?['name'] as String? ?? 'Unknown';
      case _CGroupBy.month:
        final d = r['created_at'] as String? ?? '';
        return d.length >= 7 ? d.substring(0, 7) : d;
      default:                   return 'unknown';
    }
  }

  String _rawFieldValue(Map r, String field) {
    if (field == 'department') return (r['departments'] as Map?)?['name'] as String? ?? '';
    if (field == 'place')      return (r['places'] as Map?)?['name'] as String? ?? '';
    return r[field]?.toString() ?? '';
  }

  String _cellValue(Map r, String field) {
    if (field == 'department') return (r['departments'] as Map?)?['name'] as String? ?? '-';
    if (field == 'place')      return (r['places'] as Map?)?['name'] as String? ?? '-';
    if (field == 'created_at') {
      final s = r['created_at'] as String? ?? '';
      return s.length >= 10 ? s.substring(0, 10) : s;
    }
    return r[field]?.toString() ?? '-';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'user_id': widget.currentUser.id,
        'title': _titleCtrl.text.trim().isEmpty ? 'My Dashboard' : _titleCtrl.text.trim(),
        'components': _components.map((c) => c.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_savedId != null) {
        await supabase.from('custom_dashboards').update(payload).eq('id', _savedId!);
      } else {
        final res = await supabase.from('custom_dashboards').insert(payload).select('id').single();
        _savedId = res['id'] as String;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dashboard saved'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pop(context, _savedId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _addComponent() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddComponentSheet(
        onAdd: (comp) {
          setState(() => _components.add(comp));
          _fetchData(comp);
        },
      ),
    );
  }

  void _openComponentConfig(_CComponent comp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (__, ctrl) => _ComponentConfigSheet(
          comp: comp,
          onChanged: () {
            setState(() {});
            _fetchData(comp);
          },
          scrollController: ctrl,
        ),
      ),
    );
  }

  Widget _buildBody(bool isAr) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_components.isEmpty && !widget.readOnly) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(isAr ? 'ابدأ بإضافة مكوّن' : 'Add your first component',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _addComponent,
          icon: const Icon(Icons.add),
          label: Text(isAr ? 'إضافة مكوّن' : 'Add Component'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf16936),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]));
    }
    return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final isMobile = constraints.maxWidth < 560;
                    final gridCols = isMobile ? 8 : 32;

                    int effSpan(_CComponent comp) {
                      if (isMobile) {
                        return comp.type == 'kpi'
                            ? comp.colSpan.clamp(4, gridCols)
                            : gridCols;
                      }
                      return comp.colSpan.clamp(8, gridCols);
                    }

                    final rows = _groupCompsIntoRows(_components, gridCols, effSpan);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows.map((rowComps) {
                        final usedSpan = rowComps.fold<int>(0, (s, c) => s + effSpan(c));
                        final remSpan  = gridCols - usedSpan;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...rowComps.asMap().entries.map((e) {
                                final comp = e.value;
                                return Expanded(
                                  flex: effSpan(comp),
                                  child: Padding(
                                    padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
                                    child: _buildResizableCompCard(
                                        comp, constraints.maxWidth, gridCols, isMobile),
                                  ),
                                );
                              }),
                              if (remSpan > 0) Expanded(flex: remSpan, child: const SizedBox()),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (widget.readOnly) return _buildBody(isAr);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF135467),
        elevation: 1,
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(isAr ? 'حفظ' : 'Save'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFf16936)),
            ),
        ],
      ),
      body: _buildBody(isAr),
      floatingActionButton: _components.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addComponent,
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'إضافة' : 'Add'),
              backgroundColor: const Color(0xFFf16936),
              foregroundColor: Colors.white,
            ),
    );
  }

  // ── Resizable card with 4-sided handles + drag-to-reorder ──────────────────
  Widget _buildResizableCompCard(
      _CComponent comp, double totalWidth, int gridCols, bool isMobile) {
    final isResizingW = _resizingIds.contains('w_${comp.id}');
    final isResizingH = _resizingIds.contains('h_${comp.id}');
    final isResizing  = isResizingW || isResizingH;
    final minSpan  = isMobile ? (comp.type == 'kpi' ? 4 : gridCols) : 8;
    final canResizeW = !isMobile || comp.type == 'kpi';
    // Mobile KPI height is fixed by row count — height handles hidden
    final isMobileKpiComp = isMobile && comp.type == 'kpi';
    const minHLvl = _kMinHeight;
    final unitPx = totalWidth / gridCols;
    const kHUnit = 40.0;

    void wStart() => setState(() => _resizingIds.add('w_${comp.id}'));
    void wEnd()   => setState(() { _resizingIds.remove('w_${comp.id}'); _dragAccum[comp.id]  = 0; });
    void hStart() => setState(() => _resizingIds.add('h_${comp.id}'));
    void hEnd()   => setState(() { _resizingIds.remove('h_${comp.id}'); _dragAccumH[comp.id] = 0; });

    Widget handle({
      double? left, double? right, double? top, double? bottom,
      double? width, double? height,
      required MouseCursor cursor,
      required void Function() onStart,
      required void Function(DragUpdateDetails) onUpdate,
      required void Function() onEnd,
      required bool active,
      bool vertical = false,
    }) {
      return Positioned(
        left: left, right: right, top: top, bottom: bottom,
        width: width, height: height,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onStart(),
            onPanUpdate: onUpdate,
            onPanEnd: (_) => onEnd(),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width:  vertical ? (active ? 40 : 28) : (active ? 5 : 4),
                height: vertical ? (active ? 5 : 4)   : (active ? 40 : 28),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFf16936)
                      : Colors.grey.shade400.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.readOnly) return _buildCompCard(comp);

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: isResizing
              ? BoxDecoration(
                  border: Border.all(color: const Color(0xFFf16936), width: 2),
                  borderRadius: BorderRadius.circular(16))
              : null,
          child: _buildCompCard(comp),
        ),
        if (canResizeW) handle(
          right: 0, top: 0, bottom: 0, width: 18,
          cursor: SystemMouseCursors.resizeLeftRight,
          onStart: wStart, onEnd: wEnd, active: isResizingW,
          onUpdate: (d) {
            _dragAccum[comp.id] = (_dragAccum[comp.id] ?? 0) + d.delta.dx;
            if (_dragAccum[comp.id]! > unitPx && comp.colSpan < gridCols) {
              setState(() { comp.colSpan = (comp.colSpan + 1).clamp(minSpan, gridCols); _dragAccum[comp.id] = 0; });
            } else if (_dragAccum[comp.id]! < -unitPx && comp.colSpan > minSpan) {
              setState(() { comp.colSpan = (comp.colSpan - 1).clamp(minSpan, gridCols); _dragAccum[comp.id] = 0; });
            }
          },
        ),
        if (canResizeW) handle(
          left: 0, top: 0, bottom: 0, width: 18,
          cursor: SystemMouseCursors.resizeLeftRight,
          onStart: wStart, onEnd: wEnd, active: isResizingW,
          onUpdate: (d) {
            _dragAccum[comp.id] = (_dragAccum[comp.id] ?? 0) - d.delta.dx;
            if (_dragAccum[comp.id]! > unitPx && comp.colSpan < gridCols) {
              setState(() { comp.colSpan = (comp.colSpan + 1).clamp(minSpan, gridCols); _dragAccum[comp.id] = 0; });
            } else if (_dragAccum[comp.id]! < -unitPx && comp.colSpan > minSpan) {
              setState(() { comp.colSpan = (comp.colSpan - 1).clamp(minSpan, gridCols); _dragAccum[comp.id] = 0; });
            }
          },
        ),
        // Height handles — hidden on mobile KPI (height is fixed by row count)
        if (!isMobileKpiComp) handle(
          left: 0, right: 0, bottom: 0, height: 18,
          cursor: SystemMouseCursors.resizeUpDown,
          onStart: hStart, onEnd: hEnd, active: isResizingH, vertical: true,
          onUpdate: (d) {
            _dragAccumH[comp.id] = (_dragAccumH[comp.id] ?? 0) + d.delta.dy;
            if (_dragAccumH[comp.id]! > kHUnit && comp.heightLevel < 5) {
              setState(() { comp.heightLevel++; _dragAccumH[comp.id] = 0; });
            } else if (_dragAccumH[comp.id]! < -kHUnit && comp.heightLevel > minHLvl) {
              setState(() { comp.heightLevel--; _dragAccumH[comp.id] = 0; });
            }
          },
        ),
        if (!isMobileKpiComp) handle(
          left: 0, right: 0, top: 0, height: 18,
          cursor: SystemMouseCursors.resizeUpDown,
          onStart: hStart, onEnd: hEnd, active: isResizingH, vertical: true,
          onUpdate: (d) {
            _dragAccumH[comp.id] = (_dragAccumH[comp.id] ?? 0) - d.delta.dy;
            if (_dragAccumH[comp.id]! > kHUnit && comp.heightLevel < 5) {
              setState(() { comp.heightLevel++; _dragAccumH[comp.id] = 0; });
            } else if (_dragAccumH[comp.id]! < -kHUnit && comp.heightLevel > minHLvl) {
              setState(() { comp.heightLevel--; _dragAccumH[comp.id] = 0; });
            }
          },
        ),
      ],
    );
  }

  Widget _buildCompCard(_CComponent comp) {
    const kHdrH = 52.0;
    final isMobile = MediaQuery.of(context).size.width < 560;
    final contentH = (isMobile && comp.type == 'kpi')
        ? _kpiRowHeights[1]
        : _heights[comp.heightLevel.clamp(0, 5)];
    final cardH = kHdrH + contentH;

    Widget cardContent(bool over) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: cardH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: over ? Border.all(color: const Color(0xFFf16936), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            if (!widget.readOnly) ...[
              Draggable<String>(
                data: comp.id,
                feedback: Material(
                  elevation: 6, borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 200, height: 52, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(comp.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
                childWhenDragging: const Icon(Icons.drag_indicator_rounded,
                    color: Color(0xFFf16936), size: 20),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator_rounded,
                        color: Colors.grey.shade400, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(_compIcon(comp.type), size: 15,
                color: _color(_themes[comp.colorTheme])),
            const SizedBox(width: 6),
            Expanded(child: Text(comp.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
            if (!widget.readOnly) ...[
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 18),
                padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                color: Colors.grey, onPressed: () => _openComponentConfig(comp),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                onPressed: () => setState(() => _components.remove(comp)),
              ),
            ],
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: _buildCompContent(comp),
          ),
        ),
      ]),
    );

    if (widget.readOnly) return cardContent(false);

    return DragTarget<String>(
      key: ValueKey('tgt_${comp.id}'),
      onWillAcceptWithDetails: (d) => d.data != comp.id,
      onAcceptWithDetails: (d) {
        setState(() {
          final from = _components.indexWhere((c) => c.id == d.data);
          final to   = _components.indexOf(comp);
          if (from < 0 || to < 0 || from == to) return;
          final moved = _components.removeAt(from);
          _components.insert(to, moved);
        });
      },
      builder: (ctx, candidates, _) => cardContent(candidates.isNotEmpty),
    );
  }

  IconData _compIcon(String type) {
    switch (type) {
      case 'chart': return Icons.bar_chart;
      case 'table': return Icons.table_chart_outlined;
      default:      return Icons.assessment_outlined;
    }
  }

  Widget _buildCompContent(_CComponent comp) {
    final isAr       = Localizations.localeOf(context).languageCode == 'ar';
    final compTitle  = (isAr && (comp.titleAr?.isNotEmpty ?? false)) ? comp.titleAr! : comp.title;
    if (comp._loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (comp._cachedData == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: TextButton.icon(
          onPressed: () => _fetchData(comp),
          icon: const Icon(Icons.refresh),
          label: const Text('Load data'),
        )),
      );
    }

    if (comp.type == 'kpi') {
      final val = comp._cachedData.toString();
      final col = comp.accentColor != null
          ? Color(comp.accentColor!)
          : _color(_themes[comp.colorTheme]);
      final fgCol = comp.fontColor != null ? Color(comp.fontColor!) : null;
      final vSize = comp.valueFontSize;
      final tSize = comp.titleFontSize;
      final sub = 'Last ${comp.datasource.daysBack}d';
      switch (comp.styleVariant) {
        case 1: // Gradient card
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [col, col.withValues(alpha: 0.65)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(compTitle, style: TextStyle(fontSize: tSize, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              Text(val, style: TextStyle(fontSize: vSize, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(sub, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.65))),
            ]),
          );
        case 2: // Outlined/framed
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col, width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(compTitle, style: TextStyle(fontSize: tSize, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(val, style: TextStyle(fontSize: vSize, fontWeight: FontWeight.bold, color: fgCol ?? col)),
              Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ]),
          );
        case 3: // Minimal centered
          return Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(val, style: TextStyle(fontSize: vSize + 4, fontWeight: FontWeight.bold, color: fgCol ?? col)),
            const SizedBox(height: 4),
            Text(compTitle, style: TextStyle(fontSize: tSize, color: Colors.grey[500])),
          ]);
        case 4: // Bold top-bar filled
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: col, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
              child: Text(compTitle, style: TextStyle(fontSize: tSize, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(val, style: TextStyle(fontSize: vSize, fontWeight: FontWeight.bold, color: fgCol ?? col)),
                Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
            )),
          ]);
        default: // 0 — flat left-border
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: col, width: 4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(compTitle, style: TextStyle(fontSize: tSize, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(val, style: TextStyle(fontSize: vSize, fontWeight: FontWeight.bold, color: fgCol ?? col)),
              Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ]),
          );
      }
    }

    final h = _heights[comp.heightLevel.clamp(_kMinHeight, 5)];

    // Table with explicit column defs (raw rows from fetchData)
    if (comp.type == 'table' && comp._cachedData is List) {
      final tableRows = comp._cachedData as List;
      final cols = comp.datasource.tableColumns
          .map((c) => c.label.isNotEmpty ? c.label : c.field).toList();
      final colsAr = comp.datasource.tableColumns
          .map((c) => (c.labelAr?.isNotEmpty ?? false) ? c.labelAr! : (c.label.isNotEmpty ? c.label : c.field)).toList();
      return SizedBox(
        height: h,
        child: _TableCard(
          table: {
            'columns': cols.isNotEmpty ? cols : ['Column'],
            'columns_ar': colsAr,
            'rows': tableRows.map((r) => (r as List).map((v) => v.toString()).toList()).toList(),
          },
          colorTheme: comp.colorTheme,
          styleVariant: comp.styleVariant,
        ),
      );
    }

    final data = comp._cachedData as Map<String, dynamic>?;
    if (data == null || data.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
    }

    if (comp.type == 'chart') {
      final chartData = {
        'type': comp.chartType,
        'title': comp.title,
        'x_labels': data.keys.take(12).toList(),
        'series': [{'label': comp.title, 'data': data.values.take(12).map((v) => (v as num).toDouble()).toList()}],
      };
      final isPie = comp.chartType == 'pie' || comp.chartType == 'donut';
      return SizedBox(
        height: h,
        child: ClipRect(
          child: _ChartCard(
            chart: chartData,
            height: isPie ? h : h - 26,
            colorOffset: _themes[comp.colorTheme],
          ),
        ),
      );
    }

    // Table (grouped)
    final keys = data.keys.toList();
    final vals = data.values.map((v) => v.toString()).toList();
    return SizedBox(
      height: h,
      child: _TableCard(
        table: {
          'columns': ['Category', 'Value'],
          'rows': List.generate(keys.length, (i) => [keys[i], vals[i]]),
        },
        colorTheme: comp.colorTheme,
        styleVariant: comp.styleVariant,
      ),
    );
  }
}

// ─── add component sheet ──────────────────────────────────────────────────────
class _AddComponentSheet extends StatelessWidget {
  final void Function(_CComponent) onAdd;
  const _AddComponentSheet({required this.onAdd});

  static const _templates = [
    {'type': 'kpi',   'title': 'Total Tickets',   'icon': Icons.confirmation_number_outlined, 'aggFn': 'count', 'format': 'number'},
    {'type': 'kpi',   'title': 'Closed Tickets',  'icon': Icons.check_circle_outline,         'aggFn': 'count', 'format': 'number', 'status': ['closed']},
    {'type': 'kpi',   'title': 'Pending Tickets', 'icon': Icons.pending_outlined,             'aggFn': 'count', 'format': 'number', 'status': ['pending']},
    {'type': 'chart', 'title': 'Tickets by Status','icon': Icons.pie_chart_outline,           'chartType': 'pie',   'groupBy': 'status'},
    {'type': 'chart', 'title': 'Tickets by Priority','icon': Icons.bar_chart,                'chartType': 'bar',   'groupBy': 'priority'},
    {'type': 'chart', 'title': 'Trend Over Time',  'icon': Icons.show_chart,                 'chartType': 'area',  'groupBy': 'month'},
    {'type': 'chart', 'title': 'By Department',    'icon': Icons.bar_chart_outlined,         'chartType': 'horizontal_bar', 'groupBy': 'department'},
    {'type': 'table', 'title': 'Summary Table',    'icon': Icons.table_chart_outlined,       'groupBy': 'status'},
  ];

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? 'اختر نوع المكوّن' : 'Choose Component',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 3.0, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _templates.length,
          itemBuilder: (_, i) {
            final t = _templates[i];
            return InkWell(
              onTap: () {
                final ds = _CDataSource(
                  aggFn: t['aggFn'] == 'count' ? _CAggFn.count : _CAggFn.sum,
                  groupBy: t['groupBy'] != null
                      ? _CGroupBy.values.firstWhere((e) => e.name == t['groupBy'],
                          orElse: () => _CGroupBy.status)
                      : null,
                  statusFilter: t.containsKey('status')
                      ? Set<String>.from(t['status'] as List)
                      : {'pending','inprogress','prefinished','closed','resolved'},
                  format: t['format'] as String? ?? 'number',
                );
                final comp = _CComponent(
                  id: '${t['type']}_${DateTime.now().millisecondsSinceEpoch}',
                  type: t['type'] as String,
                  title: t['title'] as String,
                  chartType: t['chartType'] as String? ?? 'bar',
                  datasource: ds,
                );
                Navigator.pop(context);
                onAdd(comp);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  Icon(t['icon'] as IconData, size: 20, color: const Color(0xFFf16936)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t['title'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            );
          },
        ),
      ]),
    ));
  }
}

// ─── component config sheet ───────────────────────────────────────────────────
class _ComponentConfigSheet extends StatefulWidget {
  final _CComponent comp;
  final VoidCallback onChanged;
  final ScrollController scrollController;
  const _ComponentConfigSheet({required this.comp, required this.onChanged, required this.scrollController});

  @override
  State<_ComponentConfigSheet> createState() => _ComponentConfigSheetState();
}

class _ComponentConfigSheetState extends State<_ComponentConfigSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _titleArCtrl;
  final Map<_RowCondition, TextEditingController> _condValCtrl = {};
  final Map<_ColumnDef, TextEditingController> _colLabelCtrl = {};
  final Map<_ColumnDef, TextEditingController> _colLabelArCtrl = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(text: widget.comp.title);
    _titleArCtrl = TextEditingController(text: widget.comp.titleAr ?? '');
    final ds = widget.comp.datasource;
    for (final c in ds.conditions) {
      _condValCtrl[c] = TextEditingController(text: c.value);
    }
    for (final c in ds.tableColumns) {
      _colLabelCtrl[c]   = TextEditingController(text: c.label);
      _colLabelArCtrl[c] = TextEditingController(text: c.labelAr ?? '');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleArCtrl.dispose();
    for (final c in _condValCtrl.values) { c.dispose(); }
    for (final c in _colLabelCtrl.values) { c.dispose(); }
    for (final c in _colLabelArCtrl.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final comp = widget.comp;
    final ds   = comp.datasource;

    void upd(VoidCallback fn) { setState(fn); widget.onChanged(); }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        Text(isAr ? 'تهيئة المكوّن' : 'Configure Component',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),

        _lbl(isAr ? 'العنوان' : 'Title'),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          onChanged: (v) => upd(() => comp.title = v),
        ),
        const SizedBox(height: 8),
        _lbl(isAr ? 'العنوان (عربي)' : 'Title (Arabic)'),
        TextField(
          controller: _titleArCtrl,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: 'بالعربية...',
          ),
          textDirection: TextDirection.rtl,
          onChanged: (v) => upd(() => comp.titleAr = v.isEmpty ? null : v),
        ),
        const SizedBox(height: 16),

        // Chart type (charts only)
        if (comp.type == 'chart') ...[
          _lbl(isAr ? 'نوع الرسم' : 'Chart Type'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in ['bar','horizontal_bar','pie','line','area'])
              _typeChip(t, comp.chartType,
                  () => upd(() => comp.chartType = t), isAr),
          ]),
          const SizedBox(height: 16),
        ],

        // Aggregation
        _lbl(isAr ? 'دالة التجميع' : 'Aggregation'),
        _segmented<_CAggFn>(
          segments: {_CAggFn.count: 'COUNT', _CAggFn.sum: 'SUM', _CAggFn.avg: 'AVG'},
          selected: ds.aggFn,
          onSelect: (v) => upd(() => ds.aggFn = v),
        ),
        const SizedBox(height: 16),

        // Data Source
        _lbl(isAr ? 'مصدر البيانات' : 'Data Source'),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final entry in const {'tickets':'Tickets','users':'Users','places':'Places','departments':'Departments'}.entries)
            _filterChip(
              label: entry.value,
              selected: ds.tableSource == entry.key,
              onTap: () => upd(() => ds.tableSource = entry.key),
            ),
        ]),
        const SizedBox(height: 16),

        // Group By (charts + tables)
        if (comp.type != 'kpi') ...[
          _lbl(isAr ? 'التجميع حسب' : 'Group By'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final gb in _CGroupBy.values)
              _filterChip(
                label: gb.name,
                selected: ds.groupBy == gb,
                onTap: () => upd(() => ds.groupBy = ds.groupBy == gb ? null : gb),
              ),
          ]),
          const SizedBox(height: 16),
        ],

        // Format (kpi only)
        if (comp.type == 'kpi') ...[
          _lbl(isAr ? 'تنسيق القيمة' : 'Value Format'),
          _segmented<String>(
            segments: {'number': '123', 'percent': '%', 'duration': 'h'},
            selected: ds.format,
            onSelect: (v) => upd(() => ds.format = v),
          ),
          const SizedBox(height: 16),
        ],

        // Date range
        _lbl(isAr ? 'نطاق التاريخ' : 'Date Range'),
        Wrap(spacing: 8, children: [7, 30, 90, 180, 365].map((d) => _filterChip(
          label: '${d}d', selected: ds.daysBack == d,
          onTap: () => upd(() => ds.daysBack = d),
        )).toList()),
        const SizedBox(height: 16),

        // Status filter
        _lbl(isAr ? 'الحالة' : 'Status'),
        Wrap(spacing: 8, runSpacing: 6, children: {
          'pending': 'Pending', 'inprogress': 'In Progress',
          'prefinished': 'Pre-finished', 'closed': 'Closed', 'resolved': 'Resolved',
        }.entries.map((e) => _filterChip(
          label: e.value, selected: ds.statusFilter.contains(e.key),
          onTap: () => upd(() => ds.statusFilter.contains(e.key)
              ? ds.statusFilter.remove(e.key)
              : ds.statusFilter.add(e.key)),
        )).toList()),
        const SizedBox(height: 16),

        // Table columns (table type only)
        if (comp.type == 'table') ...[
          _lbl(isAr ? 'أعمدة الجدول' : 'Table Columns'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in _kTableFields.entries)
              _filterChip(
                label: entry.value,
                selected: ds.tableColumns.any((c) => c.field == entry.key),
                onTap: () {
                  final existing = ds.tableColumns.where((c) => c.field == entry.key).toList();
                  if (existing.isNotEmpty) {
                    for (final col in existing) {
                      _colLabelCtrl.remove(col)?.dispose();
                    }
                    setState(() => ds.tableColumns.removeWhere((c) => c.field == entry.key));
                  } else {
                    final col = _ColumnDef(field: entry.key, label: entry.value);
                    setState(() {
                      ds.tableColumns.add(col);
                      _colLabelCtrl[col] = TextEditingController(text: entry.value);
                    });
                  }
                },
              ),
          ]),
          if (ds.tableColumns.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final col in List<_ColumnDef>.from(ds.tableColumns)) ...[
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf16936).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_kTableFields[col.field] ?? col.field,
                      style: const TextStyle(fontSize: 10, color: Color(0xFFf16936),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _colLabelCtrl.putIfAbsent(
                      col, () => TextEditingController(text: col.label)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    hintText: isAr ? 'تسمية العمود' : 'Column label',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => setState(() =>
                      col.label = v.isEmpty ? (_kTableFields[col.field] ?? col.field) : v),
                )),
                const SizedBox(width: 6),
                Expanded(child: TextField(
                  controller: _colLabelArCtrl.putIfAbsent(
                      col, () => TextEditingController(text: col.labelAr ?? '')),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    hintText: 'بالعربية...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setState(() => col.labelAr = v.isEmpty ? null : v),
                )),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _colLabelCtrl.remove(col)?.dispose();
                    _colLabelArCtrl.remove(col)?.dispose();
                    setState(() => ds.tableColumns.remove(col));
                  },
                ),
              ]),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 16),
        ],

        // Row conditions (expressions)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: _lbl(isAr ? 'شروط التصفية' : 'Row Conditions')),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(isAr ? 'إضافة شرط' : 'Add Condition',
                style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFf16936),
                visualDensity: VisualDensity.compact),
            onPressed: () {
              final cond = _RowCondition(field: 'status', op: 'eq', value: '');
              setState(() {
                ds.conditions.add(cond);
                _condValCtrl[cond] = TextEditingController();
              });
            },
          ),
        ]),
        if (ds.conditions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                isAr ? 'لا توجد شروط — جميع السجلات مشمولة'
                     : 'No conditions — all rows included',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          )
        else ...[
          for (final cond in List<_RowCondition>.from(ds.conditions)) ...[
            Row(children: [
              Expanded(flex: 3, child: _styledDropdown<String>(
                value: cond.field,
                items: _kCondFields.map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(_kTableFields[f] ?? f,
                        style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (v) { if (v != null) setState(() => cond.field = v); },
              )),
              const SizedBox(width: 4),
              Expanded(flex: 2, child: _styledDropdown<String>(
                value: cond.op,
                items: _kCondOps.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (v) { if (v != null) setState(() => cond.op = v); },
              )),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: TextField(
                controller: _condValCtrl.putIfAbsent(
                    cond, () => TextEditingController(text: cond.value)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  hintText: isAr ? 'القيمة' : 'value',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (v) => setState(() => cond.value = v),
              )),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  _condValCtrl.remove(cond)?.dispose();
                  setState(() => ds.conditions.remove(cond));
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            ]),
            const SizedBox(height: 6),
          ],
        ],
        const SizedBox(height: 16),

        // Layout
        _lbl(isAr ? 'العرض (من 32 عمود)' : 'Width (of 32 cols)'),
        Row(children: [4,8,12,16,20,24,28,32].asMap().entries.map((e) {
          final cs = e.value;
          const labels = ['⅛','¼','⅜','½','⅝','¾','⅞','■'];
          final sel = comp.colSpan == cs;
          return Expanded(child: GestureDetector(
            onTap: () => upd(() => comp.colSpan = cs),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFf16936) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(labels[e.key], style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        }).toList()),
        const SizedBox(height: 14),

        // Height picker — hidden on mobile KPI (height is fixed by row count)
        if (!(MediaQuery.of(context).size.width < 560 && comp.type == 'kpi')) ...[
          _lbl(isAr ? 'الارتفاع' : 'Height'),
          Row(children: List.generate(_heights.length, (i) {
            const labels = ['XS','S','M','L','XL','XXL'];
            const minLvl = _kMinHeight;
            final sel      = comp.heightLevel == i;
            final disabled = i < minLvl;
            return Expanded(child: GestureDetector(
              onTap: disabled ? null : () => upd(() => comp.heightLevel = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.grey.shade200
                      : sel ? const Color(0xFFf16936) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(labels[i], style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: disabled
                          ? Colors.grey.shade400
                          : sel ? Colors.white : Colors.grey[600])),
                  if (i == minLvl)
                    Text(isAr ? 'حد أدنى' : 'min',
                        style: const TextStyle(fontSize: 8, color: Color(0xFFf16936))),
                ]),
              ),
            ));
          })),
          const SizedBox(height: 20),
        ],
        const Divider(),
        const SizedBox(height: 12),

        // ── Visual Style ──────────────────────────────────────────────────────
        Text(isAr ? 'النمط البصري' : 'Visual Style',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),

        // Style variant (KPI has 5 named designs; others just color)
        if (comp.type == 'kpi') ...[
          _lbl(isAr ? 'تصميم البطاقة' : 'Card Design'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in const {
              0: 'Left Border',
              1: 'Gradient',
              2: 'Outlined',
              3: 'Minimal',
              4: 'Bold Bar',
            }.entries)
              GestureDetector(
                onTap: () => upd(() => comp.styleVariant = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: comp.styleVariant == entry.key
                        ? const Color(0xFFf16936)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: comp.styleVariant == entry.key
                          ? const Color(0xFFf16936)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(entry.value, style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: comp.styleVariant == entry.key ? Colors.white : Colors.grey[700])),
                ),
              ),
          ]),
          const SizedBox(height: 16),
        ],

        // Accent color picker
        _lbl(isAr ? 'لون التمييز' : 'Accent Color'),
        Row(children: [
          // "Auto" chip (uses colorTheme)
          GestureDetector(
            onTap: () => upd(() => comp.accentColor = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: comp.accentColor == null ? const Color(0xFFf16936) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: comp.accentColor == null ? const Color(0xFFf16936) : Colors.grey.shade300),
              ),
              child: Text(isAr ? 'تلقائي' : 'Auto',
                  style: TextStyle(fontSize: 11,
                      color: comp.accentColor == null ? Colors.white : Colors.grey[700])),
            ),
          ),
          // Color swatches
          ...List.generate(_palette.length, (i) {
            final col = _palette[i];
            final sel = comp.accentColor == col.toARGB32();
            return GestureDetector(
              onTap: () => upd(() => comp.accentColor = col.toARGB32()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 5),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: col, shape: BoxShape.circle,
                  border: sel
                      ? Border.all(color: Colors.black54, width: 2.5)
                      : Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 16),

        // Font color
        _lbl(isAr ? 'لون الخط' : 'Font Color'),
        Row(children: [
          GestureDetector(
            onTap: () => upd(() => comp.fontColor = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: comp.fontColor == null ? const Color(0xFFf16936) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: comp.fontColor == null ? const Color(0xFFf16936) : Colors.grey.shade300),
              ),
              child: Text(isAr ? 'تلقائي' : 'Auto',
                  style: TextStyle(fontSize: 11,
                      color: comp.fontColor == null ? Colors.white : Colors.grey[700])),
            ),
          ),
          ...([Colors.black87, Colors.white, Colors.grey.shade700,
               Colors.blueGrey.shade700, Colors.indigo.shade800]).asMap().entries.map((e) {
            final col = e.value;
            final sel = comp.fontColor == col.toARGB32();
            return GestureDetector(
              onTap: () => upd(() => comp.fontColor = col.toARGB32()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 5),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: col, shape: BoxShape.circle,
                  border: sel
                      ? Border.all(color: const Color(0xFFf16936), width: 2.5)
                      : Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 16),

        // Font sizes
        _lbl(isAr ? 'حجم القيمة' : 'Value Font Size'),
        Row(children: [
          IconButton(
            onPressed: comp.valueFontSize > 14
                ? () => upd(() => comp.valueFontSize -= 2)
                : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: const Color(0xFFf16936),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text('${comp.valueFontSize.toInt()}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: comp.valueFontSize < 48
                ? () => upd(() => comp.valueFontSize += 2)
                : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            color: const Color(0xFFf16936),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 12),

        _lbl(isAr ? 'حجم العنوان' : 'Title Font Size'),
        Row(children: [
          IconButton(
            onPressed: comp.titleFontSize > 8
                ? () => upd(() => comp.titleFontSize -= 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: const Color(0xFFf16936),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text('${comp.titleFontSize.toInt()}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: comp.titleFontSize < 20
                ? () => upd(() => comp.titleFontSize += 1)
                : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            color: const Color(0xFFf16936),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: () { Navigator.pop(context); widget.onChanged(); },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf16936), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(isAr ? 'تطبيق' : 'Apply & Refresh'),
        ),
      ],
    );
  }

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
  );

  Widget _styledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _typeChip(String t, String current, VoidCallback onTap, bool isAr) {
    final labels = {'bar':'Bar','horizontal_bar':'H-Bar','pie':'Pie','line':'Line','area':'Area'};
    final sel = t == current;
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFFf16936) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sel ? const Color(0xFFf16936) : Colors.grey.shade300),
      ),
      child: Text(labels[t]!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : Colors.grey[700])),
    ));
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFf16936) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? const Color(0xFFf16936) : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : Colors.grey[700])),
    ));
  }

  Widget _segmented<T>({
    required Map<T, String> segments,
    required T selected,
    required void Function(T) onSelect,
  }) {
    return Row(mainAxisSize: MainAxisSize.min, children: segments.entries.map((e) {
      final sel = e.key == selected;
      return GestureDetector(
        onTap: () => onSelect(e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFf16936) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? const Color(0xFFf16936) : Colors.grey.shade300),
          ),
          child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: sel ? Colors.white : Colors.grey[700])),
        ),
      );
    }).toList());
  }
}
