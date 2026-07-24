enum UserFieldType {
  text, number, date, dropdown, boolean, email, phone, textarea;

  String get label => switch (this) {
    UserFieldType.text => 'Text',
    UserFieldType.number => 'Number',
    UserFieldType.date => 'Date',
    UserFieldType.dropdown => 'Dropdown',
    UserFieldType.boolean => 'Yes / No',
    UserFieldType.email => 'Email',
    UserFieldType.phone => 'Phone',
    UserFieldType.textarea => 'Multi-line Text',
  };

  static UserFieldType fromString(String? s) => switch (s) {
    'number' => UserFieldType.number,
    'date' => UserFieldType.date,
    'dropdown' => UserFieldType.dropdown,
    'boolean' => UserFieldType.boolean,
    'email' => UserFieldType.email,
    'phone' => UserFieldType.phone,
    'textarea' => UserFieldType.textarea,
    _ => UserFieldType.text,
  };
}

enum UserFieldFillMode {
  optional, adminOnly, userOnly, both;

  String get value => switch (this) {
    UserFieldFillMode.optional => 'optional',
    UserFieldFillMode.adminOnly => 'admin_only',
    UserFieldFillMode.userOnly => 'user_only',
    UserFieldFillMode.both => 'both',
  };

  String get label => switch (this) {
    UserFieldFillMode.optional => 'Optional',
    UserFieldFillMode.adminOnly => 'Admin Only',
    UserFieldFillMode.userOnly => 'User Only',
    UserFieldFillMode.both => 'Both',
  };

  static UserFieldFillMode fromString(String? s) => switch (s) {
    'admin_only' => UserFieldFillMode.adminOnly,
    'user_only' => UserFieldFillMode.userOnly,
    'both' => UserFieldFillMode.both,
    _ => UserFieldFillMode.optional,
  };
}

class UserFieldOption {
  final String value;
  final String label;
  final String? labelAr;

  const UserFieldOption({required this.value, required this.label, this.labelAr});

  factory UserFieldOption.fromJson(Map<String, dynamic> j) => UserFieldOption(
        value: j['value'] as String,
        label: j['label'] as String,
        labelAr: j['label_ar'] as String?,
      );

  Map<String, dynamic> toJson() => {'value': value, 'label': label, if (labelAr != null) 'label_ar': labelAr};
}

class UserFieldDefinition {
  final String id;
  final String label;
  final String? labelAr;
  final UserFieldType fieldType;
  final List<UserFieldOption> fieldOptions;
  final UserFieldFillMode fillMode;
  final bool blocksUserUntilFilled;
  final bool isShownInProfile;
  final int orderIndex;
  final bool isActive;
  final bool isComputed;
  final String? formula;
  final bool isNullable;
  final String? defaultValue;

  const UserFieldDefinition({
    required this.id,
    required this.label,
    this.labelAr,
    required this.fieldType,
    this.fieldOptions = const [],
    required this.fillMode,
    this.blocksUserUntilFilled = false,
    this.isShownInProfile = true,
    this.orderIndex = 0,
    this.isActive = true,
    this.isComputed = false,
    this.formula,
    this.isNullable = true,
    this.defaultValue,
  });

  factory UserFieldDefinition.fromJson(Map<String, dynamic> j) => UserFieldDefinition(
        id: j['id'] as String,
        label: j['label'] as String,
        labelAr: j['label_ar'] as String?,
        fieldType: UserFieldType.fromString(j['field_type'] as String?),
        fieldOptions: (j['field_options'] as List? ?? [])
            .map((o) => UserFieldOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        fillMode: UserFieldFillMode.fromString(j['fill_mode'] as String?),
        blocksUserUntilFilled: j['blocks_user_until_filled'] as bool? ?? false,
        isShownInProfile: j['is_shown_in_profile'] as bool? ?? true,
        orderIndex: j['order_index'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
        isComputed: j['is_computed'] as bool? ?? false,
        formula: j['formula'] as String?,
        isNullable: j['is_nullable'] as bool? ?? true,
        defaultValue: j['default_value'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'label_ar': labelAr,
        'field_type': fieldType.name,
        'field_options': fieldOptions.map((o) => o.toJson()).toList(),
        'fill_mode': fillMode.value,
        'blocks_user_until_filled': blocksUserUntilFilled,
        'is_shown_in_profile': isShownInProfile,
        'order_index': orderIndex,
        'is_active': isActive,
        'is_computed': isComputed,
        'formula': formula,
        'is_nullable': isNullable,
        'default_value': defaultValue,
      };

  String displayLabel(bool isAr) => isAr && labelAr != null ? labelAr! : label;
}

class UserFieldValue {
  final String id;
  final String userId;
  final String fieldId;
  final dynamic value;
  final String? filledByUserId;
  final DateTime updatedAt;

  const UserFieldValue({
    required this.id,
    required this.userId,
    required this.fieldId,
    this.value,
    this.filledByUserId,
    required this.updatedAt,
  });

  factory UserFieldValue.fromJson(Map<String, dynamic> j) => UserFieldValue(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        fieldId: j['field_id'] as String,
        value: j['value'],
        filledByUserId: j['filled_by_user_id'] as String?,
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  String? get displayValue {
    if (value == null) return null;
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }
}
