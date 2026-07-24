import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'fleet_models.dart';
import 'fleet_reminders_setup.dart';
import 'fleet_service.dart';
import 'fleet_vehicle_detail_screen.dart';
import 'fleet_vehicle_form_dialog.dart';

// 0 = critical, 1 = warning, 2 = ok/unset — lower is worse.
int _dateSeverity(DateTime? date) {
  final days = fleetDaysUntil(date);
  if (days == null) return 2;
  if (days <= 7) return 0;
  if (days <= 30) return 1;
  return 2;
}

Color _severityColor(int severity) {
  switch (severity) {
    case 0:
      return const Color(0xFFDC2626);
    case 1:
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF16A34A);
  }
}

/// Fleet/vehicle management home — its own top-level nav destination,
/// department-gated for system admins (unrestricted) and super admins.
class FleetManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const FleetManagementScreen({super.key, required this.currentUser});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  List<FleetVehicle> _vehicles = [];
  List<FleetVehiclePart> _parts = [];
  bool _loading = true;
  String _search = '';
  bool _canAdd = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FleetService.getVehicles(),
        FleetService.getAllParts(),
        FleetService.getEligibleDepartments(widget.currentUser),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicles = results[0] as List<FleetVehicle>;
        _parts = results[1] as List<FleetVehiclePart>;
        _canAdd = (results[2] as List).isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addVehicle() async {
    final saved = await showFleetVehicleFormDialog(context, currentUser: widget.currentUser);
    if (saved == true) _load();
  }

  Future<void> _openVehicle(FleetVehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FleetVehicleDetailScreen(vehicle: vehicle, currentUser: widget.currentUser)),
    );
    _load();
  }

  Future<void> _setupReminders() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final created = await setupFleetReminders(widget.currentUser);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created > 0
            ? (isAr ? 'تم إنشاء $created تنبيه(ات) في الإشعارات الذكية' : 'Created $created reminder(s) in Smart Reminders')
            : (isAr ? 'التنبيهات معدة مسبقاً' : 'Reminders are already set up')),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تعذر إعداد التنبيهات' : 'Could not set up reminders')));
    }
  }

  Widget _warningsSidebar(List<FleetAlert> orderedAlerts, bool isAr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_active_outlined, size: 16, color: orderedAlerts.isEmpty ? AppColors.primary : const Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr ? 'التنبيهات' : 'WARNINGS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6),
              ),
            ),
            if (orderedAlerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${orderedAlerts.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
              ),
          ]),
          const Divider(height: 18),
          Expanded(
            child: orderedAlerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 32, color: Color(0xFF16A34A)),
                        const SizedBox(height: 8),
                        Text(isAr ? 'لا توجد تنبيهات' : 'No warnings', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: orderedAlerts.length,
                    itemBuilder: (_, i) => _sidebarWarningItem(orderedAlerts[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarWarningItem(FleetAlert alert) {
    final color = alert.level == FleetAlertLevel.critical ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        final matches = _vehicles.where((v) => v.id == alert.vehicleId).toList();
        if (matches.isNotEmpty) _openVehicle(matches.first);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(alert.level == FleetAlertLevel.critical ? Icons.error_outline : Icons.warning_amber_outlined, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    if (alert.vehicleNumber.isNotEmpty) ...[
                      Flexible(child: Text(alert.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                    ],
                    Text(alert.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2)),
                  ]),
                  const SizedBox(height: 2),
                  Text(alert.message, style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(bool isAr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: isAr ? 'ابحث برقم المركبة أو السائق...' : 'Search by vehicle number or driver...',
          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final alerts = generateFleetAlerts(_vehicles, _parts, isAr: isAr);
    final orderedAlerts = [
      ...alerts.where((a) => a.level == FleetAlertLevel.critical),
      ...alerts.where((a) => a.level == FleetAlertLevel.warning),
    ];

    final filtered = _vehicles.where((v) {
      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return v.vehicleNumber.toLowerCase().contains(q) ||
          v.drivers.any((d) => d.fullName.toLowerCase().contains(q)) ||
          v.vehicleType.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAr ? 'الأسطول' : 'Fleet', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    isAr
                        ? '${_vehicles.length} مركبة${orderedAlerts.isNotEmpty ? ' · ${orderedAlerts.length} تنبيه نشط' : ''}'
                        : '${_vehicles.length} vehicle${_vehicles.length == 1 ? '' : 's'}${orderedAlerts.isNotEmpty ? ' · ${orderedAlerts.length} active warning${orderedAlerts.length == 1 ? '' : 's'}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Row(children: [
            Expanded(child: _searchField(isAr)),
            if (_canAdd) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _setupReminders,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(isAr ? 'إعداد التنبيهات' : 'Set up reminders'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addVehicle,
                icon: const Icon(Icons.add, size: 18),
                label: Text(isAr ? 'إضافة مركبة' : 'Add vehicle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: Builder(builder: (context) {
            Widget gridContent;
            if (_loading) {
              gridContent = const Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: AppColors.primary));
            } else if (filtered.isEmpty) {
              gridContent = Center(
                key: const ValueKey('empty'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      _vehicles.isEmpty
                          ? (isAr ? 'لا توجد مركبات مسجلة' : 'No vehicles registered')
                          : (isAr ? 'لا نتائج للبحث' : 'No results'),
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              );
            } else {
              gridContent = GridView.builder(
                key: const ValueKey('grid'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisExtent: 152,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final v = filtered[i];
                  final vehicleWarnings = alerts.where((a) => a.vehicleId == v.id).length;
                  return _VehicleCard(
                    vehicle: v,
                    warningsCount: vehicleWarnings,
                    isAr: isAr,
                    onTap: () => _openVehicle(v),
                    onDeleted: _load,
                  );
                },
              );
            }

            return LayoutBuilder(builder: (context, constraints) {
              final sidebar = _warningsSidebar(orderedAlerts, isAr);
              final animatedGrid = AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: gridContent,
              );
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: animatedGrid),
                    const SizedBox(width: 16),
                    SizedBox(width: 300, child: sidebar),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: animatedGrid),
                  const SizedBox(height: 16),
                  SizedBox(height: 260, child: sidebar),
                ],
              );
            });
          }),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatefulWidget {
  final FleetVehicle vehicle;
  final int warningsCount;
  final bool isAr;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  const _VehicleCard({
    required this.vehicle,
    required this.warningsCount,
    required this.isAr,
    required this.onTap,
    required this.onDeleted,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  bool _hovering = false;
  bool _deleting = false;
  bool _deleteHovering = false;

  Future<void> _delete() async {
    final isAr = widget.isAr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'تأكيد الحذف' : 'Confirm delete'),
        content: Text(isAr
            ? 'هل أنت متأكد من حذف المركبة ${widget.vehicle.vehicleNumber}؟ لا يمكن التراجع عن هذا الإجراء.'
            : 'Delete vehicle ${widget.vehicle.vehicleNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await FleetService.deleteVehicle(widget.vehicle.id);
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تعذر الحذف' : 'Could not delete')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final isAr = widget.isAr;
    final kmRemaining = v.nextServiceOdometer - v.currentOdometer;
    final serviceColor = kmRemaining <= 0
        ? const Color(0xFFDC2626)
        : kmRemaining <= v.serviceAlertKm
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);
    final serviceLabel = kmRemaining <= 0
        ? (isAr ? 'متأخرة' : 'Overdue')
        : kmRemaining <= v.serviceAlertKm
            ? (isAr ? 'قريباً' : 'Due soon')
            : (isAr ? 'جيدة' : 'OK');

    final worstDateSeverity = [
      _dateSeverity(v.licenseExpiry),
      _dateSeverity(v.insuranceExpiry),
      _dateSeverity(v.tachographExpiry),
      _dateSeverity(v.winterInspectionDate),
    ].reduce((a, b) => a < b ? a : b);
    final docColor = _severityColor(worstDateSeverity);
    final docLabel = worstDateSeverity == 0
        ? (isAr ? 'تنتبه' : 'Attention')
        : worstDateSeverity == 1
            ? (isAr ? 'قريباً' : 'Soon')
            : (isAr ? 'سارية' : 'OK');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _hovering ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _hovering ? 0.08 : 0.02),
                    blurRadius: _hovering ? 16 : 4,
                    offset: Offset(0, _hovering ? 6 : 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(v.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), overflow: TextOverflow.ellipsis),
                          Text(v.vehicleType.isEmpty ? '—' : v.vehicleType, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (widget.warningsCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.notifications_active_outlined, size: 11, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text('${widget.warningsCount}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        ]),
                      ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _deleteHovering = true),
                      onExit: (_) => setState(() => _deleteHovering = false),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _deleting ? null : _delete,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _deleteHovering ? const Color(0xFFDC2626).withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _deleting
                              ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[300]))
                              : Icon(Icons.delete_outline, size: 17, color: _deleteHovering ? const Color(0xFFDC2626) : Colors.grey[400]),
                        ),
                      ),
                    ),
                  ]),
                  const Spacer(),
                  Row(children: [
                    Icon(Icons.person_outline, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        v.drivers.isEmpty
                            ? (isAr ? 'بدون سائق' : 'No driver')
                            : v.drivers.length == 1
                                ? v.primaryDriver!.fullName
                                : '${v.primaryDriver!.fullName} +${v.drivers.length - 1}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _statusPill(isAr ? 'الصيانة' : 'Service', serviceLabel, serviceColor)),
                    const SizedBox(width: 6),
                    Expanded(child: _statusPill(isAr ? 'المستندات' : 'Docs', docLabel, docColor)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label: $value',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
