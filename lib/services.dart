// Services
import 'dart:math' as math;

import 'package:jalasupport/FCMService.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// Add to services.dart

class TrackingService {
  // Get current check-in status for a user on a ticket
  static Future<TicketCheckInStatus?> getCurrentCheckInStatus(
    String ticketId,
    String userId,
  ) async {
    try {
      final response = await supabase
          .from('ticket_tracking_points')
          .select()
          .eq('ticket_id', ticketId)
          .eq('created_by', userId)
          .eq('point_type', 'visit')
          .isFilter('check_out_time', null)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return TicketCheckInStatus.fromJson(response.first);
    } catch (e) {
      print('Error getting check-in status: $e');
      return null;
    }
  }

  // Check in to a ticket
  static Future<bool> checkIn({
    required String ticketId,
    required String userId,
  }) async {
    try {
      // First check if already checked in
      final existingCheckIn = await getCurrentCheckInStatus(ticketId, userId);
      if (existingCheckIn != null) {
        print('Already checked in');
        return false;
      }

      // Create new check-in tracking point
      await supabase.from('ticket_tracking_points').insert({
        'ticket_id': ticketId,
        'created_by': userId,
        'check_in_time': DateTime.now().toIso8601String(),
        'check_out_time': null,
        'description': '', // Will be filled on check-out
        'point_type': 'visit',
      });

      print('✅ Checked in successfully');
      return true;
    } catch (e) {
      print('Error checking in: $e');
      return false;
    }
  }

  // Check out from a ticket
  static Future<bool> checkOut({
    required String trackingPointId,
    required DateTime checkOutTime,
    required String description,
  }) async {
    try {
      await supabase.from('ticket_tracking_points').update({
        'check_out_time': checkOutTime.toIso8601String(),
        'description': description,
      }).eq('id', trackingPointId);

      print('✅ Checked out successfully');
      return true;
    } catch (e) {
      print('Error checking out: $e');
      return false;
    }
  }

  // Get tracking points for a ticket
  static Future<List<TicketTrackingPoint>> getTrackingPoints(
      String ticketId) async {
    try {
      final response = await supabase
          .from('ticket_tracking_points')
          .select('*, users!created_by(full_name)')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      return response.map<TicketTrackingPoint>((json) {
        final point = Map<String, dynamic>.from(json);
        if (json['users'] != null) {
          point['creator_name'] = json['users']['full_name'];
        }
        return TicketTrackingPoint.fromJson(point);
      }).toList();
    } catch (e) {
      print('Error loading tracking points: $e');
      return [];
    }
  }

  // Create a tracking point (note only)
  static Future<bool> createTrackingPoint({
    required String ticketId,
    required String createdBy,
    required String description,
    required String pointType,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    try {
      await supabase.from('ticket_tracking_points').insert({
        'ticket_id': ticketId,
        'created_by': createdBy,
        'check_in_time': checkInTime?.toIso8601String(),
        'check_out_time': checkOutTime?.toIso8601String(),
        'description': description,
        'point_type': pointType,
      });

      return true;
    } catch (e) {
      print('Error creating tracking point: $e');
      return false;
    }
  }

  // Subscribe to real-time tracking points updates
  static Stream<List<TicketTrackingPoint>> subscribeToTrackingPoints(
      String ticketId) {
    return supabase
        .from('ticket_tracking_points')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .asyncMap((data) async {
          final points = <TicketTrackingPoint>[];

          for (final json in data) {
            final point = Map<String, dynamic>.from(json);

            // Load creator name
            try {
              final user = await supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', json['created_by'])
                  .single();
              point['creator_name'] = user['full_name'];
            } catch (e) {
              point['creator_name'] = 'Unknown';
            }

            points.add(TicketTrackingPoint.fromJson(point));
          }

          return points;
        });
  }
}

class TicketCheckInStatus {
  final String trackingPointId;
  final DateTime checkInTime;

  TicketCheckInStatus({
    required this.trackingPointId,
    required this.checkInTime,
  });

  factory TicketCheckInStatus.fromJson(Map<String, dynamic> json) {
    return TicketCheckInStatus(
      trackingPointId: json['id'],
      checkInTime: DateTime.parse(json['check_in_time']),
    );
  }
}

class AdminUserService {
  // Create user using Supabase Admin API (for management screen)
  static Future<Map<String, dynamic>?> createUserViaAdmin({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('Creating user via Admin API: $email');

      // This uses a service role key or admin endpoint
      // You need to set up an Edge Function or use Management API

      final response = await supabase.functions.invoke(
        'create-user',
        body: {
          'email': email,
          'password': password,
          'user_data': userData,
        },
      );

      print('User created successfully via Admin API');
      return response.data;
    } catch (e) {
      print('Error creating user via Admin API: $e');
      return null;
    }
  }
}

class AuthService {
  /// Converts a phone number (+9665XXXXXXXX) to the placeholder email used
  /// for phone-based accounts so they can log in via email+password.
  static String _resolveLoginEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      return 'phone_${digits}@phone.user';
    }
    // Local Israeli number: 0XXXXXXXXX → +972XXXXXXXXX
    if (RegExp(r'^0\d{9}$').hasMatch(trimmed)) {
      return 'phone_972${trimmed.substring(1)}@phone.user';
    }
    return trimmed;
  }

  static Future<bool> signIn(String emailOrPhone, String password) async {
    try {
      final email = _resolveLoginEmail(emailOrPhone);
      print('Attempting sign in for: $email');

      // Step 1: Attempt authentication
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        print('Authentication failed');
        return false;
      }

      print('Auth successful, checking user status...');

      // Step 2: Get user data from database
      final user = await getCurrentUser();

      if (user == null) {
        print('User not found in database');
        await supabase.auth.signOut(); // Sign out if no user record
        return false;
      }

      // Step 3: Check if user is active
      if (!user.isActive) {
        print('User account is inactive. User ID: ${user.id}');

        // Sign out the user since account is inactive
        await supabase.auth.signOut();

        // You can throw a specific exception or return false
        throw Exception('Account is inactive. Please contact administrator.');
      }

      print('User is active, proceeding with login...');

      // Step 4: Setup FCM for mobile users
      if (!kIsWeb) {
        await _setupFCMAfterLogin(user);
      }

      return true;
    } catch (e) {
      print('Sign in error: $e');

      // Ensure user is signed out on any error
      try {
        await supabase.auth.signOut();
      } catch (signOutError) {
        print('Error during sign out: $signOutError');
      }

      return false;
    }
  }

  static Future<void> _setupFCMAfterLogin(UserModel user) async {
    if (kIsWeb) return;
    // Delegate entirely to FCMService which has retry logic and proper iOS handling
    await FCMService.setupForUser(user);
  }

  static Future<void> signOut() async {
    try {
      // Clear FCM token only on mobile platforms
      if (!kIsWeb) {
        try {
          // Clear FCM data
          await FCMService.clearForLogout();
        } catch (fcmError) {
          print('Error clearing FCM on logout: $fcmError');
          // Don't let FCM errors block logout
        }
      }

      // Sign out from Supabase
      await supabase.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

// ✨ UPDATED: Faster user fetching with specific fields only
  static Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      return null;
    }

    try {
      // ✅ Only select needed fields to reduce data transfer
      final response = await supabase
          .from('users')
          .select(
              'id, auth_id, email, full_name, phone, user_type, department_id, place_id, nature_of_work, is_active, language, profile_image_url, created_at, updated_at')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (response == null) {
        print('❌ No user found in users table for auth_id: ${user.id}');
        return null;
      }

      print('✅ User data loaded: ${response['full_name']}');
      return UserModel.fromJson(response);
    } catch (e) {
      print('❌ Error fetching user: $e');
      return null;
    }
  }

  static Future<String?> uploadProfileImage({
    File? imageFile, // For mobile
    Uint8List? imageBytes, // For web
    required String userId,
    required String fileName,
  }) async {
    try {
      print('Starting profile image upload...');

      Uint8List bytes;

      if (kIsWeb) {
        if (imageBytes == null) {
          throw Exception('Image bytes required for web upload');
        }
        bytes = imageBytes;
        print('Using web image bytes, size: ${bytes.length}');
      } else {
        if (imageFile == null) {
          throw Exception('Image file required for mobile upload');
        }
        bytes = await imageFile.readAsBytes();
        print('Using mobile image file, size: ${bytes.length}');
      }

      // Create a simpler filename without special characters
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
      final uniqueFileName = '${userId}_${timestamp}_$cleanFileName';

      print('Uploading to: profile_images/$uniqueFileName');

      // Upload to Supabase Storage with proper content type
      final response =
          await supabase.storage.from('profile_images').uploadBinary(
                uniqueFileName,
                bytes,
                fileOptions: FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                  contentType: _getContentType(fileName),
                ),
              );

      print('Upload response: $response');

      // Get public URL
      final imageUrl =
          supabase.storage.from('profile_images').getPublicUrl(uniqueFileName);

      print('Generated public URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Detailed error uploading profile image: $e');
      print('Error type: ${e.runtimeType}');
      if (e is StorageException) {
        print(
            'Storage error - statusCode: ${e.statusCode}, message: ${e.message}');
      }
      return null;
    }
  }

  // Helper method to determine content type
  static String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  static Future<bool> updateProfileImage(String userId, String imageUrl) async {
    try {
      print('Updating profile image URL in database: $imageUrl');

      await supabase
          .from('users')
          .update({'profile_image_url': imageUrl}).eq('id', userId);

      print('Profile image URL updated successfully');
      return true;
    } catch (e) {
      print('Error updating profile image URL: $e');
      return false;
    }
  }

// REPLACE the entire signUp method in AuthService class
  static Future<bool> signUp(
      String email, String password, Map<String, dynamic> userData) async {
    String? createdAuthId;

    try {
      print('Starting sign up for: $email');

      // Step 1: Sign up the new user
      final authResponse = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: null,
      );

      if (authResponse.user == null) {
        print('Failed to create auth user');
        return false;
      }

      createdAuthId = authResponse.user!.id;
      print('Auth user created: $createdAuthId');

      // Step 2: Create user record BEFORE signing out (while still authenticated)
      final userRecord = {
        'auth_id': createdAuthId,
        ...userData,
        'is_active': false,
      };

      final response = await supabase.from('users').insert(userRecord).select();

      if (response.isEmpty) {
        print('Failed to create user record in database');
        // Clean up: try to delete the auth user
        try {
          await supabase.auth.admin.deleteUser(createdAuthId);
          print('Cleaned up auth user after database insert failure');
        } catch (cleanupError) {
          print('Could not clean up auth user: $cleanupError');
        }
        return false;
      }

      print('User record created successfully with inactive status');

      // Step 3: Send activation notification to admin
      try {
        await _notifyAdminForActivation(
          userData['full_name'],
          email,
          userData['place_id'],
        );
      } catch (e) {
        print('Warning: Failed to send admin notification: $e');
      }

      // Step 4: NOW sign out after everything is complete
      await supabase.auth.signOut();
      print('✅ User signed out after successful registration');

      print('✅ User registered successfully');
      return true;
    } catch (e) {
      print('Sign up error: $e');

      // Cleanup: try to delete auth user if it was created
      if (createdAuthId != null) {
        try {
          // If we're still authenticated, try to delete
          await supabase.auth.admin.deleteUser(createdAuthId);
          print('Cleaned up auth user after error');
        } catch (cleanupError) {
          print('Could not clean up auth user: $cleanupError');
        }
      }

      // Always sign out on error
      try {
        await supabase.auth.signOut();
      } catch (_) {}

      return false;
    }
  }

  static Future<void> _notifyAdminForActivation(
      String userName, String userEmail, String? placeId) async {
    try {
      // Notify system admins and super admins via in-app notification
      final admins = await supabase
          .from('users')
          .select('id')
          .inFilter('user_type', [
        UserType.systemAdmin.value,
        UserType.superAdmin.value,
      ]).eq('is_active', true);

      for (final admin in admins) {
        await supabase.from('notifications').insert({
          'user_id': admin['id'],
          'title': 'New User Registration',
          'message':
              'User $userName ($userEmail) has registered and requires account activation.',
          'type': 'user_registration',
          'priority': 'medium',
        });
      }

      // Notify super users of the chosen place via push + in-app notification
      if (placeId != null) {
        final superUsers = await supabase
            .from('users')
            .select('id, fcm_token, fcm_token_web')
            .eq('user_type', UserType.superUser.value)
            .eq('place_id', placeId)
            .eq('is_active', true);

        for (final su in superUsers) {
          // In-app notification
          await supabase.from('notifications').insert({
            'user_id': su['id'],
            'title': 'New User Registration',
            'message':
                'User $userName ($userEmail) registered for your place and requires activation.',
            'type': 'user_registration',
            'priority': 'high',
          });

          // Push notification via FCM edge function
          final token = (su['fcm_token'] ?? su['fcm_token_web']) as String?;
          if (token != null && token.isNotEmpty) {
            try {
              await supabase.functions.invoke(
                'send-push-notification',
                body: {
                  'token': token,
                  'title': 'New User Registration',
                  'body': '$userName ($userEmail) registered and needs activation.',
                  'data': {
                    'type': 'user_registration',
                    'place_id': placeId,
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  },
                },
              );
            } catch (pushError) {
              print('❌ Push to super user failed: $pushError');
            }
          }
        }
      }

      print('✅ Admins and super users notified about new user registration');
    } catch (e) {
      print('❌ Error notifying admin: $e');
    }
  }

  static Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('users').update(updates).eq('auth_id', user.id);

      final updatedUser = await getCurrentUser();
      if (updatedUser != null && !kIsWeb) {
        try {
          await FCMService.setupForUser(updatedUser);
        } catch (fcmError) {
          print('Error updating FCM after profile update: $fcmError');
        }
      }

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  /// Change password for the currently signed-in user.
  /// Re-authenticates with [currentPassword] first to confirm identity.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated');
    }
    // Re-authenticate to confirm current password
    await supabase.auth.signInWithPassword(
      email: user.email!,
      password: currentPassword,
    );
    // Update to the new password
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Send a 6-digit OTP to [email] for password reset.
  static Future<void> sendPasswordResetOTP(String email) async {
    await supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  /// Verify [otp] sent to [email] and set [newPassword].
  /// Signs out immediately after so the OTP session does not persist.
  static Future<void> verifyOTPAndSetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.email,
    );
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
    // Sign out right away so the temporary OTP session never stays active.
    await supabase.auth.signOut();
  }
}

class TicketService {
  static Future<List<TicketModel>> getTickets({
    TicketStatus? status,
    String? search,
    String? departmentId,
    String? placeId,
  }) async {
    try {
      var query = supabase.from('tickets').select();

      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'title.ilike.%$search%,description.ilike.%$search%,ticket_number.ilike.%$search%');
      }
      if (departmentId != null) {
        query = query.eq('target_department_id', departmentId);
      }
      if (placeId != null) {
        query = query.eq('place_id', placeId);
      }

      final response = await query.order('created_at', ascending: false);
      return response
          .map<TicketModel>((json) => TicketModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching tickets: $e');
      return [];
    }
  }

