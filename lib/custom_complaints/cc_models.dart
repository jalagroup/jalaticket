import 'dart:ui';

// ── Enums ─────────────────────────────────────────────────

enum CcIdentityMode {
  identified('identified'),
  anonymous('anonymous'),
  choice('choice');

  const CcIdentityMode(this.value);
  final String value;

  static CcIdentityMode fromString(String v) =>
      CcIdentityMode.values.firstWhere((e) => e.value == v,
          orElse: () => CcIdentityMode.identified);
}

enum CcProgressStyle {
  numbered('numbered'),
  percentage('percentage'),
  dotted('dotted');

  const CcProgressStyle(this.value);
  final String value;

  static CcProgressStyle fromString(String v) =>
      CcProgressStyle.values.firstWhere((e) => e.value == v,
          orElse: () => CcProgressStyle.numbered);
}

enum CcSubmissionStatus {
  pending('pending'),
  resolved('resolved'),
  misleading('misleading');

  const CcSubmissionStatus(this.value);
  final String value;

  static CcSubmissionStatus fromString(String v) =>
      CcSubmissionStatus.values.firstWhere((e) => e.value == v,
          orElse: () => CcSubmissionStatus.pending);
}

enum CcFieldType {
  shortText('short_text'),
  longText('long_text'),
  attachment('attachment'),
  singleSelect('single_select'),
  multiSelect('multi_select'),
  checkboxGroup('checkbox_group'),
  radio('radio'),
  ranking('ranking'),
  rating('rating'),
  slider('slider'),
  datePicker('date_picker'),
  timePicker('time_picker'),
  dateTimePicker('date_time_picker'),
  yesNo('yes_no'),
  phone('phone'),
  imageChoice('image_choice'),
  heading('heading'),
  divider('divider'),
  signature('signature'),
  imageAttachment('image_attachment'),
  styledSelect('styled_select');

  const CcFieldType(this.value);
  final String value;

  static CcFieldType fromString(String v) =>
      CcFieldType.values.firstWhere((e) => e.value == v,
          orElse: () => CcFieldType.shortText);

  String get displayName {
    switch (this) {
      case shortText:        return 'Short Text';
      case longText:         return 'Long Text';
      case attachment:       return 'Attachment';
      case imageAttachment:  return 'Image Upload';
      case singleSelect:     return 'Dropdown';
      case multiSelect:      return 'Multi-Select';
      case checkboxGroup:    return 'Checkboxes';
      case radio:            return 'Radio';
      case ranking:          return 'Ranking';
      case rating:           return 'Rating';
      case slider:           return 'Slider';
      case datePicker:       return 'Date';
      case timePicker:       return 'Time';
      case dateTimePicker:   return 'Date & Time';
      case yesNo:            return 'Yes / No';
      case phone:            return 'Phone';
      case imageChoice:      return 'Image Choice';
      case heading:          return 'Heading';
      case divider:          return 'Divider';
      case signature:        return 'Signature';
      case styledSelect:     return 'Status Selector';
    }
  }

  String get displayNameAr {
    switch (this) {
      case shortText:        return 'نص قصير';
      case longText:         return 'نص طويل';
      case attachment:       return 'مرفق';
      case imageAttachment:  return 'رفع صور';
      case singleSelect:     return 'قائمة منسدلة';
      case multiSelect:      return 'اختيار متعدد';
      case checkboxGroup:    return 'مربعات اختيار';
      case radio:            return 'اختيار واحد';
      case ranking:          return 'ترتيب';
      case rating:           return 'تقييم';
      case slider:           return 'شريط تمرير';
      case datePicker:       return 'تاريخ';
      case timePicker:       return 'وقت';
      case dateTimePicker:   return 'تاريخ ووقت';
      case yesNo:            return 'نعم / لا';
      case phone:            return 'هاتف';
      case imageChoice:      return 'اختيار صورة';
      case heading:          return 'عنوان';
      case divider:          return 'فاصل';
      case signature:        return 'توقيع';
      case styledSelect:     return 'محدد الحالة';
    }
  }

