import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

String _empStatusLabel(String s) {
  switch (s) {
    case 'active':
      return 'Faol';
    case 'on_leave':
      return 'Dam olishda';
    case 'terminated':
      return 'Ishdan bo\'shatilgan';
  }
  return s;
}

String _attStatusLabel(String s) {
  switch (s) {
    case 'present':
      return 'Keldi';
    case 'absent':
      return 'Kelmadi';
    case 'late':
      return 'Kech qoldi';
    case 'sick_leave':
      return 'Kasal';
    case 'vacation':
      return 'Ta\'til';
    case 'unpaid_leave':
      return 'Ishsiz ruxsat';
    case 'business_trip':
      return 'Xizmat safari';
  }
  return s;
}

String _adjTypeLabel(String s) {
  switch (s) {
    case 'bonus':
      return 'Premiya';
    case 'penalty':
      return 'Jarima';
    case 'advance':
      return 'Avans';
    case 'other':
      return 'Boshqa';
  }
  return s;
}

String _adjStatusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'Kutilmoqda';
    case 'approved':
      return 'Tasdiqlangan';
    case 'rejected':
      return 'Rad etilgan';
  }
  return s;
}

String _workTypeLabel(String? s) {
  switch (s) {
    case 'mixing':
      return 'Aralashtirish';
    case 'packaging':
      return 'Qadoqlash';
    case 'other':
      return 'Boshqa';
  }
  return s ?? '';
}

Color _statusColor(String status) {
  if (status == 'approved' || status == 'active' || status == 'present') {
    return AppColors.statusOk;
  }
  if (status == 'pending' || status == 'late' || status == 'on_leave') {
    return AppColors.statusWarning;
  }
  return AppColors.statusCritical;
}

class _HrRefreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _HrRefreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Yangilash'),
        ),
      ),
    );
  }
}

class HrScreen extends StatelessWidget {
  const HrScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    final isReadOnly = !FactoryHubApi.role.canManageHr;
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const Material(
            color: AppColors.surface,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Xodimlar'),
                Tab(text: 'Davomat'),
                Tab(text: 'Stavkalar'),
                Tab(text: 'Ishlar'),
                Tab(text: 'Moliyaviy'),
                Tab(text: 'Hisobot'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _EmployeesTab(readOnly: isReadOnly, refreshNotifier: refreshNotifier),
                _AttendanceTab(readOnly: isReadOnly, refreshNotifier: refreshNotifier),
                _PieceRatesTab(readOnly: isReadOnly, refreshNotifier: refreshNotifier),
                _WorkRecordsTab(readOnly: isReadOnly, refreshNotifier: refreshNotifier),
                _FinancialTab(readOnly: isReadOnly, refreshNotifier: refreshNotifier),
                _MonthlyReportTab(refreshNotifier: refreshNotifier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── XODIMLAR ────────────────────────────────────────────────

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab({required this.readOnly, this.refreshNotifier});
  final bool readOnly;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  List<dynamic> _employees = [];
  bool _loading = true;
  String _status = 'active';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getEmployees(
      status: _status == 'all' ? null : _status,
      search: _search.isEmpty ? null : _search,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _employees = result['employees'] ?? [];
    });
  }

  Future<void> _openEdit([dynamic emp]) async {
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmployeeFormSheet(employee: emp, readOnly: widget.readOnly),
    );
    if (saved != null) _load();
  }

