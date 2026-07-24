import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_template_models.dart';

final _sb = Supabase.instance.client;

class EmailTemplateService {
  static Future<EmailTemplate?> load() async {
    final row = await _sb
        .from('email_templates')
        .select('*')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row != null ? EmailTemplate.fromJson(row) : null;
  }

  static Future<EmailTemplate> save(EmailTemplate template) async {
    final uid = _sb.auth.currentUser?.id;
    final ownerRow = uid != null
        ? await _sb.from('users').select('id').eq('auth_id', uid).maybeSingle()
        : null;
    final payload = {
      ...template.toJson(),
      'updated_by': ownerRow?['id'],
      'updated_at': DateTime.now().toIso8601String(),
    };
    final row = template.id != null
        ? await _sb.from('email_templates').update(payload).eq('id', template.id!).select().single()
        : await _sb.from('email_templates').insert(payload).select().single();
    return EmailTemplate.fromJson(row);
  }

  static Future<void> sendTest({
    required String to,
    required EmailTemplateMode mode,
    required List<EmailTemplateBlock> blocks,
    required String? htmlSource,
  }) async {
    await _sb.functions.invoke('send-email', body: {
      'to': to,
      'subject': 'Email Template Preview',
      'title': 'Sample Notification',
      'message': 'This is a preview of your email template. Replace this with a real ticket, chat, or reminder message once you save.',
      'recipient_name': 'Preview User',
      // Send the unsaved draft along so "send test" reflects edits before Save.
      'preview_mode': mode.value,
      'preview_blocks': blocks.map((b) => b.toJson()).toList(),
      'preview_html_source': htmlSource,
    });
  }
}
