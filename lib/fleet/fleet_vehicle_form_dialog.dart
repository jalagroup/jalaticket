import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show DepartmentModel, UserModel, UserType;
import 'fleet_models.dart';
import 'fleet_notify.dart';
import 'fleet_service.dart';
import 'fleet_user_picker.dart';

/// Create/edit a fleet vehicle. Returns true via Navigator.pop if saved.
Future<bool?> showFleetVehicleFormDialog(
  BuildContext context, {
  required UserModel currentUser,
  FleetVehicle? vehicle,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FleetVehicleFormDialog(currentUser: currentUser, vehicle: vehicle),
  );
}

class FleetVehicleFormDialog extends StatefulWidget {
  final UserModel currentUser;
  final FleetVehicle? vehicle;
  const FleetVehicleFormDialog({super.key, required this.currentUser, this.vehicle});

  @override
  State<FleetVehicleFormDialog> createState() => _FleetVehicleFormDialogState();
}

class _FleetVehicleFormDialogState extends State<FleetVehicleFormDialog> {
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _currentOdometerCtrl = TextEditingController(text: '0');
  final _nextServiceOdometerCtrl = TextEditingController(text: '10000');
  final _serviceAlertKmCtrl = TextEditingController(text: '8000');
  final _workAreaCtrl = TextEditingController();
  final _whatsappGroupCtrl = TextEditingController();

  DateTime? _licenseExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _insuranceStart;
  DateTime? _tachographExpiry;
  DateTime? _winterInspectionDate;

  List<UserModel> _drivers = [];
  String? _primaryDriverId;
  String? _selectedDepartmentId;

