import '../models.dart' show UserModel;
import '../reminders/reminder_models.dart';
import '../reminders/reminder_service.dart';

/// Configures fleet vehicle alerts (license/insurance/tachograph/winter
/// inspection expiry + service-due + daily odometer check-in) as real Smart
/// Reminders, using the same engine/table/edge-functions every other
/// reminder in the app uses — so they show up in the Reminders tab and
/// deliver via push+email+in-app like everything else, instead of a bespoke
/// fleet-only alert mechanism.
const fleetReminderTitlePrefix = 'Fleet: ';

/// Every vehicle can have multiple drivers now (fleet_vehicle_drivers), so
/// all fleet reminders notify every assigned driver via this generic
/// join-based recipient type rather than a single scalar field — and also
/// each driver's own direct manager (users.direct_manager_id), since a
/// vehicle no longer has its own manager field.
const _kFleetRecipientConfig = {
  'type': 'mapped_user_ids_from_join',
  'join_table': 'fleet_vehicle_drivers',
  'join_fk_column': 'vehicle_id',
  'join_user_column': 'user_id',
  'also_notify_managers': true,
};

class _FleetReminderSpec {
  final String key;
  final String? field;
  final ReminderConditionRule? rule;
  final dynamic value;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  const _FleetReminderSpec({
    required this.key,
    this.field,
    this.rule,
    this.value,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  bool get hasCondition => field != null;
}

final List<_FleetReminderSpec> _fleetReminderSpecs = [
  _FleetReminderSpec(
    key: 'License expiry',
    field: 'license_expiry',
    rule: ReminderConditionRule.daysUntilLte,
    value: 14,
    titleAr: 'تنبيه: رخصة المركبة {{vehicle_number}}',
    titleEn: 'Vehicle license expiring',
    bodyAr: 'رخصة المركبة {{vehicle_number}} تنتهي خلال {{days_until.license_expiry}} يوم. يرجى التجديد.',
    bodyEn: 'Vehicle {{vehicle_number}} license expires in {{days_until.license_expiry}} day(s). Please renew.',
  ),
  _FleetReminderSpec(
    key: 'Insurance expiry',
    field: 'insurance_expiry',
    rule: ReminderConditionRule.daysUntilLte,
    value: 14,
    titleAr: 'تنبيه: تأمين المركبة {{vehicle_number}}',
    titleEn: 'Vehicle insurance expiring',
    bodyAr: 'تأمين المركبة {{vehicle_number}} ينتهي خلال {{days_until.insurance_expiry}} يوم. يرجى التجديد.',
    bodyEn: 'Vehicle {{vehicle_number}} insurance expires in {{days_until.insurance_expiry}} day(s). Please renew.',
  ),
  _FleetReminderSpec(
    key: 'Tachograph expiry',
    field: 'tachograph_expiry',
    rule: ReminderConditionRule.daysUntilLte,
    value: 14,
    titleAr: 'تنبيه: تاكوغراف المركبة {{vehicle_number}}',
    titleEn: 'Vehicle tachograph expiring',
    bodyAr: 'تاكوغراف المركبة {{vehicle_number}} ينتهي خلال {{days_until.tachograph_expiry}} يوم. يرجى التجديد.',
    bodyEn: 'Vehicle {{vehicle_number}} tachograph expires in {{days_until.tachograph_expiry}} day(s). Please renew.',
  ),
  _FleetReminderSpec(
    key: 'Winter inspection',
    field: 'winter_inspection_date',
    rule: ReminderConditionRule.daysUntilLte,
    value: 14,
    titleAr: 'تنبيه: فحص الشتاء للمركبة {{vehicle_number}}',
    titleEn: 'Vehicle winter inspection due',
    bodyAr: 'فحص الشتاء للمركبة {{vehicle_number}} خلال {{days_until.winter_inspection_date}} يوم.',
    bodyEn: 'Vehicle {{vehicle_number}} winter inspection is due in {{days_until.winter_inspection_date}} day(s).',
  ),
  _FleetReminderSpec(
    key: 'Service due',
    field: 'service_due',
    rule: ReminderConditionRule.equals,
    value: true,
    titleAr: 'تنبيه: صيانة المركبة {{vehicle_number}}',
    titleEn: 'Vehicle service due',
    bodyAr: 'المركبة {{vehicle_number}} بحاجة إلى صيانة الآن (العداد الحالي {{current_odometer}} كم).',
    bodyEn: 'Vehicle {{vehicle_number}} is due for service now (odometer {{current_odometer}} km).',
  ),
  _FleetReminderSpec(
    key: 'Daily odometer check-in',
    // No condition — fires for every vehicle every day, since the generic
    // reminders engine has no clean way to condition on "no check-in logged
    // yet today" against a separate table.
    titleAr: 'تذكير: تحديث عداد المركبة {{vehicle_number}}',
    titleEn: 'Reminder: update vehicle {{vehicle_number}} odometer',
    bodyAr: 'يرجى تسجيل الدخول/الخروج وتحديث قراءة العداد للمركبة {{vehicle_number}} اليوم.',
    bodyEn: 'Please check in/out and log today\'s odometer reading for vehicle {{vehicle_number}}.',
  ),
];

/// Creates the fleet reminders for [currentUser] if they don't already
/// exist (matched by title prefix), or updates them in place if they do —
/// so re-running this after a recipient-mechanism change (e.g. moving from
/// single-driver to multi-driver) actually fixes already-created reminders
/// instead of leaving them on the old, now-broken config. Returns how many
/// were created (existing ones are silently refreshed).
Future<int> setupFleetReminders(UserModel currentUser) async {
  final existing = await ReminderService.getAll();
  final existingByTitle = {for (final r in existing) r.title: r};
  final isAr = currentUser.language == 'ar';

  var created = 0;
  for (final spec in _fleetReminderSpecs) {
    final title = '$fleetReminderTitlePrefix${spec.key}';
    final data = {
      'title': title,
      'description': isAr ? 'تنبيه تلقائي لأسطول المركبات' : 'Auto-configured fleet reminder',
      'is_active': true,
      'data_source_type': ReminderDataSourceType.internal.value,
      'data_source_config': {'table': 'fleet_vehicles'},
      'schedule_type': ReminderScheduleType.daily.value,
      'schedule_config': {
        'times': ['08:00']
      },
      'has_condition': spec.hasCondition,
      'conditions': spec.hasCondition
          ? [ReminderCondition(field: spec.field!, rule: spec.rule!, value: spec.value).toJson()]
          : [],
      'condition_operator': 'and',
      'channels': const ['app', 'email'],
      'msg_title_template': isAr ? spec.titleAr : spec.titleEn,
      'msg_body_template': isAr ? spec.bodyAr : spec.bodyEn,
      'recipient_config': _kFleetRecipientConfig,
    };

    final existingReminder = existingByTitle[title];
    if (existingReminder != null) {
      await ReminderService.update(existingReminder.id, data);
      continue;
    }

    final reminder = SmartReminder(
      id: '',
      ownerUserId: currentUser.id,
      title: title,
      description: data['description'] as String?,
      isActive: true,
      dataSourceType: ReminderDataSourceType.internal,
      dataSourceConfig: data['data_source_config'] as Map<String, dynamic>,
      scheduleType: ReminderScheduleType.daily,
      scheduleConfig: data['schedule_config'] as Map<String, dynamic>,
      hasCondition: spec.hasCondition,
      conditions: spec.hasCondition ? [ReminderCondition(field: spec.field!, rule: spec.rule!, value: spec.value)] : [],
      conditionOperator: 'and',
      channels: const ['app', 'email'],
      msgTitleTemplate: isAr ? spec.titleAr : spec.titleEn,
      msgBodyTemplate: isAr ? spec.bodyAr : spec.bodyEn,
      recipientConfig: _kFleetRecipientConfig,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ReminderService.create(reminder);
    created++;
  }
  return created;
}
