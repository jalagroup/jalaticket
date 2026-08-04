import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../l10n/app_localizations.dart';
import '../main.dart' show AppColors, supabase;
import '../models.dart' show UserModel;
import '../tickets.dart' show OptimizedDialog;
import 'library_models.dart';
import 'library_service.dart';

class LibraryScreen extends StatefulWidget {
  final UserModel currentUser;
  const LibraryScreen({super.key, required this.currentUser});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryFolder> _folders = [];
  List<LibraryFile> _files = [];
  List<LibraryFolder> _sharedFolders = [];
  List<LibraryFile> _sharedFiles = [];
  bool _loading = true;
  bool _uploading = false;

  // Breadcrumb — the folder currently open is _folderStack.last, or the
  // library root when the stack is empty.
  final List<LibraryFolder> _folderStack = [];
  String? get _currentFolderId => _folderStack.isEmpty ? null : _folderStack.last.id;
  bool get _atRoot => _folderStack.isEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final folderId = _currentFolderId;
      final folders = await LibraryService.getFolders(widget.currentUser.id, folderId);
      final files = await LibraryService.getFiles(widget.currentUser.id, folderId);
      List<LibraryFolder> sharedFolders = [];
      List<LibraryFile> sharedFiles = [];
      if (_atRoot) {
        sharedFolders = await LibraryService.getSharedFolders(widget.currentUser.id);
        sharedFiles = await LibraryService.getSharedFiles(widget.currentUser.id);
      }
      if (mounted) {
        setState(() {
          _folders = folders;
          _files = files;
          _sharedFolders = sharedFolders;
          _sharedFiles = sharedFiles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFolder(LibraryFolder folder) {
    setState(() => _folderStack.add(folder));
    _load();
  }

  void _goUp() {
    if (_folderStack.isEmpty) return;
    setState(() => _folderStack.removeLast());
    _load();
  }

  void _goToRoot() {
    if (_folderStack.isEmpty) return;
    setState(() => _folderStack.clear());
    _load();
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      await LibraryService.uploadFile(
        userId: widget.currentUser.id,
        bytes: bytes,
        fileName: file.name,
        mimeType: _guessMimeType(file.name),
        folderId: _currentFolderId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif',
      'pdf': 'application/pdf', 'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'psd': 'image/vnd.adobe.photoshop', 'zip': 'application/zip', 'txt': 'text/plain',
    };
    return map[ext];
  }

  Future<void> _toggleShare(LibraryFile file) async {
    final l10n = AppLocalizations.safeOf(context);
    await LibraryService.setShared(file.id, !file.isShared);
    await _load();
    if (!file.isShared && mounted) {
      final url = LibraryService.getPublicUrl(file.filePath);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.linkCopied), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _copyLink(LibraryFile file) {
    final l10n = AppLocalizations.safeOf(context);
    final url = LibraryService.getPublicUrl(file.filePath);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.linkCopied), backgroundColor: Colors.green),
    );
  }

  Future<void> _regenerate(LibraryFile file) async {
    try {
      await LibraryService.regenerateLink(file);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteFile(LibraryFile file) async {
    final l10n = AppLocalizations.safeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OptimizedDialog(
        title: l10n.deleteFileTitle,
        isScrollable: false,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
        child: Text('${l10n.deleteFileConfirm}\n"${file.fileName}"'),
      ),
    );
    if (confirmed != true) return;
    await LibraryService.deleteFile(file);
    await _load();
  }

  Future<void> _renameFile(LibraryFile file) async {
    await _promptRename(
      title: AppLocalizations.safeOf(context).renameFile,
      initialValue: file.fileName,
      onSubmit: (value) => LibraryService.renameFile(file.id, value),
    );
    await _load();
  }

  Future<void> _moveFile(LibraryFile file) async {
    final picked = await _pickFolder(excludeFolderId: null);
    if (picked == null) return;
    await LibraryService.moveFile(file.id, picked.folderId);
    await _load();
  }

  void _shareFile(LibraryFile file) {
    showDialog(
      context: context,
      builder: (_) => _ShareDialog(currentUser: widget.currentUser, fileId: file.id, resourceName: file.fileName),
    );
  }

  void _shareFolder(LibraryFolder folder) {
    showDialog(
      context: context,
      builder: (_) => _ShareDialog(currentUser: widget.currentUser, folderId: folder.id, resourceName: folder.name),
    );
  }

  Future<void> _attachToTicket(LibraryFile file) async {
    final l10n = AppLocalizations.safeOf(context);
    final ticket = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TicketPickerDialog(userId: widget.currentUser.id),
    );
    if (ticket == null) return;
    try {
      await LibraryService.attachToTicket(
        file: file,
        ticketId: ticket['id'] as String,
        uploadedByUserId: widget.currentUser.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.attachedToTicket} #${ticket['ticket_number']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.safeOf(context);
    await _promptRename(
      title: l10n.newFolder,
      initialValue: '',
      onSubmit: (value) => LibraryService.createFolder(
        userId: widget.currentUser.id,
        name: value,
        parentFolderId: _currentFolderId,
      ),
    );
    await _load();
  }

  Future<void> _renameFolder(LibraryFolder folder) async {
    await _promptRename(
      title: AppLocalizations.safeOf(context).renameFolder,
      initialValue: folder.name,
      onSubmit: (value) => LibraryService.renameFolder(folder.id, value),
    );
    await _load();
  }

  Future<void> _moveFolder(LibraryFolder folder) async {
    // Best-effort cycle guard: excludes the folder itself from the picker.
    // Moving it into one of its own deeper descendants isn't checked here —
    // low-stakes for a personal library, and the folder would still be
    // reachable by browsing back up if that ever happened.
    final picked = await _pickFolder(excludeFolderId: folder.id);
    if (picked == null) return;
    await LibraryService.moveFolder(folder.id, picked.folderId);
    await _load();
  }

  Future<void> _deleteFolder(LibraryFolder folder) async {
    final l10n = AppLocalizations.safeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OptimizedDialog(
        title: l10n.deleteFolderTitle,
        isScrollable: false,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
        child: Text('${l10n.deleteFolderConfirm}\n"${folder.name}"'),
      ),
    );
    if (confirmed != true) return;
    final ok = await LibraryService.deleteFolderIfEmpty(folder.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.folderNotEmpty), backgroundColor: Colors.orange),
      );
      return;
    }
    await _load();
  }

  /// Shared text-prompt dialog for both "new folder" and "rename" flows —
  /// validates non-empty before calling [onSubmit].
  Future<void> _promptRename({
    required String title,
    required String initialValue,
    required Future<void> Function(String value) onSubmit,
  }) async {
    final l10n = AppLocalizations.safeOf(context);
    final controller = TextEditingController(text: initialValue);
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => OptimizedDialog(
          title: title,
          isScrollable: false,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => errorText = l10n.folderNameRequired);
                  return;
                }
                Navigator.pop(ctx);
                await onSubmit(value);
              },
              child: Text(l10n.save),
            ),
          ],
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.folderName,
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
            onSubmitted: (_) {},
          ),
        ),
      ),
    );
    controller.dispose();
  }

  /// Browsable folder picker used by both "move file" and "move folder" —
  /// navigate deeper by tapping a row, "Move here" confirms whatever level
  /// is currently open (including the library root). Returns null only
  /// when the dialog was dismissed without a selection; a selection of
  /// "root" comes back as _FolderPick(null), not null itself.
  Future<_FolderPick?> _pickFolder({required String? excludeFolderId}) {
    return showDialog<_FolderPick>(
      context: context,
      builder: (_) => _FolderPickerDialog(
        userId: widget.currentUser.id,
        excludeFolderId: excludeFolderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isEmpty = _folders.isEmpty && _files.isEmpty && _sharedFolders.isEmpty && _sharedFiles.isEmpty;
    // Same reserved-space convention used across the app so the FAB clears
    // the floating bottom-nav island instead of sitting behind it.
    final isCompact = MediaQuery.of(context).size.width < 992;
    final bottomNavBarHeight = isCompact && !kIsWeb ? 90.0 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: _folderStack.isNotEmpty
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
            : null,
        titleSpacing: _folderStack.isEmpty ? null : 0,
        title: _folderStack.isEmpty
            ? Text(l10n.myLibrary)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _goToRoot,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(Icons.folder_special_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
                  Flexible(
                    child: Text(_folderStack.last.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.85)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
            onPressed: _createFolder,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomNavBarHeight),
        child: FloatingActionButton.extended(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_rounded, color: Colors.white),
          label: Text(
            _uploading ? l10n.uploading : l10n.uploadFile,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          elevation: 3,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.folder_open_rounded, size: 46, color: AppColors.secondary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _folderStack.isEmpty ? l10n.libraryEmpty : l10n.folderEmpty,
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(12, 14, 12, bottomNavBarHeight + 90),
                  children: [
                    if (_sharedFolders.isNotEmpty || _sharedFiles.isNotEmpty) ...[
                      _SectionHeader(icon: Icons.group_outlined, label: l10n.sharedWithMe, color: AppColors.secondary),
                      const SizedBox(height: 8),
                      for (final folder in _sharedFolders)
                        _FolderTile(
                          folder: folder,
                          sharedByLabel: folder.ownerName,
                          onOpen: () => _openFolder(folder),
                          onRename: null,
                          onMove: null,
                          onDelete: null,
                          onShare: null,
                        ),
                      for (final file in _sharedFiles)
                        _FileTile(
                          file: file,
                          sharedByLabel: file.ownerName,
                          onToggleShare: null,
                          onCopyLink: file.isShared ? () => _copyLink(file) : null,
                          onRegenerate: null,
                          onAttachToTicket: () => _attachToTicket(file),
                          onRename: null,
                          onMove: null,
                          onDelete: null,
                          onShare: null,
                        ),
                      const SizedBox(height: 18),
                    ],
                    if (_folders.isNotEmpty || _files.isNotEmpty) ...[
                      if (_sharedFolders.isNotEmpty || _sharedFiles.isNotEmpty) ...[
                        _SectionHeader(icon: Icons.folder_outlined, label: l10n.myFiles, color: AppColors.primary),
                        const SizedBox(height: 8),
                      ],
                      for (final folder in _folders)
                        _FolderTile(
                          folder: folder,
                          sharedByLabel: null,
                          onOpen: () => _openFolder(folder),
                          onRename: () => _renameFolder(folder),
                          onMove: () => _moveFolder(folder),
                          onDelete: () => _deleteFolder(folder),
                          onShare: () => _shareFolder(folder),
                        ),
                      for (final file in _files)
                        _FileTile(
                          file: file,
                          sharedByLabel: null,
                          onToggleShare: () => _toggleShare(file),
                          onCopyLink: () => _copyLink(file),
                          onRegenerate: () => _regenerate(file),
                          onAttachToTicket: () => _attachToTicket(file),
                          onRename: () => _renameFile(file),
                          onMove: () => _moveFile(file),
                          onDelete: () => _deleteFile(file),
                          onShare: () => _shareFile(file),
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final LibraryFolder folder;
  final String? sharedByLabel;
  final VoidCallback onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const _FolderTile({
    required this.folder,
    required this.sharedByLabel,
    required this.onOpen,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final hasMenu = onRename != null || onMove != null || onDelete != null || onShare != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onOpen,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.shade300, Colors.amber.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder_rounded, color: Colors.white, size: 22),
        ),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        subtitle: sharedByLabel != null
            ? _SharedByChip(name: sharedByLabel!)
            : null,
        trailing: hasMenu
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'share': onShare?.call(); break;
                    case 'rename': onRename?.call(); break;
                    case 'move': onMove?.call(); break;
                    case 'delete': onDelete?.call(); break;
                  }
                },
                itemBuilder: (context) => [
                  if (onShare != null)
                    PopupMenuItem(value: 'share', child: Row(children: [
                      const Icon(Icons.person_add_alt_outlined, size: 18), const SizedBox(width: 8), Text(l10n.shareWithPeople),
                    ])),
                  if (onRename != null)
                    PopupMenuItem(value: 'rename', child: Row(children: [
                      const Icon(Icons.drive_file_rename_outline, size: 18), const SizedBox(width: 8), Text(l10n.rename),
                    ])),
                  if (onMove != null)
                    PopupMenuItem(value: 'move', child: Row(children: [
                      const Icon(Icons.drive_file_move_outline, size: 18), const SizedBox(width: 8), Text(l10n.move),
                    ])),
                  if (onDelete != null) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Row(children: [
                      const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 8),
                      Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                    ])),
                  ],
                ],
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

class _SharedByChip extends StatelessWidget {
  final String name;
  const _SharedByChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined, size: 11, color: AppColors.secondary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${l10n.sharedByName} $name',
              style: TextStyle(fontSize: 10.5, color: AppColors.secondary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final LibraryFile file;
  final String? sharedByLabel;
  final VoidCallback? onToggleShare;
  final VoidCallback? onCopyLink;
  final VoidCallback? onRegenerate;
  final VoidCallback? onAttachToTicket;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const _FileTile({
    required this.file,
    required this.sharedByLabel,
    required this.onToggleShare,
    required this.onCopyLink,
    required this.onRegenerate,
    required this.onAttachToTicket,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.onShare,
  });

  IconData get _icon {
    final mimeType = file.mimeType;
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('photoshop')) return Icons.brush_outlined;
    if (mimeType.contains('zip')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _iconColor {
    final mimeType = file.mimeType;
    if (mimeType == null) return Colors.blueGrey;
    if (mimeType.startsWith('image/')) return Colors.purple;
    if (mimeType == 'application/pdf') return Colors.red;
    if (mimeType.contains('photoshop')) return Colors.indigo;
    if (mimeType.contains('zip')) return Colors.brown;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final hasMenu = onCopyLink != null || onRegenerate != null || onAttachToTicket != null ||
        onRename != null || onMove != null || onDelete != null || onShare != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, color: _iconColor, size: 20),
        ),
        title: Text(file.fileName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(file.formattedSize, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (file.isShared) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public, size: 10, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(l10n.shared, style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (sharedByLabel != null) _SharedByChip(name: sharedByLabel!),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleShare != null)
              IconButton(
                tooltip: file.isShared ? l10n.unshare : l10n.share,
                icon: Icon(
                  file.isShared ? Icons.link_rounded : Icons.share_outlined,
                  color: file.isShared ? Colors.green : Colors.grey[600],
                  size: 20,
                ),
                onPressed: onToggleShare,
              ),
            if (hasMenu)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'copy_link': onCopyLink?.call(); break;
                    case 'regenerate': onRegenerate?.call(); break;
                    case 'attach': onAttachToTicket?.call(); break;
                    case 'share': onShare?.call(); break;
                    case 'rename': onRename?.call(); break;
                    case 'move': onMove?.call(); break;
                    case 'delete': onDelete?.call(); break;
                  }
                },
                itemBuilder: (context) => [
                  if (onCopyLink != null)
                    PopupMenuItem(value: 'copy_link', child: Row(children: [
                      const Icon(Icons.copy_outlined, size: 18), const SizedBox(width: 8), Text(l10n.copyLink),
                    ])),
                  if (onRegenerate != null)
                    PopupMenuItem(value: 'regenerate', child: Row(children: [
                      const Icon(Icons.refresh, size: 18), const SizedBox(width: 8), Text(l10n.revokeLink),
                    ])),
                  if (onShare != null)
                    PopupMenuItem(value: 'share', child: Row(children: [
                      const Icon(Icons.person_add_alt_outlined, size: 18), const SizedBox(width: 8), Text(l10n.shareWithPeople),
                    ])),
                  if (onAttachToTicket != null)
                    PopupMenuItem(value: 'attach', child: Row(children: [
                      const Icon(Icons.confirmation_number_outlined, size: 18), const SizedBox(width: 8), Text(l10n.attachToTicket),
                    ])),
                  if (onRename != null)
                    PopupMenuItem(value: 'rename', child: Row(children: [
                      const Icon(Icons.drive_file_rename_outline, size: 18), const SizedBox(width: 8), Text(l10n.rename),
                    ])),
                  if (onMove != null)
                    PopupMenuItem(value: 'move', child: Row(children: [
                      const Icon(Icons.drive_file_move_outline, size: 18), const SizedBox(width: 8), Text(l10n.move),
                    ])),
                  if (onDelete != null) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Row(children: [
                      const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 8),
                      Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                    ])),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a picked folder id so "root selected" (null) is distinguishable
/// from "dialog dismissed without a selection" (no _FolderPick at all).
class _FolderPick {
  final String? folderId;
  const _FolderPick(this.folderId);
}

/// Move-to picker: browses the same folder tree as the main screen,
/// starting at the root, letting the user drill into sub-folders and
/// confirm whichever level is currently open via "Move here".
class _FolderPickerDialog extends StatefulWidget {
  final String userId;
  final String? excludeFolderId;
  const _FolderPickerDialog({required this.userId, required this.excludeFolderId});

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  final List<LibraryFolder> _stack = [];
  List<LibraryFolder> _children = [];
  bool _loading = true;

  String? get _currentFolderId => _stack.isEmpty ? null : _stack.last.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folders = await LibraryService.getFolders(widget.userId, _currentFolderId);
    if (mounted) {
      setState(() {
        _children = folders.where((f) => f.id != widget.excludeFolderId).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return OptimizedDialog(
      title: l10n.selectDestinationFolder,
      isScrollable: false,
      height: 460,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: Text(l10n.moveHere),
          onPressed: () => Navigator.pop(context, _FolderPick(_currentFolderId)),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_stack.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  onPressed: () => setState(() { _stack.removeLast(); _load(); }),
                ),
              Expanded(
                child: Text(
                  _stack.isEmpty ? l10n.libraryRoot : _stack.last.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _children.isEmpty
                    ? Center(child: Text(l10n.folderEmpty, style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          final folder = _children[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 20),
                            title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => setState(() { _stack.add(folder); _load(); }),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Manage-access dialog for a single file or folder — add a person by
/// name search, change their permission, or remove access.
class _ShareDialog extends StatefulWidget {
  final UserModel currentUser;
  final String? fileId;
  final String? folderId;
  final String resourceName;
  const _ShareDialog({required this.currentUser, this.fileId, this.folderId, required this.resourceName});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  List<LibraryShare> _shares = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final shares = widget.fileId != null
        ? await LibraryService.getSharesForFile(widget.fileId!)
        : await LibraryService.getSharesForFolder(widget.folderId!);
    if (mounted) setState(() { _shares = shares; _loading = false; });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await LibraryService.searchUsers(widget.currentUser.id, trimmed);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _addPerson(Map<String, dynamic> user) async {
    final l10n = AppLocalizations.safeOf(context);
    if (widget.fileId != null) {
      await LibraryService.shareFile(
        fileId: widget.fileId!,
        sharedByUserId: widget.currentUser.id,
        sharedWithUserId: user['id'] as String,
        permission: 'view',
      );
    } else {
      await LibraryService.shareFolder(
        folderId: widget.folderId!,
        sharedByUserId: widget.currentUser.id,
        sharedWithUserId: user['id'] as String,
        permission: 'view',
      );
    }
    _searchCtrl.clear();
    if (mounted) setState(() => _searchResults = []);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.personAdded), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _changePermission(LibraryShare share, String permission) async {
    if (widget.fileId != null) {
      await LibraryService.shareFile(
        fileId: widget.fileId!,
        sharedByUserId: widget.currentUser.id,
        sharedWithUserId: share.sharedWithUserId,
        permission: permission,
      );
    } else {
      await LibraryService.shareFolder(
        folderId: widget.folderId!,
        sharedByUserId: widget.currentUser.id,
        sharedWithUserId: share.sharedWithUserId,
        permission: permission,
      );
    }
    await _load();
  }

  Future<void> _remove(LibraryShare share) async {
    await LibraryService.unshare(share.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return OptimizedDialog(
      title: l10n.shareWithPeople,
      isScrollable: false,
      height: 500,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.resourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: l10n.addPerson,
              hintText: l10n.searchByName,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _search,
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final u = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline, size: 18),
                    title: Text(u['full_name'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                    onTap: () => _addPerson(u),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          Text(l10n.manageAccess, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _shares.isEmpty
                    ? Center(child: Text(l10n.noOneHasAccessYet, style: TextStyle(color: Colors.grey[500], fontSize: 12)))
                    : ListView.builder(
                        itemCount: _shares.length,
                        itemBuilder: (context, index) {
                          final s = _shares[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                              child: Text(
                                (s.sharedWithName?.isNotEmpty == true ? s.sharedWithName![0] : '?').toUpperCase(),
                                style: TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(s.sharedWithName ?? '', style: const TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<String>(
                                  value: s.permission,
                                  underline: const SizedBox(),
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  items: [
                                    DropdownMenuItem(value: 'view', child: Text(l10n.viewOnly)),
                                    DropdownMenuItem(value: 'edit', child: Text(l10n.canEdit)),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) _changePermission(s, v);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  tooltip: l10n.removeAccess,
                                  onPressed: () => _remove(s),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TicketPickerDialog extends StatefulWidget {
  final String userId;
  const _TicketPickerDialog({required this.userId});

  @override
  State<_TicketPickerDialog> createState() => _TicketPickerDialogState();
}

class _TicketPickerDialogState extends State<_TicketPickerDialog> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('tickets')
          .select('id, ticket_number, title')
          .or('created_by.eq.${widget.userId},assigned_to.eq.${widget.userId}')
          .neq('status', 'deleted')
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) setState(() { _tickets = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _tickets
        : _tickets.where((t) =>
            (t['title'] as String? ?? '').toLowerCase().contains(query) ||
            (t['ticket_number'] as String? ?? '').toLowerCase().contains(query)).toList();

    return OptimizedDialog(
      title: l10n.selectATicket,
      isScrollable: false,
      height: 460,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      ],
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: l10n.searchByTitleOrNumber,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text(l10n.noTicketsFound))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.confirmation_number_outlined, size: 18),
                            title: Text(t['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('#${t['ticket_number']}'),
                            onTap: () => Navigator.pop(context, t),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
