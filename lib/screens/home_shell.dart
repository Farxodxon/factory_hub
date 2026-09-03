import 'package:flutter/material.dart';

import '../models/user.dart';
import '../responsive/responsive_navigation.dart';
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
  int _selectedIndex = 0;

  late final List<_NavEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries();
  }

  List<_NavEntry> _buildEntries() {
    final role = FactoryHubApi.role;
    final entries = <_NavEntry>[
      _NavEntry(const NavItem(index: 0, icon: Icons.dashboard, label: 'Bosh oyna'), const DashboardHome()),
      _NavEntry(const NavItem(index: 1, icon: Icons.warehouse, label: 'Omborlar'), const WarehousesScreen()),
      _NavEntry(const NavItem(index: 2, icon: Icons.category, label: 'Katalog'), const CatalogScreen()),
    ];

    if (!role.isDirector) {
      entries.add(_NavEntry(const NavItem(index: 3, icon: Icons.assignment, label: 'Rejalar'), const PlansScreen()));
      entries.add(_NavEntry(const NavItem(index: 4, icon: Icons.factory, label: 'Ishlab chiqarish'), const ProductionScreen()));
    }
    if (role.canControlWarehouses) {
      entries.add(_NavEntry(const NavItem(index: 5, icon: Icons.local_shipping, label: "Ta'minotchi buyurtmalari"), const SupplierOrdersScreen()));
    }

    entries.add(_NavEntry(const NavItem(index: 6, icon: Icons.bar_chart, label: 'Hisobotlar'), const ReportsScreen()));
    entries.add(_NavEntry(const NavItem(index: 7, icon: Icons.notifications_active, label: 'Ogohlantirishlar'), const AlertsScreen()));

    if (role.canManageThresholds) {
      entries.add(_NavEntry(const NavItem(index: 8, icon: Icons.tune, label: 'Kritik darajalar'), const ThresholdsScreen()));
    }
    if (role.canManageUsers) {
      entries.add(_NavEntry(const NavItem(index: 9, icon: Icons.people, label: 'Foydalanuvchilar'), const UsersScreen()));
    }

    return entries;
  }

  void _onNavSelected(int displayIndex) {
    if (displayIndex < _entries.length) {
      setState(() => _selectedIndex = displayIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex >= _entries.length) _selectedIndex = 0;

    return AdaptiveNavigation(
      selectedIndex: _selectedIndex,
      onSelected: _onNavSelected,
      items: _entries.map((e) => e.navItem).toList(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _entries.map((e) => e.screen).toList(),
      ),
      username: FactoryHubApi.username,
      roleLabel: FactoryHubApi.role.label,
      onLogout: () async {
        await FactoryHubApi.logout();
        if (!mounted) return;
        final ctx = context;
        if (!ctx.mounted) return;
        Navigator.pushReplacement(
          ctx,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
    );
  }
}

class _NavEntry {
  final NavItem navItem;
  final Widget screen;
  const _NavEntry(this.navItem, this.screen);
}
