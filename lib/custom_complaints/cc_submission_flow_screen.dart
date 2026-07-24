import 'dart:io' show File;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show GestureBinding, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'cc_web_file_picker_stub.dart'
    if (dart.library.html) 'cc_web_file_picker_impl.dart';
import '../main.dart' show AppColors, supabase;
import '../models.dart' show UserModel;
import 'cc_models.dart';
import 'cc_service.dart';
import 'cc_screen_designer.dart' show ccIconCatalog;

/// Builds the full diagnostic text (timestamp, breadcrumb log, error and
/// stack trace) shown in the details dialog and copied to the clipboard.
String _ccBuildDiagnosticText(Object error, StackTrace? stackTrace, List<String>? log) {
  final buf = StringBuffer();
  buf.writeln('Reported at: ${DateTime.now().toIso8601String()}');
  if (log != null && log.isNotEmpty) {
    buf.writeln();
    buf.writeln('--- Steps leading up to the error ---');
    for (final line in log) {
      buf.writeln(line);
    }
  }
  buf.writeln();
  buf.writeln('--- Error ---');
  buf.writeln('$error');
  if (stackTrace != null) {
    buf.writeln();
    buf.writeln('--- Stack trace ---');
    buf.writeln('$stackTrace');
  }
  return buf.toString();
}

void _showCcErrorDetailsDialog(
  BuildContext context,
  bool isAr,
  Object error, [
  StackTrace? stackTrace,
  List<String>? log,
]) {
  final fullText = _ccBuildDiagnosticText(error, stackTrace, log);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isAr ? 'تفاصيل الخطأ' : 'Error details'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            fullText,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: fullText));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                content: Text(isAr ? 'تم نسخ التفاصيل' : 'Details copied'),
                duration: const Duration(seconds: 2),
              ));
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(isAr ? 'نسخ الكل' : 'Copy all'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? 'إغلاق' : 'Close'),
        ),
      ],
    ),
  );
}

/// Shows [shortMessage] with a "Details" action that reveals the full [error]
/// (and optional [stackTrace] and breadcrumb [log]) in a selectable,
/// copyable dialog, so failures can be diagnosed instead of just retried
/// blindly.
void showCcErrorSnackbar(
  BuildContext context, {
  required bool isAr,
  required String shortMessage,
  required Object error,
  StackTrace? stackTrace,
  List<String>? log,
}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(shortMessage),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: isAr ? 'التفاصيل' : 'Details',
      onPressed: () => _showCcErrorDetailsDialog(context, isAr, error, stackTrace, log),
    ),
  ));
}

/// Authenticated entry point: loads the form then hands off to [CcFormFillView].
class CcSubmissionFlowScreen extends StatefulWidget {
  final String formId;
  final UserModel currentUser;

  const CcSubmissionFlowScreen({super.key, required this.formId, required this.currentUser});

  @override
  State<CcSubmissionFlowScreen> createState() => _CcSubmissionFlowScreenState();
}

class _CcSubmissionFlowScreenState extends State<CcSubmissionFlowScreen> {
  CcForm? _form;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  final List<String> _log = [];
  void _logEvent(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _log.add('[$ts] $message');
    debugPrint('[CC] $message');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _logEvent('Loading form: formId=${widget.formId}, userId=${widget.currentUser.id}');
    try {
      final form = await CcService.getFullForm(widget.formId);
      _logEvent(form == null ? 'Form not found' : 'Form loaded: ${form.id}');
      setState(() {
        _form = form;
        _loading = false;
        _error = form == null ? 'not_found' : null;
      });
    } catch (e) {
      _logEvent('Load FAILED: $e');
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_error != null || _form == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isAr ? 'تعذر تحميل النموذج' : 'Could not load this form'),
              if (_error != null && _error != 'not_found') ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showCcErrorDetailsDialog(context, isAr, _error!, null, List.of(_log)),
                  child: Text(isAr ? 'عرض التفاصيل' : 'Show more'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return CcFormFillView(
      form: _form!,
      currentUserId: widget.currentUser.id,
      currentUserFullName: widget.currentUser.fullName,
      onCompleted: () => Navigator.pop(context),
    );
  }
}

/// Reusable fill flow: onboarding → identity choice → steps → closing.
/// Used both by the authenticated [CcSubmissionFlowScreen] and the public
/// external (no-login) submission screen.
class CcFormFillView extends StatefulWidget {
  final CcForm form;
  final String? currentUserId;
  final String? currentUserFullName;
  final VoidCallback onCompleted;
  final String? deviceType;
  final bool isPreview;

  const CcFormFillView({
    super.key,
    required this.form,
    required this.currentUserId,
    required this.currentUserFullName,
    required this.onCompleted,
    this.deviceType,
    this.isPreview = false,
  });

  @override
  State<CcFormFillView> createState() => _CcFormFillViewState();
}

enum _Stage { onboarding, identity, step, closing, submitting }

class _CcFormFillViewState extends State<CcFormFillView> {
  late _Stage _stage;
  int _currentStepIndex = 0;
  bool? _identityIsAnonymous;
  final Map<String, dynamic> _values = {};
  final Map<String, List<_PendingFile>> _pendingFiles = {};
  String? _stepError;
  Set<String> _errorFieldIds = {};
  Map<String, String> _typeErrors = {};

  // Rolling breadcrumb log of what happened during this submission attempt,
  // so a failure can be diagnosed from the "Details" dialog instead of
  // reproduced. Capped to avoid unbounded growth over a long-lived session.
  final List<String> _log = [];
  void _logEvent(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _log.add('[$ts] $message');
    if (_log.length > 200) _log.removeAt(0);
    debugPrint('[CC] $message');
  }

  // Action-computed runtime state
  Map<String, bool> _actionHiddenFields = {};
  Map<String, bool> _sectionHiddenBySA = {};
  Map<String, bool> _actionDisabledFields = {};
  Map<String, bool?> _actionForcedRequired = {};

  // Step navigation history for back button
  final List<int> _stepHistory = [];

  @override
  void initState() {
    super.initState();
    // External forms (no logged-in user) are always anonymous — skip identity stage
    final isExternal = widget.currentUserId == null;
    if (isExternal) {
      _identityIsAnonymous = true;
      _stage = widget.form.showOnboarding && widget.form.onboardingConfig != null
          ? _Stage.onboarding
          : _Stage.step;
    } else if (widget.form.showOnboarding && widget.form.onboardingConfig != null) {
      _stage = _Stage.onboarding;
    } else if (widget.form.identityMode == CcIdentityMode.choice) {
      _stage = _Stage.identity;
    } else {
      _stage = _Stage.step;
      _identityIsAnonymous = widget.form.identityMode == CcIdentityMode.anonymous;
    }
  }

  List<CcFormField> get _allFields =>
      widget.form.steps.expand((s) => s.sections.expand((sec) => sec.fields)).toList();

  CcFormField? _findField(String fieldId) {
    for (final step in widget.form.steps) {
      for (final section in step.sections) {
        for (final field in section.fields) {
          if (field.id == fieldId) return field;
        }
      }
    }
    return null;
  }

  bool _evaluateCondition(CcCondition c) {
    final actual = _values[c.sourceFieldId];
    final expected = c.value;
    switch (c.rule) {
      case CcConditionRule.isEmpty:
        return actual == null || (actual is String && actual.isEmpty) || (actual is List && actual.isEmpty);
      case CcConditionRule.isNotEmpty:
        return !(actual == null || (actual is String && actual.isEmpty) || (actual is List && actual.isEmpty));
      case CcConditionRule.equals:
        return actual?.toString() == expected?.toString();
      case CcConditionRule.notEquals:
        return actual?.toString() != expected?.toString();
      case CcConditionRule.contains:
        if (actual is List) return actual.map((e) => e.toString()).contains(expected?.toString());
        return (actual?.toString() ?? '').contains(expected?.toString() ?? '');
      case CcConditionRule.notContains:
        if (actual is List) return !actual.map((e) => e.toString()).contains(expected?.toString());
        return !(actual?.toString() ?? '').contains(expected?.toString() ?? '');
      case CcConditionRule.greaterThan:
        final a = double.tryParse(actual?.toString() ?? '');
        final b = double.tryParse(expected?.toString() ?? '');
        if (a == null || b == null) return false;
        return a > b;
      case CcConditionRule.lessThan:
        final a = double.tryParse(actual?.toString() ?? '');
        final b = double.tryParse(expected?.toString() ?? '');
        if (a == null || b == null) return false;
        return a < b;
    }
  }

