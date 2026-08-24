import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import 'alerts_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_home.dart';
import 'login_screen.dart';
import 'plans_screen.dart';
import 'production_screen.dart';
import 'reports_screen.dart';
import 'supplier_orders_screen.dart';
import 'thresholds_screen.dart';
import 'users_screen.dart';
import 'warehouses_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  String get _role => FactoryHubApi.role;

  List<Widget> get _screens => [
        const DashboardHome(),
        const WarehousesScreen(),
        const CatalogScreen(),
        const PlansScreen(),
        const ProductionScreen(),
        const SupplierOrdersScreen(),
        const ReportsScreen(),
        const AlertsScreen(),
        if (_role.canManageThresholds) const ThresholdsScreen(),
        if (_role.canManageUsers) const UsersScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    if (_index >= screens.length) _index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(_index)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(FactoryHubApi.username),
              accountEmail: Text(_role.label),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.precision_manufacturing, color: const Color(0xFF1565C0)),
              ),
              decoration: const BoxDecoration(color: Color(0xFF1565C0)),
            ),
            _item(0, Icons.dashboard, 'Bosh oyna'),
            _item(1, Icons.warehouse, 'Omborlar'),
            _item(2, Icons.category, 'Katalog'),
            if (!_role.isDirector) _item(3, Icons.assignment, 'Rejalar'),
            if (!_role.isDirector) _item(4, Icons.factory, 'Ishlab chiqarish'),
            if (_role.canControlWarehouses)
              _item(5, Icons.local_shipping, "Ta'minotchi buyurtmalari"),
            _item(6, Icons.bar_chart, 'Hisobotlar'),
            _item(7, Icons.notifications_active, 'Ogohlantirishlar'),
            if (_role.canManageThresholds)
              _item(8, Icons.tune, 'Kritik darajalar'),
            if (_role.canManageUsers) _item(9, Icons.people, 'Foydalanuvchilar'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Chiqish'),
              onTap: () async {
                await FactoryHubApi.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: screens),
    );
  }

  Widget _item(int i, IconData icon, String label) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        selected: _index == i,
        onTap: () {
          setState(() => _index = i);
          Navigator.pop(context);
        },
      );

  String _titleFor(int i) => [
        'Bosh oyna',
        'Omborlar',
        'Katalog',
        'Rejalar',
        'Ishlab chiqarish',
        "Ta'minotchi buyurtmalari",
        'Hisobotlar',
        'Ogohlantirishlar',
        'Kritik darajalar',
        'Foydalanuvchilar'
      ][i];
}
