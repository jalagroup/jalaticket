import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import 'reminder_models.dart';
import 'reminder_service.dart';
import 'reminder_editor_screen.dart';

class SmartRemindersScreen extends StatefulWidget {
  final UserModel currentUser;

  const SmartRemindersScreen({super.key, required this.currentUser});

  @override
  State<SmartRemindersScreen> createState() => _SmartRemindersScreenState();
}

class _SmartRemindersScreenState extends State<SmartRemindersScreen> {
  List<SmartReminder> _reminders = [];
  bool _loading = true;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ReminderService.getAll();
    if (mounted) setState(() { _reminders = list; _loading = false; });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return _isAr ? 'غير محدد' : 'Not set';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('HH:mm').format(dt);
    if (day == today) return '${_isAr ? "اليوم" : "Today"} $timeStr';
    if (day == today.add(const Duration(days: 1))) return '${_isAr ? "غداً" : "Tomorrow"} $timeStr';
    return DateFormat(_isAr ? 'd MMM' : 'MMM d').format(dt);
  }

  Future<void> _toggleActive(SmartReminder r) async {
    await ReminderService.toggle(r.id, !r.isActive);
    await _load();
  }

  Future<void> _runNow(SmartReminder r) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isAr ? 'جارٍ التشغيل...' : 'Running reminder...')),
    );
    try {
      await ReminderService.runNow(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isAr ? 'تم التشغيل بنجاح' : 'Reminder triggered successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    await _load();
  }

  Future<void> _delete(SmartReminder r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAr ? 'حذف التذكير' : 'Delete Reminder'),
        content: Text(_isAr
            ? 'هل أنت متأكد من حذف "${r.title}"؟'
            : 'Delete "${r.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ReminderService.delete(r.id);
      await _load();
    }
  }

  void _showRunsSheet(SmartReminder r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RunsBottomSheet(reminder: r, isAr: _isAr),
    );
  }

  Future<void> _openEditor({SmartReminder? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderEditorScreen(
          currentUser: widget.currentUser,
          existing: existing,
        ),
      ),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAr ? 'التذكيرات الذكية' : 'Smart Reminders',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.secondary,
              ),
            ),
            Text(
              _isAr
                  ? 'إشعارات آلية من بياناتك'
                  : 'Automated notifications from your data',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _reminders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _reminders.length,
                      itemBuilder: (ctx, i) => _buildCard(_reminders[i]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                _isAr ? 'لا توجد تذكيرات بعد' : 'No reminders yet',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                _isAr
                    ? 'أنشئ تذكيراً ذكياً لإرسال إشعارات آلية'
                    : 'Create a smart reminder to send automated notifications',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: Text(_isAr ? 'إنشاء أول تذكير' : 'Create your first reminder'),
                onPressed: () => _openEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(SmartReminder r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: r.isActive,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) => _toggleActive(r),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openEditor(existing: r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.secondary)),
                        const SizedBox(height: 2),
                        Text(r.scheduleLabel,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '${r.runCount} ${_isAr ? "تشغيل" : "run(s)"}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                _StatusChip(isActive: r.isActive, isAr: _isAr),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit': await _openEditor(existing: r); break;
                      case 'run': await _runNow(r); break;
                      case 'runs': _showRunsSheet(r); break;
                      case 'delete': await _delete(r); break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(_isAr ? 'تعديل' : 'Edit')),
                    PopupMenuItem(value: 'run', child: Text(_isAr ? 'تشغيل الآن' : 'Run Now')),
                    PopupMenuItem(value: 'runs', child: Text(_isAr ? 'عرض التشغيلات' : 'View Runs')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(_isAr ? 'حذف' : 'Delete',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                _InfoPill(
                  icon: Icons.history_rounded,
                  label: '${_isAr ? "آخر تشغيل" : "Last"}: ${_formatDateTime(r.lastRunAt)}',
                ),
                const SizedBox(width: 8),
                _InfoPill(
                  icon: Icons.schedule_rounded,
                  label: '${_isAr ? "التالي" : "Next"}: ${_formatDateTime(r.nextRunAt)}',
                  highlight: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final bool isAr;
  const _StatusChip({required this.isActive, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF22C55E) : Colors.grey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? (isAr ? 'نشط' : 'Active') : (isAr ? 'متوقف' : 'Inactive'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF16A34A) : Colors.grey[600],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoPill({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: highlight ? AppColors.primary : Colors.grey),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? AppColors.primary : Colors.grey[600],
            )),
      ],
    );
  }
}

class _RunsBottomSheet extends StatefulWidget {
  final SmartReminder reminder;
  final bool isAr;
  const _RunsBottomSheet({required this.reminder, required this.isAr});

  @override
  State<_RunsBottomSheet> createState() => _RunsBottomSheetState();
}

class _RunsBottomSheetState extends State<_RunsBottomSheet> {
  List<ReminderRun> _runs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final runs = await ReminderService.getRuns(widget.reminder.id);
    if (mounted) setState(() { _runs = runs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, sc) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  widget.isAr
                      ? 'تشغيلات: ${widget.reminder.title}'
                      : 'Runs: ${widget.reminder.title}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.secondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _runs.isEmpty
                    ? Center(
                        child: Text(widget.isAr ? 'لا توجد تشغيلات بعد' : 'No runs yet',
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _runs.length,
                        itemBuilder: (_, i) => _RunTile(run: _runs[i], isAr: widget.isAr),
                      ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final ReminderRun run;
  final bool isAr;
  const _RunTile({required this.run, required this.isAr});

  IconData get _icon => switch (run.status) {
    'success' => Icons.check_circle_rounded,
    'failed' => Icons.cancel_rounded,
    'skipped' => Icons.skip_next_rounded,
    _ => Icons.timelapse_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(_icon, color: run.statusColor, size: 22),
              Container(width: 2, height: 40, color: Colors.grey[200]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, HH:mm').format(run.startedAt.toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${isAr ? "سجلات" : "Records"}: ${run.recordsFetched}  •  '
                  '${isAr ? "إشعارات" : "Notifications"}: ${run.notificationsSent}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (run.errorMessage != null)
                  Text(run.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