  bool _isVisible(CcFormField field) {
    if (_actionHiddenFields[field.id] == true) return false;
    if (_sectionHiddenBySA[field.sectionId] == true) return false;
    final conds = field.config.conditions;
    if (conds.isEmpty) return true;
    if (field.config.conditionOperator == CcConditionOperator.or) {
      return conds.any(_evaluateCondition);
    }
    return conds.every(_evaluateCondition);
  }

  bool _isEmptyValue(dynamic v) =>
      v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

  /// Returns per-field error messages (fieldId → message).
  /// Covers required checks + type-specific validation (phone, multiSelect min).
  Map<String, String> _fieldErrors(bool isAr) {
    final step = widget.form.steps[_currentStepIndex];
    final errors = <String, String>{};
    for (final section in step.sections) {
      for (final field in section.fields) {
        if (field.fieldType.isDisplayOnly) continue;
        if (!_isVisible(field)) continue;
        if (_actionDisabledFields[field.id] == true) continue;
        final isRequired = _actionForcedRequired[field.id] ?? field.config.required;
        if (isRequired) {
          if (field.fieldType == CcFieldType.attachment ||
              field.fieldType == CcFieldType.imageAttachment) {
            if ((_pendingFiles[field.id] ?? []).isEmpty) {
              errors[field.id] = isAr ? 'هذا الحقل مطلوب' : 'This field is required';
            }
            continue;
          }
          if (_isEmptyValue(_values[field.id])) {
            errors[field.id] = isAr ? 'هذا الحقل مطلوب' : 'This field is required';
            continue;
          }
        }
        // Phone: must have at least 7 digits
        if (field.fieldType == CcFieldType.phone) {
          final v = (_values[field.id] as String? ?? '').trim();
          if (v.isNotEmpty) {
            final digits = v.replaceAll(RegExp(r'[^\d]'), '');
            if (digits.length < 7) {
              errors[field.id] = isAr ? 'رقم الهاتف غير صالح' : 'Invalid phone number';
            }
          }
        }
        // multiSelect / checkboxGroup: enforce minSelections
        if (field.fieldType == CcFieldType.multiSelect ||
            field.fieldType == CcFieldType.checkboxGroup) {
          final min = field.config.minSelections;
          if (min != null && min > 1) {
            final count = _values[field.id] is List
                ? (_values[field.id] as List).length
                : 0;
            if (count < min) {
              errors[field.id] = isAr
                  ? 'اختر $min خيارات على الأقل'
                  : 'Select at least $min options';
            }
          }
        }
      }
    }
    return errors;
  }

  void _recomputeActionState() {
    final Map<String, bool> hidden = {};
    final Map<String, bool> sectionHidden = {};
    final Map<String, bool> disabled = {};
    final Map<String, bool?> forcedRequired = {};

    for (final step in widget.form.steps) {
      for (final section in step.sections) {
        for (final field in section.fields) {
          if (field.config.optionActions.isEmpty) continue;
          final value = _values[field.id];
          if (value == null) continue;
          final actions = field.config.optionActions[value.toString()] ?? [];
          for (final action in actions) {
            switch (action.type) {
              case CcFieldActionType.showField:
                if (action.targetId != null) hidden[action.targetId!] = false;
              case CcFieldActionType.hideField:
                if (action.targetId != null) hidden[action.targetId!] = true;
              case CcFieldActionType.showSection:
                if (action.targetId != null) sectionHidden[action.targetId!] = false;
              case CcFieldActionType.hideSection:
                if (action.targetId != null) sectionHidden[action.targetId!] = true;
              case CcFieldActionType.requireField:
                if (action.targetId != null) forcedRequired[action.targetId!] = true;
              case CcFieldActionType.unrequireField:
                if (action.targetId != null) forcedRequired[action.targetId!] = false;
              case CcFieldActionType.enableField:
                if (action.targetId != null) disabled[action.targetId!] = false;
              case CcFieldActionType.disableField:
                if (action.targetId != null) disabled[action.targetId!] = true;
              default:
                break;
            }
          }
        }
      }
    }

    setState(() {
      _actionHiddenFields = hidden;
      _sectionHiddenBySA = sectionHidden;
      _actionDisabledFields = disabled;
      _actionForcedRequired = forcedRequired;
    });
  }

  void _showActionToast(CcToastType type, String message) {
    if (!mounted || message.trim().isEmpty) return;
    final color = switch (type) {
      CcToastType.success => const Color(0xFF22C55E),
      CcToastType.info    => const Color(0xFF3B82F6),
      CcToastType.warning => const Color(0xFFF59E0B),
      CcToastType.error   => const Color(0xFFEF4444),
    };
    final icon = switch (type) {
      CcToastType.success => Icons.check_circle_rounded,
      CcToastType.info    => Icons.info_rounded,
      CcToastType.warning => Icons.warning_rounded,
      CcToastType.error   => Icons.error_rounded,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    ));
  }

  void _handleValueChanged(String fieldId, dynamic value) {
    setState(() {
      _values[fieldId] = value;
      _errorFieldIds.remove(fieldId);
      _typeErrors.remove(fieldId);
    });

    if (value != null) {
      final field = _findField(fieldId);
      if (field != null) {
        final actions = field.config.optionActions[value.toString()] ?? [];
        for (final action in actions) {
          if (action.type == CcFieldActionType.showToast) {
            _showActionToast(action.toastType, action.toastMessage);
          }
        }
      }
    }

    _recomputeActionState();
  }

  /// Checks if any visible field in the current step has optionActions for its current value.
  /// Returns 'submit', a step ID string, or null (= advance normally).
  String? _resolveJumpTarget() {
    final step = widget.form.steps[_currentStepIndex];
    for (final section in step.sections) {
      for (final field in section.fields) {
        if (!_isVisible(field)) continue;
        if (field.config.optionActions.isEmpty) continue;
        final value = _values[field.id];
        if (value == null) continue;
        final actions = field.config.optionActions[value.toString()] ?? [];
        for (final action in actions) {
          if (action.type == CcFieldActionType.submitForm) return 'submit';
          if (action.type == CcFieldActionType.jumpToStep && action.targetId != null) {
            return action.targetId!;
          }
        }
      }
    }
    return null;
  }

