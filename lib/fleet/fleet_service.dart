import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import '../main.dart' show supabase;
import '../models.dart' show DepartmentModel, UserModel, UserType;
import 'fleet_models.dart';

// Note: assigned_drivers.user.direct_manager is a 3-level nested PostgREST
// embed (vehicle -> fleet_vehicle_drivers -> users -> users). It's purely
// informational for the UI — notification logic resolves managers via its
// own direct query instead of relying on this, so if it ever fails to
// resolve the fallback is just a blank manager label, not a functional break.
const _kFleetVehicleSelect =
    '*, assigned_drivers:fleet_vehicle_drivers(is_primary, user:users(id, full_name, phone, user_type, '
    'direct_manager:users!users_direct_manager_id_fkey(id, full_name)))';

class FleetService {
  /// RLS already scopes rows to what the caller is allowed to see, so no
  /// client-side department filtering is needed here.
  static Future<List<FleetVehicle>> getVehicles() async {
    final rows = await supabase
        .from('fleet_vehicles')
        .select(_kFleetVehicleSelect)
        .order('created_at', ascending: false);
    return rows.map<FleetVehicle>((j) => FleetVehicle.fromJson(j)).toList();
  }

  static Future<FleetVehicle?> getVehicleById(String id) async {
    final row = await supabase
        .from('fleet_vehicles')
        .select(_kFleetVehicleSelect)
        .eq('id', id)
        .maybeSingle();
    return row != null ? FleetVehicle.fromJson(row) : null;
  }

  /// Replace-all: clears the vehicle's current driver assignments and
  /// inserts the new set. [drivers] is a list of (userId, isPrimary) pairs.
  static Future<void> setVehicleDrivers(
      String vehicleId, List<({String userId, bool isPrimary})> drivers) async {
    await supabase.from('fleet_vehicle_drivers').delete().eq('vehicle_id', vehicleId);
    if (drivers.isEmpty) return;
    await supabase.from('fleet_vehicle_drivers').insert(drivers
        .map((d) => {
              'vehicle_id': vehicleId,
              'user_id': d.userId,
              'is_primary': d.isPrimary,
            })
        .toList());
  }