// UPDATED: approveTicket method
  static Future<bool> approveTicket({
    required String ticketId,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    try {
      final ticket = await supabase
          .from('tickets')
          .select('ticket_number, created_by')
          .eq('id', ticketId)
          .single();

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return false;

      // Insert approval record
      await supabase.from('ticket_approvals').insert({
        'ticket_id': ticketId,
        'approved_by': currentUser.id,
        'is_approved': isApproved,
        'rejection_reason': rejectionReason,
      });

      // Update ticket status
      final newStatus = isApproved ? 'closed' : 'inprogress';
      await supabase.from('tickets').update({
        'status': newStatus,
        'under_supervision': false,
      }).eq('id', ticketId);

      // Send approval/rejection notification
      await NotificationService.notifyTicketApproved(
        ticketId: ticketId,
        ticketCreatorId: ticket['created_by'],
        approvedByUserId: currentUser.id,
        ticketNumber: ticket['ticket_number'],
        isApproved: isApproved,
        rejectionReason: rejectionReason,
        isAutoApproval: false,
      );

      return true;
    } catch (e) {
      print('Error approving ticket: $e');
      return false;
    }
  }

  // Enhanced createSubticket method
  static Future<bool> createSubticket({
    required String parentTicketId,
    required String targetAdminId,
    required Map<String, dynamic> subticketData,
  }) async {
    try {
      // Get parent ticket data
      final parentTicket = await supabase
          .from('tickets')
          .select('ticket_number')
          .eq('id', parentTicketId)
          .single();

      // Add parent ticket reference
      subticketData['parent_ticket_id'] = parentTicketId;

      // Create subticket
      final response = await supabase
          .from('tickets')
          .insert(subticketData)
          .select()
          .single();

      final subticketId = response['id'];
      final subticketNumber = response['ticket_number'];
      final title = response['title'];
      final createdBy = response['created_by'];

      // Send enhanced notification to target admin
      await NotificationService.notifySubticketCreated(
        subticketId: subticketId,
        parentTicketId: parentTicketId,
        createdByUserId: createdBy,
        targetAdminId: targetAdminId,
        subticketNumber: subticketNumber,
        subticketTitle: title,
        parentTicketNumber: parentTicket['ticket_number'],
      );

      return true;
    } catch (e) {
      print('Error creating subticket: $e');
      return false;
    }
  }

  static Future<bool> createTicket(Map<String, dynamic> ticketData) async {
    try {
      print('🎫 Creating ticket with auto-assignment check...');

      final targetDepartmentId = ticketData['target_department_id'];

      print('🔍 Checking auto-assignment for department: $targetDepartmentId');

      // Get auto-assignment - handle both true and NULL as enabled
      final autoAssignment = await supabase
          .from('auto_assignment_settings')
          .select('assigned_admin_id, is_enabled')
          .eq('department_id', targetDepartmentId)
          .or('is_enabled.eq.true,is_enabled.is.null') // Accept true OR null
          .maybeSingle();

      print('🎯 Auto-assignment result: $autoAssignment');

      // Apply auto-assignment if found and has an assigned admin
      if (autoAssignment != null &&
          autoAssignment['assigned_admin_id'] != null) {
        ticketData['assigned_to'] = autoAssignment['assigned_admin_id'];
        ticketData['status'] = 'inprogress';
        print(
            '✅ Auto-assignment found - Assigning to: ${autoAssignment['assigned_admin_id']}');
        print('✅ Status set to: inprogress');
      } else {
        ticketData['status'] = 'pending';
        print('ℹ️ No auto-assignment found - Status set to: pending');
      }

      // Create ticket
      print('💾 Inserting ticket into database...');
      final response =
          await supabase.from('tickets').insert(ticketData).select().single();

      final ticketId = response['id'];
      final ticketNumber = response['ticket_number'];
      final title = response['title'];
      final createdBy = response['created_by'];
      final assignedTo = response['assigned_to'];
      final status = response['status'];

      print('✅ Ticket created successfully:');
      print('   - ID: $ticketId');
      print('   - Number: $ticketNumber');
      print('   - Title: $title');
      print('   - Status: $status');
      print('   - Assigned to: ${assignedTo ?? "None"}');

      // Send notifications
      if (assignedTo != null) {
        print('📢 Sending assignment notification...');
        await NotificationService.notifyTicketAssigned(
          ticketId: ticketId,
          assignedToUserId: assignedTo,
          assignedByUserId: createdBy,
          ticketNumber: ticketNumber,
          ticketTitle: title,
        );
      } else {
        print('📢 Sending creation notification to department admins...');
        await NotificationService.notifyTicketCreated(
          ticketId: ticketId,
          createdByUserId: createdBy,
          targetDepartmentId: targetDepartmentId,
          ticketNumber: ticketNumber,
          ticketTitle: title,
        );
      }

      return true;
    } catch (e) {
      print('❌ Error creating ticket: $e');
      return false;
    }
  }

// Enhanced updateTicket method
  static Future<bool> updateTicket(
      String ticketId, Map<String, dynamic> updates) async {
    try {
      // Get current ticket data
      final currentTicket = await supabase
          .from('tickets')
          .select('status, created_by, assigned_to, ticket_number')
          .eq('id', ticketId)
          .single();

      // Update ticket
      await supabase.from('tickets').update(updates).eq('id', ticketId);

      // Check if status changed and send enhanced notification
      if (updates.containsKey('status')) {
        final currentUser = await AuthService.getCurrentUser();
        if (currentUser != null) {
          await NotificationService.notifyTicketStatusChanged(
            ticketId: ticketId,
            ticketCreatorId: currentTicket['created_by'],
            changedByUserId: currentUser.id,
            ticketNumber: currentTicket['ticket_number'],
            oldStatus: currentTicket['status'],
            newStatus: updates['status'],
          );
        }
      }

      return true;
    } catch (e) {
      print('Error updating ticket: $e');
      return false;
    }
  }

  // Fixed method in services.dart
  static Future<List<TicketModel>> getSubtickets(String parentTicketId) async {
    try {
      final response = await supabase
          .from('tickets')
          .select('''
          *,
          creator:users!created_by(full_name),
          assignee:users!assigned_to(full_name),
          department:departments!target_department_id(name),
          place:places!place_id(name)
        ''')
          .eq('parent_ticket_id', parentTicketId)
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      return response
          .map<TicketModel>((json) => TicketModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading subtickets: $e');
      return [];
    }
  }

  // Get tickets with their subtickets for hierarchical display
  static Future<List<Map<String, dynamic>>> getTicketsWithSubtickets({
    TicketStatus? status,
    String? search,
    String? departmentId,
    String? placeId,
  }) async {
    try {
      var query = supabase.from('tickets').select();

      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'title.ilike.%$search%,description.ilike.%$search%,ticket_number.ilike.%$search%');
      }
      if (departmentId != null) {
        query = query.eq('target_department_id', departmentId);
      }
      if (placeId != null) {
        query = query.eq('place_id', placeId);
      }

      // Only get parent tickets (no parent_ticket_id)
      query = query.isFilter('parent_ticket_id', null);

      final parentTickets = await query.order('created_at', ascending: false);

      List<Map<String, dynamic>> result = [];

      for (final parentTicketData in parentTickets) {
        final parentTicket = TicketModel.fromJson(parentTicketData);

        // Get subtickets for this parent
        final subticketResponse = await supabase
            .from('tickets')
            .select()
            .eq('parent_ticket_id', parentTicket.id)
            .neq('status', 'deleted')
            .order('created_at', ascending: false);

        final subtickets = subticketResponse
            .map<TicketModel>((json) => TicketModel.fromJson(json))
            .toList();

        result.add({
          'parent': parentTicket,
          'subtickets': subtickets,
        });
      }

      return result;
    } catch (e) {
      print('Error fetching tickets with subtickets: $e');
      return [];
    }
  }

  // Get tickets that should appear as normal tickets in a department
  // (includes both parent tickets and subtickets targeted to this department)
  static Future<List<TicketModel>> getTicketsForDepartment({
    required String departmentId,
    TicketStatus? status,
    String? search,
  }) async {
    try {
      var query = supabase.from('tickets').select();

      query = query.eq('target_department_id', departmentId);

      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'title.ilike.%$search%,description.ilike.%$search%,ticket_number.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false);
      return response
          .map<TicketModel>((json) => TicketModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching department tickets: $e');
      return [];
    }
  }

  // Check if a ticket has any active subtickets
  static Future<bool> hasActiveSubtickets(String ticketId) async {
    try {
      final response = await supabase
          .from('tickets')
          .select('id')
          .eq('parent_ticket_id', ticketId)
          .neq('status', 'deleted')
          .neq('status', 'closed')
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking active subtickets: $e');
      return false;
    }
  }

  static Future<TicketModel?> getParentTicket(String subticketId) async {
    try {
      final subticket = await supabase
          .from('tickets')
          .select('parent_ticket_id')
          .eq('id', subticketId)
          .maybeSingle(); // Use maybeSingle to handle null cases gracefully

      if (subticket != null && subticket['parent_ticket_id'] != null) {
        final parentResponse = await supabase
            .from('tickets')
            .select()
            .eq('id', subticket['parent_ticket_id'])
            .maybeSingle(); // Use maybeSingle here too

        if (parentResponse != null) {
          return TicketModel.fromJson(parentResponse);
        }
      }
      return null;
    } catch (e) {
      print('Error getting parent ticket: $e');
      return null;
    }
  }

  /// Check if a ticket is eligible for auto-approval
  static Future<bool> isTicketEligibleForAutoApproval(String ticketId) async {
    try {
      final approvalMinutes =
          await NotificationService.getAutoApprovalMinutes();

      final result = await supabase.rpc(
        'is_ticket_eligible_for_auto_approval',
        params: {
          'p_ticket_id': ticketId,
          'p_approval_minutes': approvalMinutes,
        },
      );

      return result == true;
    } catch (e) {
      print('Error checking ticket eligibility: $e');
      return false;
    }
  }

  /// Auto-approve a single ticket
  static Future<bool> autoApproveSingleTicket(String ticketId) async {
    try {
      print('🔄 Attempting to auto-approve ticket: $ticketId');

      final approvalMinutes =
          await NotificationService.getAutoApprovalMinutes();

      final result = await supabase.rpc(
        'auto_approve_single_ticket',
        params: {
          'p_ticket_id': ticketId,
          'p_approval_minutes': approvalMinutes,
        },
      );

      if (result == true) {
        print('✅ Ticket auto-approved successfully');
        return true;
      } else {
        print('⏭️ Ticket not eligible for auto-approval');
        return false;
      }
    } catch (e) {
      print('❌ Error auto-approving ticket: $e');
      return false;
    }
  }

  /// Check and auto-approve all eligible tickets (batch process) - JSON VERSION
  static Future<Map<String, dynamic>>
      checkAndAutoApproveExpiredTickets() async {
    try {
      print('🔍 Checking for expired prefinished tickets...');

      final result = await supabase.rpc('auto_approve_expired_tickets');

      print('📦 Raw result from RPC: $result');
      print('📦 Result type: ${result.runtimeType}');

      if (result != null) {
        // Result is already a Map from JSON
        final data = result as Map<String, dynamic>;

        final approvedCount = data['approved_count'] as int? ?? 0;
        final ticketNumbersList = data['ticket_numbers'] as List? ?? [];
        final ticketNumbers =
            ticketNumbersList.map((item) => item.toString()).toList();

        print('✅ Auto-approved $approvedCount tickets: $ticketNumbers');

        return {
          'count': approvedCount,
          'ticket_numbers': ticketNumbers,
        };
      }

      print('ℹ️ No results returned from function');
      return {'count': 0, 'ticket_numbers': <String>[]};
    } catch (e, stackTrace) {
      print('❌ Error in batch auto-approval: $e');
      print('Stack trace: $stackTrace');
      return {'count': 0, 'ticket_numbers': <String>[]};
    }
  }

  /// Get tickets that will expire soon (for warnings)
  static Future<List<Map<String, dynamic>>> getTicketsNearingAutoApproval({
    int warningMinutes = 30,
  }) async {
    try {
      final approvalMinutes =
          await NotificationService.getAutoApprovalMinutes();
      final warningThreshold = approvalMinutes - warningMinutes;

      if (warningThreshold <= 0) {
        return [];
      }

      final cutoffTime =
          DateTime.now().subtract(Duration(minutes: warningThreshold));

      final response = await supabase
          .from('tickets')
          .select('id, ticket_number, updated_at, created_by')
          .eq('status', 'prefinished')
          .lt('updated_at', cutoffTime.toIso8601String())
          .order('updated_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting tickets nearing auto-approval: $e');
      return [];
    }
  }

  // Enhanced assignTicket method
  static Future<bool> assignTicket(String ticketId, String adminId) async {
    try {
      // Get current ticket data
      final ticket = await supabase
          .from('tickets')
          .select('ticket_number, title, created_by')
          .eq('id', ticketId)
          .single();

      // Update ticket
      await supabase.from('tickets').update({
        'assigned_to': adminId,
        'status': TicketStatus.inprogress.value,
      }).eq('id', ticketId);

      // Get current user (assigner)
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser != null) {
        // Notify assigned user with enhanced notification
        await NotificationService.notifyTicketAssigned(
          ticketId: ticketId,
          assignedToUserId: adminId,
          assignedByUserId: currentUser.id,
          ticketNumber: ticket['ticket_number'],
          ticketTitle: ticket['title'],
        );

        // Notify ticket creator about status change
        await NotificationService.notifyTicketStatusChanged(
          ticketId: ticketId,
          ticketCreatorId: ticket['created_by'],
          changedByUserId: currentUser.id,
          ticketNumber: ticket['ticket_number'],
          oldStatus: 'pending',
          newStatus: TicketStatus.inprogress.value,
        );
      }

      return true;
    } catch (e) {
      print('Error assigning ticket: $e');
      return false;
    }
  }

// UPDATED: markTicketFinished method
  static Future<bool> markTicketFinished({
    required String ticketId,
    required String title,
    required String description,
    List<String>? attachmentPaths,
  }) async {
    try {
      print('📋 Marking ticket as finished (regular): $ticketId');

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        print('❌ No authenticated user');
        return false;
      }

      if (currentUser.userType != UserType.admin &&
          currentUser.userType != UserType.superAdmin) {
        print('❌ Only admins and super admins can mark tickets as finished');
        return false;
      }

      final ticket = await supabase
          .from('tickets')
          .select('ticket_number, created_by, assigned_to, status, title')
          .eq('id', ticketId)
          .single();

      if (ticket['assigned_to'] != currentUser.id) {
        print('❌ You can only mark your assigned tickets as finished');
        return false;
      }

      if (ticket['status'] != 'inprogress') {
        print('❌ Ticket must be in progress status');
        return false;
      }

      // Create ticket report
      final reportResponse = await supabase
          .from('ticket_reports')
          .insert({
            'ticket_id': ticketId,
            'title': title,
            'description': description,
            'submitted_by': currentUser.id,
          })
          .select()
          .single();

      final reportId = reportResponse['id'];

      if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
        for (final path in attachmentPaths) {
          await supabase.from('ticket_report_attachments').insert({
            'report_id': reportId,
            'file_path': path,
            'file_name': path.split('/').last,
            'uploaded_by': currentUser.id,
          });
        }
      }

      // Update ticket status
      await supabase.from('tickets').update({
        'status': TicketStatus.prefinished.value,
        'under_supervision': false,
      }).eq('id', ticketId);

      print('✅ Ticket marked as finished (awaiting creator approval)');

      // Send notification with report details
      await NotificationService.notifyTicketMarkedFinished(
        ticketId: ticketId,
        ticketCreatorId: ticket['created_by'],
        finishedByUserId: currentUser.id,
        ticketNumber: ticket['ticket_number'],
        ticketTitle: ticket['title'],
        reportTitle: title,
        reportDescription: description,
      );

      return true;
    } catch (e) {
      print('❌ Error marking ticket as finished: $e');
      return false;
    }
  }

