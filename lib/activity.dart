import 'package:flutter/material.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:jalasupport/l10n/app_localizations.dart';

class ActivityLogsView extends StatefulWidget {
  final UserModel currentUser;

  const ActivityLogsView({super.key, required this.currentUser});

  @override
  State<ActivityLogsView> createState() => _ActivityLogsViewState();
}

class _ActivityLogsViewState extends State<ActivityLogsView> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _actionFilter = 'all';
  int _limit = 200;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('activity_logs')
          .select('*, users(full_name)')
          .order('created_at', ascending: false)
          .limit(_limit);
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error loading logs: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilters() {
    _filtered = _logs.where((log) {
      final action = (log['action'] ?? '').toString().toUpperCase();
      final table = (log['table_name'] ?? '').toString();
      final user = (log['users']?['full_name'] ?? '').toString();
      final matchesSearch = _searchQuery.isEmpty ||
          action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          table.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesAction =
          _actionFilter == 'all' || action == _actionFilter.toUpperCase();
      return matchesSearch && matchesAction;
    }).toList();
  }

  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT': return const Color(0xFF22C55E);
      case 'UPDATE': return const Color(0xFFF59E0B);
      case 'DELETE': return const Color(0xFFEF4444);
      case 'SELECT': return const Color(0xFF3B82F6);
      case 'LOGIN':  return const Color(0xFF8B5CF6);
      case 'LOGOUT': return const Color(0xFF6B7280);
      default:       return const Color(0xFF6B7280);
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      case 'SELECT': return Icons.search;
      case 'LOGIN':  return Icons.login;
      case 'LOGOUT': return Icons.logout;
      default:       return Icons.circle_outlined;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  /// Returns list of changed fields: {field, oldValue, newValue}
  List<Map<String, String>> _getChanges(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString().toUpperCase();
    final oldData = log['old_data'];
    final newData = log['new_data'];

    if (action == 'UPDATE' && oldData is Map && newData is Map) {
      final changes = <Map<String, String>>[];
      for (final key in newData.keys) {
        if (key == 'updated_at') continue;
        final oldVal = oldData[key]?.toString() ?? '';
        final newVal = newData[key]?.toString() ?? '';
        if (oldVal != newVal) {
          changes.add({'field': key, 'old': oldVal, 'new': newVal});
        }
      }
      return changes;
    }
    return [];
  }

  /// Returns key fields for INSERT or DELETE
  List<Map<String, String>> _getKeyFields(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString().toUpperCase();
    final data = action == 'INSERT' ? log['new_data'] : log['old_data'];
    if (data is! Map) return [];

    final skipKeys = {'id', 'created_at', 'updated_at', 'auth_id', 'password'};
    final result = <Map<String, String>>[];
    for (final key in data.keys) {
      if (skipKeys.contains(key)) continue;
      final val = data[key]?.toString() ?? '';
      if (val.isNotEmpty) {
        result.add({'field': key, 'value': val});
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  String _formatFieldName(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  String _truncate(String val, [int max = 40]) {
    return val.length > max ? '${val.substring(0, max)}…' : val;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history, color: Colors.indigo, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.activityLogs,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_filtered.length} / ${_logs.length} ${l10n.entries}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadLogs,
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: l10n.refresh,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (v) =>
                          setState(() { _searchQuery = v; _applyFilters(); }),
                      decoration: InputDecoration(
                        hintText: l10n.searchActionTableUser,
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.indigo, width: 1.2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _actionFilter,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.indigo, width: 1.2)),
                      ),
                      items: [
                        DropdownMenuItem(value: 'all',    child: Text(l10n.allActions, style: const TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'insert', child: Text('INSERT', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'update', child: Text('UPDATE', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'delete', child: Text('DELETE', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'login',  child: Text('LOGIN',  style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'logout', child: Text('LOGOUT', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) =>
                          setState(() { _actionFilter = v!; _applyFilters(); }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Log list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(l10n.noLogsFound,
                              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount:
                          _filtered.length + (_filtered.length < _logs.length ? 0 : 1),
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        if (index == _filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton.icon(
                              onPressed: () { _limit += 200; _loadLogs(); },
                              icon: const Icon(Icons.expand_more, size: 16),
                              label: Text(l10n.loadMore,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          );
                        }

                        final log = _filtered[index];
                        final action = (log['action'] ?? '').toString();
                        final table = (log['table_name'] ?? '').toString();
                        final userName =
                            log['users']?['full_name'] ?? l10n.system;
                        final createdAt =
                            DateTime.tryParse(log['created_at'] ?? '');
                        final color = _actionColor(action);
                        final icon = _actionIcon(action);
                        final recordId = log['record_id']?.toString();
                        final isExpanded = _expanded.contains(index);

                        final changes = _getChanges(log);
                        final keyFields = changes.isEmpty ? _getKeyFields(log) : [];
                        final hasDetails = changes.isNotEmpty || keyFields.isNotEmpty;

                        return GestureDetector(
                          onTap: hasDetails
                              ? () => setState(() {
                                    if (isExpanded) {
                                      _expanded.remove(index);
                                    } else {
                                      _expanded.add(index);
                                    }
                                  })
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isExpanded
                                    ? color.withOpacity(0.3)
                                    : Colors.grey.shade100,
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Action icon badge
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(icon, size: 15, color: color),
                                      ),
                                      const SizedBox(width: 10),
                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: color.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    action.toUpperCase(),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: color,
                                                        letterSpacing: 0.3),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    table.replaceAll('_', ' '),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (hasDetails)
                                                  Icon(
                                                    isExpanded
                                                        ? Icons.keyboard_arrow_up
                                                        : Icons.keyboard_arrow_down,
                                                    size: 14,
                                                    color: Colors.grey[400],
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline,
                                                    size: 11, color: Colors.grey[400]),
                                                const SizedBox(width: 3),
                                                Text(userName,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600])),
                                                if (recordId != null) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.tag,
                                                      size: 10,
                                                      color: Colors.grey[400]),
                                                  Text(
                                                    recordId.length > 8
                                                        ? recordId.substring(0, 8)
                                                        : recordId,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[400],
                                                        fontFamily: 'monospace'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Time
                                      if (createdAt != null)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _relativeTime(createdAt),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[400]),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat('HH:mm').format(createdAt),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[400]),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),

                                // Expanded details
                                if (isExpanded && hasDetails)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.04),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Divider(height: 1, color: color.withOpacity(0.15)),
                                        const SizedBox(height: 6),
                                        if (changes.isNotEmpty)
                                          ...changes.map((c) => Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                        _formatFieldName(c['field']!),
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey[600],
                                                            fontWeight: FontWeight.w500),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Wrap(
                                                        spacing: 4,
                                                        runSpacing: 2,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.withOpacity(0.1),
                                                              borderRadius:
                                                                  BorderRadius.circular(3),
                                                            ),
                                                            child: Text(
                                                              _truncate(c['old']!.isEmpty
                                                                  ? '—'
                                                                  : c['old']!),
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.red,
                                                                  decoration: TextDecoration.lineThrough),
                                                            ),
                                                          ),
                                                          const Icon(Icons.arrow_forward,
                                                              size: 10,
                                                              color: Colors.grey),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.withOpacity(0.1),
                                                              borderRadius:
                                                                  BorderRadius.circular(3),
                                                            ),
                                                            child: Text(
                                                              _truncate(c['new']!.isEmpty
                                                                  ? '—'
                                                                  : c['new']!),
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.green),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ))
                                        else
                                          ...keyFields.map((f) => Padding(
                                                padding: const EdgeInsets.only(bottom: 3),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                        _formatFieldName(f['field']!),
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey[600],
                                                            fontWeight: FontWeight.w500),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        _truncate(f['value']!),
                                                        style: const TextStyle(fontSize: 10),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class ReportsView extends StatefulWidget {
  final UserModel currentUser;

  const ReportsView({super.key, required this.currentUser});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Reports feature will be implemented here'),
      ),
    );
  }
}