  void _goNext() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _stepError = null);

    if (_stage == _Stage.onboarding) {
      setState(() {
        final isExternal = widget.currentUserId == null;
        if (!isExternal && widget.form.identityMode == CcIdentityMode.choice) {
          _stage = _Stage.identity;
        } else {
          if (!isExternal) {
            _identityIsAnonymous = widget.form.identityMode == CcIdentityMode.anonymous;
          }
          _stage = _Stage.step;
        }
      });
      return;
    }

    if (_stage == _Stage.identity) {
      if (_identityIsAnonymous == null) {
        setState(() => _stepError = isAr ? 'الرجاء اختيار طريقة الإرسال' : 'Please choose how to submit');
        return;
      }
      setState(() => _stage = _Stage.step);
      return;
    }

    if (_stage == _Stage.step) {
      final errs = _fieldErrors(isAr);
      if (errs.isNotEmpty) {
        setState(() {
          _stepError = errs.values.first;
          _errorFieldIds = errs.keys.toSet();
          _typeErrors = Map.from(errs);
        });
        return;
      }
      setState(() { _errorFieldIds = {}; _typeErrors = {}; });
      final jumpTarget = _resolveJumpTarget();
      if (jumpTarget == 'submit') {
        _submit();
        return;
      }
      if (jumpTarget != null) {
        final idx = widget.form.steps.indexWhere((s) => s.id == jumpTarget);
        if (idx >= 0) {
          _stepHistory.add(_currentStepIndex);
          setState(() => _currentStepIndex = idx);
          return;
        }
      }
      if (_currentStepIndex < widget.form.steps.length - 1) {
        _stepHistory.add(_currentStepIndex);
        setState(() => _currentStepIndex++);
      } else {
        _submit();
      }
    }
  }

  VoidCallback? _resolveOnBack(CcForm form) {
    if (!form.allowBack) return null;
    final isLastStep = _currentStepIndex == form.steps.length - 1;
    if (isLastStep) return null;
    if (_stepHistory.isNotEmpty) return _goBack;
    if (_currentStepIndex > 0) return _goBack;
    if (form.identityMode == CcIdentityMode.choice) return _goBack;
    return null;
  }

  void _goBack() {
    setState(() { _stepError = null; _errorFieldIds = {}; _typeErrors = {}; });
    if (_stage == _Stage.step) {
      if (_stepHistory.isNotEmpty) {
        setState(() => _currentStepIndex = _stepHistory.removeLast());
      } else if (widget.form.identityMode == CcIdentityMode.choice) {
        setState(() => _stage = _Stage.identity);
      }
    } else if (_stage == _Stage.identity) {
      if (widget.form.showOnboarding && widget.form.onboardingConfig != null) {
        setState(() => _stage = _Stage.onboarding);
      }
    }
  }

  /// Mobile browsers can silently lose/expire the Supabase auth session
  /// while the tab is backgrounded (e.g. during a native camera capture
  /// for an image-attachment field). If that happens, the insert is
  /// rejected by RLS even though the app still shows the user as logged
  /// in. Refresh the session once and retry before giving up.
  Future<CcSubmission> _createSubmissionWithSessionRetry({
    required String formId,
    required String? submittedByUserId,
    required bool isAnonymous,
    required String? deviceMac,
    required String? deviceType,
  }) async {
    final session = supabase.auth.currentSession;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    _logEvent('Auth session check: hasSession=${session != null}, '
        'userId=${session?.user.id}, expiresAt=${session?.expiresAt}, '
        'now=$nowSec, expired=${session != null && session.expiresAt != null && session.expiresAt! < nowSec}');
    try {
      _logEvent('Creating submission (attempt 1)...');
      final result = await CcService.createSubmission(
        formId: formId,
        submittedByUserId: submittedByUserId,
        isAnonymous: isAnonymous,
        deviceMac: deviceMac,
        deviceType: deviceType,
      );
      _logEvent('Submission created: id=${result.id}');
      return result;
    } on PostgrestException catch (e) {
      _logEvent('Submission insert failed: code=${e.code}, message=${e.message}');
      if (e.code != '42501') rethrow;
      _logEvent('RLS error (42501) — attempting session refresh...');
      await supabase.auth.refreshSession();
      final refreshed = supabase.auth.currentSession;
      _logEvent('Session refreshed: userId=${refreshed?.user.id}, expiresAt=${refreshed?.expiresAt}');
      _logEvent('Creating submission (attempt 2, after refresh)...');
      final result = await CcService.createSubmission(
        formId: formId,
        submittedByUserId: submittedByUserId,
        isAnonymous: isAnonymous,
        deviceMac: deviceMac,
        deviceType: deviceType,
      );
      _logEvent('Submission created on retry: id=${result.id}');
      return result;
    }
  }

  Future<void> _submit() async {
    if (widget.isPreview) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.orange[700],
        content: Text(isAr ? 'وضع المعاينة — لن يتم حفظ البيانات' : 'Preview mode — no data is saved'),
        duration: const Duration(seconds: 2),
      ));
      setState(() {
        _currentStepIndex = 0;
        _stage = _Stage.step;
      });
      return;
    }
    setState(() => _stage = _Stage.submitting);
    _log.clear();
    _logEvent('Submit started: formId=${widget.form.id}, userId=${widget.currentUserId}, '
        'pendingFiles=${_pendingFiles.values.fold<int>(0, (n, l) => n + l.length)}');
    try {
      final deviceType = widget.deviceType ??
          CcService.detectDeviceType(MediaQuery.of(context).size.width);
      final mac = await CcService.tryGetMacAddress();
      _logEvent('Device info resolved: deviceType=$deviceType, mac=$mac');

      final submission = await _createSubmissionWithSessionRetry(
        formId: widget.form.id,
        submittedByUserId: widget.currentUserId,
        isAnonymous: _identityIsAnonymous ?? (widget.form.identityMode == CcIdentityMode.anonymous),
        deviceMac: mac,
        deviceType: deviceType,
      );

      final values = <CcSubmissionValue>[];
      for (final field in _allFields) {
        if (field.fieldType.isDisplayOnly) continue;
        if (field.fieldType == CcFieldType.attachment) continue;
        if (field.fieldType == CcFieldType.imageAttachment) continue;
        if (!_isVisible(field)) continue;
        final v = _values[field.id];
        if (_isEmptyValue(v)) continue;
        values.add(CcSubmissionValue(
          id: '',
          submissionId: submission.id,
          fieldId: field.id,
          value: v,
        ));
      }
      _logEvent('Saving ${values.length} field values...');
      await CcService.saveSubmissionValues(submission.id, values);
      _logEvent('Field values saved');

      final attachmentCount = _pendingFiles.values.fold<int>(0, (n, l) => n + l.length);
      if (attachmentCount > 0) _logEvent('Uploading $attachmentCount attachment(s)...');
      await Future.wait([
        for (final entry in _pendingFiles.entries)
          for (final file in entry.value)
            Future(() async {
              try {
                final url = await CcService.uploadSubmissionAttachment(
                    submission.id, entry.key, file.bytes, file.name, file.mimeType ?? '');
                if (url != null) {
                  await CcService.saveSubmissionAttachment(
                    submissionId: submission.id,
                    fieldId: entry.key,
                    fileUrl: url,
                    fileName: file.name,
                    fileType: file.mimeType,
                    fileSize: file.bytes.length,
                  );
                  _logEvent('Attachment uploaded: ${file.name} (field=${entry.key})');
                }
              } catch (uploadErr) {
                _logEvent('Attachment upload FAILED: ${file.name} (field=${entry.key}) — $uploadErr');
                debugPrint('Attachment upload failed for ${file.name}: $uploadErr');
              }
            }),
      ]);

      if (widget.form.notifyCreatorOnSubmit ||
          widget.form.notifyAdditionalEmails.isNotEmpty ||
          widget.form.notifyAdditionalUserIds.isNotEmpty) {
        _logEvent('Sending owner notification...');
        CcService.notifyFormSubmission(
          formId: widget.form.id,
          submissionId: submission.id,
          formTitle: widget.form.title,
          notifyEmail: widget.form.notifyCreatorOnSubmit ? widget.form.notifyEmail : null,
          additionalEmails: widget.form.notifyAdditionalEmails,
          additionalUserIds: widget.form.notifyAdditionalUserIds,
          customMessage: widget.form.notifyCustomMessage,
        ).then((ok) {
          _logEvent('Notification result: ${ok ? 'sent' : 'FAILED'}');
          if (!ok && mounted) {
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            showCcErrorSnackbar(
              context,
              isAr: isAr,
              shortMessage: isAr
                  ? 'تم إرسال الشكوى، لكن تعذر إرسال إشعار المالك'
                  : 'Submission sent, but the owner notification failed',
              error: 'notifyFormSubmission returned false for form ${widget.form.id}',
              log: List.of(_log),
            );
          }
        });
      }

      _logEvent('Submit completed successfully: submissionId=${submission.id}');
      if (!mounted) return;
      if (widget.form.showClosing && widget.form.closingConfig != null) {
        setState(() => _stage = _Stage.closing);
      } else {
        widget.onCompleted();
      }
    } catch (e, st) {
      _logEvent('Submit FAILED: $e');
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      setState(() => _stage = _Stage.step);
      showCcErrorSnackbar(
        context,
        log: List.of(_log),
        isAr: isAr,
        shortMessage: isAr ? 'تعذر إرسال النموذج، حاول مرة أخرى' : 'Could not submit, please try again',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final bg = form.themeColorValue;
    final fg = form.contrastTextColor;

    switch (_stage) {
      case _Stage.onboarding:
        return _ScreenStage(
          config: CcScreenConfig.fromJson(form.onboardingConfig),
          themeColor: bg,
          onPrimary: _goNext,
          isPrimaryStage: true,
        );
      case _Stage.identity:
        return _IdentityStage(
          form: form,
          selected: _identityIsAnonymous,
          error: _stepError,
          onSelect: (v) => setState(() => _identityIsAnonymous = v),
          onNext: _goNext,
          onBack: widget.form.showOnboarding && form.onboardingConfig != null ? _goBack : null,
        );
      case _Stage.closing:
        return _ScreenStage(
          config: CcScreenConfig.fromJson(form.closingConfig),
          themeColor: bg,
          onPrimary: widget.onCompleted,
          isPrimaryStage: false,
        );
      case _Stage.submitting:
        return Scaffold(
          backgroundColor: bg,
          body: Center(child: CircularProgressIndicator(color: fg)),
        );
      case _Stage.step:
        return _StepStage(
          form: form,
          stepIndex: _currentStepIndex,
          values: _values,
          pendingFiles: _pendingFiles,
          errorFieldIds: _errorFieldIds,
          typeErrors: _typeErrors,
          isVisible: _isVisible,
          error: _stepError,
          onValueChanged: _handleValueChanged,
          onFilesChanged: (fieldId, files) => setState(() {
            _pendingFiles[fieldId] = files;
            if (files.isNotEmpty) {
              _errorFieldIds.remove(fieldId);
              _typeErrors.remove(fieldId);
            }
          }),
          onNext: _goNext,
          onBack: _resolveOnBack(form),
          disabledFields: _actionDisabledFields,
          hiddenSections: _sectionHiddenBySA,
        );
    }
  }
}

