import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'cc_models.dart';
import 'cc_service.dart';

/// Embedded inside the form builder as the "Audience" tab.
/// Lets the creator pick individual users and/or reusable groups,
/// and build/manage those groups right here without leaving the builder.
class CcAudiencePanel extends StatefulWidget {
  final CcForm form;
  final UserModel currentUser;

  const CcAudiencePanel({super.key, required this.form, required this.currentUser});

  @override
  State<CcAudiencePanel> createState() => _CcAudiencePanelState();
}

class _CcAudiencePanelState extends State<CcAudiencePanel> {
  List<CcGroup> _groups = [];
  List<Map<String, dynamic>> _allUsers = [];
  Set<String> _selectedUserIds = {};
  Set<String> _selectedGroupIds = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await CcService.getMyGroups();
    final users = await CcService.getAllUsers();
    final audience = await CcService.getFormAudience(widget.form.id);
    setState(() {
      _groups = groups;
      _allUsers = users;
      _selectedUserIds = audience.where((a) => a.userId != null).map((a) => a.userId!).toSet();
      _selectedGroupIds = audience.where((a) => a.groupId != null).map((a) => a.groupId!).toSet();
      _loading = false;
    });
  }

  Future<void> _save() async {
    await CcService.setFormAudience(
      widget.form.id,
      _selectedUserIds.toList(),
      _selectedGroupIds.toList(),
    );
    if (mounted) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم حفظ الجمهور' : 'Audience saved'), backgroundColor: AppColors.primary),
      );
    }
  }

  Future<void> _createGroupFlow() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'مجموعة جديدة' : 'New group'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: isAr ? 'اسم المجموعة' : 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isAr ? 'إنشاء' : 'Create', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final group = await CcService.createGroup(name);
    setState(() => _groups.insert(0, group));
    await _editGroupMembers(group);
  }

  Future<void> _editGroupMembers(CcGroup group) async {
    final fresh = await CcService.getGroupWithMembers(group.id) ?? group;
    final selected = fresh.members.map((m) => m.userId).toSet();
    if (!mounted) return;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _GroupMembersDialog(
        group: fresh,
        allUsers: _allUsers,
        initialSelected: selected,
      ),
    );
    if (result == null) return;
    await CcService.setGroupMembers(group.id, result.toList());
    if (mounted) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم تحديث أعضاء المجموعة' : 'Group members updated'), backgroundColor: AppColors.primary),
      );
    }
  }

  Future<void> _renameGroup(CcGroup group) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final ctrl = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'إعادة تسمية' : 'Rename group'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await CcService.renameGroup(group.id, name);
    setState(() => group.name = name);
  }

  Future<void> _deleteGroup(CcGroup group) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'حذف المجموعة؟' : 'Delete group?'),
        content: Text(isAr
            ? 'سيتم حذف "${group.name}" نهائياً. لن تتأثر النماذج التي استخدمتها سابقاً بأعضائها الفعليين.'
            : '"${group.name}" will be permanently deleted. Forms that previously used it keep their existing assignment until you remove it from them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await CcService.deleteGroup(group.id);
    setState(() {
      _groups.removeWhere((g) => g.id == group.id);
      _selectedGroupIds.remove(group.id);
    });
  }

  // Avatar background color from name
  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF1E40AF), Color(0xFF16A34A), Color(0xFF7C3AED),
      Color(0xFF0891B2), Color(0xFFDC2626), Color(0xFFD97706),
      Color(0xFF374151), Color(0xFF0F766E),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final filteredUsers = _allUsers.where((u) {
      if (_search.isEmpty) return true;
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || email.contains(_search.toLowerCase());
    }).toList();

    return Row(
      children: [
        // ── Groups column ──────────────────────────────────
        Container(
          width: 310,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            border: Border(right: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.group_outlined, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isAr ? 'المجموعات' : 'Groups',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                              if (_groups.isNotEmpty)
                                Text(
                                  '${_selectedGroupIds.length} ${isAr ? "محددة" : "selected"} · ${_groups.length} ${isAr ? "مجموعة" : "total"}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _createGroupFlow,
                          icon: const Icon(Icons.add_rounded, size: 15),
                          label: Text(isAr ? 'جديدة' : 'New', style: const TextStyle(fontSize: 11.5)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Groups list
              Expanded(
                child: _groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.group_outlined, size: 28, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 10),
                            Text(isAr ? 'لا توجد مجموعات بعد' : 'No groups yet',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                            const SizedBox(height: 4),
                            Text(
                              isAr ? 'أنشئ مجموعة لتنظيم المستخدمين' : 'Create a group to organize users',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _groups.length,
                        itemBuilder: (ctx, i) {
                          final g = _groups[i];
                          final checked = _selectedGroupIds.contains(g.id);
                          final color = _avatarColor(g.name);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: checked ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: checked ? AppColors.primary.withValues(alpha: 0.4) : Colors.grey[200]!,
                                width: checked ? 1.5 : 1,
                              ),
                              boxShadow: checked ? [] : [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => setState(() {
                                if (checked) _selectedGroupIds.remove(g.id);
                                else _selectedGroupIds.add(g.id);
                              }),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 18, height: 18,
                                      decoration: BoxDecoration(
                                        color: checked ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: checked ? AppColors.primary : Colors.grey[400]!, width: 1.5),
                                      ),
                                      child: checked
                                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    // Avatar
                                    Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _initials(g.name),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(g.name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: checked ? AppColors.primary : AppColors.secondary,
                                              ),
                                              overflow: TextOverflow.ellipsis),
                                          Text(
                                            isAr ? 'مجموعة محفوظة' : 'Saved group',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Actions menu
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey[500]),
                                      padding: EdgeInsets.zero,
                                      splashRadius: 16,
                                      onSelected: (v) {
                                        if (v == 'edit') _editGroupMembers(g);
                                        if (v == 'rename') _renameGroup(g);
                                        if (v == 'delete') _deleteGroup(g);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            const Icon(Icons.people_outline_rounded, size: 15),
                                            const SizedBox(width: 8),
                                            Text(isAr ? 'تعديل الأعضاء' : 'Edit members'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Row(children: [
                                            const Icon(Icons.drive_file_rename_outline_rounded, size: 15),
                                            const SizedBox(width: 8),
                                            Text(isAr ? 'إعادة تسمية' : 'Rename'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red[400]),
                                            const SizedBox(width: 8),
                                            Text(isAr ? 'حذف' : 'Delete', style: TextStyle(color: Colors.red[400])),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // ── Individual users column ────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                color: Colors.white,
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAr ? 'مستخدمون أفراد' : 'Individual Users',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                          Text(
                            '${_selectedUserIds.length} ${isAr ? "محدد" : "selected"} · ${_allUsers.length} ${isAr ? "مستخدم" : "users"}',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                color: Colors.white,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isAr ? 'ابحث بالاسم أو البريد...' : 'Search by name or email...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8F9FC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const Divider(height: 1),
              // Users list
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 36, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              _search.isEmpty
                                  ? (isAr ? 'لا يوجد مستخدمون' : 'No users found')
                                  : (isAr ? 'لا توجد نتائج' : 'No results'),
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filteredUsers.length,
                        itemBuilder: (ctx, i) {
                          final u = filteredUsers[i];
                          final id = u['id'] as String;
                          final checked = _selectedUserIds.contains(id);
                          final name = u['full_name']?.toString() ?? '';
                          final email = u['email']?.toString() ?? '';
                          final color = _avatarColor(name);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: checked ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: checked ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => setState(() {
                                if (checked) _selectedUserIds.remove(id);
                                else _selectedUserIds.add(id);
                              }),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 18, height: 18,
                                      decoration: BoxDecoration(
                                        color: checked ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: checked ? AppColors.primary : Colors.grey[300]!, width: 1.5),
                                      ),
                                      child: checked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 10),
                                    // Avatar
                                    Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(_initials(name),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Name + email
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: checked ? AppColors.primary : AppColors.secondary,
                                              ),
                                              overflow: TextOverflow.ellipsis),
                                          Text(email,
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    if (checked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isAr ? 'محدد' : 'Selected',
                                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupMembersDialog extends StatefulWidget {
  final CcGroup group;
  final List<Map<String, dynamic>> allUsers;
  final Set<String> initialSelected;

  const _GroupMembersDialog({
    required this.group,
    required this.allUsers,
    required this.initialSelected,
  });

  @override
  State<_GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<_GroupMembersDialog> {
  late Set<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelected);
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF1E40AF), Color(0xFF16A34A), Color(0xFF7C3AED),
      Color(0xFF0891B2), Color(0xFFDC2626), Color(0xFFD97706),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = widget.allUsers.where((u) {
      if (_search.isEmpty) return true;
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || email.contains(_search.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
        width: 460,
        height: 560,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.secondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_selected.length} ${isAr ? "عضو محدد" : "members selected"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isAr ? 'ابحث بالاسم أو البريد...' : 'Search by name or email...',
                  hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8F9FC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(isAr ? 'لا توجد نتائج' : 'No results', style: TextStyle(color: Colors.grey[400], fontSize: 13)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        final id = u['id'] as String;
                        final checked = _selected.contains(id);
                        final name = u['full_name']?.toString() ?? '';
                        final email = u['email']?.toString() ?? '';
                        final color = _avatarColor(name);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: checked ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: checked ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              if (checked) _selected.remove(id); else _selected.add(id);
                            }),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: checked ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: checked ? AppColors.primary : Colors.grey[300]!, width: 1.5),
                                    ),
                                    child: checked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                                    child: Center(child: Text(_initials(name), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: checked ? AppColors.primary : AppColors.secondary), overflow: TextOverflow.ellipsis),
                                        Text(email, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: Text(isAr ? 'حفظ التغييرات' : 'Save Changes'),
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