  Future<void> _fire(dynamic emp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ishdan bo\'shatish'),
        content: Text('${emp['fullName']} ishdan bo\'shatilsinmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bo\'shatish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await FactoryHubApi.fireEmployee(emp['id']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error'] ?? 'Xodim ishdan bo\'shatildi')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HrRefreshButton(onPressed: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Qidiruv',
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  _search = v;
                  _load();
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Holat',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Hammasi')),
                        DropdownMenuItem(value: 'active', child: Text('Faol')),
                        DropdownMenuItem(value: 'on_leave', child: Text('Dam olishda')),
                        DropdownMenuItem(value: 'terminated', child: Text('Bo\'shatilgan')),
                      ],
                      onChanged: (v) {
                        _status = v ?? 'active';
                        _load();
                      },
                    ),
                  ),
                  if (!widget.readOnly)
                    FilledButton.icon(
                      onPressed: () => _openEdit(null),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Yangi xodim'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? const Center(child: Text('Xodimlar topilmadi'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _employees.length,
                        itemBuilder: (_, i) {
                          final e = _employees[i];
                          final isTerminated = e['status'] == 'terminated';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryBg,
                                child: Text(
                                  (e['fullName']?.toString() ?? '?').isNotEmpty
                                      ? (e['fullName'].toString().substring(0, 1)).toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(e['fullName'] ?? ''),
                              subtitle: Text(
                                [
                                  e['position'],
                                  e['department'],
                                  e['phone'],
                                  _payLabel(e['payType']?.toString()),
                                  if (e['baseSalary'] != null) '${_fmtNum(e['baseSalary'])} so\'m',
                                ].where((x) => x != null && x.toString().isNotEmpty).join(' • '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(_empStatusLabel(e['status'] ?? 'active')),
                                    labelStyle: TextStyle(fontSize: 11, color: _statusColor(e['status'] ?? 'active')),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.background,
                                  ),
                                  if (!widget.readOnly) PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _openEdit(e);
                                      if (v == 'fire' && !isTerminated) _fire(e);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                                      if (!isTerminated)
                                        const PopupMenuItem(value: 'fire', child: Text('Ishdan bo\'shatish')),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => _openEdit(e),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

String _payLabel(String? payType) => switch (payType) {
      'piece_rate' => 'Ishbay',
      'hybrid' => 'Aralash',
      'salary' => 'Oylik',
      _ => '',
    };

bool _hasOt(dynamic r) {
  final ot = r['overtimeHours'] ?? r['totalOvertimeHours'];
  if (ot == null) return false;
  final n = num.tryParse(ot.toString());
  return n != null && n > 0;
}

String _fmtNum(dynamic v) {
  if (v == null) return '-';
  final n = num.tryParse(v.toString());
  if (n == null) return v.toString();
  final f = n % 1 == 0 ? n.toInt().toString() : n.toString();
  final b = StringBuffer();
  var count = 0;
  for (var i = f.length - 1; i >= 0; i--) {
    b.write(f[i]);
    count++;
    if (count % 3 == 0 && i != 0) b.write(' ');
  }
  return String.fromCharCodes(b.toString().codeUnits.reversed);
}

class _EmployeeFormSheet extends StatefulWidget {
  const _EmployeeFormSheet({this.employee, required this.readOnly});
  final dynamic employee;
  final bool readOnly;

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  final _nameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _status = 'active';
  DateTime? _hireDate;
  String? _error;
  late String _payType = 'salary';
  int? _userId;

  bool get _isNew => widget.employee == null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _nameCtrl.text = e['fullName']?.toString() ?? '';
      _positionCtrl.text = e['position']?.toString() ?? '';
      _deptCtrl.text = e['department']?.toString() ?? '';
      _phoneCtrl.text = e['phone']?.toString() ?? '';
      if (e['baseSalary'] != null) _salaryCtrl.text = e['baseSalary'].toString();
      _noteCtrl.text = e['note']?.toString() ?? '';
      _status = e['status'] ?? 'active';
      _payType = e['payType']?.toString() ?? 'salary';
      _userId = e['userId'] as int?;
      final hd = e['hireDate'];
      if (hd != null) _hireDate = DateTime.tryParse(hd.toString());
    } else {
      _hireDate = DateTime.now();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _hireDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ism-sharif majburiy');
      return;
    }
    final data = <String, dynamic>{
      'fullName': name,
      'position': _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim(),
      'department': _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'status': _status,
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      'hireDate': _hireDate == null ? null : DateFormat('yyyy-MM-dd').format(_hireDate!),
      'payType': _payType,
    };
    final salary = double.tryParse(_salaryCtrl.text.trim().replaceAll(' ', ''));
    if (salary != null) data['baseSalary'] = salary;
    if (_userId != null) data['userId'] = _userId;

    final result = _isNew
        ? await FactoryHubApi.createEmployee(data)
        : await FactoryHubApi.updateEmployee(widget.employee['id'], data);
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, <String, dynamic>{'ok': true});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew ? 'YANGI XODIM' : 'XODIMNI TAHRIRLASH',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Ism-sharif *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _positionCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Lavozim', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deptCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Bo\'lim', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              enabled: !widget.readOnly,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _payType,
              decoration: const InputDecoration(labelText: 'Haq turi', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'salary', child: Text('Oylik maosh')),
                DropdownMenuItem(value: 'piece_rate', child: Text('Ishbay')),
                DropdownMenuItem(value: 'hybrid', child: Text('Aralash (oylik + ishbay)')),
              ],
              onChanged: widget.readOnly ? null : (v) => setState(() => _payType = v ?? 'salary'),
            ),
            const SizedBox(height: 12),
            if (_payType != 'piece_rate')
              TextField(
                controller: _salaryCtrl,
                enabled: !widget.readOnly,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _payType == 'hybrid' ? 'Oylik qismi (so\'m)' : 'Oylik maosh (so\'m)',
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Ishga qabul sanasi', border: OutlineInputBorder()),
              child: InkWell(
                onTap: widget.readOnly ? null : _pickDate,
                child: Text(DateFormat('dd.MM.yyyy').format(_hireDate ?? DateTime(now.year, now.month, now.day))),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Holat', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Faol')),
                DropdownMenuItem(value: 'on_leave', child: Text('Dam olishda')),
                DropdownMenuItem(value: 'terminated', child: Text('Ishdan bo\'shatilgan')),
              ],
              onChanged: widget.readOnly ? null : (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !widget.readOnly,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            if (!widget.readOnly)
              ElevatedButton(onPressed: _submit, child: Text(_isNew ? 'Qo\'shish' : 'Saqlash')),
          ],
        ),
      ),
    );
  }
}

