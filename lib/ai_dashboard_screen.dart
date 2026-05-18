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
  String chartType;  // 'bar' | 'pie' | 'line' | 'area' | 'horizontal_bar'
  int heightLevel;   // 0-5 → XS/S/M/L/XL/XXL
  int colorTheme;    // index into _themes
  int colSpan;       // 1-8 (columns in an 8-column grid)
  bool deleted;

  _DashItem({
    required this.id,
    required this.kind,
    required this.raw,
    this.chartType = 'bar',
    this.heightLevel = 1,
    this.colorTheme = 0,
    this.colSpan = 4,
    this.deleted = false,
  });
}

const _heights = [100.0, 140.0, 180.0, 240.0, 320.0, 440.0]; // XS S M L XL XXL

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
      colSpan:     (l['colSpan']     as int?) ?? 8,
      heightLevel: (l['heightLevel'] as int?) ?? 1,
      colorTheme:  (l['colorTheme']  as int?) ?? 0,
    ));
  }
  final charts = (data['charts'] as List?)?.cast<Map>() ?? [];
  for (int i = 0; i < charts.length; i++) {
    final id = 'chart_$i';
    final l = lOf(id);
    items.add(_DashItem(
      id: id, kind: _Kind.chart, raw: charts[i],
      chartType:   (l['chartType']   as String?) ?? (charts[i]['type'] as String? ?? 'bar').toLowerCase(),
      colSpan:     (l['colSpan']     as int?) ?? 4,
      heightLevel: (l['heightLevel'] as int?) ?? 2,
      colorTheme:  (l['colorTheme']  as int?) ?? 0,
    ));
  }
  final tables = (data['tables'] as List?)?.cast<Map>() ?? [];
  for (int i = 0; i < tables.length; i++) {
    final id = 'table_$i';
    final l = lOf(id);
    items.add(_DashItem(
      id: id, kind: _Kind.table, raw: tables[i],
      colSpan:     (l['colSpan']     as int?) ?? 8,
      heightLevel: (l['heightLevel'] as int?) ?? 2,
      colorTheme:  (l['colorTheme']  as int?) ?? 0,
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
    _tabCtrl = TabController(length: 3, vsync: this);
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
    if (_statusFilter.length < 6) {
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
  const AiDashboardView({super.key, required this.data, this.showTitle = true});

  @override
  Widget build(BuildContext context) => _InteractiveDashboard(
        data: data,
        l10n: AppLocalizations.safeOf(context),
        showTitle: showTitle,
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
  const _InteractiveDashboard({super.key, required this.data, required this.l10n, this.showTitle = true});

  @override
  State<_InteractiveDashboard> createState() => _InteractiveDashboardState();
}

class _InteractiveDashboardState extends State<_InteractiveDashboard> {
  late List<_DashItem> _items;
  final _dragAccum   = <String, double>{};
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

  List<List<_DashItem>> _groupIntoRows(List<_DashItem> vis) =>
      _groupIntoRowsN(vis, 4, (cs) => cs.clamp(1, 4).toInt());

  List<List<_DashItem>> _groupIntoRowsN(
      List<_DashItem> vis, int cols, int Function(int) eff) {
    final rows = <List<_DashItem>>[];
    var row = <_DashItem>[];
    var span = 0;
    for (final item in vis) {
      final cs = eff(item.colSpan);
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

  Widget _buildResizableCard(_DashItem item, List<_DashItem> vis, double totalWidth, int gridCols) {
    final isResizing = _resizingIds.contains(item.id);
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
        Positioned(
          right: 0, top: 0, bottom: 0, width: 20,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() => _resizingIds.add(item.id)),
              onPanUpdate: (d) {
                _dragAccum[item.id] = (_dragAccum[item.id] ?? 0) + d.delta.dx;
                final unitPx = totalWidth / gridCols;
                if (_dragAccum[item.id]! > unitPx && item.colSpan < gridCols) {
                  setState(() { item.colSpan++; _dragAccum[item.id] = 0; });
                } else if (_dragAccum[item.id]! < -unitPx && item.colSpan > 1) {
                  setState(() { item.colSpan--; _dragAccum[item.id] = 0; });
                }
              },
              onPanEnd: (_) => setState(() {
                _resizingIds.remove(item.id);
                _dragAccum[item.id] = 0;
              }),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: isResizing ? 5 : 4,
                  height: isResizing ? 48 : 36,
                  decoration: BoxDecoration(
                    color: isResizing
                        ? const Color(0xFFf16936)
                        : Colors.grey.shade400.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
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
      final isMobile = constraints.maxWidth < 560;
      final gridCols = isMobile ? 4 : 8;
      int eff(int cs) => cs.clamp(1, gridCols).toInt();

      final rows = _groupIntoRowsN(vis, gridCols, eff);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.showTitle) ...[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
        Padding(
          padding: EdgeInsets.only(top: widget.showTitle ? 4 : 0, bottom: 12),
          child: Text(
            isAr
                ? 'اسحب المقبض للتحريك  •  اسحب الحافة اليمنى لتغيير العرض  •  ▲ ▼ للارتفاع  •  انقر للخصائص  •  ✕ للحذف'
                : 'Drag handle to move  •  Drag right edge to resize  •  ▲ ▼ height  •  Tap card to edit  •  ✕ to remove',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ),
        ...rows.map((rowItems) {
          final usedSpan = rowItems.fold<int>(0, (s, i) => s + eff(i.colSpan));
          final remSpan  = gridCols - usedSpan;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...rowItems.asMap().entries.map((e) {
                    final item = e.value;
                    return Expanded(
                      flex: eff(item.colSpan),
                      child: Padding(
                        padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
                        child: _buildResizableCard(item, vis, constraints.maxWidth, gridCols),
                      ),
                    );
                  }),
                  if (remSpan > 0) Expanded(
                    flex: remSpan,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildEmptySlot(insertAfterId: rowItems.last.id),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ]);
    });
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: drag handle + title + close ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            // Explicit drag handle — only this area initiates a drag
            Draggable<String>(
              data: item.id,
              feedback: ghostPreview(),
              childWhenDragging: const Icon(Icons.drag_indicator_rounded, color: Color(0xFFf16936), size: 20),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.drag_indicator_rounded, color: Colors.grey.shade400, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(_label(item),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
              padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
              onPressed: () => setState(() => item.deleted = true),
            ),
          ]),
        ),
        // ── Controls row ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: Row(children: [
            _ctrlBtn(Icons.chevron_left,  item.colSpan > 1 ? () => setState(() => item.colSpan--) : null),
            GestureDetector(
              onTap: () => setState(() => item.colSpan = item.colSpan % 8 + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)),
                child: Text(_spanLabel(item.colSpan),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ),
            ),
            _ctrlBtn(Icons.chevron_right, item.colSpan < 8 ? () => setState(() => item.colSpan++) : null),
            const SizedBox(width: 4),
            _ctrlBtn(Icons.expand_more, item.heightLevel > 0 ? () => setState(() => item.heightLevel--) : null),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)),
              child: Text(_heightLabel(item.heightLevel),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
            _ctrlBtn(Icons.expand_less, item.heightLevel < 5 ? () => setState(() => item.heightLevel++) : null),
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

  String _spanLabel(int cs) => switch (cs.clamp(1, 8)) {
        1 => '⅛', 2 => '¼', 3 => '⅜', 4 => '½',
        5 => '⅝', 6 => '¾', 7 => '⅞', _ => '■',
      };
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
    return (item.raw as Map)['title'] as String? ?? (item.kind == _Kind.chart ? 'Chart' : 'Table');
  }

  Widget _content(_DashItem item) {
    switch (item.kind) {
      case _Kind.kpiGroup:
        return _KpiGrid(kpis: (item.raw as List).cast<Map>(), colorOffset: _themes[item.colorTheme], colSpan: item.colSpan);
      case _Kind.chart:
        final d = Map<String, dynamic>.from(item.raw as Map)..['type'] = item.chartType;
        return _ChartCard(chart: d, height: _heights[item.heightLevel], colorOffset: _themes[item.colorTheme]);
      case _Kind.table:
        return _TableCard(table: item.raw as Map);
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

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _getTitle());
  }

  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

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
        _sectionLabel(isAr ? 'العرض (من 8 أعمدة)' : 'Width (of 8 columns)'),
        Row(children: List.generate(8, (i) {
          final cs = i + 1;
          final sel = item.colSpan == cs;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() { item.colSpan = cs; widget.onChanged(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? col : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text('$cs',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        })),
        const SizedBox(height: 14),

        _sectionLabel(isAr ? 'الارتفاع' : 'Height'),
        Row(children: List.generate(_heights.length, (i) {
          const labels = ['XS','S','M','L','XL','XXL'];
          final sel = item.heightLevel == i;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() { item.heightLevel = i; widget.onChanged(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? col : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(labels[i],
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        })),
        const SizedBox(height: 20),

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
}

// ─── kpi grid ─────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final List<Map> kpis;
  final int colorOffset;
  final int colSpan; // kpis per row = colSpan
  const _KpiGrid({required this.kpis, this.colorOffset = 0, this.colSpan = 4});

  @override
  Widget build(BuildContext context) {
    final perRow = colSpan.clamp(1, 4);
    final rows = <List<Map>>[];
    for (int i = 0; i < kpis.length; i += perRow) {
      rows.add(kpis.sublist(i, (i + perRow).clamp(i, kpis.length)));
    }
    return Column(
      children: rows.asMap().entries.map((re) {
        final row = re.value;
        final rowIdx = re.key;
        return Padding(
          padding: EdgeInsets.only(bottom: rowIdx < rows.length - 1 ? 10 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row.asMap().entries.map((ke) {
              final kpi = ke.value;
              final kpiIdx = rowIdx * perRow + ke.key;
              final col = _color(kpiIdx + colorOffset);
              final label    = kpi['label']?.toString() ?? '';
              final value    = kpi['value']?.toString() ?? '—';
              final subtitle = kpi['subtitle'] as String?;
              final change   = kpi['change'] as String?;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: ke.key > 0 ? 8 : 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                      border: Border(left: BorderSide(color: col, width: 4)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                      if (change != null && change.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: change.startsWith('+') ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(change, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: change.startsWith('+') ? Colors.green : Colors.red)),
                        ),
                      ],
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
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
    return Column(
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
    );
  }
}

class _Legend extends StatelessWidget {
  final List<Map> series;
  final int colorOffset;
  const _Legend({required this.series, this.colorOffset = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 5,
        children: series.asMap().entries.map((e) {
          final label = e.value['label']?.toString() ?? 'Series ${e.key + 1}';
          final col   = _color(e.key + colorOffset);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey[700])),
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
    final labels = (chart['x_labels'] as List?)?.cast<String>() ?? [];
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
      final lbl = labels[idx];
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(lbl.length > 8 ? '${lbl.substring(0, 7)}…' : lbl,
            style: const TextStyle(fontSize: 9)),
      );
    }

    return BarChart(BarChartData(
      barGroups: groups, maxY: maxY * 1.2,
      gridData: FlGridData(drawVerticalLine: !horizontal, drawHorizontalLine: horizontal),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: horizontal ? 64 : 32,
          getTitlesWidget: (v, meta) {
            if (!horizontal) return const SizedBox.shrink();
            final idx = v.toInt();
            if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
            final lbl = labels[idx];
            return Padding(padding: const EdgeInsets.only(right: 4),
                child: Text(lbl.length > 9 ? '${lbl.substring(0, 8)}…' : lbl,
                    style: const TextStyle(fontSize: 9), textAlign: TextAlign.right));
          },
        )),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: !horizontal, getTitlesWidget: labelWidget,
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
    // x_labels = slice names; series[0].data = values
    var labels = (chart['x_labels'] as List?)?.cast<String>() ?? [];
    final series  = (chart['series'] as List?)?.cast<Map>() ?? [];
    final rawData = series.isNotEmpty
        ? (series[0]['data'] as List?)?.cast<num>() ?? []
        : (chart['data'] as List?)?.cast<num>() ?? [];
    if (labels.isEmpty && rawData.isNotEmpty) {
      labels = List.generate(rawData.length, (i) => 'Item ${i + 1}');
    }
    if (labels.isEmpty || rawData.isEmpty) return const Center(child: Text('No data'));

    final total = rawData.fold<double>(0, (s, v) => s + v.toDouble());
    final sections = rawData.asMap().entries.map((e) {
      final pct = total > 0 ? e.value.toDouble() / total * 100 : 0.0;
      return PieChartSectionData(
        value: e.value.toDouble(), color: _color(e.key + colorOffset),
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 70,
      );
    }).toList();

    final legendItems = labels.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9,
            decoration: BoxDecoration(color: _color(e.key + colorOffset), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Flexible(child: Text(e.value.length > 14 ? '${e.value.substring(0, 13)}…' : e.value,
            style: const TextStyle(fontSize: 10))),
      ]),
    )).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 220;
      final pieWidget = PieChart(PieChartData(
          sections: sections, sectionsSpace: 2, centerSpaceRadius: narrow ? 20 : 28));

      if (narrow) {
        return Column(children: [
          SizedBox(height: constraints.maxWidth * 0.8, child: pieWidget),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: legendItems),
        ]);
      }
      return Row(children: [
        Expanded(child: pieWidget),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
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
    final labels = (chart['x_labels'] as List?)?.cast<String>() ?? [];
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
          showTitles: true,
          interval: (labels.length / 5).ceilToDouble(),
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx >= labels.length || idx < 0) return const SizedBox.shrink();
            final lbl = labels[idx];
            return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(lbl.length > 6 ? lbl.substring(lbl.length - 5) : lbl,
                    style: const TextStyle(fontSize: 9)));
          },
        )),
      ),
    ));
  }
}

// ─── table card ───────────────────────────────────────────────────────────────
class _TableCard extends StatefulWidget {
  final Map table;
  const _TableCard({required this.table});
  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  int?   _sortCol;
  bool   _sortAsc = true;
  String _filter  = '';

  @override
  Widget build(BuildContext context) {
    final isAr    = Localizations.localeOf(context).languageCode == 'ar';
    final columns = (widget.table['columns'] as List?)?.cast<String>() ?? [];
    var   rows    = (widget.table['rows'] as List?)
            ?.map((r) => (r as List).cast<String>()).toList() ?? [];
    if (columns.isEmpty) return const SizedBox.shrink();

    // Apply filter
    if (_filter.isNotEmpty) {
      final q = _filter.toLowerCase();
      rows = rows.where((r) => r.any((cell) => cell.toLowerCase().contains(q))).toList();
    }

    // Apply sort
    if (_sortCol != null && _sortCol! < columns.length) {
      rows.sort((a, b) {
        final av = _sortCol! < a.length ? a[_sortCol!] : '';
        final bv = _sortCol! < b.length ? b[_sortCol!] : '';
        final numA = double.tryParse(av.replaceAll(',', ''));
        final numB = double.tryParse(bv.replaceAll(',', ''));
        final cmp = (numA != null && numB != null)
            ? numA.compareTo(numB)
            : av.compareTo(bv);
        return _sortAsc ? cmp : -cmp;
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filter bar
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: isAr ? 'بحث...' : 'Filter...',
            prefixIcon: const Icon(Icons.search, size: 16),
            suffixIcon: _filter.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _filter = ''),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
      ),
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(isAr ? 'لا توجد نتائج' : 'No matching rows',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        )
      else
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1),
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              children: [
                // Header row — tappable to sort
                TableRow(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFf16936).withValues(alpha: 0.12),
                      const Color(0xFFf16936).withValues(alpha: 0.06),
                    ]),
                  ),
                  children: columns.asMap().entries.map((e) {
                    final isSorted = _sortCol == e.key;
                    return InkWell(
                      onTap: () => setState(() {
                        if (_sortCol == e.key) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortCol = e.key;
                          _sortAsc = true;
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(e.value,
                              style: const TextStyle(fontWeight: FontWeight.bold,
                                  fontSize: 12.5, color: Color(0xFF333333))),
                          if (isSorted) ...[
                            const SizedBox(width: 4),
                            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 12, color: const Color(0xFFf16936)),
                          ],
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                // Data rows
                ...rows.asMap().entries.map((re) => TableRow(
                  decoration: BoxDecoration(
                      color: re.key.isEven ? Colors.white : Colors.grey.shade50),
                  children: re.value.map((cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Text(cell, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                  )).toList(),
                )),
              ],
            ),
          ),
        ),
    ]);
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

class _CDataSource {
  _CAggFn aggFn;
  String? aggField;
  _CGroupBy? groupBy;
  int daysBack;
  Set<String> statusFilter;
  Set<String> priorityFilter;
  String format; // 'number' | 'percent' | 'duration'

  _CDataSource({
    this.aggFn = _CAggFn.count,
    this.aggField,
    this.groupBy,
    this.daysBack = 30,
    Set<String>? statusFilter,
    Set<String>? priorityFilter,
    this.format = 'number',
  })  : statusFilter  = statusFilter  ?? {'pending','inprogress','prefinished','closed','resolved'},
        priorityFilter = priorityFilter ?? {'low','medium','high','critical','urgent'};

  Map<String, dynamic> toJson() => {
    'aggFn': aggFn.name, 'aggField': aggField, 'groupBy': groupBy?.name,
    'daysBack': daysBack,
    'statusFilter': statusFilter.toList(),
    'priorityFilter': priorityFilter.toList(),
    'format': format,
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
  );
}

class _CComponent {
  String id;
  String type; // 'kpi' | 'chart' | 'table'
  String title;
  String chartType;
  int colSpan;
  int heightLevel;
  int colorTheme;
  _CDataSource datasource;
  dynamic _cachedData;
  bool _loading = false;

  _CComponent({
    required this.id,
    required this.type,
    required this.title,
    this.chartType = 'bar',
    this.colSpan = 4,
    this.heightLevel = 2,
    this.colorTheme = 0,
    _CDataSource? datasource,
  }) : datasource = datasource ?? _CDataSource();

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'title': title,
    'chartType': chartType, 'colSpan': colSpan,
    'heightLevel': heightLevel, 'colorTheme': colorTheme,
    'datasource': datasource.toJson(),
  };

  factory _CComponent.fromJson(Map<String, dynamic> j) => _CComponent(
    id: j['id'] as String? ?? UniqueKey().toString(),
    type: j['type'] as String? ?? 'kpi',
    title: j['title'] as String? ?? '',
    chartType: j['chartType'] as String? ?? 'bar',
    colSpan: (j['colSpan'] as int?) ?? 4,
    heightLevel: (j['heightLevel'] as int?) ?? 2,
    colorTheme: (j['colorTheme'] as int?) ?? 0,
    datasource: j['datasource'] != null
        ? _CDataSource.fromJson(Map<String, dynamic>.from(j['datasource'] as Map))
        : _CDataSource(),
  );
}

class CustomDashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  final String? dashboardId;
  const CustomDashboardScreen({super.key, required this.currentUser, this.dashboardId});

  @override
  State<CustomDashboardScreen> createState() => _CustomDashboardScreenState();
}

