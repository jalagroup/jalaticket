import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReportProblemScreen extends StatefulWidget {
  final UserModel currentUser;

  const ReportProblemScreen({super.key, required this.currentUser});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _pickedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return null;
    final bytes = await _pickedImage!.readAsBytes();
    final ext = _pickedImage!.name.split('.').last.toLowerCase();
    final path = 'problem_reports/${const Uuid().v4()}.$ext';
    await supabase.storage.from('problem_reports').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(cacheControl: '3600', upsert: false),
        );
    return supabase.storage.from('problem_reports').getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      if (_pickedImage != null) imageUrl = await _uploadImage();

      await supabase.from('problem_reports').insert({
        'user_id': widget.currentUser.id,
        'user_name': widget.currentUser.fullName,
        'user_email': widget.currentUser.email,
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'status': 'new',
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Your report has been submitted. We will review it shortly.')),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          isRtl ? 'الإبلاغ عن مشكلة' : 'Report a Problem',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bug_report_rounded,
                            color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRtl ? 'ساعدنا في التحسين' : 'Help us improve',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.onBackground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRtl
                                  ? 'صف المشكلة التي واجهتها وسنتواصل معك في أقرب وقت.'
                                  : 'Describe the issue you faced and we\'ll look into it as soon as possible.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Description field
                Text(
                  isRtl ? 'وصف المشكلة *' : 'Problem Description *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  minLines: 4,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: isRtl
                        ? 'اشرح المشكلة بالتفصيل...'
                        : 'Describe the problem in detail...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isRtl
                          ? 'يرجى وصف المشكلة'
                          : 'Please describe the problem';
                    }
                    if (v.trim().length < 10) {
                      return isRtl
                          ? 'يرجى إدخال وصف أكثر تفصيلاً (10 أحرف على الأقل)'
                          : 'Please provide more detail (min 10 characters)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Image picker
                Text(
                  isRtl ? 'إرفاق صورة (اختياري)' : 'Attach Screenshot (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 8),

                if (_pickedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(_pickedImage!.path,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Image.file(File(_pickedImage!.path),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(isRtl ? 'تغيير الصورة' : 'Change Image'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(
                            color: Colors.grey[300]!, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            isRtl ? 'أضف صورة توضيحية' : 'Add a screenshot',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isRtl ? 'إرسال التقرير' : 'Submit Report',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
