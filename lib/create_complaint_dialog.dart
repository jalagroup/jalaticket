import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jalasupport/complaint_service.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/tickets.dart';

class CreateComplaintDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onComplaintCreated;

  const CreateComplaintDialog({
    super.key,
    required this.currentUser,
    required this.onComplaintCreated,
  });

  @override
  State<CreateComplaintDialog> createState() => _CreateComplaintDialogState();
}

class _CreateComplaintDialogState extends State<CreateComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complainantNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _mobileController = TextEditingController();
  final _phoneController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedItemId;
  DateTime? _produceDate;
  DateTime? _expiredDate;
  ComplaintType _complaintType = ComplaintType.technical;
  List<ComplaintItemModel> _items = [];
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    try {
      final items = await ComplaintService.getComplaintItems();
      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      setState(() => _loadingItems = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.error}: $e')),
        );
      }
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context, bool isProduceDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isProduceDate) {
          _produceDate = picked;
        } else {
          _expiredDate = picked;
        }
      });
    }
  }

  Future<void> _submitComplaint() async {
    final l10n = AppLocalizations.safeOf(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectItem)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final complaintData = {
        'complaint_receiver': widget.currentUser.fullName,
        'complainant_name': _complainantNameController.text.trim(),
        'location': _locationController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'phone_number': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'item_id': _selectedItemId,
        'batch_number': _batchNumberController.text.trim().isEmpty
            ? null
            : _batchNumberController.text.trim(),
        'quantity': _quantityController.text.trim().isEmpty
            ? null
            : double.parse(_quantityController.text.trim()),
        'produce_date': _produceDate?.toIso8601String(),
        'expired_date': _expiredDate?.toIso8601String(),
        'description': _descriptionController.text.trim(),
        'complaint_type': _complaintType.value,
        'created_by': widget.currentUser.id,
      };

      final complaintId =
          await ComplaintService.createComplaintTicket(complaintData);

      if (complaintId == null) {
        throw Exception('Failed to create complaint');
      }

      // Upload attachments
      for (final file in _selectedFiles) {
        if (file.bytes != null) {
          await ComplaintService.uploadComplaintAttachment(
            complaintId: complaintId,
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'image/${file.extension}',
            attachmentType: 'initial',
            uploadedBy: widget.currentUser.id,
          );
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onComplaintCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.complaintCreatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorCreatingComplaint}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return OptimizedDialog(
      title: l10n.createQualityComplaint,
      width: MediaQuery.of(context).size.width * 0.7,
      contentPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: CreateComplaintContent(
            complainantNameController: _complainantNameController,
            locationController: _locationController,
            mobileController: _mobileController,
            phoneController: _phoneController,
            batchNumberController: _batchNumberController,
            quantityController: _quantityController,
            descriptionController: _descriptionController,
            selectedItemId: _selectedItemId,
            produceDate: _produceDate,
            expiredDate: _expiredDate,
            complaintType: _complaintType,
            items: _items,
            selectedFiles: _selectedFiles,
            loadingItems: _loadingItems,
            currentUser: widget.currentUser,
            onItemChanged: (value) {
              setState(() => _selectedItemId = value);
            },
            onComplaintTypeChanged: (value) {
              setState(() => _complaintType = value);
            },
            onSelectProduceDate: () => _selectDate(context, true),
            onSelectExpiredDate: () => _selectDate(context, false),
            onPickFiles: _pickFiles,
            onRemoveFile: _removeFile,
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            l10n.cancel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitComplaint,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: const Color(0xFFf16936),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.submitComplaint,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _complainantNameController.dispose();
    _locationController.dispose();
    _mobileController.dispose();
    _phoneController.dispose();
    _batchNumberController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Helper function to check if should use full screen
bool _shouldUseFullScreen(BuildContext context) {
  return MediaQuery.of(context).size.width < 1200; // Desktop threshold
}

// Public function to show complaint creation
void showCreateComplaintDialog(BuildContext context, UserModel currentUser,
    VoidCallback onComplaintCreated) {
  if (_shouldUseFullScreen(context)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateComplaintScreen(
          currentUser: currentUser,
          onComplaintCreated: onComplaintCreated,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => CreateComplaintDialog(
        currentUser: currentUser,
        onComplaintCreated: onComplaintCreated,
      ),
    );
  }
}

class CreateComplaintScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onComplaintCreated;

  const CreateComplaintScreen({
    super.key,
    required this.currentUser,
    required this.onComplaintCreated,
  });

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complainantNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _mobileController = TextEditingController();
  final _phoneController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedItemId;
  DateTime? _produceDate;
  DateTime? _expiredDate;
  ComplaintType _complaintType = ComplaintType.technical;
  List<ComplaintItemModel> _items = [];
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    try {
      final items = await ComplaintService.getComplaintItems();
      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      setState(() => _loadingItems = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.error}: $e')),
        );
      }
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context, bool isProduceDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isProduceDate) {
          _produceDate = picked;
        } else {
          _expiredDate = picked;
        }
      });
    }
  }

  Future<void> _submitComplaint() async {
    final l10n = AppLocalizations.safeOf(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectItem)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final complaintData = {
        'complaint_receiver': widget.currentUser.fullName,
        'complainant_name': _complainantNameController.text.trim(),
        'location': _locationController.text.trim(),
        'mobile_number': _mobileController.text.trim(),
        'phone_number': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'item_id': _selectedItemId,
        'batch_number': _batchNumberController.text.trim().isEmpty
            ? null
            : _batchNumberController.text.trim(),
        'quantity': _quantityController.text.trim().isEmpty
            ? null
            : double.parse(_quantityController.text.trim()),
        'produce_date': _produceDate?.toIso8601String(),
        'expired_date': _expiredDate?.toIso8601String(),
        'description': _descriptionController.text.trim(),
        'complaint_type': _complaintType.value,
        'created_by': widget.currentUser.id,
      };

      final complaintId =
          await ComplaintService.createComplaintTicket(complaintData);

      if (complaintId == null) {
        throw Exception('Failed to create complaint');
      }

      // Upload attachments
      for (final file in _selectedFiles) {
        if (file.bytes != null) {
          await ComplaintService.uploadComplaintAttachment(
            complaintId: complaintId,
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'image/${file.extension}',
            attachmentType: 'initial',
            uploadedBy: widget.currentUser.id,
          );
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onComplaintCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.complaintCreatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorCreatingComplaint}: $e')),
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
        title: Text(
          l10n.createQualityComplaint,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: CreateComplaintContent(
                  complainantNameController: _complainantNameController,
                  locationController: _locationController,
                  mobileController: _mobileController,
                  phoneController: _phoneController,
                  batchNumberController: _batchNumberController,
                  quantityController: _quantityController,
                  descriptionController: _descriptionController,
                  selectedItemId: _selectedItemId,
                  produceDate: _produceDate,
                  expiredDate: _expiredDate,
                  complaintType: _complaintType,
                  items: _items,
                  selectedFiles: _selectedFiles,
                  loadingItems: _loadingItems,
                  currentUser: widget.currentUser,
                  onItemChanged: (value) {
                    setState(() => _selectedItemId = value);
                  },
                  onComplaintTypeChanged: (value) {
                    setState(() => _complaintType = value);
                  },
                  onSelectProduceDate: () => _selectDate(context, true),
                  onSelectExpiredDate: () => _selectDate(context, false),
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
                    onPressed: _isLoading ? null : _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
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
                                l10n.submitComplaint,
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
    _complainantNameController.dispose();
    _locationController.dispose();
    _mobileController.dispose();
    _phoneController.dispose();
    _batchNumberController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Reusable content widget for both dialog and screen
class CreateComplaintContent extends StatelessWidget {
  final TextEditingController complainantNameController;
  final TextEditingController locationController;
  final TextEditingController mobileController;
  final TextEditingController phoneController;
  final TextEditingController batchNumberController;
  final TextEditingController quantityController;
  final TextEditingController descriptionController;
  final String? selectedItemId;
  final DateTime? produceDate;
  final DateTime? expiredDate;
  final ComplaintType complaintType;
  final List<ComplaintItemModel> items;
  final List<PlatformFile> selectedFiles;
  final bool loadingItems;
  final UserModel currentUser;
  final Function(String?) onItemChanged;
  final Function(ComplaintType) onComplaintTypeChanged;
  final VoidCallback onSelectProduceDate;
  final VoidCallback onSelectExpiredDate;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const CreateComplaintContent({
    Key? key,
    required this.complainantNameController,
    required this.locationController,
    required this.mobileController,
    required this.phoneController,
    required this.batchNumberController,
    required this.quantityController,
    required this.descriptionController,
    required this.selectedItemId,
    required this.produceDate,
    required this.expiredDate,
    required this.complaintType,
    required this.items,
    required this.selectedFiles,
    required this.loadingItems,
    required this.currentUser,
    required this.onItemChanged,
    required this.onComplaintTypeChanged,
    required this.onSelectProduceDate,
    required this.onSelectExpiredDate,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    const primaryColor = Color(0xFFf16936);
    const secondaryColor = Color(0xFF135467);

    InputDecoration styledField(String label, IconData icon, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
    }

    Widget sectionHeader(String text) {
      return Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.complaintForm,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.date}: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      '${l10n.receiverName}: ${currentUser.fullName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Complainant Information
        sectionHeader(l10n.complainantInformation),
        const SizedBox(height: 10),

        TextFormField(
          controller: complainantNameController,
          decoration: styledField('${l10n.complainantsName} *', Icons.person),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterComplainantName;
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: locationController,
          decoration: styledField('${l10n.location} *', Icons.location_on),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterLocation;
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: mobileController,
          decoration: styledField('${l10n.mobileNumber} *', Icons.phone_android),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterMobile;
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: phoneController,
          decoration: styledField(l10n.phoneNumberOptional, Icons.phone),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        // Product Information
        sectionHeader(l10n.productInformation),
        const SizedBox(height: 10),

        if (loadingItems)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: selectedItemId,
            decoration: styledField('${l10n.item} *', Icons.inventory),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item.id,
                child: Text(item.localizedName(lang)),
              );
            }).toList(),
            onChanged: onItemChanged,
            validator: (value) {
              if (value == null) return l10n.pleaseSelectItem;
              return null;
            },
          ),
        const SizedBox(height: 10),

        TextFormField(
          controller: batchNumberController,
          decoration: styledField(l10n.batchNumberOptional, Icons.numbers),
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: quantityController,
          decoration: styledField(l10n.quantityOptional, Icons.production_quantity_limits),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
        ),
        const SizedBox(height: 10),

        // Produce Date
        InkWell(
          onTap: onSelectProduceDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: styledField(l10n.produceDate, Icons.calendar_today),
            child: Text(
              produceDate != null
                  ? DateFormat('dd/MM/yyyy').format(produceDate!)
                  : l10n.selectProduceDate,
              style: TextStyle(
                color: produceDate != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Expired Date
        InkWell(
          onTap: onSelectExpiredDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: styledField(l10n.expiredDate, Icons.event_busy),
            child: Text(
              expiredDate != null
                  ? DateFormat('dd/MM/yyyy').format(expiredDate!)
                  : l10n.selectExpiredDate,
              style: TextStyle(
                color: expiredDate != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Complaint Details
        sectionHeader(l10n.complaintDetails),
        const SizedBox(height: 10),

        TextFormField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: '${l10n.description} *',
            hintText: l10n.describeIssueDetail,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterDescription;
            }
            return null;
          },
        ),
        const SizedBox(height: 10),

        // Complaint Type
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '${l10n.complaintType} *',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: secondaryColor,
                  ),
                ),
              ),
              ...ComplaintType.values.map((type) {
                return RadioListTile<ComplaintType>(
                  title: Text(
                    type == ComplaintType.technical
                        ? l10n.technical
                        : l10n.coordinationDelivery,
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: type,
                  groupValue: complaintType,
                  activeColor: primaryColor,
                  dense: true,
                  onChanged: (value) {
                    if (value != null) onComplaintTypeChanged(value);
                  },
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Attachments
        sectionHeader(l10n.attachments),
        const SizedBox(height: 10),

        if (selectedFiles.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedFiles.length,
              itemBuilder: (context, index) {
                final file = selectedFiles[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 36, color: Colors.grey[500]),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                file.name,
                                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        OutlinedButton.icon(
          onPressed: onPickFiles,
          icon: const Icon(Icons.add_photo_alternate, size: 20),
          label: Text(l10n.addImages),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