  bool get isDisplayOnly => this == heading || this == divider;
  bool get isAlwaysFullWidth =>
      this == longText || this == attachment || this == imageAttachment ||
      this == ranking || this == signature || this == heading || this == divider;

  // Minimum desktop columns (out of 16)
  int get minDesktopCols {
    switch (this) {
      case longText: case ranking: case signature:
      case heading: case divider: return 8;
      case attachment: case imageAttachment: case multiSelect: case checkboxGroup: return 6;
      case datePicker: case dateTimePicker: case phone: return 5;
      default: return 4;
    }
  }

  int get defaultDesktopCols {
    if (isAlwaysFullWidth) return 16;
    switch (this) {
      case singleSelect: case multiSelect: return 8;
      default: return 8;
    }
  }
}

// ── Styled select option ──────────────────────────────────
class StyledSelectOption {
  final String id;
  final String label;
  final String bgColor;     // hex e.g. '#4CAF50'
  final double bgOpacity;   // 0.0–1.0
  final String textColor;   // hex e.g. '#FFFFFF'
  final double textOpacity; // 0.0–1.0

  const StyledSelectOption({
    required this.id,
    required this.label,
    this.bgColor = '#E0E0E0',
    this.bgOpacity = 1.0,
    this.textColor = '#212121',
    this.textOpacity = 1.0,
  });

  factory StyledSelectOption.fromJson(Map<String, dynamic> j) =>
      StyledSelectOption(
        id: j['id'] as String? ?? 'opt_${j.hashCode}',
        label: j['label'] as String? ?? '',
        bgColor: j['bg_color'] as String? ?? '#E0E0E0',
        bgOpacity: (j['bg_opacity'] as num?)?.toDouble() ?? 1.0,
        textColor: j['text_color'] as String? ?? '#212121',
        textOpacity: (j['text_opacity'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'bg_color': bgColor,
        'bg_opacity': bgOpacity,
        'text_color': textColor,
        'text_opacity': textOpacity,
      };

  Color get bgColorValue => _hexColor(bgColor, bgOpacity);
  Color get textColorValue => _hexColor(textColor, textOpacity);

  static Color _hexColor(String hex, double opacity) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16)).withValues(alpha: opacity);
    } catch (_) {
      return const Color(0xFFE0E0E0);
    }
  }
}

// ── Group models ──────────────────────────────────────────

class CcGroup {
  final String id;
  final String ownerUserId;
  String name;
  final DateTime createdAt;
  List<CcGroupMember> members;

  CcGroup({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.createdAt,
    List<CcGroupMember>? members,
  }) : members = members ?? [];

  factory CcGroup.fromJson(Map<String, dynamic> j) => CcGroup(
        id: j['id'] as String,
        ownerUserId: j['owner_user_id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_user_id': ownerUserId,
        'name': name,
      };
}

class CcGroupMember {
  final String id;
  final String groupId;
  final String userId;
  // Joined field for display
  final String? userFullName;
  final String? userEmail;

  CcGroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.userFullName,
    this.userEmail,
  });

  factory CcGroupMember.fromJson(Map<String, dynamic> j) => CcGroupMember(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        userId: j['user_id'] as String,
        userFullName: j['users']?['full_name'] as String?,
        userEmail: j['users']?['email'] as String?,
      );
}

// ── Form model ────────────────────────────────────────────

class CcForm {
  final String id;
  final String ownerUserId;
  String title;
  String? logoUrl;
  String themeColor;
  CcIdentityMode identityMode;
  bool externalApplyEnabled;
  bool showOnboarding;
  Map<String, dynamic>? onboardingConfig;
  bool showClosing;
  Map<String, dynamic>? closingConfig;
  CcProgressStyle progressStyle;
  bool isActive;
  bool notifyCreatorOnSubmit;
  String? notifyEmail;
  bool allowBack;
  final DateTime createdAt;
  DateTime updatedAt;