// UPDATED: markTicketUnderSupervision method
  static Future<bool> markTicketUnderSupervision({
    required String ticketId,
    required String title,
    required String description,
    List<String>? attachmentPaths,
  }) async {
    try {
      print('🔍 Marking ticket as under supervision: $ticketId');

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        print('❌ No authenticated user');
        return false;
      }

      if (currentUser.userType != UserType.admin &&
          currentUser.userType != UserType.superAdmin) {
        print(
            '❌ Only admins and super admins can mark tickets as under supervision');
        return false;
      }

      final ticket = await supabase
          .from('tickets')
          .select('ticket_number, created_by, assigned_to, status, title')
          .eq('id', ticketId)
          .single();

      if (ticket['assigned_to'] != currentUser.id) {
        print('❌ You can only mark your assigned tickets as under supervision');
        return false;
      }

      if (ticket['status'] != 'inprogress') {
        print('❌ Ticket must be in progress status');
        return false;
      }

      // Create ticket report
      final reportResponse = await supabase
          .from('ticket_reports')
          .insert({
            'ticket_id': ticketId,
            'title': title,
            'description': description,
            'submitted_by': currentUser.id,
          })
          .select()
          .single();

      final reportId = reportResponse['id'];

      if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
        for (final path in attachmentPaths) {
          await supabase.from('ticket_report_attachments').insert({
            'report_id': reportId,
            'file_path': path,
            'file_name': path.split('/').last,
            'uploaded_by': currentUser.id,
          });
        }
      }

      // Update ticket status with supervision flag
      await supabase.from('tickets').update({
        'status': TicketStatus.prefinished.value,
        'under_supervision': true,
      }).eq('id', ticketId);

      print('✅ Ticket marked as under supervision (will auto-approve)');

      // Send supervision notification
      await NotificationService.notifyTicketUnderSupervision(
        ticketId: ticketId,
        ticketCreatorId: ticket['created_by'],
        supervisedByUserId: currentUser.id,
        ticketNumber: ticket['ticket_number'],
        ticketTitle: ticket['title'],
        reportTitle: title,
        reportDescription: description,
      );

      return true;
    } catch (e) {
      print('❌ Error marking ticket as under supervision: $e');
      return false;
    }
  }

  /// Admin or super_admin can reject ticket from supervision (before auto-approval)
  /// Only the assigned admin can reject their own supervised tickets
  static Future<bool> rejectTicketFromSupervision({
    required String ticketId,
    required String rejectionReason,
  }) async {
    try {
      print('❌ Rejecting ticket from supervision: $ticketId');

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        print('❌ No authenticated user');
        return false;
      }

      // Verify user is admin or super_admin
      if (currentUser.userType != UserType.admin &&
          currentUser.userType != UserType.superAdmin) {
        print('❌ Only admins and super admins can reject supervised tickets');
        return false;
      }

      // Get ticket data
      final ticket = await supabase
          .from('tickets')
          .select(
              'ticket_number, created_by, assigned_to, under_supervision, status')
          .eq('id', ticketId)
          .single();

      // Verify ticket is under supervision
      if (ticket['under_supervision'] != true) {
        print('❌ Ticket is not under supervision');
        return false;
      }

      // Verify user is the one who assigned it
      if (ticket['assigned_to'] != currentUser.id) {
        print('❌ Only the assigned admin can reject from supervision');
        return false;
      }

      // Verify ticket is in prefinished status
      if (ticket['status'] != 'prefinished') {
        print('❌ Ticket must be in prefinished status');
        return false;
      }

      // Delete the ticket report (since work is being rejected)
      await supabase.from('ticket_reports').delete().eq('ticket_id', ticketId);

      // Update ticket back to in-progress and remove supervision flag
      await supabase.from('tickets').update({
        'status': TicketStatus.inprogress.value,
        'under_supervision': false,
      }).eq('id', ticketId);

      // Create rejection record
      await supabase.from('ticket_approvals').insert({
        'ticket_id': ticketId,
        'approved_by': currentUser.id,
        'is_approved': false,
        'rejection_reason': 'SUPERVISION REJECTED: $rejectionReason',
        'notes': 'Admin rejected work while under supervision',
      });

      print('✅ Ticket rejected from supervision, returned to in-progress');

      // Notify creator
      await NotificationService.createAndSendNotification(
        userId: ticket['created_by'],
        type: 'ticket_status_changed',
        title: '🔄 Ticket Returned to In-Progress',
        message:
            'Your ticket #${ticket['ticket_number']} was under supervision but has been returned to in-progress status.\n\nReason: $rejectionReason',
        ticketId: ticketId,
        additionalData: {
          'ticket_number': ticket['ticket_number'],
          'rejection_reason': rejectionReason,
        },
      );

      return true;
    } catch (e) {
      print('❌ Error rejecting ticket from supervision: $e');
      return false;
    }
  }

  /// Check if current user can mark ticket as finished
  static Future<bool> canMarkTicketFinished(String ticketId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) return false;

      // Must be admin or super_admin
      if (currentUser.userType != UserType.admin &&
          currentUser.userType != UserType.superAdmin) {
        return false;
      }

      // Get ticket
      final ticket = await supabase
          .from('tickets')
          .select('assigned_to, status')
          .eq('id', ticketId)
          .single();

      // Must be assigned to current user and in progress
      return ticket['assigned_to'] == currentUser.id &&
          ticket['status'] == 'inprogress';
    } catch (e) {
      print('❌ Error checking if can mark finished: $e');
      return false;
    }
  }
}

/// Allows any screen to request navigation to a specific ticket.
/// The TicketsScreen registers a listener in initState and removes it in dispose.
class TicketNavigationService {
  static String? _pendingTicketId;
  static String? _pendingTargetStatus;
  static VoidCallback? _listener;

  /// Called by main.dart when a notification is tapped.
  /// [targetStatus] is the TicketStatus.value to switch to (e.g. 'inprogress').
  static void navigateTo(String ticketId, {String? targetStatus}) {
    _pendingTicketId = ticketId;
    _pendingTargetStatus = targetStatus;
    _listener?.call();
  }

  /// Consumes the pending ticket ID.
  static String? consume() {
    final id = _pendingTicketId;
    _pendingTicketId = null;
    return id;
  }

  /// Consumes the pending target status (call after consume()).
  static String? consumeTargetStatus() {
    final s = _pendingTargetStatus;
    _pendingTargetStatus = null;
    return s;
  }

  static void setListener(VoidCallback cb) => _listener = cb;
  static void removeListener() => _listener = null;
}

// Updated ChatService with professional unread count management
// Replace your existing ChatService class in services.dart with this:

class ChatService {
  // Cache for message streams to prevent multiple subscriptions
  static final Map<String, StreamController<List<ChatMessageModel>>>
      _streamControllers = {};

  // Cache to store user names
  static final Map<String, String> _userCache = {};
  static final Map<String, String?> _userNameCache = {};
  static final Map<String, String?> _userImageCache = {};
  // Unread count cache with timestamp for invalidation
  static final Map<String, Map<String, dynamic>> _unreadCountCache = {};
  static const Duration _cacheValidity = Duration(seconds: 5);

// Add this method to ChatService class
  static Stream<List<Map<String, dynamic>>> subscribeToChatRoomUpdates(
      List<String> chatRoomIds) {
    return supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .inFilter('chat_room_id', chatRoomIds)
        .asyncMap((_) async {
          // This will trigger whenever new messages are added to any subscribed chat room
          return [];
        });
  }

  // Rest of your ChatService methods remain the same...
  static Future<bool> markChatAsRead(String chatRoomId, String userId) async {
    try {
      print('📖 Marking chat $chatRoomId as read for user: $userId');

      await supabase.rpc('upsert_chat_read_status', params: {
        'p_chat_room_id': chatRoomId,
        'p_user_id': userId,
      });

      print('✅ Successfully marked chat as read');
      _invalidateUnreadCache();
      return true;
    } catch (e) {
      print('❌ Error marking chat as read: $e');
      return false;
    }
  }

  static Future<Map<String, int>> getUnreadCountsForTickets(
      List<String> ticketIds, String userId) async {
    if (ticketIds.isEmpty) return {};

    try {
      print(
          '🔢 Getting unread counts for ${ticketIds.length} tickets for user: $userId');

      final cacheKey = '$userId:${ticketIds.join(',')}';
      final cachedData = _unreadCountCache[cacheKey];
      if (cachedData != null) {
        final cacheTime = cachedData['timestamp'] as DateTime;
        if (DateTime.now().difference(cacheTime) < _cacheValidity) {
          print('📊 Returning cached unread counts');
          return Map<String, int>.from(cachedData['data']);
        }
      }

      final response =
          await supabase.rpc('get_unread_counts_for_user', params: {
        'p_user_id': userId,
        'p_ticket_ids': ticketIds,
      });

      final unreadCounts = <String, int>{};

      if (response != null) {
        for (final row in response) {
          final ticketId = row['ticket_id'] as String;
          final count = (row['unread_count'] as num).toInt();
          unreadCounts[ticketId] = count;
        }
      }

      for (final ticketId in ticketIds) {
        unreadCounts.putIfAbsent(ticketId, () => 0);
      }

      _unreadCountCache[cacheKey] = {
        'data': unreadCounts,
        'timestamp': DateTime.now(),
      };

      print('📊 Final unread counts for user $userId: $unreadCounts');
      return unreadCounts;
    } catch (e) {
      print('❌ Error getting unread counts: $e');
      return {for (String id in ticketIds) id: 0};
    }
  }

  /// Get total unread count for a user
  static Future<int> getTotalUnreadCount(String userId) async {
    try {
      final response = await supabase.rpc('get_total_unread_count', params: {
        'p_user_id': userId,
      });

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      print('❌ Error getting total unread count: $e');
      return 0;
    }
  }

  static void _invalidateUnreadCache() {
    _unreadCountCache.clear();
    print('🗑️ Unread count cache invalidated');
  }

