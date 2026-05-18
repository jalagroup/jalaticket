import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ─── Source picker helper (shared with tickets.dart) ──────────────────────────

Future<ImageSource?> showImageSourceBottomSheet(BuildContext context) {
  final isRtl = Localizations.localeOf(context).languageCode == 'ar';
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.photo_library, color: Colors.blue)),
            title: Text(isRtl ? 'المعرض' : 'Gallery',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.camera_alt, color: Colors.green)),
            title: Text(isRtl ? 'الكاميرا' : 'Camera',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

// ─── Truck Maintenance Ticket Screen ──────────────────────────────────────────

class TrucksMaintenanceTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const TrucksMaintenanceTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<TrucksMaintenanceTicketScreen> createState() =>
      _TrucksMaintenanceTicketScreenState();
}

class _TrucksMaintenanceTicketScreenState
    extends State<TrucksMaintenanceTicketScreen> {
  final _vehicleTypeCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _counterNumberCtrl = TextEditingController();
  final _problemDescCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priorityReasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PriorityType _priority = PriorityType.medium;
  List<PlatformFile> _selectedFiles = [];
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;

  String? _trucksDeptId;

  @override
  void initState() {
    super.initState();
    _loadTrucksDepartment();
  }

  Future<void> _loadTrucksDepartment() async {
    try {
      final row = await supabase
          .from('system_settings')
          .select('value')
          .eq('setting_key', 'vehicle_maintenance_target_department')
          .maybeSingle();
      if (mounted && row != null) {
        setState(() => _trucksDeptId = row['value'] as String?);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _vehicleTypeCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _counterNumberCtrl.dispose();
    _problemDescCtrl.dispose();
    _locationCtrl.dispose();
    _priorityReasonCtrl.dispose();
    super.dispose();
  }

  String get _combinedDescription =>
      'نوع المركبة: ${_vehicleTypeCtrl.text.trim()}\n'
      'رقم المركبة: ${_vehicleNumberCtrl.text.trim()}\n'
      'رقم العداد: ${_counterNumberCtrl.text.trim()}\n'
      'وصف المشكلة: ${_problemDescCtrl.text.trim()}';

  bool get _needsReason =>
      _priority == PriorityType.high || _priority == PriorityType.urgent;

  // ── Image / file picking ───────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final source = await showImageSourceBottomSheet(context);
      if (source == null) return;
      List<XFile> images;
      if (source == ImageSource.camera) {
        final img = await _imagePicker.pickImage(
            source: ImageSource.camera, imageQuality: 90);
        images = img != null ? [img] : [];
      } else {
        images = await _imagePicker.pickMultiImage(imageQuality: 90);
      }
      if (images.isNotEmpty) {
        final files = <PlatformFile>[];
        for (final img in images) {
          final bytes = await img.readAsBytes();
          files.add(PlatformFile(
              name: img.name, size: bytes.length, bytes: bytes, path: img.path));
        }
        setState(() => _selectedFiles.addAll(files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          allowMultiple: true, withData: true);
      if (result != null) setState(() => _selectedFiles.addAll(result.files));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking files: $e')));
      }
    }
  }

  void _removeFile(int i) => setState(() => _selectedFiles.removeAt(i));

  String _getMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];
    setState(() => _isUploadingFiles = true);
    final paths = <String>[];
    try {
      for (final file in _selectedFiles) {
        if (file.bytes == null) continue;
        final fileName = '${const Uuid().v4()}.${file.name.split('.').last}';
        final filePath = 'ticket_attachments/$ticketId/$fileName';
        await supabase.storage.from('attachments').uploadBinary(
              filePath, file.bytes!,
              fileOptions: FileOptions(contentType: _getMime(file.name)));
        await supabase.from('ticket_attachments').insert({
          'ticket_id': ticketId,
          'file_name': file.name,
          'file_path': filePath,
          'file_size': file.size,
          'mime_type': _getMime(file.name),
          'uploaded_by': widget.currentUser.id,
        });
        paths.add(filePath);
      }
    } finally {
      if (mounted) setState(() => _isUploadingFiles = false);
    }
    return paths;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final ticketData = {
        'title': 'صيانة شاحنات',
        'description': _combinedDescription,
        'target_department_id': _trucksDeptId,
        'place_id': widget.currentUser.placeId,
        'other_nature_of_work': 'Other',
        'other_place': 'Other',
        'other_problem_title': 'صيانة شاحنات',
        'other_model_number': 'Other',
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'priority': _priority.value,
        'high_priority_explain': _needsReason
            ? _priorityReasonCtrl.text.trim()
            : null,
        'created_by': widget.currentUser.id,
        'creator_phone': widget.currentUser.phone ?? '',
      };

      final success = await TicketService.createTicket(ticketData);
      if (!success) throw Exception('createTicket returned false');

      final recent = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);
      if (recent.isEmpty) throw Exception('Could not find created ticket');

      final ticketId = recent.first['id'] as String;
      final ticketNumber = recent.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) await _uploadFiles(ticketId);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onTicketCreated();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text('تم إنشاء تذكرة صيانة شاحنات #$ticketNumber بنجاح'),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ في إنشاء التذكرة: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'صيانة شاحنات',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Orange header strip
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تذكرة صيانة شاحنات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card(children: [
                      _sectionTitle('بيانات المركبة', Icons.directions_car),
                      const SizedBox(height: 12),
                      _field(
                        controller: _vehicleTypeCtrl,
                        label: 'نوع المركبة *',
                        hint: 'مثال: شاحنة نقل / رافعة شوكية',
                        icon: Icons.directions_car,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'يرجى إدخال نوع المركبة'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _vehicleNumberCtrl,
                        label: 'رقم المركبة *',
                        hint: 'رقم لوحة المركبة',
                        icon: Icons.pin,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'يرجى إدخال رقم المركبة'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _counterNumberCtrl,
                        label: 'رقم العداد *',
                        hint: 'قراءة عداد المسافة الحالية',
                        icon: Icons.speed,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'يرجى إدخال رقم العداد'
                            : null,
                      ),
                    ]),

                    const SizedBox(height: 12),

                    _card(children: [
                      _sectionTitle('وصف المشكلة', Icons.build_circle_outlined),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _problemDescCtrl,
                        maxLines: 4,
                        textDirection: TextDirection.rtl,
                        decoration: _inputDeco(
                            label: 'وصف المشكلة *',
                            hint: 'اشرح المشكلة بالتفصيل...',
                            icon: Icons.description),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى وصف المشكلة';
                          }
                          if (v.trim().length < 5) {
                            return 'يرجى تفصيل المشكلة أكثر';
                          }
                          return null;
                        },
                      ),
                    ]),

                    const SizedBox(height: 12),

                    _card(children: [
                      _sectionTitle('تفاصيل إضافية', Icons.tune),
                      const SizedBox(height: 12),
                      _field(
                        controller: _locationCtrl,
                        label: 'الموقع (اختياري)',
                        hint: 'موقع المركبة الحالي',
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      // Priority
                      Text('الأولوية *',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PriorityType.values.map((p) {
                          final isSelected = _priority == p;
                          final color = _priorityColor(p);
                          return ChoiceChip(
                            label: Text(_priorityLabel(p)),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _priority = p),
                            selectedColor: color.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: isSelected ? color : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                                color: isSelected
                                    ? color
                                    : Colors.grey[300]!),
                            backgroundColor: Colors.white,
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      if (_needsReason) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _priorityReasonCtrl,
                          maxLines: 2,
                          textDirection: TextDirection.rtl,
                          decoration: _inputDeco(
                              label: 'سبب الأولوية العالية *',
                              hint: 'اشرح سبب تحديد هذه الأولوية...',
                              icon: Icons.priority_high),
                          validator: (v) => _needsReason &&
                                  (v == null || v.trim().isEmpty)
                              ? 'يرجى ذكر سبب الأولوية العالية'
                              : null,
                        ),
                      ],
                    ]),

                    const SizedBox(height: 12),

                    // Attachments
                    _card(children: [
                      Row(children: [
                        _sectionTitle('المرفقات (اختياري)', Icons.attach_file),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('صور'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary),
                        ),
                        TextButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('ملفات'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary),
                        ),
                      ]),
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedFiles.length,
                            itemBuilder: (_, i) {
                              final f = _selectedFiles[i];
                              final isImg = ['jpg', 'jpeg', 'png', 'gif']
                                  .contains(f.extension?.toLowerCase());
                              return Stack(children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey[200]!),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isImg && f.bytes != null
                                        ? Image.memory(f.bytes!,
                                            fit: BoxFit.cover)
                                        : Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons.insert_drive_file,
                                                    color: Colors.grey),
                                                Text(
                                                  f.extension
                                                          ?.toUpperCase() ??
                                                      'FILE',
                                                  style: const TextStyle(
                                                      fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => _removeFile(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ]);
                            },
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'يمكنك إرفاق صور أو ملفات للمشكلة',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_isLoading || _isUploadingFiles) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.5),
            ),
            child: (_isLoading || _isUploadingFiles)
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('إرسال طلب الصيانة',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────────

  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.onBackground)),
      ]);

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        textDirection: TextDirection.rtl,
        keyboardType: keyboardType,
        decoration: _inputDeco(label: label, hint: hint, icon: icon),
        validator: validator,
      );

  InputDecoration _inputDeco(
          {required String label,
          required String hint,
          required IconData icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      );

  Color _priorityColor(PriorityType p) {
    switch (p) {
      case PriorityType.low:
        return Colors.green;
      case PriorityType.medium:
        return Colors.blue;
      case PriorityType.high:
        return Colors.orange;
      case PriorityType.urgent:
        return Colors.red;
    }
  }

  String _priorityLabel(PriorityType p) {
    switch (p) {
      case PriorityType.low:
        return 'منخفضة';
      case PriorityType.medium:
        return 'متوسطة';
      case PriorityType.high:
        return 'عالية';
      case PriorityType.urgent:
        return 'عاجلة';
    }
  }
}
