import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel, UserType;
import 'fleet_service.dart';

/// Shows a searchable list of every active user (any role) and returns the
/// one picked, or null if cancelled. Used to link a vehicle's driver to a
/// real system user instead of free text.
Future<UserModel?> showFleetUserPicker(BuildContext context, {String? title}) {
  return showDialog<UserModel>(
    context: context,
    builder: (_) => _FleetUserPickerDialog(title: title),
  );
}

/// Same searchable list as [showFleetUserPicker], but with checkbox
/// multi-selection and a "Done" button instead of pop-on-tap. Used for
/// assigning multiple drivers to one vehicle.
Future<List<UserModel>?> showFleetUserMultiPicker(
  BuildContext context, {
  String? title,
  List<UserModel> initiallySelected = const [],
}) {
  return showDialog<List<UserModel>>(
    context: context,
    builder: (_) => _FleetUserMultiPickerDialog(title: title, initiallySelected: initiallySelected),
  );
}

String _roleLabel(UserType type, bool isAr) {
  switch (type) {
    case UserType.systemAdmin:
      return isAr ? 'مدير النظام' : 'System Admin';
    case UserType.superAdmin:
      return isAr ? 'مدير عام' : 'Super Admin';
    case UserType.admin:
      return isAr ? 'مدير' : 'Admin';
    case UserType.branchAdmin:
      return isAr ? 'مدير فرع' : 'Branch Admin';
    case UserType.superUser:
      return isAr ? 'مستخدم متميز' : 'Super User';
    case UserType.user:
      return isAr ? 'مستخدم' : 'User';
  }
}

class _FleetUserPickerDialog extends StatefulWidget {
  final String? title;
  const _FleetUserPickerDialog({this.title});

  @override
  State<_FleetUserPickerDialog> createState() => _FleetUserPickerDialogState();
}

class _FleetUserPickerDialogState extends State<_FleetUserPickerDialog> {
  List<UserModel> _users = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final users = await FleetService.getAllActiveUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _filtered = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  (u.phone ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? (isAr ? 'اختر مستخدم' : 'Select a user'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[850]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isAr ? 'ابحث بالاسم أو البريد أو الهاتف...' : 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            isAr ? 'لا يوجد مستخدمون' : 'No users found',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                [if ((u.phone ?? '').isNotEmpty) u.phone!, u.email].join(' · '),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _roleLabel(u.userType, isAr),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                ),
                              ),
                              onTap: () => Navigator.pop(context, u),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetUserMultiPickerDialog extends StatefulWidget {
  final String? title;
  final List<UserModel> initiallySelected;
  const _FleetUserMultiPickerDialog({this.title, this.initiallySelected = const []});

  @override
  State<_FleetUserMultiPickerDialog> createState() => _FleetUserMultiPickerDialogState();
}

class _FleetUserMultiPickerDialogState extends State<_FleetUserMultiPickerDialog> {
  List<UserModel> _users = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  late Set<String> _selectedIds;
  late Map<String, UserModel> _selectedById;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelected.map((u) => u.id).toSet();
    _selectedById = {for (final u in widget.initiallySelected) u.id: u};
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final users = await FleetService.getAllActiveUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _filtered = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              return u.fullName.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  (u.phone ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  void _toggle(UserModel u) {
    setState(() {
      if (_selectedIds.contains(u.id)) {
        _selectedIds.remove(u.id);
        _selectedById.remove(u.id);
      } else {
        _selectedIds.add(u.id);
        _selectedById[u.id] = u;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 420,
        height: 560,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? (isAr ? 'اختر مستخدمين' : 'Select users'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[850]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isAr ? 'ابحث بالاسم أو البريد أو الهاتف...' : 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            isAr ? 'لا يوجد مستخدمون' : 'No users found',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final u = _filtered[i];
                            final selected = _selectedIds.contains(u.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (_) => _toggle(u),
                              activeColor: AppColors.primary,
                              secondary: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                [if ((u.phone ?? '').isNotEmpty) u.phone!, u.email].join(' · '),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr ? '${_selectedIds.length} محدد' : '${_selectedIds.length} selected',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context, _selectedById.values.toList()),
                    child: Text(isAr ? 'تم' : 'Done'),
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
