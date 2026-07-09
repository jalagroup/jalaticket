import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jalasupport/complaint_service.dart';
import 'package:jalasupport/helpers/download_helper.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/complaint_check_dialog.dart';
import 'package:jalasupport/complaint_pdf_generator.dart';
import 'package:jalasupport/tickets.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';

class ComplaintsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ComplaintsScreen({super.key, required this.currentUser});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<ComplaintStatus, List<ComplaintTicketModel>> _complaintsByStatus =
      {};
  StreamSubscription? _mainSubscription;
  final Map<ComplaintStatus, bool> _loadingByStatus = {};
  bool _isInitialLoad = true;

  List<ComplaintStatus> _getTabsForUserType() {
    if (widget.currentUser.userType == UserType.admin) {
      return [
        ComplaintStatus.inprogress,
        ComplaintStatus.prefinished,
        ComplaintStatus.checked,
      ];
    } else {
      return [
        ComplaintStatus.pending,
        ComplaintStatus.inprogress,
        ComplaintStatus.prefinished,
        ComplaintStatus.checked,
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    final tabs = _getTabsForUserType();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    for (var status in tabs) {
      _complaintsByStatus[status] = [];
      _loadingByStatus[status] = true;
    }

    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _mainSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _mainSubscription?.cancel();

    if (mounted) {
      setState(() {
        final tabs = _getTabsForUserType();
        for (var status in tabs) {
          _loadingByStatus[status] = true;
        }
      });
    }

    _mainSubscription =
        supabase.from('complaint_tickets').stream(primaryKey: ['id']).timeout(
      const Duration(seconds: 30),
      onTimeout: (sink) {
        print('Stream timeout, reconnecting...');
        if (mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _setupRealtimeSubscription();
          });
        }
      },
    ).listen(
      (data) {
        _processAllComplaintsData(data);
      },
      onError: (error) {
        print('Stream error: $error');
        if (mounted) {
          setState(() {
            final tabs = _getTabsForUserType();
            for (var status in tabs) {
              _loadingByStatus[status] = false;
            }
          });

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              print('Reconnecting after error...');
              _setupRealtimeSubscription();
            }
          });
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _processAllComplaintsData(
      List<Map<String, dynamic>> data) async {
    if (!mounted) return;

    try {
      final tabs = _getTabsForUserType();

      Map<ComplaintStatus, List<ComplaintTicketModel>> newComplaintsByStatus =
          {};
      for (var status in tabs) {
        newComplaintsByStatus[status] = [];
      }

      final itemIds = data
          .where(
              (c) => c['item_id'] != null && c['item_id'].toString().isNotEmpty)
          .map((c) => c['item_id'].toString())
          .toSet()
          .toList();

      Map<String, String> itemNamesMap = {};
      if (itemIds.isNotEmpty) {
        try {
          final itemsResponse = await supabase
              .from('complaint_items')
              .select('id, name')
              .inFilter('id', itemIds);

          for (var item in itemsResponse) {
            itemNamesMap[item['id'].toString()] = item['name'].toString();
          }
        } catch (e) {
          print('Error fetching item names: $e');
        }
      }

      for (final complaintData in data) {
        try {
          String? itemName;
          final itemId = complaintData['item_id']?.toString();
          if (itemId != null && itemId.isNotEmpty) {
            itemName = itemNamesMap[itemId];
          }

          final complaint = ComplaintTicketModel(
            id: complaintData['id']?.toString() ?? '',
            complaintNumber:
                complaintData['complaint_number']?.toString() ?? 'N/A',
            date: complaintData['date'] != null
                ? DateTime.parse(complaintData['date']).toLocal()
                : DateTime.now(),
            complaintReceiver:
                complaintData['complaint_receiver']?.toString() ?? 'Unknown',
            complainantName:
                complaintData['complainant_name']?.toString() ?? 'Unknown',
            location:
                complaintData['location']?.toString() ?? 'Unknown Location',
            mobileNumber: complaintData['mobile_number']?.toString() ?? 'N/A',
            phoneNumber: complaintData['phone_number']?.toString(),
            itemId: itemId,
            itemName: itemName ?? 'No Item',
            batchNumber: complaintData['batch_number']?.toString(),
            quantity: complaintData['quantity']?.toDouble(),
            produceDate: complaintData['produce_date'] != null
                ? DateTime.parse(complaintData['produce_date']).toLocal()
                : null,
            expiredDate: complaintData['expired_date'] != null
                ? DateTime.parse(complaintData['expired_date']).toLocal()
                : null,
            description: complaintData['description']?.toString() ?? '',
            complaintType: ComplaintType.values.firstWhere(
              (e) =>
                  e.value == (complaintData['complaint_type'] ?? 'technical'),
              orElse: () => ComplaintType.technical,
            ),
            status: ComplaintStatus.values.firstWhere(
              (e) => e.value == (complaintData['status'] ?? 'pending'),
              orElse: () => ComplaintStatus.pending,
            ),
            createdBy: complaintData['created_by']?.toString() ?? '',
            assignedTo: complaintData['assigned_to']?.toString(),
            departmentId: (complaintData['department_id'] == null ||
                    complaintData['department_id'].toString().isEmpty)
                ? null
                : complaintData['department_id'].toString(),
            createdAt: complaintData['created_at'] != null
                ? DateTime.parse(complaintData['created_at']).toLocal()
                : DateTime.now(),
            updatedAt: complaintData['updated_at'] != null
                ? DateTime.parse(complaintData['updated_at']).toLocal()
                : DateTime.now(),
          );

          if (!tabs.contains(complaint.status)) {
            continue;
          }

          bool shouldInclude = false;

          if (widget.currentUser.userType == UserType.systemAdmin) {
            shouldInclude = true;
          } else if (widget.currentUser.userType == UserType.superAdmin) {
            if (widget.currentUser.departmentId != null) {
              shouldInclude =
                  complaint.departmentId == widget.currentUser.departmentId ||
                      complaint.departmentId == null ||
                      complaint.departmentId!.isEmpty ||
                      complaint.createdBy == widget.currentUser.id;
            } else {
              shouldInclude = true;
            }
          } else if (widget.currentUser.userType == UserType.admin) {
            shouldInclude = complaint.assignedTo == widget.currentUser.id;
          } else {
            shouldInclude = complaint.createdBy == widget.currentUser.id;
          }

          if (shouldInclude) {
            newComplaintsByStatus[complaint.status]?.add(complaint);
          }
        } catch (e) {
          print('Error processing complaint: $e');
          print('Complaint data: $complaintData');
        }
      }

      for (var status in tabs) {
        newComplaintsByStatus[status]
            ?.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (mounted) {
        setState(() {
          _complaintsByStatus.clear();
          _complaintsByStatus.addAll(newComplaintsByStatus);

          for (var status in tabs) {
            _loadingByStatus[status] = false;
          }

          _isInitialLoad = false;
        });
      }
    } catch (e) {
      print('Error processing stream data: $e');
      if (mounted) {
        setState(() {
          final tabs = _getTabsForUserType();
          for (var status in tabs) {
            _loadingByStatus[status] = false;
          }
        });
      }
    }
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _refreshData() {
    _mainSubscription?.cancel();
    setState(() {
      _isInitialLoad = true;
      final tabs = _getTabsForUserType();
      for (var status in tabs) {
        _loadingByStatus[status] = true;
      }
    });
    _setupRealtimeSubscription();
  }

  String _getTabTitle(ComplaintStatus status) {
    final l10n = AppLocalizations.safeOf(context);
    final count = (_complaintsByStatus[status] ?? []).length;
    final title = _getStatusText(status, l10n).toUpperCase();
    return count > 0 ? '$title ($count)' : title;
  }

  String _getStatusText(ComplaintStatus status, AppLocalizations l10n) {
    switch (status) {
      case ComplaintStatus.pending:
        return l10n.pending;
      case ComplaintStatus.inprogress:
        return l10n.inProgress;
      case ComplaintStatus.prefinished:
        return l10n.prefinished;
      case ComplaintStatus.checked:
        return l10n.closed;
    }
  }

  List<ComplaintTicketModel> _getCurrentComplaints() {
    final tabs = _getTabsForUserType();
    final currentStatus = tabs[_tabController.index];
    return _complaintsByStatus[currentStatus] ?? [];
  }

  bool _isCurrentTabLoading() {
    final tabs = _getTabsForUserType();
    final currentStatus = tabs[_tabController.index];
    return _loadingByStatus[currentStatus] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final tabs = _getTabsForUserType();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        title: Text(
          l10n.qualityComplaints,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.orange,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
              tabs: tabs.map((status) {
                final count = (_complaintsByStatus[status] ?? []).length;
                final title = _getStatusText(status, l10n);
                final isSelected = _tabController.index == tabs.indexOf(status);

                return Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.orange : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count > 99 ? '99' : count.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: _refreshData,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _buildComplaintList(),
    );
  }

  Widget _buildComplaintList() {
    final l10n = AppLocalizations.safeOf(context);
    final complaints = _getCurrentComplaints();
    final tabs = _getTabsForUserType();
    final currentStatus = tabs[_tabController.index];
    final isLoading = _isCurrentTabLoading();
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isLoading && _isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (complaints.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.noComplaintsFound} ${_getStatusText(currentStatus, l10n).toLowerCase()}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final double listWidth;
    if (screenWidth >= 1400) {
      listWidth = 1320;
    } else if (screenWidth >= 1200) {
      listWidth = 1140;
    } else if (screenWidth >= 992) {
      listWidth = 960;
    } else if (screenWidth >= 768) {
      listWidth = 720;
    } else {
      listWidth = screenWidth;
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Center(
        child: Container(
          width: listWidth,
          child: ListView.builder(
            key: ValueKey('complaint_list_$currentStatus'),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: complaints.length,
            padding: EdgeInsets.only(
              left: isMobile ? 16 : 24,
              right: isMobile ? 16 : 24,
              top: 8,
              bottom: 8,
            ),
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ComplaintCard(
                  key: ValueKey(complaint.id),
                  complaint: complaint,
                  currentUser: widget.currentUser,
                  onRefresh: _refreshData,
                  currentStatus: currentStatus,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Updated ComplaintCard with white background and ticket-like design
class ComplaintCard extends StatefulWidget {
  final ComplaintTicketModel complaint;
  final UserModel currentUser;
  final VoidCallback onRefresh;
  final ComplaintStatus currentStatus;

  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.currentUser,
    required this.onRefresh,
    required this.currentStatus,
  });

  @override
  State<ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<ComplaintCard> {
  bool _isExpanded = false;
  bool _loadingUserInfo = false;
  bool _loadingExpandedData = false;

  // Cached user info
  String? _creatorName;
  String? _assignedToName;
  String? _departmentName;
  String? _checkerName;

  // Expanded data
  ComplaintCheckModel? _checkData;
  List<Map<String, dynamic>> _activityLogs = [];

  @override
  void initState() {
    super.initState();
    _loadBasicUserInfo();
  }

  Future<void> _loadBasicUserInfo() async {
    if (_loadingUserInfo) return;
    setState(() => _loadingUserInfo = true);

    try {
      final futures = <Future>[];

      // Load creator name
      futures.add(
        supabase
            .from('users')
            .select('full_name')
            .eq('id', widget.complaint.createdBy)
            .maybeSingle()
            .then((response) {
          if (response != null && mounted) {
            _creatorName = response['full_name'];
          }
        }),
      );

      // Load assigned user name if exists
      if (widget.complaint.assignedTo != null) {
        futures.add(
          supabase
              .from('users')
              .select('full_name')
              .eq('id', widget.complaint.assignedTo!)
              .maybeSingle()
              .then((response) {
            if (response != null && mounted) {
              _assignedToName = response['full_name'];
            }
          }),
        );
      }

      // Load department name if exists
      if (widget.complaint.departmentId != null &&
          widget.complaint.departmentId!.isNotEmpty) {
        futures.add(
          supabase
              .from('departments')
              .select('name')
              .eq('id', widget.complaint.departmentId!)
              .maybeSingle()
              .then((response) {
            if (response != null && mounted) {
              _departmentName = response['name'];
            }
          }),
        );
      }

      await Future.wait(futures);

      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    } catch (e) {
      print('Error loading basic user info: $e');
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    }
  }

  Future<void> _loadExpandedData() async {
    if (_loadingExpandedData) return;
    setState(() => _loadingExpandedData = true);

    try {
      final futures = <Future>[];

      // Load check data if complaint is checked or prefinished
      if (widget.complaint.status == ComplaintStatus.checked ||
          widget.complaint.status == ComplaintStatus.prefinished) {
        futures.add(
          supabase
              .from('complaint_checks')
              .select('*')
              .eq('complaint_id', widget.complaint.id)
              .order('created_at', ascending: false)
              .limit(1)
              .then((response) {
            if (response.isNotEmpty) {
              _checkData = ComplaintCheckModel.fromJson(response.first);
              _checkerName = _checkData?.checkerName;
            }
          }),
        );
      }

      // Load activity logs
      futures.add(
        supabase
            .from('activity_logs')
            .select('*, users(full_name)')
            .eq('record_id', widget.complaint.id)
            .eq('table_name', 'complaint_tickets')
            .order('created_at', ascending: false)
            .limit(10)
            .then((response) => _activityLogs = response),
      );

      await Future.wait(futures);

      if (mounted) {
        setState(() => _loadingExpandedData = false);
      }
    } catch (e) {
      print('Error loading expanded data: $e');
      if (mounted) {
        setState(() => _loadingExpandedData = false);
      }
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && !_loadingExpandedData) {
      _loadExpandedData();
    }
  }

  Color _getStatusColor() {
    switch (widget.complaint.status) {
      case ComplaintStatus.pending:
        return Colors.orange;
      case ComplaintStatus.inprogress:
        return Colors.blue;
      case ComplaintStatus.prefinished:
        return Colors.purple;
      case ComplaintStatus.checked:
        return Colors.green;
    }
  }

  Color _getTypeColor() {
    switch (widget.complaint.complaintType) {
      case ComplaintType.technical:
        return Colors.red;
      case ComplaintType.coordination_delivery:
        return Colors.indigo;
    }
  }

  IconData _getComplaintIcon() {
    switch (widget.complaint.status) {
      case ComplaintStatus.pending:
        return Icons.pending;
      case ComplaintStatus.inprogress:
        return Icons.work;
      case ComplaintStatus.prefinished:
        return Icons.check_circle_outline;
      case ComplaintStatus.checked:
        return Icons.verified;
    }
  }

  List<Map<String, dynamic>> _getAvailableActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    // Super admin can assign pending complaints
    if (widget.complaint.status == ComplaintStatus.pending &&
        (widget.currentUser.userType == UserType.superAdmin ||
            widget.currentUser.userType == UserType.systemAdmin)) {
      actions.add({
        'label': l10n.assign,
        'icon': Icons.assignment_ind,
        'color': Colors.blue,
        'onPressed': () => _showAssignDialog(),
      });
    }

    // Admin can check inprogress complaints
    if (widget.complaint.status == ComplaintStatus.inprogress &&
        widget.complaint.assignedTo == widget.currentUser.id) {
      actions.add({
        'label': l10n.checkComplaint,
        'icon': Icons.fact_check,
        'color': Colors.purple,
        'onPressed': () => _showCheckDialog(),
      });
    }

    // Can download PDF for prefinished and checked
    if (widget.complaint.status == ComplaintStatus.prefinished ||
        widget.complaint.status == ComplaintStatus.checked) {
      actions.add({
        'label': l10n.downloadPdf,
        'icon': Icons.picture_as_pdf,
        'color': Colors.red,
        'onPressed': () => _downloadPDF(),
      });
    }

    // Can upload signed document for prefinished
    if (widget.complaint.status == ComplaintStatus.prefinished &&
        widget.complaint.assignedTo == widget.currentUser.id) {
      actions.add({
        'label': l10n.uploadSigned,
        'icon': Icons.upload_file,
        'color': Colors.green,
        'onPressed': () => _uploadSignedDocument(),
      });
    }

    return actions;
  }

  void _showAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => AssignComplaintDialog(
        complaint: widget.complaint,
        currentUser: widget.currentUser,
        onComplaintAssigned: () {
          widget.onRefresh();
        },
      ),
    );
  }

  // Add this at the top of your tickets.dart file or in a utils file
  bool _shouldUseFullScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 992;
  }

  void _showCheckDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ComplaintCheckScreen(
            complaint: widget.complaint,
            currentUser: widget.currentUser,
            onCheckSubmitted: () {
              widget.onRefresh();
            },
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => ComplaintCheckDialog(
          complaint: widget.complaint,
          currentUser: widget.currentUser,
          onCheckSubmitted: () {
            widget.onRefresh();
          },
        ),
      );
    }
  }

  Future<void> _downloadPDF() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      if (_checkData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noCheckReportAvailable),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.generatingPdf)),
      );

      final pdfBytes = await ComplaintPDFGenerator.generateCheckReportPDF(
        widget.complaint,
        _checkData!,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pdfGeneratedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorGeneratingPdf}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadSignedDocument() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.loadingCheckData),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      if (_checkData == null) {
        try {
          final response = await supabase
              .from('complaint_checks')
              .select('*')
              .eq('complaint_id', widget.complaint.id)
              .order('created_at', ascending: false)
              .limit(1);

          if (response.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.noCheckRecordFound),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          _checkData = ComplaintCheckModel.fromJson(response.first);
        } catch (e) {
          print('Error loading check data: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.errorLoadingCheckData}: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (_checkData!.signedDocumentPath != null) {
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) => OptimizedDialog(
            title: l10n.replaceSignedDocument,
            width: 400,
            child: Text(l10n.signedDocumentExists),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.replace),
              ),
            ],
          ),
        );

        if (shouldReplace != true) {
          return;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.couldNotReadFile),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (file.bytes!.length > 52428800) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fileSizeExceedsLimit),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      String mimeType = 'application/pdf';
      final extension = file.extension?.toLowerCase() ?? '';
      if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(extension == 'pdf'
                    ? l10n.uploadingPdf
                    : l10n.uploadingImage),
              ],
            ),
            duration: const Duration(minutes: 2),
          ),
        );
      }

      final success = await ComplaintService.uploadSignedDocument(
        complaintId: widget.complaint.id,
        checkId: _checkData!.id,
        fileName: file.name,
        fileBytes: file.bytes!,
        mimeType: mimeType,
        currentUserId: widget.currentUser.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(extension == 'pdf'
                      ? l10n.signedPdfUploaded
                      : l10n.signedImageUploaded),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          widget.onRefresh();

          setState(() {
            _checkData = null;
            _loadingExpandedData = false;
          });
          _loadExpandedData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedUploadSigned),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading signed document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorUploading}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white, // White background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCompactHeader(),
          if (_isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final actions = _getAvailableActions();

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            if (isMobile)
              _buildMobileLayout(actions, l10n)
            else
              _buildDesktopLayout(actions, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
      List<Map<String, dynamic>> actions, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor().withOpacity(0.8),
                    _getStatusColor().withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getComplaintIcon(),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.complaint.complaintNumber,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            if (actions.isNotEmpty)
              PopupMenuButton<VoidCallback>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (callback) => callback(),
                itemBuilder: (context) => actions
                    .map((action) => PopupMenuItem<VoidCallback>(
                          value: action['onPressed'],
                          child: Row(
                            children: [
                              Icon(action['icon'],
                                  size: 16, color: action['color']),
                              const SizedBox(width: 8),
                              Text(action['label'],
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.complaint.complainantName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatusBadge(l10n),
            const SizedBox(width: 6),
            _buildTypeBadge(l10n),
          ],
        ),
        const SizedBox(height: 10),
        _buildMobileInfoGrid(l10n),
      ],
    );
  }

  Widget _buildDesktopLayout(
      List<Map<String, dynamic>> actions, AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getStatusColor().withOpacity(0.8),
                _getStatusColor().withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getComplaintIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.complaint.complaintNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.complaint.complainantName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildDesktopInfoLine(l10n),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          PopupMenuButton<VoidCallback>(
            icon: const Icon(Icons.more_vert),
            onSelected: (callback) => callback(),
            itemBuilder: (context) => actions
                .map((action) => PopupMenuItem<VoidCallback>(
                      value: action['onPressed'],
                      child: Row(
                        children: [
                          Icon(action['icon'],
                              size: 18, color: action['color']),
                          const SizedBox(width: 8),
                          Text(action['label']),
                        ],
                      ),
                    ))
                .toList(),
          ),
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[600],
        ),
      ],
    );
  }

  Widget _buildMobileInfoGrid(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFreeGridItem(
                Icons.inventory_2,
                widget.complaint.itemName ?? l10n.noItem,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFreeGridItem(
                Icons.location_on,
                widget.complaint.location,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFreeGridItem(
                Icons.phone,
                widget.complaint.mobileNumber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFreeGridItem(
                Icons.calendar_today,
                DateFormat('dd/MM/yy').format(widget.complaint.date),
              ),
            ),
          ],
        ),
        if (widget.complaint.assignedTo != null) ...[
          const SizedBox(height: 8),
          _buildFreeGridItem(
            Icons.assignment_ind,
            _loadingUserInfo ? l10n.loading : _assignedToName ?? l10n.unknown,
          ),
        ],
      ],
    );
  }

  Widget _buildFreeGridItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopInfoLine(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCompactInfo(
              Icons.inventory_2, widget.complaint.itemName ?? l10n.noItem),
          _buildDivider(),
          _buildCompactInfo(Icons.location_on, widget.complaint.location),
          _buildDivider(),
          _buildCompactInfo(Icons.phone, widget.complaint.mobileNumber),
          if (widget.complaint.assignedTo != null) ...[
            _buildDivider(),
            _buildCompactInfo(
              Icons.assignment_ind,
              _loadingUserInfo ? l10n.loading : _assignedToName ?? l10n.unknown,
            ),
          ],
          _buildDivider(),
          _buildCompactInfo(
            Icons.calendar_today,
            DateFormat('dd/MM/yy').format(widget.complaint.date),
          ),
          _buildDivider(),
          _buildStatusBadge(l10n),
          const SizedBox(width: 6),
          _buildTypeBadge(l10n),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(IconData icon, String text) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isMobile ? 14 : 12, color: Colors.grey[600]),
        SizedBox(width: isMobile ? 6 : 4),
        Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 12 : 11,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 1,
      height: 12,
      color: Colors.grey[300],
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 6, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
      ),
      child: Text(
        _getStatusText(widget.complaint.status, l10n).toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(AppLocalizations l10n) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final typeText = widget.complaint.complaintType == ComplaintType.technical
        ? l10n.technical
        : l10n.coordinationDelivery;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 6, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: _getTypeColor(),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
      ),
      child: Text(
        typeText.toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getStatusText(ComplaintStatus status, AppLocalizations l10n) {
    switch (status) {
      case ComplaintStatus.pending:
        return l10n.pending;
      case ComplaintStatus.inprogress:
        return l10n.inProgress;
      case ComplaintStatus.prefinished:
        return l10n.prefinished;
      case ComplaintStatus.checked:
        return l10n.closed;
    }
  }

  Widget _buildExpandedContent() {
    final l10n = AppLocalizations.safeOf(context);

    if (_loadingExpandedData) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.02),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            l10n.basicInformation,
            Icons.info_outline,
            Colors.blue,
            [
              if (isMobile)
                _buildMobileBasicInfoGrid(l10n)
              else
                _buildDetailGrid(_buildBasicInfoDetails(l10n)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            l10n.productDetails,
            Icons.inventory_2,
            Colors.orange,
            [
              if (isMobile)
                _buildMobileProductGrid(l10n)
              else
                _buildDetailGrid(_buildProductDetails(l10n)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            l10n.complaintDescription,
            Icons.description_outlined,
            Colors.green,
            [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Text(
                  widget.complaint.description,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildImagesSection(l10n),
          if (_checkData != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.checkReport,
              Icons.fact_check,
              Colors.purple,
              [_buildCheckReportContent(l10n)],
            ),
          ],
          if (widget.complaint.status == ComplaintStatus.checked) ...[
            const SizedBox(height: 16),
            _buildSignedDocumentSection(l10n),
          ],
          if (_activityLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.recentActivity,
              Icons.timeline_outlined,
              Colors.grey,
              [_buildActivityTimeline(l10n)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBasicInfoGrid(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.complainant, widget.complaint.complainantName)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.receiver, widget.complaint.complaintReceiver)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.mobile, widget.complaint.mobileNumber)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildLabeledGridItem(l10n.phone,
                    widget.complaint.phoneNumber ?? l10n.notApplicable)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.location, widget.complaint.location)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.date, widget.complaint.formattedDate)),
          ],
        ),
        if (widget.complaint.assignedTo != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildLabeledGridItem(
                      l10n.assignedTo, _assignedToName ?? l10n.loading)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildLabeledGridItem(
                      l10n.department, _departmentName ?? l10n.notApplicable)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileProductGrid(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.item, widget.complaint.itemName ?? l10n.noItem)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildLabeledGridItem(l10n.batchNumber,
                    widget.complaint.batchNumber ?? l10n.notApplicable)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(
                    l10n.quantity,
                    widget.complaint.quantity?.toString() ??
                        l10n.notApplicable)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledGridItem(
                l10n.produceDate,
                widget.complaint.produceDate != null
                    ? DateFormat('dd/MM/yyyy')
                        .format(widget.complaint.produceDate!)
                    : l10n.notApplicable,
              ),
            ),
          ],
        ),
        if (widget.complaint.expiredDate != null) ...[
          const SizedBox(height: 12),
          _buildLabeledGridItem(l10n.expiredDate,
              DateFormat('dd/MM/yyyy').format(widget.complaint.expiredDate!)),
        ],
      ],
    );
  }

  Widget _buildLabeledGridItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBasicInfoDetails(AppLocalizations l10n) {
    return [
      _buildDetailItem(l10n.complainant, widget.complaint.complainantName),
      _buildDetailItem(l10n.receiver, widget.complaint.complaintReceiver),
      _buildDetailItem(l10n.mobile, widget.complaint.mobileNumber),
      _buildDetailItem(
          l10n.phone, widget.complaint.phoneNumber ?? l10n.notApplicable),
      _buildDetailItem(l10n.location, widget.complaint.location),
      _buildDetailItem(l10n.date, widget.complaint.formattedDate),
      _buildDetailItem(l10n.status,
          _getStatusText(widget.complaint.status, l10n).toUpperCase()),
      _buildDetailItem(
        l10n.type,
        widget.complaint.complaintType == ComplaintType.technical
            ? l10n.technical
            : l10n.coordinationDelivery,
      ),
      if (widget.complaint.assignedTo != null)
        _buildDetailItem(l10n.assignedTo, _assignedToName ?? l10n.loading),
    ];
  }

  List<Widget> _buildProductDetails(AppLocalizations l10n) {
    return [
      _buildDetailItem(l10n.item, widget.complaint.itemName ?? l10n.noItem),
      _buildDetailItem(
          l10n.batchNumber, widget.complaint.batchNumber ?? l10n.notApplicable),
      _buildDetailItem(l10n.quantity,
          widget.complaint.quantity?.toString() ?? l10n.notApplicable),
      if (widget.complaint.produceDate != null)
        _buildDetailItem(l10n.produceDate,
            DateFormat('dd/MM/yyyy').format(widget.complaint.produceDate!)),
      if (widget.complaint.expiredDate != null)
        _buildDetailItem(l10n.expiredDate,
            DateFormat('dd/MM/yyyy').format(widget.complaint.expiredDate!)),
    ];
  }

  Widget _buildCheckReportContent(AppLocalizations l10n) {
    if (_checkData == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.purple[700]),
              const SizedBox(width: 6),
              Text(
                '${l10n.complaintCheckedBy}: ${_checkData!.checkerName}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[700],
                ),
              ),
              const Spacer(),
              Text(
                _checkData!.formattedCheckDate,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _checkData!.complaintCheck
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _checkData!.complaintCheck
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _checkData!.complaintCheck
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _checkData!.complaintCheck ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _checkData!.complaintCheck
                      ? l10n.complaintValid
                      : l10n.complaintInvalid,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _checkData!.complaintCheck
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${l10n.checkReport}:',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _checkData!.report,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          if (_checkData!.therapeuticProcedure != null &&
              _checkData!.therapeuticProcedure!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.therapeuticProcedure}:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _checkData!.therapeuticProcedure!,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ComplaintService.getComplaintAttachmentsWithUrls(
                widget.complaint.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final checkAttachments = snapshot.data!
                  .where((a) =>
                      a['attachment_type']?.toString().toLowerCase() ==
                          'check' &&
                      a['is_image'] == true)
                  .toList();

              if (checkAttachments.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.image, size: 16, color: Colors.purple[700]),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.checkImages} (${checkAttachments.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildImagesGrid(checkAttachments, l10n),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection(AppLocalizations l10n) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future:
          ComplaintService.getComplaintAttachmentsWithUrls(widget.complaint.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoSection(
            l10n.initialAttachments,
            Icons.image_outlined,
            Colors.teal,
            [
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildInfoSection(
            l10n.initialAttachments,
            Icons.image_outlined,
            Colors.teal,
            [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.error}: ${snapshot.error}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final attachments = snapshot.data ?? [];
        final initialAttachments = attachments
            .where((a) =>
                a['attachment_type']?.toString().toLowerCase() == 'initial')
            .toList();

        final imageAttachments =
            initialAttachments.where((a) => a['is_image'] == true).toList();
        final nonImageAttachments =
            initialAttachments.where((a) => a['is_image'] != true).toList();

        if (initialAttachments.isEmpty) {
          return _buildInfoSection(
            l10n.initialAttachments,
            Icons.image_outlined,
            Colors.teal,
            [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      l10n.noInitialAttachments,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return _buildInfoSection(
          '${l10n.initialAttachments} (${initialAttachments.length})',
          Icons.attach_file,
          Colors.teal,
          [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageAttachments.isNotEmpty) ...[
                  Text(
                    '${l10n.images} (${imageAttachments.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImagesGrid(imageAttachments, l10n),
                  const SizedBox(height: 12),
                ],
                if (nonImageAttachments.isNotEmpty) ...[
                  Text(
                    '${l10n.documents} (${nonImageAttachments.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...nonImageAttachments.map(
                      (attachment) => _buildAttachmentItem(attachment, l10n)),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignedDocumentSection(AppLocalizations l10n) {
    if (widget.complaint.status != ComplaintStatus.checked) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future:
          ComplaintService.getComplaintAttachmentsWithUrls(widget.complaint.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoSection(
            l10n.signedDocument,
            Icons.verified,
            Colors.green,
            [
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final signedAttachments = snapshot.data
                ?.where((a) =>
                    a['attachment_type']?.toString().toLowerCase() == 'signed')
                .toList() ??
            [];

        if (signedAttachments.isEmpty) {
          return const SizedBox.shrink();
        }

        final signedImages =
            signedAttachments.where((a) => a['is_image'] == true).toList();
        final signedDocs =
            signedAttachments.where((a) => a['is_image'] != true).toList();

        return _buildInfoSection(
          l10n.signedDocument,
          Icons.verified,
          Colors.green,
          [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (signedImages.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.images} (${signedImages.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildImagesGrid(signedImages, l10n),
                  if (signedDocs.isNotEmpty) const SizedBox(height: 12),
                ],
                if (signedDocs.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf,
                          color: Colors.green[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.documents} (${signedDocs.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...signedDocs.map((doc) => _buildAttachmentItem(doc, l10n)),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagesGrid(
      List<Map<String, dynamic>> images, AppLocalizations l10n) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final crossAxisCount = isMobile ? 2 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return _buildImageThumbnail(image, l10n);
      },
    );
  }

  Widget _buildImageThumbnail(
      Map<String, dynamic> image, AppLocalizations l10n) {
    return InkWell(
      onTap: () => _showImageDialog(image, l10n),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image['signed_url'] != null
                  ? Image.network(
                      image['signed_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image,
                              size: 40, color: Colors.grey),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getAttachmentTypeColor(image['attachment_type']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getAttachmentTypeLabel(image['attachment_type'], l10n),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(Map<String, dynamic> image, AppLocalizations l10n) {
    final TransformationController transformationController =
        TransformationController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                image['file_name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.type}: ${_getAttachmentTypeLabel(image['attachment_type'], l10n)} • ${_formatFileSize(image['file_size'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out),
                          onPressed: () {
                            final currentScale = transformationController.value
                                .getMaxScaleOnAxis();
                            if (currentScale > 0.5) {
                              final newScale =
                                  (currentScale - 0.5).clamp(0.5, 5.0);
                              transformationController.value =
                                  Matrix4.identity()..scale(newScale);
                            }
                          },
                          tooltip: l10n.zoomOut,
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in),
                          onPressed: () {
                            final currentScale = transformationController.value
                                .getMaxScaleOnAxis();
                            if (currentScale < 5.0) {
                              final newScale =
                                  (currentScale + 0.5).clamp(0.5, 5.0);
                              transformationController.value =
                                  Matrix4.identity()..scale(newScale);
                            }
                          },
                          tooltip: l10n.zoomIn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            transformationController.value = Matrix4.identity();
                          },
                          tooltip: l10n.resetZoom,
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _downloadImage(image, l10n),
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.download),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: image['signed_url'] != null
                    ? InteractiveViewer(
                        transformationController: transformationController,
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: Center(
                          child: Image.network(
                            image['signed_url'],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image,
                                        size: 64, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(l10n.failedToLoadImage),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : Center(
                        child: Text(l10n.failedToLoad),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadImage(
      Map<String, dynamic> image, AppLocalizations l10n) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(l10n.downloadingImage),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      final url = image['signed_url'];
      if (url != null) {
        if (DownloadHelper.isDownloadSupported()) {
          final success = await DownloadHelper.downloadFile(
            url,
            image['file_name'] ?? 'image.jpg',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(l10n.imageDownloadedSuccessfully),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.failedToDownloadImage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.downloadNotSupported),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error downloading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentItem(
      Map<String, dynamic> attachment, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment['file_name'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getAttachmentTypeLabel(attachment['attachment_type'], l10n)} • ${_formatFileSize(attachment['file_size'])}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getAttachmentTypeColor(attachment['attachment_type']),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getAttachmentTypeLabel(attachment['attachment_type'], l10n)
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAttachmentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'initial':
        return Colors.blue;
      case 'check':
        return Colors.purple;
      case 'signed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getAttachmentTypeLabel(String type, AppLocalizations l10n) {
    switch (type.toLowerCase()) {
      case 'initial':
        return l10n.initial;
      case 'check':
        return l10n.check;
      case 'signed':
        return l10n.signed;
      default:
        return type;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildActivityTimeline(AppLocalizations l10n) {
    return Column(
      children: _activityLogs.take(5).map((log) {
        final actionType = log['action'] as String;
        final userName = log['users']?['full_name'] ?? 'System';
        final timestamp = DateTime.parse(log['created_at']);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(
                _getActivityIcon(actionType),
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getActivityDescription(actionType, userName),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                DateFormat('dd/MM HH:mm').format(timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailGrid(List<Widget> details) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: details,
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'insert':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.timeline;
    }
  }

  String _getActivityDescription(String actionType, String userName) {
    switch (actionType.toLowerCase()) {
      case 'insert':
        return '$userName created this complaint';
      case 'update':
        return '$userName updated the complaint';
      case 'delete':
        return '$userName deleted the complaint';
      default:
        return '$userName performed $actionType';
    }
  }
}

class AssignComplaintDialog extends StatefulWidget {
  final ComplaintTicketModel complaint;
  final UserModel currentUser;
  final VoidCallback onComplaintAssigned;

  const AssignComplaintDialog({
    super.key,
    required this.complaint,
    required this.currentUser,
    required this.onComplaintAssigned,
  });

  @override
  State<AssignComplaintDialog> createState() => _AssignComplaintDialogState();
}

class _AssignComplaintDialogState extends State<AssignComplaintDialog> {
  List<Map<String, dynamic>> _admins = [];
  String? _selectedAdminId;
  bool _isLoading = false;
  bool _loadingAdmins = true;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdmins();
    });
  }

  // Alternative approach: use didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load admins only once when dependencies change
    if (_admins.isEmpty && _loadingAdmins) {
      _loadAdmins();
    }
  }

  Future<void> _loadAdmins() async {
    // Don't use AppLocalizations here since context might not be fully available
    try {
      setState(() => _loadingAdmins = true);

      final response = await supabase
          .from('users')
          .select('id, full_name, email')
          .eq('department_id', widget.currentUser.departmentId!)
          .eq('user_type', 'admin')
          .eq('is_active', true)
          .order('full_name');

      setState(() {
        _admins = response;
        _loadingAdmins = false;
      });
    } catch (e) {
      print('Error loading admins: $e');
      setState(() => _loadingAdmins = false);

      // Show error using ScaffoldMessenger only if mounted
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorLoadingAdmins}: $e')),
        );
      }
    }
  }

  Future<void> _assignComplaint() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_selectedAdminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectAdmin)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ComplaintService.assignComplaint(
        widget.complaint.id,
        _selectedAdminId!,
        widget.currentUser.departmentId!,
      );

      if (success) {
        setState(() => _isLoading = false);

        if (mounted) {
          Navigator.pop(context);
          widget.onComplaintAssigned();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.complaintAssignedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to assign complaint');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorAssigningComplaint}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return OptimizedDialog(
      title: l10n.assignComplaint,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.9
          : MediaQuery.of(context).size.width * 0.5,
      contentPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.selectAdminFromDepartment,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          if (_loadingAdmins)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.loadingAdmins),
                ],
              ),
            )
          else if (_admins.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.noAdminsAvailable,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.selectAdmin} (${_admins.length} ${l10n.available}):',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _admins.length,
                    itemBuilder: (context, index) {
                      final admin = _admins[index];
                      final isSelected = _selectedAdminId == admin['id'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: admin['id'],
                          groupValue: _selectedAdminId,
                          onChanged: (value) {
                            setState(() => _selectedAdminId = value);
                          },
                          title: Text(
                            admin['full_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            admin['email'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            l10n.cancel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: (_isLoading || _selectedAdminId == null)
              ? null
              : _assignComplaint,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_turned_in, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.assign,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// Public function to show assign complaint dialog
void showAssignComplaintDialog(
  BuildContext context,
  ComplaintTicketModel complaint,
  UserModel currentUser,
  VoidCallback onComplaintAssigned,
) {
  showDialog(
    context: context,
    builder: (context) => AssignComplaintDialog(
      complaint: complaint,
      currentUser: currentUser,
      onComplaintAssigned: onComplaintAssigned,
    ),
  );
}
