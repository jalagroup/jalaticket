import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models.dart';
import 'reminder_models.dart';
import 'reminder_service.dart';

class ReminderEditorScreen extends StatefulWidget {
  final UserModel currentUser;
  final SmartReminder? existing;

  const ReminderEditorScreen({
    super.key,
    required this.currentUser,
    this.existing,
  });

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';
  bool get _isEdit => widget.existing != null;

  // Basic
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isActive = true;

  // Data source
  ReminderDataSourceType _dsType = ReminderDataSourceType.api;
  // API
  final _apiUrlCtrl = TextEditingController();
  String _apiMethod = 'GET';
  final _apiPathCtrl = TextEditingController();
  List<Map<String, TextEditingController>> _apiHeaders = [];
  String _authType = 'none';
  final _authValueCtrl = TextEditingController();
  // Internal
  String? _internalTable;
  List<String> _availableTables = [];
  final _selectColsCtrl = TextEditingController(text: '*');
  List<Map<String, dynamic>> _filters = [];
  // Excel
  List<Map<String, dynamic>> _excelRecords = [];
  List<String> _excelColumns = [];

  // Preview fields
  List<String> _previewedFields = [];
  bool _previewLoading = false;

  // Schedule
  ReminderScheduleType _schedType = ReminderScheduleType.interval;
  // Interval
  final _intervalValueCtrl = TextEditingController(text: '1');
  String _intervalUnit = 'hours'; // minutes/hours/days/weeks
  // Daily
  List<TimeOfDay> _dailyTimes = [const TimeOfDay(hour: 9, minute: 0)];
  // Weekly
  List<int> _weeklyDays = [1];
  TimeOfDay _weeklyTime = const TimeOfDay(hour: 9, minute: 0);
  // Custom
  final _cronCtrl = TextEditingController();

  // Conditions
  bool _hasCondition = false;
  String _condOperator = 'and';
  List<ReminderCondition> _conditions = [];

  // Recipients
  ReminderRecipientType _recipientType = ReminderRecipientType.creator;
  final _mappedFieldCtrl = TextEditingController();
  bool _alsoNotifyCreator = false;
  List<Map<String, dynamic>> _allUsers = [];
  List<String> _selectedUserIds = [];

  // Message
  final _msgTitleCtrl = TextEditingController();
  final _msgBodyCtrl = TextEditingController();

  // Channels
  bool _chanApp = true;
  bool _chanEmail = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    _availableTables = await ReminderService.getAvailableTables();
    _allUsers = await ReminderService.getAllUsers();
    if (mounted) setState(() {});

    final e = widget.existing;
    if (e == null) return;

    _titleCtrl.text = e.title;
    _descCtrl.text = e.description ?? '';
    _isActive = e.isActive;
    _dsType = e.dataSourceType;

    final dsc = e.dataSourceConfig;
    _apiUrlCtrl.text = dsc['url'] as String? ?? '';
    _apiMethod = dsc['method'] as String? ?? 'GET';
    _apiPathCtrl.text = dsc['response_array_path'] as String? ?? '';
    final heads = dsc['headers'] as Map? ?? {};
    _apiHeaders = heads.entries.map((en) {
      final kc = TextEditingController(text: en.key.toString());
      final vc = TextEditingController(text: en.value.toString());
      return {'key': kc, 'value': vc};
    }).toList();
    _authType = dsc['auth_type'] as String? ?? 'none';
    _authValueCtrl.text = dsc['auth_value'] as String? ?? '';
    _internalTable = dsc['table'] as String?;
    _selectColsCtrl.text = dsc['select_columns'] as String? ?? '*';
    _filters = List<Map<String, dynamic>>.from(
        (dsc['filters'] as List? ?? []).map((f) => Map<String, dynamic>.from(f as Map)));
    _excelRecords = List<Map<String, dynamic>>.from(dsc['records'] as List? ?? []);
    if (_excelRecords.isNotEmpty) {
      _excelColumns = (_excelRecords.first).keys.take(3).toList();
    }

