import '../models.dart' show UserType;

class FleetVehicleDriverInfo {
  final String userId;
  final String fullName;
  final String? phone;
  final UserType? userType;
  final bool isPrimary;
  // The driver's own system-wide direct manager (users.direct_manager_id),
  // NOT a vehicle-level field — informational only, populated via a nested
  // embed when available.
  final String? directManagerId;
  final String? directManagerName;

  const FleetVehicleDriverInfo({
    required this.userId,
    required this.fullName,
    this.phone,
    this.userType,
    this.isPrimary = false,
    this.directManagerId,
    this.directManagerName,
  });

  factory FleetVehicleDriverInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final directManager = user?['direct_manager'] as Map<String, dynamic>?;
    return FleetVehicleDriverInfo(
      userId: (user?['id'] ?? json['user_id']) as String,
      fullName: user?['full_name'] ?? '',
      phone: user?['phone'],
      userType: user?['user_type'] != null ? UserType.fromString(user!['user_type']) : null,
      isPrimary: json['is_primary'] as bool? ?? false,
      directManagerId: directManager?['id'],
      directManagerName: directManager?['full_name'],
    );
  }
}

class FleetCheckin {
  final String id;
  final String vehicleId;
  final String? driverUserId;
  final String? driverName;
  final String type; // 'check_in' | 'check_out'
  final int odometer;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;

  const FleetCheckin({
    required this.id,
    required this.vehicleId,
    this.driverUserId,
    this.driverName,
    required this.type,
    required this.odometer,
    this.photoUrl,
    this.notes,
    required this.createdAt,
  });

