import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../l10n/app_localizations.dart';
import '../main.dart' show AppColors, supabase;
import '../models.dart' show UserModel;
import 'library_models.dart';
import 'library_service.dart';

class LibraryScreen extends StatefulWidget {
  final UserModel currentUser;
  const LibraryScreen({super.key, required this.currentUser});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryFile> _files = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final files = await LibraryService.getMyFiles(widget.currentUser.id);
      if (mounted) setState(() { _files = files; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
    await LibraryService.setShared(file.id, !file.isShared);
    await _load();
    if (!file.isShared && mounted) {
      final url = LibraryService.getPublicUrl(file.filePath);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _copyLink(LibraryFile file) {
    final url = LibraryService.getPublicUrl(file.filePath);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard'), backgroundColor: Colors.green),
    );
  }

  Future<void> _regenerate(LibraryFile file) async {
    try {
      await LibraryService.regenerateLink(file);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Old link revoked. Share again to get a new one.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(LibraryFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('This will permanently delete "${file.fileName}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LibraryService.deleteFile(file);
    await _load();
  }

  Future<void> _attachToTicket(LibraryFile file) async {
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
            content: Text('Attached to ticket #${ticket['ticket_number']}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myLibrary),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
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
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(l10n.libraryEmpty, style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_iconFor(file.mimeType), color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(file.fileName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(file.formattedSize,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                if (file.isShared)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.public, size: 11, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(l10n.shared, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _toggleShare(file),
                                  icon: Icon(file.isShared ? Icons.link_off : Icons.share_outlined, size: 15),
                                  label: Text(file.isShared ? l10n.unshare : l10n.share, style: const TextStyle(fontSize: 12)),
                                ),
                                if (file.isShared)
                                  OutlinedButton.icon(
                                    onPressed: () => _copyLink(file),
                                    icon: const Icon(Icons.copy_outlined, size: 15),
                                    label: Text(l10n.copyLink, style: const TextStyle(fontSize: 12)),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _regenerate(file),
                                  icon: const Icon(Icons.refresh, size: 15),
                                  label: Text(l10n.revokeLink, style: const TextStyle(fontSize: 12)),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _attachToTicket(file),
                                  icon: const Icon(Icons.confirmation_number_outlined, size: 15),
                                  label: Text(l10n.attachToTicket, style: const TextStyle(fontSize: 12)),
                                ),
                                IconButton(
                                  onPressed: () => _delete(file),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _tickets
        : _tickets.where((t) =>
            (t['title'] as String? ?? '').toLowerCase().contains(query) ||
            (t['ticket_number'] as String? ?? '').toLowerCase().contains(query)).toList();

    return AlertDialog(
      title: const Text('Select a ticket'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by title or ticket number',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No tickets found'))
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
