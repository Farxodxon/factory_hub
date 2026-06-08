import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'materials_screen.dart';
import 'warehouses_screen.dart';
import 'boms_screen.dart';
import 'production_screen.dart';
import 'reports_screen.dart';
import 'alerts_screen.dart';

class FactoryDetailScreen extends StatefulWidget {
  final Map factory;
  const FactoryDetailScreen({super.key, required this.factory});

  @override
  State<FactoryDetailScreen> createState() => _FactoryDetailScreenState();
}

class _FactoryDetailScreenState extends State<FactoryDetailScreen> {
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getDashboard();
    setState(() {
      _summary = result['summary'] ?? {};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final factory = widget.factory;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(factory['name'] ?? 'Zavod', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Zavod info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.factory, color: Colors.white, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(factory['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (factory['address'] != null)
                        Text(factory['address'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _infoBadge('${factory['userCount'] ?? 0} xodim'),
                        const SizedBox(width: 8),
                        _infoBadge('${factory['materialCount'] ?? 0} material'),
                      ]),
                    ])),
                  ]),
                ),

                const SizedBox(height: 16),

                // Statistika
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _statCard('Materiallar', '${_summary['totalMaterials'] ?? 0}', Icons.inventory_2, Colors.blue),
                    _statCard('Kam zaxira', '${_summary['lowStockCount'] ?? 0}', Icons.warning_amber, Colors.red),
                    _statCard('Faol partiya', '${_summary['activeBatches'] ?? 0}', Icons.play_circle, Colors.green),
                    _statCard('Omborlar', '${_summary['totalWarehouses'] ?? 0}', Icons.warehouse, Colors.purple),
                  ],
                ),

                const SizedBox(height: 20),

                // Modullar
                const Text('Boshqaruv modullari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _moduleCard('Materiallar', 'Xom ashyo va materiallar boshqaruvi', Icons.inventory_2, Colors.blue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()))),
                _moduleCard('Omborlar', 'Kirim, chiqim va zaxira nazorati', Icons.warehouse, Colors.orange,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen()))),
                _moduleCard('BOM', 'Mahsulot tarkibi va formulalar', Icons.list_alt, Colors.purple,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen()))),
                _moduleCard('Ishlab chiqarish', 'Partiyalar va jarayonlar', Icons.precision_manufacturing, Colors.green,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen()))),
                _moduleCard('Hisobotlar', 'Tahlil va statistika', Icons.bar_chart, Colors.teal,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                _moduleCard('Ogohlantirishlar', 'Zaxira va jarayon ogohlantirishlari', Icons.notifications, Colors.red,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()))),
              ],
            ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _moduleCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