class _PendingFile {
  final String name;
  final Uint8List bytes;
  final String? mimeType;
  _PendingFile({required this.name, required this.bytes, this.mimeType});
}

// ── Onboarding / Closing screen stage ──────────────────────

class _ScreenStage extends StatelessWidget {
  final CcScreenConfig config;
  final Color themeColor;
  final VoidCallback onPrimary;
  final bool isPrimaryStage;

  const _ScreenStage({
    required this.config,
    required this.themeColor,
    required this.onPrimary,
    required this.isPrimaryStage,
  });

  Color _hex(String h) {
    var v = h.replaceAll('#', '');
    if (v.length == 6) v = 'FF$v';
    return Color(int.parse(v, radix: 16));
  }

  TextAlign _align(String v) => v == 'left'
      ? TextAlign.left
      : v == 'right'
          ? TextAlign.right
          : TextAlign.center;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final hasImage = (config.backgroundImageUrl ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: _hex(config.backgroundColor),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(config.backgroundImageUrl!, fit: BoxFit.cover),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...(config.items.where((item) => item.visible).toList()
                          ..sort((a, b) => a.y.compareTo(b.y)))
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _renderItem(item),
                            )),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isPrimaryStage ? (isAr ? 'ابدأ' : 'Start') : (isAr ? 'تم' : 'Done'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderItem(CcCanvasItem item) {
    switch (item.type) {
      case CcCanvasItemType.heading:
      case CcCanvasItemType.body:
        return Text(
          item.text ?? '',
          textAlign: _align(item.textAlign),
          style: TextStyle(
            fontSize: item.fontSize,
            fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
            color: _hex(item.textColor),
          ),
        );
      case CcCanvasItemType.icon:
        return Icon(
          ccIconCatalog[item.iconName] ?? Icons.info_outline_rounded,
          size: (item.height * 0.7).clamp(24.0, 96.0),
          color: _hex(item.textColor),
        );
      case CcCanvasItemType.image:
        return item.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl!,
                  width: item.width > 0 ? item.width : null,
                  height: item.height > 0 ? item.height : null,
                  fit: BoxFit.contain,
                ),
              )
            : const SizedBox.shrink();
      case CcCanvasItemType.spacer:
        return SizedBox(height: item.spacerHeight);
      case CcCanvasItemType.bullets:
        final lines = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: lines.map((line) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: item.fontSize, color: _hex(item.textColor))),
                Expanded(child: Text(line,
                  style: TextStyle(
                    fontSize: item.fontSize,
                    fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
                    color: _hex(item.textColor),
                  ))),
              ],
            ),
          )).toList(),
        );
      case CcCanvasItemType.numberedList:
        final nLines = (item.text ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: nLines.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.key + 1}. ', style: TextStyle(fontSize: item.fontSize, color: _hex(item.textColor), fontWeight: FontWeight.bold)),
                Expanded(child: Text(e.value,
                  style: TextStyle(
                    fontSize: item.fontSize,
                    fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
                    color: _hex(item.textColor),
                    letterSpacing: item.letterSpacing,
                  ))),
              ],
            ),
          )).toList(),
        );
      case CcCanvasItemType.divider:
        return Container(
          height: item.borderWidth > 0 ? item.borderWidth : 2,
          color: _hex(item.textColor),
          margin: const EdgeInsets.symmetric(vertical: 4),
        );
      case CcCanvasItemType.button:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: item.bgFill != null ? _hex(item.bgFill!) : const Color(0xFFF16936),
            borderRadius: BorderRadius.circular(item.itemBorderRadius > 0 ? item.itemBorderRadius : 8),
            border: item.borderWidth > 0 ? Border.all(color: _hex(item.borderColor), width: item.borderWidth) : null,
          ),
          child: Text(
            item.text ?? 'Button',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: item.fontSize,
              fontWeight: item.bold ? FontWeight.bold : FontWeight.normal,
              color: _hex(item.textColor),
              letterSpacing: item.letterSpacing,
            ),
          ),
        );
    }
  }
}

// ── Identity choice stage ──────────────────────────────────

