import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});
  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  Map<String, dynamic>? _data;
  List _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getProductionReport('month');
    setState(() {
      _data = result;
      _batches = (result['batches'] as List?) ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ishlab chiqarish'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_data != null && _data!['statistics'] != null) ...[
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Text('Jami partiyalar: ${_data!['statistics']['totalBatches']}', style: const TextStyle(fontSize: 16)),
              Text('Yakunlangan: ${_data!['statistics']['completedBatches']}', style: const TextStyle(color: Colors.green)),
              Text('Ishlab chiqarilgan: ${_data!['statistics']['totalProduced']} dona', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]))),
          ],
          const SizedBox(height: 10),
          ...(_batches.map((b) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
            title: Text(b['batchNumber'] ?? ''),
            subtitle: Text('Reja: ${b['plannedQuantity']} | Haqiqiy: ${b['actualQuantity']} ${b['unit']}'),
            trailing: _statusChip(b['status']),
          )))),
        ]),
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    String text;
    switch (status) {
      case 'completed': color = Colors.green; text = 'Yakunlangan'; break;
      case 'in_progress': color = Colors.blue; text = 'Jarayonda'; break;
      case 'planned': color = Colors.orange; text = 'Rejalashtirilgan'; break;
      case 'cancelled': color = Colors.red; text = 'Bekor qilingan'; break;
      default: color = Colors.grey; text = status ?? 'Noma\'lum';
    }
    return Chip(label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: color);
  }
}
