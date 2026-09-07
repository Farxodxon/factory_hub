import 'package:flutter/material.dart';

import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Widget _refreshButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Yangilash'),
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getAlerts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = result['error'] == null ? result : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return const Center(child: Text("Ma'lumot olinmadi"));
    }

    final lowStock = _data!['lowStock'] as List<dynamic>? ?? [];
    final lateOrders = _data!['lateSupplierOrders'] as List<dynamic>? ?? [];
    final overduePlans = _data!['overduePlans'] as List<dynamic>? ?? [];
    final isDesktop = AppBreakpoints.isDesktop(context);

    if (lowStock.isEmpty && lateOrders.isEmpty && overduePlans.isEmpty) {
      return Column(
        children: [
          _refreshButton(),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.statusOk),
                  SizedBox(height: 12),
                  Text('Hamma narsa tartibda', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _refreshButton(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: isDesktop
                ? _buildDesktopLayout(lowStock, lateOrders, overduePlans)
                : _buildMobileLayout(lowStock, lateOrders, overduePlans),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<dynamic> lowStock, List<dynamic> lateOrders, List<dynamic> overduePlans) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (lowStock.isNotEmpty) ...[
          _sectionTitle('Kam qoldiq (${lowStock.length})', AppColors.statusWarning),
          ...lowStock.map((a) => Card(
                color: AppColors.statusWarning.withValues(alpha: 0.08),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.inventory, color: AppColors.statusWarning),
                  title: Text(a['name'] ?? ''),
                  trailing: Text('${a['balance']} < ${a['minQty']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
        ],
        if (lateOrders.isNotEmpty) ...[
          _sectionTitle("Kechikkan buyurtmalar (${lateOrders.length})", AppColors.statusCritical),
          ...lateOrders.map((a) => Card(
                color: AppColors.statusCritical.withValues(alpha: 0.08),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping, color: AppColors.statusCritical),
                  title: Text('${a['materialName'] ?? ''} — ${a['supplierName'] ?? ''}'),
                  subtitle: Text('Kutilgan sana: ${a['expectedAt']?.toString().substring(0, 10)}'),
                  trailing: Text('+${a['daysLate']} kun',
                      style: const TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.bold)),
                ),
              )),
        ],
        if (overduePlans.isNotEmpty) ...[
          _sectionTitle('Muddati o\'tgan rejalar (${overduePlans.length})', AppColors.statusWarning),
          ...overduePlans.map((a) => Card(
                color: AppColors.statusWarning.withValues(alpha: 0.08),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.assignment_late, color: AppColors.statusWarning),
                  title: Text(a['title'] ?? ''),
                  trailing: Text('Qoldi: ${a['remaining']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(List<dynamic> lowStock, List<dynamic> lateOrders, List<dynamic> overduePlans) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lowStock.isNotEmpty)
            Expanded(
              child: _AlertSection(
                title: 'Kam qoldiq (${lowStock.length})',
                color: AppColors.statusWarning,
                icon: Icons.inventory,
                items: lowStock,
                itemBuilder: (a) => ListTile(
                  title: Text(a['name'] ?? ''),
                  trailing: Text('${a['balance']} < ${a['minQty']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          if (lowStock.isNotEmpty && lateOrders.isNotEmpty) const SizedBox(width: 16),
          if (lateOrders.isNotEmpty)
            Expanded(
              child: _AlertSection(
                title: "Kechikkan buyurtmalar (${lateOrders.length})",
                color: AppColors.statusCritical,
                icon: Icons.local_shipping,
                items: lateOrders,
                itemBuilder: (a) => ListTile(
                  title: Text('${a['materialName'] ?? ''} — ${a['supplierName'] ?? ''}'),
                  subtitle: Text('Kutilgan: ${a['expectedAt']?.toString().substring(0, 10)}'),
                  trailing: Text('+${a['daysLate']} kun',
                      style: const TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          if (lateOrders.isNotEmpty && overduePlans.isNotEmpty) const SizedBox(width: 16),
          if (overduePlans.isNotEmpty)
            Expanded(
              child: _AlertSection(
                title: 'Muddati o\'tgan rejalar (${overduePlans.length})',
                color: AppColors.statusWarning,
                icon: Icons.assignment_late,
                items: overduePlans,
                itemBuilder: (a) => ListTile(
                  title: Text(a['title'] ?? ''),
                  trailing: Text('Qoldi: ${a['remaining']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      );
}

class _AlertSection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<dynamic> items;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _AlertSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                ),
              ],
            ),
            const Divider(),
            ...items.map((a) => itemBuilder(a as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }
}