    _schedType = e.scheduleType;
    final sc = e.scheduleConfig;
    switch (_schedType) {
      case ReminderScheduleType.interval:
        final m = sc['every_minutes'] as int? ?? 60;
        if (m % 10080 == 0) { _intervalUnit = 'weeks'; _intervalValueCtrl.text = '${m ~/ 10080}'; }
        else if (m % 1440 == 0) { _intervalUnit = 'days'; _intervalValueCtrl.text = '${m ~/ 1440}'; }
        else if (m % 60 == 0) { _intervalUnit = 'hours'; _intervalValueCtrl.text = '${m ~/ 60}'; }
        else { _intervalUnit = 'minutes'; _intervalValueCtrl.text = '$m'; }
        break;
      case ReminderScheduleType.daily:
        _dailyTimes = (sc['times'] as List? ?? ['09:00']).map<TimeOfDay>((t) {
          final parts = (t as String).split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }).toList();
        break;
      case ReminderScheduleType.weekly:
        _weeklyDays = List<int>.from(sc['days_of_week'] as List? ?? [1]);
        final wt = sc['time'] as String? ?? '09:00';
        final parts = wt.split(':');
        _weeklyTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        break;
      case ReminderScheduleType.custom:
        _cronCtrl.text = sc['expression'] as String? ?? '';
        break;
    }

    _hasCondition = e.hasCondition;
    _condOperator = e.conditionOperator;
    _conditions = List.from(e.conditions);

    final rc = e.recipientConfig;
    _recipientType = ReminderRecipientType.fromString(rc['type'] as String? ?? 'creator');
    _mappedFieldCtrl.text = (rc['user_id_field'] ?? rc['email_field'] ?? '') as String;
    _alsoNotifyCreator = rc['also_notify_creator'] as bool? ?? false;
    _selectedUserIds = List<String>.from(rc['user_ids'] as List? ?? []);

