import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'fleet_checkin_dialog.dart';
import 'fleet_models.dart';
import 'fleet_parts_dialog.dart';
import 'fleet_service.dart';
import 'fleet_vehicle_form_dialog.dart';
import 'fleet_whatsapp.dart';

int _dateSeverity(DateTime? date) {
  final days = fleetDaysUntil(date);
  if (days == null) return 2;
  if (days < 0) return 0;
  if (days <= 7) return 0;
  if (days <= 30) return 1;
  return 2;
}

class FleetVehicleDetailScreen extends StatefulWidget {
  final FleetVehicle? vehicle;
  final String? vehicleId;
  final UserModel currentUser;
  /// Whether the viewer can edit/delete the vehicle and manage its parts —
  /// true for fleet-access admins (the default, matching existing call
  /// sites), false for a plain assigned driver opening from "My Vehicles"
  /// or a notification tap, who only gets check-in/out + read-only info.
  final bool canManage;
  const FleetVehicleDetailScreen({
    super.key,
    this.vehicle,
    this.vehicleId,
    required this.currentUser,
    this.canManage = true,
  }) : assert(vehicle != null || vehicleId != null, 'Provide either vehicle or vehicleId');

  @override
  State<FleetVehicleDetailScreen> createState() => _FleetVehicleDetailScreenState();
}

