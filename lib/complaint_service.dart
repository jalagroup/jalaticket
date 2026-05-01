import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'dart:typed_data';

class ComplaintService {
  // Get complaint items
  static Future<List<ComplaintItemModel>> getComplaintItems() async {
    try {
      final response = await supabase
          .from('complaint_items')
          .select()
          .eq('is_active', true)
          .order('name');

      return response.map((json) => ComplaintItemModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading complaint items: $e');
      return [];
    }
  }

  // Create complaint ticket
  static Future<String?> createComplaintTicket(
      Map<String, dynamic> complaintData) async {
    try {
      // Clean up the data - convert empty strings to null for UUID fields
      final cleanedData = Map<String, dynamic>.from(complaintData);

      // Handle department_id
      if (cleanedData['department_id'] != null &&
          cleanedData['department_id'].toString().isEmpty) {
        cleanedData['department_id'] = null;
      }

      // Handle item_id
      if (cleanedData['item_id'] != null &&
          cleanedData['item_id'].toString().isEmpty) {
        cleanedData['item_id'] = null;
      }

      // Handle assigned_to
      if (cleanedData['assigned_to'] != null &&
          cleanedData['assigned_to'].toString().isEmpty) {
        cleanedData['assigned_to'] = null;
      }

      final response = await supabase
          .from('complaint_tickets')
          .insert(cleanedData)
          .select()
          .single();

      return response['id'];
    } catch (e) {
      print('Error creating complaint ticket: $e');
      throw Exception('Failed to create complaint ticket: $e');
    }
  }

  // Upload complaint attachment
  static Future<String> uploadComplaintAttachment({
    required String complaintId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    required String attachmentType,
    required String uploadedBy,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final storagePath =
          'complaints/$complaintId/${attachmentType}_${timestamp}.$extension';

      await supabase.storage
          .from('complaint_attachments')
          .uploadBinary(storagePath, fileBytes);

      await supabase.from('complaint_attachments').insert({
        'complaint_id': complaintId,
        'file_name': fileName,
        'file_path': storagePath,
        'file_size': fileBytes.length,
        'mime_type': mimeType,
        'attachment_type': attachmentType,
        'uploaded_by': uploadedBy,
      });

      return storagePath;
    } catch (e) {
      print('Error uploading complaint attachment: $e');
      throw Exception('Failed to upload attachment: $e');
    }
  }

// FIXED: getComplaintsByStatus - Now properly fetches item name
  static Future<List<ComplaintTicketModel>> getComplaintsByStatus(
    String userId,
    ComplaintStatus status,
    UserType userType,
    String? departmentId,
  ) async {
    try {
      // Use explicit column selection with LEFT JOIN
      var query = supabase.from('complaint_tickets').select('''
      id,
      complaint_number,
      date,
      complaint_receiver,
      complainant_name,
      location,
      mobile_number,
      phone_number,
      item_id,
      batch_number,
      quantity,
      produce_date,
      expired_date,
      description,
      complaint_type,
      status,
      created_by,
      assigned_to,
      department_id,
      created_at,
      updated_at,
      complaint_items!left(id, name)
    ''').eq('status', status.value);

      // Filter based on user type - SERVER SIDE
      if (userType == UserType.user || userType == UserType.superUser) {
        query = query.eq('created_by', userId);
      } else if (userType == UserType.admin) {
        query = query.eq('assigned_to', userId);
      } else if (userType == UserType.superAdmin) {
        if (departmentId != null && departmentId.isNotEmpty) {
          query = query.or(
              'department_id.eq.$departmentId,department_id.is.null,created_by.eq.$userId');
        }
      }

      final response = await query.order('created_at', ascending: false);

      return response.map((json) {
        try {
          // Extract item name from the joined table
          String? itemName;

          if (json['complaint_items'] != null) {
            final items = json['complaint_items'];

            if (items is Map<String, dynamic>) {
              itemName = items['name'] as String?;
            } else if (items is List && items.isNotEmpty) {
              if (items.first is Map) {
                itemName =
                    (items.first as Map<String, dynamic>)['name'] as String?;
              }
            }
          }

          // Create model with item name
          return ComplaintTicketModel(
            id: json['id']?.toString() ?? '',
            complaintNumber: json['complaint_number']?.toString() ?? 'N/A',
            date: json['date'] != null
                ? DateTime.parse(json['date']).toLocal()
                : DateTime.now(),
            complaintReceiver:
                json['complaint_receiver']?.toString() ?? 'Unknown',
            complainantName: json['complainant_name']?.toString() ?? 'Unknown',
            location: json['location']?.toString() ?? 'Unknown Location',
            mobileNumber: json['mobile_number']?.toString() ?? 'N/A',
            phoneNumber: json['phone_number']?.toString(),
            itemId: json['item_id']?.toString(),
            itemName: itemName ?? 'No Item',
            batchNumber: json['batch_number']?.toString(),
            quantity: json['quantity']?.toDouble(),
            produceDate: json['produce_date'] != null
                ? DateTime.parse(json['produce_date']).toLocal()
                : null,
            expiredDate: json['expired_date'] != null
                ? DateTime.parse(json['expired_date']).toLocal()
                : null,
            description: json['description']?.toString() ?? '',
            complaintType: ComplaintType.values.firstWhere(
              (e) => e.value == (json['complaint_type'] ?? 'technical'),
              orElse: () => ComplaintType.technical,
            ),
            status: ComplaintStatus.values.firstWhere(
              (e) => e.value == (json['status'] ?? 'pending'),
              orElse: () => ComplaintStatus.pending,
            ),
            createdBy: json['created_by']?.toString() ?? '',
            assignedTo: json['assigned_to']?.toString(),
            departmentId: (json['department_id'] == null ||
                    json['department_id'].toString().isEmpty)
                ? null
                : json['department_id'].toString(),
            createdAt: json['created_at'] != null
                ? DateTime.parse(json['created_at']).toLocal()
                : DateTime.now(),
            updatedAt: json['updated_at'] != null
                ? DateTime.parse(json['updated_at']).toLocal()
                : DateTime.now(),
          );
        } catch (e) {
          print('Error parsing complaint JSON: $e');
          print('Problematic JSON: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      print('Error loading complaints: $e');
      return [];
    }
  }

// FIXED: Upload signed document - now accepts images and PDFs
  static Future<bool> uploadSignedDocument({
    required String complaintId,
    required String checkId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    required String currentUserId,
  }) async {
    try {
      // Upload file
      final filePath = await uploadComplaintAttachment(
        complaintId: complaintId,
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        attachmentType: 'signed',
        uploadedBy: currentUserId,
      );

      // Update check record
      await supabase.from('complaint_checks').update({
        'signed_document_path': filePath,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', checkId);

      // Update complaint status
      await supabase.from('complaint_tickets').update({
        'status': ComplaintStatus.checked.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', complaintId);

      return true;
    } catch (e) {
      print('Error uploading signed document: $e');
      return false;
    }
  }

// NEW: Get all attachments for a complaint with their URLs
  static Future<List<Map<String, dynamic>>> getComplaintAttachmentsWithUrls(
      String complaintId) async {
    try {
      final attachments = await supabase
          .from('complaint_attachments')
          .select()
          .eq('complaint_id', complaintId)
          .order('created_at');

      // Get signed URLs for each attachment
      List<Map<String, dynamic>> attachmentsWithUrls = [];

      for (var attachment in attachments) {
        try {
          final filePath = attachment['file_path'] as String;
          final mimeType = attachment['mime_type'] as String? ?? '';

          // Get signed URL
          final signedUrl = await supabase.storage
              .from('complaint_attachments')
              .createSignedUrl(filePath, 3600); // 1 hour expiry

          attachmentsWithUrls.add({
            ...attachment,
            'signed_url': signedUrl,
            'is_image': mimeType.startsWith('image/'),
          });
        } catch (e) {
          print('Error getting signed URL for attachment: $e');
          attachmentsWithUrls.add({
            ...attachment,
            'signed_url': null,
            'is_image': false,
          });
        }
      }

      return attachmentsWithUrls;
    } catch (e) {
      print('Error loading attachments with URLs: $e');
      return [];
    }
  }

// NEW: Download image bytes for PDF generation
  static Future<Uint8List?> downloadImageBytes(String filePath) async {
    try {
      final bytes = await supabase.storage
          .from('complaint_attachments')
          .download(filePath);
      return bytes;
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  // FIXED: Assignment method with NULL handling for empty strings
  static Future<bool> assignComplaint(
      String complaintId, String adminId, String departmentId) async {
    try {
      print(
          'Attempting to assign complaint $complaintId to admin $adminId in department $departmentId');

      // Prepare update data - handle empty strings
      final updateData = <String, dynamic>{
        'assigned_to': adminId.isEmpty ? null : adminId,
        'status': ComplaintStatus.inprogress.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only add department_id if it's not empty, otherwise set to null
      if (departmentId.isEmpty) {
        updateData['department_id'] = null;
      } else {
        updateData['department_id'] = departmentId;
      }

      // Perform the update
      final response = await supabase
          .from('complaint_tickets')
          .update(updateData)
          .eq('id', complaintId)
          .select();

      print('Assignment response: $response');

      if (response.isEmpty) {
        print('ERROR: No rows updated - possible RLS policy issue');
        return false;
      }

      print('Successfully assigned complaint');
      return true;
    } catch (e) {
      print('Error assigning complaint: $e');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  // Submit complaint check
  static Future<String?> submitComplaintCheck({
    required String complaintId,
    required bool complaintCheck,
    required String checkerId,
    required String checkerName,
    required String report,
    required String? therapeuticProcedure,
  }) async {
    try {
      // Create check record
      final checkResponse = await supabase
          .from('complaint_checks')
          .insert({
            'complaint_id': complaintId,
            'complaint_check': complaintCheck,
            'checker_id': checkerId,
            'checker_name': checkerName,
            'report': report,
            'therapeutic_procedure': therapeuticProcedure,
          })
          .select()
          .single();

      // Update complaint status
      await supabase.from('complaint_tickets').update({
        'status': ComplaintStatus.prefinished.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', complaintId);

      return checkResponse['id'];
    } catch (e) {
      print('Error submitting complaint check: $e');
      throw Exception('Failed to submit check: $e');
    }
  }

  // Get complaint check
  static Future<ComplaintCheckModel?> getComplaintCheck(
      String complaintId) async {
    try {
      final response = await supabase
          .from('complaint_checks')
          .select()
          .eq('complaint_id', complaintId)
          .single();

      return ComplaintCheckModel.fromJson(response);
    } catch (e) {
      print('No check found or error: $e');
      return null;
    }
  }

  // Check if department has complaint access
  static Future<bool> departmentHasComplaintAccess(String departmentId) async {
    try {
      final response = await supabase
          .from('department_complaint_permissions')
          .select('can_access_complaints')
          .eq('department_id', departmentId)
          .single();

      return response['can_access_complaints'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Get complaint attachments
  static Future<List<Map<String, dynamic>>> getComplaintAttachments(
      String complaintId) async {
    try {
      return await supabase
          .from('complaint_attachments')
          .select()
          .eq('complaint_id', complaintId)
          .order('created_at');
    } catch (e) {
      print('Error loading attachments: $e');
      return [];
    }
  }
}