  // Joined
  List<CcFormStep> steps;
  List<CcFormAudience> audience;

  CcForm({
    required this.id,
    required this.ownerUserId,
    required this.title,
    this.logoUrl,
    required this.themeColor,
    required this.identityMode,
    required this.externalApplyEnabled,
    required this.showOnboarding,
    this.onboardingConfig,
    required this.showClosing,
    this.closingConfig,
    required this.progressStyle,
    required this.isActive,
    this.notifyCreatorOnSubmit = false,
    this.notifyEmail,
    this.allowBack = true,
    required this.createdAt,
    required this.updatedAt,
    List<CcFormStep>? steps,
    List<CcFormAudience>? audience,
  })  : steps = steps ?? [],
        audience = audience ?? [];

  factory CcForm.fromJson(Map<String, dynamic> j) => CcForm(
        id: j['id'] as String,
        ownerUserId: j['owner_user_id'] as String,
        title: j['title'] as String? ?? '',
        logoUrl: j['logo_url'] as String?,
        themeColor: j['theme_color'] as String? ?? '#f16936',
        identityMode: CcIdentityMode.fromString(j['identity_mode'] as String? ?? 'identified'),
        externalApplyEnabled: j['external_apply_enabled'] as bool? ?? false,
        showOnboarding: j['show_onboarding'] as bool? ?? false,
        onboardingConfig: j['onboarding_config'] as Map<String, dynamic>?,
        showClosing: j['show_closing'] as bool? ?? false,
        closingConfig: j['closing_config'] as Map<String, dynamic>?,
        progressStyle: CcProgressStyle.fromString(j['progress_style'] as String? ?? 'numbered'),
        isActive: j['is_active'] as bool? ?? true,
        notifyCreatorOnSubmit: j['notify_creator_on_submit'] as bool? ?? false,
        notifyEmail: j['notify_email'] as String?,
        allowBack: j['allow_back'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'owner_user_id': ownerUserId,
        'title': title,
        'logo_url': logoUrl,
        'theme_color': themeColor,
        'identity_mode': identityMode.value,
        'external_apply_enabled': externalApplyEnabled,
        'show_onboarding': showOnboarding,
        'onboarding_config': onboardingConfig,
        'show_closing': showClosing,
        'closing_config': closingConfig,
        'progress_style': progressStyle.value,
        'is_active': isActive,
        'notify_creator_on_submit': notifyCreatorOnSubmit,
        'notify_email': notifyEmail,
        'allow_back': allowBack,
      };

  Color get themeColorValue {
    try {
      final hex = themeColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFf16936);
    }
  }

  // Compute accessible text color for the theme background
  Color get contrastTextColor {
    final bg = themeColorValue;
    final luminance = bg.computeLuminance();
    return luminance > 0.35 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  }

  String get publicSubmitUrl => '/c/submit/$id';
}

// ── Form Audience ─────────────────────────────────────────

class CcFormAudience {
  final String id;
  final String formId;
  final String? userId;
  final String? groupId;
  // Joined display names
  final String? userFullName;
  final String? groupName;

  CcFormAudience({
    required this.id,
    required this.formId,
    this.userId,
    this.groupId,
    this.userFullName,
    this.groupName,
  });

  factory CcFormAudience.fromJson(Map<String, dynamic> j) => CcFormAudience(
        id: j['id'] as String,
        formId: j['form_id'] as String,
        userId: j['user_id'] as String?,
        groupId: j['group_id'] as String?,
        userFullName: j['users']?['full_name'] as String?,
        groupName: j['cc_groups']?['name'] as String?,
      );
}

// ── Form structure ────────────────────────────────────────

class CcFormStep {
  final String id;
  final String formId;
  int orderIndex;
  String title;
  List<CcFormSection> sections;

