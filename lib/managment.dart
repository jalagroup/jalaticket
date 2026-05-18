import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:jalasupport/activity.dart';
import 'package:jalasupport/ai_dashboard_screen.dart';
import 'package:jalasupport/ai_insights.dart';
import 'package:jalasupport/branch_admin_management_screen.dart';
import 'package:jalasupport/problem_reports_admin_screen.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/services.dart';

class CreateUserDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onUserCreated;

  const CreateUserDialog({
    super.key,
    required this.currentUser,
    required this.onUserCreated,
  });

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserType _selectedUserType = UserType.user;
  String? _selectedDepartmentId;
  String? _selectedPlaceId;
  List<String> _natureOfWork = [];

  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setDefaultUserType();
  }

  void _setDefaultUserType() {
    if (widget.currentUser.userType == UserType.systemAdmin) {
      _selectedUserType = UserType.superAdmin;
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      _selectedUserType = UserType.admin;
    } else if (widget.currentUser.userType == UserType.superUser) {
      _selectedUserType = UserType.user;
      _selectedPlaceId = widget.currentUser.placeId;
    }
  }

  List<UserType> _getAvailableUserTypes() {
    if (widget.currentUser.userType == UserType.systemAdmin) {
      return [UserType.superAdmin, UserType.superUser, UserType.branchAdmin];
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      return [UserType.admin];
    } else if (widget.currentUser.userType == UserType.superUser) {
      return [UserType.user];
    }
    return [];
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      final placesResponse = await supabase.from('places').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
        _places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

// Replace the _createUser() method in CreateUserDialog with this version:

// REPLACE the entire _createUser method in _CreateUserDialogState class

// REPLACE the entire _createUser method in _CreateUserDialogState class
  Future<void> _createUser() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if ((_selectedUserType == UserType.superAdmin ||
            _selectedUserType == UserType.admin) &&
        _selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectDepartmentForAdminUsers)),
      );
      return;
    }

    if (_selectedUserType == UserType.superUser && _selectedPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectPlaceForSuperUsers)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Prepare user data
      final userData = {
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'user_type': _selectedUserType.value,
        'department_id': _selectedDepartmentId,
        'place_id': _selectedPlaceId,
        'nature_of_work': _natureOfWork.isEmpty ? null : _natureOfWork,
        'is_active': true,
        'language': 'en',
      };

      print('📞 Calling Edge Function to create user...');

      // ✅ Call Edge Function with proper authorization
      final response = await supabase.functions.invoke(
        'create-user-admin',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'userData': userData,
        },
        headers: {
          'Authorization':
              'Bearer ${supabase.auth.currentSession?.accessToken}',
        },
      );

      print('📥 Edge Function response: ${response.data}');

      if (response.data != null && response.data['success'] == true) {
        setState(() => _isLoading = false);

        if (mounted) {
          Navigator.pop(context);
          widget.onUserCreated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(l10n.userCreatedSuccessfully),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception(response.data?['message'] ?? 'Failed to create user');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Error creating user: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedToCreateUser}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;
    final availableUserTypes = _getAvailableUserTypes();

    if (availableUserTypes.isEmpty) {
      return AlertDialog(
        title: Text(l10n.accessRestricted),
        content: Text(l10n.noPermissionToCreateUsers),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      );
    }

    const primaryColor = Color(0xFFf16936);

    InputDecoration _field(String label, IconData icon, {bool enabled = true}) =>
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: enabled ? primaryColor : Colors.grey, size: 18),
          isDense: true,
          filled: true,
          fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: primaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 460,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clean flat header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_add_outlined, color: primaryColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.createNewUser, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _fullNameController,
                      decoration: _field('${l10n.fullName} *', Icons.person_outline),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      decoration: _field('${l10n.email} *', Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: _field(l10n.phone, Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      decoration: _field('${l10n.password} *', Icons.lock_outline),
                      obscureText: true,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserType>(
                      value: _selectedUserType,
                      isDense: true,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: _field('${l10n.userType} *', Icons.badge_outlined),
                      items: availableUserTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.value.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        _selectedUserType = value!;
                        _selectedDepartmentId = null;
                        _selectedPlaceId = null;
                        _natureOfWork.clear();
                      }),
                    ),
                    if (_selectedUserType == UserType.superAdmin || _selectedUserType == UserType.admin) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedDepartmentId,
                        isDense: true,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: _field('${l10n.department} *', Icons.business_outlined),
                        items: _departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.localizedName(lang), style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _selectedDepartmentId = v),
                      ),
                    ],
                    if (_selectedUserType == UserType.superUser &&
                        widget.currentUser.userType != UserType.superUser) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedPlaceId,
                        isDense: true,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: _field('${l10n.place} *', Icons.location_on_outlined),
                        items: _places.map((p) => DropdownMenuItem(value: p.id, child: Text(p.localizedName(lang), style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _selectedPlaceId = v),
                      ),
                    ],
                    if (_selectedUserType == UserType.user &&
                        widget.currentUser.userType == UserType.superUser &&
                        widget.currentUser.placeId != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _places.firstWhere(
                              (p) => p.id == widget.currentUser.placeId,
                              orElse: () => PlaceModel(
                                id: '', name: l10n.place, nameEn: l10n.place,
                                nameAr: l10n.place, isActive: true,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                                allowedDepartmentIds: [], allowedTicketTypes: [],
                              ),
                            ).localizedName(lang),
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          const Spacer(),
                          Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
                        ]),
                      ),
                    ],
                    if (_selectedUserType == UserType.admin) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${l10n.natureOfWork} (${l10n.optional})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_natureOfWork.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _natureOfWork.map((work) => Chip(
                                  label: Text(work, style: const TextStyle(fontSize: 12)),
                                  onDeleted: () => setState(() => _natureOfWork.remove(work)),
                                  backgroundColor: const Color(0xFFfff3e0),
                                  side: const BorderSide(color: Color(0xFFffcc80)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                )).toList(),
                              ),
                            TextField(
                              decoration: InputDecoration(
                                hintText: l10n.addNatureOfWorkAndPressEnter,
                                border: InputBorder.none,
                                isDense: true,
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              style: const TextStyle(fontSize: 13),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty && !_natureOfWork.contains(value.trim())) {
                                  setState(() => _natureOfWork.add(value.trim()));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    ),
                    child: Text(l10n.cancel, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.createUser, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Replace the existing UsersManagement class with this updated version:

// Add this EditUserDialog class after the CreateUserDialog

class EditUserDialog extends StatefulWidget {
  final UserModel currentUser;
  final UserModel userToEdit;
  final VoidCallback onUserUpdated;

  const EditUserDialog({
    super.key,
    required this.currentUser,
    required this.userToEdit,
    required this.onUserUpdated,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  late UserType _selectedUserType;
  String? _selectedDepartmentId;
  String? _selectedPlaceId;

  List<String> _selectedNatureOfWorkIds = [];
  List<NatureOfWorkModel> _availableNatureOfWork = [];

  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedUserType = widget.userToEdit.userType;
    _initializeFields();
    _loadData();
    if (widget.userToEdit.userType == UserType.admin) {
      _loadAdminNatureOfWork();
    }
  }

  Future<void> _loadAdminNatureOfWork() async {
    if (widget.userToEdit.departmentId == null) return;

    try {
      // Load available nature of work for department
      final natureOfWorkResponse = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', widget.userToEdit.departmentId!)
          .eq('is_active', true)
          .order('name');

      _availableNatureOfWork = natureOfWorkResponse
          .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
          .toList();

      // Load admin's current nature of work
      final adminNatureResponse = await supabase
          .from('admin_nature_of_work')
          .select('nature_of_work_id')
          .eq('admin_id', widget.userToEdit.id);

      setState(() {
        _selectedNatureOfWorkIds = adminNatureResponse
            .map<String>((json) => json['nature_of_work_id'] as String)
            .toList();
      });
    } catch (e) {
      print('Error loading admin nature of work: $e');
    }
  }

  void _initializeFields() {
    _fullNameController.text = widget.userToEdit.fullName;
    _phoneController.text = widget.userToEdit.phone ?? '';
    _selectedDepartmentId = widget.userToEdit.departmentId;
    _selectedPlaceId = widget.userToEdit.placeId;
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      final placesResponse = await supabase.from('places').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
        _places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _updateUser() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillFullNameField)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'user_type': _selectedUserType.value,
        'department_id': (_selectedUserType == UserType.superAdmin ||
                _selectedUserType == UserType.admin)
            ? _selectedDepartmentId
            : null,
        'place_id': (_selectedUserType == UserType.superUser ||
                _selectedUserType == UserType.user)
            ? _selectedPlaceId
            : null,
      };

      await supabase
          .from('users')
          .update(updateData)
          .eq('id', widget.userToEdit.id);

      if (_selectedUserType == UserType.admin) {
        await supabase
            .from('admin_nature_of_work')
            .delete()
            .eq('admin_id', widget.userToEdit.id);

        if (_selectedNatureOfWorkIds.isNotEmpty) {
          final insertData = _selectedNatureOfWorkIds
              .map((nowId) => {
                    'admin_id': widget.userToEdit.id,
                    'nature_of_work_id': nowId,
                  })
              .toList();

          await supabase.from('admin_nature_of_work').insert(insertData);
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onUserUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToUpdateUser}: $e')),
        );
      }
      print('Error updating user: $e');
    }
  }

  Widget _buildNatureOfWorkSection() {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    if (_selectedUserType != UserType.admin) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.natureOfWorkExpertise,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _availableNatureOfWork.isEmpty
              ? Text(l10n.noNatureOfWorkAvailable, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _availableNatureOfWork.map((now) {
                    final isSelected = _selectedNatureOfWorkIds.contains(now.id);
                    return FilterChip(
                      label: Text(now.localizedName(lang), style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      selectedColor: const Color(0xFFfff3e0),
                      checkmarkColor: const Color(0xFFf16936),
                      side: BorderSide(color: isSelected ? const Color(0xFFffcc80) : Colors.grey.shade300),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedNatureOfWorkIds.add(now.id);
                          } else {
                            _selectedNatureOfWorkIds.remove(now.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.selectTypesOfWorkAdminSpecializesIn,
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }

  bool _canEditDepartment() {
    return widget.currentUser.userType == UserType.systemAdmin;
  }

  bool _canEditPlace() {
    return widget.currentUser.userType == UserType.systemAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    const primaryColor = Color(0xFFf16936);

    InputDecoration field(String label, IconData icon, {bool enabled = true}) =>
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: enabled ? primaryColor : Colors.grey[400], size: 18),
          isDense: true,
          filled: true,
          fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: primaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 460,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clean flat header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_outlined, color: primaryColor, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.editUser, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(widget.userToEdit.fullName, style: TextStyle(fontSize: 12, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _fullNameController,
                      decoration: field('${l10n.fullName} *', Icons.person_outline),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: field(l10n.phone, Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserType>(
                      value: _selectedUserType,
                      isDense: true,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: field(l10n.userType, Icons.badge_outlined,
                          enabled: widget.currentUser.userType == UserType.systemAdmin),
                      items: [
                        UserType.user,
                        UserType.superUser,
                        UserType.branchAdmin,
                        UserType.admin,
                        UserType.superAdmin,
                      ].map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.value.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      )).toList(),
                      onChanged: widget.currentUser.userType == UserType.systemAdmin
                          ? (v) => setState(() {
                                _selectedUserType = v!;
                                _selectedDepartmentId = null;
                                _selectedPlaceId = null;
                              })
                          : null,
                    ),
                    if (_selectedUserType == UserType.superAdmin ||
                        _selectedUserType == UserType.admin) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedDepartmentId,
                        isDense: true,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: field(l10n.department, Icons.business_outlined, enabled: _canEditDepartment()),
                        items: _departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.localizedName(lang), style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: _canEditDepartment() ? (v) => setState(() => _selectedDepartmentId = v) : null,
                      ),
                    ],
                    if (_selectedUserType == UserType.superUser ||
                        _selectedUserType == UserType.user) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedPlaceId,
                        isDense: true,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: field(l10n.place, Icons.location_on_outlined, enabled: _canEditPlace()),
                        items: _places.map((p) => DropdownMenuItem(value: p.id, child: Text(p.localizedName(lang), style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: _canEditPlace() ? (v) => setState(() => _selectedPlaceId = v) : null,
                      ),
                    ],
                    _buildNatureOfWorkSection(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    ),
                    child: Text(l10n.cancel, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.updateUser, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add to management.dart

// ============================================================================
// OPTIMIZED MANAGEMENT SCREEN WITH LAZY TAB LOADING
// ============================================================================
class ManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const ManagementScreen({super.key, required this.currentUser});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final Map<int, Widget> _cachedTabs = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cachedTabs.clear();
    super.dispose();
  }

  int _getTabCount() {
    switch (widget.currentUser.userType) {
      case UserType.systemAdmin:
        return 14;
      case UserType.superAdmin:
        return 9;
      case UserType.superUser:
        return 2;
      default:
        return 1;
    }
  }

  List<Tab> _getTabs() {
    final l10n = AppLocalizations.safeOf(context);
    final tabs = <Tab>[];

    if (widget.currentUser.userType == UserType.systemAdmin) {
      tabs.addAll([
        Tab(icon: const Icon(Icons.business, size: 20), text: l10n.departments),
        Tab(icon: const Icon(Icons.location_on, size: 20), text: l10n.places),
        Tab(icon: const Icon(Icons.people, size: 20), text: l10n.users),
        Tab(
            icon: const Icon(Icons.admin_panel_settings, size: 20),
            text: l10n.branchAdmins), // NEW TAB
        Tab(icon: const Icon(Icons.title, size: 20), text: l10n.problemTitles),
        Tab(icon: const Icon(Icons.build, size: 20), text: l10n.parts),
        Tab(
            icon: const Icon(Icons.inventory, size: 20),
            text: l10n.complaintItems),
        Tab(icon: const Icon(Icons.shield, size: 20), text: l10n.permissions),
        Tab(
            icon: const Icon(Icons.schedule, size: 20),
            text: l10n.autoApproval),
        Tab(icon: const Icon(Icons.history, size: 20), text: l10n.logs),
        Tab(icon: const Icon(Icons.settings, size: 20), text: l10n.preferences),
        Tab(icon: const Icon(Icons.auto_awesome, size: 20), text: l10n.aiInsights),
        Tab(icon: const Icon(Icons.bug_report_rounded, size: 20), text: l10n.problemReports),
        Tab(icon: const Icon(Icons.tune, size: 20), text: l10n.systemSettings),
      ]);
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      tabs.addAll([
        Tab(icon: const Icon(Icons.work, size: 20), text: l10n.natureOfWork),
        Tab(icon: const Icon(Icons.title, size: 20), text: l10n.problemTitles),
        Tab(icon: const Icon(Icons.build, size: 20), text: l10n.parts),
        Tab(icon: const Icon(Icons.people, size: 20), text: l10n.users),
        Tab(icon: const Icon(Icons.assessment, size: 20), text: l10n.reports),
        Tab(icon: const Icon(Icons.autorenew, size: 20), text: l10n.autoAssign),
        Tab(icon: const Icon(Icons.settings, size: 20), text: l10n.preferences),
        Tab(icon: const Icon(Icons.auto_awesome, size: 20), text: l10n.aiInsights),
        Tab(icon: const Icon(Icons.dashboard_customize, size: 20), text: l10n.aiDashboard),
      ]);
    } else if (widget.currentUser.userType == UserType.superUser) {
      tabs.addAll([
        Tab(icon: const Icon(Icons.people, size: 20), text: l10n.users),
        Tab(icon: const Icon(Icons.settings, size: 20), text: l10n.preferences),
      ]);
    } else {
      tabs.add(Tab(
          icon: const Icon(Icons.settings, size: 20), text: l10n.preferences));
    }

    return tabs;
  }

  Widget _getTabView(int index) {
    if (_cachedTabs.containsKey(index)) {
      return _cachedTabs[index]!;
    }

    Widget view;

    if (widget.currentUser.userType == UserType.systemAdmin) {
      switch (index) {
        case 0:
          view = DepartmentsManagement(currentUser: widget.currentUser);
          break;
        case 1:
          view = PlacesManagement(currentUser: widget.currentUser);
          break;
        case 2:
          view = UsersManagement(currentUser: widget.currentUser);
          break;
        case 3:
          view = BranchAdminManagement(
              currentUser: widget.currentUser); // NEW CASE
          break;
        case 4:
          view = ProblemTitlesManagement(currentUser: widget.currentUser);
          break;
        case 5:
          view = PartsManagement(currentUser: widget.currentUser);
          break;
        case 6:
          view = ComplaintItemsManagement(currentUser: widget.currentUser);
          break;
        case 7:
          view =
              DepartmentComplaintPermissions(currentUser: widget.currentUser);
          break;
        case 8:
          view = AutoApprovalSettingsWidget(currentUser: widget.currentUser);
          break;
        case 9:
          view = ActivityLogsView(currentUser: widget.currentUser);
          break;
        case 10:
          view = NotificationPreferencesWidget(currentUser: widget.currentUser);
          break;
        case 11:
          view = AiInsightsView(currentUser: widget.currentUser);
          break;
        case 12:
          view = ProblemReportsAdminScreen(currentUser: widget.currentUser);
          break;
        case 13:
          view = SystemSettingsScreen(currentUser: widget.currentUser);
          break;
        default:
          view =
              Center(child: Text(AppLocalizations.safeOf(context).invalidTab));
      }
    } else if (widget.currentUser.userType == UserType.superAdmin) {
      switch (index) {
        case 0:
          view = NatureOfWorkManagement(currentUser: widget.currentUser);
          break;
        case 1:
          view = ProblemTitlesManagement(currentUser: widget.currentUser);
          break;
        case 2:
          view = PartsManagement(currentUser: widget.currentUser);
          break;
        case 3:
          view = UsersManagement(currentUser: widget.currentUser);
          break;
        case 4:
          view = ReportsView(currentUser: widget.currentUser);
          break;
        case 5:
          view = AutoAssignmentSettingsWidget(currentUser: widget.currentUser);
          break;
        case 6:
          view = NotificationPreferencesWidget(currentUser: widget.currentUser);
          break;
        case 7:
          view = AiInsightsView(currentUser: widget.currentUser);
          break;
        case 8:
          view = AiDashboardScreen(currentUser: widget.currentUser);
          break;
        default:
          view =
              Center(child: Text(AppLocalizations.safeOf(context).invalidTab));
      }
    } else if (widget.currentUser.userType == UserType.superUser) {
      switch (index) {
        case 0:
          view = UsersManagement(currentUser: widget.currentUser);
          break;
        case 1:
          view = NotificationPreferencesWidget(currentUser: widget.currentUser);
          break;
        default:
          view =
              Center(child: Text(AppLocalizations.safeOf(context).invalidTab));
      }
    } else {
      view = NotificationPreferencesWidget(currentUser: widget.currentUser);
    }

    _cachedTabs[index] = view;
    return view;
  }

  void _refreshCurrentTab() {
    final currentIndex = _tabController.index;

    // Clear cached tab to force rebuild
    setState(() {
      _cachedTabs.remove(currentIndex);
    });
  }

// Add this method to expose refresh to child widgets
  void refreshAllTabs() {
    setState(() {
      _cachedTabs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    if (_getTabCount() == 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.noManagementOptionsAvailable,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(
          l10n.management,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: _getTabs(),
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                physics: const BouncingScrollPhysics(),
              ),
              Container(
                height: 1,
                color: Colors.grey.withOpacity(0.1),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: List.generate(
          _getTabCount(),
          (index) => _getTabView(index),
        ),
      ),
    );
  }
}

// ============================================================================
// OPTIMIZED DEPARTMENTS MANAGEMENT
// ============================================================================
class DepartmentsManagement extends StatefulWidget {
  final UserModel currentUser;

  const DepartmentsManagement({super.key, required this.currentUser});

  @override
  State<DepartmentsManagement> createState() => _DepartmentsManagementState();
}

class _DepartmentsManagementState extends State<DepartmentsManagement>
    with AutomaticKeepAliveClientMixin {
  List<DepartmentModel> _departments = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('departments')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _departments = response
              .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading departments: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

// Replace the existing _showCreateDialog with this updated version that supports edit
  void _showCreateDialog({DepartmentModel? department}) {
    final l10n = AppLocalizations.safeOf(context);
    final nameEnController = TextEditingController(text: department?.nameEn ?? department?.name ?? '');
    final nameArController = TextEditingController(text: department?.nameAr ?? '');
    final descriptionController =
        TextEditingController(text: department?.description ?? '');
    final isEditing = department != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.business,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? l10n.edit : l10n.createDepartment,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameEnController,
                  decoration: InputDecoration(
                    labelText: 'Name (English) *',
                    prefixIcon: const Icon(Icons.label_outline, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameArController,
                  decoration: InputDecoration(
                    labelText: 'الاسم (عربي)',
                    prefixIcon: const Icon(Icons.label_outline, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final enName = nameEnController.text.trim();
                final arName = nameArController.text.trim();
                if (enName.isEmpty && arName.isEmpty) {
                  _showError(l10n.nameIsRequired);
                  return;
                }
                // Use whichever name is filled as the base name
                final baseName = enName.isNotEmpty ? enName : arName;

                try {
                  if (isEditing) {
                    await supabase.from('departments').update({
                      'name': baseName,
                      'name_en': enName.isEmpty ? null : enName,
                      'name_ar': arName.isEmpty ? null : arName,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    }).eq('id', department.id);

                    Navigator.pop(context);
                    await _loadDepartments();
                    _showSuccess(l10n.departmentUpdatedSuccessfully);

                    // Refresh parent management screen to update all tabs
                    if (context.findAncestorStateOfType<
                            _ManagementScreenState>() !=
                        null) {
                      context
                          .findAncestorStateOfType<_ManagementScreenState>()!
                          .refreshAllTabs();
                    }
                  } else {
                    await supabase.from('departments').insert({
                      'name': baseName,
                      'name_en': enName.isEmpty ? null : enName,
                      'name_ar': arName.isEmpty ? null : arName,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    });

                    Navigator.pop(context);
                    await _loadDepartments();
                    _showSuccess(l10n.departmentCreatedSuccessfully);

                    // Refresh parent management screen to update all tabs
                    if (context.findAncestorStateOfType<
                            _ManagementScreenState>() !=
                        null) {
                      context
                          .findAncestorStateOfType<_ManagementScreenState>()!
                          .refreshAllTabs();
                    }
                  }
                } catch (e) {
                  _showError(isEditing
                      ? l10n.failedToUpdateDepartment
                      : l10n.failedToCreateDepartment);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isEditing ? l10n.update : l10n.create,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteDialog(DepartmentModel department) async {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.deleteDepartment,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '${l10n.areYouSureDeleteDepartment} "${department.localizedName(lang)}"?\n\n${l10n.thisActionCannotBeUndone}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteDepartment(department);
    }
  }

// Replace the _deleteDepartment method
  Future<void> _deleteDepartment(DepartmentModel department) async {
    final l10n = AppLocalizations.safeOf(context);

    // Show loading
    setState(() => _isLoading = true);

    try {
      // Perform delete
      await supabase.from('departments').delete().eq('id', department.id);

      // Remove from local list immediately
      setState(() {
        _departments.removeWhere((d) => d.id == department.id);
        _isLoading = false;
      });

      _showSuccess(l10n.departmentDeletedSuccessfully);

      // Refresh all tabs in parent
      if (context.findAncestorStateOfType<_ManagementScreenState>() != null) {
        context
            .findAncestorStateOfType<_ManagementScreenState>()!
            .refreshAllTabs();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error deleting department: $e');
      _showError('${l10n.failedToDeleteDepartment}: ${e.toString()}');
      // Reload to refresh on error
      await _loadDepartments();
    }
  }

// Replace the _toggleStatus method
  Future<void> _toggleStatus(DepartmentModel department) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final newStatus = !department.isActive;

      await supabase.from('departments').update({
        'is_active': newStatus,
      }).eq('id', department.id);

      // Update local state immediately to prevent UI jump
      setState(() {
        final index = _departments.indexWhere((d) => d.id == department.id);
        if (index != -1) {
          _departments[index] = DepartmentModel(
            id: department.id,
            name: department.name,
            nameEn: department.nameEn,
            nameAr: department.nameAr,
            description: department.description,
            isActive: newStatus,
            createdAt: department.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });

      _showSuccess(
        newStatus ? l10n.departmentActivated : l10n.departmentDeactivated,
      );
    } catch (e) {
      print('Error toggling department status: $e');
      _showError('${l10n.failedToUpdateDepartment}: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.business, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.departments, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('${_departments.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 14),
                label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _departments.isEmpty
                  ? SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.business_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.noDepartmentsYet,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.createYourFirstDepartment,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _departments.length,
                      itemBuilder: (context, index) {
                        final dept = _departments[index];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: dept.isActive
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: dept.isActive
                                      ? AppColors.primary
                                      : Colors.grey,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                dept.localizedName(lang),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: dept.description != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        dept.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit button - always first
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    color: Colors.blue,
                                    onPressed: () =>
                                        _showCreateDialog(department: dept),
                                    tooltip: l10n.edit,
                                  ),
                                  // Delete button - always second
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    color: Colors.red,
                                    onPressed: () => _showDeleteDialog(dept),
                                    tooltip: l10n.delete,
                                  ),
                                  const SizedBox(width: 8),
                                  // Status badge - always third
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dept.isActive
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dept.isActive
                                          ? l10n.active
                                          : l10n.inactive,
                                      style: TextStyle(
                                        color: dept.isActive
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Switch - always last
                                  Switch(
                                    value: dept.isActive,
                                    onChanged: (_) => _toggleStatus(dept),
                                    activeColor: Colors.green,
                                  ),
                                ],
                              ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED PLACES MANAGEMENT
// ============================================================================
class PlacesManagement extends StatefulWidget {
  final UserModel currentUser;

  const PlacesManagement({super.key, required this.currentUser});

  @override
  State<PlacesManagement> createState() => _PlacesManagementState();
}

class _PlacesManagementState extends State<PlacesManagement>
    with AutomaticKeepAliveClientMixin {
  List<PlaceModel> _places = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('places')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _places = response
              .map<PlaceModel>((json) => PlaceModel.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading places: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog({PlaceModel? place}) {
    showDialog(
      context: context,
      builder: (context) => _PlaceEditDialog(
        place: place,
        onSaved: _loadPlaces,
      ),
    );
  }

  Future<void> _showDeactivateDialog(PlaceModel place) async {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.block, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.deletePlace,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '${l10n.areYouSureDeletePlace} "${place.localizedName(lang)}"?\n\n${l10n.thisActionCannotBeUndone}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deactivatePlace(place);
    }
  }

  Future<void> _deactivatePlace(PlaceModel place) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      await supabase.from('places').update({'is_active': false}).eq('id', place.id);
      setState(() {
        final index = _places.indexWhere((p) => p.id == place.id);
        if (index != -1) {
          _places[index] = PlaceModel(
            id: place.id,
            name: place.name,
            nameEn: place.nameEn,
            nameAr: place.nameAr,
            description: place.description,
            isActive: false,
            createdAt: place.createdAt,
            updatedAt: DateTime.now(),
            allowedDepartmentIds: place.allowedDepartmentIds,
            allowedTicketTypes: place.allowedTicketTypes,
          );
        }
      });
      _showSuccess(l10n.placeDeactivated);
    } catch (e) {
      print('Error deactivating place: $e');
      _showError('${l10n.failedToDeletePlace}: ${e.toString()}');
    }
  }

// Keep only the _toggleStatus method
  Future<void> _toggleStatus(PlaceModel place) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final newStatus = !place.isActive;

      await supabase.from('places').update({
        'is_active': newStatus,
      }).eq('id', place.id);

      // Update local state immediately
      setState(() {
        final index = _places.indexWhere((p) => p.id == place.id);
        if (index != -1) {
          _places[index] = PlaceModel(
            id: place.id,
            name: place.name,
            nameEn: place.nameEn,
            nameAr: place.nameAr,
            description: place.description,
            isActive: newStatus,
            createdAt: place.createdAt,
            updatedAt: DateTime.now(),
            allowedDepartmentIds: place.allowedDepartmentIds,
            allowedTicketTypes: place.allowedTicketTypes,
          );
        }
      });

      _showSuccess(
        newStatus ? l10n.placeActivated : l10n.placeDeactivated,
      );
    } catch (e) {
      print('Error toggling place status: $e');
      _showError('${l10n.failedToUpdatePlace}: ${e.toString()}');
      // Reload to revert on error
      await _loadPlaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.places, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('${_places.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 14),
                label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _places.isEmpty
                  ? SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.noPlacesYet,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.createYourFirstPlace,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _places.length,
                      itemBuilder: (context, index) {
                        final place = _places[index];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: place.isActive
                                      ? AppColors.secondary.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: place.isActive
                                      ? AppColors.secondary
                                      : Colors.grey,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                place.localizedName(lang),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: place.description != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        place.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              trailing: isMobile
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (v) {
                                        if (v == 'edit') _showCreateDialog(place: place);
                                        if (v == 'toggle') _toggleStatus(place);
                                        if (v == 'delete') _showDeactivateDialog(place);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 16, color: Colors.blue), const SizedBox(width: 8), Text(l10n.edit)])),
                                        PopupMenuItem(value: 'toggle', child: Row(children: [Icon(place.isActive ? Icons.toggle_off : Icons.toggle_on, size: 16, color: Colors.orange), const SizedBox(width: 8), Text(place.isActive ? l10n.inactive : l10n.active)])),
                                        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.block, size: 16, color: Colors.red), const SizedBox(width: 8), Text(l10n.delete, style: const TextStyle(color: Colors.red))])),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          color: Colors.blue,
                                          onPressed: () => _showCreateDialog(place: place),
                                          tooltip: l10n.edit,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: place.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            place.isActive ? l10n.active : l10n.inactive,
                                            style: TextStyle(
                                              color: place.isActive ? Colors.green : Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: place.isActive,
                                          onChanged: (_) => _toggleStatus(place),
                                          activeColor: Colors.green,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.block, size: 20),
                                          color: Colors.red,
                                          onPressed: () => _showDeactivateDialog(place),
                                          tooltip: l10n.delete,
                                        ),
                                      ],
                                    ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED USERS MANAGEMENT
// ============================================================================
// ─── Place create / edit dialog ──────────────────────────────────────────────

class _PlaceEditDialog extends StatefulWidget {
  final PlaceModel? place;
  final VoidCallback onSaved;

  const _PlaceEditDialog({this.place, required this.onSaved});

  @override
  State<_PlaceEditDialog> createState() => _PlaceEditDialogState();
}

class _PlaceEditDialogState extends State<_PlaceEditDialog> {
  final _nameEnCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<Map<String, dynamic>> _allDepartments = [];
  Set<String> _selectedDeptIds = {};
  Set<String> _selectedTicketTypes = {};
  bool _loadingDepts = true;
  bool _saving = false;

  static const _ticketTypeOptions = [
    ('it_solution', 'IT Solution / حلول تقنية', Icons.computer, Colors.blue),
    ('places_maintenance', 'Places Maintenance / صيانة المواقع', Icons.home_repair_service, Colors.green),
    ('complaint', 'Complaint / شكوى جودة', Icons.report_problem, Colors.orange),
    ('individuals_maintenance', 'Individuals Maintenance / صيانة أفراد', Icons.person_pin, Colors.purple),
    ('requests', 'Requests / طلبات', Icons.request_page, Colors.teal),
    ('trucks_maintenance', 'Truck Maintenance / صيانة الشاحنات', Icons.local_shipping, Colors.brown),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    if (p != null) {
      _nameEnCtrl.text = p.nameEn ?? p.name;
      _nameArCtrl.text = p.nameAr ?? '';
      _descCtrl.text = p.description ?? '';
      _selectedDeptIds = Set.from(p.allowedDepartmentIds);
      _selectedTicketTypes = Set.from(p.allowedTicketTypes);
    }
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await supabase
          .from('departments')
          .select('id, name, name_ar')
          .order('name');
      if (mounted) {
        setState(() {
          _allDepartments = List<Map<String, dynamic>>.from(data);
          _loadingDepts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  Future<void> _save() async {
    final enName = _nameEnCtrl.text.trim();
    final arName = _nameArCtrl.text.trim();
    if (enName.isEmpty && arName.isEmpty) return;
    final baseName = enName.isNotEmpty ? enName : arName;
    setState(() => _saving = true);
    try {
      final payload = {
        'name': baseName,
        'name_en': enName.isEmpty ? null : enName,
        'name_ar': arName.isEmpty ? null : arName,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'allowed_department_ids': _selectedDeptIds.toList(),
        'allowed_ticket_types': _selectedTicketTypes.toList(),
      };
      if (widget.place != null) {
        await supabase.from('places').update(payload).eq('id', widget.place!.id);
      } else {
        await supabase.from('places').insert(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.place != null;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';

    InputDecoration fieldDecor(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(isEditing ? Icons.edit : Icons.location_on, color: AppColors.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(isEditing ? (isRtl ? 'تعديل الموقع' : 'Edit Place') : (isRtl ? 'إنشاء موقع' : 'Create Place'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name fields
              TextField(controller: _nameEnCtrl, decoration: fieldDecor('Name (English) *', Icons.label_outline), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              TextField(controller: _nameArCtrl, decoration: fieldDecor('الاسم (عربي)', Icons.label_outline), textAlign: TextAlign.right),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: fieldDecor(isRtl ? 'الوصف' : 'Description', Icons.description_outlined), maxLines: 2),

              const SizedBox(height: 20),

              // Departments section
              Row(children: [
                Icon(Icons.business, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(isRtl ? 'الأقسام المسموح بها' : 'Allowed Departments',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 6),
                Text(isRtl ? '(فارغ = الكل)' : '(empty = all)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
              const SizedBox(height: 8),
              if (_loadingDepts)
                const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allDepartments.length,
                    itemBuilder: (_, i) {
                      final dept = _allDepartments[i];
                      final id = dept['id'] as String;
                      final name = (isRtl ? dept['name_ar'] : dept['name']) as String? ?? dept['name'] as String;
                      final checked = _selectedDeptIds.contains(id);
                      return CheckboxListTile(
                        dense: true,
                        value: checked,
                        title: Text(name, style: const TextStyle(fontSize: 13)),
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() {
                          if (v == true) _selectedDeptIds.add(id);
                          else _selectedDeptIds.remove(id);
                        }),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // Ticket types section
              Row(children: [
                Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(isRtl ? 'أنواع التذاكر المسموح بها' : 'Allowed Ticket Types',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 6),
                Text(isRtl ? '(فارغ = الكل)' : '(empty = all)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: _ticketTypeOptions.map((opt) {
                    final (value, label, icon, color) = opt;
                    final checked = _selectedTicketTypes.contains(value);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      title: Row(children: [
                        Icon(icon, size: 15, color: color),
                        const SizedBox(width: 6),
                        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
                      ]),
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        if (v == true) _selectedTicketTypes.add(value);
                        else _selectedTicketTypes.remove(value);
                      }),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(isRtl ? 'إلغاء' : 'Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? (isRtl ? 'تحديث' : 'Update') : (isRtl ? 'إنشاء' : 'Create'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ============================================================================
// SYSTEM SETTINGS SCREEN
// ============================================================================
class SystemSettingsScreen extends StatefulWidget {
  final UserModel currentUser;

  const SystemSettingsScreen({super.key, required this.currentUser});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with AutomaticKeepAliveClientMixin {
  static const _itKey = 'it_solution_target_department';
  static const _vehicleKey = 'vehicle_maintenance_target_department';

  List<DepartmentModel> _departments = [];
  String? _itDeptId;
  String? _vehicleDeptId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final deptRes = await supabase
          .from('departments')
          .select()
          .eq('is_active', true)
          .order('name');
      final settingsRes = await supabase
          .from('system_settings')
          .select()
          .inFilter('setting_key', [_itKey, _vehicleKey]);

      String? itVal;
      String? vehicleVal;
      for (final row in settingsRes) {
        if (row['setting_key'] == _itKey) itVal = row['value'] as String?;
        if (row['setting_key'] == _vehicleKey) vehicleVal = row['value'] as String?;
      }

      if (mounted) {
        setState(() {
          _departments = deptRes
              .map<DepartmentModel>((j) => DepartmentModel.fromJson(j))
              .toList();
          _itDeptId = itVal;
          _vehicleDeptId = vehicleVal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.safeOf(context);
    setState(() => _isSaving = true);
    try {
      await supabase.from('system_settings').upsert(
        {'setting_key': _itKey, 'value': _itDeptId, 'updated_at': DateTime.now().toIso8601String()},
        onConflict: 'setting_key',
      );
      await supabase.from('system_settings').upsert(
        {'setting_key': _vehicleKey, 'value': _vehicleDeptId, 'updated_at': DateTime.now().toIso8601String()},
        onConflict: 'setting_key',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(l10n.systemSettingsSaved),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.failedToSaveSettings}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.systemSettings,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionCard(
                        icon: Icons.alt_route,
                        title: l10n.ticketRoutingSettings,
                        children: [
                          _deptDropdown(
                            label: l10n.itSolutionTargetDept,
                            hint: l10n.itSolutionDeptHint,
                            icon: Icons.computer,
                            iconColor: Colors.blue,
                            value: _itDeptId,
                            departments: _departments,
                            lang: lang,
                            onChanged: (v) => setState(() => _itDeptId = v),
                          ),
                          const SizedBox(height: 16),
                          _deptDropdown(
                            label: l10n.vehicleMaintenanceTargetDept,
                            hint: l10n.vehicleMaintenanceDeptHint,
                            icon: Icons.local_shipping,
                            iconColor: Colors.brown,
                            value: _vehicleDeptId,
                            departments: _departments,
                            lang: lang,
                            onChanged: (v) => setState(() => _vehicleDeptId = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            l10n.save,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _deptDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required String? value,
    required List<DepartmentModel> departments,
    required String lang,
    required ValueChanged<String?> onChanged,
  }) {
    final l10n = AppLocalizations.safeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        Text(hint,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: departments.any((d) => d.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
          hint: Text(l10n.selectDepartment,
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.notConfigured,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
            ...departments.map((d) => DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(d.localizedName(lang),
                      style: const TextStyle(fontSize: 13)),
                )),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class UsersManagement extends StatefulWidget {
  final UserModel currentUser;

  const UsersManagement({super.key, required this.currentUser});

  @override
  State<UsersManagement> createState() => _UsersManagementState();
}

class _UsersManagementState extends State<UsersManagement>
    with AutomaticKeepAliveClientMixin {
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _filterType = 'active';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      var query = supabase.from('users').select();

      if (widget.currentUser.userType == UserType.superUser &&
          widget.currentUser.placeId != null) {
        query = query.eq('place_id', widget.currentUser.placeId!);
      } else if (widget.currentUser.userType == UserType.superAdmin &&
          widget.currentUser.departmentId != null) {
        query = query.eq('department_id', widget.currentUser.departmentId!);
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = response
              .map<UserModel>((json) => UserModel.fromJson(json))
              .toList();
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredUsers = _users.where((user) {
      // Never show the current logged-in user
      if (user.id == widget.currentUser.id) return false;

      // Deleted filter shows only deleted users
      if (_filterType == 'deleted') return user.isDeleted;

      // Hide deleted users from all other filters
      if (user.isDeleted) return false;

      final matchesSearch = _searchQuery.isEmpty ||
          user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _filterType == 'all' ||
          (_filterType == 'active' && user.isActive) ||
          (_filterType == 'inactive' && !user.isActive) ||
          user.userType.value == _filterType;

      return matchesSearch && matchesType;
    }).toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleUserStatus(UserModel user) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      await supabase.from('users').update({
        'is_active': !user.isActive,
      }).eq('id', user.id);

      _loadUsers();
      _showSuccess(
        user.isActive ? l10n.userDeactivated : l10n.userActivated,
      );
    } catch (e) {
      _showError(l10n.failedToUpdateUserStatus);
    }
  }

  void _removeUser(UserModel user) async {
    final l10n = AppLocalizations.safeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_off_outlined, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Text(l10n.removeUser, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${l10n.confirmRemoveUser} "${user.fullName}"?\n\nThe account will remain in the database.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(l10n.removeUser),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await supabase.from('users').update({
          'is_deleted': true,
          'is_active': false,
        }).eq('id', user.id);
        _loadUsers();
        _showSuccess(l10n.userRemoved);
      } catch (e) {
        _showError(l10n.failedToUpdateUserStatus);
      }
    }
  }

  void _restoreUser(UserModel user) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      await supabase.from('users').update({
        'is_deleted': false,
        'is_active': true,
      }).eq('id', user.id);
      _loadUsers();
      _showSuccess(l10n.userRestored);
    } catch (e) {
      _showError(l10n.failedToUpdateUserStatus);
    }
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateUserDialog(
        currentUser: widget.currentUser,
        onUserCreated: _loadUsers,
      ),
    );
  }

  bool _canCreateUsers() {
    return widget.currentUser.userType == UserType.systemAdmin ||
        widget.currentUser.userType == UserType.superAdmin ||
        widget.currentUser.userType == UserType.superUser;
  }

  bool _canEditUser(UserModel user) {
    if (widget.currentUser.userType == UserType.systemAdmin) {
      return true;
    }

    if (widget.currentUser.userType == UserType.superAdmin) {
      return user.userType == UserType.admin &&
          user.departmentId == widget.currentUser.departmentId;
    }

    if (widget.currentUser.userType == UserType.superUser) {
      return user.userType == UserType.user &&
          user.placeId == widget.currentUser.placeId;
    }

    return false;
  }

  void _showEditUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        currentUser: widget.currentUser,
        userToEdit: user,
        onUserUpdated: _loadUsers,
      ),
    );
  }

  Color _getUserTypeColor(UserType type) {
    switch (type) {
      case UserType.systemAdmin:
        return Colors.purple;
      case UserType.superAdmin:
        return Colors.blue;
      case UserType.admin:
        return Colors.orange;
      case UserType.superUser:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Compact Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.12))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.users,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_filteredUsers.length} ${l10n.oF} ${_users.length}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (_canCreateUsers())
                    ElevatedButton.icon(
                      onPressed: _showCreateUserDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.addUser, style: const TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      }),
                      decoration: InputDecoration(
                        hintText: l10n.searchTicketsPlacesCreators,
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterType,
                      isDense: true,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(l10n.allUsers, style: const TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'active', child: Text(l10n.active, style: const TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'inactive', child: Text(l10n.inactive, style: const TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'admin', child: Text(l10n.management, style: const TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'user', child: Text(l10n.users, style: const TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'deleted', child: Text(l10n.removed, style: const TextStyle(fontSize: 13))),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() { _filterType = value; _applyFilters(); });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 52, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? l10n.noUsersYet : l10n.noResultsFound,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isEmpty ? l10n.createYourFirstUser : l10n.tryAdjustingFilters,
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomNavBarHeight + 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final typeColor = _getUserTypeColor(user.userType);
                        final isInactive = !user.isActive;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isInactive ? Colors.grey.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isInactive
                                  ? Colors.grey.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.12),
                            ),
                            boxShadow: isInactive
                                ? null
                                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isInactive ? Colors.grey.withOpacity(0.1) : typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isInactive ? Colors.grey.withOpacity(0.2) : typeColor.withOpacity(0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8.5),
                                          child: Image.network(
                                            user.profileImageUrl!,
                                            width: 42, height: 42, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                user.fullName.substring(0, 1).toUpperCase(),
                                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isInactive ? Colors.grey : typeColor),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            user.fullName.substring(0, 1).toUpperCase(),
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isInactive ? Colors.grey : typeColor),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isInactive ? Colors.grey[500] : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user.email,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isInactive ? Colors.grey.withOpacity(0.08) : typeColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              user.userType.value.replaceAll('_', ' ').toUpperCase(),
                                              style: TextStyle(
                                                color: isInactive ? Colors.grey : typeColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: user.isActive ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              user.isActive ? l10n.active : l10n.inactive,
                                              style: TextStyle(
                                                color: user.isActive ? Colors.green[700] : Colors.red[400],
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_canEditUser(user))
                                      _ActionIconButton(
                                        icon: Icons.edit_outlined,
                                        color: AppColors.primary,
                                        tooltip: l10n.edit,
                                        onTap: () => _showEditUserDialog(user),
                                      ),
                                    if (_canEditUser(user) && !user.isDeleted) ...[
                                      const SizedBox(width: 4),
                                      _ActionIconButton(
                                        icon: user.isActive
                                            ? Icons.block_outlined
                                            : Icons.check_circle_outline,
                                        color: user.isActive
                                            ? Colors.orange
                                            : Colors.green,
                                        tooltip: user.isActive
                                            ? l10n.deactivate
                                            : l10n.activate,
                                        onTap: () => _toggleUserStatus(user),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    if (user.isDeleted)
                                      _ActionIconButton(
                                        icon: Icons.restore_outlined,
                                        color: Colors.green,
                                        tooltip: l10n.restoreUser,
                                        onTap: () => _restoreUser(user),
                                      )
                                    else
                                      _ActionIconButton(
                                        icon: Icons.person_off_outlined,
                                        color: Colors.red,
                                        tooltip: l10n.removeUser,
                                        onTap: () => _removeUser(user),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ============================================================================
// OPTIMIZED PROBLEM TITLES MANAGEMENT
// ============================================================================
class ProblemTitlesManagement extends StatefulWidget {
  final UserModel currentUser;

  const ProblemTitlesManagement({super.key, required this.currentUser});

  @override
  State<ProblemTitlesManagement> createState() =>
      _ProblemTitlesManagementState();
}

class _ProblemTitlesManagementState extends State<ProblemTitlesManagement>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _problemTitles = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProblemTitles();
  }

  void _showEditDialog(Map<String, dynamic> problemTitle) {
    final l10n = AppLocalizations.safeOf(context);
    final titleController = TextEditingController(text: problemTitle['title']);
    final descriptionController =
        TextEditingController(text: problemTitle['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.edit,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '${l10n.title} *',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  _showError(l10n.titleRequired);
                  return;
                }

                try {
                  await supabase.from('problem_titles').update({
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  }).eq('id', problemTitle['id']);

                  Navigator.pop(context);
                  _loadProblemTitles();
                  _showSuccess(l10n.problemTitleUpdatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToUpdateProblemTitle);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.update, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

// Replace the entire _showDeleteDialog method
  void _showDeleteDialog(Map<String, dynamic> problemTitle) {
    final l10n = AppLocalizations.safeOf(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.deleteProblemTitle,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.areYouSureDeleteProblemTitle,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.title, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        problemTitle['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.thisActionCannotBeUndone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Show loading
                setState(() => _isLoading = true);

                try {
                  // Perform delete
                  await supabase
                      .from('problem_titles')
                      .delete()
                      .eq('id', problemTitle['id']);

                  // Remove from local list immediately
                  setState(() {
                    _problemTitles
                        .removeWhere((p) => p['id'] == problemTitle['id']);
                    _isLoading = false;
                  });

                  _showSuccess(l10n.problemTitleDeletedSuccessfully);
                } catch (e) {
                  setState(() => _isLoading = false);
                  print('Error deleting problem title: $e');
                  _showError(
                      '${l10n.failedToDeleteProblemTitle}: ${e.toString()}');
                  // Reload to refresh on error
                  await _loadProblemTitles();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadProblemTitles() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      var query =
          supabase.from('problem_titles').select('*, departments(name)');

      if (widget.currentUser.userType == UserType.superAdmin) {
        if (widget.currentUser.departmentId != null) {
          query = query.eq('department_id', widget.currentUser.departmentId!);
        }
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(
            () => _problemTitles = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      print('Error loading problem titles: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.title, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.createProblemTitle,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '${l10n.title} *',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  _showError(l10n.titleRequired);
                  return;
                }

                try {
                  await supabase.from('problem_titles').insert({
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'department_id': widget.currentUser.departmentId,
                    'created_by': widget.currentUser.id,
                  });
                  Navigator.pop(context);
                  _loadProblemTitles();
                  _showSuccess(l10n.problemTitleCreatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToCreateProblemTitle);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.create, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredProblemTitles {
    if (_searchQuery.isEmpty) return _problemTitles;

    return _problemTitles.where((problem) {
      final title = problem['title']?.toString().toLowerCase() ?? '';
      final description =
          problem['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return title.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.title,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.problemTitles, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_filteredProblemTitles.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchProblemTitles,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProblemTitles.isEmpty
                  ? SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.title,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.noProblemTitlesYet
                                  : l10n.noResultsFound,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.createYourFirstProblemTitle
                                  : l10n.tryAdjustingFilters,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredProblemTitles.length,
                      itemBuilder: (context, index) {
                        final problem = _filteredProblemTitles[index];
                        final departmentName =
                            problem['departments']?['name'] ?? 'N/A';

                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.title,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                problem['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (problem['description'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      problem['description'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      departmentName,
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _showEditDialog(problem),
                                    tooltip: l10n.edit,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _showDeleteDialog(problem),
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED PARTS MANAGEMENT
// ============================================================================
class PartsManagement extends StatefulWidget {
  final UserModel currentUser;

  const PartsManagement({super.key, required this.currentUser});

  @override
  State<PartsManagement> createState() => _PartsManagementState();
}

class _PartsManagementState extends State<PartsManagement>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _parts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  void _showEditDialog(Map<String, dynamic> part) {
    final l10n = AppLocalizations.safeOf(context);
    final nameController = TextEditingController(text: part['name']);
    final modelController = TextEditingController(text: part['model_number']);
    final descriptionController =
        TextEditingController(text: part['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.edit,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.name} *',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelController,
                decoration: InputDecoration(
                  labelText: '${l10n.modelNumber} *',
                  prefixIcon: const Icon(Icons.numbers, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    modelController.text.trim().isEmpty) {
                  _showError(l10n.nameAndModelRequired);
                  return;
                }

                try {
                  await supabase.from('parts').update({
                    'name': nameController.text.trim(),
                    'model_number': modelController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  }).eq('id', part['id']);

                  Navigator.pop(context);
                  _loadParts();
                  _showSuccess(l10n.partUpdatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToUpdatePart);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.update, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

// Replace the entire _showDeleteDialog method
  void _showDeleteDialog(Map<String, dynamic> part) {
    final l10n = AppLocalizations.safeOf(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.deletePart,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.areYouSureDeletePart,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.build, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            part['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.numbers, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          part['model_number'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.thisActionCannotBeUndone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Show loading
                setState(() => _isLoading = true);

                try {
                  // Perform delete
                  await supabase.from('parts').delete().eq('id', part['id']);

                  // Remove from local list immediately
                  setState(() {
                    _parts.removeWhere((p) => p['id'] == part['id']);
                    _isLoading = false;
                  });

                  _showSuccess(l10n.partDeletedSuccessfully);
                } catch (e) {
                  setState(() => _isLoading = false);
                  print('Error deleting part: $e');
                  _showError('${l10n.failedToDeletePart}: ${e.toString()}');
                  // Reload to refresh on error
                  await _loadParts();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadParts() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      var query = supabase.from('parts').select('*, departments(name)');

      if (widget.currentUser.userType == UserType.superAdmin) {
        if (widget.currentUser.departmentId != null) {
          query = query.eq('department_id', widget.currentUser.departmentId!);
        }
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() => _parts = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      print('Error loading parts: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final nameController = TextEditingController();
    final modelController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.createPart,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.name} *',
                  prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelController,
                decoration: InputDecoration(
                  labelText: '${l10n.modelNumber} *',
                  prefixIcon: const Icon(Icons.numbers, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    modelController.text.trim().isEmpty) {
                  _showError(l10n.nameAndModelRequired);
                  return;
                }

                try {
                  await supabase.from('parts').insert({
                    'name': nameController.text.trim(),
                    'model_number': modelController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'department_id': widget.currentUser.departmentId!,
                    'created_by': widget.currentUser.id,
                  });
                  Navigator.pop(context);
                  _loadParts();
                  _showSuccess(l10n.partCreatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToCreatePart);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.create, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredParts {
    if (_searchQuery.isEmpty) return _parts;

    return _parts.where((part) {
      final name = part['name']?.toString().toLowerCase() ?? '';
      final model = part['model_number']?.toString().toLowerCase() ?? '';
      final description = part['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) ||
          model.contains(query) ||
          description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.build,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.parts, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_filteredParts.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchParts,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredParts.isEmpty
                  ? SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.build_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.noPartsYet
                                  : l10n.noResultsFound,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.createYourFirstPart
                                  : l10n.tryAdjustingFilters,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 8,
                        bottom: bottomNavBarHeight + 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredParts.length,
                      itemBuilder: (context, index) {
                        final part = _filteredParts[index];
                        final departmentName =
                            part['departments']?['name'] ?? 'N/A';

                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.build,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                part['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.numbers,
                                          size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        part['model_number'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (part['description'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      part['description'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      departmentName,
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange, size: 20),
                                    onPressed: () => _showEditDialog(part),
                                    tooltip: l10n.edit,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _showDeleteDialog(part),
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED NATURE OF WORK MANAGEMENT
// ============================================================================
class NatureOfWorkManagement extends StatefulWidget {
  final UserModel currentUser;

  const NatureOfWorkManagement({super.key, required this.currentUser});

  @override
  State<NatureOfWorkManagement> createState() => _NatureOfWorkManagementState();
}

class _NatureOfWorkManagementState extends State<NatureOfWorkManagement>
    with AutomaticKeepAliveClientMixin {
  List<NatureOfWorkModel> _natureOfWorkList = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNatureOfWork();
  }

  void _showEditDialog(NatureOfWorkModel item) {
    final l10n = AppLocalizations.safeOf(context);
    final nameEnController = TextEditingController(text: item.nameEn ?? item.name);
    final nameArController = TextEditingController(text: item.nameAr ?? '');
    final descriptionController =
        TextEditingController(text: item.description ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.edit,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameEnController,
                  decoration: InputDecoration(
                    labelText: 'Name (English) *',
                    hintText: l10n.exampleNetworkIssuesHardwareRepair,
                    prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameArController,
                  decoration: InputDecoration(
                    labelText: 'الاسم (عربي)',
                    prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final enName = nameEnController.text.trim();
                final arName = nameArController.text.trim();
                if (enName.isEmpty && arName.isEmpty) {
                  _showError(l10n.nameIsRequired);
                  return;
                }
                final baseName = enName.isNotEmpty ? enName : arName;

                try {
                  await supabase.from('nature_of_work').update({
                    'name': baseName,
                    'name_en': enName.isEmpty ? null : enName,
                    'name_ar': arName.isEmpty ? null : arName,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  }).eq('id', item.id);

                  Navigator.pop(context);
                  _loadNatureOfWork();
                  _showSuccess(l10n.natureOfWorkUpdatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToUpdateNatureOfWork);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.update, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

// Replace the entire _showDeleteDialog method
  void _showDeleteDialog(NatureOfWorkModel item) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.deleteNatureOfWork,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.areYouSureDeleteNatureOfWork,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.localizedName(lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.thisActionCannotBeUndone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Show loading
                setState(() => _isLoading = true);

                try {
                  // Perform delete
                  await supabase
                      .from('nature_of_work')
                      .delete()
                      .eq('id', item.id);

                  // Remove from local list immediately
                  setState(() {
                    _natureOfWorkList.removeWhere((n) => n.id == item.id);
                    _isLoading = false;
                  });

                  _showSuccess(l10n.natureOfWorkDeletedSuccessfully);
                } catch (e) {
                  setState(() => _isLoading = false);
                  print('Error deleting nature of work: $e');
                  _showError(
                      '${l10n.failedToDeleteNatureOfWork}: ${e.toString()}');
                  // Reload to refresh on error
                  await _loadNatureOfWork();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadNatureOfWork() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      var query = supabase.from('nature_of_work').select();

      if (widget.currentUser.userType == UserType.superAdmin) {
        if (widget.currentUser.departmentId != null) {
          query = query.eq('department_id', widget.currentUser.departmentId!);
        }
      }

      final response = await query.order('name');

      if (mounted) {
        setState(() {
          _natureOfWorkList = response
              .map<NatureOfWorkModel>(
                  (json) => NatureOfWorkModel.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading nature of work: $e');
      if (mounted) {
        _showError('Failed to load nature of work');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final nameEnController = TextEditingController();
    final nameArController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.createNatureOfWork,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameEnController,
                  decoration: InputDecoration(
                    labelText: 'Name (English) *',
                    hintText: l10n.exampleNetworkIssuesHardwareRepair,
                    prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameArController,
                  decoration: InputDecoration(
                    labelText: 'الاسم (عربي)',
                    prefixIcon: const Icon(Icons.label, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    prefixIcon: const Icon(Icons.description, color: Color(0xFFf16936), size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFf16936), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final enName = nameEnController.text.trim();
                final arName = nameArController.text.trim();
                if (enName.isEmpty && arName.isEmpty) {
                  _showError(l10n.nameIsRequired);
                  return;
                }
                final baseName = enName.isNotEmpty ? enName : arName;

                try {
                  await supabase.from('nature_of_work').insert({
                    'name': baseName,
                    'name_en': enName.isEmpty ? null : enName,
                    'name_ar': arName.isEmpty ? null : arName,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'department_id': widget.currentUser.departmentId,
                    'created_by': widget.currentUser.id,
                  });
                  Navigator.pop(context);
                  _loadNatureOfWork();
                  _showSuccess(l10n.natureOfWorkCreatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToCreateNatureOfWork);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.create, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

// Replace the _toggleActive method
  void _toggleActive(NatureOfWorkModel item) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final newStatus = !item.isActive;

      await supabase.from('nature_of_work').update({
        'is_active': newStatus,
      }).eq('id', item.id);

      // Update local state immediately to prevent UI jump
      setState(() {
        final index = _natureOfWorkList.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _natureOfWorkList[index] = NatureOfWorkModel(
            id: item.id,
            departmentId: item.departmentId,
            name: item.name,
            nameEn: item.nameEn,
            nameAr: item.nameAr,
            description: item.description,
            isActive: newStatus,
            createdBy: item.createdBy,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });

      _showSuccess(
        newStatus ? l10n.activatedSuccessfully : l10n.deactivatedSuccessfully,
      );
    } catch (e) {
      print('Error toggling nature of work status: $e');
      _showError('${l10n.failedToUpdateStatus}: ${e.toString()}');
    }
  }

  List<NatureOfWorkModel> get _filteredNatureOfWork {
    if (_searchQuery.isEmpty) return _natureOfWorkList;

    return _natureOfWorkList.where((item) {
      final name = item.name.toLowerCase();
      final description = item.description?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.work,
                      color: Colors.teal,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.natureOfWorkManagement, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_filteredNatureOfWork.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchNatureOfWork,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredNatureOfWork.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.noNatureOfWorkYet
                                : l10n.noNatureOfWorkFound,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.defineYourFirstNatureOfWork
                                : l10n.tryAdjustingSearch,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredNatureOfWork.length,
                      itemBuilder: (context, index) {
                        final item = _filteredNatureOfWork[index];

                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: item.isActive
                                      ? Colors.teal.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.work,
                                  color:
                                      item.isActive ? Colors.teal : Colors.grey,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item.localizedName(lang),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: item.description != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.description!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status badge - always first
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.isActive
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.isActive
                                          ? l10n.active
                                          : l10n.inactive,
                                      style: TextStyle(
                                        color: item.isActive
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Switch - always second
                                  Switch(
                                    value: item.isActive,
                                    onChanged: (_) => _toggleActive(item),
                                    activeColor: Colors.green,
                                  ),
                                  // Edit button - always third
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.teal, size: 20),
                                    onPressed: () => _showEditDialog(item),
                                    tooltip: l10n.edit,
                                  ),
                                  // Delete button - always last
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _showDeleteDialog(item),
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED COMPLAINT ITEMS MANAGEMENT
// ============================================================================
class ComplaintItemsManagement extends StatefulWidget {
  final UserModel currentUser;

  const ComplaintItemsManagement({super.key, required this.currentUser});

  @override
  State<ComplaintItemsManagement> createState() =>
      _ComplaintItemsManagementState();
}

class _ComplaintItemsManagementState extends State<ComplaintItemsManagement>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final l10n = AppLocalizations.safeOf(context);
    final nameController = TextEditingController(text: item['name']);
    final descriptionController =
        TextEditingController(text: item['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.edit,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.itemName} *',
                  hintText: l10n.exampleProductXServiceY,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showError(l10n.itemNameRequired);
                  return;
                }

                try {
                  await supabase.from('complaint_items').update({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  }).eq('id', item['id']);

                  Navigator.pop(context);
                  _loadItems();
                  _showSuccess(l10n.itemUpdatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToUpdateItem);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.update,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

// Replace the entire _showDeleteDialog method
  void _showDeleteDialog(Map<String, dynamic> item) {
    final l10n = AppLocalizations.safeOf(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.deleteComplaintItem,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.areYouSureDeleteItem,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.thisActionCannotBeUndone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),

// Replace the delete button onPressed in _showDeleteDialog
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Show loading
                setState(() => _isLoading = true);

                try {
                  // Perform delete
                  await supabase
                      .from('complaint_items')
                      .delete()
                      .eq('id', item['id']);

                  // Remove from local list immediately
                  setState(() {
                    _items.removeWhere((i) => i['id'] == item['id']);
                    _isLoading = false;
                  });

                  _showSuccess(l10n.itemDeletedSuccessfully);
                } catch (e) {
                  setState(() => _isLoading = false);
                  print('Error deleting complaint item: $e');
                  _showError('${l10n.failedToDeleteItem}: ${e.toString()}');
                  // Reload to refresh on error
                  await _loadItems();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadItems() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('complaint_items')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() => _items = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      print('Error loading complaint items: $e');
      if (mounted) {
        _showError('Failed to load items');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.inventory, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.createComplaintItem,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.itemName} *',
                  hintText: l10n.exampleProductXServiceY,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showError(l10n.itemNameRequired);
                  return;
                }

                try {
                  await supabase.from('complaint_items').insert({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'created_by': widget.currentUser.id,
                  });
                  Navigator.pop(context);
                  _loadItems();
                  _showSuccess(l10n.itemCreatedSuccessfully);
                } catch (e) {
                  _showError(l10n.failedToCreateItem);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.create,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

// Replace the _toggleActive method
  void _toggleActive(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final isActive = item['is_active'] ?? false;
      final newStatus = !isActive;

      await supabase.from('complaint_items').update({
        'is_active': newStatus,
      }).eq('id', item['id']);

      // Update local state immediately to prevent UI jump
      setState(() {
        final index = _items.indexWhere((i) => i['id'] == item['id']);
        if (index != -1) {
          _items[index] = {
            ..._items[index],
            'is_active': newStatus,
          };
        }
      });

      _showSuccess(
        newStatus ? l10n.itemActivated : l10n.itemDeactivated,
      );
    } catch (e) {
      print('Error toggling complaint item status: $e');
      _showError('${l10n.failedToUpdateItem}: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;

    return _items.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory,
                      color: Colors.purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.complaintItems, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_filteredItems.length} ${l10n.total}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(l10n.addItem, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchItems,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inventory_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.noComplaintItemsYet
                                : l10n.noItemsFound,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.createYourFirstItem
                                : l10n.tryAdjustingSearch,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isActive = item['is_active'] ?? false;

                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.inventory,
                                  color: isActive ? Colors.purple : Colors.grey,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: item['description'] != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item['description'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status badge - always first
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isActive ? l10n.active : l10n.inactive,
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Switch - always second
                                  Switch(
                                    value: isActive,
                                    onChanged: (_) => _toggleActive(item),
                                    activeColor: Colors.green,
                                  ),
                                  // Edit button - always third
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.purple, size: 20),
                                    onPressed: () => _showEditDialog(item),
                                    tooltip: l10n.edit,
                                  ),
                                  // Delete button - always last
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _showDeleteDialog(item),
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            ));
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// OPTIMIZED DEPARTMENT COMPLAINT PERMISSIONS
// ============================================================================
class DepartmentComplaintPermissions extends StatefulWidget {
  final UserModel currentUser;

  const DepartmentComplaintPermissions({super.key, required this.currentUser});

  @override
  State<DepartmentComplaintPermissions> createState() =>
      _DepartmentComplaintPermissionsState();
}

class _DepartmentComplaintPermissionsState
    extends State<DepartmentComplaintPermissions>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _departments = [];
  Map<String, bool> _permissions = {};
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force reload when tab becomes visible
    _loadData();
  }

// Update _loadData to always fetch fresh data
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final depts = await supabase
          .from('departments')
          .select()
          .eq('is_active', true)
          .order('name');

      final perms =
          await supabase.from('department_complaint_permissions').select();

      if (mounted) {
        setState(() {
          _departments = List<Map<String, dynamic>>.from(depts);
          _permissions = {
            for (var p in perms) p['department_id']: p['can_access_complaints']
          };
        });
      }
    } catch (e) {
      print('Error loading permissions: $e');
      if (mounted) {
        _showError('Failed to load permissions');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredDepartments {
    if (_searchQuery.isEmpty) return _departments;

    return _departments.where((dept) {
      final name = dept['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: Colors.indigo,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.complaintPermissions, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(l10n.manageDepartmentAccess, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.enableComplaintAccessDescription,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Search
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchDepartments,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDepartments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchQuery.isEmpty
                                ? l10n.noDepartmentsFound
                                : l10n.noDepartmentsMatchSearch,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredDepartments.length,
                      itemBuilder: (context, index) {
                        final dept = _filteredDepartments[index];
                        final deptId = dept['id'];
                        final hasAccess = _permissions[deptId] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasAccess
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hasAccess
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasAccess ? Icons.check_circle : Icons.block,
                                color: hasAccess ? Colors.green : Colors.grey,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              dept['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                hasAccess
                                    ? l10n.canAccessComplaints
                                    : l10n.noComplaintAccess,
                                style: TextStyle(
                                  color: hasAccess ? Colors.green : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            trailing: Switch(
                              value: hasAccess,
                              onChanged: (value) =>
                                  _togglePermission(deptId, value),
                              activeColor: Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _togglePermission(String departmentId, bool newValue) async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      final existing = await supabase
          .from('department_complaint_permissions')
          .select()
          .eq('department_id', departmentId)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('department_complaint_permissions').insert({
          'department_id': departmentId,
          'can_access_complaints': newValue,
        });
      } else {
        await supabase
            .from('department_complaint_permissions')
            .update({'can_access_complaints': newValue}).eq(
                'department_id', departmentId);
      }

      setState(() {
        _permissions[departmentId] = newValue;
      });

      _showSuccess(
        newValue ? l10n.complaintAccessEnabled : l10n.complaintAccessDisabled,
      );
    } catch (e) {
      _showError(l10n.failedToUpdatePermission);
    }
  }
}

class AutoApprovalSettingsWidget extends StatefulWidget {
  final UserModel currentUser;

  const AutoApprovalSettingsWidget({super.key, required this.currentUser});

  @override
  State<AutoApprovalSettingsWidget> createState() =>
      _AutoApprovalSettingsWidgetState();
}

class _AutoApprovalSettingsWidgetState extends State<AutoApprovalSettingsWidget>
    with AutomaticKeepAliveClientMixin {
  int _currentMinutes = 1440;
  bool _isLoading = false;
  int _eligibleTickets = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final minutes = await NotificationService.getAutoApprovalMinutes();
      final eligible = await NotificationService.checkAutoApprovalEligible();

      if (mounted) {
        setState(() {
          _currentMinutes = minutes;
          _eligibleTickets = eligible;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

// Replace the _updateSettings method
  Future<void> _updateSettings(int newMinutes) async {
    setState(() => _isLoading = true);

    try {
      final success = await NotificationService.updateAutoApprovalMinutes(
        newMinutes,
        widget.currentUser.id,
      );

      if (success) {
        // Update local state immediately
        setState(() {
          _currentMinutes = newMinutes;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-approval time updated to ${_formatDuration(newMinutes)}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDuration(int minutes) {
    final l10n = AppLocalizations.safeOf(context);

    if (minutes < 60) return '$minutes ${l10n.minutes}';
    if (minutes < 1440) {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      return mins > 0
          ? '$hours ${l10n.hours} $mins ${l10n.minutes}'
          : '$hours ${l10n.hours}';
    }
    final days = (minutes / 1440).floor();
    final hours = ((minutes % 1440) / 60).floor();
    if (hours > 0) return '$days ${l10n.days} $hours ${l10n.hours}';
    return '$days ${l10n.days}';
  }

  void _showEditDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final controller = TextEditingController(text: _currentMinutes.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.setAutoApprovalTime,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.minutes,
                helperText: l10n.minimum1Minute,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commonValues,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 5 = 5 ${l10n.minutes}\n'
                    '• 15 = 15 ${l10n.minutes}\n'
                    '• 30 = 30 ${l10n.minutes}\n'
                    '• 60 = 1 ${l10n.hour}\n'
                    '• 720 = 12 ${l10n.hours}\n'
                    '• 1440 = 24 ${l10n.hours}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes >= 1) {
                Navigator.pop(context);
                _updateSettings(minutes);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.pleaseEnterValidNumber),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.update),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualApproval() async {
    final l10n = AppLocalizations.safeOf(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.triggerAutoApproval),
        content: Text(
          '${l10n.thisWillImmediatelyAutoApprove.replaceAll('{count}', _eligibleTickets.toString())}\n\n'
          '${l10n.areYouSure}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.approveNow),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      final success = await NotificationService.triggerAutoApproval();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    success
                        ? l10n.autoApprovalCompletedSuccessfully
                        : l10n.errorTriggeringAutoApproval,
                  ),
                ),
              ],
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadSettings();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.schedule, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.autoApprovalSettings, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        l10n.automaticallyApprovePrefinishedTickets,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.1),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.timer, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.currentAutoApprovalTime,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(_currentMinutes),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue, size: 20),
                        onPressed: _showEditDialog,
                        tooltip: l10n.editTime,
                      ),
                    ),
                  ],
                ),
              ),
              if (_eligibleTickets > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warning,
                            color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.ticketsReadyForAutoApproval.replaceAll(
                              '{count}', _eligibleTickets.toString()),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _triggerManualApproval,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(l10n.approveNow),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l10n.howItWorks,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n.autoApprovalInfo1}\n'
                      '• ${l10n.autoApprovalInfo2}\n'
                      '• ${l10n.autoApprovalInfo3}\n'
                      '• ${l10n.autoApprovalInfo4}',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AutoAssignmentSettingsWidget extends StatefulWidget {
  final UserModel currentUser;

  const AutoAssignmentSettingsWidget({super.key, required this.currentUser});

  @override
  State<AutoAssignmentSettingsWidget> createState() =>
      _AutoAssignmentSettingsWidgetState();
}

class _AutoAssignmentSettingsWidgetState
    extends State<AutoAssignmentSettingsWidget>
    with AutomaticKeepAliveClientMixin {
  AutoAssignmentSettings? _currentSettings;
  List<UserModel> _departmentAdmins = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (widget.currentUser.departmentId == null) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Load current settings
      final settingsResponse = await supabase
          .from('auto_assignment_settings')
          .select()
          .eq('department_id', widget.currentUser.departmentId!)
          .maybeSingle();

      if (settingsResponse != null) {
        _currentSettings = AutoAssignmentSettings.fromJson(settingsResponse);
      }

      // Load department admins (normal admins only, not super admins)
      final adminsResponse = await supabase
          .from('users')
          .select()
          .eq('department_id', widget.currentUser.departmentId!)
          .eq('user_type', 'admin')
          .eq('is_active', true)
          .order('full_name');

      if (mounted) {
        setState(() {
          _departmentAdmins = adminsResponse
              .map<UserModel>((json) => UserModel.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading auto-assignment settings: $e');
      if (mounted) {
        _showError('Failed to load settings');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveSettings({
    required bool isEnabled,
    String? assignedAdminId,
  }) async {
    final l10n = AppLocalizations.safeOf(context);

    if (widget.currentUser.departmentId == null) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'department_id': widget.currentUser.departmentId!,
        'is_enabled': isEnabled,
        'assigned_admin_id': assignedAdminId,
        'created_by': widget.currentUser.id,
      };

      if (_currentSettings == null) {
        await supabase.from('auto_assignment_settings').insert(data);
      } else {
        await supabase
            .from('auto_assignment_settings')
            .update(data)
            .eq('department_id', widget.currentUser.departmentId!);
      }

      await _loadSettings();

      if (mounted) {
        _showSuccess(
          isEnabled
              ? l10n.autoAssignmentEnabledSuccessfully
              : l10n.autoAssignmentDisabledSuccessfully,
        );
      }
    } catch (e) {
      print('Error saving auto-assignment settings: $e');
      if (mounted) {
        _showError(l10n.failedToSaveSettings);
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildAdminDropdown(String? selectedAdminId) {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.assignNewTicketsTo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.chooseWhichAdminWillReceive,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: DropdownButtonFormField<String>(
            value: selectedAdminId,
            isExpanded: true,
            isDense: false,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(
                Icons.person,
                color: Colors.indigo,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: _departmentAdmins.map((admin) {
              return DropdownMenuItem<String>(
                value: admin.id,
                child: Text(
                  '${admin.fullName} • ${admin.email}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value != null) {
                      _saveSettings(
                        isEnabled: _currentSettings?.isEnabled ?? false,
                        assignedAdminId: value,
                      );
                    }
                  },
            menuMaxHeight: 300,
            icon: const Icon(Icons.arrow_drop_down),
            elevation: 8,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            dropdownColor: Colors.white,
          ),
        ),
        if (selectedAdminId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.indigo.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _departmentAdmins
                          .firstWhere(
                            (a) => a.id == selectedAdminId,
                            orElse: () => _departmentAdmins.first,
                          )
                          .fullName[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectedAdmin,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _departmentAdmins
                            .firstWhere(
                              (a) => a.id == selectedAdminId,
                              orElse: () => _departmentAdmins.first,
                            )
                            .fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _departmentAdmins
                            .firstWhere(
                              (a) => a.id == selectedAdminId,
                              orElse: () => _departmentAdmins.first,
                            )
                            .email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    if (widget.currentUser.userType != UserType.superAdmin) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  color: Colors.orange,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.accessRestricted,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onlySuperAdminsCanManage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loadingSettings),
          ],
        ),
      );
    }

    final isEnabled = _currentSettings?.isEnabled ?? false;
    final selectedAdminId = _currentSettings?.assignedAdminId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.autorenew,
                    color: Colors.indigo,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.autoAssignmentSettings, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        l10n.automaticallyAssignNewTickets,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.1),
            ),
            const SizedBox(height: 20),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.howItWorks,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• ${l10n.autoAssignmentHowItWorks1}\n'
                    '• ${l10n.autoAssignmentHowItWorks2}\n'
                    '• ${l10n.autoAssignmentHowItWorks3}\n'
                    '• ${l10n.autoAssignmentHowItWorks4}',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Enable/Disable Switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEnabled ? Icons.check_circle : Icons.cancel,
                      color: isEnabled ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.autoAssignmentStatus,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEnabled
                              ? l10n.newTicketsWillBeAutomaticallyAssigned
                              : l10n.newTicketsWillRequireManualAssignment,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: isEnabled,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value &&
                                (selectedAdminId == null ||
                                    _departmentAdmins.isEmpty)) {
                              _showError(l10n.pleaseSelectAdminBeforeEnabling);
                              return;
                            }
                            _saveSettings(
                              isEnabled: value,
                              assignedAdminId: selectedAdminId,
                            );
                          },
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Admin Selection
            if (_departmentAdmins.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning,
                        color: Colors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.noNormalAdminsFound,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildAdminDropdown(selectedAdminId),

            if (_isSaving)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        l10n.savingSettings,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Active Status
            if (isEnabled && selectedAdminId != null && !_isSaving) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${l10n.autoAssignmentIsActive} ${_departmentAdmins.firstWhere((a) => a.id == selectedAdminId, orElse: () => _departmentAdmins.first).fullName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// OPTIMIZED NOTIFICATION PREFERENCES
// ============================================================================
class NotificationPreferencesWidget extends StatefulWidget {
  final UserModel currentUser;

  const NotificationPreferencesWidget({super.key, required this.currentUser});

  @override
  State<NotificationPreferencesWidget> createState() =>
      _NotificationPreferencesWidgetState();
}

class _NotificationPreferencesWidgetState
    extends State<NotificationPreferencesWidget>
    with AutomaticKeepAliveClientMixin {
  NotificationPreferences? _preferences;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', widget.currentUser.id)
          .maybeSingle();

      if (response != null) {
        if (mounted) {
          setState(() {
            _preferences = NotificationPreferences.fromJson(response);
          });
        }
      } else {
        // Create default preferences
        await supabase.from('notification_preferences').insert({
          'user_id': widget.currentUser.id,
          'push_notifications_enabled': true,
          'push_chat_messages_enabled': true,
          'email_notifications_enabled': true,
        });
        await _loadPreferences();
        return;
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
      if (mounted) {
        _showError(AppLocalizations.safeOf(context).failedToLoadPreferences);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updatePreference(String field, bool value) async {
    setState(() => _isSaving = true);

    try {
      await supabase
          .from('notification_preferences')
          .update({field: value}).eq('user_id', widget.currentUser.id);

      await _loadPreferences();

      if (mounted) {
        _showSuccess(
            AppLocalizations.safeOf(context).preferencesUpdatedSuccessfully);
      }
    } catch (e) {
      print('Error updating notification preferences: $e');
      if (mounted) {
        _showError(AppLocalizations.safeOf(context).failedToUpdatePreferences);
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required String field,
    bool isSubPreference = false,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isSubPreference ? 16 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? iconColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: _isSaving ? null : (val) => _updatePreference(field, val),
          activeColor: iconColor,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isEnabled, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isEnabled ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isEnabled ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isEnabled
                ? AppLocalizations.safeOf(context).on
                : AppLocalizations.safeOf(context).off,
            style: TextStyle(
              fontSize: 10,
              color: isEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    // Calculate bottom padding for floating nav bar
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_preferences == null) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomNavBarHeight + 24,
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.couldNotLoadPreferences,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadPreferences,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomNavBarHeight + 24,
      ),
      physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.purple,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.notificationPreferences, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        l10n.manageHowYouReceiveNotifications,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.1),
            ),
            const SizedBox(height: 20),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.aboutNotifications,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• ${l10n.notificationsInfo1}\n'
                    '• ${l10n.notificationsInfo2}\n'
                    '• ${l10n.notificationsInfo3}\n'
                    '• ${l10n.notificationsInfo4}',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Push Notifications Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.pushNotifications,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildPreferenceCard(
              icon: Icons.notifications_active,
              iconColor: Colors.orange,
              title: l10n.enablePushNotifications,
              subtitle: l10n.receivePushNotificationsOnDevice,
              value: _preferences!.pushNotificationsEnabled,
              field: 'push_notifications_enabled',
            ),

            if (_preferences!.pushNotificationsEnabled)
              _buildPreferenceCard(
                icon: Icons.chat_bubble,
                iconColor: Colors.blue,
                title: l10n.chatMessageNotifications,
                subtitle: l10n.getNotifiedNewChatMessages,
                value: _preferences!.pushChatMessagesEnabled,
                field: 'push_chat_messages_enabled',
                isSubPreference: true,
              ),

            const SizedBox(height: 24),

            // Email Notifications Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.email,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.emailNotifications,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildPreferenceCard(
              icon: Icons.email,
              iconColor: Colors.teal,
              title: l10n.enableEmailNotifications,
              subtitle: l10n.receiveNotificationsViaEmail,
              value: _preferences!.emailNotificationsEnabled,
              field: 'email_notifications_enabled',
            ),

            if (_isSaving)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        l10n.savingPreferences,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Current Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.currentStatus,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusChip(
                          l10n.push,
                          _preferences!.pushNotificationsEnabled,
                          Icons.notifications,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusChip(
                          l10n.chat,
                          _preferences!.pushChatMessagesEnabled,
                          Icons.chat,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusChip(
                          l10n.email,
                          _preferences!.emailNotificationsEnabled,
                          Icons.email,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
