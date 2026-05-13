import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:photo_view/photo_view.dart';

class ProblemReportsAdminScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProblemReportsAdminScreen({super.key, required this.currentUser});

  @override
  State<ProblemReportsAdminScreen> createState() =>
      _ProblemReportsAdminScreenState();
}

class _ProblemReportsAdminScreenState
    extends State<ProblemReportsAdminScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  static const _statusColors = {
    'new': Color(0xFFe53935),
    'reviewing': Color(0xFFf57c00),
    'resolved': Color(0xFF43a047),
  };

  static const _statusLabels = {
    'new': 'New',
    'reviewing': 'Reviewing',
    'resolved': 'Resolved',
  };

  static const _statusLabelsAr = {
    'new': 'جديد',
    'reviewing': 'قيد المراجعة',
    'resolved': 'تم الحل',
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      var q = supabase
          .from('problem_reports')
          .select()
          .order('created_at', ascending: false);

      final data = await q;
      if (mounted) setState(() => _reports = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String reportId, String newStatus,
      {String? adminNotes}) async {
    try {
      final update = <String, dynamic>{'status': newStatus};
      if (adminNotes != null) update['admin_notes'] = adminNotes;
      await supabase.from('problem_reports').update(update).eq('id', reportId);
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_filterStatus == 'all') return _reports;
    return _reports.where((r) => r['status'] == _filterStatus).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showDetailDialog(Map<String, dynamic> report) {
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final notesController =
        TextEditingController(text: report['admin_notes'] ?? '');
    String selectedStatus = report['status'] ?? 'new';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRtl ? 'تفاصيل التقرير' : 'Report Details',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info
                        _infoRow(Icons.person, 'From', report['user_name']),
                        const SizedBox(height: 8),
                        _infoRow(Icons.email, 'Email', report['user_email']),
                        const SizedBox(height: 8),
                        _infoRow(Icons.access_time, 'Submitted',
                            _formatDate(report['created_at'])),
                        const SizedBox(height: 16),

                        // Description
                        Text(isRtl ? 'الوصف' : 'Description',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(report['description'] ?? '',
                              style: const TextStyle(
                                  fontSize: 14, height: 1.5)),
                        ),

                        // Screenshot
                        if (report['image_url'] != null) ...[
                          const SizedBox(height: 16),
                          Text(isRtl ? 'الصورة المرفقة' : 'Screenshot',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showImageFullscreen(
                                ctx, report['image_url']),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                report['image_url'],
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 80,
                                  color: Colors.grey[100],
                                  child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey)),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showImageFullscreen(ctx, report['image_url']),
                              icon: const Icon(Icons.open_in_full, size: 16),
                              label: Text(isRtl ? 'عرض كامل' : 'Full view'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary),
                            ),
                          ),
                        ],

                        const Divider(height: 28),

                        // Status selector
                        Text(isRtl ? 'تغيير الحالة' : 'Change Status',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          items: ['new', 'reviewing', 'resolved'].map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _statusColors[s],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isRtl
                                      ? (_statusLabelsAr[s] ?? s)
                                      : (_statusLabels[s] ?? s)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedStatus = v);
                          },
                        ),

                        const SizedBox(height: 12),

                        // Admin notes
                        Text(isRtl ? 'ملاحظات المشرف' : 'Admin Notes',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: isRtl
                                ? 'أضف ملاحظاتك هنا...'
                                : 'Add your notes here...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(
                          report['id'],
                          selectedStatus,
                          adminNotes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(isRtl ? 'حفظ التغييرات' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageFullscreen(BuildContext ctx, String url) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Screenshot'),
          ),
          body: PhotoView(imageProvider: NetworkImage(url)),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(
          child: Text(value ?? '-',
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = _filteredReports;

    final statusFilters = ['all', 'new', 'reviewing', 'resolved'];
    final filterLabels = {
      'all': isRtl ? 'الكل' : 'All',
      'new': isRtl ? 'جديد' : 'New',
      'reviewing': isRtl ? 'قيد المراجعة' : 'Reviewing',
      'resolved': isRtl ? 'تم الحل' : 'Resolved',
    };

    // Count badges per status
    final counts = {
      'all': _reports.length,
      'new': _reports.where((r) => r['status'] == 'new').length,
      'reviewing': _reports.where((r) => r['status'] == 'reviewing').length,
      'resolved': _reports.where((r) => r['status'] == 'resolved').length,
    };

    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...statusFilters.map((s) {
                  final isSelected = _filterStatus == s;
                  final color = s == 'all'
                      ? AppColors.primary
                      : (_statusColors[s] ?? AppColors.primary);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(filterLabels[s] ?? s),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${counts[s] ?? 0}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onSelected: (_) =>
                          setState(() => _filterStatus = s),
                      selectedColor: color,
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      checkmarkColor: Colors.white,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReports,
                  tooltip: 'Refresh',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            isRtl ? 'لا توجد تقارير' : 'No reports found',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _buildReportCard(filtered[i], isRtl),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isRtl) {
    final status = report['status'] ?? 'new';
    final color = _statusColors[status] ?? AppColors.primary;
    final hasImage = report['image_url'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        onTap: () => _showDetailDialog(report),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isRtl
                              ? (_statusLabelsAr[status] ?? status)
                              : (_statusLabels[status] ?? status),
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.image, size: 16, color: Colors.grey[400]),
                    ),
                  Text(
                    _formatDate(report['created_at']),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // User name
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (report['user_name'] ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['user_name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          report['user_email'] ?? '',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Description preview
              Text(
                report['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.4),
              ),

              if (report['admin_notes'] != null &&
                  (report['admin_notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.note_alt_outlined,
                        size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report['admin_notes'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isRtl ? 'اضغط للتفاصيل ←' : 'Tap for details →',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