class _IdentityStage extends StatelessWidget {
  final CcForm form;
  final bool? selected;
  final String? error;
  final ValueChanged<bool> onSelect;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const _IdentityStage({
    required this.form,
    required this.selected,
    required this.error,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack)
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'كيف تود الإرسال؟' : 'How would you like to submit?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 20),
                _OptionCard(
                  icon: Icons.badge_outlined,
                  title: isAr ? 'معرّف الهوية' : 'Identified',
                  subtitle: isAr ? 'سيتم ربط الإجابة باسمك' : 'Your response will be linked to your name',
                  selected: selected == false,
                  onTap: () => onSelect(false),
                ),
                const SizedBox(height: 12),
                _OptionCard(
                  icon: Icons.visibility_off_outlined,
                  title: isAr ? 'مجهول الهوية' : 'Anonymous',
                  subtitle: isAr ? 'لن يظهر اسمك في النتائج' : 'Your name will not be shown in the results',
                  selected: selected == true,
                  onTap: () => onSelect(true),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: form.themeColorValue,
                    foregroundColor: form.contrastTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isAr ? 'متابعة' : 'Continue', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey[300]!, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : Colors.grey[500]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// ── Step stage (form fields) ───────────────────────────────

class _StepStage extends StatefulWidget {
  final CcForm form;
  final int stepIndex;
  final Map<String, dynamic> values;
  final Map<String, List<_PendingFile>> pendingFiles;
  final Set<String> errorFieldIds;
  final bool Function(CcFormField) isVisible;
  final String? error;
  final void Function(String fieldId, dynamic value) onValueChanged;
  final void Function(String fieldId, List<_PendingFile> files) onFilesChanged;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final Map<String, String> typeErrors;
  final Map<String, bool> disabledFields;
  final Map<String, bool> hiddenSections;

  const _StepStage({
    required this.form,
    required this.stepIndex,
    required this.values,
    required this.pendingFiles,
    required this.errorFieldIds,
    required this.isVisible,
    required this.error,
    required this.onValueChanged,
    required this.onFilesChanged,
    required this.onNext,
    this.onBack,
    this.typeErrors = const {},
    this.disabledFields = const {},
    this.hiddenSections = const {},
  });

  @override
  State<_StepStage> createState() => _StepStageState();
}

class _StepStageState extends State<_StepStage> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final step = widget.form.steps[widget.stepIndex];
    final isLastStep = widget.stepIndex == widget.form.steps.length - 1;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.form.logoUrl != null && widget.form.logoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  widget.form.logoUrl!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.form.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _ProgressBar(
            current: widget.stepIndex,
            total: widget.form.steps.length,
            style: widget.form.progressStyle,
            color: widget.form.themeColorValue,
            stepTitle: step.title,
          ),
          Expanded(
            // Listener with opaque hit-test covers the full width (including empty
            // space beside the 880px card). PointerSignalResolver ensures the inner
            // SingleChildScrollView wins when the cursor IS over content, so there
            // is no double-scroll. The outer Listener only fires in the empty areas.
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent && _scrollCtrl.hasClients) {
                  GestureBinding.instance.pointerSignalResolver.register(signal, (event) {
                    final s = event as PointerScrollEvent;
                    _scrollCtrl.jumpTo(
                      (_scrollCtrl.offset + s.scrollDelta.dy)
                          .clamp(0.0, _scrollCtrl.position.maxScrollExtent),
                    );
                  });
                }
              },
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (step.title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        for (int si = 0; si < step.sections.length; si++)
                          if (widget.hiddenSections[step.sections[si].id] != true) ...[
                            _SectionBlock(
                              section: step.sections[si],
                              sectionIndex: si,
                              showDivider: si > 0,
                              isMobile: isMobile,
                              values: widget.values,
                              pendingFiles: widget.pendingFiles,
                              errorFieldIds: widget.errorFieldIds,
                              typeErrors: widget.typeErrors,
                              isVisible: widget.isVisible,
                              onValueChanged: widget.onValueChanged,
                              onFilesChanged: widget.onFilesChanged,
                              disabledFields: widget.disabledFields,
                            ),
                          ],
                        if (widget.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(widget.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.onBack != null) ...[
                    OutlinedButton(
                      onPressed: widget.onBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        foregroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(isAr ? 'رجوع' : 'Back'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.form.themeColorValue,
                        foregroundColor: widget.form.contrastTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isLastStep ? (isAr ? 'إرسال' : 'Submit') : (isAr ? 'التالي' : 'Next'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final CcProgressStyle style;
  final Color color;
  final String stepTitle;

  const _ProgressBar({
    required this.current,
    required this.total,
    required this.style,
    required this.color,
    required this.stepTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    Widget bar;
    switch (style) {
      case CcProgressStyle.percentage:
        final pct = ((current + 1) / total * 100).round();
        bar = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (current + 1) / total,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Text('$pct%  ·  $stepTitle', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        );
        break;
      case CcProgressStyle.dotted:
        bar = Row(
          children: List.generate(total, (i) {
            final active = i == current;
            final done = i < current;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 5,
                decoration: BoxDecoration(
                  color: active || done ? color : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
        break;
      case CcProgressStyle.numbered:
        bar = Row(
          children: List.generate(total * 2 - 1, (i) {
            if (i.isOdd) {
              final passed = (i ~/ 2) < current;
              return Expanded(child: Container(height: 2, color: passed ? color : Colors.grey[300]));
            }
            final idx = i ~/ 2;
            final active = idx == current;
            final done = idx < current;
            return CircleAvatar(
              radius: 12,
              backgroundColor: active || done ? color : Colors.grey[300],
              child: done
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : Text('${idx + 1}', style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.grey[700])),
            );
          }),
        );
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: bar,
    );
  }
}

// ── Section block with optional header ────────────────────

class _SectionBlock extends StatelessWidget {
  final CcFormSection section;
  final int sectionIndex;
  final bool showDivider;
  final bool isMobile;
  final Map<String, dynamic> values;
  final Map<String, List<_PendingFile>> pendingFiles;
  final Set<String> errorFieldIds;
  final Map<String, String> typeErrors;
  final bool Function(CcFormField) isVisible;
  final void Function(String, dynamic) onValueChanged;
  final void Function(String, List<_PendingFile>) onFilesChanged;
  final Map<String, bool> disabledFields;

  const _SectionBlock({
    required this.section,
    required this.sectionIndex,
    required this.showDivider,
    required this.isMobile,
    required this.values,
    required this.pendingFiles,
    required this.errorFieldIds,
    this.typeErrors = const {},
    required this.isVisible,
    required this.onValueChanged,
    required this.onFilesChanged,
    this.disabledFields = const {},
  });

  @override
  Widget build(BuildContext context) {
    final visible = section.fields.where(isVisible).toList();
    if (visible.isEmpty && section.title.isEmpty) return const SizedBox.shrink();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final displayTitle = section.title.isNotEmpty
        ? section.title
        : isAr
            ? 'قسم ${sectionIndex + 1}'
            : 'Section ${sectionIndex + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (visible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _FieldRows(
                fields: visible,
                isMobile: isMobile,
                values: values,
                pendingFiles: pendingFiles,
                errorFieldIds: errorFieldIds,
                typeErrors: typeErrors,
                onValueChanged: onValueChanged,
                onFilesChanged: onFilesChanged,
                disabledFields: disabledFields,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Field row packing (16-col desktop, 2-col mobile) ───────

class _FieldRows extends StatelessWidget {
  final List<CcFormField> fields;
  final bool isMobile;
  final Map<String, dynamic> values;
  final Map<String, List<_PendingFile>> pendingFiles;
  final Set<String> errorFieldIds;
  final Map<String, String> typeErrors;
  final void Function(String, dynamic) onValueChanged;
  final void Function(String, List<_PendingFile>) onFilesChanged;
  final Map<String, bool> disabledFields;

  const _FieldRows({
    required this.fields,
    required this.isMobile,
    required this.values,
    required this.pendingFiles,
    required this.errorFieldIds,
    this.typeErrors = const {},
    required this.onValueChanged,
    required this.onFilesChanged,
    this.disabledFields = const {},
  });

  @override
  Widget build(BuildContext context) {
    final unit = isMobile ? 2 : 16;
    final rows = <List<MapEntry<CcFormField, int>>>[];
    var currentRow = <MapEntry<CcFormField, int>>[];
    var currentUnits = 0;

    for (final f in fields) {
      int w;
      if (isMobile) {
        w = f.fieldType.isAlwaysFullWidth || f.config.desktopColWidth >= 12 ? 2 : 1;
      } else {
        w = f.config.desktopColWidth.clamp(f.fieldType.minDesktopCols, 16);
      }
      if (currentUnits + w > unit && currentRow.isNotEmpty) {
        rows.add(currentRow);
        currentRow = [MapEntry(f, w)];
        currentUnits = w;
      } else {
        currentRow.add(MapEntry(f, w));
        currentUnits += w;
      }
    }
    if (currentRow.isNotEmpty) rows.add(currentRow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: () {
              final widgets = <Widget>[];
              for (final entry in row) {
                if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 12));
                Widget fieldWidget = _FieldInput(
                  key: ValueKey(entry.key.id),
                  field: entry.key,
                  value: values[entry.key.id],
                  files: pendingFiles[entry.key.id] ?? const [],
                  showError: errorFieldIds.contains(entry.key.id),
                  errorMessage: typeErrors[entry.key.id],
                  onChanged: (v) => onValueChanged(entry.key.id, v),
                  onFilesChanged: (f) => onFilesChanged(entry.key.id, f),
                );
                final isDisabled = disabledFields[entry.key.id] == true;
                if (isDisabled) {
                  fieldWidget = Opacity(opacity: 0.45, child: IgnorePointer(child: fieldWidget));
                }
                widgets.add(Expanded(flex: entry.value, child: fieldWidget));
              }
              return widgets;
            }(),
          ),
        );
      }).toList(),
    );
  }
}

// ── Individual field input widgets ─────────────────────────

class _FieldInput extends StatefulWidget {
  final CcFormField field;
  final dynamic value;
  final List<_PendingFile> files;
  final ValueChanged<dynamic> onChanged;
  final ValueChanged<List<_PendingFile>> onFilesChanged;
  final bool showError;
  final String? errorMessage;

  const _FieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.files,
    required this.onChanged,
    required this.onFilesChanged,
    this.showError = false,
    this.errorMessage,
  });

  @override
  State<_FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends State<_FieldInput> with SingleTickerProviderStateMixin {
  late TextEditingController _textCtrl;
  String? _fileTypeError;
  bool _isPickingFile = false;
  bool _overlayShown = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.value?.toString() ?? '');
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_FieldInput old) {
    super.didUpdateWidget(old);
    if (widget.showError && !old.showError) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Widget _errorRow(bool isAr) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 13, color: Colors.red[400]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.errorMessage ?? (isAr ? 'هذا الحقل مطلوب' : 'This field is required'),
                style: TextStyle(fontSize: 11, color: Colors.red[400]),
              ),
            ),
          ],
        ),
      );

