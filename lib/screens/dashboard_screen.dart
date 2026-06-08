import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  Map<String, dynamic> _production = {};
  Map<String, dynamic> _stock = {};
  bool _loading = true;
  String? _error;

  String get role => widget.user['role'] ?? 'employee';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      FactoryHubApi.getDashboard(),
      FactoryHubApi.getProductionReport('month'),
      FactoryHubApi.getStockReport(),
    ]);
    if (results[0]['error'] != null) {
      setState(() { _error = results[0]['error']; _loading = false; });
      return;
    }
    setState(() {
      _summary = results[0]['summary'] ?? {};
      _production = results[1];
      _stock = results[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('FactoryHub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_roleLabel(role), style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: _buildDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 16),
                      _buildStatGrid(),
                      const SizedBox(height: 20),
                      _buildProductionChart(),
                      const SizedBox(height: 16),
                      _buildStockChart(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(
            (widget.user['username'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xush kelibsiz, ${widget.user['username']}!',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_roleLabel(role), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(widget.user['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        const Icon(Icons.precision_manufacturing, color: Colors.white30, size: 48),
      ]),
    );
  }

  Widget _buildStatGrid() {
    final stats = [
      {'title': 'Materiallar', 'value': '${_summary['totalMaterials'] ?? 0}', 'icon': Icons.inventory_2, 'color': const Color(0xFF1565C0)},
      {'title': 'Kam qolgan', 'value': '${_summary['lowStockCount'] ?? 0}', 'icon': Icons.warning_amber, 'color': Colors.red},
      {'title': 'Faol partiya', 'value': '${_summary['activeBatches'] ?? 0}', 'icon': Icons.play_circle, 'color': Colors.green},
      {'title': 'Omborlar', 'value': '${_summary['totalWarehouses'] ?? 0}', 'icon': Icons.warehouse, 'color': Colors.purple},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        final color = s['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(s['icon'] as IconData, color: color, size: 28),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(s['icon'] as IconData, color: color, size: 16),
              ),
            ]),
            const SizedBox(height: 10),
            Text(s['value'] as String, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(s['title'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        );
      },
    );
  }

  Widget _buildProductionChart() {
    final batches = (_production['batches'] as List?) ?? [];
    if (batches.isEmpty) return _buildEmptyChart('Ishlab chiqarish grafigi', 'Ma\'lumot yo\'q');

    // So'ngi 7 ta partiya
    final recent = batches.take(7).toList().reversed.toList();
    final bars = recent.asMap().entries.map((e) {
      final qty = double.tryParse(e.value['plannedQuantity']?.toString() ?? '0') ?? 0;
      final actual = double.tryParse(e.value['actualQuantity']?.toString() ?? '0') ?? 0;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: qty, color: const Color(0xFF1565C0).withValues(alpha: 0.5), width: 10, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: actual, color: Colors.green, width: 10, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return _buildChartCard(
      title: 'Ishlab chiqarish (so\'ngi partiyalar)',
      legend: Row(children: [
        _legendDot(const Color(0xFF1565C0).withValues(alpha: 0.5), 'Rejalashtirilgan'),
        const SizedBox(width: 16),
        _legendDot(Colors.green, 'Haqiqiy'),
      ]),
      child: BarChart(
        BarChartData(
          barGroups: bars,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('P${v.toInt() + 1}', style: const TextStyle(fontSize: 10)),
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

  Widget _buildStockChart() {
    final materials = (_stock['materials'] as List?) ?? [];
    if (materials.isEmpty) return _buildEmptyChart('Zaxira holati', 'Ma\'lumot yo\'q');

    final top = materials.take(6).toList();
    final sections = top.asMap().entries.map((e) {
      final stock = double.tryParse(e.value['currentStock']?.toString() ?? '0') ?? 0;
      final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];
      return PieChartSectionData(
        value: stock <= 0 ? 0.1 : stock,
        title: stock <= 0 ? '' : stock.toStringAsFixed(0),
        color: colors[e.key % colors.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return _buildChartCard(
      title: 'Zaxira holati (materiallar)',
      legend: Wrap(
        spacing: 8,
        children: top.asMap().entries.map((e) {
          final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];
          return _legendDot(colors[e.key % colors.length], e.value['name'] ?? '');
        }).toList(),
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 3,
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child, Widget? legend}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        if (legend != null) ...[const SizedBox(height: 8), legend],
        const SizedBox(height: 16),
        SizedBox(height: 200, child: child),
      ]),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
        Text(message, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _buildQuickActions() {
    final items = [
      {'title': 'Materiallar', 'icon': Icons.inventory_2, 'screen': const MaterialsScreen()},
      {'title': 'Omborlar', 'icon': Icons.warehouse, 'screen': const WarehousesScreen()},
      {'title': 'Ishlab chiqarish', 'icon': Icons.precision_manufacturing, 'screen': const ProductionScreen()},
      {'title': 'Hisobotlar', 'icon': Icons.bar_chart, 'screen': const ReportsScreen()},
      {'title': 'Ogohlantirishlar', 'icon': Icons.notifications, 'screen': const AlertsScreen()},
    ];
    if (role == 'super_admin' || role == 'admin') {
      items.insert(2, {'title': 'BOM', 'icon': Icons.list_alt, 'screen': const BomsScreen()});
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tezkor menyu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item['icon'] as IconData, color: const Color(0xFF1565C0), size: 20),
          ),
          title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'] as Widget)),
        ),
      )),
    ]);
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 60, color: Colors.red),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
    ]));
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Zavod Admin';
      default: return 'Xodim';
    }
  }

  Widget _buildDrawer() {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF1565C0)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.white,
            child: Text((widget.user['username'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF1565C0), fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Text(widget.user['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(widget.user['email'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('Rol: ${_roleLabel(role)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
      _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
      _drawerItem(Icons.inventory_2, 'Materiallar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen())); }),
      _drawerItem(Icons.warehouse, 'Omborlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen())); }),
      if (role == 'super_admin' || role == 'admin')
        _drawerItem(Icons.list_alt, 'BOM', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen())); }),
      _drawerItem(Icons.precision_manufacturing, 'Ishlab chiqarish', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen())); }),
      _drawerItem(Icons.bar_chart, 'Hisobotlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())); }),
      _drawerItem(Icons.notifications, 'Ogohlantirishlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())); }),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Chiqish', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
        onTap: () {
          FactoryHubApi.logout();
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        },
      ),
    ]));
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
