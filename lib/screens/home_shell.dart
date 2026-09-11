import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/user_access.dart';
import '../responsive/responsive_navigation.dart';
import '../services/api_service.dart';
import 'alerts_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_home.dart';
import 'dealers_screen.dart';
import 'hr_screen.dart';
import 'inspection_screen.dart';
import 'login_screen.dart';
import 'mixing_screen.dart';
import 'packaging_screen.dart';
import 'plans_screen.dart';
import 'production_screen.dart';
import 'recipes_screen.dart';
import 'reports_screen.dart';
import 'supplier_orders_screen.dart';
import 'thresholds_screen.dart';
import 'users_screen.dart';
import 'warehouses_screen.dart';

Widget? moduleScreenFor(String key, ValueNotifier<int>? refreshNotifier) {
  switch (key) {
    case 'hr':
      return HrScreen(refreshNotifier: refreshNotifier);
    case 'production':
      return MixingScreen(refreshNotifier: refreshNotifier);
    case 'packaging':
      return PackagingScreen(refreshNotifier: refreshNotifier);
    case 'recipes':
      return RecipesScreen(refreshNotifier: refreshNotifier);
    case 'planning':
      return PlansScreen(refreshNotifier: refreshNotifier);
    case 'inspection':
      return InspectionScreen(refreshNotifier: refreshNotifier);
    case 'production_planning':
      return ProductionScreen(refreshNotifier: refreshNotifier);
    case 'supplier_orders':
      return SupplierOrdersScreen(refreshNotifier: refreshNotifier);
    case 'reports_general':
    case 'regime51_report':
      return ReportsScreen(refreshNotifier: refreshNotifier);
    case 'user_management':
      return UsersScreen(refreshNotifier: refreshNotifier);
    case 'admin_settings':
      return ThresholdsScreen(refreshNotifier: refreshNotifier);
  }
  return null;
}

