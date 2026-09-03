import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_breakpoints.dart';

class NavItem {
  final int index;
  final IconData icon;
  final String label;
  final bool visible;

  const NavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.visible = true,
  });
}

class AdaptiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;
  final Widget body;
  final String username;
  final String roleLabel;
  final VoidCallback onLogout;

  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.body,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((i) => i.visible).toList();

    if (AppBreakpoints.isDesktop(context)) {
      return _DesktopLayout(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        items: visibleItems,
        body: body,
        username: username,
        roleLabel: roleLabel,
        onLogout: onLogout,
      );
    }
    if (AppBreakpoints.isTablet(context)) {
      return _TabletLayout(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        items: visibleItems,
        body: body,
      );
    }
    return _MobileLayout(
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      items: visibleItems,
      body: body,
      username: username,
      roleLabel: roleLabel,
      onLogout: onLogout,
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;
  final Widget body;
  final String username;
  final String roleLabel;
  final VoidCallback onLogout;

  const _MobileLayout({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.body,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(items.firstWhere((i) => i.index == selectedIndex).label),
      ),
      drawer: _buildDrawer(context),
      body: body,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(username),
            accountEmail: Text(roleLabel),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.precision_manufacturing, color: AppColors.primary),
            ),
            decoration: const BoxDecoration(color: AppColors.primary),
          ),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: item.index == selectedIndex,
              onTap: () {
                onSelected(item.index);
                Navigator.pop(context);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Chiqish'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;
  final Widget body;

  const _TabletLayout({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surface,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontSize: 11),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
            unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryBg,
                child: Icon(Icons.precision_manufacturing, color: AppColors.primary),
              ),
            ),
            destinations: items
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon),
                      label: Text(item.label, style: AppTypography.navLabel),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;
  final Widget body;
  final String username;
  final String roleLabel;
  final VoidCallback onLogout;

  const _DesktopLayout({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.body,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            items: items,
            username: username,
            roleLabel: roleLabel,
            onLogout: onLogout,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavItem> items;
  final String username;
  final String roleLabel;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.surface,
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: AppColors.primary,
            child: Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FactoryHub', style: AppTypography.appBarTitle),
                      Text(
                        '$username · $roleLabel',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: ListTile(
                      leading: Icon(
                        item.icon,
                        color: item.index == selectedIndex ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: item.index == selectedIndex ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: item.index == selectedIndex ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      dense: true,
                      selected: item.index == selectedIndex,
                      selectedTileColor: AppColors.primaryBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () => onSelected(item.index),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.logout, size: 22),
              title: const Text('Chiqish', style: TextStyle(fontSize: 14)),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
