import 'package:flutter/material.dart';
import 'main.dart' show AppColors, supabase;
import 'models.dart' show UserModel, UserType;

/// Shows a searchable list of every active user (any role) and returns the
/// one picked, or null if cancelled. General-purpose — e.g. assigning a
/// user's direct manager in User Management. Pass [excludeUserId] to keep a
/// user from being able to pick themselves (e.g. as their own manager).
Future<UserModel?> showUserPicker(BuildContext context, {String? title, String? excludeUserId}) {
  return showDialog<UserModel>(
    context: context,
    builder: (_) => _UserPickerDialog(title: title, excludeUserId: excludeUserId),
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

class _UserPickerDialog extends StatefulWidget {
  final String? title;
  final String? excludeUserId;
  const _UserPickerDialog({this.title, this.excludeUserId});

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
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
      final rows = await supabase
          .from('users')
          .select()
          .eq('is_active', true)
          .order('full_name');
      var users = rows.map<UserModel>((j) => UserModel.fromJson(j)).toList();
      if (widget.excludeUserId != null) {
        users = users.where((u) => u.id != widget.excludeUserId).toList();
      }
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
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