  CcFormStep({
    required this.id,
    required this.formId,
    required this.orderIndex,
    required this.title,
    List<CcFormSection>? sections,
  }) : sections = sections ?? [];

  factory CcFormStep.fromJson(Map<String, dynamic> j) => CcFormStep(
        id: j['id'] as String,
        formId: j['form_id'] as String,
        orderIndex: j['order_index'] as int? ?? 0,
        title: j['title'] as String? ?? 'Step',
      );

  Map<String, dynamic> toJson() => {
        'form_id': formId,
        'order_index': orderIndex,
        'title': title,
      };
}

class CcFormSection {
  final String id;
  final String stepId;
  int orderIndex;
  String title;
  List<CcFormField> fields;

  CcFormSection({
    required this.id,
    required this.stepId,
    required this.orderIndex,
    required this.title,
    List<CcFormField>? fields,
  }) : fields = fields ?? [];

  factory CcFormSection.fromJson(Map<String, dynamic> j) => CcFormSection(
        id: j['id'] as String,
        stepId: j['step_id'] as String,
        orderIndex: j['order_index'] as int? ?? 0,
        title: j['title'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'step_id': stepId,
        'order_index': orderIndex,
        'title': title,
      };
}

class CcFormField {
  final String id;
  final String sectionId;
  CcFieldType fieldType;
  int orderIndex;
  String label;
  CcFieldConfig config;

  CcFormField({
    required this.id,
    required this.sectionId,
    required this.fieldType,
    required this.orderIndex,
    required this.label,
    required this.config,
  });

