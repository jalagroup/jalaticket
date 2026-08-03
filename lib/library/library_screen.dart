import 'package:file_picker/file_picker.dart';
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
  bool _loading = true;
  bool _uploading = false;

  // Breadcrumb — the folder currently open is _folderStack.last, or the
  // library root when the stack is empty.
  final List<LibraryFolder> _folderStack = [];
  String? get _currentFolderId => _folderStack.isEmpty ? null : _folderStack.last.id;

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
      if (mounted) setState(() { _folders = folders; _files = files; _loading = false; });
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

  IconData _iconFor(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('photoshop')) return Icons.brush_outlined;
    if (mimeType.contains('zip')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isEmpty = _folders.isEmpty && _files.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: _folderStack.isNotEmpty
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
            : null,
        title: GestureDetector(
          onTap: _folderStack.isNotEmpty ? _goToRoot : null,
          child: Text(_folderStack.isEmpty ? l10n.myLibrary : _folderStack.last.name),
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newFolder,
            onPressed: _createFolder,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? l10n.uploading : l10n.uploadFile),
        backgroundColor: AppColors.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        _folderStack.isEmpty ? l10n.libraryEmpty : l10n.folderEmpty,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [
                    for (final folder in _folders) _FolderTile(
                      folder: folder,
                      onOpen: () => _openFolder(folder),
                      onRename: () => _renameFolder(folder),
                      onMove: () => _moveFolder(folder),
                      onDelete: () => _deleteFolder(folder),
                    ),
                    for (final file in _files) _FileTile(
                      file: file,
                      iconFor: _iconFor,
                      onToggleShare: () => _toggleShare(file),
                      onCopyLink: () => _copyLink(file),
                      onRegenerate: () => _regenerate(file),
                      onAttachToTicket: () => _attachToTicket(file),
                      onRename: () => _renameFile(file),
                      onMove: () => _moveFile(file),
                      onDelete: () => _deleteFile(file),
                    ),
                  ],
                ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final LibraryFolder folder;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _FolderTile({
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.folder_rounded, color: Colors.amber),
        ),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            switch (value) {
              case 'rename': onRename(); break;
              case 'move': onMove(); break;
              case 'delete': onDelete(); break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'rename', child: Row(children: [
              const Icon(Icons.drive_file_rename_outline, size: 18), const SizedBox(width: 8), Text(l10n.rename),
            ])),
            PopupMenuItem(value: 'move', child: Row(children: [
              const Icon(Icons.drive_file_move_outline, size: 18), const SizedBox(width: 8), Text(l10n.move),
            ])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Row(children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 8),
              Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ])),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final LibraryFile file;
  final IconData Function(String?) iconFor;
  final VoidCallback onToggleShare;
  final VoidCallback onCopyLink;
  final VoidCallback onRegenerate;
  final VoidCallback onAttachToTicket;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _FileTile({
    required this.file,
    required this.iconFor,
    required this.onToggleShare,
    required this.onCopyLink,
    required this.onRegenerate,
    required this.onAttachToTicket,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconFor(file.mimeType), color: AppColors.primary, size: 20),
        ),
        title: Text(file.fileName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: file.isShared ? l10n.unshare : l10n.share,
              icon: Icon(
                file.isShared ? Icons.link_rounded : Icons.share_outlined,
                color: file.isShared ? Colors.green : Colors.grey[600],
                size: 20,
              ),
              onPressed: onToggleShare,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'copy_link': onCopyLink(); break;
                  case 'regenerate': onRegenerate(); break;
                  case 'attach': onAttachToTicket(); break;
                  case 'rename': onRename(); break;
                  case 'move': onMove(); break;
                  case 'delete': onDelete(); break;
                }
              },
              itemBuilder: (context) => [
                if (file.isShared)
                  PopupMenuItem(value: 'copy_link', child: Row(children: [
                    const Icon(Icons.copy_outlined, size: 18), const SizedBox(width: 8), Text(l10n.copyLink),
                  ])),
                if (file.isShared)
                  PopupMenuItem(value: 'regenerate', child: Row(children: [
                    const Icon(Icons.refresh, size: 18), const SizedBox(width: 8), Text(l10n.revokeLink),
                  ])),
                PopupMenuItem(value: 'attach', child: Row(children: [
                  const Icon(Icons.confirmation_number_outlined, size: 18), const SizedBox(width: 8), Text(l10n.attachToTicket),
                ])),
                PopupMenuItem(value: 'rename', child: Row(children: [
                  const Icon(Icons.drive_file_rename_outline, size: 18), const SizedBox(width: 8), Text(l10n.rename),
                ])),
                PopupMenuItem(value: 'move', child: Row(children: [
                  const Icon(Icons.drive_file_move_outline, size: 18), const SizedBox(width: 8), Text(l10n.move),
                ])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: Row(children: [
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 8),
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                ])),
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
