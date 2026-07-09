import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import 'cc_models.dart';
import 'cc_service.dart';
import 'cc_submission_flow_screen.dart';

/// Public, no-login submission page reached via the shareable static URL
/// `/c/submit/{formId}`. Loads the form anonymously (allowed by RLS only
/// when the form has external submissions enabled) and reuses the same
/// fill flow as the authenticated screen, with no submitter identity.
class CcExternalScreen extends StatefulWidget {
  final String formId;

  const CcExternalScreen({super.key, required this.formId});

  @override
  State<CcExternalScreen> createState() => _CcExternalScreenState();
}

class _CcExternalScreenState extends State<CcExternalScreen> {
  CcForm? _form;
  bool _loading = true;
  bool _notAvailable = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final form = await CcService.getFullForm(widget.formId);
      setState(() {
        _form = form;
        _notAvailable = form == null || !form.externalApplyEnabled || !form.isActive;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _notAvailable = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_notAvailable || _form == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_rounded, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'هذا الرابط غير متاح حالياً' : 'This link is not available right now',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_done) {
      return Scaffold(
        backgroundColor: _form!.themeColorValue,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 64, color: _form!.contrastTextColor),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'تم الإرسال بنجاح، يمكنك إغلاق هذه الصفحة الآن' : 'Submitted successfully — you can close this page now',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _form!.contrastTextColor, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CcFormFillView(
      form: _form!,
      currentUserId: null,
      currentUserFullName: null,
      deviceType: CcService.detectDeviceType(MediaQuery.of(context).size.width),
      onCompleted: () => setState(() => _done = true),
    );
  }
}
