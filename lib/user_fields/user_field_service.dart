import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jalasupport/models.dart';
import 'user_field_models.dart';

class UserFieldService {
  static final _db = Supabase.instance.client;

  static Future<List<UserFieldDefinition>> getDefinitions({bool activeOnly = false}) async {
    final q = _db.from('user_field_definitions').select();
    final res = activeOnly
        ? await q.eq('is_active', true).order('order_index')
        : await q.order('order_index');
    return (res as List).map((j) => UserFieldDefinition.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<UserFieldDefinition> createDefinition(Map<String, dynamic> data) async {
    final res = await _db.from('user_field_definitions').insert(data).select().single();
    return UserFieldDefinition.fromJson(res);
  }

  static Future<UserFieldDefinition> updateDefinition(String id, Map<String, dynamic> data) async {
    final res = await _db
        .from('user_field_definitions')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return UserFieldDefinition.fromJson(res);
  }

  static Future<void> deleteDefinition(String id) async {
    await _db.from('user_field_definitions').delete().eq('id', id);
  }

  static Future<void> reorderDefinitions(List<String> orderedIds) async {
    await Future.wait(orderedIds.asMap().entries.map((e) =>
        _db.from('user_field_definitions').update({'order_index': e.key}).eq('id', e.value)));
  }

  static Future<List<UserFieldValue>> getValuesForUser(String userId) async {
    final res = await _db.from('user_field_values').select().eq('user_id', userId);
    return (res as List).map((j) => UserFieldValue.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, List<UserFieldValue>>> getValuesForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _db.from('user_field_values').select().inFilter('user_id', userIds);
    final values = (res as List).map((j) => UserFieldValue.fromJson(j as Map<String, dynamic>)).toList();
    final map = <String, List<UserFieldValue>>{};
    for (final v in values) {
      map.putIfAbsent(v.userId, () => []).add(v);
    }
    return map;
  }

  static Future<void> upsertValue({
    required String userId,
    required String fieldId,
    required dynamic value,
    required String filledByUserId,
  }) async {
    await _db.from('user_field_values').upsert({
      'user_id': userId,
      'field_id': fieldId,
      'value': value,
      'filled_by_user_id': filledByUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,field_id');
  }

  static Future<List<UserFieldDefinition>> getMissingBlockingFields(String userId) async {
    final defsRes = await _db
        .from('user_field_definitions')
        .select()
        .eq('is_active', true)
        .eq('blocks_user_until_filled', true)
        .inFilter('fill_mode', ['user_only', 'both'])
        .order('order_index');

    final defs = (defsRes as List)
        .map((j) => UserFieldDefinition.fromJson(j as Map<String, dynamic>))
        .toList();

    if (defs.isEmpty) return [];

    final defIds = defs.map((d) => d.id).toList();
    final filledRes = await _db
        .from('user_field_values')
        .select('field_id, value')
        .eq('user_id', userId)
        .inFilter('field_id', defIds);

    final filledIds = (filledRes as List)
        .where((v) => v['value'] != null)
        .map((v) => v['field_id'] as String)
        .toSet();

    return defs.where((d) => !filledIds.contains(d.id)).toList();
  }

  static String evaluateFormula({
    required String formula,
    required UserModel user,
    required List<UserFieldDefinition> allDefs,
    required List<UserFieldValue> userValues,
  }) {
    var result = formula;
    result = result.replaceAll('{{user.name}}', user.fullName);
    result = result.replaceAll('{{user.email}}', user.email);
    result = result.replaceAll('{{user.phone}}', user.phone ?? '');
    result = result.replaceAll('{{user.type}}', user.userType.value.replaceAll('_', ' '));
    for (final def in allDefs) {
      if (!def.isComputed) {
        final val = userValues.where((v) => v.fieldId == def.id).firstOrNull;
        result = result.replaceAll('{{field.${def.label}}}', val?.displayValue ?? '');
        if (def.labelAr != null) {
          result = result.replaceAll('{{field.${def.labelAr}}}', val?.displayValue ?? '');
        }
      }
    }
    return result.trim();
  }
}
