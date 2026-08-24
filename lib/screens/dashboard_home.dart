import 'package:flutter/material.dart';

import '../services/api_service.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _data = result;
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      );
    }

    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _card(Icons.people, 'Faol xodimlar', stats['activeUsers']),
              _card(Icons.warehouse, 'Omborlar', stats['activeWarehouses']),
              _card(Icons.assignment, 'Ochiq rejalar', stats['openPlans']),
              _card(Icons.factory, 'Jarayondagi partiyalar', stats['batchesInProgress']),
              _card(Icons.local_shipping, "Ta'minot buyurtmalari", stats['pendingSupplierOrders']),
              _card(Icons.inventory_2, 'Mahsulotlar', stats['totalProducts']),
              _card(Icons.science, 'Xom ashyolar', stats['totalRawMaterials']),
              _card(Icons.handshake, 'Hamkorlar', stats['activePartners']),
            ],
          ),
          const SizedBox(height: 16),
          if ((stats['batchesInProgress'] ?? 0) > 0 || (_data?['lowStockCount'] ?? 0) > 0)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                title: Text("Kam qoldiq: ${_data?['lowStockCount']} ta element"),
                subtitle: const Text('Ogohlantirishlar bo\'limida batafsil'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String label, dynamic value) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${value ?? 0}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
}