class _CustomDashboardScreenState extends State<CustomDashboardScreen> {
  final _titleCtrl = TextEditingController(text: 'My Dashboard');
  List<_CComponent> _components = [];
  bool _loading = false;
  bool _saving  = false;
  String? _savedId;

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
      final ds   = comp.datasource;
      final since = DateTime.now().subtract(Duration(days: ds.daysBack)).toIso8601String();
      var q = supabase.from('tickets').select(
          'id,status,priority,assigned_to,created_at,'
          'departments:target_department_id(name),places(name)');
      if (widget.currentUser.departmentId != null) {
        q = q.eq('target_department_id', widget.currentUser.departmentId!);
      }
      q = q.gte('created_at', since);
      if (ds.statusFilter.length < 6) q = q.inFilter('status', ds.statusFilter.toList());
      if (ds.priorityFilter.length < 5) q = q.inFilter('priority', ds.priorityFilter.toList());
      final rows = await q.limit(500);

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
          final total = rows.length > 0 ? rows.length : 1;
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

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _components.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final gridCols = constraints.maxWidth < 560 ? 4 : 8;
                    return Wrap(spacing: 10, runSpacing: 10,
                      children: _components.map((comp) {
                        final w = constraints.maxWidth * comp.colSpan / gridCols - 5;
                        return SizedBox(
                          width: w.clamp(120.0, constraints.maxWidth),
                          child: _buildCompCard(comp),
                        );
                      }).toList(),
                    );
                  }),
                ),
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

  Widget _buildCompCard(_CComponent comp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
          child: Row(children: [
            Icon(_compIcon(comp.type), size: 16, color: _color(_themes[comp.colorTheme])),
            const SizedBox(width: 8),
            Expanded(child: Text(comp.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
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
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _buildCompContent(comp),
        ),
      ]),
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
      final col = _color(_themes[comp.colorTheme]);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: col, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comp.title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: col)),
          Text('Last ${comp.datasource.daysBack}d',
              style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
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
      return SizedBox(
        height: _heights[comp.heightLevel],
        child: _ChartCard(chart: chartData, height: _heights[comp.heightLevel],
            colorOffset: _themes[comp.colorTheme]),
      );
    }

    // Table
    final keys = data.keys.toList();
    final vals = data.values.map((v) => v.toString()).toList();
    return _TableCard(table: {
      'columns': ['Category', 'Value'],
      'rows': List.generate(keys.length, (i) => [keys[i], vals[i]]),
    });
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

  @override
  void initState() { super.initState(); _titleCtrl = TextEditingController(text: widget.comp.title); }
  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

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

        // Layout
        _lbl(isAr ? 'العرض (من 8 أعمدة)' : 'Width (of 8 cols)'),
        Row(children: List.generate(8, (i) {
          final cs = i + 1;
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
              child: Center(child: Text('$cs', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        })),
        const SizedBox(height: 14),

        _lbl(isAr ? 'الارتفاع' : 'Height'),
        Row(children: List.generate(_heights.length, (i) {
          const labels = ['XS','S','M','L','XL','XXL'];
          final sel = comp.heightLevel == i;
          return Expanded(child: GestureDetector(
            onTap: () => upd(() => comp.heightLevel = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFf16936) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(labels[i], style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.grey[600]))),
            ),
          ));
        })),
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
