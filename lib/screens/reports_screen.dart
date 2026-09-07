import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Zaxira'),
                Tab(text: 'Ishlab chiqarish'),
                Tab(text: 'Kirim/Chiqim'),
                Tab(text: '51-rejim'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StockReport(refreshNotifier: refreshNotifier),
                _ProductionReport(refreshNotifier: refreshNotifier),
                _TransactionReport(refreshNotifier: refreshNotifier),
                _Regime51Report(refreshNotifier: refreshNotifier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ZAXIRA ───────────────────────────────────────────────

class _StockReport extends StatefulWidget {
  const _StockReport({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_StockReport> createState() => _StockReportState();
}

class _StockReportState extends State<_StockReport> {
  List<dynamic> _stock = [];
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
    final result = await FactoryHubApi.getStock();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stock = result['stock'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final refreshBtn = Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Yangilash'),
        ),
      ),
    );
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stock.isEmpty) {
      return Column(
        children: [
          refreshBtn,
          const Expanded(child: Center(child: Text('Zaxira topilmadi'))),
        ],
      );
    }
    return Column(
      children: [
        refreshBtn,
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _stock.length,
              itemBuilder: (_, i) {
                final s = _stock[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: Text(s['warehouseName'] ?? ''),
                    title: Text(s['name'] ?? ''),
                    trailing: Text('${s['balance']} ${s['unit'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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

// ─── ISHLAB CHIQARISH ─────────────────────────────────────

class _ProductionReport extends StatefulWidget {
  const _ProductionReport({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_ProductionReport> createState() => _ProductionReportState();
}

class _ProductionReportState extends State<_ProductionReport> {
  List<dynamic> _batches = [];
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
    final result = await FactoryHubApi.getBatches();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _batches = result['batches'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final refreshBtn = Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Yangilash'),
        ),
      ),
    );
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_batches.isEmpty) {
      return Column(
        children: [
          refreshBtn,
          const Expanded(child: Center(child: Text('Ishlab chiqarish topilmadi'))),
        ],
      );
    }
    return Column(
      children: [
        refreshBtn,
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _batches.length,
              itemBuilder: (_, i) {
                final b = _batches[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(b['productName'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Reja ${b['plannedQty']} / bajarildi ${b['producedQty'] ?? '-'} dona'),
                    trailing: Text(b['status'] ?? ''),
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

// ─── KIRIM/CHIQIM HISOBOT ────────────────────────────────

class _TransactionReport extends StatefulWidget {
  const _TransactionReport({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_TransactionReport> createState() => _TransactionReportState();
}

class _TransactionReportState extends State<_TransactionReport> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String _type = 'all';
  int? _warehouseId;
  bool _downloading = false;
  List<dynamic> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _loadWarehouses();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final result = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    final all = result['warehouses'] ?? [];
    setState(() => _warehouses = all.where((w) => w['canAnalyze'] != false).toList());
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
          if (_from.isAfter(_to)) _to = _from;
        } else {
          _to = picked;
          if (_to.isBefore(_from)) _from = _to;
        }
      });
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtDisplay(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  Future<void> _download() async {
    setState(() => _downloading = true);
    final path = await FactoryHubApi.downloadTransactionReport(
      from: _fmt(_from),
      to: _fmt(_to),
      type: _type,
      warehouseId: _warehouseId,
    );
    if (!mounted) return;
    setState(() => _downloading = false);
    if (path != null) {
      final fileName = path.split('/').last;
      final xFile = XFile(path, name: fileName);
      await Share.shareXFiles(
        [xFile],
        subject: 'Hisobot: $_fmtDisplay(_from) — ${_fmtDisplay(_to)}',
        text: 'Kirim/Chiqim hisoboti',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hisobot yuklab bo\'lmadi'),
          backgroundColor: AppColors.statusCritical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadWarehouses,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yangilash'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hisobot sozlamalari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  isDesktop
                      ? Row(
                          children: [
                            Expanded(child: _dateField('Dan', _fmtDisplay(_from), () => _pickDate(isFrom: true))),
                            const SizedBox(width: 12),
                            Expanded(child: _dateField('Gacha', _fmtDisplay(_to), () => _pickDate(isFrom: false))),
                            const SizedBox(width: 12),
                            Expanded(child: _warehouseSelector()),
                            const SizedBox(width: 12),
                            Expanded(child: _typeSelector()),
                            const SizedBox(width: 12),
                            _downloadButton(),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _dateField('Dan', _fmtDisplay(_from), () => _pickDate(isFrom: true))),
                                const SizedBox(width: 12),
                                Expanded(child: _dateField('Gacha', _fmtDisplay(_to), () => _pickDate(isFrom: false))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _warehouseSelector(),
                            const SizedBox(height: 12),
                            _typeSelector(),
                            const SizedBox(height: 16),
                            _downloadButton(),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warehouseSelector() {
    return DropdownButtonFormField<int?>(
      value: _warehouseId,
      decoration: const InputDecoration(
        labelText: 'Ombor',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Barcha omborlar')),
        ..._warehouses.map<DropdownMenuItem<int?>>((w) =>
          DropdownMenuItem(value: w['id'], child: Text(w['name'] ?? '')),
        ),
      ],
      onChanged: (v) => setState(() => _warehouseId = v),
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _typeSelector() {
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(
        labelText: 'Turi',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Hammasi (alohida varaqalar)')),
        DropdownMenuItem(value: 'in', child: Text('Faqat kirim')),
        DropdownMenuItem(value: 'out', child: Text('Faqat chiqim')),
      ],
      onChanged: (v) => setState(() => _type = v ?? 'all'),
    );
  }

  Widget _downloadButton() {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: _downloading ? null : _download,
        icon: _downloading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download),
        label: Text(_downloading ? 'Yuklanmoqda...' : 'Excel yuklab olish'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      ),
    );
  }
}

// ─── 51-REJIM QOLDIQ HISOBOTI ─────────────────────────────
// Faqat is_regime_51=true bo'lgan yozuvlarni ko'rsatadi — umumiy zaxira
// hisobotidan butunlay alohida bo'lim.

class _Regime51Report extends StatefulWidget {
  const _Regime51Report({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_Regime51Report> createState() => _Regime51ReportState();
}

class _Regime51ReportState extends State<_Regime51Report> {
  List<dynamic> _rows = [];
  List<dynamic> _warehouses = [];
  int? _warehouseId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
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

  Future<void> _loadWarehouses() async {
    final result = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    final all = result['warehouses'] ?? [];
    setState(() => _warehouses = all);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getRegime51Balance(warehouseId: _warehouseId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = result['balance'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yangilash'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<int?>(
            initialValue: _warehouseId,
            decoration: const InputDecoration(
              labelText: 'Ombor (ixtiyoriy)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Barcha omborlar')),
              ..._warehouses.map<DropdownMenuItem<int?>>(
                (w) => DropdownMenuItem(
                  value: w['id'] is int ? w['id'] as int : int.tryParse('${w['id']}'),
                  child: Text('${w['name'] ?? ''} (${w['type'] ?? ''})'),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _warehouseId = v);
              _load();
            },
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
                          Center(child: Text('51-rejim bo\'yicha yozuvlar topilmadi')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          final whList = _warehouses
                              .where((w) => (w['id'] as int?) == r['warehouseId'])
                              .toList();
                          final whName = whList.isEmpty ? null : whList.first['name'] as String?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.flag, color: AppColors.primary),
                              title: Text(r['name'] ?? ''),
                              subtitle: Text(
                                'Kod: ${r['refKey'] ?? '-'}${whName != null ? ' | Ombor: $whName' : ''}',
                              ),
                              trailing: Text(
                                '${r['balance']} ${r['unit'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
}
