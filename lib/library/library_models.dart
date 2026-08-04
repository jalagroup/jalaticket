class LibraryFile {
  final String id;
  final String ownerUserId;
  final String fileName;
  final String filePath;
  final int? fileSize;
  final String? mimeType;
  final bool isShared;
  final String? folderId;
  final DateTime createdAt;
  // Populated only on "shared with me" queries — the owner's display name,
  // so the UI can badge the item "Shared by X" instead of showing it as
  // one of the current user's own files.
  final String? ownerName;

  const LibraryFile({
    required this.id,
    required this.ownerUserId,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.mimeType,
    required this.isShared,
    this.folderId,
    required this.createdAt,
    this.ownerName,
  });

  factory LibraryFile.fromJson(Map<String, dynamic> j) => LibraryFile(
        id: j['id'] as String,
        ownerUserId: j['owner_user_id'] as String,
        fileName: j['file_name'] as String,
        filePath: j['file_path'] as String,
        fileSize: j['file_size'] as int?,
        mimeType: j['mime_type'] as String?,
        isShared: j['is_shared'] as bool? ?? false,
        folderId: j['folder_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        ownerName: (j['owner'] as Map<String, dynamic>?)?['full_name'] as String?,
      );

  String get formattedSize {
    final bytes = fileSize;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class LibraryFolder {
  final String id;
  final String ownerUserId;
  final String? parentFolderId;
  final String name;
  final DateTime createdAt;
  final String? ownerName;

  const LibraryFolder({
    required this.id,
    required this.ownerUserId,
    this.parentFolderId,
    required this.name,
    required this.createdAt,
    this.ownerName,
  });

  factory LibraryFolder.fromJson(Map<String, dynamic> j) => LibraryFolder(
        id: j['id'] as String,
        ownerUserId: j['owner_user_id'] as String,
        parentFolderId: j['parent_folder_id'] as String?,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        ownerName: (j['owner'] as Map<String, dynamic>?)?['full_name'] as String?,
      );
}

/// A single share grant — who a file/folder was shared with and at what
/// permission level. Used both for the library's own "manage sharing" UI
/// and for ticket attachments showing who a library file was shared with.
class LibraryShare {
  final String id;
  final String? fileId;
  final String? folderId;
  final String sharedByUserId;
  final String sharedWithUserId;
  final String? sharedWithName;
  final String permission; // 'view' | 'edit'
  final DateTime createdAt;

  const LibraryShare({
    required this.id,
    this.fileId,
    this.folderId,
    required this.sharedByUserId,
    required this.sharedWithUserId,
    this.sharedWithName,
    required this.permission,
    required this.createdAt,
  });

  factory LibraryShare.fromJson(Map<String, dynamic> j) => LibraryShare(
        id: j['id'] as String,
        fileId: j['file_id'] as String?,
        folderId: j['folder_id'] as String?,
        sharedByUserId: j['shared_by_user_id'] as String,
        sharedWithUserId: j['shared_with_user_id'] as String,
        sharedWithName: (j['shared_with'] as Map<String, dynamic>?)?['full_name'] as String?,
        permission: j['permission'] as String? ?? 'view',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
