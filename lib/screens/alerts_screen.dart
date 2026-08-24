import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getAlerts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = result['error'] == null ? result : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return const Center(child: Text("Ma'lumot olinmadi"));
    }

    final lowStock = _data!['lowStock'] as List<dynamic>? ?? [];
    final lateOrders = _data!['lateSupplierOrders'] as List<dynamic>? ?? [];
    final overduePlans = _data!['overduePlans'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (lowStock.isEmpty && lateOrders.isEmpty && overduePlans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('Hamma narsa tartibda')),
            ),
          if (lowStock.isNotEmpty) ...[
            _sectionTitle('Kam qoldiq (${lowStock.length})', Colors.orange),
            ...lowStock.map((a) => Card(
                  color: Colors.orange.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.inventory, color: Colors.orange),
                    title: Text(a['name'] ?? ''),
                    trailing: Text('${a['balance']} < ${a['minQty']}'),
                  ),
                )),
          ],
          if (lateOrders.isNotEmpty) ...[
            _sectionTitle("Kechikkan buyurtmalar (${lateOrders.length})", Colors.red),
            ...lateOrders.map((a) => Card(
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.red),
                    title: Text('${a['materialName'] ?? ''} — ${a['supplierName'] ?? ''}'),
                    subtitle: Text('Kutilgan sana: ${a['expectedAt']?.toString().substring(0, 10)}'),
                    trailing: Text('+${a['daysLate']} kun', style: TextStyle(color: Colors.red.shade700)),
                  ),
                )),
          ],
          if (overduePlans.isNotEmpty) ...[
            _sectionTitle('Muddati o`tgan rejalar (${overduePlans.length})', Colors.deepPurple),
            ...overduePlans.map((a) => Card(
                  color: Colors.deepPurple.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(Icons.assignment_late, color: Colors.deepPurple.shade400),
                    title: Text(a['title'] ?? ''),
                    trailing: Text('Qoldi: ${a['remaining']}'),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      );
}
