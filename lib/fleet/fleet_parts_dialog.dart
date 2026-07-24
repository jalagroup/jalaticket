import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import 'fleet_service.dart';

const fleetPartStatusOptions = [
  ('good', 'جيد', 'Good', Colors.green, Icons.check_circle_outline),
  ('watch', 'تحت المتابعة', 'Watch', Colors.amber, Icons.visibility_outlined),
  ('replace', 'بحاجة استبدال', 'Replace', Colors.red, Icons.error_outline),
];

/// Compact add/edit form for a single vehicle part — used inline by the
/// Parts sidebar on the vehicle detail screen. Returns true if saved.
Future<bool> showFleetPartFormDialog(
  BuildContext context, {
  required String vehicleId,
  String? partId,
  String? initialName,
  int? initialAlertKm,
  String? initialNotes,
}) async {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final alertKmCtrl = TextEditingController(text: (initialAlertKm ?? 10000).toString());
  final notesCtrl = TextEditingController(text: initialNotes ?? '');
  final isEditing = partId != null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(isEditing ? (isAr ? 'تعديل قطعة' : 'Edit part') : (isAr ? 'إضافة قطعة' : 'Add part')),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: isAr ? 'اسم القطعة' : 'Part name', isDense: true, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertKmCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: isAr ? 'تنبيه كل (كم)' : 'Alert every (km)', isDense: true, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(labelText: isAr ? 'ملاحظات' : 'Notes', isDense: true, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: Text(isEditing ? (isAr ? 'حفظ' : 'Save') : (isAr ? 'إضافة' : 'Add')),
        ),
      ],
    ),
  );

  if (saved != true || nameCtrl.text.trim().isEmpty) return false;
  final alertKm = int.tryParse(alertKmCtrl.text) ?? 10000;
  try {
    if (isEditing) {
      await FleetService.updatePart(partId, partName: nameCtrl.text.trim(), alertKm: alertKm, notes: notesCtrl.text.trim());
    } else {
      await FleetService.createPart(vehicleId: vehicleId, partName: nameCtrl.text.trim(), alertKm: alertKm, notes: notesCtrl.text.trim());
    }
    return true;
  } catch (_) {
    return false;
  }
}
