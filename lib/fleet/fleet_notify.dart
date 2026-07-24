import '../main.dart' show supabase;
import '../services.dart' show NotificationService;
import 'fleet_models.dart';

/// Checks a just-created/edited vehicle for warnings that are ALREADY active
/// (e.g. a license expiry date that's already past, or entered in the past)
/// and immediately notifies the driver(s) AND each driver's direct manager
/// through the app's normal notification system (in-app + push + email,
/// same as everything else) — rather than waiting for the next scheduled
/// Smart Reminders run, which could be up to a day away.
Future<void> notifyFleetVehicleWarningsNow(FleetVehicle vehicle, {required bool isAr}) async {
  if (vehicle.drivers.isEmpty) return;

  final alerts = generateFleetAlerts([vehicle], const [], isAr: isAr);
  if (alerts.isEmpty) return;

  final title = isAr
      ? 'تنبيه: المركبة ${vehicle.vehicleNumber} تحتاج انتباه'
      : 'Alert: vehicle ${vehicle.vehicleNumber} needs attention';
  final message = alerts.map((a) => '${a.category}: ${a.message}').join(isAr ? '، ' : '; ');

  final driverIds = vehicle.drivers.map((d) => d.userId).toSet();

  // 'fleet_alert' is in NotificationService's critical-type list, so email
  // always sends here (not just as a no-push-token fallback) — the user
  // explicitly wants both driver and manager emailed every time.
  for (final driverId in driverIds) {
    await NotificationService.createAndSendNotification(
      userId: driverId,
      type: 'fleet_alert',
      title: title,
      message: message,
      additionalData: {'source_table': 'fleet_vehicles', 'record_id': vehicle.id},
    );
  }

  // Also notify each driver's own direct manager (a system-wide user field,
  // not a vehicle-level one) — queried directly rather than relying on the
  // nested embed on `vehicle.drivers`, so this stays correct even if that
  // embed doesn't resolve.
  try {
    final rows = await supabase
        .from('users')
        .select('id, direct_manager_id')
        .inFilter('id', driverIds.toList());
    final managerIds = rows
        .map((r) => r['direct_manager_id'] as String?)
        .whereType<String>()
        .toSet();
    for (final managerId in managerIds) {
      await NotificationService.createAndSendNotification(
        userId: managerId,
        type: 'fleet_alert',
        title: title,
        message: message,
        additionalData: {'source_table': 'fleet_vehicles', 'record_id': vehicle.id},
      );
    }
  } catch (_) {
    // Non-fatal — the driver(s) were already notified above.
  }
}