IconData moduleIconFor(String key) {
  switch (key) {
    case 'hr':
      return Icons.badge;
    case 'production':
      return Icons.deck;
    case 'packaging':
      return Icons.inventory_2;
    case 'recipes':
      return Icons.menu_book;
    case 'planning':
      return Icons.assignment;
    case 'inspection':
      return Icons.fact_check;
    case 'production_planning':
      return Icons.assignment;
    case 'supplier_orders':
      return Icons.local_shipping;
    case 'reports_general':
      return Icons.bar_chart;
    case 'regime51_report':
      return Icons.description;
    case 'user_management':
      return Icons.people;
    case 'admin_settings':
      return Icons.tune;
  }
  return Icons.apps;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  late final List<_NavEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries();
  }

  List<_NavEntry> _buildEntries() {
    final role = FactoryHubApi.role;
    final access = FactoryHubApi.userAccess;

    // Modul/ombor asosidagi kirish: admin/director bo'lmaganlar
    // faqat biriktirilgan omborlar va modullarni ko'radi.
    if (access != null && !access.isFullAccess) {
      return _buildRestrictedEntries(access, role);
    }

    return _buildDefaultEntries(role);
  }

  List<_NavEntry> _buildRestrictedEntries(UserAccess access, String role) {
    final entries = <_NavEntry>[];
    var idx = 0;

    for (final w in access.warehouses) {
      entries.add(_NavEntry(
        NavItem(index: idx++, icon: Icons.warehouse, label: w.name.isEmpty ? 'Ombor' : w.name),
        WarehouseDetailScreen(id: w.id, key: ValueKey('wh_${w.id}')),
      ));
    }

    for (final m in access.modules) {
      // Admin toifasi modullari faqat admin (to'liq kirish) uchun mantiqli.
      if (m.category == 'admin' && !role.isAdmin) continue;
      final screen = moduleScreenFor(m.key, refreshNotifier);
      if (screen == null) continue;
      entries.add(_NavEntry(
        NavItem(index: idx++, icon: moduleIconFor(m.key), label: m.nameUz),
        screen,
      ));
    }

    if (entries.isEmpty) {
      return const [
        _NavEntry(
          NavItem(index: 0, icon: Icons.lock_outline, label: "Kirish yo'q"),
          _NoAccessScreen(),
        ),
      ];
    }

    return entries;
  }

  List<_NavEntry> _buildDefaultEntries(String role) {
    // HR boshqaruvchi faqat HR modulini ko'radi (ombor/ishlab chiqarish yashirin)
    if (role.isHrManager) {
      return [
        _NavEntry(const NavItem(index: 0, icon: Icons.dashboard, label: 'Bosh oyna'),
            DashboardHome(refreshNotifier: refreshNotifier)),
        _NavEntry(const NavItem(index: 1, icon: Icons.badge, label: 'Xodimlar'),
            HrScreen(refreshNotifier: refreshNotifier)),
        _NavEntry(const NavItem(index: 2, icon: Icons.notifications_active, label: 'Ogohlantirishlar'),
            AlertsScreen(refreshNotifier: refreshNotifier)),
      ];
    }

    final entries = <_NavEntry>[
      _NavEntry(const NavItem(index: 0, icon: Icons.dashboard, label: 'Bosh oyna'), DashboardHome(refreshNotifier: refreshNotifier)),
      _NavEntry(const NavItem(index: 1, icon: Icons.warehouse, label: 'Omborlar'), WarehousesScreen(refreshNotifier: refreshNotifier)),
      _NavEntry(const NavItem(index: 2, icon: Icons.category, label: 'Katalog'), CatalogScreen(refreshNotifier: refreshNotifier)),
    ];

    if (!role.isDirector) {
      entries.add(_NavEntry(const NavItem(index: 3, icon: Icons.assignment, label: 'Rejalar'), PlansScreen(refreshNotifier: refreshNotifier)));
      entries.add(_NavEntry(const NavItem(index: 4, icon: Icons.deck, label: 'Aralashtirish'), MixingScreen(refreshNotifier: refreshNotifier)));
      entries.add(_NavEntry(const NavItem(index: 5, icon: Icons.inventory_2, label: 'Qadoqlash'), PackagingScreen(refreshNotifier: refreshNotifier)));
      entries.add(_NavEntry(const NavItem(index: 6, icon: Icons.menu_book, label: 'Retseptlar'), RecipesScreen(refreshNotifier: refreshNotifier)));
      entries.add(_NavEntry(const NavItem(index: 7, icon: Icons.fact_check, label: 'Tekshiruv'), InspectionScreen(refreshNotifier: refreshNotifier)));
    }
    if (role.canControlWarehouses) {
      entries.add(_NavEntry(const NavItem(index: 8, icon: Icons.local_shipping, label: "Ta'minotchi buyurtmalari"), SupplierOrdersScreen(refreshNotifier: refreshNotifier)));
    }
    if (role.canControlWarehouses || role.isOpsManager || role.isDirector) {
      entries.add(_NavEntry(NavItem(index: entries.length, icon: Icons.storefront, label: 'Dillerlar'), DealersScreen(refreshNotifier: refreshNotifier)));
    }

    entries.add(_NavEntry(const NavItem(index: 9, icon: Icons.bar_chart, label: 'Hisobotlar'), ReportsScreen(refreshNotifier: refreshNotifier)));
    entries.add(_NavEntry(const NavItem(index: 10, icon: Icons.notifications_active, label: 'Ogohlantirishlar'), AlertsScreen(refreshNotifier: refreshNotifier)));

    if (role.canManageThresholds) {
      entries.add(_NavEntry(const NavItem(index: 11, icon: Icons.tune, label: 'Kritik darajalar'), ThresholdsScreen(refreshNotifier: refreshNotifier)));
    }
    if (role.canManageUsers) {
      entries.add(_NavEntry(const NavItem(index: 12, icon: Icons.people, label: 'Foydalanuvchilar'), UsersScreen(refreshNotifier: refreshNotifier)));
    }
    if (role.canViewHr) {
      entries.add(_NavEntry(NavItem(index: entries.length, icon: Icons.badge, label: 'Xodimlar'), HrScreen(refreshNotifier: refreshNotifier)));
    }

    return entries;
  }

  void _onNavSelected(int displayIndex) {
    if (displayIndex < _entries.length) {
      setState(() => _selectedIndex = displayIndex);
      refreshNotifier.value++;
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

class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sizga hali hech qanday bo\'lim biriktirilmagan. Administratorga murojaat qiling.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  final NavItem navItem;
  final Widget screen;
  const _NavEntry(this.navItem, this.screen);
}