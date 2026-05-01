import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';

const _functionUrl =
    'https://wxibjgzemtfzkattbpue.supabase.co/functions/v1/analyze-tickets';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4aWJqZ3plbXRmemthdHRicHVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5MTQwMTIsImV4cCI6MjA3MzQ5MDAxMn0.OUXZsVloijKMgFbHtAKIaT7e-c-rAWNKA2Mak1D7SJM';

const _palette = [
  Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFFF59E0B),
  Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFF8B5CF6),
  Color(0xFF14B8A6), Color(0xFFEF4444),
];

class AiInsightsView extends StatefulWidget {
  final UserModel currentUser;
  const AiInsightsView({super.key, required this.currentUser});
  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  String? _placeFilter;
  String? _departmentFilter;
  List<PlaceModel> _places = [];
  List<DepartmentModel> _departments = [];
  final Set<String> _savedTitles = {};

  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadFilters();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadFilters() async {
    try {
      final p = await supabase.from('places').select();
      final d = await supabase.from('departments').select();
      setState(() {
        _places = p.map<PlaceModel>((j) => PlaceModel.fromJson(j)).toList();
        _departments = d.map<DepartmentModel>((j) => DepartmentModel.fromJson(j)).toList();
      });
    } catch (_) {}
  }

  Future<void> _analyze() async {
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      var q = supabase.from('tickets').select(
        'id,title,description,problem_title_id,place_id,target_department_id,status,created_at,updated_at,'
        'places(name),departments:target_department_id(name),problem_titles:problem_title_id(title)',
      );
      if (_placeFilter != null) q = q.eq('place_id', _placeFilter!);
      if (_departmentFilter != null) q = q.eq('target_department_id', _departmentFilter!);
      final rows = await q.limit(200);

      final tickets = rows.map((r) => {
        'id': r['id'], 'title': r['title'] ?? '',
        'description': r['description'] ?? '',
        'problem_title': r['problem_titles']?['title'],
        'place_name': r['places']?['name'],
        'department_name': r['departments']?['name'],
        'status': r['status'] ?? '', 'created_at': r['created_at'] ?? '',
      }).toList();

      final res = await http.post(Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_anonKey'},
        body: jsonEncode({
          'tickets': tickets, 'language': lang,
          if (_placeFilter != null) 'place_filter': _places.firstWhere((p) => p.id == _placeFilter).name,
          if (_departmentFilter != null) 'department_filter': _departments.firstWhere((d) => d.id == _departmentFilter).name,
        }),
      );

      if (res.statusCode == 200) {
        setState(() { _result = jsonDecode(res.body); });
        _animCtrl.forward(from: 0);
      } else {
        setState(() { _error = (jsonDecode(res.body)['error'] ?? 'Error') as String; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Column(children: [
      _filterBar(l10n),
      Expanded(child: _loading ? _stateLoading() : _error != null ? _stateError() : _result == null ? _stateEmpty(l10n) : _results(l10n)),
    ]);
  }

  // ── Filter bar ──────────────────────────────────────────────────────────────

  Widget _filterBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(child: _dropdown(l10n.place, _placeFilter,
          [DropdownMenuItem(value: null, child: Text(l10n.all, style: const TextStyle(fontSize: 12))),
           ..._places.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))],
          (v) => setState(() => _placeFilter = v))),
        const SizedBox(width: 6),
        Expanded(child: _dropdown(l10n.department, _departmentFilter,
          [DropdownMenuItem(value: null, child: Text(l10n.all, style: const TextStyle(fontSize: 12))),
           ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))],
          (v) => setState(() => _departmentFilter = v))),
        const SizedBox(width: 6),
        SizedBox(height: 38,
          child: ElevatedButton(
            onPressed: _loading ? null : _analyze,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome, size: 18),
          )),
      ]),
    );
  }

  Widget _dropdown(String label, String? val, List<DropdownMenuItem<String>> items, ValueChanged<String?> cb) {
    return DropdownButtonFormField<String>(
      value: val, isExpanded: true,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        isDense: true),
      items: items, onChanged: cb,
    );
  }

  // ── States ──────────────────────────────────────────────────────────────────

  Widget _stateLoading() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: AppColors.primary),
    const SizedBox(height: 10),
    Text('Analyzing...', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
  ]));

  Widget _stateEmpty(AppLocalizations l10n) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), shape: BoxShape.circle),
      child: Icon(Icons.auto_awesome, size: 36, color: AppColors.primary.withValues(alpha: 0.4))),
    const SizedBox(height: 10),
    Text(l10n.aiInsightsHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
  ]));

  Widget _stateError() => Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 36, color: Colors.red),
    const SizedBox(height: 8),
    Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
    const SizedBox(height: 10),
    TextButton.icon(onPressed: _analyze, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
  ])));

  // ── Results ─────────────────────────────────────────────────────────────────

  Widget _results(AppLocalizations l10n) {
    final r = _result!;
    final places = (r['top_problem_places'] as List?)?.cast<Map>() ?? [];
    final issues = (r['recurring_issues'] as List?)?.cast<Map>() ?? [];
    final causes = (r['root_causes'] as List?)?.cast<Map>() ?? [];
    final replacements = (r['replacement_recommendations'] as List?)?.cast<Map>() ?? [];
    final prevention = (r['prevention_suggestions'] as List?)?.cast<String>() ?? [];
    final titles = (r['smart_title_suggestions'] as List?)?.cast<String>() ?? [];

    return ListView(padding: const EdgeInsets.fromLTRB(10, 10, 10, 20), children: [

      // ── 1. AI Summary ───────────────────────────────────────────────────────
      if (r['summary'] != null) ...[
        _sectionLabel('✦  ${l10n.aiSummary}'),
        _summaryCard(r['summary'] as String),
      ],

      // ── 2. Quick stats row ──────────────────────────────────────────────────
      _statsRow(places.length, issues.length, replacements.length, l10n),

      // ── 3. Top problem places ───────────────────────────────────────────────
      if (places.isNotEmpty) ...[
        _sectionLabel('📍  ${l10n.topProblemPlaces}'),
        _card(_placesContent(places)),
      ],

      // ── 4. Recurring issues ─────────────────────────────────────────────────
      if (issues.isNotEmpty) ...[
        _sectionLabel('🔄  ${l10n.recurringIssues}'),
        _card(_issuesContent(issues)),
      ],

      // ── 5. Root causes ──────────────────────────────────────────────────────
      if (causes.isNotEmpty) ...[
        _sectionLabel('🔍  ${l10n.rootCauses}'),
        _card(_causesContent(causes)),
      ],

      // ── 6. Replacement recommendations ─────────────────────────────────────
      if (replacements.isNotEmpty) ...[
        _sectionLabel('🔧  ${l10n.replacementRecommendations}'),
        _card(_replacementsContent(replacements)),
      ],

      // ── 7. Prevention suggestions ───────────────────────────────────────────
      if (prevention.isNotEmpty) ...[
        _sectionLabel('🛡️  ${l10n.preventionSuggestions}'),
        _card(_preventionContent(prevention)),
      ],

      // ── 8. Smart title suggestions ──────────────────────────────────────────
      if (titles.isNotEmpty) ...[
        _sectionLabel('💡  ${l10n.smartTitleSuggestions}'),
        _card(_titlesContent(l10n, titles)),
      ],
    ]);
  }

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
  );

  // ── Card shell ──────────────────────────────────────────────────────────────

  Widget _card(Widget child) => Container(
    margin: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
  );

  // ── Summary card ────────────────────────────────────────────────────────────

  Widget _summaryCard(String text) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.primary, Color.lerp(AppColors.primary, Colors.indigo, 0.5)!],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.6)),
  );

  // ── Stats row ───────────────────────────────────────────────────────────────

  Widget _statsRow(int places, int issues, int recs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        _statBox('$places', l10n.topProblemPlaces, const Color(0xFFF59E0B)),
        const SizedBox(width: 6),
        _statBox('$issues', l10n.recurringIssues, const Color(0xFFEF4444)),
        const SizedBox(width: 6),
        _statBox('$recs', l10n.replacementRecommendations, const Color(0xFF3B82F6)),
      ]),
    );
  }

  Widget _statBox(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), height: 1.2), maxLines: 2),
      ]),
    ),
  );

  // ── Places content ──────────────────────────────────────────────────────────

  Widget _placesContent(List<Map> places) {
    final maxCount = places.fold<double>(1, (m, p) => max(m, (p['count'] as num).toDouble()));
    return Column(children: places.asMap().entries.map((e) {
      final i = e.key; final p = e.value;
      final count = (p['count'] as num).toDouble();
      final ratio = count / maxCount;
      final color = _palette[i % _palette.length];
      final issues = (p['common_issues'] as List?)?.cast<String>() ?? [];
      return Container(
        decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(p['place'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('${p['count']} tickets', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          AnimatedBuilder(animation: _anim, builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio * _anim.value, minHeight: 5,
              backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(color)),
          )),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 3, children: issues.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
            )).toList()),
          ],
        ]),
      );
    }).toList());
  }

  // ── Issues content ──────────────────────────────────────────────────────────

  Widget _issuesContent(List<Map> issues) {
    final maxFreq = issues.fold<double>(1, (m, p) => max(m, (p['frequency'] as num).toDouble()));
    return Column(children: issues.asMap().entries.map((e) {
      final i = e.key; final item = e.value;
      final freq = (item['frequency'] as num).toDouble();
      final ratio = freq / maxFreq;
      final color = _palette[i % _palette.length];
      final places = (item['affected_places'] as List?)?.cast<String>() ?? [];
      return Container(
        decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Rank circle
          Container(width: 22, height: 22,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item['issue'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text('×${item['frequency']}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 5),
            AnimatedBuilder(animation: _anim, builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ratio * _anim.value, minHeight: 4,
                backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(color)),
            )),
            if (places.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${places.join('  ·  ')}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ])),
        ]),
      );
    }).toList());
  }

  // ── Causes content ──────────────────────────────────────────────────────────

  Widget _causesContent(List<Map> causes) => Column(
    children: causes.asMap().entries.map((e) {
      final i = e.key; final item = e.value;
      final evidence = (item['evidence'] as List?)?.cast<String>() ?? [];
      return Container(
        decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 20, height: 20,
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['cause'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ...evidence.map((ev) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('→ ', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                Expanded(child: Text(ev, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4))),
              ]),
            )),
          ])),
        ]),
      );
    }).toList(),
  );

  // ── Replacements content ────────────────────────────────────────────────────

  Widget _replacementsContent(List<Map> reps) {
    const pc = {'high': Color(0xFFEF4444), 'medium': Color(0xFFF59E0B), 'low': Color(0xFF10B981)};
    final high = reps.where((r) => r['priority'] == 'high').toList();
    final med = reps.where((r) => r['priority'] == 'medium').toList();
    final low = reps.where((r) => r['priority'] == 'low').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Priority summary bar
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          if (high.isNotEmpty) _priorityChip('HIGH ${high.length}', pc['high']!),
          if (high.isNotEmpty && (med.isNotEmpty || low.isNotEmpty)) const SizedBox(width: 6),
          if (med.isNotEmpty) _priorityChip('MED ${med.length}', pc['medium']!),
          if (med.isNotEmpty && low.isNotEmpty) const SizedBox(width: 6),
          if (low.isNotEmpty) _priorityChip('LOW ${low.length}', pc['low']!),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      ...[...high, ...med, ...low].asMap().entries.map((e) {
        final i = e.key; final item = e.value;
        final p = item['priority'] as String? ?? 'low';
        final color = pc[p] ?? Colors.grey;
        return Container(
          decoration: i > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(item['item'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(p.toUpperCase(), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                    ]),
                    if (item['reason'] != null && (item['reason'] as String).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item['reason'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4)),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _priorityChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
  );

  // ── Prevention content ──────────────────────────────────────────────────────

  Widget _preventionContent(List<String> items) => Column(
    children: items.asMap().entries.map((e) => Container(
      decoration: e.key > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 20, height: 20,
          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12, height: 1.4))),
      ]),
    )).toList(),
  );

  // ── Titles content ──────────────────────────────────────────────────────────

  Widget _titlesContent(AppLocalizations l10n, List<String> titles) => Column(
    children: titles.asMap().entries.map((e) {
      final title = e.value;
      final saved = _savedTitles.contains(title);
      return Container(
        decoration: e.key > 0 ? BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))) : null,
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(children: [
          Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12, height: 1.3))),
          saved
            ? const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)))
            : IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
                onPressed: () => _saveTitle(l10n, title),
              ),
        ]),
      );
    }).toList(),
  );

  // ── Save title ──────────────────────────────────────────────────────────────

  Future<void> _saveTitle(AppLocalizations l10n, String title) async {
    String? deptId = _departmentFilter;
    if (deptId == null) {
      deptId = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String? sel;
          return StatefulBuilder(builder: (ctx, ss) => AlertDialog(
            title: Text(l10n.selectDepartment, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true,
              children: _departments.map((d) {
                final isSel = sel == d.id;
                return InkWell(onTap: () => ss(() => sel = d.id),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18, color: isSel ? AppColors.primary : Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 13))),
                    ])));
              }).toList())),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              ElevatedButton(
                onPressed: sel == null ? null : () => Navigator.pop(ctx, sel),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
                child: Text(l10n.save)),
            ],
          ));
        },
      );
    }
    if (deptId == null) return;
    try {
      await supabase.from('problem_titles').insert({'title': title, 'department_id': deptId, 'created_by': widget.currentUser.id});
      setState(() => _savedTitles.add(title));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedSuccessfully), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }
}