  factory CcFormField.fromJson(Map<String, dynamic> j) {
    final type = CcFieldType.fromString(j['field_type'] as String);
    return CcFormField(
      id: j['id'] as String,
      sectionId: j['section_id'] as String,
      fieldType: type,
      orderIndex: j['order_index'] as int? ?? 0,
      label: j['label'] as String? ?? '',
      config: CcFieldConfig.fromJson(j['config'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'section_id': sectionId,
        'field_type': fieldType.value,
        'order_index': orderIndex,
        'label': label,
        'config': config.toJson(),
      };
}

// ── Field configuration ───────────────────────────────────

class CcFieldConfig {
  // Grid
  int desktopColWidth;    // 1-16
  int desktopRowHeight;   // rows
  // Validation
  bool required;
  dynamic minValue;
  dynamic maxValue;
  int? minLength;
  int? maxLength;
  // Display
  String? placeholder;
  String? helperText;
  String? accentColor;
  // Options (for select/checkbox/radio/ranking/imageChoice)
  List<String> options;
  List<String> imageUrls;  // for imageChoice
  // Short text subtype
  String subtype; // 'text'|'number'|'percentage'
  // Rating
  int ratingMax;
  bool ratingStars;
  // Slider
  double sliderMin;
  double sliderMax;
  double sliderStep;
  String sliderUnit;
  // File upload
  List<String> allowedExtensions;
  int maxFileCount;
  double maxFileSizeMb;
  // Rich text
  bool richText;
  // Date
  String? minDate;
  String? maxDate;
  String dateFormat;
  // Phone
  String defaultCountryCode;
  // Yes/No
  bool defaultYesNo;
  // Multi-select constraints
  int? minSelections;
  int? maxSelections;
  // Textarea rows
  int minRows;
  int maxRows;
  // Styled select options
  List<StyledSelectOption> styledSelectOptions;
  // Conditional logic
  List<CcCondition> conditions;
  CcConditionOperator conditionOperator;

  CcFieldConfig({
    this.desktopColWidth = 8,
    this.desktopRowHeight = 1,
    this.required = false,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.placeholder,
    this.helperText,
    this.accentColor,
    List<String>? options,
    List<String>? imageUrls,
    this.subtype = 'text',
    this.ratingMax = 5,
    this.ratingStars = true,
    this.sliderMin = 0,
    this.sliderMax = 100,
    this.sliderStep = 1,
    this.sliderUnit = '',
    List<String>? allowedExtensions,
    this.maxFileCount = 5,
    this.maxFileSizeMb = 10,
    this.richText = false,
    this.minDate,
    this.maxDate,
    this.dateFormat = 'yyyy-MM-dd',
    this.defaultCountryCode = '+966',
    this.defaultYesNo = false,
    this.minSelections,
    this.maxSelections,
    this.minRows = 3,
    this.maxRows = 10,
    List<StyledSelectOption>? styledSelectOptions,
    List<CcCondition>? conditions,
    this.conditionOperator = CcConditionOperator.and,
  })  : options = options ?? [],
        imageUrls = imageUrls ?? [],
        allowedExtensions = allowedExtensions ?? [],
        styledSelectOptions = styledSelectOptions ?? [],
        conditions = conditions ?? [];

  factory CcFieldConfig.fromJson(Map<String, dynamic> j) => CcFieldConfig(
        desktopColWidth: j['desktop_col_width'] as int? ?? 8,
        desktopRowHeight: j['desktop_row_height'] as int? ?? 1,
        required: j['required'] as bool? ?? false,
        minValue: j['min_value'],
        maxValue: j['max_value'],
        minLength: j['min_length'] as int?,
        maxLength: j['max_length'] as int?,
        placeholder: j['placeholder'] as String?,
        helperText: j['helper_text'] as String?,
        accentColor: j['accent_color'] as String?,
        options: List<String>.from(j['options'] as List? ?? []),
        imageUrls: List<String>.from(j['image_urls'] as List? ?? []),
        subtype: j['subtype'] as String? ?? 'text',
        ratingMax: j['rating_max'] as int? ?? 5,
        ratingStars: j['rating_stars'] as bool? ?? true,
        sliderMin: (j['slider_min'] as num?)?.toDouble() ?? 0,
        sliderMax: (j['slider_max'] as num?)?.toDouble() ?? 100,
        sliderStep: (j['slider_step'] as num?)?.toDouble() ?? 1,
        sliderUnit: j['slider_unit'] as String? ?? '',
        allowedExtensions: List<String>.from(j['allowed_extensions'] as List? ?? []),
        maxFileCount: j['max_file_count'] as int? ?? 5,
        maxFileSizeMb: (j['max_file_size_mb'] as num?)?.toDouble() ?? 10,
        richText: j['rich_text'] as bool? ?? false,
        minDate: j['min_date'] as String?,
        maxDate: j['max_date'] as String?,
        dateFormat: j['date_format'] as String? ?? 'yyyy-MM-dd',
        defaultCountryCode: j['default_country_code'] as String? ?? '+966',
        defaultYesNo: j['default_yes_no'] as bool? ?? false,
        minSelections: j['min_selections'] as int?,
        maxSelections: j['max_selections'] as int?,
        minRows: j['min_rows'] as int? ?? 3,
        maxRows: j['max_rows'] as int? ?? 10,
        styledSelectOptions: (j['styled_select_options'] as List? ?? [])
            .map((o) => StyledSelectOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        conditions: (j['conditions'] as List? ?? [])
            .map((c) => CcCondition.fromJson(c as Map<String, dynamic>))
            .toList(),
        conditionOperator: CcConditionOperator.fromString(
            j['condition_operator'] as String? ?? 'and'),
      );

  Map<String, dynamic> toJson() => {
        'desktop_col_width': desktopColWidth,
        'desktop_row_height': desktopRowHeight,
        'required': required,
        'min_value': minValue,
        'max_value': maxValue,
        'min_length': minLength,
        'max_length': maxLength,
        'placeholder': placeholder,
        'helper_text': helperText,
        'accent_color': accentColor,
        'options': options,
        'image_urls': imageUrls,
        'subtype': subtype,
        'rating_max': ratingMax,
        'rating_stars': ratingStars,
        'slider_min': sliderMin,
        'slider_max': sliderMax,
        'slider_step': sliderStep,
        'slider_unit': sliderUnit,
        'allowed_extensions': allowedExtensions,
        'max_file_count': maxFileCount,
        'max_file_size_mb': maxFileSizeMb,
        'rich_text': richText,
        'min_date': minDate,
        'max_date': maxDate,
        'date_format': dateFormat,
        'default_country_code': defaultCountryCode,
        'default_yes_no': defaultYesNo,
        'min_selections': minSelections,
        'max_selections': maxSelections,
        'min_rows': minRows,
        'max_rows': maxRows,
        'styled_select_options': styledSelectOptions.map((o) => o.toJson()).toList(),
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'condition_operator': conditionOperator.value,
      };
}

// ── Conditional logic ─────────────────────────────────────

enum CcConditionOperator {
  and('and'),
  or('or');

  const CcConditionOperator(this.value);
  final String value;

  static CcConditionOperator fromString(String v) =>
      v == 'or' ? CcConditionOperator.or : CcConditionOperator.and;
}

enum CcConditionRule {
  equals('equals'),
  notEquals('not_equals'),
  contains('contains'),
  notContains('not_contains'),
  greaterThan('greater_than'),
  lessThan('less_than'),
  isEmpty('is_empty'),
  isNotEmpty('is_not_empty');

  const CcConditionRule(this.value);
  final String value;

  static CcConditionRule fromString(String v) =>
      CcConditionRule.values.firstWhere((e) => e.value == v,
          orElse: () => CcConditionRule.equals);
}

class CcCondition {
  final String sourceFieldId;
  final CcConditionRule rule;
  final dynamic value;

  CcCondition({
    required this.sourceFieldId,
    required this.rule,
    this.value,
  });

  factory CcCondition.fromJson(Map<String, dynamic> j) => CcCondition(
        sourceFieldId: j['source_field_id'] as String,
        rule: CcConditionRule.fromString(j['rule'] as String? ?? 'equals'),
        value: j['value'],
      );

  Map<String, dynamic> toJson() => {
        'source_field_id': sourceFieldId,
        'rule': rule.value,
        'value': value,
      };
}

// ── Submission models ─────────────────────────────────────

class CcSubmission {
  final String id;
  final String formId;
  final String? submittedByUserId;
  final bool isAnonymous;
  final String? deviceMac;
  final String? deviceType;
  CcSubmissionStatus status;
  final DateTime createdAt;

  // Joined
  final String? submitterFullName;
  List<CcSubmissionValue> values;
  List<CcSubmissionAttachment> attachments;
  List<CcSubmissionNote> notes;

  CcSubmission({
    required this.id,
    required this.formId,
    this.submittedByUserId,
    required this.isAnonymous,
    this.deviceMac,
    this.deviceType,
    required this.status,
    required this.createdAt,
    this.submitterFullName,
    List<CcSubmissionValue>? values,
    List<CcSubmissionAttachment>? attachments,
    List<CcSubmissionNote>? notes,
  })  : values = values ?? [],
        attachments = attachments ?? [],
        notes = notes ?? [];

  factory CcSubmission.fromJson(Map<String, dynamic> j) => CcSubmission(
        id: j['id'] as String,
        formId: j['form_id'] as String,
        submittedByUserId: j['submitted_by_user_id'] as String?,
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        deviceMac: j['device_mac'] as String?,
        deviceType: j['device_type'] as String?,
        status: CcSubmissionStatus.fromString(j['status'] as String? ?? 'pending'),
        createdAt: DateTime.parse(j['created_at'] as String),
        submitterFullName: j['users']?['full_name'] as String?,
      );

  String get displayName {
    if (isAnonymous) return 'Anonymous';
    return submitterFullName ?? 'Unknown';
  }
}

class CcSubmissionValue {
  final String id;
  final String submissionId;
  final String fieldId;
  final dynamic value;

  CcSubmissionValue({
    required this.id,
    required this.submissionId,
    required this.fieldId,
    this.value,
  });

  factory CcSubmissionValue.fromJson(Map<String, dynamic> j) =>
      CcSubmissionValue(
        id: j['id'] as String,
        submissionId: j['submission_id'] as String,
        fieldId: j['field_id'] as String,
        value: j['value'],
      );

  Map<String, dynamic> toJson() => {
        'submission_id': submissionId,
        'field_id': fieldId,
        'value': value,
      };
}

class CcSubmissionAttachment {
  final String id;
  final String submissionId;
  final String? fieldId;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;

  CcSubmissionAttachment({
    required this.id,
    required this.submissionId,
    this.fieldId,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.createdAt,
  });

  factory CcSubmissionAttachment.fromJson(Map<String, dynamic> j) =>
      CcSubmissionAttachment(
        id: j['id'] as String,
        submissionId: j['submission_id'] as String,
        fieldId: j['field_id'] as String?,
        fileUrl: j['file_url'] as String,
        fileName: j['file_name'] as String,
        fileType: j['file_type'] as String?,
        fileSize: j['file_size'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  bool get isImage {
    final t = fileType?.toLowerCase() ?? '';
    return t.contains('image') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.gif') ||
        fileName.toLowerCase().endsWith('.webp');
  }

  String get fileSizeLabel {
    if (fileSize == null) return '';
    final kb = fileSize! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

class CcSubmissionNote {
  final String id;
  final String submissionId;
  final String authorUserId;
  final String note;
  final DateTime createdAt;
  final String? authorFullName;

  CcSubmissionNote({
    required this.id,
    required this.submissionId,
    required this.authorUserId,
    required this.note,
    required this.createdAt,
    this.authorFullName,
  });

  factory CcSubmissionNote.fromJson(Map<String, dynamic> j) =>
      CcSubmissionNote(
        id: j['id'] as String,
        submissionId: j['submission_id'] as String,
        authorUserId: j['author_user_id'] as String,
        note: j['note'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        authorFullName: j['users']?['full_name'] as String?,
      );
}

// ── Onboarding / Closing screen canvas item ───────────────

enum CcCanvasItemType {
  heading('heading'),
  body('body'),
  icon('icon'),
  image('image'),
  spacer('spacer'),
  bullets('bullets'),
  divider('divider'),
  button('button'),
  numberedList('numbered_list');

  const CcCanvasItemType(this.value);
  final String value;

  static CcCanvasItemType fromString(String v) =>
      CcCanvasItemType.values.firstWhere((e) => e.value == v,
          orElse: () => CcCanvasItemType.body);
}

class CcCanvasItem {
  final String id;
  CcCanvasItemType type;
  String? text;
  String? iconName;
  String? imageUrl;
  double fontSize;
  bool bold;
  bool italic;
  String textAlign;
  String textColor;
  double spacerHeight;
  double x;
  double y;
  double width;
  double height;
  // Layer controls
  bool locked;
  bool visible;
  // Visual styling
  double opacity;
  String? bgFill;
  double itemBorderRadius;
  double borderWidth;
  String borderColor;
  double letterSpacing;

  CcCanvasItem({
    required this.id,
    required this.type,
    this.text,
    this.iconName,
    this.imageUrl,
    this.fontSize = 16,
    this.bold = false,
    this.italic = false,
    this.textAlign = 'center',
    this.textColor = '#1A1A1A',
    this.spacerHeight = 24,
    this.x = 20,
    this.y = 20,
    this.width = 320,
    this.height = 60,
    this.locked = false,
    this.visible = true,
    this.opacity = 1.0,
    this.bgFill,
    this.itemBorderRadius = 0,
    this.borderWidth = 0,
    this.borderColor = '#CCCCCC',
    this.letterSpacing = 0,
  });

  factory CcCanvasItem.fromJson(Map<String, dynamic> j) => CcCanvasItem(
        id: j['id'] as String,
        type: CcCanvasItemType.fromString(j['type'] as String? ?? 'body'),
        text: j['text'] as String?,
        iconName: j['icon_name'] as String?,
        imageUrl: j['image_url'] as String?,
        fontSize: (j['font_size'] as num?)?.toDouble() ?? 16,
        bold: j['bold'] as bool? ?? false,
        italic: j['italic'] as bool? ?? false,
        textAlign: j['text_align'] as String? ?? 'center',
        textColor: j['text_color'] as String? ?? '#1A1A1A',
        spacerHeight: (j['spacer_height'] as num?)?.toDouble() ?? 24,
        x: (j['x'] as num?)?.toDouble() ?? 20,
        y: (j['y'] as num?)?.toDouble() ?? 20,
        width: (j['width'] as num?)?.toDouble() ?? 320,
        height: (j['height'] as num?)?.toDouble() ?? 60,
        locked: j['locked'] as bool? ?? false,
        visible: j['visible'] as bool? ?? true,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
        bgFill: j['bg_fill'] as String?,
        itemBorderRadius: (j['item_border_radius'] as num?)?.toDouble() ?? 0,
        borderWidth: (j['border_width'] as num?)?.toDouble() ?? 0,
        borderColor: j['border_color'] as String? ?? '#CCCCCC',
        letterSpacing: (j['letter_spacing'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'text': text,
        'icon_name': iconName,
        'image_url': imageUrl,
        'font_size': fontSize,
        'bold': bold,
        'italic': italic,
        'text_align': textAlign,
        'text_color': textColor,
        'spacer_height': spacerHeight,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'locked': locked,
        'visible': visible,
        'opacity': opacity,
        'bg_fill': bgFill,
        'item_border_radius': itemBorderRadius,
        'border_width': borderWidth,
        'border_color': borderColor,
        'letter_spacing': letterSpacing,
      };

  CcCanvasItem copyWith({
    CcCanvasItemType? type,
    String? text,
    String? iconName,
    String? imageUrl,
    double? fontSize,
    bool? bold,
    bool? italic,
    String? textAlign,
    String? textColor,
    double? spacerHeight,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? locked,
    bool? visible,
    double? opacity,
    String? bgFill,
    double? itemBorderRadius,
    double? borderWidth,
    String? borderColor,
    double? letterSpacing,
  }) =>
      CcCanvasItem(
        id: id,
        type: type ?? this.type,
        text: text ?? this.text,
        iconName: iconName ?? this.iconName,
        imageUrl: imageUrl ?? this.imageUrl,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        textAlign: textAlign ?? this.textAlign,
        textColor: textColor ?? this.textColor,
        spacerHeight: spacerHeight ?? this.spacerHeight,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        locked: locked ?? this.locked,
        visible: visible ?? this.visible,
        opacity: opacity ?? this.opacity,
        bgFill: bgFill ?? this.bgFill,
        itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
        borderWidth: borderWidth ?? this.borderWidth,
        borderColor: borderColor ?? this.borderColor,
        letterSpacing: letterSpacing ?? this.letterSpacing,
      );
}

class CcScreenConfig {
  String backgroundColor;
  String? backgroundImageUrl;
  List<CcCanvasItem> items;

  CcScreenConfig({
    this.backgroundColor = '#FFFFFF',
    this.backgroundImageUrl,
    List<CcCanvasItem>? items,
  }) : items = items ?? [];

  factory CcScreenConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return CcScreenConfig();
    return CcScreenConfig(
      backgroundColor: j['background_color'] as String? ?? '#FFFFFF',
      backgroundImageUrl: j['background_image_url'] as String?,
      items: (j['items'] as List? ?? [])
          .map((i) => CcCanvasItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'background_color': backgroundColor,
        if (backgroundImageUrl != null) 'background_image_url': backgroundImageUrl,
        'items': items.map((i) => i.toJson()).toList(),
      };
}