// ─── DAVOMAT ─────────────────────────────────────────────────

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.readOnly, this.refreshNotifier});
  final bool readOnly;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _date = DateTime.now();
  List<dynamic> _records = [];
  bool _loading = true;

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final r in _records) {
      final s = (r['status'] ?? 'present').toString();
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getAttendance(from: _dateStr, to: _dateStr);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _records = result['attendance'] ?? [];
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _openBulk() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BulkAttendanceSheet(workDate: _dateStr, readOnly: widget.readOnly),
    );
    _load();
  }

  Future<void> _editRecord(dynamic rec) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AttendanceFormSheet(record: rec, readOnly: widget.readOnly),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HrRefreshButton(onPressed: _load),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Sana',
                      isDense: true,
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('EEEE, dd.MM.yyyy').format(_date)),
                  ),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openBulk,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Kuzatuv'),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Yangilash'),
              ),
            ],
          ),
        ),
        if (!_loading && _records.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _statChip('Jami', _records.length, AppColors.textSecondary),
                _statChip('Keldi', _statusCounts['present'] ?? 0, AppColors.statusOk),
                _statChip('Kelmadi', _statusCounts['absent'] ?? 0, AppColors.statusCritical),
                if ((_statusCounts['late'] ?? 0) > 0)
                  _statChip('Kech qoldi', _statusCounts['late'] ?? 0, AppColors.statusWarning),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Bu kunga davomat kiritilmagan')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _records.length,
                        itemBuilder: (_, i) {
                          final r = _records[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: ListTile(
                              dense: true,
                              title: Text(r['employeeName'] ?? ''),
                              subtitle: Text(
                                'Kirish: ${r['checkIn'] ?? '-'} • Chiqish: ${r['checkOut'] ?? '-'} • '
                                'Soat: ${r['hoursWorked'] ?? '-'}'
                                '${_hasOt(r) ? ' • Qo\'shimcha: ${_fmtNum(r['overtimeHours'])}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(_attStatusLabel(r['status'] ?? 'present')),
                                    labelStyle: TextStyle(fontSize: 11, color: _statusColor(r['status'] ?? 'present')),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.background,
                                  ),
                                  if (!widget.readOnly) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _editRecord(r),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _BulkAttendanceSheet extends StatefulWidget {
  const _BulkAttendanceSheet({required this.workDate, required this.readOnly});
  final String workDate;
  final bool readOnly;

  @override
  State<_BulkAttendanceSheet> createState() => _BulkAttendanceSheetState();
}

class _BulkAttendanceSheetState extends State<_BulkAttendanceSheet> {
  List<dynamic> _employees = [];
  bool _loading = true;
  final Map<int, String> _statuses = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FactoryHubApi.getEmployees(status: 'active');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _employees = result['employees'] ?? [];
      for (final e in _employees) {
        _statuses.putIfAbsent(e['id'], () => 'present');
      }
    });
  }

  Future<void> _submit() async {
    final records = _employees
        .where((e) => _statuses[e['id']] != null)
        .map((e) {
      final st = _statuses[e['id']]!;
      final present = st == 'present' || st == 'late';
      return <String, dynamic>{
        'employeeId': e['id'],
        'status': st,
        if (present) 'checkIn': '08:00',
        if (present) 'checkOut': '18:00',
      };
    }).toList();
    if (records.isEmpty) return;
    final result = await FactoryHubApi.addAttendanceBulk({
      'workDate': widget.workDate,
      'records': records,
    });
    if (!mounted) return;
    final errors = (result['errors'] as List<dynamic>?) ?? [];
    if (errors.isNotEmpty) {
      setState(() => _error = '${errors.length} ta yozuv allaqachon bor (tahrirlash orqali yangilang)');
    } else {
      Navigator.pop(context, <String, dynamic>{'ok': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DAVOMAT KIRITISH — ${DateFormat('dd.MM.yyyy').format(DateTime.parse(widget.workDate))}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Standart holat: hammasi "Keldi". Faqat kelmaganlarni bosib belgilang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (!_loading && _employees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('Jami: ${_employees.length}   Kelmadi: $_absentCount',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      for (final e in _employees) {
                        _statuses[e['id']] = 'present';
                      }
                    }),
                    child: const Text('Barchasi keldi'),
                  ),
                ],
              ),
            ),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('Faol xodimlar yo\'q'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _employees.length,
                        itemBuilder: (_, i) {
                          final e = _employees[i];
                          final id = e['id'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(e['fullName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  _presentToggle(id),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.statusWarning)),
          ],
          const SizedBox(height: 12),
          if (!widget.readOnly)
            ElevatedButton(onPressed: _loading ? null : _submit, child: const Text('Saqlash')),
        ],
      ),
    );
  }

  int get _absentCount => _statuses.values.where((s) => s == 'absent').length;

  Widget _presentToggle(int id) {
    final isAbsent = (_statuses[id] ?? 'present') == 'absent';
    return InkWell(
      onTap: () => setState(() => _statuses[id] = isAbsent ? 'present' : 'absent'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isAbsent ? AppColors.statusCritical : AppColors.statusOk).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isAbsent ? AppColors.statusCritical : AppColors.statusOk),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAbsent ? Icons.close : Icons.check, size: 16,
                color: isAbsent ? AppColors.statusCritical : AppColors.statusOk),
            const SizedBox(width: 4),
            Text(isAbsent ? 'Kelmadi' : 'Keldi',
                style: TextStyle(
                    color: isAbsent ? AppColors.statusCritical : AppColors.statusOk,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceFormSheet extends StatefulWidget {
  const _AttendanceFormSheet({required this.record, required this.readOnly});
  final dynamic record;
  final bool readOnly;

  @override
  State<_AttendanceFormSheet> createState() => _AttendanceFormSheetState();
}

class _AttendanceFormSheetState extends State<_AttendanceFormSheet> {
  late String _status;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  final _noteCtrl = TextEditingController();
  final _otCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _status = r['status'] ?? 'present';
    _inTime = _parseTime(r['checkIn']) ?? const TimeOfDay(hour: 8, minute: 0);
    _outTime = _parseTime(r['checkOut']) ?? const TimeOfDay(hour: 18, minute: 0);
    _noteCtrl.text = r['note']?.toString() ?? '';
    final ot = r['overtimeHours'];
    if (ot != null && ot.toString() != '0' && ot.toString() != '0.0') {
      _otCtrl.text = ot.toString();
    }
  }

  TimeOfDay? _parseTime(dynamic v) {
    if (v == null) return null;
    final parts = v.toString().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Asosiy ish vaqti: obed (tushlik) hisobga olinib, 8 soatgacha.
  double? get _previewHours {
    if (_inTime == null || _outTime == null) return null;
    var mins = (_outTime!.hour * 60 + _outTime!.minute) -
        (_inTime!.hour * 60 + _inTime!.minute);
    if (mins < 0) mins += 1440;
    final d = mins / 60.0;
    final capped = d > 8 ? 8.0 : d;
    return double.parse(capped.toStringAsFixed(2));
  }

  Future<void> _pickIn() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _inTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _inTime = picked);
  }

  Future<void> _pickOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _outTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) setState(() => _outTime = picked);
  }

  Future<void> _submit() async {
    final otText = _otCtrl.text.trim().replaceAll(' ', '');
    var ot = 0.0;
    if (otText.isNotEmpty) {
      final parsed = double.tryParse(otText);
      if (parsed == null || parsed < 0) {
        setState(() => _error = 'Qo\'shimcha ish soati raqam bo\'lishi kerak (masalan: 2.5)');
        return;
      }
      ot = parsed;
    }
    if (_inTime == null || _outTime == null) {
      setState(() => _error = 'Kirish va chiqish vaqtini tanlang');
      return;
    }
    final data = <String, dynamic>{
      'status': _status,
      'checkIn': _fmt(_inTime!),
      'checkOut': _fmt(_outTime!),
      'overtimeHours': ot,
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    };
    final result = await FactoryHubApi.updateAttendance(widget.record['id'], data);
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _timeField(String label, TimeOfDay? t, VoidCallback onTap) {
    return InkWell(
      onTap: widget.readOnly ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(t == null ? '' : _fmt(t),
            style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewHours;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DAVOMATNI TAHRIRLASH',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Holat', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'present', child: Text('Keldi')),
                DropdownMenuItem(value: 'absent', child: Text('Kelmadi')),
                DropdownMenuItem(value: 'late', child: Text('Kech qoldi')),
                DropdownMenuItem(value: 'sick_leave', child: Text('Kasal')),
                DropdownMenuItem(value: 'vacation', child: Text('Ta\'til')),
                DropdownMenuItem(value: 'unpaid_leave', child: Text('Ishsiz ruxsat')),
                DropdownMenuItem(value: 'business_trip', child: Text('Xizmat safari')),
              ],
              onChanged: widget.readOnly ? null : (v) => setState(() => _status = v ?? 'present'),
            ),
            const SizedBox(height: 12),
            _timeField('Ishga kelish vaqti', _inTime, _pickIn),
            const SizedBox(height: 12),
            _timeField('Ishdan ketish vaqti', _outTime, _pickOut),
            if (preview != null) ...[
              const SizedBox(height: 8),
              Text(
                'Asosiy ish vaqti: ${_fmtNum(preview)} soat'
                '${preview == 8 ? ' (obed bilan cheklangan)' : ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _otCtrl,
              enabled: !widget.readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Qo\'shimcha ish soati (soatda, masalan: 2.5)',
                border: OutlineInputBorder(),
                hintText: '0',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Izoh', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            if (!widget.readOnly)
              ElevatedButton(onPressed: _submit, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}

// ─── MOLIYAVIY ───────────────────────────────────────────────

class _FinancialTab extends StatefulWidget {
  const _FinancialTab({required this.readOnly, this.refreshNotifier});
  final bool readOnly;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<_FinancialTab> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getSalaryAdjustments();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = result['adjustments'] ?? [];
    });
  }

  Future<void> _openAdd() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustmentFormSheet(readOnly: widget.readOnly),
    );
    _load();
  }

  Future<void> _approve(dynamic item, bool approve) async {
    final result = approve
        ? await FactoryHubApi.approveSalaryAdjustment(item['id'])
        : await FactoryHubApi.rejectSalaryAdjustment(item['id']);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Bajarildi')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (!widget.readOnly) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Premiya / Jarima / Avans'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yangilash'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('Moliyaviy tuzatishlar yo\'q'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final s = _items[i];
                          final sign = s['adjustmentType'] == 'penalty' ? '-' : '+';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: ListTile(
                              dense: true,
                              title: Text(s['employeeName'] ?? ''),
                              subtitle: Text(
                                '${_adjTypeLabel(s['adjustmentType'])} • ${s['adjustmentDate']} • ${s['reason']}',
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryBg,
                                child: Text(sign, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$sign ${_fmtNum(s['amount'])}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: sign == '-' ? Colors.red : AppColors.primary),
                                  ),
                                  Text(
                                    _adjStatusLabel(s['status'] ?? 'pending'),
                                    style: TextStyle(fontSize: 11, color: _statusColor(s['status'] ?? 'pending')),
                                  ),
                                ],
                              ),
                              onTap: (s['status'] == 'pending' && !widget.readOnly)
                                  ? () => _approve(s, true)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _AdjustmentFormSheet extends StatefulWidget {
  const _AdjustmentFormSheet({required this.readOnly});
  final bool readOnly;

  @override
  State<_AdjustmentFormSheet> createState() => _AdjustmentFormSheetState();
}

