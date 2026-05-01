import 'package:flutter/material.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/main.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// Define app colors from main.dart
class AppColors {
  static const Color primary = Color(0xFFf16936); // Orange
  static const Color secondary = Color(0xFF135467); // Dark blue-green
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;
  static const Color onBackground = Color(0xFF135467);
  static const Color onSurface = Color(0xFF135467);
}

class DashboardMobile extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onNavigateToTickets;

  const DashboardMobile({
    super.key,
    required this.currentUser,
    required this.onNavigateToTickets,
  });

  @override
  State<DashboardMobile> createState() => _DashboardMobileState();
}

class _DashboardMobileState extends State<DashboardMobile>
    with AutomaticKeepAliveClientMixin {
  Map<String, int> _ticketCounts = {};
  List<Map<String, dynamic>> _recentTickets = [];
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Initialize data only once
  Future<void> _initializeData() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadTicketCounts(),
        _loadRecentTickets(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTicketCounts() async {
    try {
      final response = await supabase
          .from('tickets')
          .select('status')
          .neq('status', 'deleted');

      final counts = <String, int>{};
      for (final ticket in response) {
        final status = ticket['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      if (mounted) {
        setState(() => _ticketCounts = counts);
      }
    } catch (e) {
      debugPrint('Error loading ticket counts: $e');
    }
  }

  Future<void> _loadRecentTickets() async {
    try {
      final response = await supabase
          .from('tickets')
          .select('id, ticket_number, title, status, created_at, priority')
          .neq('status', 'deleted')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(
            () => _recentTickets = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading recent tickets: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
        return AppColors.secondary;
      case 'prefinished':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      case 'wrong_info':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return AppColors.primary;
      case 'medium':
        return AppColors.secondary;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.safeOf(context);

    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.loadingDashboard,
                style: TextStyle(
                  color: AppColors.onBackground.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  _buildWelcomeSection(isTablet),
                  SizedBox(height: isTablet ? 28 : 24),

                  // Quick stats section
                  _buildStatsSection(isTablet),
                  SizedBox(height: isTablet ? 28 : 24),

                  // Pie Chart section
                  _buildPieChartSection(isTablet),
                  SizedBox(height: isTablet ? 28 : 24),

                  // Recent tickets section
                  _buildRecentTicketsSection(isTablet),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 28 : 24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.dashboard_rounded,
                  color: AppColors.onPrimary,
                  size: isTablet ? 28 : 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 12,
                  vertical: isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.onPrimary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: isTablet ? 16 : 14,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.mobile,
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            l10n.welcomeBack,
            style: TextStyle(
              color: AppColors.onPrimary.withOpacity(0.8),
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.currentUser.fullName,
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: isTablet ? 30 : 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 14 : 12,
              vertical: isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.currentUser.userType.value
                  .replaceAll('_', ' ')
                  .toUpperCase(),
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: isTablet ? 13 : 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: AppColors.secondary,
                size: isTablet ? 22 : 20,
              ),
            ),
            SizedBox(width: isTablet ? 14 : 12),
            Text(
              l10n.ticketOverview,
              style: TextStyle(
                fontSize: isTablet ? 22 : 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 20 : 16),
        if (isTablet)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  l10n.pending,
                  _ticketCounts['pending'] ?? 0,
                  Colors.orange,
                  Icons.pending_actions_rounded,
                  isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  l10n.inProgress,
                  _ticketCounts['inprogress'] ?? 0,
                  AppColors.secondary,
                  Icons.work_outline_rounded,
                  isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  l10n.prefinished,
                  _ticketCounts['prefinished'] ?? 0,
                  Colors.purple,
                  Icons.timer_outlined,
                  isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  l10n.closed,
                  _ticketCounts['closed'] ?? 0,
                  Colors.green,
                  Icons.check_circle_outline_rounded,
                  isTablet,
                ),
              ),
            ],
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard(
                l10n.pending,
                _ticketCounts['pending'] ?? 0,
                Colors.orange,
                Icons.pending_actions_rounded,
                isTablet,
              ),
              _buildStatCard(
                l10n.inProgress,
                _ticketCounts['inprogress'] ?? 0,
                AppColors.secondary,
                Icons.work_outline_rounded,
                isTablet,
              ),
              _buildStatCard(
                l10n.prefinished,
                _ticketCounts['prefinished'] ?? 0,
                Colors.purple,
                Icons.timer_outlined,
                isTablet,
              ),
              _buildStatCard(
                l10n.closed,
                _ticketCounts['closed'] ?? 0,
                Colors.green,
                Icons.check_circle_outline_rounded,
                isTablet,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPieChartSection(bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);
    final totalTickets =
        _ticketCounts.values.fold(0, (sum, count) => sum + count);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: isTablet ? 22 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Text(
                l10n.ticketDistribution,
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 24 : 20),
          if (totalTickets > 0)
            SizedBox(
              height: isTablet ? 240 : 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: isTablet ? 45 : 35,
                  sections: _buildPieChartSections(),
                  borderData: FlBorderData(show: false),
                ),
              ),
            )
          else
            SizedBox(
              height: isTablet ? 240 : 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: isTablet ? 56 : 48,
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Text(
                      l10n.noTicketData,
                      style: TextStyle(
                        color: AppColors.onBackground.withOpacity(0.5),
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: isTablet ? 24 : 20),
          if (totalTickets > 0) _buildPieChartLegend(isTablet),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final l10n = AppLocalizations.safeOf(context);

    final List<Map<String, dynamic>> statusData = [
      {
        'status': 'pending',
        'label': l10n.pending,
        'color': Colors.orange,
        'count': _ticketCounts['pending'] ?? 0,
      },
      {
        'status': 'inprogress',
        'label': l10n.inProgress,
        'color': AppColors.secondary,
        'count': _ticketCounts['inprogress'] ?? 0,
      },
      {
        'status': 'prefinished',
        'label': l10n.prefinished,
        'color': Colors.purple,
        'count': _ticketCounts['prefinished'] ?? 0,
      },
      {
        'status': 'closed',
        'label': l10n.completed,
        'color': Colors.green,
        'count': _ticketCounts['closed'] ?? 0,
      },
    ];

    final totalTickets =
        statusData.fold(0, (sum, item) => sum + (item['count'] as int));
    if (totalTickets == 0) return [];

    return statusData.where((item) => item['count'] > 0).map((item) {
      final count = item['count'] as int;
      final percentage = (count / totalTickets * 100);

      return PieChartSectionData(
        color: item['color'] as Color,
        value: count.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildPieChartLegend(bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);

    final List<Map<String, dynamic>> statusData = [
      {
        'label': l10n.pending,
        'color': Colors.orange,
        'count': _ticketCounts['pending'] ?? 0,
      },
      {
        'label': l10n.inProgress,
        'color': AppColors.secondary,
        'count': _ticketCounts['inprogress'] ?? 0,
      },
      {
        'label': l10n.prefinished,
        'color': Colors.purple,
        'count': _ticketCounts['prefinished'] ?? 0,
      },
      {
        'label': l10n.completed,
        'color': Colors.green,
        'count': _ticketCounts['closed'] ?? 0,
      },
    ];

    return Wrap(
      spacing: isTablet ? 20 : 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: statusData.where((item) => item['count'] > 0).map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isTablet ? 14 : 12,
              height: isTablet ? 14 : 12,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isTablet ? 8 : 6),
            Text(
              '${item['label']}: ${item['count']}',
              style: TextStyle(
                fontSize: isTablet ? 13 : 11,
                color: AppColors.onBackground.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentTicketsSection(bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                    size: isTablet ? 22 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 14 : 12),
                Text(
                  l10n.recentTickets,
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackground,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: widget.onNavigateToTickets,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 18 : 16,
                    vertical: isTablet ? 10 : 8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewAll,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 15 : 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: isTablet ? 18 : 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 20 : 16),
        _recentTickets.isEmpty
            ? Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inbox_outlined,
                          color: AppColors.secondary.withOpacity(0.6),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noRecentTickets,
                        style: TextStyle(
                          color: AppColors.onBackground.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTickets.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ticket = _recentTickets[index];
                  return _buildRecentTicketCard(ticket, isTablet);
                },
              ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    Color color,
    IconData icon,
    bool isTablet,
  ) {
    // Reduced height for tablet
    final cardHeight = isTablet ? 90.0 : null;

    return Container(
      height: cardHeight,
      padding: EdgeInsets.all(isTablet ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isTablet ? 16 : 18),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 5 : 6,
                  vertical: isTablet ? 2 : 3,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 9 : 10,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: isTablet ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              SizedBox(height: isTablet ? 3 : 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 11 : 12,
                  color: AppColors.onBackground.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTicketCard(Map<String, dynamic> ticket, bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);
    return InkWell(
      onTap: widget.onNavigateToTickets,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 18 : 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: isTablet ? 55 : 50,
              decoration: BoxDecoration(
                color: _getStatusColor(ticket['status']),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: isTablet ? 18 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 10 : 8,
                          vertical: isTablet ? 5 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket['ticket_number'],
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM dd')
                            .format(DateTime.parse(ticket['created_at'])),
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          color: AppColors.onBackground.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 10 : 8),
                  Text(
                    ticket['title'],
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isTablet ? 10 : 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 10 : 8,
                          vertical: isTablet ? 4 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket['status'])
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusColor(ticket['status'])
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          //                           pending('pending'),
                          // inprogress('inprogress'),
                          // prefinished('prefinished'),
                          // closed('closed'),
                          // deleted('deleted'),
                          // wrongInfo('wrong_info');
                          ticket['status'] == 'pending'
                              ? l10n.pending
                              : ticket['status'] == 'inprogress'
                                  ? l10n.inProgress
                                  : ticket['status'] == 'prefinished'
                                      ? l10n.prefinished
                                      : ticket['status'] == 'closed'
                                          ? l10n.closed
                                          : ticket['status'] == 'deleted'
                                              ? l10n.deleted
                                              : l10n.wrongInfo,
                          style: TextStyle(
                            fontSize: isTablet ? 11 : 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(ticket['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: isTablet ? 10 : 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onBackground.withOpacity(0.4),
              size: isTablet ? 22 : 20,
            ),
          ],
        ),
      ),
    );
  }
}
