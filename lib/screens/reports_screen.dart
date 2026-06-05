import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _stock;
  Map<String, dynamic>? _forecast;
  Map<String, dynamic>? _production;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final stock = await FactoryHubApi.getStockReport();
    final forecast = await FactoryHubApi.getForecastReport();
    final production = await FactoryHubApi.getProductionReport();
    setState(() {
      _stock = stock;
      _forecast = forecast;
      _production = production;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hisobotlar'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _loadAll,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _reportCard('Zaxira hisoboti', Icons.inventory_2, _stock?['statistics']),
          _reportCard('Prognoz', Icons.trending_up, _forecast?['summary']),
          _reportCard('Ishlab chiqarish', Icons.precision_manufacturing, _production?['statistics']),
        ]),
      ),
    );
  }

  Widget _reportCard(String title, IconData icon, Map<String, dynamic>? stats) {
    if (stats == null) return const SizedBox();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: const Color(0xFF1565C0)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        const Divider(),
        ...stats.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(e.key.toString()), Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]))),
      ])),
    );
  }
}
