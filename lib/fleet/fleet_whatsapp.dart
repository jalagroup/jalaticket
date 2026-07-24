import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fleet_models.dart';
import 'fleet_service.dart';

/// Digits-only, international-format phone number for a wa.me / WhatsApp Web
/// link. Mirrors AuthService._resolveLoginEmail's local-number convention:
/// a local 0XXXXXXXXX number is assumed to be Israeli (+972).
String? _fleetWhatsAppDigits(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  final trimmed = phone.trim();
  if (trimmed.startsWith('+')) {
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : digits;
  }
  if (RegExp(r'^0\d{9}$').hasMatch(trimmed)) {
    return '972${trimmed.substring(1)}';
  }
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  return digits.isEmpty ? null : digits;
}

/// Fetches the fleet vehicle by [vehicleId] and opens WhatsApp pre-filled
/// with a message (in the current locale) — the user only has to press
/// send. Pass [reason] (already in the caller's locale) to reference the
/// specific warning that triggered this — e.g. from a vehicle's Warnings
/// section — otherwise a generic prompt is used.
///
/// Recipient: if the vehicle has a `whatsappGroupNumber` set (fleet-manager
/// configurable, see the vehicle form), the message goes there instead of
/// the driver directly, with driver + vehicle details folded into the text
/// so the group still has full context. Otherwise it goes to the driver.
///
/// Platform routing:
/// - Web on a desktop-sized viewport: opens web.whatsapp.com directly
///   (skips the wa.me interstitial, drops straight into WhatsApp Web).
/// - Web on a mobile-sized viewport, and the native app on any platform:
///   uses the wa.me link, which hands off to the installed WhatsApp app.
Future<void> openFleetVehicleWhatsApp(BuildContext context, String vehicleId, {String? reason}) async {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  FleetVehicle? vehicle;
  try {
    vehicle = await FleetService.getVehicleById(vehicleId);
  } catch (_) {
    vehicle = null;
  }

  if (!context.mounted) return;

  if (vehicle == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAr ? 'تعذر العثور على المركبة' : 'Could not find the vehicle')),
    );
    return;
  }

  final primaryDriver = vehicle.primaryDriver;
  final groupNumber = vehicle.whatsappGroupNumber?.trim();
  final usingGroup = groupNumber != null && groupNumber.isNotEmpty;
  final digits = _fleetWhatsAppDigits(usingGroup ? groupNumber : primaryDriver?.phone);

  if (digits == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(usingGroup
          ? (isAr ? 'رقم مجموعة الواتساب غير صالح' : 'The WhatsApp group number is invalid')
          : (isAr ? 'لا يوجد رقم هاتف مسجل للسائق' : 'No phone number on file for the driver'))),
    );
    return;
  }

  final vehicleLabel = '${vehicle.vehicleNumber}${vehicle.vehicleType.isNotEmpty ? ' (${vehicle.vehicleType})' : ''}';
  final message = StringBuffer();
  if (usingGroup) {
    message.writeln(isAr ? 'تنبيه بخصوص المركبة رقم $vehicleLabel:' : 'Alert regarding vehicle $vehicleLabel:');
    if (primaryDriver != null && (primaryDriver.fullName.isNotEmpty || primaryDriver.phone?.isNotEmpty == true)) {
      final driverBit = [primaryDriver.fullName, primaryDriver.phone].where((s) => s?.isNotEmpty == true).join(' — ');
      message.writeln(isAr ? 'السائق: $driverBit' : 'Driver: $driverBit');
    }
  } else {
    message.writeln(isAr ? 'مرحباً ${primaryDriver?.fullName ?? ''}،' : 'Hello ${primaryDriver?.fullName ?? ''},');
    message.writeln(isAr ? 'بخصوص المركبة رقم $vehicleLabel:' : 'Regarding vehicle $vehicleLabel:');
  }
  message.writeln(reason ?? (isAr
      ? 'يوجد تنبيه يحتاج إلى متابعتكم، يرجى التواصل في أقرب وقت ممكن.'
      : 'There is an alert that needs your attention — please get in touch as soon as possible.'));

  final text = Uri.encodeComponent(message.toString());
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktopWeb = kIsWeb && screenWidth >= 768;

  final uri = isDesktopWeb
      ? Uri.parse('https://web.whatsapp.com/send?phone=$digits&text=$text')
      : Uri.parse('https://wa.me/$digits?text=$text');

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAr ? 'تعذر فتح واتساب' : 'Could not open WhatsApp')),
    );
  }
}
