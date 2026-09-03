import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_StockReport(), _ProductionReport(), _TransactionReport()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ZAXIRA ───────────────────────────────────────────────

class _StockReport extends StatefulWidget {
  const _StockReport();

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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stock.isEmpty) return const Center(child: Text('Zaxira topilmadi'));
    return RefreshIndicator(
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
    );
  }
}

// ─── ISHLAB CHIQARISH ─────────────────────────────────────

class _ProductionReport extends StatefulWidget {
  const _ProductionReport();

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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_batches.isEmpty) return const Center(child: Text('Ishlab chiqarish topilmadi'));
    return RefreshIndicator(
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
    );
  }
}

// ─── KIRIM/CHIQIM HISOBOT ────────────────────────────────

class _TransactionReport extends StatefulWidget {
  const _TransactionReport();

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
