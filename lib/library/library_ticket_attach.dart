import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show AppColors, supabase;
import '../models.dart' show UserModel;
import '../tickets.dart' show OptimizedDialog;
import 'library_models.dart';
import 'library_service.dart';

/// Shared "attach from library" flow used by every ticket-creation dialog:
/// browse-and-pick one or more files (picking a folder attaches every file
/// directly inside it), then — once the ticket exists — offer to share
/// those files with the people who'll be handling the ticket.

IconData libraryFileIcon(String? mimeType) {
  if (mimeType == null) return Icons.insert_drive_file_outlined;
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mimeType.contains('photoshop')) return Icons.brush_outlined;
  if (mimeType.contains('zip')) return Icons.folder_zip_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Opens the library in multi-select mode; returns the chosen files, or
/// null if the picker was dismissed without confirming a selection.
Future<List<LibraryFile>?> pickLibraryFiles(BuildContext context, {required String userId}) {
  return showDialog<List<LibraryFile>>(
    context: context,
    builder: (_) => _LibraryFilePickerDialog(userId: userId),
  );
}

/// After a ticket is created with one or more library-sourced attachments,
/// asks the creator whether to share those files with the people who'll
/// work on it — either everyone with admin/super-admin access in the
/// target department, or one specific admin. No-op (silently returns) if
/// [departmentId] is null or nothing is picked/attached.
Future<void> promptShareLibraryAttachments(
  BuildContext context, {
  required UserModel currentUser,
  required List<LibraryFile> attachedFiles,
  required String? departmentId,
}) async {
  if (attachedFiles.isEmpty || departmentId == null || !context.mounted) return;
  final l10n = AppLocalizations.safeOf(context);

  final choice = await showDialog<String>(
    context: context,
    builder: (_) => OptimizedDialog(
      title: l10n.shareThisLibraryAttachment,
      isScrollable: false,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'skip'), child: Text(l10n.dontShare)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shareThisLibraryAttachmentHint, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 16),
          _ChoiceTile(
            icon: Icons.groups_outlined,
            label: l10n.shareWithAllDeptAdmins,
            onTap: () => Navigator.pop(context, 'all'),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: Icons.person_outline,
            label: l10n.shareWithSpecificAdmin,
            onTap: () => Navigator.pop(context, 'specific'),
          ),
        ],
      ),
    ),
  );

  if (choice == null || choice == 'skip' || !context.mounted) return;

  List<Map<String, dynamic>> recipients;
  if (choice == 'all') {
    final rows = await supabase
        .from('users')
        .select('id, full_name')
        .eq('department_id', departmentId)
        .inFilter('user_type', ['admin', 'super_admin'])
        .eq('is_active', true);
    recipients = List<Map<String, dynamic>>.from(rows);
  } else {
    if (!context.mounted) return;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DeptAdminPickerDialog(departmentId: departmentId),
    );
    recipients = picked == null ? [] : [picked];
  }

  for (final file in attachedFiles) {
    for (final user in recipients) {
      final userId = user['id'] as String?;
      if (userId == null || userId == currentUser.id) continue;
      await LibraryService.shareFile(
        fileId: file.id,
        sharedByUserId: currentUser.id,
        sharedWithUserId: userId,
        permission: 'view',
      );
    }
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ChoiceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _DeptAdminPickerDialog extends StatefulWidget {
  final String departmentId;
  const _DeptAdminPickerDialog({required this.departmentId});

  @override
  State<_DeptAdminPickerDialog> createState() => _DeptAdminPickerDialogState();
}

class _DeptAdminPickerDialogState extends State<_DeptAdminPickerDialog> {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await supabase
        .from('users')
        .select('id, full_name')
        .eq('department_id', widget.departmentId)
        .inFilter('user_type', ['admin', 'super_admin'])
        .eq('is_active', true)
        .order('full_name');
    if (mounted) setState(() { _admins = List<Map<String, dynamic>>.from(rows); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return OptimizedDialog(
      title: l10n.shareWithSpecificAdmin,
      isScrollable: false,
      height: 400,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? Center(child: Text(l10n.noAvailableAdminsFound))
              : ListView.builder(
                  itemCount: _admins.length,
                  itemBuilder: (context, index) {
                    final a = _admins[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 18),
                      title: Text(a['full_name'] as String? ?? ''),
                      onTap: () => Navigator.pop(context, a),
                    );
                  },
                ),
    );
  }
}

/// Multi-select browse dialog — tap a folder to enter it, tap a file's
/// checkbox to toggle selection, "Attach whole folder" grabs every file
/// directly inside the currently-open folder in one go.
class _LibraryFilePickerDialog extends StatefulWidget {
  final String userId;
  const _LibraryFilePickerDialog({required this.userId});

  @override
  State<_LibraryFilePickerDialog> createState() => _LibraryFilePickerDialogState();
}

class _LibraryFilePickerDialogState extends State<_LibraryFilePickerDialog> {
  final List<LibraryFolder> _stack = [];
  List<LibraryFolder> _folders = [];
  List<LibraryFile> _files = [];
  bool _loading = true;
  final Map<String, LibraryFile> _selected = {};

  String? get _currentFolderId => _stack.isEmpty ? null : _stack.last.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folders = await LibraryService.getFolders(widget.userId, _currentFolderId);
    final files = await LibraryService.getFiles(widget.userId, _currentFolderId);
    if (mounted) setState(() { _folders = folders; _files = files; _loading = false; });
  }

  void _toggle(LibraryFile file) {
    setState(() {
      if (_selected.containsKey(file.id)) {
        _selected.remove(file.id);
      } else {
        _selected[file.id] = file;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return OptimizedDialog(
      title: l10n.attachFromLibrary,
      isScrollable: false,
      height: 520,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.values.toList()),
          child: Text('${l10n.attachToTicket} (${_selected.length})'),
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
              if (_files.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    for (final f in _files) {
                      _selected[f.id] = f;
                    }
                  }),
                  child: Text(l10n.selectAll, style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const Divider(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_folders.isEmpty && _files.isEmpty)
                    ? Center(child: Text(l10n.folderEmpty, style: TextStyle(color: Colors.grey[500])))
                    : ListView(
                        children: [
                          for (final folder in _folders)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 20),
                              title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => setState(() { _stack.add(folder); _load(); }),
                            ),
                          for (final file in _files)
                            CheckboxListTile(
                              dense: true,
                              value: _selected.containsKey(file.id),
                              onChanged: (_) => _toggle(file),
                              secondary: Icon(libraryFileIcon(file.mimeType), size: 18, color: AppColors.primary),
                              title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(file.formattedSize, style: const TextStyle(fontSize: 10)),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Removable chip row showing files picked from the library, rendered
/// alongside a ticket dialog's regular picked-images/attachments list.
class LibraryAttachmentChips extends StatelessWidget {
  final List<LibraryFile> files;
  final ValueChanged<LibraryFile> onRemove;
  const LibraryAttachmentChips({super.key, required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: files.map((f) {
        return Chip(
          avatar: Icon(libraryFileIcon(f.mimeType), size: 16, color: AppColors.primary),
          label: Text(f.fileName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: () => onRemove(f),
        );
      }).toList(),
    );
  }
}
