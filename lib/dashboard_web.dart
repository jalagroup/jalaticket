import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/main.dart';
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

class DashboardWeb extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onNavigateToTickets;

  const DashboardWeb({
    super.key,
    required this.currentUser,
    required this.onNavigateToTickets,
  });

  @override
  State<DashboardWeb> createState() => _DashboardWebState();
}

class _DashboardWebState extends State<DashboardWeb>
    with AutomaticKeepAliveClientMixin {
  Map<String, int> _ticketCounts = {};
  List<Map<String, dynamic>> _inProgressTickets = [];
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
        _loadInProgressTickets(),
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

  Future<void> _loadInProgressTickets() async {
    try {
      final response = await supabase
          .from('tickets')
          .select('id, ticket_number, title, status, created_at, priority')
          .eq('status', 'inprogress')
          .order('created_at', ascending: false)
          .limit(8);

      if (mounted) {
        setState(() =>
            _inProgressTickets = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading in-progress tickets: $e');
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.loadingDashboard,
                style: TextStyle(
                  color: AppColors.onBackground.withOpacity(0.7),
                  fontSize: 16,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 1200;
          final isMediumScreen = constraints.maxWidth > 768;
          final isSmallScreen = constraints.maxWidth <= 768;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEnhancedWelcomeSection(isSmallScreen),
                SizedBox(height: isSmallScreen ? 16 : 20),
                _buildResponsiveStatsSection(isSmallScreen, isMediumScreen),
                SizedBox(height: isSmallScreen ? 16 : 20),
                if (isSmallScreen)
                  _buildMobileContent()
                else
                  _buildContentGrid(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileWelcome() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 12,
                    color: AppColors.onPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.mobile,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.welcomeBack,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.onPrimary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.currentUser.fullName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.currentUser.userType.value
                .replaceAll('_', ' ')
                .toUpperCase(),
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveStatsSection(bool isSmallScreen, bool isMediumScreen) {
    final l10n = AppLocalizations.safeOf(context);

    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMobileStyleStatCard(
                  l10n.pending,
                  _ticketCounts['pending'] ?? 0,
                  Colors.orange,
                  Icons.pending_actions_rounded,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileStyleStatCard(
                  l10n.inProgress,
                  _ticketCounts['inprogress'] ?? 0,
                  AppColors.secondary,
                  Icons.work_outline_rounded,
                  isSmallScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMobileStyleStatCard(
                  l10n.prefinished,
                  _ticketCounts['prefinished'] ?? 0,
                  Colors.purple,
                  Icons.timer_outlined,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileStyleStatCard(
                  l10n.completed,
                  _ticketCounts['closed'] ?? 0,
                  Colors.green,
                  Icons.check_circle_outline_rounded,
                  isSmallScreen,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildMobileStyleStatCard(
            l10n.pending,
            _ticketCounts['pending'] ?? 0,
            Colors.orange,
            Icons.pending_actions_rounded,
            isSmallScreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMobileStyleStatCard(
            l10n.inProgress,
            _ticketCounts['inprogress'] ?? 0,
            AppColors.secondary,
            Icons.work_outline_rounded,
            isSmallScreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMobileStyleStatCard(
            l10n.prefinished,
            _ticketCounts['prefinished'] ?? 0,
            Colors.purple,
            Icons.timer_outlined,
            isSmallScreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMobileStyleStatCard(
            l10n.completed,
            _ticketCounts['closed'] ?? 0,
            Colors.green,
            Icons.check_circle_outline_rounded,
            isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedWelcomeSection(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
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
      child: isSmallScreen ? _buildMobileWelcome() : _buildDesktopWelcome(),
    );
  }

  Widget _buildDesktopWelcome() {
    final l10n = AppLocalizations.safeOf(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.dashboard_rounded,
            color: AppColors.onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.welcomeBack,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.currentUser.fullName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.currentUser.userType.value
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.desktop_windows_rounded,
                size: 16,
                color: AppColors.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.webDashboard,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent() {
    final l10n = AppLocalizations.safeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // In Progress tickets section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.work_outline_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.inProgressTickets,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tickets container
        _buildTicketsContainer(true),

        const SizedBox(height: 24),

        // Pie Chart Section
        _buildPieChartSection(true),
      ],
    );
  }

  Widget _buildContentGrid() {
    final l10n = AppLocalizations.safeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // In Progress tickets section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.work_outline_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.inProgressTickets,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Two-column layout: Tickets and Pie Chart side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tickets container - Left side (2/3 width)
            Expanded(
              flex: 2,
              child: _buildTicketsContainer(false),
            ),

            const SizedBox(width: 20),

            // Pie Chart section - Right side (1/3 width)
            Expanded(
              flex: 1,
              child: _buildPieChartSection(false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTicketsContainer(bool isMobile) {
    final l10n = AppLocalizations.safeOf(context);
    return Container(
      height: isMobile ? null : 400,
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
      child: _inProgressTickets.isEmpty
          ? Center(
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
                      Icons.work_outline_rounded,
                      color: AppColors.secondary.withOpacity(0.6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noTicketsInProgress,
                    style: TextStyle(
                      color: AppColors.onBackground.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: isMobile
                        ? _inProgressTickets.take(3).length
                        : _inProgressTickets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ticket = _inProgressTickets[index];
                      return _buildTicketItem(ticket, isMobile);
                    },
                  ),
                ),
                // View All button at the bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: widget.onNavigateToTickets,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.viewAllTickets,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPieChartSection(bool isMobile) {
    final l10n = AppLocalizations.safeOf(context);
    final totalTickets =
        _ticketCounts.values.fold(0, (sum, count) => sum + count);

    return Container(
      height: isMobile ? null : 400,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.ticketDistribution,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pie Chart
          if (totalTickets > 0)
            SizedBox(
              height: isMobile ? 200 : 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: isMobile ? 35 : 40,
                  sections: _buildPieChartSections(),
                  borderData: FlBorderData(show: false),
                ),
              ),
            )
          else
            SizedBox(
              height: isMobile ? 200 : 220,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 48,
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noTicketData,
                      style: TextStyle(
                        color: AppColors.onBackground.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Legend
          if (totalTickets > 0) _buildPieChartLegend(isMobile),
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

  Widget _buildPieChartLegend(bool isMobile) {
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
        'label': l10n.closed,
        'color': Colors.green,
        'count': _ticketCounts['closed'] ?? 0,
      },
    ];

    return Wrap(
      spacing: isMobile ? 12 : 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: statusData.where((item) => item['count'] > 0).map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item['label']}: ${item['count']}',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: AppColors.onBackground.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileStyleStatCard(
    String title,
    int count,
    Color color,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: isSmallScreen ? 3 : 4,
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
                    fontSize: isSmallScreen ? 10 : 11,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
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

  Widget _buildTicketItem(Map<String, dynamic> ticket, bool isMobile) {
    final l10n = AppLocalizations.safeOf(context);
    return InkWell(
      onTap: widget.onNavigateToTickets,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: isMobile ? 24 : 32,
              decoration: BoxDecoration(
                color: _getStatusColor(ticket['status']),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
                        ),
                        child: Text(
                          ticket['ticket_number'],
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                          vertical: isMobile ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket['status'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
                        ),
                        child: Text(
                          l10n.inProgress,
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 9,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(ticket['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 3 : 4),
                  Text(
                    ticket['title'],
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 2 : 3),
                  Text(
                    DateFormat('MMM dd, HH:mm')
                        .format(DateTime.parse(ticket['created_at'])),
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: AppColors.onBackground.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
