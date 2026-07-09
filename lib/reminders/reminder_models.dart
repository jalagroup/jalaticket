import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────

enum ReminderDataSourceType {
  api('api'),
  internal('internal'),
  excel('excel');

  const ReminderDataSourceType(this.value);
  final String value;
  static ReminderDataSourceType fromString(String v) =>
      ReminderDataSourceType.values.firstWhere((e) => e.value == v,
          orElse: () => ReminderDataSourceType.api);

  String get label => switch (this) {
    api => 'External API',
    internal => 'Internal Table',
    excel => 'Excel / Static',
  };
  String get labelAr => switch (this) {
    api => 'API خارجي',
    internal => 'جدول داخلي',
    excel => 'إكسيل / ثابت',
  };
  IconData get icon => switch (this) {
    api => Icons.api_rounded,
    internal => Icons.table_chart_rounded,
    excel => Icons.grid_on_rounded,
  };
}

enum ReminderScheduleType {
  interval('interval'),
  daily('daily'),
  weekly('weekly'),
  custom('custom');

  const ReminderScheduleType(this.value);
  final String value;
  static ReminderScheduleType fromString(String v) =>
      ReminderScheduleType.values.firstWhere((e) => e.value == v,
          orElse: () => ReminderScheduleType.interval);

  String get label => switch (this) {
    interval => 'Every interval',
    daily => 'Daily at time',
    weekly => 'Weekly',
    custom => 'Custom (cron)',
  };
  String get labelAr => switch (this) {
    interval => 'كل فترة زمنية',
    daily => 'يومياً في وقت محدد',
    weekly => 'أسبوعياً',
    custom => 'مخصص (cron)',
  };
}

enum ReminderRecipientType {
  creator('creator'),
  mappedUserId('mapped_user_id'),
  mappedEmail('mapped_email'),
  broadcastEmail('broadcast_email'),
  specificUsers('specific_users');

  const ReminderRecipientType(this.value);
  final String value;
  static ReminderRecipientType fromString(String v) =>
      ReminderRecipientType.values.firstWhere((e) => e.value == v,
          orElse: () => ReminderRecipientType.creator);

  String get label => switch (this) {
    creator => 'Notify me (creator)',
    mappedUserId => 'Map field → System user ID',
    mappedEmail => 'Map field → Email in system',
    broadcastEmail => 'Send to email field directly',
    specificUsers => 'Specific users',
  };
  String get labelAr => switch (this) {
    creator => 'إشعاري أنا (المنشئ)',
    mappedUserId => 'ربط حقل → رقم مستخدم في النظام',
    mappedEmail => 'ربط حقل → بريد في النظام',
    broadcastEmail => 'إرسال مباشر لحقل البريد',
    specificUsers => 'مستخدمون محددون',
  };
}

enum ReminderConditionRule {
  equals('equals'),
  notEquals('not_equals'),
  contains('contains'),
  greaterThan('greater_than'),
  lessThan('less_than'),
  greaterEqual('greater_equal'),
  lessEqual('less_equal'),
  isEmpty('is_empty'),
  isNotEmpty('is_not_empty'),
  daysUntilLte('days_until_lte'),
  daysUntilGte('days_until_gte'),
  daysSinceLte('days_since_lte'),
  daysSinceGte('days_since_gte');

  const ReminderConditionRule(this.value);
  final String value;
  static ReminderConditionRule fromString(String v) =>
      ReminderConditionRule.values.firstWhere((e) => e.value == v,
          orElse: () => ReminderConditionRule.equals);

  String get label => switch (this) {
    equals => 'equals',
    notEquals => 'not equals',
    contains => 'contains',
    greaterThan => 'greater than',
    lessThan => 'less than',
    greaterEqual => '>= (≥)',
    lessEqual => '<= (≤)',
    isEmpty => 'is empty',
    isNotEmpty => 'is not empty',
    daysUntilLte => 'days until ≤',
    daysUntilGte => 'days until ≥',
    daysSinceLte => 'days since ≤',
    daysSinceGte => 'days since ≥',
  };
  String get labelAr => switch (this) {
    equals => 'يساوي',
    notEquals => 'لا يساوي',
    contains => 'يحتوي',
    greaterThan => 'أكبر من',
    lessThan => 'أصغر من',
    greaterEqual => 'أكبر أو يساوي',
    lessEqual => 'أصغر أو يساوي',
    isEmpty => 'فارغ',
    isNotEmpty => 'غير فارغ',
    daysUntilLte => 'أيام حتى ≤',
    daysUntilGte => 'أيام حتى ≥',
    daysSinceLte => 'أيام منذ ≤',
    daysSinceGte => 'أيام منذ ≥',
  };
  bool get needsValue => this != isEmpty && this != isNotEmpty;
}

// ── Models ─────────────────────────────────────────────────────

class ReminderCondition {
  String field;
  ReminderConditionRule rule;
  dynamic value;

  ReminderCondition({
    required this.field,
    this.rule = ReminderConditionRule.equals,
    this.value,
  });

  factory ReminderCondition.fromJson(Map<String, dynamic> j) => ReminderCondition(
    field: j['field'] as String? ?? '',
    rule: ReminderConditionRule.fromString(j['rule'] as String? ?? 'equals'),
    value: j['value'],
  );

  Map<String, dynamic> toJson() => {
    'field': field,
    'rule': rule.value,
    'value': value,
  };
}

class SmartReminder {
  final String id;
  final String ownerUserId;
  String title;
  String? description;
  bool isActive;

  ReminderDataSourceType dataSourceType;
  Map<String, dynamic> dataSourceConfig;

  ReminderScheduleType scheduleType;
  Map<String, dynamic> scheduleConfig;