class _AdjustmentFormSheetState extends State<_AdjustmentFormSheet> {
  List<dynamic> _employees = [];
  bool _loading = true;
  int? _employeeId;
  String _type = 'bonus';
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FactoryHubApi.getEmployees(status: 'active');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _employees = result['employees'] ?? [];
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_employeeId == null) {
      setState(() => _error = 'Xodimni tanlang');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(' ', ''));
    final reason = _reasonCtrl.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Summa (>0) noto\'g\'ri');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Sabab majburiy');
      return;
    }
    final result = await FactoryHubApi.addSalaryAdjustment({
      'employeeId': _employeeId,
      'adjustmentType': _type,
      'amount': amount,
      'reason': reason,
      'adjustmentDate': DateFormat('yyyy-MM-dd').format(_date),
      'status': 'pending',
    });
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MOLIYAVIY TUZATISH',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _employeeId,
              decoration: const InputDecoration(labelText: 'Xodim *', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tanlang...')),
                for (final e in _employees)
                  DropdownMenuItem(value: e['id'], child: Text(e['fullName'] ?? '')),
              ],
              onChanged: widget.readOnly ? null : (v) => setState(() => _employeeId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Turi', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'bonus', child: Text('Premiya')),
                DropdownMenuItem(value: 'penalty', child: Text('Jarima')),
                DropdownMenuItem(value: 'advance', child: Text('Avans')),
                DropdownMenuItem(value: 'other', child: Text('Boshqa')),
              ],
              onChanged: widget.readOnly ? null : (v) => setState(() => _type = v ?? 'bonus'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Summa (so\'m) *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Sabab *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Sana', border: OutlineInputBorder()),
              child: InkWell(
                onTap: widget.readOnly ? null : _pickDate,
                child: Text(DateFormat('dd.MM.yyyy').format(_date)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            if (!widget.readOnly)
              ElevatedButton(onPressed: _loading ? null : _submit, child: const Text('Qo\'shish')),
          ],
        ),
      ),
    );
  }
}