  factory FleetCheckin.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    return FleetCheckin(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      driverUserId: json['driver_user_id'],
      driverName: driver?['full_name'],
      type: json['type'] ?? 'check_in',
      odometer: (json['odometer'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FleetVehicle {
  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String manufacturer;
  final int currentOdometer;
  final int nextServiceOdometer;
  final int serviceAlertKm;
  final DateTime? licenseExpiry;
  final DateTime? insuranceExpiry;
  final DateTime? insuranceStart;
  final DateTime? tachographExpiry;
  final DateTime? winterInspectionDate;
  // All drivers currently assigned to this vehicle (many-to-many via
  // fleet_vehicle_drivers), populated via an embedded join when loading.
  final List<FleetVehicleDriverInfo> drivers;
  /// Optional WhatsApp group/dispatch number. When set, alerts go here
  /// instead of the driver directly (with driver + vehicle details folded
  /// into the message so the group still has context).
  final String? whatsappGroupNumber;
  final String workArea;
  final String departmentId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FleetVehicle({
    required this.id,
    required this.vehicleNumber,
    this.vehicleType = '',
    this.manufacturer = '',
    this.currentOdometer = 0,
    this.nextServiceOdometer = 10000,
    this.serviceAlertKm = 8000,
    this.licenseExpiry,
    this.insuranceExpiry,
    this.insuranceStart,
    this.tachographExpiry,
    this.winterInspectionDate,
    this.drivers = const [],
    this.whatsappGroupNumber,
    this.workArea = '',
    required this.departmentId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
    final assignedDrivers = json['assigned_drivers'] as List?;
    return FleetVehicle(
      id: json['id'],
      vehicleNumber: json['vehicle_number'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      currentOdometer: (json['current_odometer'] as num?)?.toInt() ?? 0,
      nextServiceOdometer: (json['next_service_odometer'] as num?)?.toInt() ?? 10000,
      serviceAlertKm: (json['service_alert_km'] as num?)?.toInt() ?? 8000,
      licenseExpiry: parseDate(json['license_expiry']),
      insuranceExpiry: parseDate(json['insurance_expiry']),
      insuranceStart: parseDate(json['insurance_start']),
      tachographExpiry: parseDate(json['tachograph_expiry']),
      winterInspectionDate: parseDate(json['winter_inspection_date']),
      drivers: (assignedDrivers ?? [])
          .map((d) => FleetVehicleDriverInfo.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      whatsappGroupNumber: json['whatsapp_group_number'],
      workArea: json['work_area'] ?? '',
      departmentId: json['department_id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  FleetVehicle copyWith({String? id}) => FleetVehicle(
        id: id ?? this.id,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        manufacturer: manufacturer,
        currentOdometer: currentOdometer,
        nextServiceOdometer: nextServiceOdometer,
        serviceAlertKm: serviceAlertKm,
        licenseExpiry: licenseExpiry,
        insuranceExpiry: insuranceExpiry,
        insuranceStart: insuranceStart,
        tachographExpiry: tachographExpiry,
        winterInspectionDate: winterInspectionDate,
        drivers: drivers,
        whatsappGroupNumber: whatsappGroupNumber,
        workArea: workArea,
        departmentId: departmentId,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Payload for insert/update — excludes id/timestamps/denormalized driver
  /// fields. Driver assignment is written separately via
  /// FleetService.setVehicleDrivers (many-to-many, not a scalar column).
  Map<String, dynamic> toPayload() => {
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'manufacturer': manufacturer,
        'current_odometer': currentOdometer,
        'next_service_odometer': nextServiceOdometer,
        'service_alert_km': serviceAlertKm,
        'license_expiry': licenseExpiry?.toIso8601String().split('T').first,
        'insurance_expiry': insuranceExpiry?.toIso8601String().split('T').first,
        'insurance_start': insuranceStart?.toIso8601String().split('T').first,
        'tachograph_expiry': tachographExpiry?.toIso8601String().split('T').first,
        'winter_inspection_date': winterInspectionDate?.toIso8601String().split('T').first,
        'whatsapp_group_number': whatsappGroupNumber,
        'work_area': workArea,
        'department_id': departmentId,
      };

  FleetVehicleDriverInfo? get primaryDriver {
    if (drivers.isEmpty) return null;
    return drivers.firstWhere((d) => d.isPrimary, orElse: () => drivers.first);
  }
}

class FleetVehiclePart {
  final String id;
  final String vehicleId;
  final String partName;
  final int installedAtOdometer;
  final int alertKm;
  final int lastCheckedOdometer;
  final String status; // good | watch | replace
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FleetVehiclePart({
    required this.id,
    required this.vehicleId,
    required this.partName,
    this.installedAtOdometer = 0,
    this.alertKm = 10000,
    this.lastCheckedOdometer = 0,
    this.status = 'good',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory FleetVehiclePart.fromJson(Map<String, dynamic> json) {
    return FleetVehiclePart(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      partName: json['part_name'] ?? '',
      installedAtOdometer: (json['installed_at_odometer'] as num?)?.toInt() ?? 0,
      alertKm: (json['alert_km'] as num?)?.toInt() ?? 10000,
      lastCheckedOdometer: (json['last_checked_odometer'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'good',
      notes: json['notes'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

enum FleetAlertLevel { critical, warning }

class FleetAlert {
  final String id;
  final String vehicleId;
  final String vehicleNumber;
  final FleetAlertLevel level;
  final String category;
  final String message;

  const FleetAlert({
    required this.id,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.level,
    required this.category,
    required this.message,
  });
}

String fleetFormatDate(DateTime? date, {bool isAr = true}) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String fleetFormatNumber(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Days from today until [date]; negative if already past. Null if [date] is null.
int? fleetDaysUntil(DateTime? date) {
  if (date == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

/// Ported from the reference app's `generateAlerts` (Downloads/project/src/lib/types.ts).
/// Same thresholds: 30-day warning / 7-day critical on each expiry date,
/// service_alert_km for the odometer-based service alert.
List<FleetAlert> generateFleetAlerts(List<FleetVehicle> vehicles, List<FleetVehiclePart> parts, {bool isAr = true}) {
  final alerts = <FleetAlert>[];

  for (final v in vehicles) {
    final kmRemaining = v.nextServiceOdometer - v.currentOdometer;
    if (kmRemaining <= 0) {
      alerts.add(FleetAlert(
        id: '${v.id}-service-critical',
        vehicleId: v.id,
        vehicleNumber: v.vehicleNumber,
        level: FleetAlertLevel.critical,
        category: isAr ? 'صيانة' : 'Service',
        message: isAr
            ? 'تجاوز موعد الصيانة بـ ${fleetFormatNumber(kmRemaining.abs())} كم'
            : 'Overdue for service by ${fleetFormatNumber(kmRemaining.abs())} km',
      ));
    } else if (kmRemaining <= v.serviceAlertKm) {
      alerts.add(FleetAlert(
        id: '${v.id}-service-warn',
        vehicleId: v.id,
        vehicleNumber: v.vehicleNumber,
        level: FleetAlertLevel.warning,
        category: isAr ? 'صيانة' : 'Service',
        message: isAr
            ? 'الصيانة القادمة بعد ${fleetFormatNumber(kmRemaining)} كم'
            : 'Next service in ${fleetFormatNumber(kmRemaining)} km',
      ));
    }

    final dateChecks = <(String, DateTime?)>[
      (isAr ? 'انتهاء الرخصة' : 'License expiry', v.licenseExpiry),
      (isAr ? 'انتهاء التأمين' : 'Insurance expiry', v.insuranceExpiry),
      (isAr ? 'انتهاء التاكوغراف' : 'Tachograph expiry', v.tachographExpiry),
      (isAr ? 'فحص الشتاء' : 'Winter inspection', v.winterInspectionDate),
    ];
    for (final (cat, date) in dateChecks) {
      final days = fleetDaysUntil(date);
      if (days == null) continue;
      if (days < 0) {
        alerts.add(FleetAlert(
          id: '${v.id}-$cat-crit',
          vehicleId: v.id,
          vehicleNumber: v.vehicleNumber,
          level: FleetAlertLevel.critical,
          category: cat,
          message: isAr ? 'منتهي منذ ${days.abs()} يوم' : 'Expired ${days.abs()} days ago',
        ));
      } else if (days <= 7) {
        alerts.add(FleetAlert(
          id: '${v.id}-$cat-crit',
          vehicleId: v.id,
          vehicleNumber: v.vehicleNumber,
          level: FleetAlertLevel.critical,
          category: cat,
          message: isAr ? 'ينتهي بعد $days يوم' : 'Expires in $days days',
        ));
      } else if (days <= 30) {
        alerts.add(FleetAlert(
          id: '${v.id}-$cat-warn',
          vehicleId: v.id,
          vehicleNumber: v.vehicleNumber,
          level: FleetAlertLevel.warning,
          category: cat,
          message: isAr ? 'ينتهي بعد $days يوم' : 'Expires in $days days',
        ));
      }
    }
  }

  for (final p in parts) {
    final vehicleNumber = vehicles.where((v) => v.id == p.vehicleId).map((v) => v.vehicleNumber).firstOrNullOrEmpty;
    if (p.status == 'replace') {
      alerts.add(FleetAlert(
        id: '${p.id}-bad',
        vehicleId: p.vehicleId,
        vehicleNumber: vehicleNumber,
        level: FleetAlertLevel.critical,
        category: isAr ? 'قطعة' : 'Part',
        message: isAr ? '${p.partName} بحاجة استبدال' : '${p.partName} needs replacement',
      ));
    } else if (p.status == 'watch') {
      alerts.add(FleetAlert(
        id: '${p.id}-warn',
        vehicleId: p.vehicleId,
        vehicleNumber: vehicleNumber,
        level: FleetAlertLevel.warning,
        category: isAr ? 'قطعة' : 'Part',
        message: isAr ? '${p.partName} تحت المتابعة' : '${p.partName} under watch',
      ));
    }
  }

  return alerts;
}

extension _FirstOrNullOrEmpty on Iterable<String> {
  String get firstOrNullOrEmpty => isEmpty ? '' : first;
}
