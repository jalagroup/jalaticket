import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jalasupport/complaint_service.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/tickets.dart';

class ComplaintCheckDialog extends StatefulWidget {
  final ComplaintTicketModel complaint;
  final UserModel currentUser;
  final VoidCallback onCheckSubmitted;

  const ComplaintCheckDialog({
    super.key,
    required this.complaint,
    required this.currentUser,
    required this.onCheckSubmitted,
  });

  @override
  State<ComplaintCheckDialog> createState() => _ComplaintCheckDialogState();
}

class _ComplaintCheckDialogState extends State<ComplaintCheckDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();
  final _therapeuticProcedureController = TextEditingController();

  bool _complaintCheck = true;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitCheck() async {
    final l10n = AppLocalizations.safeOf(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Submit check
      final checkId = await ComplaintService.submitComplaintCheck(
        complaintId: widget.complaint.id,
        complaintCheck: _complaintCheck,
        checkerId: widget.currentUser.id,
        checkerName: widget.currentUser.fullName,
        report: _reportController.text.trim(),
        therapeuticProcedure:
            _therapeuticProcedureController.text.trim().isEmpty
                ? null
                : _therapeuticProcedureController.text.trim(),
      );

      if (checkId == null) {
        throw Exception('Failed to submit check');
      }

      // Upload check images
      for (final file in _selectedFiles) {
        if (file.bytes != null) {
          await ComplaintService.uploadComplaintAttachment(
            complaintId: widget.complaint.id,
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'image/${file.extension}',
            attachmentType: 'check',
            uploadedBy: widget.currentUser.id,
          );
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onCheckSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkSubmittedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorSubmittingCheck}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return OptimizedDialog(
      title: l10n.complaintCheck,
      width: MediaQuery.of(context).size.width * 0.7,
      contentPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: ComplaintCheckContent(
            reportController: _reportController,
            therapeuticProcedureController: _therapeuticProcedureController,
            complaintCheck: _complaintCheck,
            selectedFiles: _selectedFiles,
            currentUser: widget.currentUser,
            onComplaintCheckChanged: (value) {
              setState(() => _complaintCheck = value);
            },
            onPickFiles: _pickFiles,
            onRemoveFile: _removeFile,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            l10n.cancel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitCheck,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.submitCheck,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reportController.dispose();
    _therapeuticProcedureController.dispose();
    super.dispose();
  }
}

class ComplaintCheckScreen extends StatefulWidget {
  final ComplaintTicketModel complaint;
  final UserModel currentUser;
  final VoidCallback onCheckSubmitted;

  const ComplaintCheckScreen({
    super.key,
    required this.complaint,
    required this.currentUser,
    required this.onCheckSubmitted,
  });

  @override
  State<ComplaintCheckScreen> createState() => _ComplaintCheckScreenState();
}

class _ComplaintCheckScreenState extends State<ComplaintCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();
  final _therapeuticProcedureController = TextEditingController();

  bool _complaintCheck = true;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitCheck() async {
    final l10n = AppLocalizations.safeOf(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Submit check
      final checkId = await ComplaintService.submitComplaintCheck(
        complaintId: widget.complaint.id,
        complaintCheck: _complaintCheck,
        checkerId: widget.currentUser.id,
        checkerName: widget.currentUser.fullName,
        report: _reportController.text.trim(),
        therapeuticProcedure:
            _therapeuticProcedureController.text.trim().isEmpty
                ? null
                : _therapeuticProcedureController.text.trim(),
      );

      if (checkId == null) {
        throw Exception('Failed to submit check');
      }

      // Upload check images
      for (final file in _selectedFiles) {
        if (file.bytes != null) {
          await ComplaintService.uploadComplaintAttachment(
            complaintId: widget.complaint.id,
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'image/${file.extension}',
            attachmentType: 'check',
            uploadedBy: widget.currentUser.id,
          );
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onCheckSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkSubmittedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorSubmittingCheck}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.complaintCheck,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.complaint.complaintNumber,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ComplaintCheckContent(
                  reportController: _reportController,
                  therapeuticProcedureController:
                      _therapeuticProcedureController,
                  complaintCheck: _complaintCheck,
                  selectedFiles: _selectedFiles,
                  currentUser: widget.currentUser,
                  onComplaintCheckChanged: (value) {
                    setState(() => _complaintCheck = value);
                  },
                  onPickFiles: _pickFiles,
                  onRemoveFile: _removeFile,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitCheck,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.submitCheck,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reportController.dispose();
    _therapeuticProcedureController.dispose();
    super.dispose();
  }
}

// Reusable content widget for both dialog and screen
class ComplaintCheckContent extends StatelessWidget {
  final TextEditingController reportController;
  final TextEditingController therapeuticProcedureController;
  final bool complaintCheck;
  final List<PlatformFile> selectedFiles;
  final UserModel currentUser;
  final Function(bool) onComplaintCheckChanged;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const ComplaintCheckContent({
    Key? key,
    required this.reportController,
    required this.therapeuticProcedureController,
    required this.complaintCheck,
    required this.selectedFiles,
    required this.currentUser,
    required this.onComplaintCheckChanged,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    const primaryColor = Color(0xFFF16936);

    InputDecoration styledField(String label, {String? hint, IconData? icon, int? maxLines}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: icon != null
            ? Icon(icon, color: primaryColor, size: 18)
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checker (read-only)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.blue[600], size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.checker}:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  Text(
                    currentUser.fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Complaint Check
        Text(
          '${l10n.complaintCheck} *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    l10n.yes,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: complaintCheck ? Colors.green[700] : Colors.grey.shade600,
                    ),
                  ),
                  value: true,
                  groupValue: complaintCheck,
                  onChanged: (value) {
                    if (value != null) onComplaintCheckChanged(value);
                  },
                  activeColor: Colors.green,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade300),
              Expanded(
                child: RadioListTile<bool>(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    l10n.no,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: !complaintCheck ? Colors.red[700] : Colors.grey.shade600,
                    ),
                  ),
                  value: false,
                  groupValue: complaintCheck,
                  onChanged: (value) {
                    if (value != null) onComplaintCheckChanged(value);
                  },
                  activeColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Report
        TextFormField(
          controller: reportController,
          decoration: styledField(
            '${l10n.report} *',
            hint: l10n.enterDetailedCheckReport,
            icon: Icons.description_outlined,
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterReport;
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        // Therapeutic Procedure
        TextFormField(
          controller: therapeuticProcedureController,
          decoration: styledField(
            l10n.therapeuticProcedure,
            hint: l10n.enterTherapeuticProcedureIfApplicable,
            icon: Icons.medical_services_outlined,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 10),

        // Attachments
        Text(
          l10n.addImagesOptional,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),

        if (selectedFiles.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedFiles.length,
              itemBuilder: (context, index) {
                final file = selectedFiles[index];
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image,
                                size: 30, color: Colors.grey[600]),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                file.name,
                                style: const TextStyle(fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => onRemoveFile(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        OutlinedButton.icon(
          onPressed: onPickFiles,
          icon: const Icon(Icons.add_photo_alternate, size: 18),
          label: Text(l10n.addImages, style: const TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 10),

        // Info box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.afterSubmission,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.afterSubmissionInfo,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