// ─── STAVKALAR (piece_rates) ─────────────────────────────────

class _PieceRatesTab extends StatefulWidget {
  const _PieceRatesTab({required this.readOnly, this.refreshNotifier});
  final bool readOnly;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_PieceRatesTab> createState() => _PieceRatesTabState();
}

class _PieceRatesTabState extends State<_PieceRatesTab> {
  List<dynamic> _rates = [];
  bool _loading = true;
  String _workType = 'mixing';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getPieceRates(workType: _workType);
    if (!mounted) return;
    setState(() {
      _rates = result['rates'] ?? [];
      _loading = false;
    });
  }

  Future<void> _edit({int? id, Map<String, dynamic>? existing}) async {
    if (widget.readOnly) return;
    final rate = TextEditingController();
    final unit = TextEditingController();
    if (existing != null) {
      rate.text = (existing['ratePerUnit'] ?? '').toString();
      unit.text = (existing['unit'] ?? '').toString();
    } else {
      unit.text = 'dona';
    }
    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Yangi stavka' : 'Stavkani tahrirlash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Ish turi'),
              child: Text(_workTypeLabel(_workType),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stavka (so\'m/birlik)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unit,
              decoration: const InputDecoration(labelText: 'Birlik (masalan: dona)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
          FilledButton(
            onPressed: () {
              final r = double.tryParse(rate.text);
              final u = unit.text.trim();
              if (r != null && r > 0 && u.isNotEmpty) Navigator.pop(ctx, r);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (confirmed == null) return;
    final data = {
      'workType': _workType,
      'ratePerUnit': confirmed,
      'unit': unit.text.trim(),
    };
    if (id == null) {
      await FactoryHubApi.createPieceRate(data);
    } else {
      await FactoryHubApi.updatePieceRate(id, data);
    }
    _load();
  }

  Future<void> _delete(int id) async {
    if (widget.readOnly) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirish'),
        content: const Text('Ushbu stavkani o\'chirishni tasdiqlaysizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('O\'chirish')),
        ],
      ),
    );
    if (ok == true) {
      await FactoryHubApi.deletePieceRate(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HrRefreshButton(onPressed: _load),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _workType,
                  items: const [
                    DropdownMenuItem(value: 'mixing', child: Text('Aralashtirish')),
                    DropdownMenuItem(value: 'packaging', child: Text('Qadoqlash')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _workType = v);
                      _load();
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Ish turi'),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Yangi stavka',
                  onPressed: () => _edit(),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _rates.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Stavkalar topilmadi')),
                        ])
                      : ListView.separated(
                          itemCount: _rates.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _rates[i];
                            final itemName = r['itemName'] ?? '';
                            return ListTile(
                              title: Text('${_workTypeLabel(r['workType']?.toString())} stavkasi'
                                  '${itemName.isEmpty ? '' : ' — $itemName'}'),
                              subtitle: Text('${_fmtNum((r['ratePerUnit'] ?? 0).toDouble())} so\'m/${r['unit'] ?? ''}'),
                              trailing: widget.readOnly
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () => _edit(id: r['id'], existing: r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18),
                                          onPressed: () => _delete(r['id']),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

// ─── ISHLAR (work_records) ───────────────────────────────────

class _WorkRecordsTab extends StatefulWidget {
  const _WorkRecordsTab({required this.readOnly, this.refreshNotifier});
  final bool readOnly;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_WorkRecordsTab> createState() => _WorkRecordsTabState();
}

class _WorkRecordsTabState extends State<_WorkRecordsTab> {
  List<dynamic> _records = [];
  bool _loading = true;
  String _workType = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getWorkRecords(
      workType: _workType == 'all' ? null : _workType,
    );
    if (!mounted) return;
    setState(() {
      _records = result['records'] ?? [];
      _loading = false;
    });
  }

  double get _totalAmount =>
      _records.fold(0.0, (sum, r) => sum + ((r['computedAmount'] ?? 0) as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HrRefreshButton(onPressed: _load),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _workType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Hammasi')),
                DropdownMenuItem(value: 'mixing', child: Text('Aralashtirish')),
                DropdownMenuItem(value: 'packaging', child: Text('Qadoqlash')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _workType = v);
                  _load();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Ish turi',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Ish yozuvlari topilmadi')),
                        ])
                      : ListView.separated(
                          itemCount: _records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _records[i];
                            final label = r['employeeName'] ?? '—';
                            return ListTile(
                              leading: const Icon(Icons.work_outline),
                              title: Text(label),
                              subtitle: Text('${_workTypeLabel(r['workType']?.toString())} · '
                                  '${r['workDate'] ?? ''} · '
                                  '${_fmtNum((r['quantity'] ?? 0).toDouble())} ${r['unit'] ?? ''}'),
                              trailing: Text(
                                '${_fmtNum((r['computedAmount'] ?? 0).toDouble())} so\'m',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              isThreeLine: false,
                            );
                          },
                        ),
                ),
        ),
        if (!_loading && _records.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.background,
            child: Text(
              'Jami: ${_fmtNum(_totalAmount)} so\'m  (${_records.length} ta yozuv)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

// ─── OYLIK HISOBOT ───────────────────────────────────────────

class _MonthlyReportTab extends StatefulWidget {
  const _MonthlyReportTab({this.refreshNotifier});
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  DateTime _month = DateTime.now();
  List<dynamic> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  String get _monthStr => DateFormat('yyyy-MM').format(_month);

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getMonthlyReport(month: _monthStr);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = result['rows'] ?? [];
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _month = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickMonth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Oy',
                      isDense: true,
                      prefixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('MMMM yyyy').format(_month)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Yangilash'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('Bu oy uchun ma\'lumot yo\'q')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          final payType = r['payType']?.toString() ?? 'salary';
                          final base = double.tryParse(r['baseSalaryComponent']?.toString() ?? '0') ?? 0;
                          final piece = double.tryParse(r['pieceRateComponent']?.toString() ?? '0') ?? 0;
                          final bonus = double.tryParse(r['totalBonus']?.toString() ?? '0') ?? 0;
                          final penalty = double.tryParse(r['totalPenalty']?.toString() ?? '0') ?? 0;
                          final advance = double.tryParse(r['totalAdvance']?.toString() ?? '0') ?? 0;
                          final net = double.tryParse(r['netAmount']?.toString() ?? '');
                          final payLabel = switch (payType) {
                            'piece_rate' => 'Ishbay',
                            'hybrid' => 'Aralash',
                            _ => 'Oylik',
                          };
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r['fullName'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        net == null ? 'Hisob yo\'q' : 'Jami: ${_fmtNum(net)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: net == null ? AppColors.textSecondary : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _stat('Haq turi', payLabel),
                                      _stat('Keldi', r['daysPresent']),
                                      _stat('Kelmadi', r['daysAbsent']),
                                      _stat('Kech', r['daysLate']),
                                      _stat('Soat', r['totalHours']),
                                      _stat('Qo\'shimcha',
                                          _hasOt(r) ? r['totalOvertimeHours'] : '-'),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Oylik: ${_fmtNum(base)}  •  Ishbay: ${_fmtNum(piece)}  •  Premiya: ${_fmtNum(bonus)}  •  Jarima: ${_fmtNum(penalty)}  •  Avans: ${_fmtNum(advance)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  if (r['position'] != null || r['department'] != null)
                                    Text(
                                      [r['department'], r['position']].where((x) => x != null && x.toString().isNotEmpty).join(' — '),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _stat(String label, dynamic v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: ${v ?? 0}', style: const TextStyle(fontSize: 11)),
    );
  }
}