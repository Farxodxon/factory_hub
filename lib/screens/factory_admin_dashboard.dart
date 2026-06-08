import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'materials_screen.dart';
import 'warehouses_screen.dart';
import 'boms_screen.dart';
import 'production_screen.dart';
import 'reports_screen.dart';
import 'alerts_screen.dart';
import 'users_screen.dart';
import 'login_screen.dart';

class FactoryAdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const FactoryAdminDashboard({super.key, required this.user});

  @override
  State<FactoryAdminDashboard> createState() => _FactoryAdminDashboardState();
}

class _FactoryAdminDashboardState extends State<FactoryAdminDashboard> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getFactoryAdminDashboard();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() { _data = result; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final factory = _data['factory'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(factory['name']?.toString() ?? 'Zavod Admin', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: _buildDrawer(factory),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(factory),
                      const SizedBox(height: 16),
                      _buildTodayCard(),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 16),
                      _buildMonthlyCard(),
                      const SizedBox(height: 16),
                      _buildTrendChart(),
                      const SizedBox(height: 16),
                      _buildLowMaterials(),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Map factory) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.factory, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(factory['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (factory['address'] != null)
            Text(factory['address'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Xush kelibsiz, ${widget.user['username']}!', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, color: Colors.greenAccent, size: 8),
            SizedBox(width: 4),
            Text('Faol', style: TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTodayCard() {
    final today = _data['today'] as Map<String, dynamic>? ?? {};
    final batches = today['batches'] ?? 0;
    final qty = double.tryParse(today['quantity']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.today, color: Color(0xFF1565C0), size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bugun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('$batches partiya • ${qty.toStringAsFixed(0)} dona ishlab chiqarildi',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen())),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Yangi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    final overview = _data['overview'] as Map<String, dynamic>? ?? {};
    final stats = [
      {'title': 'Xodimlar', 'value': '${overview['totalUsers'] ?? 0}', 'icon': Icons.people, 'color': const Color(0xFF1565C0)},
      {'title': 'Materiallar', 'value': '${overview['totalMaterials'] ?? 0}', 'icon': Icons.inventory_2, 'color': Colors.purple},
      {'title': 'Kam zaxira', 'value': '${overview['lowStockCount'] ?? 0}', 'icon': Icons.warning_amber, 'color': Colors.red},
      {'title': 'Omborlar', 'value': '${overview['totalWarehouses'] ?? 0}', 'icon': Icons.warehouse, 'color': Colors.orange},
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
        return GestureDetector(
          onTap: () {
            if (i == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
            if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()));
            if (i == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen()));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(s['icon'] as IconData, color: color, size: 24),
                if (i != 2) const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ]),
              const SizedBox(height: 8),
              Text(s['value'] as String, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              Text(s['title'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyCard() {
    final monthly = _data['monthly'] as Map<String, dynamic>? ?? {};
    return _card('Bu oygi ishlab chiqarish', Icons.precision_manufacturing,
      Row(children: [
        Expanded(child: _miniStat('Bajarildi', '${monthly['completed'] ?? 0}', Colors.green)),
        Expanded(child: _miniStat('Jarayonda', '${monthly['inProgress'] ?? 0}', Colors.orange)),
        Expanded(child: _miniStat('Rejalangan', '${monthly['planned'] ?? 0}', Colors.blue)),
        Expanded(child: _miniStat('Jami dona', '${(double.tryParse(monthly['totalQuantity']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}', Colors.purple)),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildTrendChart() {
    final trend = (_data['trend'] as List?) ?? [];
    if (trend.isEmpty) {
      return _card('Ishlab chiqarish trendi', Icons.trending_up,
        const SizedBox(height: 100, child: Center(child: Text('Ma\'lumot yo\'q', style: TextStyle(color: Colors.grey)))));
    }

    final spots = trend.asMap().entries.map((e) {
      final qty = double.tryParse(e.value['quantity']?.toString() ?? '0') ?? 0;
      return FlSpot(e.key.toDouble(), qty);
    }).toList();
    final months = trend.map((e) => e['month']?.toString() ?? '').toList();

    return _card('Ishlab chiqarish trendi (6 oy)', Icons.trending_up,
      SizedBox(height: 160, child: LineChart(LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox();
              return Text(months[i], style: const TextStyle(fontSize: 10));
            },
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [LineChartBarData(
          spots: spots, isCurved: true,
          color: const Color(0xFF1565C0), barWidth: 3,
          belowBarData: BarAreaData(show: true, color: const Color(0xFF1565C0).withValues(alpha: 0.1)),
          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: const Color(0xFF1565C0), strokeWidth: 2, strokeColor: Colors.white)),
        )],
      ))),
    );
  }

  Widget _buildLowMaterials() {
    final lowMaterials = (_data['lowMaterials'] as List?) ?? [];
    if (lowMaterials.isEmpty) return const SizedBox();

    return _card('Kam qolgan materiallar', Icons.warning_amber,
      Column(children: lowMaterials.map((m) {
        final current = double.tryParse(m['currentStock']?.toString() ?? '0') ?? 0;
        final min = double.tryParse(m['minStock']?.toString() ?? '0') ?? 0;
        final pct = min > 0 ? (current / min).clamp(0.0, 1.0) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              Text('${current.toStringAsFixed(1)} / ${min.toStringAsFixed(1)} ${m['unit']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.red.shade50,
                valueColor: AlwaysStoppedAnimation(pct < 0.3 ? Colors.red : Colors.orange),
                minHeight: 8,
              ),
            ),
          ]),
        );
      }).toList()),
    );
  }

  Widget _buildRecentActivity() {
    final activity = (_data['recentActivity'] as List?) ?? [];
    if (activity.isEmpty) return const SizedBox();

    return _card('So\'ngi ishlab chiqarish', Icons.history,
      Column(children: activity.take(5).map((a) {
        final status = a['status'] as String? ?? '';
        Color statusColor;
        IconData statusIcon;
        switch (status) {
          case 'completed': statusColor = Colors.green; statusIcon = Icons.check_circle; break;
          case 'in_progress': statusColor = Colors.orange; statusIcon = Icons.play_circle; break;
          default: statusColor = Colors.blue; statusIcon = Icons.schedule;
        }
        final qty = double.tryParse(a['actualQty']?.toString() ?? '0') ?? 0;
        final planned = double.tryParse(a['plannedQty']?.toString() ?? '0') ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Partiya #${a['id']} — ${qty > 0 ? qty.toStringAsFixed(0) : planned.toStringAsFixed(0)} ${a['unit']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(a['operator']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(status), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }).toList()),
    );
  }

  Widget _buildQuickActions() {
    return _card('Tezkor amallar', Icons.flash_on,
      Column(children: [
        Row(children: [
          Expanded(child: _actionBtn('Partiya boshlash', Icons.play_arrow, Colors.green,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen())))),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn('Material qo\'shish', Icons.add_box, Colors.blue,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen())))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _actionBtn('BOM', Icons.list_alt, Colors.purple,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen())))),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn('Hisobot', Icons.bar_chart, Colors.teal,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())))),
        ]),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed': return 'Bajarildi';
      case 'in_progress': return 'Jarayonda';
      default: return 'Rejalangan';
    }
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 60, color: Colors.red),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
    ]));
  }

  Widget _buildDrawer(Map factory) {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF1565C0)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.white,
            child: Text((widget.user['username'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF1565C0), fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Text(widget.user['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(factory['name']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Text('Zavod Admin', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
      _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
      _drawerItem(Icons.people, 'Xodimlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())); }),
      _drawerItem(Icons.inventory_2, 'Materiallar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen())); }),
      _drawerItem(Icons.warehouse, 'Omborlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen())); }),
      _drawerItem(Icons.list_alt, 'BOM', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BomsScreen())); }),
      _drawerItem(Icons.precision_manufacturing, 'Ishlab chiqarish', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen())); }),
      _drawerItem(Icons.bar_chart, 'Hisobotlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())); }),
      _drawerItem(Icons.notifications, 'Ogohlantirishlar', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())); }),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Chiqish', style: TextStyle(color: Colors.red)),
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