  /// Vehicles the given user is an assigned driver of ("My Vehicles").
  static Future<List<FleetVehicle>> getVehiclesForUser(String userId) async {
    final rows = await supabase
        .from('fleet_vehicle_drivers')
        .select('vehicle:fleet_vehicles($_kFleetVehicleSelect)')
        .eq('user_id', userId);
    return rows
        .map<Map<String, dynamic>?>((j) => j['vehicle'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map<FleetVehicle>((j) => FleetVehicle.fromJson(j))
        .toList();
  }

  static Future<void> createCheckin({
    required String vehicleId,
    required String driverUserId,
    required String type, // 'check_in' | 'check_out'
    required int odometer,
    Uint8List? photoBytes,
    String? photoFileName,
    String? notes,
  }) async {
    String? photoUrl;
    if (photoBytes != null) {
      final ext = (photoFileName != null && photoFileName.contains('.'))
          ? photoFileName.split('.').last
          : 'jpg';
      final path = 'checkins/$vehicleId/${const Uuid().v4()}.$ext';
      await supabase.storage.from('fleet_checkin_photos').uploadBinary(
            path,
            photoBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      photoUrl = supabase.storage.from('fleet_checkin_photos').getPublicUrl(path);
    }
    await supabase.from('fleet_vehicle_checkins').insert({
      'vehicle_id': vehicleId,
      'driver_user_id': driverUserId,
      'type': type,
      'odometer': odometer,
      'photo_url': photoUrl,
      'notes': notes,
    });
  }

  static Future<List<FleetCheckin>> getCheckins(String vehicleId, {int limit = 20}) async {
    final rows = await supabase
        .from('fleet_vehicle_checkins')
        .select('*, driver:users!fleet_vehicle_checkins_driver_user_id_fkey(full_name)')
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<FleetCheckin>((j) => FleetCheckin.fromJson(j)).toList();
  }

  static Future<List<FleetVehiclePart>> getParts(String vehicleId) async {
    final rows = await supabase
        .from('fleet_vehicle_parts')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false);
    return rows.map<FleetVehiclePart>((j) => FleetVehiclePart.fromJson(j)).toList();
  }

  static Future<List<FleetVehiclePart>> getAllParts() async {
    final rows = await supabase.from('fleet_vehicle_parts').select();
    return rows.map<FleetVehiclePart>((j) => FleetVehiclePart.fromJson(j)).toList();
  }

  static Future<String> createVehicle(FleetVehicle vehicle, String createdByUserId) async {
    final row = await supabase
        .from('fleet_vehicles')
        .insert({
          ...vehicle.toPayload(),
          'created_by': createdByUserId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<void> updateVehicle(String id, FleetVehicle vehicle) async {
    await supabase.from('fleet_vehicles').update(vehicle.toPayload()).eq('id', id);
  }

  static Future<void> deleteVehicle(String id) async {
    // Parts cascade-delete via the vehicle_id foreign key.
    await supabase.from('fleet_vehicles').delete().eq('id', id);
  }

  static Future<void> createPart({
    required String vehicleId,
    required String partName,
    required int alertKm,
    String notes = '',
  }) async {
    await supabase.from('fleet_vehicle_parts').insert({
      'vehicle_id': vehicleId,
      'part_name': partName,
      'alert_km': alertKm,
      'notes': notes,
      'status': 'good',
    });
  }

  static Future<void> updatePart(
    String id, {
    String? partName,
    int? alertKm,
    String? notes,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (partName != null) data['part_name'] = partName;
    if (alertKm != null) data['alert_km'] = alertKm;
    if (notes != null) data['notes'] = notes;
    if (status != null) data['status'] = status;
    if (data.isEmpty) return;
    await supabase.from('fleet_vehicle_parts').update(data).eq('id', id);
  }

  static Future<void> deletePart(String id) async {
    await supabase.from('fleet_vehicle_parts').delete().eq('id', id);
  }

  /// Departments this user can create/manage fleet vehicles for.
  /// system_admin: all fleet-enabled departments.
  /// super_admin: intersection of their assigned departments and fleet-enabled ones.
  static Future<List<DepartmentModel>> getEligibleDepartments(UserModel currentUser) async {
    final allFleetEnabled = await supabase
        .from('departments')
        .select()
        .eq('fleet_access_enabled', true)
        .order('name');
    final departments = allFleetEnabled.map<DepartmentModel>((j) => DepartmentModel.fromJson(j)).toList();

    if (currentUser.userType == UserType.systemAdmin) return departments;

    final assigned = await supabase
        .from('admin_departments')
        .select('department_id')
        .eq('admin_id', currentUser.id);
    final assignedIds = assigned.map<String>((j) => j['department_id'] as String).toSet();

    return departments.where((d) => assignedIds.contains(d.id)).toList();
  }

  /// Whether the current super admin has fleet access via any assigned
  /// department. System admins are checked separately by the caller.
  static Future<bool> superAdminHasFleetAccess(String userId) async {
    final assigned = await supabase
        .from('admin_departments')
        .select('department_id')
        .eq('admin_id', userId);
    final deptIds = assigned.map<String>((j) => j['department_id'] as String).toList();
    if (deptIds.isEmpty) return false;

    final rows = await supabase
        .from('departments')
        .select('id')
        .inFilter('id', deptIds)
        .eq('fleet_access_enabled', true)
        .limit(1);
    return rows.isNotEmpty;
  }

  static Future<List<UserModel>> getAllActiveUsers() async {
    final rows = await supabase
        .from('users')
        .select()
        .eq('is_active', true)
        .order('full_name');
    return rows.map<UserModel>((j) => UserModel.fromJson(j)).toList();
  }
}