  bool hasCondition;
  List<ReminderCondition> conditions;
  String conditionOperator;

  List<String> channels;
  String msgTitleTemplate;
  String msgBodyTemplate;
  Map<String, dynamic> recipientConfig;

  DateTime? lastRunAt;
  DateTime? nextRunAt;
  int runCount;

  final DateTime createdAt;
  DateTime updatedAt;

  SmartReminder({
    required this.id,
    required this.ownerUserId,
    required this.title,
    this.description,
    this.isActive = true,
    this.dataSourceType = ReminderDataSourceType.api,
    Map<String, dynamic>? dataSourceConfig,
    this.scheduleType = ReminderScheduleType.interval,
    Map<String, dynamic>? scheduleConfig,
    this.hasCondition = false,
    List<ReminderCondition>? conditions,
    this.conditionOperator = 'and',
    List<String>? channels,
    this.msgTitleTemplate = '',
    this.msgBodyTemplate = '',
    Map<String, dynamic>? recipientConfig,
    this.lastRunAt,
    this.nextRunAt,
    this.runCount = 0,
    required this.createdAt,
    required this.updatedAt,
  })  : dataSourceConfig = dataSourceConfig ?? {},
        scheduleConfig = scheduleConfig ?? {'every_minutes': 60},
        conditions = conditions ?? [],
        channels = channels ?? ['app'],
        recipientConfig = recipientConfig ?? {'type': 'creator'};

  factory SmartReminder.fromJson(Map<String, dynamic> j) => SmartReminder(
    id: j['id'] as String,
    ownerUserId: j['owner_user_id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    isActive: j['is_active'] as bool? ?? true,
    dataSourceType: ReminderDataSourceType.fromString(j['data_source_type'] as String? ?? 'api'),
    dataSourceConfig: Map<String, dynamic>.from(j['data_source_config'] as Map? ?? {}),
    scheduleType: ReminderScheduleType.fromString(j['schedule_type'] as String? ?? 'interval'),
    scheduleConfig: Map<String, dynamic>.from(j['schedule_config'] as Map? ?? {'every_minutes': 60}),
    hasCondition: j['has_condition'] as bool? ?? false,
    conditions: (j['conditions'] as List? ?? [])
        .map((c) => ReminderCondition.fromJson(c as Map<String, dynamic>))
        .toList(),
    conditionOperator: j['condition_operator'] as String? ?? 'and',
    channels: List<String>.from(j['channels'] as List? ?? ['app']),
    msgTitleTemplate: j['msg_title_template'] as String? ?? '',
    msgBodyTemplate: j['msg_body_template'] as String? ?? '',
    recipientConfig: Map<String, dynamic>.from(j['recipient_config'] as Map? ?? {'type': 'creator'}),
    lastRunAt: j['last_run_at'] != null ? DateTime.parse(j['last_run_at'] as String) : null,
    nextRunAt: j['next_run_at'] != null ? DateTime.parse(j['next_run_at'] as String) : null,
    runCount: j['run_count'] as int? ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'owner_user_id': ownerUserId,
    'title': title,
    'description': description,
    'is_active': isActive,
    'data_source_type': dataSourceType.value,
    'data_source_config': dataSourceConfig,
    'schedule_type': scheduleType.value,
    'schedule_config': scheduleConfig,
    'has_condition': hasCondition,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'condition_operator': conditionOperator,
    'channels': channels,
    'msg_title_template': msgTitleTemplate,
    'msg_body_template': msgBodyTemplate,
    'recipient_config': recipientConfig,
  };

  String get scheduleLabel {
    switch (scheduleType) {
      case ReminderScheduleType.interval:
        final m = scheduleConfig['every_minutes'] as int? ?? 60;
        if (m >= 10080) return 'Every ${m ~/ 10080} week(s)';
        if (m >= 1440) return 'Every ${m ~/ 1440} day(s)';
        if (m >= 60) return 'Every ${m ~/ 60} hour(s)';
        return 'Every $m minute(s)';
      case ReminderScheduleType.daily:
        final times = List<String>.from(scheduleConfig['times'] as List? ?? ['09:00']);
        return 'Daily at ${times.join(', ')}';
      case ReminderScheduleType.weekly:
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final dow = List<int>.from(scheduleConfig['days_of_week'] as List? ?? [1]);
        final t = scheduleConfig['time'] as String? ?? '09:00';
        return 'Weekly on ${dow.map((d) => days[d % 7]).join(', ')} at $t';
      case ReminderScheduleType.custom:
        return scheduleConfig['expression'] as String? ?? 'Custom';
    }
  }
}

class ReminderRun {
  final String id;
  final String reminderId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;
  final int recordsFetched;
  final int notificationsSent;
  final String? errorMessage;

  ReminderRun({
    required this.id,
    required this.reminderId,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.recordsFetched,
    required this.notificationsSent,
    this.errorMessage,
  });

  factory ReminderRun.fromJson(Map<String, dynamic> j) => ReminderRun(
    id: j['id'] as String,
    reminderId: j['reminder_id'] as String,
    startedAt: DateTime.parse(j['started_at'] as String),
    completedAt: j['completed_at'] != null ? DateTime.parse(j['completed_at'] as String) : null,
    status: j['status'] as String? ?? 'unknown',
    recordsFetched: j['records_fetched'] as int? ?? 0,
    notificationsSent: j['notifications_sent'] as int? ?? 0,
    errorMessage: j['error_message'] as String?,
  );

  Color get statusColor => switch (status) {
    'success' => const Color(0xFF22C55E),
    'failed' => const Color(0xFFEF4444),
    'skipped' => const Color(0xFFF59E0B),
    _ => const Color(0xFF94A3B8),
  };
}
