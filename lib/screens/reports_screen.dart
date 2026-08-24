import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(tabs: [Tab(text: 'Zaxira'), Tab(text: 'Ishlab chiqarish')]),
        ),
        body: const TabBarView(children: [_StockReport(), _ProductionReport()]),
      ),
    );
  }
}

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
              subtitle:
                  Text('Reja ${b['plannedQty']} / bajarildi ${b['producedQty'] ?? '-'} dona'),
              trailing: Text(b['status'] ?? ''),
            ),
          );
        },
      ),
    );
  }
}