  List<DepartmentModel> _departments = [];
  bool _loadingDepartments = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _vehicleNumberCtrl.text = v.vehicleNumber;
      _vehicleTypeCtrl.text = v.vehicleType;
      _manufacturerCtrl.text = v.manufacturer;
      _currentOdometerCtrl.text = v.currentOdometer.toString();
      _nextServiceOdometerCtrl.text = v.nextServiceOdometer.toString();
      _serviceAlertKmCtrl.text = v.serviceAlertKm.toString();
      _workAreaCtrl.text = v.workArea;
      _whatsappGroupCtrl.text = v.whatsappGroupNumber ?? '';
      _licenseExpiry = v.licenseExpiry;
      _insuranceExpiry = v.insuranceExpiry;
      _insuranceStart = v.insuranceStart;
      _tachographExpiry = v.tachographExpiry;
      _winterInspectionDate = v.winterInspectionDate;
      _selectedDepartmentId = v.departmentId;
      _drivers = v.drivers
          .map((d) => UserModel(
                id: d.userId,
                email: '',
                fullName: d.fullName,
                phone: d.phone,
                userType: d.userType ?? UserType.user,
                isActive: true,
                language: 'en',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();
      _primaryDriverId = v.primaryDriver?.userId;
    }
    _loadDepartments();
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _manufacturerCtrl.dispose();
    _currentOdometerCtrl.dispose();
    _nextServiceOdometerCtrl.dispose();
    _serviceAlertKmCtrl.dispose();
    _workAreaCtrl.dispose();
    _whatsappGroupCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await FleetService.getEligibleDepartments(widget.currentUser);
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _selectedDepartmentId ??= depts.isNotEmpty ? depts.first.id : null;
        _loadingDepartments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDepartments = false);
    }
  }

  Future<void> _pickDate(bool isAr, DateTime? current, void Function(DateTime?) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickDrivers(bool isAr) async {
    final picked = await showFleetUserMultiPicker(
      context,
      title: isAr ? 'اختر السائقين' : 'Select drivers',
      initiallySelected: _drivers,
    );
    if (picked != null) {
      setState(() {
        _drivers = picked;
        if (!_drivers.any((d) => d.id == _primaryDriverId)) {
          _primaryDriverId = _drivers.isNotEmpty ? _drivers.first.id : null;
        }
      });
    }
  }

  Future<void> _save() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_vehicleNumberCtrl.text.trim().isEmpty) {
      setState(() => _error = isAr ? 'رقم المركبة مطلوب' : 'Vehicle number is required');
      return;
    }
    if (_drivers.isEmpty) {
      setState(() => _error = isAr ? 'يرجى اختيار سائق واحد على الأقل' : 'Please select at least one driver');
      return;
    }
    if (_selectedDepartmentId == null) {
      setState(() => _error = isAr ? 'يرجى اختيار القسم' : 'Please select a department');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final vehicle = FleetVehicle(
        id: widget.vehicle?.id ?? '',
        vehicleNumber: _vehicleNumberCtrl.text.trim(),
        vehicleType: _vehicleTypeCtrl.text.trim(),
        manufacturer: _manufacturerCtrl.text.trim(),
        currentOdometer: int.tryParse(_currentOdometerCtrl.text) ?? 0,
        nextServiceOdometer: int.tryParse(_nextServiceOdometerCtrl.text) ?? 10000,
        serviceAlertKm: int.tryParse(_serviceAlertKmCtrl.text) ?? 8000,
        licenseExpiry: _licenseExpiry,
        insuranceExpiry: _insuranceExpiry,
        insuranceStart: _insuranceStart,
        tachographExpiry: _tachographExpiry,
        winterInspectionDate: _winterInspectionDate,
        drivers: _drivers
            .map((u) => FleetVehicleDriverInfo(
                  userId: u.id,
                  fullName: u.fullName,
                  phone: u.phone,
                  userType: u.userType,
                  isPrimary: u.id == _primaryDriverId,
                ))
            .toList(),
        whatsappGroupNumber: _whatsappGroupCtrl.text.trim().isEmpty ? null : _whatsappGroupCtrl.text.trim(),
        workArea: _workAreaCtrl.text.trim(),
        departmentId: _selectedDepartmentId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String savedId;
      if (_isEditing) {
        savedId = widget.vehicle!.id;
        await FleetService.updateVehicle(savedId, vehicle);
      } else {
        savedId = await FleetService.createVehicle(vehicle, widget.currentUser.id);
      }

      await FleetService.setVehicleDrivers(
        savedId,
        _drivers.map((u) => (userId: u.id, isPrimary: u.id == _primaryDriverId)).toList(),
      );

      // Fire an immediate notification if any warning (e.g. an already-past
      // license expiry) is active right now — don't make the driver wait for
      // the next scheduled Smart Reminders run.
      try {
        await notifyFleetVehicleWarningsNow(vehicle.copyWith(id: savedId), isAr: isAr);
      } catch (_) {
        // Non-fatal — the save itself already succeeded.
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = isAr ? 'تعذر الحفظ: $e' : 'Could not save: $e';
        });
      }
    }
  }

  InputDecoration _decor(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.primary) : null,
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _dateField(String label, DateTime? value, VoidCallback onTap, bool isAr) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _decor(label, icon: Icons.calendar_today_outlined),
        child: Text(
          value != null ? fleetFormatDate(value) : (isAr ? 'غير محدد' : 'Not set'),
          style: TextStyle(fontSize: 13, color: value != null ? Colors.grey[850] : Colors.grey[400]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final lang = Localizations.localeOf(context).languageCode;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditing ? (isAr ? 'تعديل مركبة' : 'Edit vehicle') : (isAr ? 'إضافة مركبة' : 'Add vehicle'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[850]),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _saving ? null : () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                    Row(children: [
                      Expanded(child: TextField(controller: _vehicleNumberCtrl, decoration: _decor(isAr ? 'رقم المركبة *' : 'Vehicle number *', icon: Icons.numbers))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _vehicleTypeCtrl, decoration: _decor(isAr ? 'النوع' : 'Type'))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: _manufacturerCtrl, decoration: _decor(isAr ? 'الشركة المصنعة' : 'Manufacturer'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _workAreaCtrl, decoration: _decor(isAr ? 'منطقة العمل' : 'Work area', icon: Icons.map_outlined))),
                    ]),
                    const SizedBox(height: 16),
                    Text(isAr ? 'القسم' : 'Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    _loadingDepartments
                        ? const LinearProgressIndicator()
                        : _departments.isEmpty
                            ? Text(
                                isAr ? 'لا توجد أقسام لديها صلاحية الأسطول' : 'No departments have fleet access enabled',
                                style: TextStyle(fontSize: 12, color: Colors.red[400]),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedDepartmentId,
                                isDense: true,
                                decoration: _decor(isAr ? 'القسم *' : 'Department *', icon: Icons.business_outlined),
                                items: _departments
                                    .map((d) => DropdownMenuItem(value: d.id, child: Text(d.localizedName(lang), style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedDepartmentId = v),
                              ),
                    const SizedBox(height: 16),
                    Text(isAr ? 'العداد والصيانة' : 'Odometer & service', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: TextField(controller: _currentOdometerCtrl, keyboardType: TextInputType.number, decoration: _decor(isAr ? 'العداد الحالي' : 'Current odometer', icon: Icons.speed_outlined))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _nextServiceOdometerCtrl, keyboardType: TextInputType.number, decoration: _decor(isAr ? 'الصيانة القادمة عند' : 'Next service at'))),
                    ]),
                    const SizedBox(height: 10),
                    TextField(controller: _serviceAlertKmCtrl, keyboardType: TextInputType.number, decoration: _decor(isAr ? 'تنبيه قبل (كم)' : 'Alert before (km)')),
                    const SizedBox(height: 16),
                    Text(isAr ? 'التواريخ' : 'Dates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _dateField(isAr ? 'انتهاء الرخصة' : 'License expiry', _licenseExpiry, () => _pickDate(isAr, _licenseExpiry, (d) => _licenseExpiry = d), isAr)),
                      const SizedBox(width: 10),
                      Expanded(child: _dateField(isAr ? 'انتهاء التأمين' : 'Insurance expiry', _insuranceExpiry, () => _pickDate(isAr, _insuranceExpiry, (d) => _insuranceExpiry = d), isAr)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _dateField(isAr ? 'بداية التأمين' : 'Insurance start', _insuranceStart, () => _pickDate(isAr, _insuranceStart, (d) => _insuranceStart = d), isAr)),
                      const SizedBox(width: 10),
                      Expanded(child: _dateField(isAr ? 'انتهاء التاكوغراف' : 'Tachograph expiry', _tachographExpiry, () => _pickDate(isAr, _tachographExpiry, (d) => _tachographExpiry = d), isAr)),
                    ]),
                    const SizedBox(height: 10),
                    _dateField(isAr ? 'فحص الشتاء' : 'Winter inspection', _winterInspectionDate, () => _pickDate(isAr, _winterInspectionDate, (d) => _winterInspectionDate = d), isAr),
                    const SizedBox(height: 16),
                    Row(children: [
                      Text(isAr ? 'السائقون' : 'Drivers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _pickDrivers(isAr),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: Text(isAr ? 'إضافة/تعديل' : 'Add / edit', style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    _drivers.isEmpty
                        ? InkWell(
                            onTap: () => _pickDrivers(isAr),
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: _decor(isAr ? 'السائقون *' : 'Drivers *', icon: Icons.person_outline),
                              child: Text(
                                isAr ? 'اختر سائقاً واحداً أو أكثر' : 'Select one or more drivers',
                                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _drivers.map((u) {
                              final isPrimary = u.id == _primaryDriverId;
                              return GestureDetector(
                                onTap: () => setState(() => _primaryDriverId = u.id),
                                child: Chip(
                                  avatar: Icon(
                                    isPrimary ? Icons.star : Icons.star_border,
                                    size: 16,
                                    color: isPrimary ? AppColors.primary : Colors.grey[400],
                                  ),
                                  label: Text(u.fullName, style: const TextStyle(fontSize: 12)),
                                  onDeleted: () => setState(() {
                                    _drivers = _drivers.where((d) => d.id != u.id).toList();
                                    if (_primaryDriverId == u.id) {
                                      _primaryDriverId = _drivers.isNotEmpty ? _drivers.first.id : null;
                                    }
                                  }),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                ),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(isAr ? 'تنبيهات واتساب' : 'WhatsApp alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    ]),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _whatsappGroupCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _decor(isAr ? 'رقم مجموعة واتساب (اختياري)' : 'WhatsApp group number (optional)', icon: Icons.groups_outlined),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'إذا تم تعيينه، تُرسل التنبيهات إلى هذا الرقم بدلاً من السائق مباشرة، وتتضمن الرسالة بيانات السائق والمركبة.'
                          : 'If set, alerts are sent here instead of the driver directly — the message includes the driver and vehicle details.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(isAr ? 'إلغاء' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEditing ? (isAr ? 'حفظ' : 'Save') : (isAr ? 'إضافة' : 'Add'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
