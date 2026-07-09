import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cc_models.dart';

final _supabase = Supabase.instance.client;

class CcService {
  // ── Current user helpers ─────────────────────────────────

  static Future<String?> _currentUserId() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null) return null;
    final row = await _supabase
        .from('users')
        .select('id')
        .eq('auth_id', authId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  // ── Groups ────────────────────────────────────────────────

  static Future<List<CcGroup>> getMyGroups() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    final rows = await _supabase
        .from('cc_groups')
        .select('id, owner_user_id, name, created_at')
        .eq('owner_user_id', uid)
        .order('created_at', ascending: false);
    return rows.map((r) => CcGroup.fromJson(r)).toList();
  }

  static Future<CcGroup?> getGroupWithMembers(String groupId) async {
    final row = await _supabase
        .from('cc_groups')
        .select('id, owner_user_id, name, created_at')
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return null;
    final group = CcGroup.fromJson(row);
    group.members = await getGroupMembers(groupId);
    return group;
  }

  static Future<List<CcGroupMember>> getGroupMembers(String groupId) async {
    final rows = await _supabase
        .from('cc_group_members')
        .select('id, group_id, user_id, users(full_name, email)')
        .eq('group_id', groupId);
    return rows.map((r) => CcGroupMember.fromJson(r)).toList();
  }

  static Future<CcGroup> createGroup(String name) async {
    final uid = await _currentUserId();
    final row = await _supabase
        .from('cc_groups')
        .insert({'owner_user_id': uid, 'name': name})
        .select()
        .single();
    return CcGroup.fromJson(row);
  }

  static Future<void> renameGroup(String groupId, String name) async {
    await _supabase.from('cc_groups').update({'name': name}).eq('id', groupId);
  }

  static Future<void> deleteGroup(String groupId) async {
    await _supabase.from('cc_groups').delete().eq('id', groupId);
  }

  static Future<void> setGroupMembers(
      String groupId, List<String> userIds) async {
    // Delete existing then insert new
    await _supabase
        .from('cc_group_members')
        .delete()
        .eq('group_id', groupId);
    if (userIds.isEmpty) return;
    final rows = userIds
        .map((uid) => {'group_id': groupId, 'user_id': uid})
        .toList();
    await _supabase.from('cc_group_members').insert(rows);
  }

  static Future<void> addGroupMember(String groupId, String userId) async {
    await _supabase
        .from('cc_group_members')
        .upsert({'group_id': groupId, 'user_id': userId});
  }

  static Future<void> removeGroupMember(String groupId, String userId) async {
    await _supabase
        .from('cc_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  // ── User directory (for audience picker) ─────────────────

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final rows = await _supabase
        .from('users')
        .select('id, full_name, email, user_type, is_active')
        .eq('is_active', true)
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Forms ─────────────────────────────────────────────────

  static Future<List<CcForm>> getMyForms() async {
    final uid = await _currentUserId();
    if (uid == null) return [];
    final rows = await _supabase
        .from('cc_forms')
        .select()
        .eq('owner_user_id', uid)
        .order('created_at', ascending: false);
    return rows.map((r) => CcForm.fromJson(r)).toList();
  }

  static Future<List<CcForm>> getFormsForCurrentUser() async {
    final uid = await _currentUserId();
    if (uid == null) return [];

    // Direct audience membership
    final directRows = await _supabase
        .from('cc_form_audience')
        .select('form_id')
        .eq('user_id', uid);
    // Group membership
    final groupMemberRows = await _supabase
        .from('cc_group_members')
        .select('group_id')
        .eq('user_id', uid);
    final groupIds = groupMemberRows.map((r) => r['group_id'] as String).toList();
    List<String> groupFormIds = [];
    if (groupIds.isNotEmpty) {
      final gRows = await _supabase
          .from('cc_form_audience')
          .select('form_id')
          .inFilter('group_id', groupIds);
      groupFormIds = gRows.map((r) => r['form_id'] as String).toList();
    }
    // Owned forms — creators can fill/test their own forms
    final ownedRows = await _supabase
        .from('cc_forms')
        .select('id')
        .eq('owner_user_id', uid)
        .eq('is_active', true);
    final ownedIds = ownedRows.map((r) => r['id'] as String).toList();

    final formIds = {
      ...directRows.map((r) => r['form_id'] as String),
      ...groupFormIds,
      ...ownedIds,
    }.toList();
    if (formIds.isEmpty) return [];

    final rows = await _supabase
        .from('cc_forms')
        .select()
        .inFilter('id', formIds)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return rows.map((r) => CcForm.fromJson(r)).toList();
  }

  static Future<CcForm?> getFormById(String formId) async {
    final row = await _supabase
        .from('cc_forms')
        .select()
        .eq('id', formId)
        .maybeSingle();
    if (row == null) return null;
    return CcForm.fromJson(row);
  }

  static Future<CcForm> createForm(String ownerUserId) async {
    final row = await _supabase
        .from('cc_forms')
        .insert({
          'owner_user_id': ownerUserId,
          'title': '',
          'theme_color': '#f16936',
          'identity_mode': 'identified',
          'external_apply_enabled': false,
          'show_onboarding': false,
          'show_closing': false,
          'progress_style': 'numbered',
          'is_active': true,
        })
        .select()
        .single();
    final form = CcForm.fromJson(row);
    // Create a default first step
    final stepRow = await _supabase
        .from('cc_form_steps')
        .insert({'form_id': form.id, 'order_index': 0, 'title': 'Step 1'})
        .select()
        .single();
    final step = CcFormStep.fromJson(stepRow);
    // Create default section in that step
    final sectionRow = await _supabase
        .from('cc_form_sections')
        .insert({'step_id': step.id, 'order_index': 0, 'title': ''})
        .select()
        .single();
    step.sections = [CcFormSection.fromJson(sectionRow)];
    form.steps = [step];
    return form;
  }

  static Future<void> updateFormSettings(String formId,
      Map<String, dynamic> updates) async {
    await _supabase.from('cc_forms').update(updates).eq('id', formId);
  }

  static Future<void> deleteForm(String formId) async {
    await _supabase.from('cc_forms').delete().eq('id', formId);
  }

  // ── Full form fetch (with steps → sections → fields) ─────

  static Future<CcForm?> getFullForm(String formId) async {
    // Single query: form + all steps + sections + fields in one round-trip
    final formRow = await _supabase
        .from('cc_forms')
        .select('''
          *,
          cc_form_steps (
            *,
            cc_form_sections (
              *,
              cc_form_fields (*)
            )
          )
        ''')
        .eq('id', formId)
        .maybeSingle();
    if (formRow == null) return null;

    final form = CcForm.fromJson(formRow);

    final stepsJson = (formRow['cc_form_steps'] as List? ?? [])
      ..sort((a, b) => ((a['order_index'] as int?) ?? 0)
          .compareTo((b['order_index'] as int?) ?? 0));

    form.steps = stepsJson.map((stepJson) {
      final step = CcFormStep.fromJson(stepJson as Map<String, dynamic>);
      final sectionsJson = (stepJson['cc_form_sections'] as List? ?? [])
        ..sort((a, b) => ((a['order_index'] as int?) ?? 0)
            .compareTo((b['order_index'] as int?) ?? 0));
      step.sections = sectionsJson.map((sJson) {
        final section = CcFormSection.fromJson(sJson as Map<String, dynamic>);
        final fieldsJson = (sJson['cc_form_fields'] as List? ?? [])
          ..sort((a, b) => ((a['order_index'] as int?) ?? 0)
              .compareTo((b['order_index'] as int?) ?? 0));
        section.fields = fieldsJson
            .map((f) => CcFormField.fromJson(f as Map<String, dynamic>))
            .toList();
        return section;
      }).toList();
      return step;
    }).toList();

    form.audience = await getFormAudience(formId);
    return form;
  }

  // ── Steps ─────────────────────────────────────────────────

  static Future<CcFormStep> addStep(String formId, int orderIndex,
      String title) async {
    final row = await _supabase
        .from('cc_form_steps')
        .insert({'form_id': formId, 'order_index': orderIndex, 'title': title})
        .select()
        .single();
    final step = CcFormStep.fromJson(row);
    // Add default section
    final sRow = await _supabase
        .from('cc_form_sections')
        .insert({'step_id': step.id, 'order_index': 0, 'title': ''})
        .select()
        .single();
    step.sections = [CcFormSection.fromJson(sRow)];
    return step;
  }

  static Future<void> updateStep(String stepId, Map<String, dynamic> updates) async {
    await _supabase.from('cc_form_steps').update(updates).eq('id', stepId);
  }

  static Future<void> deleteStep(String stepId) async {
    await _supabase.from('cc_form_steps').delete().eq('id', stepId);
  }

  static Future<void> reorderSteps(List<CcFormStep> steps) async {
    for (var i = 0; i < steps.length; i++) {
      await _supabase
          .from('cc_form_steps')
          .update({'order_index': i})
          .eq('id', steps[i].id);
    }
  }

  // ── Sections ──────────────────────────────────────────────

  static Future<CcFormSection> addSection(
      String stepId, int orderIndex, String title) async {
    final row = await _supabase
        .from('cc_form_sections')
        .insert({'step_id': stepId, 'order_index': orderIndex, 'title': title})
        .select()
        .single();
    return CcFormSection.fromJson(row);
  }

  static Future<void> updateSection(
      String sectionId, Map<String, dynamic> updates) async {
    await _supabase
        .from('cc_form_sections')
        .update(updates)
        .eq('id', sectionId);
  }

  static Future<void> deleteSection(String sectionId) async {
    await _supabase.from('cc_form_sections').delete().eq('id', sectionId);
  }

  // ── Fields ────────────────────────────────────────────────

  static Future<CcFormField> addField(String sectionId, CcFieldType type,
      int orderIndex) async {
    final config = CcFieldConfig(
      desktopColWidth: type.defaultDesktopCols,
      required: false,
    );
    final row = await _supabase
        .from('cc_form_fields')
        .insert({
          'section_id': sectionId,
          'field_type': type.value,
          'order_index': orderIndex,
          'label': type.displayName,
          'config': config.toJson(),
        })
        .select()
        .single();
    return CcFormField.fromJson(row);
  }

  static Future<void> updateField(String fieldId,
      Map<String, dynamic> updates) async {
    await _supabase.from('cc_form_fields').update(updates).eq('id', fieldId);
  }

  static Future<void> deleteField(String fieldId) async {
    await _supabase.from('cc_form_fields').delete().eq('id', fieldId);
  }

  static Future<void> reorderFields(List<CcFormField> fields) async {
    for (var i = 0; i < fields.length; i++) {
      await _supabase
          .from('cc_form_fields')
          .update({'order_index': i})
          .eq('id', fields[i].id);
    }
  }

  static Future<void> moveFieldToSection(
      String fieldId, String targetSectionId, int orderIndex) async {
    await _supabase.from('cc_form_fields').update({
      'section_id': targetSectionId,
      'order_index': orderIndex,
    }).eq('id', fieldId);
  }

  // ── Audience ──────────────────────────────────────────────

  static Future<List<CcFormAudience>> getFormAudience(String formId) async {
    final rows = await _supabase
        .from('cc_form_audience')
        .select('id, form_id, user_id, group_id, users(full_name), cc_groups(name)')
        .eq('form_id', formId);
    return rows.map((r) => CcFormAudience.fromJson(r)).toList();
  }

  static Future<void> setFormAudience(String formId,
      List<String> userIds, List<String> groupIds) async {
    await _supabase.from('cc_form_audience').delete().eq('form_id', formId);
    final rows = <Map<String, dynamic>>[];
    for (final uid in userIds) {
      rows.add({'form_id': formId, 'user_id': uid});
    }
    for (final gid in groupIds) {
      rows.add({'form_id': formId, 'group_id': gid});
    }
    if (rows.isNotEmpty) {
      await _supabase.from('cc_form_audience').insert(rows);
    }
  }

  // ── Logo / attachment upload ──────────────────────────────

  static Future<String?> uploadFormLogo(
      String formId, Uint8List bytes, String fileName) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
    final path = 'logos/$formId/logo.$ext';
    await _supabase.storage.from('cc_logos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _supabase.storage.from('cc_logos').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<String?> uploadSubmissionAttachment(
      String submissionId, String fieldId,
      Uint8List bytes, String fileName, String mimeType) async {
    // Use a UUID-based storage key to avoid non-ASCII/space rejections.
    // The human-readable fileName is stored separately in the DB record.
    final ext   = fileName.contains('.') ? fileName.split('.').last : '';
    final safeKey = _uuid();
    final path  = 'submissions/$submissionId/$fieldId/$safeKey${ext.isNotEmpty ? '.$ext' : ''}';
    await _supabase.storage.from('cc_attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );
    final url = _supabase.storage.from('cc_attachments').getPublicUrl(path);
    return url;
  }

  static String _uuid() {
    const hex = '0123456789abcdef';
    final r = Random.secure();
    final buf = StringBuffer();
    for (int i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
      buf.write(hex[r.nextInt(16)]);
    }
    return buf.toString();
  }

  // ── Onboarding/closing screen image upload ────────────────

  static Future<String?> uploadScreenImage(
      String formId, Uint8List bytes, String fileName) async {
    final path = 'screens/$formId/$fileName';
    await _supabase.storage.from('cc_logos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('cc_logos').getPublicUrl(path);
  }

  // ── Submissions ───────────────────────────────────────────

  static Future<CcSubmission> createSubmission({
    required String formId,
    String? submittedByUserId,
    required bool isAnonymous,
    String? deviceMac,
    String? deviceType,
  }) async {
    final row = await _supabase
        .from('cc_submissions')
        .insert({
          'form_id': formId,
          'submitted_by_user_id': submittedByUserId,
          'is_anonymous': isAnonymous,
          'device_mac': deviceMac,
          'device_type': deviceType,
          'status': 'pending',
        })
        .select()
        .single();
    return CcSubmission.fromJson(row);
  }

  static Future<void> saveSubmissionValues(
      String submissionId, List<CcSubmissionValue> values) async {
    if (values.isEmpty) return;
    await _supabase.from('cc_submission_values').insert(
        values.map((v) => v.toJson()).toList());
  }

  static Future<void> saveSubmissionAttachment({
    required String submissionId,
    required String fieldId,
    required String fileUrl,
    required String fileName,
    String? fileType,
    int? fileSize,
  }) async {
    await _supabase.from('cc_submission_attachments').insert({
      'submission_id': submissionId,
      'field_id': fieldId,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
    });
  }

  // ── Records (creator view) ────────────────────────────────

  static Future<List<CcSubmission>> getSubmissionsForForm(
    String formId, {
    int page = 0,
    int pageSize = 50,
    String? statusFilter,
    String? searchQuery,
    String? searchFieldId,
  }) async {
    List<String>? matchingSubmissionIds;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      var valueQuery = _supabase
          .from('cc_submission_values')
          .select('submission_id')
          .ilike('value', '%${searchQuery.trim()}%');
      if (searchFieldId != null) {
        valueQuery = valueQuery.eq('field_id', searchFieldId);
      }
      final matches = await valueQuery;
      matchingSubmissionIds =
          matches.map((r) => r['submission_id'] as String).toSet().toList();
      if (matchingSubmissionIds.isEmpty) return [];
    }

    var query = _supabase
        .from('cc_submissions')
        .select('''
          id, form_id, submitted_by_user_id, is_anonymous,
          device_mac, device_type, status, created_at,
          users!submitted_by_user_id(full_name)
        ''')
        .eq('form_id', formId);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    if (matchingSubmissionIds != null) {
      query = query.inFilter('id', matchingSubmissionIds);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return rows.map((r) => CcSubmission.fromJson(r)).toList();
  }

  // Bulk-load values + attachments for a page of submissions.
  static Future<void> loadValuesForSubmissions(
      List<CcSubmission> submissions) async {
    if (submissions.isEmpty) return;
    final ids = submissions.map((s) => s.id).toList();

    final valueRows = await _supabase
        .from('cc_submission_values')
        .select()
        .inFilter('submission_id', ids);

    final attRows = await _supabase
        .from('cc_submission_attachments')
        .select()
        .inFilter('submission_id', ids)
        .order('created_at');

    final groupedValues = <String, List<CcSubmissionValue>>{};
    for (final r in valueRows) {
      final v = CcSubmissionValue.fromJson(r as Map<String, dynamic>);
      groupedValues.putIfAbsent(v.submissionId, () => []).add(v);
    }

    final groupedAtts = <String, List<CcSubmissionAttachment>>{};
    for (final r in attRows) {
      final a = CcSubmissionAttachment.fromJson(r);
      groupedAtts.putIfAbsent(a.submissionId, () => []).add(a);
    }

    for (final s in submissions) {
      s.values = groupedValues[s.id] ?? [];
      s.attachments = groupedAtts[s.id] ?? [];
    }
  }

  static Future<CcSubmission?> getSubmissionDetail(
      String submissionId) async {
    final row = await _supabase
        .from('cc_submissions')
        .select('''
          id, form_id, submitted_by_user_id, is_anonymous,
          device_mac, device_type, status, created_at,
          users!submitted_by_user_id(full_name)
        ''')
        .eq('id', submissionId)
        .maybeSingle();
    if (row == null) return null;
    final sub = CcSubmission.fromJson(row);
    sub.values = await _getSubmissionValues(submissionId);
    sub.attachments = await _getSubmissionAttachments(submissionId);
    sub.notes = await _getSubmissionNotes(submissionId);
    return sub;
  }

  static Future<List<CcSubmissionValue>> _getSubmissionValues(
      String submissionId) async {
    final rows = await _supabase
        .from('cc_submission_values')
        .select()
        .eq('submission_id', submissionId);
    return rows.map((r) => CcSubmissionValue.fromJson(r)).toList();
  }

  static Future<List<CcSubmissionAttachment>> _getSubmissionAttachments(
      String submissionId) async {
    final rows = await _supabase
        .from('cc_submission_attachments')
        .select()
        .eq('submission_id', submissionId)
        .order('created_at');
    return rows.map((r) => CcSubmissionAttachment.fromJson(r)).toList();
  }

  static Future<List<CcSubmissionNote>> _getSubmissionNotes(
      String submissionId) async {
    final rows = await _supabase
        .from('cc_submission_notes')
        .select('id, submission_id, author_user_id, note, created_at, users(full_name)')
        .eq('submission_id', submissionId)
        .order('created_at');
    return rows.map((r) => CcSubmissionNote.fromJson(r)).toList();
  }

  static Future<List<CcSubmissionNote>> getSubmissionNotes(
          String submissionId) =>
      _getSubmissionNotes(submissionId);

  static Future<void> updateSubmissionStatus(
      String submissionId, CcSubmissionStatus status) async {
    await _supabase
        .from('cc_submissions')
        .update({'status': status.value})
        .eq('id', submissionId);
  }

  static Future<void> bulkUpdateStatus(
      List<String> submissionIds, CcSubmissionStatus status) async {
    await _supabase
        .from('cc_submissions')
        .update({'status': status.value})
        .inFilter('id', submissionIds);
  }

  static Future<void> addSubmissionNote(
      String submissionId, String note) async {
    final uid = await _currentUserId();
    if (uid == null) return;
    await _supabase.from('cc_submission_notes').insert({
      'submission_id': submissionId,
      'author_user_id': uid,
      'note': note,
    });
  }

  // ── Device type detection ─────────────────────────────────

  static String detectDeviceType(double screenWidth) {
    if (screenWidth < 600) return 'mobile';
    if (screenWidth < 1024) return 'tablet';
    return 'desktop';
  }

  /// Returns a persistent device fingerprint UUID stored in SharedPreferences.
  /// On web this maps to localStorage; on mobile to the platform key-value store.
  /// A true MAC address is not accessible on any modern platform.
  static Future<String?> tryGetMacAddress() async {
    try {
      const key = 'jala_cc_device_id';
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(key);
      if (id == null || id.isEmpty) {
        id = _generateDeviceUuid();
        await prefs.setString(key, id);
      }
      return id;
    } catch (_) {
      return null;
    }
  }

  static String _generateDeviceUuid() {
    final rng = Random.secure();
    final b = List.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  static Future<void> notifyFormSubmission({
    required String formId,
    required String submissionId,
    required String formTitle,
    String? notifyEmail,
  }) async {
    try {
      await _supabase.functions.invoke(
        'notify-form-submission',
        body: {
          'form_id': formId,
          'submission_id': submissionId,
          'form_title': formTitle,
          if (notifyEmail != null) 'notify_email': notifyEmail,
        },
      );
    } catch (e) {
      debugPrint('Notification send failed (non-critical): $e');
    }
  }
}