  Widget _labelRow(bool isAr) {
    final c = widget.field.config;
    if (widget.field.fieldType.isDisplayOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onBackground),
          children: [
            TextSpan(text: widget.field.label),
            if (c.required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _helper() {
    final h = widget.field.config.helperText;
    if (h == null || h.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(h, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
    );
  }

  InputDecoration _dec({String? hint}) {
    final err = widget.showError;
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: err ? Colors.red.withValues(alpha: 0.03) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: err ? Colors.red[300]! : Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: err ? Colors.red[300]! : Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: err ? Colors.red : AppColors.primary, width: 1.5)),
    );
  }

  /// Reads bytes from a PlatformFile — uses in-memory bytes first,
  /// then falls back to reading from the file path on non-web platforms.
  Uint8List? _resolveBytes(PlatformFile f) {
    if (f.bytes != null) return f.bytes!;
    if (!kIsWeb && f.path != null) {
      try { return File(f.path!).readAsBytesSync(); } catch (_) {}
    }
    return null;
  }

  /// Returns false when the MIME type clearly contradicts the file extension,
  /// catching renamed files (e.g. malware.exe renamed to report.pdf).
  static bool _mimeMatchesExtension(String mime, String ext) {
    final m = mime.toLowerCase();
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'tif', 'heic', 'heif', 'avif', 'svg'};
    const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'mpeg', 'mpg'};
    const audioExts = {'mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma'};

