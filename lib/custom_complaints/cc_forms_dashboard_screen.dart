import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'cc_models.dart';
import 'cc_service.dart';
import 'cc_form_builder_screen.dart';
import 'cc_records_screen.dart';

class CcFormsDashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool embedded;

  const CcFormsDashboardScreen({super.key, required this.currentUser, this.embedded = false});

  @override
  State<CcFormsDashboardScreen> createState() => _CcFormsDashboardScreenState();
}

class _CcFormsDashboardScreenState extends State<CcFormsDashboardScreen> {
  List<CcForm> _forms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final forms = await CcService.getMyForms();
    setState(() {
      _forms = forms;
      _loading = false;
    });
  }

  Future<void> _createForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CcFormBuilderScreen(currentUser: widget.currentUser)),
    );
    _load();
  }

  Future<void> _editForm(CcForm form) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CcFormBuilderScreen(currentUser: widget.currentUser, editFormId: form.id)),
    );
    _load();
  }

  void _viewRecords(CcForm form) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CcRecordsScreen(formId: form.id)),
    );
  }

  Future<void> _deleteForm(CcForm form) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAr ? 'حذف النموذج' : 'Delete form'),
        content: Text(isAr
            ? 'هل أنت متأكد من حذف "${form.title}"؟ سيتم حذف جميع السجلات المرتبطة به.'
            : 'Delete "${form.title}"? All related records will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CcService.deleteForm(form.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 768 ? 1 : (width < 1100 ? 2 : 3);

    final newFormButton = ElevatedButton.icon(
      onPressed: _createForm,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(isAr ? 'نموذج جديد' : 'New form'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final grid = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _forms.isEmpty
            ? _EmptyState(isAr: isAr, onCreate: _createForm)
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 90,
                  ),
                  itemCount: _forms.length,
                  itemBuilder: (ctx, i) => _FormManageCard(
                    form: _forms[i],
                    isAr: isAr,
                    onEdit: () => _editForm(_forms[i]),
                    onRecords: () => _viewRecords(_forms[i]),
                    onDelete: () => _deleteForm(_forms[i]),
                  ),
                ),
              );

    if (widget.embedded) {
      return Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Align(alignment: Alignment.centerRight, child: newFormButton),
            ),
            Expanded(child: grid),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isAr ? 'نماذجي' : 'My Forms',
            style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: newFormButton),
        ],
      ),
      body: grid,
    );
  }
}

class _FormManageCard extends StatelessWidget {
  final CcForm form;
  final bool isAr;
  final VoidCallback onEdit;
  final VoidCallback onRecords;
  final VoidCallback onDelete;

  const _FormManageCard({
    required this.form,
    required this.isAr,
    required this.onEdit,
    required this.onRecords,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = form.themeColorValue;
    final fg = form.contrastTextColor;
    final isNearWhite = bg.computeLuminance() > 0.85;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: logo + title + status chip
            Row(
              children: [
                _LogoCircle(logoUrl: form.logoUrl, fallbackColor: bg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    form.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    form.isActive ? (isAr ? 'نشط' : 'Active') : (isAr ? 'متوقف' : 'Inactive'),
                    style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: action buttons
            Row(
              children: [
                _ActionBtn(
                  label: isAr ? 'السجلات' : 'Records',
                  icon: Icons.list_alt_rounded,
                  color: isNearWhite ? Colors.white : bg,
                  bgColor: isNearWhite ? AppColors.primary : Colors.white,
                  onTap: onRecords,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: isAr ? 'تعديل' : 'Edit',
                  icon: Icons.edit_outlined,
                  color: isNearWhite ? Colors.white : bg,
                  bgColor: isNearWhite ? AppColors.primary : Colors.white,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: isAr ? 'حذف' : 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.white,
                  bgColor: Colors.red[400]!,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoCircle extends StatelessWidget {
  final String? logoUrl;
  final Color fallbackColor;

  const _LogoCircle({this.logoUrl, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: logoUrl != null
          ? ClipOval(
              child: Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.flag_outlined, color: fallbackColor, size: 16),
              ),
            )
          : Icon(Icons.flag_outlined, color: fallbackColor, size: 16),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final VoidCallback onCreate;
  const _EmptyState({required this.isAr, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لم تنشئ أي نموذج بعد' : "You haven't created any forms yet",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(isAr ? 'إنشاء نموذج' : 'Create a form'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