  static Future<bool> sendMessage(
      String chatRoomId, String message, List<String>? mentions) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('❌ No current user found');
        return false;
      }

      print('📤 Sending message from ${user.fullName}');

      final response = await supabase
          .from('chat_messages')
          .insert({
            'chat_room_id': chatRoomId,
            'sender_id': user.id,
            'message': message,
            'mentioned_users': mentions,
          })
          .select()
          .single();

      print('✅ Message sent successfully: ${response['id']}');
      _invalidateUnreadCache();

      // Fire notifications in background — don't block the caller.
      _sendMessageNotificationsAsync(chatRoomId, user.id, message);

      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // Runs notifications in background without blocking the send call.
  static void _sendMessageNotificationsAsync(
      String chatRoomId, String senderId, String message) {
    (() async {
      try {
        final chatRoom = await supabase
            .from('chat_rooms')
            .select('ticket_id, tickets(ticket_number)')
            .eq('id', chatRoomId)
            .single();
        final ticketId = chatRoom['ticket_id'] as String?;
        final ticketInfo = chatRoom['tickets'] as Map<String, dynamic>?;
        final ticketNumber = ticketInfo?['ticket_number'] as String?;
        if (ticketId != null) {
          await NotificationService.notifyChatMessage(
            chatRoomId: chatRoomId,
            senderId: senderId,
            messageContent: message,
            ticketId: ticketId,
            ticketNumber: ticketNumber,
          );
        }
      } catch (e) {
        print('⚠️ Background notification error: $e');
      }
    })();
  }

  static Future<void> _sendChatNotifications(
      String chatRoomId, String senderId, String message) async {
    try {
      final chatRoom = await supabase
          .from('chat_rooms')
          .select('ticket_id')
          .eq('id', chatRoomId)
          .single();

      final ticketId = chatRoom['ticket_id'];
      final ticket = await supabase
          .from('tickets')
          .select('ticket_number')
          .eq('id', ticketId)
          .single();

      final participants = await _getChatParticipants(chatRoomId, ticketId);

      for (final participant in participants) {
        if (participant.id != senderId) {
          await NotificationService.notifyNewChatMessage(
            chatRoomId: chatRoomId,
            ticketId: ticketId,
            senderId: senderId,
            message: message,
            ticketNumber: ticket['ticket_number'],
          );
        }
      }
    } catch (e) {
      print('❌ Error sending chat notifications: $e');
    }
  }

  /// Get messages for a chat room with user profile data
  static Future<List<ChatMessageModel>> getMessages(String chatRoomId) async {
    try {
      print('Loading messages for room: $chatRoomId');
      final response = await supabase
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('created_at', ascending: true);

      final senderIds = response
          .map<String>((msg) => msg['sender_id'] as String)
          .toSet()
          .toList();
      await _loadUserData(senderIds);

      print('Loaded ${response.length} messages with user data');
      return response.map<ChatMessageModel>((json) {
        final messageData = Map<String, dynamic>.from(json);
        final senderId = json['sender_id'] as String;
        messageData['sender_name'] = _userNameCache[senderId];
        messageData['sender_profile_image'] = _userImageCache[senderId];
        return ChatMessageModel.fromJson(messageData);
      }).toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  /// Subscribe to real-time messages with profile data
  static Stream<List<ChatMessageModel>> subscribeToMessages(String chatRoomId) {
    print('Setting up subscription for room: $chatRoomId');

    return supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', chatRoomId)
        .order('created_at', ascending: true)
        .asyncMap((data) async {
          print('Stream update: ${data.length} messages');

          final sortedData = List<Map<String, dynamic>>.from(data);
          sortedData.sort((a, b) {
            final aTime = DateTime.parse(a['created_at']);
            final bTime = DateTime.parse(b['created_at']);
            return aTime.compareTo(bTime);
          });

          final senderIds = sortedData
              .map<String>((msg) => msg['sender_id'] as String)
              .toSet()
              .toList();

          await _loadUserData(senderIds);

          return sortedData.map<ChatMessageModel>((json) {
            final messageData = Map<String, dynamic>.from(json);
            final senderId = json['sender_id'] as String;
            messageData['sender_name'] = _userNameCache[senderId];
            messageData['sender_profile_image'] = _userImageCache[senderId];
            return ChatMessageModel.fromJson(messageData);
          }).toList();
        });
  }

  /// Load user names and profile images and cache them
  static Future<void> _loadUserData(List<String> userIds) async {
    final uncachedIds = userIds
        .where((id) =>
            !_userNameCache.containsKey(id) || !_userImageCache.containsKey(id))
        .toList();

    if (uncachedIds.isEmpty) return;

    try {
      final users = await supabase
          .from('users')
          .select('id, full_name, profile_image_url')
          .inFilter('id', uncachedIds);

      for (final user in users) {
        final userId = user['id'] as String;
        _userNameCache[userId] = user['full_name'] as String?;
        _userImageCache[userId] = user['profile_image_url'] as String?;
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // In ChatService class, UPDATE _getChatParticipants method:

  static Future<List<UserNotificationInfo>> _getChatParticipants(
      String chatRoomId, String ticketId) async {
    try {
      final ticket = await supabase
          .from('tickets')
          .select('created_by, assigned_to, target_department_id, place_id')
          .eq('id', ticketId)
          .single();

      final participantIds = <String>{};

      if (ticket['created_by'] != null) {
        participantIds.add(ticket['created_by']);
      }

      if (ticket['assigned_to'] != null) {
        participantIds.add(ticket['assigned_to']);
      }

      if (ticket['target_department_id'] != null) {
        final superAdmins = await supabase
            .from('users')
            .select('id')
            .eq('department_id', ticket['target_department_id'])
            .eq('user_type', 'super_admin')
            .eq('is_active', true);

        for (final admin in superAdmins) {
          participantIds.add(admin['id']);
        }
      }

      // NEW: Add branch admins who have access to this place
      if (ticket['place_id'] != null) {
        final branchAdmins = await supabase
            .from('branch_admin_places')
            .select('admin_id, users!admin_id(id, is_active)')
            .eq('place_id', ticket['place_id']);

        for (final branchAdmin in branchAdmins) {
          final user = branchAdmin['users'];
          if (user != null && user['is_active'] == true) {
            participantIds.add(user['id']);
          }
        }
      }

      if (participantIds.isNotEmpty) {
        final users = await supabase
            .from('users')
            .select(
                'id, full_name, email, fcm_token, fcm_token_web, user_type, department_id, place_id, language')
            .inFilter('id', participantIds.toList());

        return users
            .map((user) => UserNotificationInfo(
                  id: user['id'],
                  fullName: user['full_name'],
                  email: user['email'],
                  fcmToken: user['fcm_token'],
                  fcmTokenWeb: user['fcm_token_web'],
                  userType: user['user_type'],
                  departmentId: user['department_id'],
                  placeId: user['place_id'],
                  language: user['language'] ?? 'en',
                ))
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Error getting chat participants: $e');
      return [];
    }
  }

  /// Subscribe to real-time unread count changes
  static Stream<Map<String, int>> subscribeToUnreadCounts(
      List<String> ticketIds, String userId) {
    // Create a stream controller to merge the streams manually
    late StreamController<Map<String, int>> controller;
    StreamSubscription? messageSubscription;
    StreamSubscription? readStatusSubscription;
    Timer? debounceTimer;

    // Define the refresh function first
    void triggerRefresh() {
      // Debounce to avoid too many updates
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        try {
          _invalidateUnreadCache();
          final counts = await getUnreadCountsForTickets(ticketIds, userId);
          if (!controller.isClosed) {
            controller.add(counts);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      });
    }

    controller = StreamController<Map<String, int>>(
      onListen: () {
        // Subscribe to chat messages changes
        messageSubscription = supabase
            .from('chat_messages')
            .stream(primaryKey: ['id']).listen((_) => triggerRefresh());

        // Subscribe to read status changes for this user
        readStatusSubscription = supabase
            .from('chat_read_status')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .listen((_) => triggerRefresh());
      },
      onCancel: () {
        messageSubscription?.cancel();
        readStatusSubscription?.cancel();
        debounceTimer?.cancel();
      },
    );

    return controller.stream;
  }

  static void disposeAllStreams() {
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();
    _userCache.clear();
    _invalidateUnreadCache();
  }

  static void disposeStream(String chatRoomId) {
    final controller = _streamControllers[chatRoomId];
    if (controller != null) {
      if (!controller.isClosed) {
        controller.close();
      }
      _streamControllers.remove(chatRoomId);
    }
  }

  static void clearAllCaches() {
    _userNameCache.clear();
    _userImageCache.clear();
    _invalidateUnreadCache();
    print('All ChatService caches cleared');
  }
}

// Enhanced NotificationService class
class NotificationService {
  // Cache for user FCM tokens to reduce database queries
  static final Map<String, UserNotificationInfo> _userNotificationCache = {};
  static DateTime _cacheLastUpdated = DateTime.now();
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Email notification queue to batch emails
  static final List<Map<String, dynamic>> _emailQueue = [];
  static Timer? _emailBatchTimer;

  // Initialize the notification service
  static Future<void> initialize() async {
    _setupEmailBatchProcessor();
    print('✅ NotificationService initialized');
  }

  /// Get auto-approval time setting in minutes (with enhanced debugging)
  static int? _cachedAutoApprovalMinutes;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(minutes: 5);

  static Future<int> getAutoApprovalMinutes() async {
    try {
      // Check cache first
      if (_cachedAutoApprovalMinutes != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheValidity) {
        print(
            '📦 Using cached auto-approval time: $_cachedAutoApprovalMinutes minutes');
        return _cachedAutoApprovalMinutes!;
      }

      print('🔍 Fetching auto-approval time from database...');
      print('🔍 Current user: ${supabase.auth.currentUser?.id}');

      // Try to fetch with detailed error handling
      final response = await supabase
          .from('system_settings')
          .select('setting_key, setting_value, description')
          .eq('setting_key', 'auto_approval_minutes')
          .maybeSingle();

      print('📦 Raw response: $response');

      if (response != null && response['setting_value'] != null) {
        final value = response['setting_value'].toString();
        _cachedAutoApprovalMinutes = int.parse(value);
        _cacheTimestamp = DateTime.now();
        print(
            '✅ Successfully fetched auto-approval time: $_cachedAutoApprovalMinutes minutes');
        print('✅ Description: ${response['description']}');
        return _cachedAutoApprovalMinutes!;
      } else {
        print('⚠️ No setting found in database, using default');
      }

      // Default to 1440 minutes (24 hours)
      print('⚠️ Falling back to default: 1440 minutes (24 hours)');
      _cachedAutoApprovalMinutes = 1440;
      _cacheTimestamp = DateTime.now();
      return 1440;
    } catch (e, stackTrace) {
      print('❌ Error getting auto-approval time: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ Falling back to cached value or default');

      // If we have a cached value, use it even if expired
      if (_cachedAutoApprovalMinutes != null) {
        print('📦 Using stale cache: $_cachedAutoApprovalMinutes minutes');
        return _cachedAutoApprovalMinutes!;
      }

      // Last resort: default value
      return 1440;
    }
  }

  /// Clear the cache (call this when settings are updated)
  static void clearAutoApprovalCache() {
    _cachedAutoApprovalMinutes = null;
    _cacheTimestamp = null;
    print('🗑️ Auto-approval cache cleared');
  }

  /// Force refresh the setting (useful after system admin updates it)
  static Future<int> refreshAutoApprovalMinutes() async {
    clearAutoApprovalCache();
    return await getAutoApprovalMinutes();
  }

  /// Update auto-approval time (system admin only)
  static Future<bool> updateAutoApprovalMinutes(
      int minutes, String userId) async {
    try {
      if (minutes < 1) {
        print('Auto-approval time must be at least 1 minute');
        return false;
      }

      // Use upsert with onConflict parameter
      await supabase.from('system_settings').upsert(
        {
          'setting_key': 'auto_approval_minutes',
          'setting_value': minutes.toString(),
          'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'setting_key',
      );

      print('Auto-approval time updated to $minutes minutes');
      return true;
    } catch (e) {
      print('Error updating auto-approval time: $e');
      return false;
    }
  }

  /// Check for tickets eligible for auto-approval
  static Future<int> checkAutoApprovalEligible() async {
    try {
      final minutes = await getAutoApprovalMinutes();
      final cutoffTime = DateTime.now().subtract(Duration(minutes: minutes));

      final response = await supabase
          .from('tickets')
          .select('id')
          .eq('status', 'prefinished')
          .lt('updated_at', cutoffTime.toIso8601String());

      return response.length;
    } catch (e) {
      print('Error checking auto-approval eligible tickets: $e');
      return 0;
    }
  }

  /// Manually trigger auto-approval process
  static Future<bool> triggerAutoApproval() async {
    try {
      await supabase.rpc('auto_approve_expired_tickets');
      print('✅ Auto-approval process completed');
      return true;
    } catch (e) {
      print('❌ Error triggering auto-approval: $e');
      return false;
    }
  }

  // Setup email batch processor
  static void _setupEmailBatchProcessor() {
    _emailBatchTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_emailQueue.isNotEmpty) {
        _processBatchEmails();
      }
    });
  }

  // Process batch emails
  static Future<void> _processBatchEmails() async {
    if (_emailQueue.isEmpty) return;

    final emailsToSend = List<Map<String, dynamic>>.from(_emailQueue);
    _emailQueue.clear();

    try {
      // Group emails by type for better processing
      final emailGroups = <String, List<Map<String, dynamic>>>{};
      for (final email in emailsToSend) {
        final type = email['type'] as String;
        emailGroups.putIfAbsent(type, () => []).add(email);
      }

      // Send emails in batches
      for (final entry in emailGroups.entries) {
        await _sendEmailBatch(entry.key, entry.value);
        await Future.delayed(Duration(milliseconds: 500)); // Rate limiting
      }

      print('📧 Processed ${emailsToSend.length} batch emails');
    } catch (e) {
      print('❌ Error processing batch emails: $e');
      // Re-queue failed emails
      _emailQueue.addAll(emailsToSend);
    }
  }

  // Send email batch via the send-email edge function (Resend) — one
  // request per email, run in parallel. A failure in one doesn't block the
  // others; failed ones are surfaced via the return value so callers can
  // decide whether to re-queue them.
  static Future<void> _sendEmailBatch(
      String type, List<Map<String, dynamic>> emails) async {
    print('📧 Sending ${emails.length} emails of type: $type');
    final results = await Future.wait(emails.map((email) async {
      final to = email['to'] as String?;
      if (to == null || to.isEmpty || to.endsWith('@phone.user')) {
        return true; // nothing to send to — not a failure worth retrying
      }
      try {
        final res = await supabase.functions.invoke('send-email', body: {
          'to': to,
          'subject': email['subject'] ?? 'Notification',
          'title': email['subject'] ?? 'Notification',
          'message': email['message'] ?? '',
          'recipient_name': email['to_name'],
        });
        final ok = res.data is Map && res.data['ok'] == true;
        if (!ok) print('❌ send-email returned failure for $to: ${res.data}');
        return ok;
      } catch (e) {
        print('❌ Error sending email to $to: $e');
        return false;
      }
    }));

    final sent = results.where((ok) => ok).length;
    print('📧 Sent $sent/${emails.length} emails of type: $type');
  }

  // Get user notification info with caching
  static Future<UserNotificationInfo?> _getUserNotificationInfo(
      String userId) async {
    // Check cache first
    if (_userNotificationCache.containsKey(userId) &&
        DateTime.now().difference(_cacheLastUpdated).compareTo(_cacheExpiry) <
            0) {
      return _userNotificationCache[userId];
    }

    try {
      final response = await supabase
          .from('users')
          .select(
              'id, full_name, email, fcm_token, fcm_token_web, user_type, department_id, place_id, language')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final userInfo = UserNotificationInfo(
        id: response['id'],
        fullName: response['full_name'],
        email: response['email'],
        fcmToken: response['fcm_token'],
        fcmTokenWeb: response['fcm_token_web'],
        userType: response['user_type'],
        departmentId: response['department_id'],
        placeId: response['place_id'],
        language: response['language'] ?? 'en',
      );

      _userNotificationCache[userId] = userInfo;
      _cacheLastUpdated = DateTime.now();

      return userInfo;
    } catch (e) {
      print('❌ Error getting user notification info: $e');
      return null;
    }
  }

  // Get multiple users notification info efficiently
  static Future<Map<String, UserNotificationInfo>> _getBulkUserNotificationInfo(
      List<String> userIds) async {
    final result = <String, UserNotificationInfo>{};
    final uncachedIds = <String>[];

    // Check cache first
    for (final userId in userIds) {
      if (_userNotificationCache.containsKey(userId) &&
          DateTime.now().difference(_cacheLastUpdated).compareTo(_cacheExpiry) <
              0) {
        result[userId] = _userNotificationCache[userId]!;
      } else {
        uncachedIds.add(userId);
      }
    }

    // Fetch uncached users in one query
    if (uncachedIds.isNotEmpty) {
      try {
        final response = await supabase
            .from('users')
            .select(
                'id, full_name, email, fcm_token, fcm_token_web, user_type, department_id, place_id, language')
            .inFilter('id', uncachedIds);

        for (final userData in response) {
          final userInfo = UserNotificationInfo(
            id: userData['id'],
            fullName: userData['full_name'],
            email: userData['email'],
            fcmToken: userData['fcm_token'],
            fcmTokenWeb: userData['fcm_token_web'],
            userType: userData['user_type'],
            departmentId: userData['department_id'],
            placeId: userData['place_id'],
            language: userData['language'] ?? 'en',
          );
          result[userData['id']] = userInfo;
          _userNotificationCache[userData['id']] = userInfo;
        }
        _cacheLastUpdated = DateTime.now();
      } catch (e) {
        print('❌ Error getting bulk user notification info: $e');
      }
    }

    return result;
  }

// FIXED: Main entry point for chat notifications
  static Future<void> notifyChatMessage({
    required String chatRoomId,
    required String senderId,
    required String messageContent,
    String? ticketId,
    String? ticketNumber,
  }) async {
    try {
      print('╔═══════════════════════════════════════════════════════════╗');
      print('║  💬 CHAT MESSAGE NOTIFICATION - STARTING                  ║');
      print('╚═══════════════════════════════════════════════════════════╝');
      print('Chat Room: $chatRoomId');
      print('Sender: $senderId');
      print('Ticket: ${ticketNumber ?? "N/A"}\n');

      if (ticketId == null) {
        print('❌ No ticket ID provided, cannot get participants');
        return;
      }

      // Get all participants
      final participants = await _getChatParticipants(chatRoomId, ticketId);

      // Filter out sender
      final recipientParticipants =
          participants.where((p) => p.id != senderId).toList();

      if (recipientParticipants.isEmpty) {
        print('⚠️ No participants to notify (excluding sender)');
        return;
      }

      // Get sender name
      final senderParticipant = participants.firstWhere(
        (p) => p.id == senderId,
        orElse: () => UserNotificationInfo(
          id: senderId,
          fullName: 'Someone',
          email: '',
          fcmToken: null,
          userType: 'user',
          departmentId: null,
          placeId: null,
        ),
      );
      final senderName = senderParticipant.fullName;

      print('✅ Found ${recipientParticipants.length} recipients');
      print('👤 Sender: $senderName\n');

      // Process each recipient with preference checking
      for (int i = 0; i < recipientParticipants.length; i++) {
        final participant = recipientParticipants[i];
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print(
            'Processing ${i + 1}/${recipientParticipants.length}: ${participant.fullName}');

        await _sendChatNotificationToUser(
          userId: participant.id,
          senderId: senderId,
          senderName: senderName,
          messageContent: messageContent,
          chatRoomId: chatRoomId,
          ticketId: ticketId,
          ticketNumber: ticketNumber,
        );
      }

      print('\n╔═══════════════════════════════════════════════════════════╗');
      print('║  ✅ CHAT NOTIFICATIONS COMPLETED                          ║');
      print('╚═══════════════════════════════════════════════════════════╝\n');
    } catch (e, stackTrace) {
      print('❌ ERROR in notifyChatMessage: $e');
      print('Stack trace: $stackTrace');
    }
  }

// FIXED: Individual user notification with proper preference checking
  static Future<void> _sendChatNotificationToUser({
    required String userId,
    required String senderId,
    required String senderName,
    required String messageContent,
    required String chatRoomId,
    String? ticketId,
    String? ticketNumber,
  }) async {
    try {
      print('\n🔔 Checking notifications for: $userId');

      // Step 1: Get user info
      final userInfo = await _getUserNotificationInfo(userId);
      if (userInfo == null) {
        print('❌ User not found: $userId');
        return;
      }

      print('✓ User: ${userInfo.fullName}');
      print('✓ Email: ${userInfo.email}');
      print('✓ Has FCM (mobile): ${userInfo.fcmToken != null}, (web): ${userInfo.fcmTokenWeb != null}');

      // Step 2: Get preferences
      final preferences = await _getUserNotificationPreferences(userId);

      final pushEnabled = preferences['push_notifications_enabled'] ?? true;
      final chatPushEnabled = preferences['push_chat_messages_enabled'] ?? true;
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      print('✓ Push enabled: $pushEnabled');
      print('✓ Chat push enabled: $chatPushEnabled');
      print('✓ Email enabled: $emailEnabled');

      // Step 3: Build notification content
      final isAr = userInfo.language == 'ar';
      final title = ticketNumber != null
          ? (isAr ? 'رسالة جديدة في #$ticketNumber' : 'New message in #$ticketNumber')
          : (isAr ? 'رسالة جديدة من $senderName' : 'New message from $senderName');

      final truncatedMessage = messageContent.length > 100
          ? '${messageContent.substring(0, 100)}...'
          : messageContent;

      final message = '$senderName: $truncatedMessage';

      // Step 4: Determine if push should be sent
      final shouldSendPush = userInfo.effectiveToken != null &&
          pushEnabled &&
          chatPushEnabled;

      if (shouldSendPush) {
        print('📱 SENDING push notification');
        await _sendPushNotification(
          userInfo: userInfo,
          title: title,
          body: message,
          type: 'new_message',
          ticketId: ticketId,
          chatRoomId: chatRoomId,
          additionalData: {
            'sender_id': senderId,
            'sender_name': senderName,
          },
        );
      } else {
        print('🚫 SKIPPING push notification');
        if (userInfo.effectiveToken == null) {
          print('   Reason: No FCM token (mobile or web)');
        } else if (!pushEnabled) {
          print('   Reason: Push notifications disabled');
        } else if (!chatPushEnabled) {
          print('   Reason: Chat push notifications disabled');
        }
      }

      // Step 5: Determine if email should be sent
      if (emailEnabled) {
        print('📧 QUEUEING email notification');
        await _queueEmailNotification(
          userInfo: userInfo,
          type: 'new_message',
          title: title,
          message: message,
          ticketId: ticketId,
          additionalData: {
            'chat_room_id': chatRoomId,
            'sender_name': senderName,
          },
        );
      } else {
        print('🚫 SKIPPING email notification');
        print('   Reason: Email notifications disabled');
      }

      print('✅ Notification processing complete for ${userInfo.fullName}\n');
    } catch (e, stackTrace) {
      print('❌ ERROR in _sendChatNotificationToUser: $e');
      print('Stack trace: $stackTrace');
    }
  }

// FIXED: Generic notification creation with proper preference handling
  static Future<void> createAndSendNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? ticketId,
    String? chatRoomId,
    String? senderId,
    Map<String, dynamic>? additionalData,
    bool skipDatabaseInsert = false,
  }) async {
    try {
      final userInfo = await _getUserNotificationInfo(userId);
      if (userInfo == null) {
        print('❌ User not found: $userId');
        return;
      }

      // Get preferences
      final preferences = await _getUserNotificationPreferences(userId);

      // Determine notification category
      final isChatMessage = type == 'new_message';
      final isCriticalNotification = _isCriticalNotificationType(type);

      // Create in-app notification (unless skipped for chat)
      if (!skipDatabaseInsert) {
        try {
          await supabase.from('notifications').insert({
            'user_id': userId,
            'type': type,
            'title': title,
            'message': message,
            'ticket_id': ticketId,
            'chat_room_id': chatRoomId,
            'sender_id': senderId,
            'action_data':
                additionalData != null ? json.encode(additionalData) : null,
            'priority': _getPriorityForType(type),
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          print('❌ Error creating in-app notification: $dbError');
        }
      }

      // PUSH NOTIFICATION LOGIC
      final pushEnabled = preferences['push_notifications_enabled'] ?? true;
      final chatPushEnabled = preferences['push_chat_messages_enabled'] ?? true;
      final hasActiveFcmToken = userInfo.effectiveToken != null;

      bool shouldSendPush = false;

      if (hasActiveFcmToken && pushEnabled) {
        if (isChatMessage) {
          // For chat messages, respect the chat-specific preference
          shouldSendPush = chatPushEnabled;
        } else {
          // For non-chat notifications, just check general push setting
          shouldSendPush = true;
        }
      }

      if (shouldSendPush) {
        await _sendPushNotification(
          userInfo: userInfo,
          title: title,
          body: message,
          type: type,
          ticketId: ticketId,
          chatRoomId: chatRoomId,
          additionalData: additionalData,
        );
        print('📱 Push sent to ${userInfo.fullName}');
      } else {
        print('🚫 Push skipped for ${userInfo.fullName}');
      }

      // EMAIL NOTIFICATION LOGIC
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      // Send email for critical notifications or if no FCM token
      if (emailEnabled && (isCriticalNotification || !hasActiveFcmToken)) {
        await _queueEmailNotification(
          userInfo: userInfo,
          type: type,
          title: title,
          message: message,
          ticketId: ticketId,
          additionalData: additionalData,
        );
        print('📧 Email queued for ${userInfo.fullName}');
      }
    } catch (e) {
      print('❌ Error in createAndSendNotification: $e');
    }
  }

  static Future<void> notifyTicketCreated({
    required String ticketId,
    required String createdByUserId,
    required String targetDepartmentId,
    required String ticketNumber,
    required String ticketTitle,
  }) async {
    try {
      print('🎫 Starting ticket creation notification process...');
      print('   Ticket: $ticketNumber - $ticketTitle');

      // Get ticket details for email
      final ticketDetails = await supabase.from('tickets').select('''
          *,
          department:departments!target_department_id(name),
          place:places!place_id(name)
        ''').eq('id', ticketId).single();

      // Get creator info
      final creator = await _getUserNotificationInfo(createdByUserId);
      if (creator == null) {
        print('❌ Creator not found: $createdByUserId');
        return;
      }

      // Get ONLY super admins of the target department
      final superAdminsResponse = await supabase
          .from('users')
          .select('id, full_name, email, fcm_token, fcm_token_web, user_type, department_id, language')
          .eq('department_id', targetDepartmentId)
          .eq('user_type', 'super_admin')
          .eq('is_active', true);

      print(
          '👥 Found ${superAdminsResponse.length} super admins in department');

      final departmentName = ticketDetails['department']?['name'] ?? 'Unknown';
      final placeName = ticketDetails['place']?['name'] ??
          ticketDetails['other_place'] ??
          'Not specified';
      final description = ticketDetails['description'] ?? '';
      final priority = ticketDetails['priority'] ?? 'medium';
      final highPriorityExplain = ticketDetails['high_priority_explain'];
      final location = ticketDetails['location'] ?? 'Not specified';

      final notificationTasks = <Future>[];

      for (final adminData in superAdminsResponse) {
        if (adminData['id'] != createdByUserId) {
          final adminInfo = UserNotificationInfo(
            id: adminData['id'],
            fullName: adminData['full_name'],
            email: adminData['email'],
            fcmToken: adminData['fcm_token'],
            fcmTokenWeb: adminData['fcm_token_web'],
            userType: adminData['user_type'],
            departmentId: targetDepartmentId,
            placeId: null,
            language: adminData['language'] ?? 'en',
          );

          // Send in-app and push notification
          final ticketCreatedNotif = _getLocalizedTicketCreatedNotification(
            ticketNumber: ticketNumber,
            creatorName: creator.fullName,
            ticketTitle: ticketTitle,
            lang: adminInfo.language,
          );
          notificationTasks.add(createAndSendNotification(
            userId: adminInfo.id,
            type: 'ticket_created',
            title: ticketCreatedNotif['title']!,
            message: ticketCreatedNotif['message']!,
            ticketId: ticketId,
            additionalData: {
              'ticket_number': ticketNumber,
              'ticket_title': ticketTitle,
              'created_by': creator.id,
              'creator_name': creator.fullName,
            },
          ));

          // Send detailed email
          notificationTasks.add(_sendTicketCreatedDetailedEmail(
            adminInfo: adminInfo,
            creator: creator,
            ticketNumber: ticketNumber,
            ticketTitle: ticketTitle,
            description: description,
            departmentName: departmentName,
            placeName: placeName,
            location: location,
            priority: priority,
            highPriorityExplain: highPriorityExplain,
          ));
        }
      }

      await Future.wait(notificationTasks);
      print('✅ Ticket creation notifications completed for $ticketNumber');
    } catch (e) {
      print('❌ Error in notifyTicketCreated: $e');
    }
  }

// Detailed email for ticket creation
  static Future<void> _sendTicketCreatedDetailedEmail({
    required UserNotificationInfo adminInfo,
    required UserNotificationInfo creator,
    required String ticketNumber,
    required String ticketTitle,
    required String description,
    required String departmentName,
    required String placeName,
    required String location,
    required String priority,
    String? highPriorityExplain,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(adminInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${adminInfo.fullName} (disabled)');
        return;
      }

      final priorityColor = _getPriorityColor(priority);
      final priorityLabel = priority.toUpperCase();

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .ticket-info { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #667eea; }
          .info-row { display: flex; margin: 10px 0; padding: 8px 0; border-bottom: 1px solid #f3f4f6; }
          .info-label { font-weight: bold; color: #6b7280; min-width: 150px; }
          .info-value { color: #111827; flex: 1; }
          .priority-badge { 
            display: inline-block; 
            padding: 4px 12px; 
            border-radius: 12px; 
            font-size: 12px; 
            font-weight: bold; 
            color: white;
            background-color: $priorityColor;
          }
          .description-box { 
            background: #f3f4f6; 
            padding: 15px; 
            border-radius: 6px; 
            margin: 15px 0;
            border-left: 3px solid #667eea;
          }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .action-required { background: #fef3c7; padding: 15px; border-radius: 6px; border-left: 4px solid #f59e0b; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎫 New Ticket Created</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">A new ticket requires your attention</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${adminInfo.fullName}</strong>,</p>
            
            <div class="action-required">
              <strong>⚡ Action Required:</strong> A new ticket has been submitted to your department and needs to be reviewed and assigned.
            </div>
            
            <div class="ticket-info">
              <h2 style="margin-top: 0; color: #667eea;">Ticket Details</h2>
              
              <div class="info-row">
                <div class="info-label">Ticket Number:</div>
                <div class="info-value"><strong>#$ticketNumber</strong></div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Title:</div>
                <div class="info-value"><strong>$ticketTitle</strong></div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Priority:</div>
                <div class="info-value"><span class="priority-badge">$priorityLabel</span></div>
              </div>
              
              ${highPriorityExplain != null && highPriorityExplain.isNotEmpty ? '''
              <div class="info-row">
                <div class="info-label">Priority Reason:</div>
                <div class="info-value" style="color: #dc2626;"><strong>$highPriorityExplain</strong></div>
              </div>
              ''' : ''}
              
              <div class="info-row">
                <div class="info-label">Department:</div>
                <div class="info-value">$departmentName</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Location/Place:</div>
                <div class="info-value">$placeName</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Specific Location:</div>
                <div class="info-value">$location</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Created By:</div>
                <div class="info-value">${creator.fullName} (${creator.email})</div>
              </div>
              
              <div class="description-box">
                <strong style="color: #667eea;">Description:</strong>
                <p style="margin: 10px 0 0 0; white-space: pre-wrap;">$description</p>
              </div>
            </div>
            
            <p style="margin-top: 25px;">Please log in to the JalaSupport system to review this ticket and assign it to the appropriate administrator.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: adminInfo.email,
        toName: adminInfo.fullName,
        subject: '🎫 New Ticket Created - #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Detailed creation email sent to ${adminInfo.fullName}');
    } catch (e) {
      print('❌ Error sending ticket created email: $e');
    }
  }

// NEW: Email sending with preference check
  static Future<void> _sendTicketCreatedEmailIfEnabled({
    required UserNotificationInfo adminInfo,
    required UserNotificationInfo creator,
    required String ticketNumber,
    required String ticketTitle,
    required String departmentName,
  }) async {
    try {
      // Check email preferences
      final preferences = await _getUserNotificationPreferences(adminInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (emailEnabled) {
        await EmailService.sendTicketCreatedEmail(
          toEmail: adminInfo.email,
          toName: adminInfo.fullName,
          ticketNumber: ticketNumber,
          ticketTitle: ticketTitle,
          creatorName: creator.fullName,
          departmentName: departmentName,
        );
        print('📧 Email sent to ${adminInfo.fullName}');
      } else {
        print(
            '🚫 Email skipped for ${adminInfo.fullName} (email notifications disabled)');
      }
    } catch (e) {
      print('❌ Error sending ticket created email: $e');
    }
  }

  // Helper method for ticket creation notification
  static Future<void> _sendTicketCreatedNotification({
    required UserNotificationInfo adminInfo,
    required UserNotificationInfo creator,
    required String ticketId,
    required String ticketNumber,
    required String ticketTitle,
  }) async {
    final notif = _getLocalizedTicketCreatedNotification(
      ticketNumber: ticketNumber,
      creatorName: creator.fullName,
      ticketTitle: ticketTitle,
      lang: adminInfo.language,
    );
    await createAndSendNotification(
      userId: adminInfo.id,
      type: 'ticket_created',
      title: notif['title']!,
      message: notif['message']!,
      ticketId: ticketId,
      additionalData: {
        'ticket_number': ticketNumber,
        'ticket_title': ticketTitle,
        'created_by': creator.id,
        'creator_name': creator.fullName,
        'creator_email': creator.email,
      },
    );
  }

// Updated notifyNewChatMessage - skip database insert
  static Future<void> notifyNewChatMessage({
    required String chatRoomId,
    required String ticketId,
    required String senderId,
    required String message,
    required String ticketNumber,
  }) async {
    try {
      print('💬 Processing new chat message notification...');

      final participants = await _getChatParticipants(chatRoomId, ticketId);
      final sender = await _getUserNotificationInfo(senderId);

      if (sender == null) {
        print('❌ Sender not found: $senderId');
        return;
      }

      print('👤 Sender: ${sender.fullName}');
      print('👥 Participants: ${participants.length}');

      final notificationTasks = <Future>[];

      for (final participant in participants) {
        if (participant.id != senderId) {
          notificationTasks.add(_sendChatMessageNotification(
            participant: participant,
            sender: sender,
            message: message,
            ticketNumber: ticketNumber,
            ticketId: ticketId,
            chatRoomId: chatRoomId,
          ));
        }
      }

      await Future.wait(notificationTasks);
      print('✅ Chat message notifications sent for ticket #$ticketNumber');
    } catch (e) {
      print('❌ Error notifying new chat message: $e');
    }
  }

  // Updated helper for chat message notification
  static Future<void> _sendChatMessageNotification({
    required UserNotificationInfo participant,
    required UserNotificationInfo sender,
    required String message,
    required String ticketNumber,
    required String ticketId,
    required String chatRoomId,
  }) async {
    final shortMessage =
        message.length > 100 ? '${message.substring(0, 100)}...' : message;

    final chatNotif = _getLocalizedChatNotification(
      senderName: sender.fullName,
      ticketNumber: ticketNumber,
      shortMessage: shortMessage,
      lang: participant.language,
    );

    // Skip database insert for chat messages
    await createAndSendNotification(
      userId: participant.id,
      type: 'new_message',
      title: chatNotif['title']!,
      message: chatNotif['message']!,
      ticketId: ticketId,
      chatRoomId: chatRoomId,
      senderId: sender.id,
      additionalData: {
        'ticket_number': ticketNumber,
        'sender_name': sender.fullName,
        'sender_email': sender.email,
        'full_message': message,
        'chat_room_id': chatRoomId,
      },
      skipDatabaseInsert: true, // Skip database for chat messages
    );
  }

  static Future<void> notifyTicketAssigned({
    required String ticketId,
    required String assignedToUserId,
    required String assignedByUserId,
    required String ticketNumber,
    required String ticketTitle,
  }) async {
    try {
      print('👤 Processing ticket assignment notification...');

      // Get ticket details
      final ticketDetails = await supabase.from('tickets').select('''
          *,
          creator:users!created_by(full_name, email),
          department:departments!target_department_id(name),
          place:places!place_id(name)
        ''').eq('id', ticketId).single();

      final futures = await Future.wait([
        _getUserNotificationInfo(assignedByUserId),
        _getUserNotificationInfo(assignedToUserId),
        _getUserNotificationInfo(ticketDetails['created_by']),
      ]);

      final assigner = futures[0] as UserNotificationInfo?;
      final assignedUser = futures[1] as UserNotificationInfo?;
      final creator = futures[2] as UserNotificationInfo?;

      if (assigner == null || assignedUser == null) {
        print('❌ User info not found');
        return;
      }

      final description = ticketDetails['description'] ?? '';
      final priority = ticketDetails['priority'] ?? 'medium';
      final highPriorityExplain = ticketDetails['high_priority_explain'];
      final departmentName = ticketDetails['department']?['name'] ?? 'Unknown';
      final placeName = ticketDetails['place']?['name'] ??
          ticketDetails['other_place'] ??
          'Not specified';
      final location = ticketDetails['location'] ?? 'Not specified';

      final tasks = <Future>[];

      // Notify assigned admin with detailed ticket info
      final assignedAdminNotif = _getLocalizedTicketAssignedToAdminNotification(
        ticketNumber: ticketNumber,
        assignerName: assigner.fullName,
        lang: assignedUser.language,
      );
      tasks.add(createAndSendNotification(
        userId: assignedToUserId,
        type: 'ticket_assigned',
        title: assignedAdminNotif['title']!,
        message: assignedAdminNotif['message']!,
        ticketId: ticketId,
        additionalData: {
          'ticket_number': ticketNumber,
          'ticket_title': ticketTitle,
          'assigned_by': assignedByUserId,
          'assigner_name': assigner.fullName,
        },
      ));

      tasks.add(_sendTicketAssignedToAdminEmail(
        adminInfo: assignedUser,
        ticketNumber: ticketNumber,
        ticketTitle: ticketTitle,
        description: description,
        priority: priority,
        highPriorityExplain: highPriorityExplain,
        departmentName: departmentName,
        placeName: placeName,
        location: location,
        assignedByName: assigner.fullName,
        creatorName: creator?.fullName ?? 'Unknown',
        creatorEmail: creator?.email ?? '',
      ));

      // Notify ticket creator (if different from assigner) with simple update
      if (creator != null && creator.id != assignedByUserId) {
        final creatorAssignedNotif = _getLocalizedAssignedCreatorNotification(
          ticketNumber: ticketNumber,
          assignedToName: assignedUser.fullName,
          lang: creator.language,
        );
        tasks.add(createAndSendNotification(
          userId: creator.id,
          type: 'ticket_assigned',
          title: creatorAssignedNotif['title']!,
          message: creatorAssignedNotif['message']!,
          ticketId: ticketId,
          additionalData: {
            'ticket_number': ticketNumber,
            'assigned_to': assignedToUserId,
            'assigned_to_name': assignedUser.fullName,
          },
        ));

        tasks.add(_sendTicketAssignedToCreatorEmail(
          creatorInfo: creator,
          ticketNumber: ticketNumber,
          ticketTitle: ticketTitle,
          assignedToName: assignedUser.fullName,
        ));
      }

      await Future.wait(tasks);
      print('✅ Ticket assignment notifications sent');
    } catch (e) {
      print('❌ Error notifying ticket assigned: $e');
    }
  }

// Email to the admin who got the ticket assigned
  static Future<void> _sendTicketAssignedToAdminEmail({
    required UserNotificationInfo adminInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String description,
    required String priority,
    String? highPriorityExplain,
    required String departmentName,
    required String placeName,
    required String location,
    required String assignedByName,
    required String creatorName,
    required String creatorEmail,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(adminInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${adminInfo.fullName} (disabled)');
        return;
      }

      final priorityColor = _getPriorityColor(priority);
      final priorityLabel = priority.toUpperCase();

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .ticket-info { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #10b981; }
          .info-row { display: flex; margin: 10px 0; padding: 8px 0; border-bottom: 1px solid #f3f4f6; }
          .info-label { font-weight: bold; color: #6b7280; min-width: 150px; }
          .info-value { color: #111827; flex: 1; }
          .priority-badge { 
            display: inline-block; 
            padding: 4px 12px; 
            border-radius: 12px; 
            font-size: 12px; 
            font-weight: bold; 
            color: white;
            background-color: $priorityColor;
          }
          .description-box { 
            background: #f3f4f6; 
            padding: 15px; 
            border-radius: 6px; 
            margin: 15px 0;
            border-left: 3px solid #10b981;
          }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .highlight-box { background: #d1fae5; padding: 15px; border-radius: 6px; border-left: 4px solid #10b981; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎯 Ticket Assigned to You</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">You are now responsible for this ticket</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${adminInfo.fullName}</strong>,</p>
            
            <div class="highlight-box">
              <strong>✅ Assignment Notice:</strong> The following ticket has been assigned to you by <strong>$assignedByName</strong>. Please review the details and begin working on it.
            </div>
            
            <div class="ticket-info">
              <h2 style="margin-top: 0; color: #10b981;">Ticket Details</h2>
              
              <div class="info-row">
                <div class="info-label">Ticket Number:</div>
                <div class="info-value"><strong>#$ticketNumber</strong></div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Title:</div>
                <div class="info-value"><strong>$ticketTitle</strong></div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Priority:</div>
                <div class="info-value"><span class="priority-badge">$priorityLabel</span></div>
              </div>
              
              ${highPriorityExplain != null && highPriorityExplain.isNotEmpty ? '''
              <div class="info-row">
                <div class="info-label">Priority Reason:</div>
                <div class="info-value" style="color: #dc2626;"><strong>$highPriorityExplain</strong></div>
              </div>
              ''' : ''}
              
              <div class="info-row">
                <div class="info-label">Department:</div>
                <div class="info-value">$departmentName</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Location/Place:</div>
                <div class="info-value">$placeName</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Specific Location:</div>
                <div class="info-value">$location</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Ticket Creator:</div>
                <div class="info-value">$creatorName${creatorEmail.isNotEmpty ? ' ($creatorEmail)' : ''}</div>
              </div>
              
              <div class="info-row">
                <div class="info-label">Assigned By:</div>
                <div class="info-value">$assignedByName</div>
              </div>
              
              <div class="description-box">
                <strong style="color: #10b981;">Description:</strong>
                <p style="margin: 10px 0 0 0; white-space: pre-wrap;">$description</p>
              </div>
            </div>
            
            <p style="margin-top: 25px;">Please log in to the JalaSupport system to start working on this ticket and provide updates to the ticket creator.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: adminInfo.email,
        toName: adminInfo.fullName,
        subject: '🎯 Ticket Assigned to You - #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Assignment email sent to admin ${adminInfo.fullName}');
    } catch (e) {
      print('❌ Error sending assignment email to admin: $e');
    }
  }

  static Future<void> notifyTicketMarkedFinished({
    required String ticketId,
    required String ticketCreatorId,
    required String finishedByUserId,
    required String ticketNumber,
    required String ticketTitle,
    required String reportTitle,
    required String reportDescription,
  }) async {
    try {
      print(
          '⏳ Notifying creator about ticket completion (awaiting approval)...');

      final futures = await Future.wait([
        _getUserNotificationInfo(finishedByUserId),
        _getUserNotificationInfo(ticketCreatorId),
      ]);

      final finisher = futures[0] as UserNotificationInfo?;
      final creator = futures[1] as UserNotificationInfo?;

      if (finisher == null || creator == null) {
        print('❌ User info not found');
        return;
      }

      // Send in-app notification
      final prefinishedNotif = _getLocalizedPrefinishedNotification(
        ticketNumber: ticketNumber,
        finishedByName: finisher.fullName,
        lang: creator.language,
      );
      await createAndSendNotification(
        userId: ticketCreatorId,
        type: 'ticket_prefinished',
        title: prefinishedNotif['title']!,
        message: prefinishedNotif['message']!,
        ticketId: ticketId,
        additionalData: {
          'ticket_number': ticketNumber,
          'finished_by': finishedByUserId,
          'finisher_name': finisher.fullName,
        },
      );

      // Send detailed email
      await _sendTicketFinishedAwaitingApprovalEmail(
        creatorInfo: creator,
        ticketNumber: ticketNumber,
        ticketTitle: ticketTitle,
        finishedByName: finisher.fullName,
        reportTitle: reportTitle,
        reportDescription: reportDescription,
      );

      print('✅ Ticket completion notification sent');
    } catch (e) {
      print('❌ Error notifying ticket finished: $e');
    }
  }

  static Future<void> notifyTicketUnderSupervision({
    required String ticketId,
    required String ticketCreatorId,
    required String supervisedByUserId,
    required String ticketNumber,
    required String ticketTitle,
    required String reportTitle,
    required String reportDescription,
  }) async {
    try {
      print('🔍 Notifying creator about ticket under supervision...');

      final futures = await Future.wait([
        _getUserNotificationInfo(supervisedByUserId),
        _getUserNotificationInfo(ticketCreatorId),
      ]);

      final supervisor = futures[0] as UserNotificationInfo?;
      final creator = futures[1] as UserNotificationInfo?;

      if (supervisor == null || creator == null) {
        print('❌ User info not found');
        return;
      }

      // Get auto-approval time
      final approvalMinutes = await getAutoApprovalMinutes();

      // Send in-app notification
      final supervisionNotif = _getLocalizedSupervisionNotification(
        ticketNumber: ticketNumber,
        approvalMinutes: approvalMinutes.toString(),
        lang: creator.language,
      );
      await createAndSendNotification(
        userId: ticketCreatorId,
        type: 'ticket_under_supervision',
        title: supervisionNotif['title']!,
        message: supervisionNotif['message']!,
        ticketId: ticketId,
        additionalData: {
          'ticket_number': ticketNumber,
          'supervised_by': supervisedByUserId,
          'supervisor_name': supervisor.fullName,
          'approval_minutes': approvalMinutes.toString(),
        },
      );

      // Send email
      await _sendTicketUnderSupervisionEmail(
        creatorInfo: creator,
        ticketNumber: ticketNumber,
        ticketTitle: ticketTitle,
        supervisedByName: supervisor.fullName,
        reportTitle: reportTitle,
        reportDescription: reportDescription,
        approvalMinutes: approvalMinutes,
      );

      print('✅ Supervision notification sent');
    } catch (e) {
      print('❌ Error notifying supervision: $e');
    }
  }

// Email for ticket under supervision
  static Future<void> _sendTicketUnderSupervisionEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String supervisedByName,
    required String reportTitle,
    required String reportDescription,
    required int approvalMinutes,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final approvalHours = (approvalMinutes / 60).floor();
      final remainingMinutes = approvalMinutes % 60;
      final timeDisplay = approvalHours > 0
          ? '$approvalHours hour${approvalHours > 1 ? 's' : ''}${remainingMinutes > 0 ? ' and $remainingMinutes minutes' : ''}'
          : '$approvalMinutes minutes';

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #06b6d4; }
          .report-box { background: #f3f4f6; padding: 15px; border-radius: 6px; margin: 15px 0; border-left: 3px solid #06b6d4; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .supervision-box { background: #cffafe; padding: 15px; border-radius: 6px; border-left: 4px solid #06b6d4; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔍 Ticket Under Supervision</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Work completed - Monitoring period started</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <div class="supervision-box">
              <strong>✅ Work Completed:</strong> Your ticket has been marked as complete and is now under supervision. It will be automatically approved after the monitoring period unless issues are found.
            </div>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #06b6d4;">Ticket Information</h2>
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Ticket Title:</strong> $ticketTitle</p>
              <p><strong>Supervised By:</strong> $supervisedByName</p>
              <p><strong>Auto-Approval Time:</strong> $timeDisplay</p>
              
              <div class="report-box">
                <h3 style="margin-top: 0; color: #06b6d4;">Completion Report</h3>
                <p><strong>Report Title:</strong> $reportTitle</p>
                <p><strong>Details:</strong></p>
                <p style="white-space: pre-wrap; margin: 10px 0 0 0;">$reportDescription</p>
              </div>
            </div>
            
            <p><strong>What happens next:</strong></p>
            <ul>
              <li>The ticket will be monitored for $timeDisplay</li>
              <li>If no issues are found, it will be automatically approved</li>
              <li>If issues arise, the administrator will return it to in-progress status</li>
              <li>You will be notified of the final approval</li>
            </ul>
            
            <p style="margin-top: 25px;">No action is required from you. You will receive a notification once the ticket is officially closed.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '🔍 Ticket Under Supervision - #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Supervision email sent to ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending supervision email: $e');
    }
  }

// Email for ticket finished awaiting approval
  static Future<void> _sendTicketFinishedAwaitingApprovalEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String finishedByName,
    required String reportTitle,
    required String reportDescription,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #8b5cf6; }
          .report-box { background: #f3f4f6; padding: 15px; border-radius: 6px; margin: 15px 0; border-left: 3px solid #8b5cf6; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .action-box { background: #ede9fe; padding: 15px; border-radius: 6px; border-left: 4px solid #8b5cf6; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>⏳ Ticket Completed - Your Approval Needed</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Please review and approve the completed work</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <div class="action-box">
              <strong>✅ Work Completed - Action Required:</strong> The administrator has completed work on your ticket and it now awaits your approval.
            </div>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #8b5cf6;">Ticket Information</h2>
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Ticket Title:</strong> $ticketTitle</p>
              <p><strong>Completed By:</strong> $finishedByName</p>
              
              <div class="report-box">
                <h3 style="margin-top: 0; color: #8b5cf6;">Completion Report</h3>
                <p><strong>Report Title:</strong> $reportTitle</p>
                <p><strong>Details:</strong></p>
                <p style="white-space: pre-wrap; margin: 10px 0 0 0;">$reportDescription</p>
              </div>
            </div>
            
            <p><strong>Next Steps:</strong></p>
            <ul>
              <li>Log in to the JalaSupport system</li>
              <li>Review the work that was completed</li>
              <li>Check if the issue has been fully resolved</li>
              <li>Approve the ticket if you're satisfied with the work</li>
              <li>Or request additional work if needed</li>
            </ul>
            
            <p style="margin-top: 25px;">Your approval is important to ensure the issue has been fully resolved to your satisfaction.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '⏳ Your Approval Needed - Ticket #$ticketNumber Completed',
        htmlContent: html,
      );

      print('📧 Awaiting approval email sent to ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending awaiting approval email: $e');
    }
  }

// Email to ticket creator about assignment
  static Future<void> _sendTicketAssignedToCreatorEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String assignedToName,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3b82f6; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .status-badge { 
            display: inline-block; 
            padding: 6px 14px; 
            border-radius: 20px; 
            font-size: 13px; 
            font-weight: bold; 
            color: white;
            background-color: #10b981;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>✅ Your Ticket Has Been Assigned</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">An administrator is now working on your ticket</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <p>Good news! Your ticket has been assigned to an administrator who will start working on resolving your issue.</p>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #3b82f6;">Assignment Details</h2>
              
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Ticket Title:</strong> $ticketTitle</p>
              <p><strong>Status:</strong> <span class="status-badge">IN PROGRESS</span></p>
              <p><strong>Assigned Administrator:</strong> $assignedToName</p>
            </div>
            
            <p>The assigned administrator will review your ticket and may contact you if additional information is needed. You will receive notifications about any updates on your ticket.</p>
            
            <p>Thank you for your patience!</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '✅ Your Ticket Has Been Assigned - #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Assignment email sent to creator ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending assignment email to creator: $e');
    }
  }

// NEW: Email helper with preference checking
  static Future<void> _sendTicketAssignedEmailIfEnabled({
    required UserNotificationInfo adminInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String assignedByName,
    String? assignedToName,
    required bool isCreatorNotification,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(adminInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (emailEnabled) {
        await EmailService.sendTicketAssignedEmail(
          toEmail: adminInfo.email,
          toName: adminInfo.fullName,
          ticketNumber: ticketNumber,
          ticketTitle: ticketTitle,
          assignedByName: assignedByName,
          assignedToName: assignedToName ?? adminInfo.fullName,
          isCreatorNotification: isCreatorNotification,
        );
        print('📧 Assignment email sent to ${adminInfo.fullName}');
      } else {
        print(
            '🚫 Assignment email skipped for ${adminInfo.fullName} (disabled)');
      }
    } catch (e) {
      print('❌ Error sending assignment email: $e');
    }
  }

  static Future<void> notifyTicketStatusChanged({
    required String ticketId,
    required String ticketCreatorId,
    required String changedByUserId,
    required String ticketNumber,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      if (ticketCreatorId == changedByUserId) return;

      print('🔄 Processing ticket status change notification...');

      // Get ticket details
      final ticketDetails = await supabase.from('tickets').select('''
          title,
          description,
          under_supervision
        ''').eq('id', ticketId).single();

      final futures = await Future.wait([
        _getUserNotificationInfo(changedByUserId),
        _getUserNotificationInfo(ticketCreatorId),
      ]);

      final changer = futures[0] as UserNotificationInfo?;
      final creator = futures[1] as UserNotificationInfo?;

      if (changer == null || creator == null) {
        print('❌ User info not found');
        return;
      }

      final ticketTitle = ticketDetails['title'] ?? '';
      final underSupervision = ticketDetails['under_supervision'] ?? false;

      // Don't send email for simple status changes - only for specific actions
      // This method should only be called for status changes that aren't covered by other methods

      // For prefinished status, we handle it in markTicketFinished methods
      // For closed status, we handle it in approval methods
      // Only send notification for other status changes

      if (newStatus != 'prefinished' && newStatus != 'closed') {
        final localizedNotif = _getLocalizedStatusNotification(
          newStatus: newStatus,
          ticketNumber: ticketNumber,
          changedByName: changer.fullName,
          lang: creator.language,
        );

        await createAndSendNotification(
          userId: ticketCreatorId,
          type: 'ticket_status_changed',
          title: localizedNotif['title']!,
          message: localizedNotif['message']!,
          ticketId: ticketId,
          additionalData: {
            'ticket_number': ticketNumber,
            'old_status': oldStatus,
            'new_status': newStatus,
            'changed_by': changedByUserId,
            'changer_name': changer.fullName,
          },
        );

        // Only send email for significant status changes
        if (newStatus == 'wrong_info') {
          await _sendTicketNeedsInfoEmail(
            creatorInfo: creator,
            ticketNumber: ticketNumber,
            ticketTitle: ticketTitle,
            changedByName: changer.fullName,
          );
        }
      }

      print('✅ Ticket status change notification sent');
    } catch (e) {
      print('❌ Error notifying ticket status changed: $e');
    }
  }

// Email for when ticket needs more information
  static Future<void> _sendTicketNeedsInfoEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String changedByName,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f59e0b; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .warning-box { background: #fef3c7; padding: 15px; border-radius: 6px; border-left: 4px solid #f59e0b; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>❓ Additional Information Needed</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Your ticket requires more details</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <div class="warning-box">
              <strong>⚠️ Action Required:</strong> The administrator needs additional information to proceed with your ticket.
            </div>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #f59e0b;">Ticket Details</h2>
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Title:</strong> $ticketTitle</p>
              <p><strong>Reviewed By:</strong> $changedByName</p>
            </div>
            
            <p>Please log in to the JalaSupport system to view the administrator's comments and provide the requested information to help us resolve your issue quickly.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '❓ Additional Information Needed - Ticket #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Info needed email sent to ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending info needed email: $e');
    }
  }

// NEW: Email helper for status changes
  static Future<void> _sendStatusChangedEmailIfEnabled({
    required UserNotificationInfo creator,
    required String ticketNumber,
    required String oldStatus,
    required String newStatus,
    required String changedByName,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creator.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (emailEnabled) {
        await EmailService.sendTicketStatusChangedEmail(
          toEmail: creator.email,
          toName: creator.fullName,
          ticketNumber: ticketNumber,
          oldStatus: oldStatus,
          newStatus: newStatus,
          changedByName: changedByName,
        );
        print('📧 Status change email sent to ${creator.fullName}');
      } else {
        print(
            '🚫 Status change email skipped for ${creator.fullName} (disabled)');
      }
    } catch (e) {
      print('❌ Error sending status change email: $e');
    }
  }

  static Future<void> notifyTicketApproved({
    required String ticketId,
    required String ticketCreatorId,
    required String approvedByUserId,
    required String ticketNumber,
    required bool isApproved,
    String? rejectionReason,
    bool isAutoApproval = false,
  }) async {
    try {
      if (ticketCreatorId == approvedByUserId && !isAutoApproval) return;

      print(
          '${isApproved ? "✅" : "❌"} Processing ticket approval notification...');

      final creator = await _getUserNotificationInfo(ticketCreatorId);
      if (creator == null) {
        print('❌ Creator not found');
        return;
      }

      UserNotificationInfo? approver;
      if (!isAutoApproval) {
        approver = await _getUserNotificationInfo(approvedByUserId);
      }

      // Get ticket title
      final ticketDetails = await supabase
          .from('tickets')
          .select('title')
          .eq('id', ticketId)
          .single();

      final ticketTitle = ticketDetails['title'] ?? '';

      if (isApproved) {
        // Send approval notification
        final approvalNotif = _getLocalizedApprovalNotification(
          ticketNumber: ticketNumber,
          isApproved: true,
          isAutoApproval: isAutoApproval,
          approverName: approver?.fullName ?? 'Administrator',
          lang: creator.language,
        );
        await createAndSendNotification(
          userId: ticketCreatorId,
          type: 'ticket_approved',
          title: approvalNotif['title']!,
          message: approvalNotif['message']!,
          ticketId: ticketId,
          additionalData: {
            'ticket_number': ticketNumber,
            'is_auto_approval': isAutoApproval.toString(),
            if (!isAutoApproval) 'approved_by': approvedByUserId,
            if (!isAutoApproval) 'approver_name': approver?.fullName ?? '',
          },
        );

        // Send approval email
        await _sendTicketApprovedEmail(
          creatorInfo: creator,
          ticketNumber: ticketNumber,
          ticketTitle: ticketTitle,
          approverName: isAutoApproval ? null : approver?.fullName,
          isAutoApproval: isAutoApproval,
        );
      } else {
        // Send rejection notification
        final rejectionNotif = _getLocalizedApprovalNotification(
          ticketNumber: ticketNumber,
          isApproved: false,
          isAutoApproval: false,
          approverName: approver?.fullName ?? 'Administrator',
          rejectionReason: rejectionReason,
          lang: creator.language,
        );
        await createAndSendNotification(
          userId: ticketCreatorId,
          type: 'ticket_rejected',
          title: rejectionNotif['title']!,
          message: rejectionNotif['message']!,
          ticketId: ticketId,
          additionalData: {
            'ticket_number': ticketNumber,
            'approved_by': approvedByUserId,
            'approver_name': approver?.fullName ?? '',
            if (rejectionReason != null) 'rejection_reason': rejectionReason,
          },
        );

        // Send rejection email
        await _sendTicketRejectedEmail(
          creatorInfo: creator,
          ticketNumber: ticketNumber,
          ticketTitle: ticketTitle,
          rejectedByName: approver?.fullName ?? 'Administrator',
          rejectionReason: rejectionReason,
        );
      }

      print('✅ Approval/rejection notification sent');
    } catch (e) {
      print('❌ Error notifying ticket approval: $e');
    }
  }

// Email for approved ticket
  static Future<void> _sendTicketApprovedEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    String? approverName,
    required bool isAutoApproval,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #10b981; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .success-box { background: #d1fae5; padding: 15px; border-radius: 6px; border-left: 4px solid #10b981; margin: 20px 0; }
          .checkmark { font-size: 48px; text-align: center; color: #10b981; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>✅ Ticket Approved and Closed</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Your issue has been successfully resolved</p>
          </div>
          
          <div class="content">
            <div class="checkmark">✓</div>
            
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <div class="success-box">
              <strong>✅ Ticket Closed:</strong> Your ticket has been ${isAutoApproval ? 'automatically approved after the supervision period' : 'approved'} and is now closed.
            </div>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #10b981;">Ticket Summary</h2>
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Title:</strong> $ticketTitle</p>
              <p><strong>Status:</strong> <span style="color: #10b981; font-weight: bold;">CLOSED</span></p>
              ${!isAutoApproval && approverName != null ? '<p><strong>Approved By:</strong> $approverName</p>' : ''}
              ${isAutoApproval ? '<p><strong>Approval Type:</strong> Automatic (after supervision period)</p>' : ''}
            </div>
            
            <p>Thank you for using JalaSupport. We're glad we could help resolve your issue!</p>
            
            <p>If you experience similar issues in the future or have any feedback about our service, please don't hesitate to create a new ticket.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '✅ Ticket Closed - #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Approval email sent to ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending approval email: $e');
    }
  }

// Email for rejected ticket
  static Future<void> _sendTicketRejectedEmail({
    required UserNotificationInfo creatorInfo,
    required String ticketNumber,
    required String ticketTitle,
    required String rejectedByName,
    String? rejectionReason,
  }) async {
    try {
      final preferences = await _getUserNotificationPreferences(creatorInfo.id);
      final emailEnabled = preferences['email_notifications_enabled'] ?? true;

      if (!emailEnabled) {
        print('🚫 Email skipped for ${creatorInfo.fullName} (disabled)');
        return;
      }

      final html = '''
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
          .header h1 { margin: 0; font-size: 24px; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .info-box { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ef4444; }
          .footer { background: #f3f4f6; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; border-radius: 0 0 10px 10px; }
          .warning-box { background: #fee2e2; padding: 15px; border-radius: 6px; border-left: 4px solid #ef4444; margin: 20px 0; }
          .reason-box { background: #fef2f2; padding: 15px; border-radius: 6px; margin: 15px 0; border: 1px solid #fecaca; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>❌ Ticket Requires Additional Work</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Your ticket needs further attention</p>
          </div>
          
          <div class="content">
            <p>Hello <strong>${creatorInfo.fullName}</strong>,</p>
            
            <div class="warning-box">
              <strong>⚠️ Additional Work Required:</strong> Your ticket has been reviewed and requires additional work before it can be closed.
            </div>
            
            <div class="info-box">
              <h2 style="margin-top: 0; color: #ef4444;">Ticket Details</h2>
              <p><strong>Ticket Number:</strong> #$ticketNumber</p>
              <p><strong>Title:</strong> $ticketTitle</p>
              <p><strong>Reviewed By:</strong> $rejectedByName</p>
              <p><strong>Status:</strong> <span style="color: #ef4444; font-weight: bold;">RETURNED TO IN-PROGRESS</span></p>
              
              ${rejectionReason != null && rejectionReason.isNotEmpty ? '''
              <div class="reason-box">
                <strong style="color: #dc2626;">Reason for Additional Work:</strong>
                <p style="margin: 10px 0 0 0; white-space: pre-wrap;">$rejectionReason</p>
              </div>
              ''' : ''}
            </div>
            
            <p>The administrator will continue working on your ticket to address the issues identified. You will receive updates as progress is made.</p>
            
            <p>Thank you for your patience.</p>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from JalaSupport System</p>
            <p>© ${DateTime.now().year} JalaSupport. All rights reserved.</p>
          </div>
        </div>
      </body>
    </html>
    ''';

      await EmailService.sendEmail(
        toEmail: creatorInfo.email,
        toName: creatorInfo.fullName,
        subject: '❌ Additional Work Required - Ticket #$ticketNumber',
        htmlContent: html,
      );

      print('📧 Rejection email sent to ${creatorInfo.fullName}');
    } catch (e) {
      print('❌ Error sending rejection email: $e');
    }
  }

  static String _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return '#dc2626';
      case 'high':
        return '#f59e0b';
      case 'medium':
        return '#3b82f6';
      case 'low':
        return '#10b981';
      default:
        return '#6b7280';
    }
  }

  // Enhanced notifySubticketCreated method
  static Future<void> notifySubticketCreated({
    required String subticketId,
    required String parentTicketId,
    required String createdByUserId,
    required String targetAdminId,
    required String subticketNumber,
    required String subticketTitle,
    required String parentTicketNumber,
  }) async {
    try {
      if (createdByUserId == targetAdminId) return; // Don't notify self

      print('📋 Processing subticket creation notification...');

      // Get creator and target admin info in parallel
      final futures = await Future.wait([
        _getUserNotificationInfo(createdByUserId),
        _getUserNotificationInfo(targetAdminId),
      ]);

      final creator = futures[0] as UserNotificationInfo?;
      final targetAdmin = futures[1] as UserNotificationInfo?;

      if (creator == null || targetAdmin == null) {
        print('❌ User info not found');
        return;
      }

      final subticketNotif = _getLocalizedSubticketCreatedNotification(
        subticketNumber: subticketNumber,
        parentTicketNumber: parentTicketNumber,
        creatorName: creator.fullName,
        subticketTitle: subticketTitle,
        lang: targetAdmin.language,
      );
      await createAndSendNotification(
        userId: targetAdminId,
        type: 'subticket_created',
        title: subticketNotif['title']!,
        message: subticketNotif['message']!,
        ticketId: subticketId,
        additionalData: {
          'subticket_number': subticketNumber,
          'subticket_title': subticketTitle,
          'parent_ticket_id': parentTicketId,
          'parent_ticket_number': parentTicketNumber,
          'created_by': createdByUserId,
          'creator_name': creator.fullName,
          'creator_email': creator.email,
        },
      );

      print('✅ Subticket creation notification sent');
    } catch (e) {
      print('❌ Error notifying subticket created: $e');
    }
  }

  // Get chat participants efficiently
  static Future<List<UserNotificationInfo>> _getChatParticipants(
      String chatRoomId, String ticketId) async {
    try {
      // Get ticket info
      final ticket = await supabase
          .from('tickets')
          .select('created_by, assigned_to, target_department_id, place_id')
          .eq('id', ticketId)
          .single();

      final participantIds = <String>{};

      // Add creator
      if (ticket['created_by'] != null) {
        participantIds.add(ticket['created_by']);
      }

      // Add assigned user
      if (ticket['assigned_to'] != null) {
        participantIds.add(ticket['assigned_to']);
      }

      // Add department super admins
      if (ticket['target_department_id'] != null) {
        final superAdmins = await supabase
            .from('users')
            .select('id')
            .eq('department_id', ticket['target_department_id'])
            .eq('user_type', 'super_admin')
            .eq('is_active', true);

        for (final admin in superAdmins) {
          participantIds.add(admin['id']);
        }
      }

      // Get all participant info
      final participantInfos =
          await _getBulkUserNotificationInfo(participantIds.toList());

      return participantInfos.values.toList();
    } catch (e) {
      print('❌ Error getting chat participants: $e');
      return [];
    }
  }

  // Queue email notification
  static Future<void> _queueEmailNotification({
    required UserNotificationInfo userInfo,
    required String type,
    required String title,
    required String message,
    String? ticketId,
    Map<String, dynamic>? additionalData,
  }) async {
    _emailQueue.add({
      'type': type,
      'to': userInfo.email,
      'to_name': userInfo.fullName,
      'subject': title,
      'message': message,
      'ticket_id': ticketId,
      'additional_data': additionalData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Send push notification with enhanced error handling
  static Future<void> _sendPushNotification({
    required UserNotificationInfo userInfo,
    required String title,
    required String body,
    required String type,
    String? ticketId,
    String? chatRoomId,
    Map<String, dynamic>? additionalData,
  }) async {
    // Use mobile token if available, otherwise fall back to web token.
    // This prevents duplicate notifications when the user is logged in on both.
    final token = userInfo.effectiveToken;
    if (token == null || token.isEmpty) return;

    final data = <String, String>{
      'type': type,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'user_id': userInfo.id,
    };

    if (ticketId != null) data['ticket_id'] = ticketId;
    if (chatRoomId != null) data['chat_room_id'] = chatRoomId;
    if (additionalData != null) {
      additionalData.forEach((key, value) {
        data[key] = value.toString();
      });
    }

    try {
      final success = await _sendViaEdgeFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
      // Fall back to Firebase Cloud Function on mobile if edge function fails
      if (!success && !kIsWeb) {
        await _sendViaCloudFunction(
          token: token,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      print('❌ Error in _sendPushNotification: $e');
    }
  }

  // Legacy Firebase Cloud Function fallback (mobile only — has CORS on web)
  static Future<void> _sendViaCloudFunction({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://us-central1-jalaticketing.cloudfunctions.net/sendNotificationHTTP'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'title': title, 'body': body, 'data': data}),
      );
      if (response.statusCode == 200) {
        print('✅ Push sent via Cloud Function fallback');
      } else {
        print('❌ Cloud Function fallback failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Cloud Function fallback error: $e');
    }
  }

  static Future<void> sendTestPush({
    required String token,
    required String userId,
  }) async {
    await _sendViaEdgeFunction(
      token: token,
      title: '🔔 Test Notification',
      body: 'This is a test notification sent from the profile screen.',
      data: {
        'type': 'test',
        'user_id': userId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }

  // Send FCM push via Supabase Edge Function (works on all platforms).
  // JWT signing happens server-side in Deno — no pointycastle issues on web.
  static Future<bool> _sendViaEdgeFunction({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': token,
          'title': title,
          'body': body,
          'data': data,
        },
      );

      if (response.status == 200) {
        print('✅ Push notification sent via edge function');
        return true;
      } else {
        print('❌ Edge function returned ${response.status}: ${response.data}');
        return false;
      }
    } catch (e) {
      print('❌ Edge function error: $e');
      return false;
    }
  }

  // Helper methods
  static String _getPriorityForType(String type) {
    switch (type) {
      case 'ticket_assigned':
      case 'new_message':
        return 'high';
      case 'ticket_approved':
      case 'ticket_rejected':
      case 'ticket_created':
        return 'normal';
      case 'system_announcement':
        return 'urgent';
      default:
        return 'normal';
    }
  }

  static bool _isCriticalNotificationType(String type) {
    return [
      'ticket_created',
      'ticket_assigned',
      'ticket_approved',
      'ticket_rejected',
      'subticket_created',
      // Fleet vehicle warnings (expired documents, service due) — the
      // driver and their direct manager must always be emailed, not just
      // as a fallback when there's no push token.
      'fleet_alert',
    ].contains(type);
  }

  // Returns a localized title+message pair for a status change notification
  static Map<String, String> _getLocalizedStatusNotification({
    required String newStatus,
    required String ticketNumber,
    required String changedByName,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    switch (newStatus) {
      case 'inprogress':
        return {
          'title': isAr ? '🔄 بدأ العمل على تذكرتك' : '🔄 Work Started on Your Ticket',
          'message': isAr
              ? 'الفني $changedByName يعمل الآن على تذكرتك رقم #$ticketNumber'
              : 'A technician ($changedByName) is now working on your ticket #$ticketNumber',
        };
      case 'wrong_info':
        return {
          'title': isAr ? '❓ معلومات مطلوبة' : '❓ Information Needed',
          'message': isAr
              ? 'تذكرتك رقم #$ticketNumber تحتاج إلى معلومات إضافية قبل المتابعة'
              : 'Your ticket #$ticketNumber needs additional information before we can proceed',
        };
      case 'opened':
        return {
          'title': isAr ? '📋 تمت إعادة فتح التذكرة' : '📋 Ticket Reopened',
          'message': isAr
              ? 'تمت إعادة فتح تذكرتك رقم #$ticketNumber بواسطة $changedByName'
              : 'Your ticket #$ticketNumber has been reopened by $changedByName',
        };
      default:
        return {
          'title': isAr ? '📋 تحديث حالة التذكرة' : '📋 Ticket Status Updated',
          'message': isAr
              ? 'تم تحديث حالة تذكرتك رقم #$ticketNumber بواسطة $changedByName'
              : 'Your ticket #$ticketNumber status has been updated by $changedByName',
        };
    }
  }

  // Localized notification for ticket assigned (creator's perspective)
  static Map<String, String> _getLocalizedAssignedCreatorNotification({
    required String ticketNumber,
    required String assignedToName,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '✅ تم تعيين تذكرتك' : '✅ Your Ticket Has Been Assigned',
      'message': isAr
          ? 'تم تعيين تذكرتك رقم #$ticketNumber للفني $assignedToName وسيبدأ العمل عليها قريباً'
          : 'Your ticket #$ticketNumber has been assigned to $assignedToName, who will start working on it shortly',
    };
  }

  // Localized notification for ticket completed (creator's perspective)
  static Map<String, String> _getLocalizedPrefinishedNotification({
    required String ticketNumber,
    required String finishedByName,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '⏳ انتظار موافقتك على التذكرة' : '⏳ Ticket Awaiting Your Approval',
      'message': isAr
          ? 'أنهى الفني $finishedByName العمل على تذكرتك رقم #$ticketNumber. يرجى المراجعة والموافقة'
          : 'Technician $finishedByName has completed work on your ticket #$ticketNumber. Please review and approve',
    };
  }

  // Localized notification for ticket under supervision (creator's perspective)
  static Map<String, String> _getLocalizedSupervisionNotification({
    required String ticketNumber,
    required String approvalMinutes,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '🔍 تذكرتك تحت الإشراف' : '🔍 Ticket Under Supervision',
      'message': isAr
          ? 'تذكرتك رقم #$ticketNumber مكتملة وتحت الإشراف. ستتم الموافقة تلقائياً بعد $approvalMinutes دقيقة إذا لم يتم الرفض'
          : 'Your ticket #$ticketNumber is complete and under supervision. It will be automatically approved after $approvalMinutes minutes if not rejected',
    };
  }

  // Localized notification for ticket approved/rejected (creator's perspective)
  static Map<String, String> _getLocalizedApprovalNotification({
    required String ticketNumber,
    required bool isApproved,
    required bool isAutoApproval,
    required String approverName,
    String? rejectionReason,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    if (isApproved) {
      final auto = isAutoApproval;
      return {
        'title': isAr ? '✅ تمت الموافقة على التذكرة وإغلاقها' : '✅ Ticket Approved and Closed',
        'message': isAr
            ? auto
                ? 'تمت الموافقة تلقائياً على تذكرتك رقم #$ticketNumber وإغلاقها بعد انتهاء فترة الإشراف'
                : 'تمت الموافقة على تذكرتك رقم #$ticketNumber وإغلاقها بواسطة $approverName'
            : auto
                ? 'Your ticket #$ticketNumber has been automatically approved and closed after the supervision period'
                : 'Your ticket #$ticketNumber has been approved and closed by $approverName',
      };
    } else {
      final reasonSuffix = rejectionReason != null
          ? (isAr ? '\n\nالسبب: $rejectionReason' : '\n\nReason: $rejectionReason')
          : '';
      return {
        'title': isAr ? '❌ التذكرة تحتاج إلى عمل إضافي' : '❌ Ticket Requires Additional Work',
        'message': isAr
            ? 'تذكرتك رقم #$ticketNumber تحتاج إلى مراجعة إضافية بواسطة $approverName$reasonSuffix'
            : 'Your ticket #$ticketNumber requires additional work, as reviewed by $approverName$reasonSuffix',
      };
    }
  }

  // Localized notification for new chat message
  static Map<String, String> _getLocalizedChatNotification({
    required String senderName,
    required String ticketNumber,
    required String shortMessage,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr
          ? '💬 $senderName - تذكرة #$ticketNumber'
          : '💬 $senderName - Ticket #$ticketNumber',
      'message': shortMessage,
    };
  }

  // Localized notification for new ticket created (admin/recipient perspective)
  static Map<String, String> _getLocalizedTicketCreatedNotification({
    required String ticketNumber,
    required String creatorName,
    required String ticketTitle,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '🎫 تذكرة جديدة' : '🎫 New Ticket Created',
      'message': isAr
          ? 'تذكرة جديدة رقم #$ticketNumber أنشأها $creatorName: $ticketTitle'
          : 'New ticket #$ticketNumber created by $creatorName: $ticketTitle',
    };
  }

  // Localized notification for ticket assigned (assigned admin's perspective)
  static Map<String, String> _getLocalizedTicketAssignedToAdminNotification({
    required String ticketNumber,
    required String assignerName,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '🎯 تم تعيين تذكرة لك' : '🎯 Ticket Assigned to You',
      'message': isAr
          ? 'تم تعيين التذكرة رقم #$ticketNumber إليك بواسطة $assignerName'
          : 'Ticket #$ticketNumber has been assigned to you by $assignerName',
    };
  }

  // Localized notification for subticket created
  static Map<String, String> _getLocalizedSubticketCreatedNotification({
    required String subticketNumber,
    required String parentTicketNumber,
    required String creatorName,
    required String subticketTitle,
    required String lang,
  }) {
    final isAr = lang == 'ar';
    return {
      'title': isAr ? '📋 تذكرة فرعية جديدة' : '📋 New Subticket Created',
      'message': isAr
          ? 'تذكرة فرعية رقم #$subticketNumber أنشئت للتذكرة #$parentTicketNumber\n\nأنشأها: $creatorName\nالعنوان: $subticketTitle'
          : 'Subticket #$subticketNumber created for parent ticket #$parentTicketNumber\n\nCreated by: $creatorName\nTitle: $subticketTitle',
    };
  }

  // Utility methods (keeping existing interface)
  static Future<List<Map<String, dynamic>>> getUserNotifications(
    String userId, {
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      var query = supabase.from('notifications').select().eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting user notifications: $e');
      return [];
    }
  }

  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
      return true;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  static Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return response.length;
    } catch (e) {
      print('❌ Error getting unread notification count: $e');
      return 0;
    }
  }

// FIXED: Preference fetching with explicit null handling
  static Future<Map<String, bool>> _getUserNotificationPreferences(
      String userId) async {
    try {
      print('🔍 Fetching preferences for user: $userId');

      final response = await supabase
          .from('notification_preferences')
          .select(
              'push_notifications_enabled, push_chat_messages_enabled, email_notifications_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      print('🔍 Raw response: $response');

      if (response != null) {
        // Explicitly cast and handle nulls
        final pushEnabled = response['push_notifications_enabled'];
        final chatPushEnabled = response['push_chat_messages_enabled'];
        final emailEnabled = response['email_notifications_enabled'];

        print(
            '🔍 push_notifications_enabled: $pushEnabled (${pushEnabled.runtimeType})');
        print(
            '🔍 push_chat_messages_enabled: $chatPushEnabled (${chatPushEnabled.runtimeType})');
        print(
            '🔍 email_notifications_enabled: $emailEnabled (${emailEnabled.runtimeType})');

        return {
          'push_notifications_enabled': pushEnabled == true,
          'push_chat_messages_enabled': chatPushEnabled == true,
          'email_notifications_enabled': emailEnabled == true,
        };
      }

      print('⚠️ No preferences found, using defaults');
      return _getFallbackPreferences();
    } catch (e) {
      print('❌ Error getting notification preferences: $e');
      return _getFallbackPreferences();
    }
  }

  static Future<void> ensureNotificationPreferencesTable() async {
    try {
      // Try to create the table if it doesn't exist
      // Note: This might require RPC permissions or should be done via database migration
      // For now, we'll just verify we can access it
      final testQuery = await supabase
          .from('notification_preferences')
          .select('count')
          .limit(1)
          .maybeSingle()
          .catchError((e) {
        print('⚠️ Notification preferences table might need setup: $e');
        return null;
      });

      print('✅ Notification preferences table is accessible');
    } catch (e) {
      print('❌ Notification preferences table issue: $e');
    }
  }

// Helper to get fallback preferences
  static Map<String, bool> _getFallbackPreferences() {
    return {
      'push_notifications_enabled': true,
      'push_chat_messages_enabled': true,
      'email_notifications_enabled': true,
    };
  }

  // Send notification to multiple devices
  static Future<void> sendBulkNotifications({
    required List<String> userIds,
    required String type,
    required String title,
    required String body,
    String? ticketId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get all user info in one batch
      final userInfos = await _getBulkUserNotificationInfo(userIds);

      final notificationTasks = <Future>[];

      for (final entry in userInfos.entries) {
        notificationTasks.add(createAndSendNotification(
          userId: entry.key,
          type: type,
          title: title,
          message: body,
          ticketId: ticketId,
          additionalData: additionalData,
        ));
      }

      await Future.wait(notificationTasks);
      print('✅ Bulk notifications sent to ${userIds.length} users');
    } catch (e) {
      print('❌ Error sending bulk notifications: $e');
    }
  }
}

// UserNotificationInfo class for caching
class UserNotificationInfo {
  final String id;
  final String fullName;
  final String email;
  final String? fcmToken;      // mobile token
  final String? fcmTokenWeb;   // web browser token
  final String userType;
  final String? departmentId;
  final String? placeId;
  final String language;

  UserNotificationInfo({
    required this.id,
    required this.fullName,
    required this.email,
    this.fcmToken,
    this.fcmTokenWeb,
    required this.userType,
    this.departmentId,
    this.placeId,
    this.language = 'en',
  });

  /// Returns the best available token: mobile preferred, web as fallback.
  String? get effectiveToken =>
      (fcmToken?.isNotEmpty == true) ? fcmToken : fcmTokenWeb;
}

class EmailService {
  // Power Automate HTTP trigger URL
  static const String _powerAutomateUrl =
      'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/2656aea4480249f488c70ab46c73d826/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=-VKZLP4wRUjRR_ZrrA5p9H0o9UnxIA9MU6A9DZJusEQ';

  static Future<bool> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
    String? plainTextContent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_powerAutomateUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'to': toEmail,
          'subject': subject,
          'body': htmlContent,
          'attachments': [], // Empty array as required
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        print('✅ Email sent successfully to $toEmail');
        return true;
      } else {
        print(
            '❌ Failed to send email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // Email Templates
  static Future<bool> sendTicketCreatedEmail({
    required String toEmail,
    required String toName,
    required String ticketNumber,
    required String ticketTitle,
    required String creatorName,
    required String departmentName,
  }) async {
    final subject = 'New Ticket Created - #$ticketNumber';
    final html = '''
    <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #2563eb;">New Ticket Created</h2>
        <p>Hello $toName,</p>
        <p>A new ticket has been created and assigned to your department:</p>
        <div style="background-color: #f3f4f6; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <p><strong>Ticket Number:</strong> #$ticketNumber</p>
          <p><strong>Title:</strong> $ticketTitle</p>
          <p><strong>Created by:</strong> $creatorName</p>
          <p><strong>Department:</strong> $departmentName</p>
        </div>
        <p>Please log in to the system to review and assign this ticket.</p>
        <p>Best regards,<br>JalaSupport System</p>
      </body>
    </html>
    ''';

    return await sendEmail(
      toEmail: toEmail,
      toName: toName,
      subject: subject,
      htmlContent: html,
    );
  }

  static Future<bool> sendTicketAssignedEmail({
    required String toEmail,
    required String toName,
    required String ticketNumber,
    required String ticketTitle,
    required String assignedByName,
    required String assignedToName,
    required bool isCreatorNotification,
  }) async {
    final subject = 'Ticket Assignment Update - #$ticketNumber';
    final html = isCreatorNotification
        ? '''
    <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #2563eb;">Ticket Assigned</h2>
        <p>Hello $toName,</p>
        <p>Your ticket has been assigned to an administrator:</p>
        <div style="background-color: #f3f4f6; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <p><strong>Ticket Number:</strong> #$ticketNumber</p>
          <p><strong>Title:</strong> $ticketTitle</p>
          <p><strong>Assigned to:</strong> $assignedToName</p>
          <p><strong>Assigned by:</strong> $assignedByName</p>
        </div>
        <p>The administrator will start working on your ticket shortly.</p>
        <p>Best regards,<br>JalaSupport System</p>
      </body>
    </html>
    '''
        : '''
    <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #2563eb;">New Ticket Assigned to You</h2>
        <p>Hello $toName,</p>
        <p>A ticket has been assigned to you:</p>
        <div style="background-color: #f3f4f6; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <p><strong>Ticket Number:</strong> #$ticketNumber</p>
          <p><strong>Title:</strong> $ticketTitle</p>
          <p><strong>Assigned by:</strong> $assignedByName</p>
        </div>
        <p>Please log in to the system to start working on this ticket.</p>
        <p>Best regards,<br>JalaSupport System</p>
      </body>
    </html>
    ''';

    return await sendEmail(
      toEmail: toEmail,
      toName: toName,
      subject: subject,
      htmlContent: html,
    );
  }

  static Future<bool> sendTicketStatusChangedEmail({
    required String toEmail,
    required String toName,
    required String ticketNumber,
    required String oldStatus,
    required String newStatus,
    required String changedByName,
  }) async {
    final subject = 'Ticket Status Updated - #$ticketNumber';
    final statusEmoji = _getStatusEmoji(newStatus);
    final html = '''
    <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #2563eb;">$statusEmoji Ticket Status Updated</h2>
        <p>Hello $toName,</p>
        <p>Your ticket status has been updated:</p>
        <div style="background-color: #f3f4f6; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <p><strong>Ticket Number:</strong> #$ticketNumber</p>
          <p><strong>Previous Status:</strong> ${_formatStatus(oldStatus)}</p>
          <p><strong>New Status:</strong> ${_formatStatus(newStatus)}</p>
          <p><strong>Updated by:</strong> $changedByName</p>
        </div>
        <p>${_getStatusMessage(newStatus)}</p>
        <p>Best regards,<br>JalaSupport System</p>
      </body>
    </html>
    ''';

    return await sendEmail(
      toEmail: toEmail,
      toName: toName,
      subject: subject,
      htmlContent: html,
    );
  }

  static String _getStatusEmoji(String status) {
    switch (status) {
      case 'inprogress':
        return '🔄';
      case 'prefinished':
        return '⏳';
      case 'closed':
        return '✅';
      case 'wrong_info':
        return '❓';
      default:
        return '📋';
    }
  }

  static String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  static String _getStatusMessage(String status) {
    switch (status) {
      case 'inprogress':
        return 'An administrator is now working on your ticket.';
      case 'prefinished':
        return 'Your ticket has been completed and is awaiting your approval.';
      case 'closed':
        return 'Your ticket has been closed.';
      case 'wrong_info':
        return 'Your ticket requires additional information. Please review and update.';
      default:
        return 'Your ticket status has been updated.';
    }
  }
}

class EmailAttachment {
  final String name;
  final String contentBytes; // Base64 encoded content
  final String? contentType;

  EmailAttachment({
    required this.name,
    required this.contentBytes,
    this.contentType,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'ContentBytes': contentBytes,
    };

    if (contentType != null) {
      data['contentType'] = contentType;
    }

    return data;
  }

  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      name: json['name'],
      contentBytes: json['ContentBytes'],
      contentType: json['contentType'],
    );
  }
}
