import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart' show AppColors;
import '../truck_maintenance_dialog.dart' show showImageSourceBottomSheet;
import 'fleet_service.dart';

/// Log a check-in or check-out for a vehicle: odometer reading + optional
/// status photo + notes. Returns true via Navigator.pop if saved.
Future<bool?> showFleetCheckinDialog(
  BuildContext context, {
  required String vehicleId,
  required String driverUserId,
  required String type, // 'check_in' | 'check_out'
  required int currentOdometer,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FleetCheckinDialog(
      vehicleId: vehicleId,
      driverUserId: driverUserId,
      type: type,
      currentOdometer: currentOdometer,
    ),
  );
}

class _FleetCheckinDialog extends StatefulWidget {
  final String vehicleId;
  final String driverUserId;
  final String type;
  final int currentOdometer;
  const _FleetCheckinDialog({
    required this.vehicleId,
    required this.driverUserId,
    required this.type,
    required this.currentOdometer,
  });

  @override
  State<_FleetCheckinDialog> createState() => _FleetCheckinDialogState();
}

class _FleetCheckinDialogState extends State<_FleetCheckinDialog> {
  late final TextEditingController _odometerCtrl;
  final _notesCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _odometerCtrl = TextEditingController(text: widget.currentOdometer.toString());
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showImageSourceBottomSheet(context);
    if (source == null) return;
    final img = await _imagePicker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoFileName = img.name;
    });
  }

  Future<void> _save() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final odometer = int.tryParse(_odometerCtrl.text.trim());
    if (odometer == null) {
      setState(() => _error = isAr ? 'أدخل قيمة صحيحة للعداد' : 'Enter a valid odometer reading');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FleetService.createCheckin(
        vehicleId: widget.vehicleId,
        driverUserId: widget.driverUserId,
        type: widget.type,
        odometer: odometer,
        photoBytes: _photoBytes,
        photoFileName: _photoFileName,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isCheckIn = widget.type == 'check_in';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  Icon(isCheckIn ? Icons.login : Icons.logout, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCheckIn ? (isAr ? 'تسجيل دخول' : 'Check-in') : (isAr ? 'تسجيل خروج' : 'Check-out'),
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
                    TextField(
                      controller: _odometerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'قراءة العداد (كم)' : 'Odometer reading (km)',
                        prefixIcon: const Icon(Icons.speed_outlined, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(isAr ? 'صورة حالة المركبة (اختياري)' : 'Vehicle status photo (optional)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _photoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(_photoBytes!, fit: BoxFit.cover, width: double.infinity, height: 140),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey[400]),
                                  const SizedBox(height: 6),
                                  Text(isAr ? 'إضافة صورة' : 'Add a photo', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isAr ? 'ملاحظات (اختياري)' : 'Notes (optional)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(isAr ? 'إلغاء' : 'Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
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
