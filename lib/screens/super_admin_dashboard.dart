import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'factories_screen.dart';
import 'users_screen.dart';
import 'system_alerts_screen.dart';
import 'factory_detail_screen.dart';
import 'login_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const SuperAdminDashboard({super.key, required this.user});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
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
    final result = await FactoryHubApi.getSuperAdminDashboard();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() { _data = result; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Super Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
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
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildMainStats(),
                      const SizedBox(height: 16),
                      _buildTrendChart(),
                      const SizedBox(height: 16),
                      _buildFactoriesList(),
                      const SizedBox(height: 16),
                      _buildUserRoles(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xush kelibsiz, ${widget.user['username']}!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Super Administrator', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Text('Barcha zavodlar nazorati', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Column(children: [
          const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
          const SizedBox(height: 4),
          Text('Jonli', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildMainStats() {
    final overview = _data['overview'] as Map<String, dynamic>? ?? {};
    final factories = (_data['factories'] as List?) ?? [];
    final activeFactories = factories.where((f) => f['isActive'] == true).length;
    final inactiveFactories = factories.length - activeFactories;
    final byRole = overview['usersByRole'] as Map<String, dynamic>? ?? {};
    final totalUsers = overview['totalUsers'] ?? 0;

    return Row(children: [
      Expanded(child: _bigStatCard(
        '${overview['totalFactories'] ?? 0}',
        'Zavodlar',
        '$activeFactories faol, $inactiveFactories nofaol',
        Icons.factory,
        const Color(0xFF0D47A1),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FactoriesScreen())).then((_) => _load()),
      )),
      const SizedBox(width: 12),
      Expanded(child: _bigStatCard(
        '$totalUsers',
        'Foydalanuvchilar',
        '${byRole['admin'] ?? 0} admin, ${byRole['employee'] ?? 0} xodim',
        Icons.people,
        const Color(0xFF00897B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())).then((_) => _load()),
      )),
    ]);
  }

  Widget _bigStatCard(String value, String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ]),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
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

    return _card('Umumiy ishlab chiqarish trendi (6 oy)', Icons.trending_up,
      SizedBox(
        height: 160,
        child: LineChart(LineChartData(
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
            color: const Color(0xFF0D47A1), barWidth: 3,
            belowBarData: BarAreaData(show: true, color: const Color(0xFF0D47A1).withValues(alpha: 0.1)),
            dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                FlDotCirclePainter(radius: 4, color: const Color(0xFF0D47A1), strokeWidth: 2, strokeColor: Colors.white)),
          )],
        )),
      ),
    );
  }

  Widget _buildFactoriesList() {
    final factories = (_data['factories'] as List?) ?? [];
    return _card('Zavodlar holati', Icons.factory,
      Column(children: [
        ...factories.map((f) {
          final isActive = f['isActive'] ?? true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF0D47A1).withValues(alpha: 0.04) : Colors.red.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isActive ? const Color(0xFF0D47A1).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.factory, color: isActive ? const Color(0xFF0D47A1) : Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${f['userCount']} xodim • ${f['materialCount']} material',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isActive ? 'Faol' : 'Nofaol',
                      style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FactoryDetailScreen(factory: Map.from(f)))),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0D47A1)),
                  ),
                ),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FactoriesScreen())).then((_) => _load()),
            icon: const Icon(Icons.add_business, size: 16),
            label: const Text('Barcha zavodlarni boshqarish'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D47A1)),
          ),
        ),
      ]),
    );
  }

  Widget _buildUserRoles() {
    final overview = _data['overview'] as Map<String, dynamic>? ?? {};
    final byRole = overview['usersByRole'] as Map<String, dynamic>? ?? {};
    final superAdmins = (byRole['super_admin'] as int?) ?? 0;
    final admins = (byRole['admin'] as int?) ?? 0;
    final employees = (byRole['employee'] as int?) ?? 0;
    final total = superAdmins + admins + employees;

    return _card('Foydalanuvchilar taqsimoti', Icons.people_alt,
      Column(children: [
        _roleRow('Super Admin', superAdmins, total, const Color(0xFF0D47A1)),
        const SizedBox(height: 8),
        _roleRow('Zavod Admin', admins, total, const Color(0xFF00897B)),
        const SizedBox(height: 8),
        _roleRow('Xodim', employees, total, const Color(0xFF7B1FA2)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())).then((_) => _load()),
            icon: const Icon(Icons.manage_accounts, size: 16),
            label: const Text('Foydalanuvchilarni boshqarish'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00897B)),
          ),
        ),
      ]),
    );
  }

  Widget _roleRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 10,
        ),
      )),
      const SizedBox(width: 8),
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    ]);
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF0D47A1), size: 20),
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

  Widget _buildDrawer() {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF0D47A1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.white,
            child: Text((widget.user['username'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Text(widget.user['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('Super Administrator', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      ),
      _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
      _drawerItem(Icons.factory, 'Zavodlar', () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FactoriesScreen())).then((_) => _load());
      }),
      _drawerItem(Icons.people, 'Foydalanuvchilar', () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())).then((_) => _load());
      }),
      _drawerItem(Icons.notifications_active, 'Ogohlantirishlar', () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemAlertsScreen()));
      }),
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
      leading: Icon(icon, color: const Color(0xFF0D47A1)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
