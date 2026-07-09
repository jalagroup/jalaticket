import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'cc_models.dart';
import 'cc_service.dart';
import 'cc_submission_flow_screen.dart';

class CcSubmissionListScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool embedded;

  const CcSubmissionListScreen({super.key, required this.currentUser, this.embedded = false});

  @override
  State<CcSubmissionListScreen> createState() => _CcSubmissionListScreenState();
}

class _CcSubmissionListScreenState extends State<CcSubmissionListScreen> {
  List<CcForm> _forms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final forms = await CcService.getFormsForCurrentUser();
    setState(() {
      _forms = forms;
      _loading = false;
    });
  }

  Future<void> _openForm(CcForm form) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CcSubmissionFlowScreen(formId: form.id, currentUser: widget.currentUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 768 ? 1 : (width < 1024 ? 2 : 3);

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _forms.isEmpty
            ? _EmptyState(isAr: isAr)
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
                  itemBuilder: (ctx, i) => _FormCard(
                    form: _forms[i],
                    isAr: isAr,
                    onTap: () => _openForm(_forms[i]),
                  ),
                ),
              );

    if (widget.embedded) {
      return Container(color: Colors.grey[50], child: body);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.customComplaints,
          style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold),
        ),
      ),
      body: body,
    );
  }
}

class _FormCard extends StatelessWidget {
  final CcForm form;
  final bool isAr;
  final VoidCallback onTap;

  const _FormCard({required this.form, required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = form.themeColorValue;
    final fg = form.contrastTextColor;
    final isNearWhite = bg.computeLuminance() > 0.85;
    final btnColor = isNearWhite ? Colors.white : bg;
    final btnBg = isNearWhite ? AppColors.primary : Colors.white;

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
            // Row 1: logo + title
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: form.logoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            form.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.flag_outlined, color: bg, size: 16),
                          ),
                        )
                      : Icon(Icons.flag_outlined, color: bg, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    form.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: start button
            Row(
              children: [
                Material(
                  color: btnBg,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 14, color: btnColor),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'ابدأ' : 'Start',
                            style: TextStyle(
                                color: btnColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  const _EmptyState({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا توجد نماذج متاحة لك حالياً' : 'No forms are available to you right now',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