class _FleetVehicleDetailScreenState extends State<FleetVehicleDetailScreen> {
  FleetVehicle? _vehicle;
  bool _loadingVehicle = false;
  String? _loadError;
  List<FleetVehiclePart> _parts = [];
  bool _loadingParts = true;
  List<FleetCheckin> _checkins = [];
  bool _loadingCheckins = true;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _vehicle = widget.vehicle;
      _loadParts();
      _loadCheckins();
    } else {
      _loadVehicle();
    }
  }

  Future<void> _loadVehicle() async {
    setState(() => _loadingVehicle = true);
    try {
      final v = await FleetService.getVehicleById(widget.vehicleId!);
      if (!mounted) return;
      setState(() {
        _vehicle = v;
        _loadingVehicle = false;
      });
      if (v != null) {
        _loadParts();
        _loadCheckins();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVehicle = false;
        _loadError = '$e';
      });
    }
  }

  Future<void> _loadCheckins() async {
    setState(() => _loadingCheckins = true);
    try {
      final checkins = await FleetService.getCheckins(_vehicle!.id);
      if (!mounted) return;
      setState(() {
        _checkins = checkins;
        _loadingCheckins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCheckins = false);
    }
  }

  Future<void> _checkInOrOut(String type) async {
    final saved = await showFleetCheckinDialog(
      context,
      vehicleId: _vehicle!.id,
      driverUserId: widget.currentUser.id,
      type: type,
      currentOdometer: _vehicle!.currentOdometer,
    );
    if (saved == true) {
      _loadCheckins();
      // Refresh the vehicle so the header's current-odometer reflects the
      // just-logged reading (the DB trigger already updated it server-side).
      final v = await FleetService.getVehicleById(_vehicle!.id);
      if (mounted && v != null) setState(() => _vehicle = v);
    }
  }

  Future<void> _loadParts() async {
    setState(() => _loadingParts = true);
    try {
      final parts = await FleetService.getParts(_vehicle!.id);
      if (!mounted) return;
      setState(() {
        _parts = parts;
        _loadingParts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingParts = false);
    }
  }

  Color _dateColor(DateTime? date) {
    final days = fleetDaysUntil(date);
    if (days == null) return Colors.grey.shade700;
    if (days < 0) return Colors.red.shade700;
    if (days <= 7) return Colors.red.shade600;
    if (days <= 30) return Colors.amber.shade700;
    return Colors.grey.shade800;
  }

  Future<void> _edit() async {
    if (!widget.canManage) return; // defense in depth — UI already hides this action
    final saved = await showFleetVehicleFormDialog(context, currentUser: widget.currentUser, vehicle: _vehicle);
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!widget.canManage) return; // defense in depth — UI already hides this action
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'تأكيد الحذف' : 'Confirm delete'),
        content: Text(isAr
            ? 'هل أنت متأكد من حذف المركبة ${_vehicle!.vehicleNumber}؟ لا يمكن التراجع عن هذا الإجراء.'
            : 'Delete vehicle ${_vehicle!.vehicleNumber}? This cannot be undone.'),
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
    try {
      await FleetService.deleteVehicle(_vehicle!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تعذر الحذف' : 'Could not delete')));
      }
    }
  }

  Future<void> _addPart() async {
    if (!widget.canManage) return;
    final saved = await showFleetPartFormDialog(context, vehicleId: _vehicle!.id);
    if (saved) _loadParts();
  }

  Future<void> _editPart(FleetVehiclePart part) async {
    if (!widget.canManage) return;
    final saved = await showFleetPartFormDialog(
      context,
      vehicleId: _vehicle!.id,
      partId: part.id,
      initialName: part.partName,
      initialAlertKm: part.alertKm,
      initialNotes: part.notes,
    );
    if (saved) _loadParts();
  }

  Future<void> _deletePart(FleetVehiclePart part) async {
    if (!widget.canManage) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'حذف القطعة؟' : 'Delete part?'),
        content: Text(part.partName),
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
    try {
      await FleetService.deletePart(part.id);
      _loadParts();
    } catch (_) {}
  }

  Future<void> _updatePartStatus(String id, String status) async {
    if (!widget.canManage) return;
    try {
      await FleetService.updatePart(id, status: status);
      _loadParts();
    } catch (_) {}
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 15, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor ?? Colors.grey[850]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required List<Widget> rows, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6),
              ),
            ),
            if (trailing != null) trailing,
          ]),
          const Divider(height: 20),
          ...rows,
        ],
      ),
    );
  }

  Widget _urgencyChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _warningItem(FleetAlert alert, bool isAr) {
    final color = alert.level == FleetAlertLevel.critical ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => openFleetVehicleWhatsApp(context, _vehicle!.id, reason: alert.message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(alert.level == FleetAlertLevel.critical ? Icons.error_outline : Icons.warning_amber_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(alert.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(alert.message, style: TextStyle(fontSize: 12.5, color: Colors.grey[800])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF128C7E)),
          ),
        ]),
      ),
    );
  }

  Widget _warningsSection(bool isAr, List<FleetAlert> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warnings.isEmpty ? Colors.grey.shade200 : const Color(0xFFDC2626).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_active_outlined, size: 16, color: warnings.isEmpty ? AppColors.primary : const Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr ? 'تنبيهات هذه المركبة' : 'WARNINGS FOR THIS VEHICLE',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6),
              ),
            ),
            if (warnings.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${warnings.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
              ),
          ]),
          const Divider(height: 20),
          if (warnings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Text(isAr ? 'لا توجد تنبيهات حالياً' : 'No active warnings', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
            )
          else ...[
            Text(
              isAr ? 'اضغط على أي تنبيه لإرسال رسالة واتساب للسائق' : 'Tap a warning to send the driver a WhatsApp message',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
            ),
            const SizedBox(height: 10),
            ...warnings.map((w) => _warningItem(w, isAr)),
          ],
        ],
      ),
    );
  }

  Widget _partSidebarItem(FleetVehiclePart part, bool isAr) {
    final st = fleetPartStatusOptions.firstWhere((s) => s.$1 == part.status, orElse: () => fleetPartStatusOptions[0]);
    final color = st.$4;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade100),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(st.$5, size: 15, color: color.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(part.partName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            ),
            if (widget.canManage) ...[
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _editPart(part),
                child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.edit_outlined, size: 14, color: Colors.grey[500])),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _deletePart(part),
                child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.delete_outline, size: 14, color: Colors.red[400])),
              ),
            ],
          ]),
          if (part.notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(part.notes, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
          const SizedBox(height: 2),
          Text(
            isAr ? 'تنبيه كل ${fleetFormatNumber(part.alertKm)} كم' : 'Alert every ${fleetFormatNumber(part.alertKm)} km',
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: DropdownButtonFormField<String>(
              initialValue: part.status,
              isDense: true,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade700),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: color.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: color.shade200)),
              ),
              items: fleetPartStatusOptions.map((s) => DropdownMenuItem(value: s.$1, child: Text(isAr ? s.$2 : s.$3))).toList(),
              onChanged: !widget.canManage
                  ? null
                  : (v) {
                      if (v != null) _updatePartStatus(part.id, v);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkinHistoryItem(FleetCheckin c, bool isAr) {
    final isCheckIn = c.type == 'check_in';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(c.photoUrl!, width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Colors.grey.shade200)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckIn ? (isAr ? 'تسجيل دخول' : 'Check-in') : (isAr ? 'تسجيل خروج' : 'Check-out'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCheckIn ? const Color(0xFF16A34A) : const Color(0xFF135467),
                  ),
                ),
                Text(
                  '${fleetFormatNumber(c.odometer)} ${isAr ? 'كم' : 'km'}'
                  '${c.driverName != null ? ' · ${c.driverName}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                Text(
                  '${c.createdAt.day.toString().padLeft(2, '0')}/${c.createdAt.month.toString().padLeft(2, '0')}/${c.createdAt.year} '
                  '${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkinSection(bool isAr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.speed_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr ? 'تسجيل الدخول / الخروج' : 'CHECK-IN / CHECK-OUT',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6),
              ),
            ),
          ]),
          const Divider(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _checkInOrOut('check_in'),
                icon: const Icon(Icons.login, size: 15),
                label: Text(isAr ? 'دخول' : 'Check-in', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _checkInOrOut('check_out'),
                icon: const Icon(Icons.logout, size: 15),
                label: Text(isAr ? 'خروج' : 'Check-out', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_loadingCheckins)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
          else if (_checkins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(isAr ? 'لا يوجد سجل بعد' : 'No check-ins yet', style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
            )
          else
            ..._checkins.take(5).map((c) => _checkinHistoryItem(c, isAr)),
        ],
      ),
    );
  }

  Widget _partsSidebar(bool isAr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.build_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr ? 'القطع' : 'PARTS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.6),
              ),
            ),
            if (widget.canManage)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _addPart,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.add, size: 16, color: AppColors.primary),
                ),
              ),
          ]),
          const Divider(height: 18),
          if (_loadingParts)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
          else if (_parts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(isAr ? 'لا توجد قطع مسجلة' : 'No parts recorded', style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
            )
          else
            ..._parts.map((p) => _partSidebarItem(p, isAr)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_loadingVehicle) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_vehicle == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black87),
        body: Center(
          child: Text(
            _loadError != null
                ? (isAr ? 'تعذر تحميل المركبة' : 'Could not load the vehicle')
                : (isAr ? 'المركبة غير موجودة' : 'Vehicle not found'),
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    final v = _vehicle!;
    final kmRemaining = v.nextServiceOdometer - v.currentOdometer;
    final serviceLabel = kmRemaining <= 0
        ? (isAr ? 'تجاوز الصيانة بـ ${fleetFormatNumber(kmRemaining.abs())} كم' : 'Overdue by ${fleetFormatNumber(kmRemaining.abs())} km')
        : kmRemaining <= v.serviceAlertKm
            ? (isAr ? 'الصيانة بعد ${fleetFormatNumber(kmRemaining)} كم' : 'Service due in ${fleetFormatNumber(kmRemaining)} km')
            : (isAr ? 'الصيانة على ما يرام' : 'Service OK');

    final worstDateSeverity = [
      _dateSeverity(v.licenseExpiry),
      _dateSeverity(v.insuranceExpiry),
      _dateSeverity(v.tachographExpiry),
      _dateSeverity(v.winterInspectionDate),
    ].reduce((a, b) => a < b ? a : b);
    final docLabel = worstDateSeverity == 0
        ? (isAr ? 'مستندات تحتاج انتباه' : 'Documents need attention')
        : worstDateSeverity == 1
            ? (isAr ? 'مستندات تقترب من الانتهاء' : 'Documents expiring soon')
            : (isAr ? 'المستندات سارية' : 'Documents up to date');

    final partsNeedingAttention = _parts.where((p) => p.status != 'good').length;

    final warnings = generateFleetAlerts([v], _parts, isAr: isAr);
    final warningsCount = warnings.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 192,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            surfaceTintColor: Colors.white,
            elevation: 0,
            actions: [
              if (widget.canManage) ...[
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
                IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)), onPressed: _delete),
              ],
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                // SingleChildScrollView (rather than a plain Column) absorbs any
                // remaining overflow during the SliverAppBar's collapse animation
                // instead of throwing a RenderFlex overflow error — the header's
                // natural content height doesn't always fit the interpolated
                // height Flutter gives this background mid-scroll.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.vehicleNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text(
                              [if (v.vehicleType.isNotEmpty) v.vehicleType, if (v.manufacturer.isNotEmpty) v.manufacturer].join(' · '),
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _urgencyChip(icon: Icons.speed_outlined, label: serviceLabel, color: kmRemaining <= 0 ? const Color(0xFFDC2626) : kmRemaining <= v.serviceAlertKm ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                      _urgencyChip(icon: Icons.fact_check_outlined, label: docLabel, color: worstDateSeverity == 0 ? const Color(0xFFDC2626) : worstDateSeverity == 1 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                      if (partsNeedingAttention > 0)
                        _urgencyChip(
                          icon: Icons.build_outlined,
                          color: const Color(0xFFD97706),
                          label: isAr ? '$partsNeedingAttention قطعة تحتاج متابعة' : '$partsNeedingAttention part(s) need attention',
                        ),
                      if (warningsCount > 0)
                        _urgencyChip(
                          icon: Icons.notifications_active_outlined,
                          color: const Color(0xFFDC2626),
                          label: isAr ? '$warningsCount تنبيه نشط' : '$warningsCount active warning(s)',
                        ),
                    ]),
                  ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: LayoutBuilder(builder: (context, constraints) {
                    const sidebarWidth = 300.0;
                    final wide = constraints.maxWidth >= 900;
                    final gridWidth = wide ? constraints.maxWidth - sidebarWidth - 16 : constraints.maxWidth;
                    final columns = gridWidth >= 1000 ? 3 : (gridWidth >= 640 ? 2 : 1);
                    final cardWidth = columns == 1 ? gridWidth : (gridWidth - (columns - 1) * 16) / columns;

                    final cards = <Widget>[
                      _sectionCard(icon: Icons.local_shipping_outlined, title: isAr ? 'المركبة' : 'VEHICLE', rows: [
                        _row(Icons.confirmation_number_outlined, isAr ? 'رقم المركبة' : 'Number', v.vehicleNumber),
                        _row(Icons.build_outlined, isAr ? 'النوع' : 'Type', v.vehicleType.isEmpty ? '—' : v.vehicleType),
                        _row(Icons.factory_outlined, isAr ? 'المصنع' : 'Manufacturer', v.manufacturer.isEmpty ? '—' : v.manufacturer),
                        _row(Icons.map_outlined, isAr ? 'منطقة العمل' : 'Work area', v.workArea.isEmpty ? '—' : v.workArea),
                        _row(Icons.speed_outlined, isAr ? 'العداد الحالي' : 'Current odometer', '${fleetFormatNumber(v.currentOdometer)} ${isAr ? 'كم' : 'km'}'),
                        _row(
                          Icons.speed_outlined,
                          isAr ? 'الصيانة القادمة' : 'Next service',
                          '${fleetFormatNumber(v.nextServiceOdometer)} ${isAr ? 'كم' : 'km'}',
                          valueColor: kmRemaining <= 0 ? Colors.red.shade700 : kmRemaining <= v.serviceAlertKm ? Colors.amber.shade700 : null,
                        ),
                      ]),
                      _sectionCard(icon: Icons.fact_check_outlined, title: isAr ? 'التواريخ' : 'DATES', rows: [
                        _row(Icons.calendar_today_outlined, isAr ? 'انتهاء الرخصة' : 'License expiry', fleetFormatDate(v.licenseExpiry), valueColor: _dateColor(v.licenseExpiry)),
                        _row(Icons.shield_outlined, isAr ? 'انتهاء التأمين' : 'Insurance expiry', fleetFormatDate(v.insuranceExpiry), valueColor: _dateColor(v.insuranceExpiry)),
                        _row(Icons.calendar_today_outlined, isAr ? 'انتهاء التاكوغراف' : 'Tachograph expiry', fleetFormatDate(v.tachographExpiry), valueColor: _dateColor(v.tachographExpiry)),
                        _row(Icons.ac_unit_outlined, isAr ? 'فحص الشتاء' : 'Winter inspection', fleetFormatDate(v.winterInspectionDate), valueColor: _dateColor(v.winterInspectionDate)),
                        _row(Icons.event_available_outlined, isAr ? 'بداية التأمين' : 'Insurance start', fleetFormatDate(v.insuranceStart)),
                      ]),
                      _sectionCard(icon: Icons.people_outline, title: isAr ? 'السائقون' : 'DRIVERS', rows: [
                        if (v.drivers.isEmpty)
                          _row(Icons.person_outline, isAr ? 'السائق' : 'Driver', '—')
                        else
                          for (final d in v.drivers) ...[
                            _row(
                              Icons.person_outline,
                              d.isPrimary ? (isAr ? 'السائق (أساسي)' : 'Driver (primary)') : (isAr ? 'سائق' : 'Driver'),
                              d.fullName,
                            ),
                            _row(Icons.phone_outlined, isAr ? 'الهاتف' : 'Phone', d.phone?.isNotEmpty == true ? d.phone! : '—'),
                            _row(
                              Icons.supervisor_account_outlined,
                              isAr ? 'المدير المباشر' : 'Direct manager',
                              d.directManagerName?.isNotEmpty == true ? d.directManagerName! : '—',
                            ),
                            if (d != v.drivers.last)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Divider(height: 1)),
                          ],
                        if (v.whatsappGroupNumber?.isNotEmpty == true) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1)),
                          _row(Icons.groups_outlined, isAr ? 'مجموعة واتساب' : 'WhatsApp group', v.whatsappGroupNumber!, valueColor: const Color(0xFF128C7E)),
                        ],
                      ]),
                    ];

                    final grid = Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
                    );
                    final sidebar = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _checkinSection(isAr),
                        const SizedBox(height: 16),
                        _warningsSection(isAr, warnings),
                        const SizedBox(height: 16),
                        _partsSidebar(isAr),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sidebar,
                          const SizedBox(height: 16),
                          grid,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: grid),
                        const SizedBox(width: 16),
                        SizedBox(width: sidebarWidth, child: sidebar),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
