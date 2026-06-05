import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'materials_screen.dart';
import 'warehouses_screen.dart';
import 'boms_screen.dart';
import 'production_screen.dart';
import 'reports_screen.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;

  String get role => widget.user['role'] ?? 'employee';
  String get userId => widget.user['id']?.toString() ?? '';
  String get factoryId => widget.user['factoryId']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getDashboard();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() { _summary = result['summary'] ?? {}; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FactoryHub'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text(_roleLabel(role), style: const TextStyle(fontSize: 11, color: Colors.white)),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard),
        ],
      ),
      drawer: _buildDrawer(),
      body: _loading ? const Center(child: CircularProgressIndicator())
           : _error != null ? _buildError()
           : RefreshIndicator(onRefresh: _loadDashboard, child: ListView(padding: const EdgeInsets.all(16), children: [
        // Xush kelibsiz
        Card(
          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            CircleAvatar(radius: 25, backgroundColor: const Color(0xFF1565C0), child: Text((widget.user['username'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Xush kelibsiz, ${widget.user['username'] ?? 'Foydalanuvchi'}!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(_roleLabel(role), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ]),
          ])),
        ),
        const SizedBox(height: 16),
        _buildStatCards(),
        const SizedBox(height: 20),
        _buildQuickActions(),
      ])),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Zavod Admin';
      case 'employee': return 'Xodim';
      default: return role;
    }
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 60, color: Colors.red),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(fontSize: 16, color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _loadDashboard, child: const Text('Qayta urinish')),
    ]));
  }

  Widget _buildStatCards() {
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
      children: [
        _statCard('Materiallar', '${_summary['totalMaterials'] ?? 0}', Icons.inventory, Colors.blue),
        _statCard('Kam qolgan', '${_summary['lowStockCount'] ?? 0}', Icons.warning, Colors.red),
        _statCard('Faol partiyalar', '${_summary['activeBatches'] ?? 0}', Icons.play_circle, Colors.green),
        _statCard('Omborlar', '${_summary['totalWarehouses'] ?? 0}', Icons.warehouse, Colors.purple),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 28), const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
    ])));
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Menyu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _actionButton('Materiallar', Icons.inventory, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()))),
      _actionButton('Omborlar', Icons.warehouse, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen()))),
      if (role == 'super_admin' || role == 'admin')
        _actionButton('Mahsulot tarkiblari (BOM)', Icons.list_alt, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen()))),
      _actionButton('Ishlab chiqarish', Icons.precision_manufacturing, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen()))),
      _actionButton('Hisobotlar', Icons.bar_chart, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
      _actionButton('Ogohlantirishlar', Icons.notifications, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()))),
    ]);
  }

  Widget _actionButton(String title, IconData icon, VoidCallback onTap) {
    return Card(child: ListTile(leading: Icon(icon, color: const Color(0xFF1565C0)), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap));
  }

  Widget _buildDrawer() {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1565C0)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text((widget.user['username'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1565C0), fontSize: 22))),
          const SizedBox(height: 8),
          Text(widget.user['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18)),
          Text(widget.user['email'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('Rol: ${_roleLabel(role)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
      ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard'), onTap: () => Navigator.pop(context)),
      ListTile(leading: const Icon(Icons.inventory), title: const Text('Materiallar'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen())); }),
      ListTile(leading: const Icon(Icons.warehouse), title: const Text('Omborlar'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen())); }),
      if (role == 'super_admin' || role == 'admin')
        ListTile(leading: const Icon(Icons.list_alt), title: const Text('BOM'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen())); }),
      ListTile(leading: const Icon(Icons.precision_manufacturing), title: const Text('Ishlab chiqarish'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen())); }),
      ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Hisobotlar'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())); }),
      ListTile(leading: const Icon(Icons.notifications), title: const Text('Ogohlantirishlar'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Chiqish', style: TextStyle(color: Colors.red)), onTap: () {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }),
    ]));
  }
}