    _msgTitleCtrl.text = e.msgTitleTemplate;
    _msgBodyCtrl.text = e.msgBodyTemplate;
    _chanApp = e.channels.contains('app');
    _chanEmail = e.channels.contains('email');

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _apiUrlCtrl.dispose();
    _apiPathCtrl.dispose();
    _authValueCtrl.dispose();
    _selectColsCtrl.dispose();
    _intervalValueCtrl.dispose();
    _cronCtrl.dispose();
    _mappedFieldCtrl.dispose();
    _msgTitleCtrl.dispose();
    _msgBodyCtrl.dispose();
    for (final h in _apiHeaders) {
      (h['key'] as TextEditingController).dispose();
      (h['value'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildDataSourceConfig() {
    switch (_dsType) {
      case ReminderDataSourceType.api:
        final headers = <String, String>{};
        for (final h in _apiHeaders) {
          final k = (h['key'] as TextEditingController).text.trim();
          final v = (h['value'] as TextEditingController).text.trim();
          if (k.isNotEmpty) headers[k] = v;
        }
        if (_authType == 'bearer') headers['Authorization'] = 'Bearer ${_authValueCtrl.text.trim()}';
        if (_authType == 'apikey') headers['X-API-Key'] = _authValueCtrl.text.trim();
        return {
          'url': _apiUrlCtrl.text.trim(),
          'method': _apiMethod,
          'response_array_path': _apiPathCtrl.text.trim(),
          'headers': headers,
          'auth_type': _authType,
          'auth_value': _authValueCtrl.text.trim(),
        };
      case ReminderDataSourceType.internal:
        return {
          'table': _internalTable ?? '',
          'select_columns': _selectColsCtrl.text.trim().isEmpty ? '*' : _selectColsCtrl.text.trim(),
          'filters': _filters,
        };
      case ReminderDataSourceType.excel:
        return {'records': _excelRecords};
    }
  }

  Map<String, dynamic> _buildScheduleConfig() {
    switch (_schedType) {
      case ReminderScheduleType.interval:
        final val = int.tryParse(_intervalValueCtrl.text.trim()) ?? 1;
        final minutes = switch (_intervalUnit) {
          'weeks' => val * 10080,
          'days' => val * 1440,
          'hours' => val * 60,
          _ => val,
        };
        return {'every_minutes': minutes};
      case ReminderScheduleType.daily:
        return {'times': _dailyTimes.map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').toList()};
      case ReminderScheduleType.weekly:
        return {
          'days_of_week': _weeklyDays,
          'time': '${_weeklyTime.hour.toString().padLeft(2, '0')}:${_weeklyTime.minute.toString().padLeft(2, '0')}',
        };
      case ReminderScheduleType.custom:
        return {'expression': _cronCtrl.text.trim(), 'every_minutes': 60};
    }
  }

  Map<String, dynamic> _buildRecipientConfig() {
    final cfg = <String, dynamic>{'type': _recipientType.value};
    switch (_recipientType) {
      case ReminderRecipientType.mappedUserId:
        cfg['user_id_field'] = _mappedFieldCtrl.text.trim();
        break;
      case ReminderRecipientType.mappedEmail:
        cfg['email_field'] = _mappedFieldCtrl.text.trim();
        break;
      case ReminderRecipientType.broadcastEmail:
        cfg['email_field'] = _mappedFieldCtrl.text.trim();
        break;
      case ReminderRecipientType.specificUsers:
        cfg['user_ids'] = _selectedUserIds;
        break;
      default:
        break;
    }
    if (_alsoNotifyCreator) cfg['also_notify_creator'] = true;
    return cfg;
  }

  Future<void> _previewFields() async {
    setState(() => _previewLoading = true);
    final fields = await ReminderService.previewFields(_dsType, _buildDataSourceConfig());
    if (mounted) setState(() { _previewedFields = fields; _previewLoading = false; });
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    try {
      final excel = xl.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) return;
      final headers = sheet.rows.first
          .map((c) => c?.value?.toString() ?? '')
          .where((h) => h.isNotEmpty)
          .toList();
      final records = <Map<String, dynamic>>[];
      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final record = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          record[headers[j]] = row[j]?.value?.toString() ?? '';
        }
        records.add(record);
      }
      setState(() {
        _excelRecords = records;
        _excelColumns = headers.take(3).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel parse error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String? _validateForm() {
    if (_titleCtrl.text.trim().isEmpty) return _isAr ? 'العنوان مطلوب' : 'Title is required';
    if (!_chanApp && !_chanEmail) return _isAr ? 'اختر قناة إشعار واحدة على الأقل' : 'Select at least one notification channel';
    if (_dsType == ReminderDataSourceType.api && _apiUrlCtrl.text.trim().isEmpty) {
      return _isAr ? 'رابط الـ API مطلوب' : 'API URL is required';
    }
    if (_dsType == ReminderDataSourceType.internal && (_internalTable == null || _internalTable!.isEmpty)) {
      return _isAr ? 'اختر جدولاً داخلياً' : 'Select an internal table';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validateForm();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final channels = <String>[if (_chanApp) 'app', if (_chanEmail) 'email'];
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'is_active': _isActive,
        'data_source_type': _dsType.value,
        'data_source_config': _buildDataSourceConfig(),
        'schedule_type': _schedType.value,
        'schedule_config': _buildScheduleConfig(),
        'has_condition': _hasCondition,
        'condition_operator': _condOperator,
        'conditions': _conditions.map((c) => c.toJson()).toList(),
        'channels': channels,
        'msg_title_template': _msgTitleCtrl.text,
        'msg_body_template': _msgBodyCtrl.text,
        'recipient_config': _buildRecipientConfig(),
      };

      if (_isEdit) {
        await ReminderService.update(widget.existing!.id, data);
      } else {
        final authId = await _getOwnerUserId();
        final reminder = SmartReminder(
          id: '',
          ownerUserId: authId ?? widget.currentUser.id,
          title: data['title'] as String,
          description: data['description'] as String?,
          isActive: data['is_active'] as bool,
          dataSourceType: _dsType,
          dataSourceConfig: data['data_source_config'] as Map<String, dynamic>,
          scheduleType: _schedType,
          scheduleConfig: data['schedule_config'] as Map<String, dynamic>,
          hasCondition: data['has_condition'] as bool,
          conditions: _conditions,
          conditionOperator: data['condition_operator'] as String,
          channels: List<String>.from(data['channels'] as List),
          msgTitleTemplate: data['msg_title_template'] as String,
          msgBodyTemplate: data['msg_body_template'] as String,
          recipientConfig: data['recipient_config'] as Map<String, dynamic>,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ReminderService.create(reminder);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _getOwnerUserId() async {
    try {
      final authId = (await ReminderService.getAll()).isEmpty
          ? null
          : null;
      return authId ?? widget.currentUser.id;
    } catch (_) {
      return widget.currentUser.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit
              ? (_isAr ? 'تعديل التذكير' : 'Edit Reminder')
              : (_isAr ? 'تذكير جديد' : 'New Reminder'),
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.secondary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _section(
                icon: Icons.info_outline_rounded,
                title: _isAr ? 'المعلومات الأساسية' : 'Basic Info',
                child: _buildBasicInfo(),
              ),
              _section(
                icon: Icons.storage_rounded,
                title: _isAr ? 'مصدر البيانات' : 'Data Source',
                child: _buildDataSource(),
              ),
              _section(
                icon: Icons.schedule_rounded,
                title: _isAr ? 'الجدول الزمني' : 'Schedule',
                child: _buildSchedule(),
              ),
              _section(
                icon: Icons.filter_list_rounded,
                title: _isAr ? 'الشروط' : 'Conditions',
                child: _buildConditions(),
              ),
              _section(
                icon: Icons.people_rounded,
                title: _isAr ? 'المستلمون' : 'Recipients',
                child: _buildRecipients(),
              ),
              _section(
                icon: Icons.message_rounded,
                title: _isAr ? 'قالب الرسالة' : 'Message Template',
                child: _buildMessageTemplate(),
              ),
              _section(
                icon: Icons.notifications_rounded,
                title: _isAr ? 'قنوات الإشعار' : 'Notification Channels',
                child: _buildChannels(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isAr ? 'حفظ' : 'Save',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.secondary)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────

  Widget _buildBasicInfo() {
    return Column(
      children: [
        TextFormField(
          controller: _titleCtrl,
          decoration: _inputDeco(_isAr ? 'العنوان *' : 'Title *'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descCtrl,
          decoration: _inputDeco(_isAr ? 'الوصف (اختياري)' : 'Description (optional)'),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          title: Text(_isAr ? 'نشط' : 'Active'),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildDataSource() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _segmentedRow(
          choices: ReminderDataSourceType.values,
          selected: _dsType,
          label: (t) => _isAr ? t.labelAr : t.label,
          icon: (t) => t.icon,
          onChanged: (t) => setState(() { _dsType = t; _previewedFields = []; }),
        ),
        const SizedBox(height: 16),
        if (_dsType == ReminderDataSourceType.api) _buildApiConfig(),
        if (_dsType == ReminderDataSourceType.internal) _buildInternalConfig(),
        if (_dsType == ReminderDataSourceType.excel) _buildExcelConfig(),
        const SizedBox(height: 12),
        _previewButton(),
        if (_previewedFields.isNotEmpty) ...[
          const SizedBox(height: 10),
          _fieldChips(_previewedFields),
        ],
      ],
    );
  }

  Widget _buildApiConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _apiUrlCtrl,
          decoration: _inputDeco('URL *'),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: _inputDeco(_isAr ? 'الطريقة' : 'Method'),
                child: DropdownButton<String>(
                  value: _apiMethod,
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: ['GET', 'POST'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _apiMethod = v!),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _apiPathCtrl,
                decoration: _inputDeco('Response array path').copyWith(
                  hintText: 'data.items',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: _inputDeco(_isAr ? 'نوع المصادقة' : 'Auth type'),
          child: DropdownButton<String>(
            value: _authType,
            underline: const SizedBox(),
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'none', child: Text(_isAr ? 'بدون' : 'None')),
              const DropdownMenuItem(value: 'bearer', child: Text('Bearer Token')),
              const DropdownMenuItem(value: 'apikey', child: Text('API Key')),
            ],
            onChanged: (v) => setState(() => _authType = v!),
          ),
        ),
        if (_authType != 'none') ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _authValueCtrl,
            decoration: _inputDeco(_authType == 'bearer' ? 'Bearer token' : 'API Key value'),
            obscureText: true,
          ),
        ],
        const SizedBox(height: 12),
        Text(_isAr ? 'الترويسات' : 'Headers',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary)),
        const SizedBox(height: 6),
        ..._apiHeaders.asMap().entries.map((e) {
          final i = e.key;
          final h = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: TextFormField(controller: h['key'] as TextEditingController, decoration: _inputDeco('Key'))),
                const SizedBox(width: 6),
                Expanded(child: TextFormField(controller: h['value'] as TextEditingController, decoration: _inputDeco('Value'))),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _apiHeaders.removeAt(i)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(_isAr ? 'إضافة ترويسة' : 'Add Header'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () => setState(() => _apiHeaders.add({
            'key': TextEditingController(),
            'value': TextEditingController(),
          })),
        ),
      ],
    );
  }

  Widget _buildInternalConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: _inputDeco(_isAr ? 'الجدول' : 'Table'),
          child: DropdownButton<String>(
            value: _availableTables.contains(_internalTable) ? _internalTable : null,
            underline: const SizedBox(),
            isExpanded: true,
            hint: Text(_isAr ? 'اختر جدولاً' : 'Select table'),
            items: _availableTables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _internalTable = v),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _selectColsCtrl,
          decoration: _inputDeco(_isAr ? 'الأعمدة (افتراضي: *)' : 'Columns (default: *)'),
        ),
        const SizedBox(height: 10),
        Text(_isAr ? 'الفلاتر' : 'Filters',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.secondary)),
        const SizedBox(height: 6),
        ..._filters.asMap().entries.map((e) {
          final i = e.key;
          final f = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: f['column'] as String? ?? '',
                    decoration: _inputDeco('Column'),
                    onChanged: (v) => _filters[i]['column'] = v,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 70,
                  child: InputDecorator(
                    decoration: _inputDeco('Op').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                    child: DropdownButton<String>(
                      value: f['operator'] as String? ?? 'eq',
                      underline: const SizedBox(),
                      isExpanded: true,
                      items: ['eq', 'neq', 'gte', 'lte', 'like', 'in']
                          .map((op) => DropdownMenuItem(value: op, child: Text(op, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() => _filters[i]['operator'] = v),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextFormField(
                    initialValue: f['value']?.toString() ?? '',
                    decoration: _inputDeco('Value'),
                    onChanged: (v) => _filters[i]['value'] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _filters.removeAt(i)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(_isAr ? 'إضافة فلتر' : 'Add Filter'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () => setState(() => _filters.add({'column': '', 'operator': 'eq', 'value': ''})),
        ),
      ],
    );
  }

  Widget _buildExcelConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(_isAr ? 'استيراد Excel' : 'Import Excel'),
          onPressed: _importExcel,
        ),
        if (_excelRecords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${_excelRecords.length} ${_isAr ? "سجل مستورد" : "records imported"}',
            style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _excelColumns.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            )).toList(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            label: Text(_isAr ? 'مسح البيانات' : 'Clear data', style: const TextStyle(color: Colors.red)),
            onPressed: () => setState(() { _excelRecords = []; _excelColumns = []; }),
          ),
        ],
      ],
    );
  }

  Widget _previewButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: _previewLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : const Icon(Icons.preview_rounded, size: 18),
      label: Text(_isAr ? 'معاينة الحقول' : 'Preview Fields'),
      onPressed: _previewLoading ? null : _previewFields,
    );
  }

  Widget _fieldChips(List<String> fields) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields.map((f) => ActionChip(
        label: Text('{{$f}}', style: const TextStyle(fontSize: 11)),
        backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
        labelStyle: const TextStyle(color: AppColors.secondary),
        onPressed: () {
          final cursor = _msgBodyCtrl.selection;
          final text = _msgBodyCtrl.text;
          final insert = '{{$f}}';
          if (cursor.isValid && !cursor.isCollapsed) {
            _msgBodyCtrl.text = text.replaceRange(cursor.start, cursor.end, insert);
          } else if (cursor.isValid) {
            final pos = cursor.baseOffset;
            _msgBodyCtrl.text = text.substring(0, pos) + insert + text.substring(pos);
          } else {
            _msgBodyCtrl.text = text + insert;
          }
        },
      )).toList(),
    );
  }

  Widget _buildSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _segmentedRow(
          choices: ReminderScheduleType.values,
          selected: _schedType,
          label: (t) => _isAr ? t.labelAr : t.label,
          onChanged: (t) => setState(() => _schedType = t),
        ),
        const SizedBox(height: 16),
        if (_schedType == ReminderScheduleType.interval) _buildIntervalConfig(),
        if (_schedType == ReminderScheduleType.daily) _buildDailyConfig(),
        if (_schedType == ReminderScheduleType.weekly) _buildWeeklyConfig(),
        if (_schedType == ReminderScheduleType.custom) _buildCustomConfig(),
      ],
    );
  }

  Widget _buildIntervalConfig() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _intervalValueCtrl,
            decoration: _inputDeco(_isAr ? 'القيمة' : 'Value'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InputDecorator(
            decoration: _inputDeco(_isAr ? 'الوحدة' : 'Unit'),
            child: DropdownButton<String>(
              value: _intervalUnit,
              underline: const SizedBox(),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'minutes', child: Text(_isAr ? 'دقائق' : 'Minutes')),
                DropdownMenuItem(value: 'hours', child: Text(_isAr ? 'ساعات' : 'Hours')),
                DropdownMenuItem(value: 'days', child: Text(_isAr ? 'أيام' : 'Days')),
                DropdownMenuItem(value: 'weeks', child: Text(_isAr ? 'أسابيع' : 'Weeks')),
              ],
              onChanged: (v) => setState(() => _intervalUnit = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _dailyTimes.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final label = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            return Chip(
              label: Text(label),
              deleteIcon: const Icon(Icons.close, size: 16),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              onDeleted: _dailyTimes.length > 1 ? () => setState(() => _dailyTimes.removeAt(i)) : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(_isAr ? 'إضافة وقت' : 'Add time'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 9, minute: 0),
            );
            if (picked != null) setState(() => _dailyTimes.add(picked));
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyConfig() {
    const dayLabelsEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const dayLabelsAr = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
    final labels = _isAr ? dayLabelsAr : dayLabelsEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final selected = _weeklyDays.contains(i);
            return FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) { _weeklyDays.add(i); } else { _weeklyDays.remove(i); }
              }),
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
            );
          }),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_isAr ? 'الوقت' : 'Time'),
          trailing: TextButton(
            child: Text(
              '${_weeklyTime.hour.toString().padLeft(2, '0')}:${_weeklyTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: _weeklyTime);
              if (picked != null) setState(() => _weeklyTime = picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _cronCtrl,
          decoration: _inputDeco('Cron expression'),
        ),
        const SizedBox(height: 6),
        const Text(
          '0 9 * * 1-5  =  Mon–Fri at 9am',
          style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildConditions() {
    return Column(
      children: [
        SwitchListTile(
          value: _hasCondition,
          onChanged: (v) => setState(() => _hasCondition = v),
          title: Text(_isAr ? 'تفعيل الشروط' : 'Only send when conditions are met'),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
        if (_hasCondition) ...[
          Row(
            children: [
              ChoiceChip(
                label: Text(_isAr ? 'AND (كل الشروط)' : 'AND (all conditions)'),
                selected: _condOperator == 'and',
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                onSelected: (v) { if (v) setState(() => _condOperator = 'and'); },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(_isAr ? 'OR (أي شرط)' : 'OR (any condition)'),
                selected: _condOperator == 'or',
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                onSelected: (v) { if (v) setState(() => _condOperator = 'or'); },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._conditions.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return _buildConditionRow(i, c);
          }),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(_isAr ? 'إضافة شرط' : 'Add Condition'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: () => setState(() => _conditions.add(ReminderCondition(field: ''))),
          ),
        ],
      ],
    );
  }

  Widget _buildConditionRow(int i, ReminderCondition c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _previewedFields.isNotEmpty
                ? InputDecorator(
                    decoration: _inputDeco(_isAr ? 'الحقل' : 'Field'),
                    child: DropdownButton<String>(
                      value: _previewedFields.contains(c.field) ? c.field : null,
                      underline: const SizedBox(),
                      isExpanded: true,
                      hint: const Text('Field', style: TextStyle(fontSize: 12)),
                      items: _previewedFields.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => c.field = v ?? ''),
                    ),
                  )
                : TextFormField(
                    initialValue: c.field,
                    decoration: _inputDeco(_isAr ? 'الحقل' : 'Field'),
                    onChanged: (v) => c.field = v,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: InputDecorator(
              decoration: _inputDeco(_isAr ? 'القاعدة' : 'Rule').copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              child: DropdownButton<ReminderConditionRule>(
                value: c.rule,
                underline: const SizedBox(),
                isExpanded: true,
                items: ReminderConditionRule.values.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_isAr ? r.labelAr : r.label, style: const TextStyle(fontSize: 11)),
                )).toList(),
                onChanged: (v) => setState(() => c.rule = v!),
              ),
            ),
          ),
          if (c.rule.needsValue) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: c.value?.toString() ?? '',
                decoration: _inputDeco(_isAr ? 'القيمة' : 'Value'),
                onChanged: (v) => c.value = v,
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            onPressed: () => setState(() => _conditions.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: _inputDeco(_isAr ? 'نوع المستلم' : 'Recipient type'),
          child: DropdownButton<ReminderRecipientType>(
            value: _recipientType,
            underline: const SizedBox(),
            isExpanded: true,
            items: ReminderRecipientType.values.map((t) => DropdownMenuItem(
              value: t,
              child: Text(_isAr ? t.labelAr : t.label, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _recipientType = v!),
          ),
        ),
        const SizedBox(height: 12),
        if (_recipientType == ReminderRecipientType.mappedUserId)
          TextFormField(
            controller: _mappedFieldCtrl,
            decoration: _inputDeco(_isAr ? 'اسم الحقل (يحوي رقم المستخدم)' : 'Field name (contains user ID)'),
          ),
        if (_recipientType == ReminderRecipientType.mappedEmail)
          TextFormField(
            controller: _mappedFieldCtrl,
            decoration: _inputDeco(_isAr ? 'اسم الحقل (يحوي البريد)' : 'Field name (contains email)'),
          ),
        if (_recipientType == ReminderRecipientType.broadcastEmail)
          TextFormField(
            controller: _mappedFieldCtrl,
            decoration: _inputDeco(_isAr ? 'اسم الحقل (يحوي البريد)' : 'Field name (contains email)'),
          ),
        if (_recipientType == ReminderRecipientType.specificUsers) _buildSpecificUsers(),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _alsoNotifyCreator,
          onChanged: (v) => setState(() => _alsoNotifyCreator = v),
          title: Text(_isAr ? 'إشعاري أنا أيضاً (المنشئ)' : 'Also notify me (creator)'),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSpecificUsers() {
    final selected = _allUsers.where((u) => _selectedUserIds.contains(u['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: selected.map((u) => Chip(
            label: Text(u['full_name'] as String? ?? u['email'] as String? ?? ''),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() => _selectedUserIds.remove(u['id'])),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          )).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(_isAr ? 'إضافة مستخدم' : 'Add User'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () => _showUserSearchDialog(),
        ),
      ],
    );
  }

  void _showUserSearchDialog() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(_isAr ? 'اختر مستخدماً' : 'Select User'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: _isAr ? 'بحث...' : 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setDialog(() {}),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: _allUsers.where((u) {
                      final q = searchCtrl.text.toLowerCase();
                      return q.isEmpty ||
                          (u['full_name'] as String? ?? '').toLowerCase().contains(q) ||
                          (u['email'] as String? ?? '').toLowerCase().contains(q);
                    }).map((u) {
                      final uid = u['id'] as String;
                      final sel = _selectedUserIds.contains(uid);
                      return ListTile(
                        title: Text(u['full_name'] as String? ?? ''),
                        subtitle: Text(u['email'] as String? ?? ''),
                        trailing: sel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                        onTap: () {
                          setState(() {
                            if (sel) { _selectedUserIds.remove(uid); } else { _selectedUserIds.add(uid); }
                          });
                          setDialog(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_isAr ? 'تم' : 'Done')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTemplate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _msgTitleCtrl,
          decoration: _inputDeco(_isAr ? 'عنوان الرسالة' : 'Message title').copyWith(
            hintText: 'Reminder: {{system.now}}',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _msgBodyCtrl,
          decoration: _inputDeco(_isAr ? 'نص الرسالة' : 'Message body').copyWith(
            hintText: 'Hello {{name}}, your license expires on {{expiry_date}} ({{days_until.expiry_date}} days).',
          ),
          maxLines: 5,
        ),
        if (_previewedFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_isAr ? 'المتغيرات المتاحة (انقر للإدراج):' : 'Available variables (tap to insert):',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          _fieldChips(_previewedFields),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _specialChip('{{system.now}}'),
              ..._previewedFields.take(3).expand((f) => [
                _specialChip('{{days_until.$f}}'),
                _specialChip('{{days_since.$f}}'),
              ]),
            ],
          ),
        ],
      ],
    );
  }

  Widget _specialChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      labelStyle: const TextStyle(color: AppColors.primary),
      onPressed: () {
        _msgBodyCtrl.text += label;
      },
    );
  }

  Widget _buildChannels() {
    return Column(
      children: [
        SwitchListTile(
          value: _chanApp,
          onChanged: (v) => setState(() => _chanApp = v),
          secondary: const Icon(Icons.notifications_rounded, color: AppColors.secondary),
          title: Text(_isAr ? 'إشعار داخل التطبيق' : 'In-App Push Notification'),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: _chanEmail,
          onChanged: (v) => setState(() => _chanEmail = v),
          secondary: const Icon(Icons.email_rounded, color: AppColors.secondary),
          title: Text(_isAr ? 'البريد الإلكتروني' : 'Email'),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );

  Widget _segmentedRow<T>({
    required List<T> choices,
    required T selected,
    required String Function(T) label,
    IconData Function(T)? icon,
    required ValueChanged<T> onChanged,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: choices.map((c) {
          final sel = c == selected;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.transparent,
                border: Border.all(color: sel ? AppColors.primary : Colors.grey[300]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon(c), size: 16, color: sel ? Colors.white : Colors.grey),
                    const SizedBox(width: 4),
                  ],
                  Text(label(c),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? Colors.white : Colors.grey[700],
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
