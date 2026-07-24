import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/searchable_dropdown.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/tickets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import '../main.dart';
import '../branch_admin_service.dart' hide supabase;

class IndividualsMaintenanceTicketDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;
  const IndividualsMaintenanceTicketDialog({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });
  @override
  State<IndividualsMaintenanceTicketDialog> createState() =>
      _IndividualsMaintenanceTicketDialogState();
}

class _IndividualsMaintenanceTicketDialogState
    extends State<IndividualsMaintenanceTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _customModelController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;
  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomProblem = false;
  bool _useCustomModel = false;
  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      List<DepartmentModel> departments = departmentsResponse
          .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
          .toList();

      departments = await filterDeptsByPlaceId(
          departments, widget.currentUser.placeId, widget.currentUser.departmentId);

      setState(() {
        _departments = departments;
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');
      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
        _selectedProblemTitleId = null;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];
    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null ||
        _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        'nature_of_work_id': _selectedNatureOfWorkId,
        'other_place': 'Other',
        'location': _locationController.text.isNotEmpty
            ? _locationController.text.trim()
            : null,
        // Problem title is optional; falls back to the main title when left blank
        'problem_title_id': (_problemTitles.isNotEmpty && !_useCustomProblem) ? _selectedProblemTitleId : null,
        'other_problem_title': _problemTitles.isEmpty
            ? (_customProblemController.text.trim().isEmpty
                ? _titleController.text.trim()
                : _customProblemController.text.trim())
            : (_useCustomProblem
                ? (_customProblemController.text.trim().isEmpty
                    ? _titleController.text.trim()
                    : _customProblemController.text.trim())
                : (_selectedProblemTitleId == null
                    ? _titleController.text.trim()
                    : null)),
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'model_number_id': _useCustomModel ? null : _selectedModelNumberId,
        'other_model_number':
            _useCustomModel ? _customModelController.text.trim() : null,
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.individualsMaintenanceTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    return OptimizedDialog(
      title: l10n.individualsMaintenanceTicket,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.7,
      contentPadding: const EdgeInsets.all(16),
      child: IndividualsMaintenanceTicketContent(
        titleController: _titleController,
        descriptionController: _descriptionController,
        locationController: _locationController,
        highPriorityController: _highPriorityController,
        phoneController: _phoneController,
        customProblemController: _customProblemController,
        customModelController: _customModelController,
        selectedDepartmentId: _selectedDepartmentId,
        selectedNatureOfWorkId: _selectedNatureOfWorkId,
        selectedProblemTitleId: _selectedProblemTitleId,
        selectedModelNumberId: _selectedModelNumberId,
        selectedPriority: _selectedPriority,
        departments: _departments,
        natureOfWorkList: _natureOfWorkList,
        problemTitles: _problemTitles,
        parts: _parts,
        selectedFiles: _selectedFiles,
        useCustomProblem: _useCustomProblem,
        useCustomModel: _useCustomModel,
        onDepartmentChanged: (value) {
          setState(() {
            _selectedDepartmentId = value;
            _selectedNatureOfWorkId = null;
            _selectedProblemTitleId = null;
            _selectedModelNumberId = null;
            _natureOfWorkList.clear();
            _problemTitles.clear();
            _parts.clear();
          });
          if (value != null) {
            _loadNatureOfWorkForDepartment(value);
            _loadProblemTitles(value);
            _loadParts(value);
          }
        },
        onNatureOfWorkChanged: (value) {
          setState(() => _selectedNatureOfWorkId = value);
        },
        onProblemTitleChanged: (value) {
          setState(() => _selectedProblemTitleId = value);
        },
        onModelNumberChanged: (value) {
          setState(() => _selectedModelNumberId = value);
        },
        onPriorityChanged: (value) {
          setState(() => _selectedPriority = value);
        },
        onUseCustomProblemChanged: (value) {
          setState(() {
            _useCustomProblem = value;
            if (_useCustomProblem) {
              _selectedProblemTitleId = null;
            } else {
              _customProblemController.clear();
            }
          });
        },
        onUseCustomModelChanged: (value) {
          setState(() {
            _useCustomModel = value;
            if (_useCustomModel) {
              _selectedModelNumberId = null;
            } else {
              _customModelController.clear();
            }
          });
        },
        onPickImages: _pickImages,
        onPickFiles: _pickFiles,
        onRemoveFile: _removeFile,
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
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
          onPressed: (_isLoading || _isUploadingFiles) ? null : _createTicket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createTicket,
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
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customProblemController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}

class ITSolutionTicketDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const ITSolutionTicketDialog({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<ITSolutionTicketDialog> createState() => _ITSolutionTicketDialogState();
}

class _ITSolutionTicketDialogState extends State<ITSolutionTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();

  PriorityType _selectedPriority = PriorityType.medium;
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;

  String? _itDepartmentId = '6c9672fb-fce3-4118-a460-cee9e9c6e874';

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    if (_itDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _itDepartmentId,
        'other_nature_of_work': 'Other',
        'other_place': 'Other',
        'location': null,
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'other_model_number': 'Other',
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.itSolutionTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return OptimizedDialog(
      title: l10n.itSolutionTicket,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.5,
      contentPadding: const EdgeInsets.all(16),
      child: ITSolutionTicketDialogContent(
        titleController: _titleController,
        descriptionController: _descriptionController,
        highPriorityController: _highPriorityController,
        phoneController: _phoneController,
        selectedPriority: _selectedPriority,
        selectedFiles: _selectedFiles,
        onPriorityChanged: (value) {
          setState(() => _selectedPriority = value);
        },
        onPickImages: _pickImages,
        onPickFiles: _pickFiles,
        onRemoveFile: _removeFile,
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
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
          onPressed: (_isLoading || _isUploadingFiles) ? null : _createTicket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createTicket,
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
    _titleController.dispose();
    _descriptionController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class PlacesMaintenanceTicketDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;
  const PlacesMaintenanceTicketDialog({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });
  @override
  State<PlacesMaintenanceTicketDialog> createState() =>
      _PlacesMaintenanceTicketDialogState();
}

class _PlacesMaintenanceTicketDialogState
    extends State<PlacesMaintenanceTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _customModelController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedPlaceId;
  String? _selectedNatureOfWorkId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;
  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomProblem = false;
  bool _useCustomModel = false;
  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    if (widget.currentUser.userType == UserType.user ||
        widget.currentUser.userType == UserType.superUser) {
      _selectedPlaceId = widget.currentUser.placeId;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      List<DepartmentModel> departments = departmentsResponse
          .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
          .toList();

      List<PlaceModel> places;
      if (widget.currentUser.userType == UserType.branchAdmin) {
        places = await BranchAdminService.getBranchAdminPlaces(widget.currentUser.id);
      } else {
        final placesResponse = await supabase.from('places').select();
        places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      }

      departments = await filterDeptsByPlaceId(
          departments, widget.currentUser.placeId, widget.currentUser.departmentId);

      setState(() {
        _departments = departments;
        _places = places;
        if (widget.currentUser.userType == UserType.branchAdmin &&
            places.length == 1) {
          _selectedPlaceId = places.first.id;
        }
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');
      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
        _selectedProblemTitleId = null;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];
    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.title}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${l10n.pleaseFillAllRequired} - ${l10n.targetDepartment}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Nature of Work validation - only if list is NOT empty
    if (_natureOfWorkList.isNotEmpty && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.natureOfWork}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.place}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate high priority explanation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseExplainHighPriority),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate phone number
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        // AUTO-SET: If nature of work list is empty, send "Other", otherwise send selected
        'nature_of_work_id':
            _natureOfWorkList.isNotEmpty ? _selectedNatureOfWorkId : null,
        'other_nature_of_work': _natureOfWorkList.isEmpty ? 'Other' : null,
        'place_id': _selectedPlaceId,
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        // Problem title is optional; falls back to the main title when left blank
        'problem_title_id': (_problemTitles.isNotEmpty && !_useCustomProblem) ? _selectedProblemTitleId : null,
        'other_problem_title': _problemTitles.isEmpty
            ? (_customProblemController.text.trim().isEmpty
                ? _titleController.text.trim()
                : _customProblemController.text.trim())
            : (_useCustomProblem
                ? (_customProblemController.text.trim().isEmpty
                    ? _titleController.text.trim()
                    : _customProblemController.text.trim())
                : (_selectedProblemTitleId == null
                    ? _titleController.text.trim()
                    : null)),
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        // AUTO-SET: If parts list is empty, send "Other", otherwise send selected/custom
        'model_number_id': (_parts.isNotEmpty && !_useCustomModel)
            ? _selectedModelNumberId
            : null,
        'other_model_number': _parts.isEmpty
            ? 'Other'
            : (_useCustomModel ? _customModelController.text.trim() : null),
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('📋 Creating place ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final successMessage =
            '${l10n.placesMaintenanceTicket} #$ticketNumber ${l10n.ticketCreatedSuccessfully}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating place ticket: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _canSelectPlace() {
    return widget.currentUser.userType == UserType.admin ||
        widget.currentUser.userType == UserType.superAdmin ||
        widget.currentUser.userType == UserType.systemAdmin ||
        widget.currentUser.userType == UserType.branchAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    return OptimizedDialog(
      title: l10n.placesMaintenanceTicket,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.7,
      contentPadding: const EdgeInsets.all(16),
      child: PlacesMaintenanceTicketContent(
        titleController: _titleController,
        descriptionController: _descriptionController,
        locationController: _locationController,
        highPriorityController: _highPriorityController,
        phoneController: _phoneController,
        customProblemController: _customProblemController,
        customModelController: _customModelController,
        selectedDepartmentId: _selectedDepartmentId,
        selectedPlaceId: _selectedPlaceId,
        selectedNatureOfWorkId: _selectedNatureOfWorkId,
        selectedProblemTitleId: _selectedProblemTitleId,
        selectedModelNumberId: _selectedModelNumberId,
        selectedPriority: _selectedPriority,
        departments: _departments,
        places: _places,
        natureOfWorkList: _natureOfWorkList,
        problemTitles: _problemTitles,
        parts: _parts,
        selectedFiles: _selectedFiles,
        useCustomProblem: _useCustomProblem,
        useCustomModel: _useCustomModel,
        canSelectPlace: _canSelectPlace(),
        onDepartmentChanged: (value) {
          setState(() {
            _selectedDepartmentId = value;
            _selectedNatureOfWorkId = null;
            _selectedProblemTitleId = null;
            _selectedModelNumberId = null;
            _natureOfWorkList.clear();
            _problemTitles.clear();
            _parts.clear();
          });
          if (value != null) {
            _loadNatureOfWorkForDepartment(value);
            _loadProblemTitles(value);
            _loadParts(value);
          }
        },
        onPlaceChanged: (value) {
          setState(() => _selectedPlaceId = value);
        },
        onNatureOfWorkChanged: (value) {
          setState(() => _selectedNatureOfWorkId = value);
        },
        onProblemTitleChanged: (value) {
          setState(() => _selectedProblemTitleId = value);
        },
        onModelNumberChanged: (value) {
          setState(() => _selectedModelNumberId = value);
        },
        onPriorityChanged: (value) {
          setState(() => _selectedPriority = value);
        },
        onUseCustomProblemChanged: (value) {
          setState(() {
            _useCustomProblem = value;
            if (_useCustomProblem) {
              _selectedProblemTitleId = null;
            } else {
              _customProblemController.clear();
            }
          });
        },
        onUseCustomModelChanged: (value) {
          setState(() {
            _useCustomModel = value;
            if (_useCustomModel) {
              _selectedModelNumberId = null;
            } else {
              _customModelController.clear();
            }
          });
        },
        onPickImages: _pickImages,
        onPickFiles: _pickFiles,
        onRemoveFile: _removeFile,
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
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
          onPressed: (_isLoading || _isUploadingFiles) ? null : _createTicket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createTicket,
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
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customProblemController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}

class RequestsTicketDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;
  const RequestsTicketDialog({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });
  @override
  State<RequestsTicketDialog> createState() => _RequestsTicketDialogState();
}

class _RequestsTicketDialogState extends State<RequestsTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customModelController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;
  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _parts = [];
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomModel = false;
  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      List<DepartmentModel> departments = departmentsResponse
          .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
          .toList();
      departments = await filterDeptsByPlaceId(
          departments, widget.currentUser.placeId, widget.currentUser.departmentId);
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');
      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];
    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic required fields validation
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    // Nature of work validation - only if list is not empty
    if (_natureOfWorkList.isNotEmpty && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    // High priority explanation validation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    // Phone number validation
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,

        // Nature of Work - auto-set "Other" if list empty
        'nature_of_work_id':
            _natureOfWorkList.isNotEmpty ? _selectedNatureOfWorkId : null,
        'other_nature_of_work': _natureOfWorkList.isEmpty ? 'Other' : null,

        'other_place': 'Other',
        'location': _locationController.text.isNotEmpty
            ? _locationController.text.trim()
            : null,
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,

        // Model Number - auto-set "Other" if list empty
        'model_number_id': (_parts.isNotEmpty && !_useCustomModel)
            ? _selectedModelNumberId
            : null,
        'other_model_number': _parts.isEmpty
            ? 'Other'
            : (_useCustomModel ? _customModelController.text.trim() : null),

        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('Creating request ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final successMessage = l10n.requestsTicketCreatedSuccessfully;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket} $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    return OptimizedDialog(
      title: l10n.requestsTicket,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.7,
      contentPadding: const EdgeInsets.all(16),
      child: RequestsTicketContent(
        titleController: _titleController,
        descriptionController: _descriptionController,
        locationController: _locationController,
        highPriorityController: _highPriorityController,
        phoneController: _phoneController,
        customModelController: _customModelController,
        selectedDepartmentId: _selectedDepartmentId,
        selectedNatureOfWorkId: _selectedNatureOfWorkId,
        selectedModelNumberId: _selectedModelNumberId,
        selectedPriority: _selectedPriority,
        departments: _departments,
        natureOfWorkList: _natureOfWorkList,
        parts: _parts,
        selectedFiles: _selectedFiles,
        useCustomModel: _useCustomModel,
        onDepartmentChanged: (value) {
          setState(() {
            _selectedDepartmentId = value;
            _selectedNatureOfWorkId = null;
            _selectedModelNumberId = null;
            _natureOfWorkList.clear();
            _parts.clear();
          });
          if (value != null) {
            _loadNatureOfWorkForDepartment(value);
            _loadParts(value);
          }
        },
        onNatureOfWorkChanged: (value) {
          setState(() => _selectedNatureOfWorkId = value);
        },
        onModelNumberChanged: (value) {
          setState(() => _selectedModelNumberId = value);
        },
        onPriorityChanged: (value) {
          setState(() => _selectedPriority = value);
        },
        onUseCustomModelChanged: (value) {
          setState(() {
            _useCustomModel = value;
            if (_useCustomModel) {
              _selectedModelNumberId = null;
            } else {
              _customModelController.clear();
            }
          });
        },
        onPickImages: _pickImages,
        onPickFiles: _pickFiles,
        onRemoveFile: _removeFile,
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
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
          onPressed: (_isLoading || _isUploadingFiles) ? null : _createTicket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createRequest,
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
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}
