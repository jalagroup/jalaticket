import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:uuid/uuid.dart';
import '../main.dart' show supabase;
import 'library_models.dart';

const _uuid = Uuid();
const _bucket = 'file_library';

class LibraryService {
  /// [folderId] null means the library root — pass it explicitly (not
  /// omitted) so "root" and "not filtered" are never ambiguous.
  static Future<List<LibraryFile>> getFiles(String userId, String? folderId) async {
    var query = supabase.from('library_files').select().eq('owner_user_id', userId);
    query = folderId == null ? query.isFilter('folder_id', null) : query.eq('folder_id', folderId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map<LibraryFile>((j) => LibraryFile.fromJson(j)).toList();
  }

  static Future<List<LibraryFolder>> getFolders(String userId, String? parentFolderId) async {
    var query = supabase.from('library_folders').select().eq('owner_user_id', userId);
    query = parentFolderId == null
        ? query.isFilter('parent_folder_id', null)
        : query.eq('parent_folder_id', parentFolderId);
    final rows = await query.order('name');
    return rows.map<LibraryFolder>((j) => LibraryFolder.fromJson(j)).toList();
  }

  static Future<LibraryFolder> createFolder({
    required String userId,
    required String name,
    String? parentFolderId,
  }) async {
    final row = await supabase
        .from('library_folders')
        .insert({
          'owner_user_id': userId,
          'name': name,
          'parent_folder_id': parentFolderId,
        })
        .select()
        .single();
    return LibraryFolder.fromJson(row);
  }

  static Future<void> renameFolder(String folderId, String newName) async {
    await supabase
        .from('library_folders')
        .update({'name': newName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', folderId);
  }

  /// Only deletes an empty folder (no sub-folders, no files) — a cascading
  /// delete of an entire tree is destructive and easy to trigger by
  /// accident, so the user must empty a folder before removing it.
  static Future<bool> deleteFolderIfEmpty(String folderId) async {
    final childFolders = await supabase
        .from('library_folders')
        .select('id')
        .eq('parent_folder_id', folderId)
        .limit(1);
    final childFiles = await supabase
        .from('library_files')
        .select('id')
        .eq('folder_id', folderId)
        .limit(1);
    if (childFolders.isNotEmpty || childFiles.isNotEmpty) return false;
    await supabase.from('library_folders').delete().eq('id', folderId);
    return true;
  }

  static Future<void> moveFolder(String folderId, String? newParentFolderId) async {
    await supabase
        .from('library_folders')
        .update({
          'parent_folder_id': newParentFolderId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', folderId);
  }

  static Future<LibraryFile> uploadFile({
    required String userId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? folderId,
  }) async {
    final path = '$userId/${_uuid.v4()}_$fileName';
    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    final row = await supabase
        .from('library_files')
        .insert({
          'owner_user_id': userId,
          'file_name': fileName,
          'file_path': path,
          'file_size': bytes.length,
          'mime_type': mimeType,
          'folder_id': folderId,
        })
        .select()
        .single();
    return LibraryFile.fromJson(row);
  }

  static Future<void> renameFile(String fileId, String newName) async {
    await supabase
        .from('library_files')
        .update({'file_name': newName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', fileId);
  }

  static Future<void> moveFile(String fileId, String? newFolderId) async {
    await supabase
        .from('library_files')
        .update({
          'folder_id': newFolderId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', fileId);
  }

  static String getPublicUrl(String filePath) {
    return supabase.storage.from(_bucket).getPublicUrl(filePath);
  }

  static Future<void> setShared(String fileId, bool shared) async {
    await supabase
        .from('library_files')
        .update({'is_shared': shared, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', fileId);
  }

  /// Rotates the file's storage path (old public link stops working) —
  /// the only way to truly revoke a link on a public bucket, since anyone
  /// who already has the old URL can otherwise still use it forever.
  static Future<LibraryFile> regenerateLink(LibraryFile file) async {
    final bytes = await supabase.storage.from(_bucket).download(file.filePath);
    final newPath = '${file.ownerUserId}/${_uuid.v4()}_${file.fileName}';
    await supabase.storage.from(_bucket).uploadBinary(
          newPath,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
        );
    await supabase.storage.from(_bucket).remove([file.filePath]);
    final row = await supabase
        .from('library_files')
        .update({
          'file_path': newPath,
          'is_shared': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', file.id)
        .select()
        .single();
    return LibraryFile.fromJson(row);
  }

  static Future<void> deleteFile(LibraryFile file) async {
    await supabase.storage.from(_bucket).remove([file.filePath]);
    await supabase.from('library_files').delete().eq('id', file.id);
  }

  /// Copies the library file into the given ticket's attachments — reuses
  /// the existing ticket_attachments table/bucket so it shows up in every
  /// ticket screen's attachment gallery without any changes there.
  static Future<void> attachToTicket({
    required LibraryFile file,
    required String ticketId,
    required String uploadedByUserId,
  }) async {
    final bytes = await supabase.storage.from(_bucket).download(file.filePath);
    final attachmentPath = 'ticket_attachments/$ticketId/${_uuid.v4()}_${file.fileName}';
    await supabase.storage.from('attachments').uploadBinary(
          attachmentPath,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType),
        );
    await supabase.from('ticket_attachments').insert({
      'ticket_id': ticketId,
      'file_name': file.fileName,
      'file_path': attachmentPath,
      'file_size': bytes.length,
      'mime_type': file.mimeType,
      'uploaded_by': uploadedByUserId,
    });
  }
}
