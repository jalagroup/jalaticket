class LibraryFile {
  final String id;
  final String ownerUserId;
  final String fileName;
  final String filePath;
  final int? fileSize;
  final String? mimeType;
  final bool isShared;
  final DateTime createdAt;

  const LibraryFile({
    required this.id,
    required this.ownerUserId,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.mimeType,
    required this.isShared,
    required this.createdAt,
  });

  factory LibraryFile.fromJson(Map<String, dynamic> j) => LibraryFile(
        id: j['id'] as String,
        ownerUserId: j['owner_user_id'] as String,
        fileName: j['file_name'] as String,
        filePath: j['file_path'] as String,
        fileSize: j['file_size'] as int?,
        mimeType: j['mime_type'] as String?,
        isShared: j['is_shared'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get formattedSize {
    final bytes = fileSize;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
