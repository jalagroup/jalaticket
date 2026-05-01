// lib/services/branch_admin_service.dart

import 'package:jalasupport/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

final supabase = Supabase.instance.client;

class BranchAdminService {
  /// Get places assigned to a specific branch admin
  static Future<List<PlaceModel>> getBranchAdminPlaces(String adminId) async {
    try {
      print('🔍 Loading places for branch admin $adminId...');

      final response = await supabase
          .from('branch_admin_places')
          .select(
              'place_id, places(id, name, description, is_active, created_at, updated_at)')
          .eq('admin_id', adminId);

      final places = <PlaceModel>[];
      for (final item in response) {
        if (item['places'] != null) {
          final placeJson = item['places'] as Map<String, dynamic>;
          places.add(PlaceModel.fromJson(placeJson));
        }
      }

      print('✅ Found ${places.length} places for admin');
      return places;
    } catch (e) {
      print('❌ Error loading admin places: $e');
      return [];
    }
  }

  /// Check if a branch admin has access to a specific place
  static Future<bool> hasAccessToPlace(String adminId, String placeId) async {
    try {
      final response = await supabase
          .from('branch_admin_places')
          .select('id')
          .eq('admin_id', adminId)
          .eq('place_id', placeId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking place access: $e');
      return false;
    }
  }

  /// Assign places to a branch admin
  static Future<bool> assignPlacesToBranchAdmin({
    required String adminId,
    required List<String> placeIds,
  }) async {
    try {
      print('🔄 Assigning places to branch admin $adminId...');
      print('📍 Place IDs: $placeIds');

      // Get current user for created_by
      final currentUser = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', supabase.auth.currentUser!.id)
          .single();

      final currentUserId = currentUser['id'] as String;

      // Step 1: Delete all existing assignments for this admin
      await supabase
          .from('branch_admin_places')
          .delete()
          .eq('admin_id', adminId);

      print('✅ Deleted old assignments');

      // Step 2: Insert new assignments
      if (placeIds.isNotEmpty) {
        final assignments = placeIds
            .map((placeId) => {
                  'admin_id': adminId,
                  'place_id': placeId,
                  'created_by': currentUserId,
                })
            .toList();

        await supabase.from('branch_admin_places').insert(assignments);

        print('✅ Inserted ${placeIds.length} new assignments');
      }

      print('✅ Successfully assigned places to branch admin');
      return true;
    } catch (e) {
      print('❌ Error assigning places: $e');
      return false;
    }
  }

  /// Remove a place from branch admin
  static Future<bool> removePlaceFromBranchAdmin({
    required String adminId,
    required String placeId,
  }) async {
    try {
      print('🗑️ Removing place $placeId from branch admin: $adminId');

      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('❌ No authenticated user');
        return false;
      }

      // Check if user is system admin
      if (user.userType != UserType.systemAdmin) {
        print('❌ Only system admins can remove places');
        return false;
      }

      await supabase
          .from('branch_admin_places')
          .delete()
          .eq('admin_id', adminId)
          .eq('place_id', placeId);

      print('✅ Place removed successfully');
      return true;
    } catch (e) {
      print('❌ Error removing place: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>>
      getAllBranchAdminsWithPlaces() async {
    try {
      print('🔍 Loading all branch admins...');

      // Get all branch admins
      final adminsResponse = await supabase
          .from('users')
          .select('id, full_name, email, is_active, profile_image_url')
          .eq('user_type', 'branch_admin')
          .order('full_name', ascending: true);

      print('✅ Found ${adminsResponse.length} branch admins');

      final result = <Map<String, dynamic>>[];

      for (final admin in adminsResponse) {
        final adminId = admin['id'] as String;

        // Get assigned places for this admin
        final placesResponse = await supabase
            .from('branch_admin_places')
            .select('place_id, places(id, name, description, is_active, created_at, updated_at)')
            .eq('admin_id', adminId);

        final places = <PlaceModel>[];
        for (final placeData in placesResponse) {
          if (placeData['places'] != null) {
            final placeJson = placeData['places'] as Map<String, dynamic>;
            places.add(PlaceModel.fromJson(placeJson));
          }
        }

        result.add({
          'admin': admin,
          'places': places,
        });
      }

      print('✅ Loaded ${result.length} branch admins with places');
      return result;
    } catch (e) {
      print('❌ Error loading branch admins: $e');
      rethrow;
    }
  }

  /// Check if a user is a branch admin
  static Future<bool> isBranchAdmin(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('user_type')
          .eq('id', userId)
          .single();

      return response['user_type'] == UserType.branchAdmin.value;
    } catch (e) {
      print('❌ Error checking if user is branch admin: $e');
      return false;
    }
  }

  /// Get all available places (active places)
  static Future<List<PlaceModel>> getAllAvailablePlaces() async {
    try {
      print('🔍 Loading all available places...');

      final response = await supabase
          .from('places')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      final places = response
          .map<PlaceModel>((json) => PlaceModel.fromJson(json))
          .toList();

      print('✅ Found ${places.length} active places');
      return places;
    } catch (e) {
      print('❌ Error loading places: $e');
      rethrow;
    }
  }

  /// Get branch admin details with places
  static Future<Map<String, dynamic>?> getBranchAdminDetails(
      String adminId) async {
    try {
      print('👤 Getting branch admin details: $adminId');

      // Get admin user data
      final adminResponse = await supabase
          .from('users')
          .select(
              'id, full_name, email, is_active, profile_image_url, phone, created_at')
          .eq('id', adminId)
          .eq('user_type', UserType.branchAdmin.value)
          .maybeSingle();

      if (adminResponse == null) {
        print('❌ Branch admin not found');
        return null;
      }

      // Get assigned places
      final places = await getBranchAdminPlaces(adminId);

      return {
        'admin': adminResponse,
        'places': places,
      };
    } catch (e) {
      print('❌ Error getting branch admin details: $e');
      return null;
    }
  }

  static Future<int> getBranchAdminPlacesCount(String adminId) async {
    try {
      final response = await supabase
          .from('branch_admin_places')
          .select()
          .eq('admin_id', adminId)
          .count();

      return response.count ?? 0;
    } catch (e) {
      print('❌ Error getting branch admin places count: $e');
      return 0;
    }
  }

  /// Check if a place is assigned to any branch admin
  static Future<bool> isPlaceAssignedToBranchAdmin(String placeId) async {
    try {
      final response = await supabase
          .from('branch_admin_places')
          .select('id')
          .eq('place_id', placeId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('❌ Error checking if place is assigned: $e');
      return false;
    }
  }

  /// Get branch admins for a specific place
  static Future<List<UserModel>> getBranchAdminsForPlace(String placeId) async {
    try {
      print('👥 Getting branch admins for place: $placeId');

      final response = await supabase
          .from('branch_admin_places')
          .select('admin_id, users!inner(*)')
          .eq('place_id', placeId);

      if (response == null || (response as List).isEmpty) {
        return [];
      }

      final admins = (response as List)
          .map((item) {
            final userData = item['users'] as Map<String, dynamic>?;
            if (userData == null) return null;
            return UserModel.fromJson(userData);
          })
          .whereType<UserModel>()
          .toList();

      print('✅ Found ${admins.length} branch admins for place');
      return admins;
    } catch (e) {
      print('❌ Error getting branch admins for place: $e');
      return [];
    }
  }

  /// Add a single place to branch admin
  static Future<bool> addPlaceToBranchAdmin({
    required String adminId,
    required String placeId,
  }) async {
    try {
      print('➕ Adding place $placeId to branch admin: $adminId');

      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('❌ No authenticated user');
        return false;
      }

      if (user.userType != UserType.systemAdmin) {
        print('❌ Only system admins can add places');
        return false;
      }

      // Check if already assigned
      final existing = await supabase
          .from('branch_admin_places')
          .select('id')
          .eq('admin_id', adminId)
          .eq('place_id', placeId)
          .maybeSingle();

      if (existing != null) {
        print('⚠️ Place already assigned to this branch admin');
        return true; // Already assigned, consider it success
      }

      await supabase.from('branch_admin_places').insert({
        'admin_id': adminId,
        'place_id': placeId,
        'created_by': user.id,
      });

      print('✅ Place added successfully');
      return true;
    } catch (e) {
      print('❌ Error adding place to branch admin: $e');
      return false;
    }
  }
}
