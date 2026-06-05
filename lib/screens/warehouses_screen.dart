import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});
  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getWarehouses();
    setState(() {
      _warehouses = (result['warehouses'] as List?) ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Omborlar'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: _warehouses.isEmpty ? const Center(child: Text('Omborlar yo\'q')) : ListView.builder(
          itemCount: _warehouses.length,
          itemBuilder: (ctx, i) {
            final w = _warehouses[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
              leading: Icon(_warehouseIcon(w['type']), color: const Color(0xFF1565C0)),
              title: Text(w['name'] ?? ''), subtitle: Text('Tur: ${w['type']}'),
            ));
          },
        ),
      ),
    );
  }

  IconData _warehouseIcon(String? type) {
    switch (type) {
      case 'raw': return Icons.science;
      case 'purchased': return Icons.shopping_cart;
      case 'semi_finished': return Icons.hourglass_bottom;
      case 'finished': return Icons.check_circle;
      case 'sales': return Icons.store;
      default: return Icons.warehouse;
    }
  }
}