    if (imageExts.contains(ext)) return m.startsWith('image/');
    if (videoExts.contains(ext)) return m.startsWith('video/');
    if (audioExts.contains(ext)) return m.startsWith('audio/');
    if (ext == 'pdf') return m == 'application/pdf';
    if ({'doc', 'docx'}.contains(ext)) return m.contains('word') || m.contains('document') || m.contains('officedocument');
    if ({'xls', 'xlsx'}.contains(ext)) return m.contains('excel') || m.contains('spreadsheet') || m.contains('officedocument');
    if ({'ppt', 'pptx'}.contains(ext)) return m.contains('powerpoint') || m.contains('presentation') || m.contains('officedocument');
    if (ext == 'txt' || ext == 'csv') return m.startsWith('text/');
    // Unknown extension — allow through (don't block what we can't classify)
    return true;
  }

  void _showPickingOverlay() {
    if (_overlayShown) return;
    _overlayShown = true;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
                const SizedBox(width: 16),
                Text(isAr ? 'جاري التحميل…' : 'Loading…',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _overlayShown = false);
  }

  void _dismissPickingOverlay() {
    if (_overlayShown && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// Returns [name] unchanged if it doesn't collide with [used], otherwise
  /// appends " (2)", " (3)", ... before the extension until it's unique.
  String _uniqueFileName(String name, Set<String> used) {
    if (!used.contains(name)) return name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var i = 2;
    while (used.contains('$base ($i)$ext')) {
      i++;
    }
    return '$base ($i)$ext';
  }

  Future<void> _pickFiles() async {
    if (_isPickingFile) return;
    final c = widget.field.config;
    setState(() { _isPickingFile = true; _fileTypeError = null; });
    _showPickingOverlay();
    try {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final allowedExts = c.allowedExtensions.map((e) => e.toLowerCase()).toSet();
      final maxBytes = (c.maxFileSizeMb * 1024 * 1024).round();
      final existingNames = widget.files.map((f) => f.name).toSet();

      debugPrint('[TYPE-CHECK] field=${widget.field.id}  allowedExts=$allowedExts');

      // On web use native browser picker (avoids file_picker onChange timing bug).
      // On mobile use file_picker which handles permissions and paths.
      List<({String name, Uint8List bytes, String mimeType})> rawFiles;
      if (kIsWeb) {
        final picked = await pickFilesNative(
          imageOnly: false,
          allowMultiple: c.maxFileCount > 1,
          allowedExtensions: c.allowedExtensions,
        );
        if (picked == null || !mounted) return; // cancelled
        rawFiles = picked;
      } else {
        try { await FilePicker.platform.clearTemporaryFiles(); } catch (_) {}
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: c.maxFileCount > 1,
          withData: true,
          type: c.allowedExtensions.isEmpty ? FileType.any : FileType.custom,
          allowedExtensions: c.allowedExtensions.isEmpty ? null : c.allowedExtensions,
        );
        if (result == null || !mounted) return;
        rawFiles = result.files.map((f) {
          final bytes = _resolveBytes(f);
          return (name: f.name, bytes: bytes ?? Uint8List(0), mimeType: '');
        }).where((f) => f.bytes.isNotEmpty).toList();
      }

      final typeErrors = <String>[];
      final sizeErrors = <String>[];
      final valid = <_PendingFile>[];
      // Mobile camera captures often share one generic filename (e.g.
      // "image.jpg") across shots — a same-name file is not necessarily
      // the same file, so collisions are disambiguated, not rejected.
      final usedNames = Set<String>.from(existingNames);

      for (final f in rawFiles) {
        if (f.bytes.length > maxBytes) { sizeErrors.add(f.name); continue; }
        if (allowedExts.isNotEmpty) {
          final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
          debugPrint('[TYPE-CHECK] file="${f.name}" ext="$ext" mime="${f.mimeType}" allowed=$allowedExts → ${allowedExts.contains(ext) ? "OK" : "REJECTED"}');
          if (!allowedExts.contains(ext)) { typeErrors.add(f.name); continue; }
          // Also validate MIME type so a renamed file (e.g. script.exe → doc.pdf) is caught.
          if (f.mimeType.isNotEmpty && !_mimeMatchesExtension(f.mimeType, ext)) {
            debugPrint('[TYPE-CHECK] MIME mismatch — ext="$ext" mime="${f.mimeType}"');
            typeErrors.add(f.name); continue;
          }
        } else {
          debugPrint('[TYPE-CHECK] no ext restriction — file="${f.name}" ACCEPTED (allowedExts empty)');
        }
        final uniqueName = _uniqueFileName(f.name, usedNames);
        usedNames.add(uniqueName);
        valid.add(_PendingFile(name: uniqueName, bytes: f.bytes, mimeType: f.mimeType.isEmpty ? null : f.mimeType));
      }

      String? err;
      if (typeErrors.isNotEmpty) {
        final exts = c.allowedExtensions.map((e) => e.toUpperCase()).join(', ');
        err = isAr ? 'نوع الملف غير مدعوم. الأنواع المسموحة: $exts' : 'Wrong file type. Allowed: $exts';
      } else if (sizeErrors.isNotEmpty) {
        err = isAr ? 'الملف أكبر من الحد المسموح (${c.maxFileSizeMb.round()} MB)' : 'File exceeds size limit (${c.maxFileSizeMb.round()} MB)';
      }
      if (err != null) setState(() => _fileTypeError = err);
      if (valid.isEmpty) return;

      final combined = [...widget.files, ...valid];
      final limited = combined.length > c.maxFileCount ? combined.sublist(0, c.maxFileCount) : combined;
      widget.onFilesChanged(limited);
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        setState(() => _fileTypeError = isAr ? 'حدث خطأ، يرجى المحاولة مرة أخرى' : 'Something went wrong. Please try again.');
        debugPrint('[ATTACH] _pickFiles error: $e');
      }
    } finally {
      _dismissPickingOverlay();
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _pickImages() async {
    if (_isPickingFile) return;
    final c = widget.field.config;
    setState(() { _isPickingFile = true; _fileTypeError = null; });
    _showPickingOverlay();
    try {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final maxBytes = (c.maxFileSizeMb * 1024 * 1024).round();
      final existingNames = widget.files.map((f) => f.name).toSet();

      List<({String name, Uint8List bytes, String mimeType})> rawFiles;
      if (kIsWeb) {
        final picked = await pickFilesNative(
          imageOnly: true,
          allowMultiple: c.maxFileCount > 1,
        );
        if (picked == null || !mounted) return;
        rawFiles = picked;
      } else {
        try { await FilePicker.platform.clearTemporaryFiles(); } catch (_) {}
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: c.maxFileCount > 1,
          withData: true,
          type: FileType.image,
        );
        if (result == null || !mounted) return;
        rawFiles = result.files.map((f) {
          final bytes = _resolveBytes(f);
          return (name: f.name, bytes: bytes ?? Uint8List(0), mimeType: 'image/${f.extension ?? 'jpeg'}');
        }).where((f) => f.bytes.isNotEmpty).toList();
      }

      final sizeErrors = <String>[];
      final valid = <_PendingFile>[];
      // Mobile camera captures often share one generic filename (e.g.
      // "image.jpg") across shots — a same-name file is not necessarily
      // the same file, so collisions are disambiguated, not rejected.
      final usedNames = Set<String>.from(existingNames);

      for (final f in rawFiles) {
        if (f.bytes.length > maxBytes) { sizeErrors.add(f.name); continue; }
        final uniqueName = _uniqueFileName(f.name, usedNames);
        usedNames.add(uniqueName);
        valid.add(_PendingFile(name: uniqueName, bytes: f.bytes, mimeType: f.mimeType));
      }

      String? err;
      if (sizeErrors.isNotEmpty) {
        err = isAr ? 'الصورة أكبر من الحد المسموح (${c.maxFileSizeMb.round()} MB)' : 'Image exceeds size limit (${c.maxFileSizeMb.round()} MB)';
      }
      if (err != null) setState(() => _fileTypeError = err);
      if (valid.isEmpty) return;

      final combined = [...widget.files, ...valid];
      final limited = combined.length > c.maxFileCount ? combined.sublist(0, c.maxFileCount) : combined;
      widget.onFilesChanged(limited);
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        setState(() => _fileTypeError = isAr ? 'حدث خطأ، يرجى المحاولة مرة أخرى' : 'Something went wrong. Please try again.');
        debugPrint('[ATTACH] _pickImages error: $e');
      }
    } finally {
      _dismissPickingOverlay();
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Widget _buildAttachmentWidget(bool isAr) {
    final c = widget.field.config;
    final maxCount = c.maxFileCount;
    final files = widget.files;
    final canAdd = files.length < maxCount;

    final hints = [
      if (c.allowedExtensions.isNotEmpty)
        c.allowedExtensions.map((e) => e.toUpperCase()).join(', '),
      if (maxCount > 1) (isAr ? 'الحد الأقصى: $maxCount ملفات' : 'Max $maxCount files'),
    ].join(' • ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow(isAr),
        const SizedBox(height: 6),
        // ── Upload zone ──
        Container(
          decoration: BoxDecoration(
            color: widget.showError
                ? Colors.red.withValues(alpha: 0.03)
                : canAdd
                    ? AppColors.primary.withValues(alpha: 0.03)
                    : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.showError
                  ? Colors.red[300]!
                  : canAdd
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: canAdd ? AppColors.primary.withValues(alpha: 0.10) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 20,
                  color: canAdd ? AppColors.primary : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      canAdd
                          ? (isAr ? 'اختر ملفاً للرفع' : 'Choose a file to upload')
                          : (isAr ? 'تم الوصول للحد الأقصى' : 'Max files reached'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: canAdd ? AppColors.onBackground : Colors.grey[500],
                      ),
                    ),
                    if (hints.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(hints, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (canAdd)
                ElevatedButton(
                  onPressed: _isPickingFile ? null : _pickFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                  child: _isPickingFile
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                    isAr ? 'تصفح' : 'Browse',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        // ── Inline file-type error ──
        if (_fileTypeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _fileTypeError!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        // ── File list ──
        for (final f in files) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.insert_drive_file_rounded, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      Text('${(f.bytes.length / 1024).round()} KB', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onFilesChanged(files.where((x) => x != f).toList()),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close_rounded, size: 14, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ],
        _helper(),
        if (widget.showError) _errorRow(isAr),
      ],
    );
  }

  Widget _buildImageAttachmentWidget(bool isAr) {
    final c = widget.field.config;
    final files = widget.files;
    final canAdd = files.length < c.maxFileCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow(isAr),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in files)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      f.bytes,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 76,
                        height: 76,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: GestureDetector(
                      onTap: () => widget.onFilesChanged(files.where((x) => x != f).toList()),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (canAdd)
              GestureDetector(
                onTap: _isPickingFile ? null : _pickImages,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: widget.showError
                        ? Colors.red.withValues(alpha: 0.04)
                        : AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.showError ? Colors.red[300]! : AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _isPickingFile
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 22, color: AppColors.primary.withValues(alpha: 0.7)),
                            const SizedBox(height: 3),
                            Text(
                              isAr ? 'إضافة' : 'Add',
                              style: TextStyle(fontSize: 10, color: AppColors.primary.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        if (files.isEmpty && c.maxFileCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isAr
                  ? 'اضغط على + لإضافة صور (الحد الأقصى: ${c.maxFileCount})'
                  : 'Tap + to add images (max ${c.maxFileCount})',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        if (_fileTypeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(_fileTypeError!, style: const TextStyle(fontSize: 11, color: Colors.red))),
              ],
            ),
          ),
        _helper(),
        if (widget.showError) _errorRow(isAr),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final field = widget.field;
    final c = field.config;

    Widget input;
    switch (field.fieldType) {
      case CcFieldType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(field.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
        );
      case CcFieldType.divider:
        return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider());

      case CcFieldType.shortText:
        final isNumeric = c.subtype == 'number' || c.subtype == 'percentage';
        input = TextFormField(
          controller: _textCtrl,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))]
              : null,
          decoration: _dec(hint: c.placeholder),
          onChanged: (v) => widget.onChanged(v),
        );
        break;

      case CcFieldType.longText:
        input = TextFormField(
          controller: _textCtrl,
          minLines: c.minRows,
          maxLines: c.maxRows.clamp(c.minRows, 999),
          decoration: _dec(hint: c.placeholder),
          onChanged: (v) => widget.onChanged(v),
        );
        break;

      case CcFieldType.attachment:
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
          child: _buildAttachmentWidget(isAr),
        );

      case CcFieldType.imageAttachment:
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
          child: _buildImageAttachmentWidget(isAr),
        );

      case CcFieldType.singleSelect:
        input = DropdownButtonFormField<String>(
          initialValue: c.options.contains(widget.value) ? widget.value as String? : null,
          decoration: _dec(hint: c.placeholder ?? (isAr ? 'اختر...' : 'Select...')),
          items: c.options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => widget.onChanged(v),
        );
        break;

      case CcFieldType.multiSelect:
        final selected = (widget.value is List ? List<String>.from(widget.value) : <String>[]);
        input = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: c.options.map((o) {
            final isSel = selected.contains(o);
            return FilterChip(
              label: Text(o, style: const TextStyle(fontSize: 12)),
              selected: isSel,
              selectedColor: AppColors.primary.withValues(alpha: 0.18),
              checkmarkColor: AppColors.primary,
              onSelected: (sel) {
                final next = List<String>.from(selected);
                if (sel) {
                  if (c.maxSelections == null || next.length < c.maxSelections!) next.add(o);
                } else {
                  next.remove(o);
                }
                widget.onChanged(next);
              },
            );
          }).toList(),
        );
        break;

      case CcFieldType.checkboxGroup:
        final selected = (widget.value is List ? List<String>.from(widget.value) : <String>[]);
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: c.options
              .map((o) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    value: selected.contains(o),
                    onChanged: (v) {
                      final next = List<String>.from(selected);
                      if (v == true) {
                        next.add(o);
                      } else {
                        next.remove(o);
                      }
                      widget.onChanged(next);
                    },
                  ))
              .toList(),
        );
        break;

      case CcFieldType.radio:
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: c.options
              .map((o) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    value: o,
                    groupValue: widget.value as String?,
                    onChanged: (v) => widget.onChanged(v),
                  ))
              .toList(),
        );
        break;

      case CcFieldType.ranking:
        final order = (widget.value is List ? List<String>.from(widget.value) : List<String>.from(c.options));
        input = ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIdx, newIdx) {
            final next = List<String>.from(order);
            if (newIdx > oldIdx) newIdx--;
            final item = next.removeAt(oldIdx);
            next.insert(newIdx, item);
            widget.onChanged(next);
          },
          children: [
            for (int i = 0; i < order.length; i++)
              Container(
                key: ValueKey(order[i]),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                child: Row(
                  children: [
                    Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order[i], style: const TextStyle(fontSize: 13))),
                    Icon(Icons.drag_handle_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
          ],
        );
        if (widget.value == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(order));
        }
        break;

      case CcFieldType.rating:
        final current = (widget.value as num?)?.toInt() ?? 0;
        input = Row(
          children: List.generate(c.ratingMax, (i) {
            final filled = i < current;
            return IconButton(
              icon: Icon(
                c.ratingStars ? (filled ? Icons.star_rounded : Icons.star_border_rounded) : (filled ? Icons.circle : Icons.circle_outlined),
                color: filled ? Colors.amber[600] : Colors.grey[400],
                size: 26,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => widget.onChanged(i + 1),
            );
          }),
        );
        break;

      case CcFieldType.slider:
        final current = (widget.value as num?)?.toDouble() ?? c.sliderMin;
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: current.clamp(c.sliderMin, c.sliderMax),
              min: c.sliderMin,
              max: c.sliderMax,
              divisions: c.sliderStep > 0 ? ((c.sliderMax - c.sliderMin) / c.sliderStep).round().clamp(1, 1000) : null,
              activeColor: AppColors.primary,
              label: '${current.toStringAsFixed(0)}${c.sliderUnit}',
              onChanged: (v) => widget.onChanged(v),
            ),
            Text('${current.toStringAsFixed(0)}${c.sliderUnit}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        );
        break;

      case CcFieldType.datePicker:
        input = _PickerButton(
          icon: Icons.calendar_today_rounded,
          label: widget.value?.toString() ?? (isAr ? 'اختر تاريخاً' : 'Pick a date'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) widget.onChanged(DateFormat('yyyy-MM-dd').format(picked));
          },
        );
        break;

      case CcFieldType.timePicker:
        input = _PickerButton(
          icon: Icons.access_time_rounded,
          label: widget.value?.toString() ?? (isAr ? 'اختر وقتاً' : 'Pick a time'),
          onTap: () async {
            final localizations = MaterialLocalizations.of(context);
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (picked != null) {
              widget.onChanged(localizations.formatTimeOfDay(picked));
            }
          },
        );
        break;

      case CcFieldType.dateTimePicker:
        input = _PickerButton(
          icon: Icons.event_rounded,
          label: widget.value?.toString() ?? (isAr ? 'اختر تاريخاً ووقتاً' : 'Pick date & time'),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date == null) return;
            if (!context.mounted) return;
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (time == null) return;
            final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            widget.onChanged(DateFormat('yyyy-MM-dd HH:mm').format(combined));
          },
        );
        break;

      case CcFieldType.yesNo:
        input = Row(
          children: [
            Switch(value: widget.value == true, activeThumbColor: AppColors.primary, onChanged: (v) => widget.onChanged(v)),
            Text(widget.value == true ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No'), style: const TextStyle(fontSize: 13)),
          ],
        );
        break;

      case CcFieldType.phone:
        input = TextFormField(
          controller: _textCtrl,
          keyboardType: TextInputType.phone,
          decoration: _dec(hint: c.defaultCountryCode),
          onChanged: (v) => widget.onChanged(v),
        );
        break;

      case CcFieldType.imageChoice:
        input = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: c.imageUrls.asMap().entries.map((e) {
            final selected = widget.value == e.value;
            return GestureDetector(
              onTap: () => widget.onChanged(e.value),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppColors.primary : Colors.grey[300]!, width: selected ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(e.value, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined)),
                ),
              ),
            );
          }).toList(),
        );
        break;

      case CcFieldType.signature:
        input = _SignaturePad(
          initialPoints: widget.value is List ? widget.value as List : null,
          onChanged: (pts) => widget.onChanged(pts),
        );
        break;

      case CcFieldType.styledSelect:
        final currentId = widget.value is String ? widget.value as String : null;
        final opts = c.styledSelectOptions;
        if (opts.isEmpty) {
          input = Text(isAr ? 'لا توجد خيارات' : 'No options configured',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400));
        } else {
          input = Wrap(
            spacing: 8, runSpacing: 8,
            children: opts.map((opt) {
              final sel = currentId == opt.id;
              return GestureDetector(
                onTap: () => widget.onChanged(sel ? null : opt.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? opt.bgColorValue : opt.bgColorValue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? opt.bgColorValue : opt.bgColorValue.withValues(alpha: 0.4),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Text(opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        color: sel ? opt.textColorValue : opt.bgColorValue,
                      )),
                ),
              );
            }).toList(),
          );
        }
        break;
    }

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelRow(isAr),
          input,
          _helper(),
          if (widget.showError) _errorRow(isAr),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _SignaturePad extends StatefulWidget {
  final List? initialPoints;
  final ValueChanged<List<List<double>>> onChanged;

  const _SignaturePad({required this.initialPoints, required this.onChanged});

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];

  void _emit() {
    widget.onChanged(_strokes
        .map((s) => s.expand((o) => [o.dx, o.dy]).toList())
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              onPanEnd: (_) => _emit(),
              child: CustomPaint(
                painter: _SignaturePainter(_strokes),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () {
            setState(() => _strokes.clear());
            _emit();
          },
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: Text(isAr ? 'مسح' : 'Clear', style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}


class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
