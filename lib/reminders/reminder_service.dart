import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reminder_models.dart';

final _sb = Supabase.instance.client;

class ReminderService {
  static Future<String?> _currentUserId() async {
    final authId = _sb.auth.currentUser?.id;
    if (authId == null) return null;
    final row = await _sb.from('users').select('id').eq('auth_id', authId).maybeSingle();
    return row?['id'] as String?;
  }

  static Future<List<SmartReminder>> getAll() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    final rows = await _sb
        .from('reminders')
        .select('*')
        .eq('owner_user_id', uid)
        .order('created_at', ascending: false);
    return rows.map((r) => SmartReminder.fromJson(r)).toList();
  }

  static Future<SmartReminder?> getById(String id) async {
    final row = await _sb.from('reminders').select('*').eq('id', id).maybeSingle();
    return row != null ? SmartReminder.fromJson(row) : null;
  }

  static Future<SmartReminder> create(SmartReminder r) async {
    final row = await _sb.from('reminders').insert(r.toJson()).select().single();
    return SmartReminder.fromJson(row);
  }

  static Future<void> update(String id, Map<String, dynamic> data) async {
    await _sb.from('reminders').update({...data, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _sb.from('reminders').delete().eq('id', id);
  }

  static Future<void> toggle(String id, bool isActive) async {
    await _sb.from('reminders').update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  static Future<void> runNow(String reminderId) async {
    await _sb.functions.invoke('execute-reminder', body: {'reminder_id': reminderId});
  }

  static Future<List<ReminderRun>> getRuns(String reminderId, {int limit = 30}) async {
    final rows = await _sb
        .from('reminder_runs')
        .select('*')
        .eq('reminder_id', reminderId)
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map((r) => ReminderRun.fromJson(r)).toList();
  }

  static Future<List<String>> previewFields(
      ReminderDataSourceType type, Map<String, dynamic> config) async {
    try {
      switch (type) {
        case ReminderDataSourceType.api:
          final url = config['url'] as String? ?? '';
          if (url.isEmpty) return [];
          final headers = Map<String, String>.from(
              (config['headers'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())));
          final method = config['method'] as String? ?? 'GET';
          http.Response response;
          if (method == 'POST') {
            response = await http.post(Uri.parse(url), headers: headers,
                body: config['body'] != null ? jsonEncode(config['body']) : null);
          } else {
            response = await http.get(Uri.parse(url), headers: headers);
          }
          if (response.statusCode >= 400) return [];
          dynamic data = jsonDecode(response.body);
          final path = config['response_array_path'] as String?;
          if (path != null && path.isNotEmpty) {
            for (final key in path.split('.')) {
              data = data is Map ? data[key] : null;
              if (data == null) break;
            }
          }
          final arr = data is List ? data : [data];
          if (arr.isEmpty) return [];
          return (arr.first as Map? ?? {}).keys.map((k) => k.toString()).toList();

        case ReminderDataSourceType.internal:
          final table = config['table'] as String? ?? '';
          if (table.isEmpty) return [];
          final cols = config['select_columns'] as String? ?? '*';
          final row = await _sb.from(table).select(cols).limit(1).maybeSingle();
          return row?.keys.toList() ?? [];

        case ReminderDataSourceType.excel:
          final records = config['records'] as List? ?? [];
          if (records.isEmpty) return [];
          return (records.first as Map? ?? {}).keys.map((k) => k.toString()).toList();
      }
    } catch (e) {
      debugPrint('[ReminderService] previewFields error: $e');
      return [];
    }
  }

  static Future<List<String>> getAvailableTables() async {
    try {
      final rows = await _sb.rpc('get_public_tables');
      return List<String>.from(rows as List? ?? []);
    } catch (_) {
      return ['users', 'tickets', 'cc_submissions', 'cc_forms'];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final rows = await _sb
          .from('users')
          .select('id, full_name, email')
          .eq('is_active', true)
          .order('full_name', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
