import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show AppColors;
import 'email_template_editor_panel.dart';
import 'email_template_models.dart';
import 'email_template_preview.dart';
import 'email_template_service.dart';

class EmailTemplateDesignerScreen extends StatefulWidget {
  const EmailTemplateDesignerScreen({super.key});

  @override
  State<EmailTemplateDesignerScreen> createState() => _EmailTemplateDesignerScreenState();
}

class _EmailTemplateDesignerScreenState extends State<EmailTemplateDesignerScreen> {
  EmailTemplate? _template;
  bool _loading = true;
  bool _saving = false;
  bool _sendingTest = false;
  final _htmlCtrl = TextEditingController();

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
    _htmlCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _htmlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await EmailTemplateService.load() ?? EmailTemplate.blank();
    _htmlCtrl.text = t.htmlSource ?? '';
    setState(() {
      _template = t;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final t = _template;
    if (t == null) return;
    setState(() => _saving = true);
    try {
      t.htmlSource = _htmlCtrl.text;
      final saved = await EmailTemplateService.save(t);
      if (!mounted) return;
      setState(() => _template = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAr ? 'تم حفظ القالب' : 'Template saved'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAr ? 'فشل الحفظ: $e' : 'Save failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTest() async {
    final t = _template;
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (t == null || email == null) return;
    setState(() => _sendingTest = true);
    try {
      await EmailTemplateService.sendTest(
        to: email,
        mode: t.mode,
        blocks: t.blocks,
        htmlSource: _htmlCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAr ? 'تم إرسال بريد تجريبي إلى $email' : 'Test email sent to $email'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAr ? 'فشل الإرسال: $e' : 'Send failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _template == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final t = _template!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isAr ? 'مصمم قالب البريد الإلكتروني' : 'Email Template Designer',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onBackground),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _sendingTest ? null : _sendTest,
                icon: _sendingTest
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 16),
                label: Text(_isAr ? 'إرسال تجربة لي' : 'Send test email to myself'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_isAr ? 'حفظ' : 'Save'),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final editor = EmailTemplateEditorPanel(
                mode: t.mode,
                blocks: t.blocks,
                htmlController: _htmlCtrl,
                mergeFields: kEmailMergeFields,
                onModeChanged: (m) => setState(() => t.mode = m),
                onChanged: () => setState(() {}),
              );
              final preview = EmailTemplatePreview(
                mode: t.mode,
                blocks: t.blocks,
                htmlSource: _htmlCtrl.text,
              );
              if (!wide) {
                return Column(
                  children: [
                    Expanded(child: editor),
                    Container(height: 1, color: Colors.grey.shade200),
                    Expanded(child: preview),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: editor),
                  Container(width: 1, color: Colors.grey.shade200),
                  Expanded(child: preview),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
