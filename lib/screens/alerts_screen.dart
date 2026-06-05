import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List _alerts = [];
  List _lowStock = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getAlerts();
    setState(() {
      _alerts = (result['alerts'] as List?) ?? [];
      _lowStock = (result['lowStockMaterials'] as List?) ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ogohlantirishlar'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_lowStock.isNotEmpty) ...[
            const Text('⚠️ Kam qolgan materiallar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ...(_lowStock.map((m) => Card(color: Colors.red.shade50, child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(m['name'] ?? ''),
              subtitle: Text('Qoldiq: ${m['currentStock']} ${m['unit']}'),
            )))),
          ],
          if (_lowStock.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('✅ Barcha materiallar yetarli', style: TextStyle(fontSize: 16, color: Colors.green))))),
        ]),
      ),
    );
  }
}
