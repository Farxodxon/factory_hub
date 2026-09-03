import 'package:flutter/material.dart';

import '../responsive/app_breakpoints.dart';
import '../responsive/responsive_layout.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _data = result;
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      );
    }

    final stats = _data?['stats'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdaptiveGrid(
            childAspectRatio: AppBreakpoints.isDesktop(context) ? 2.0 : 1.3,
            children: [
              _StatCard(icon: Icons.people, label: 'Faol xodimlar', value: stats['activeUsers']),
              _StatCard(icon: Icons.warehouse, label: 'Omborlar', value: stats['activeWarehouses']),
              _StatCard(icon: Icons.assignment, label: 'Ochiq rejalar', value: stats['openPlans']),
              _StatCard(icon: Icons.factory, label: 'Jarayondagi partiyalar', value: stats['batchesInProgress']),
              _StatCard(icon: Icons.local_shipping, label: "Ta'minot buyurtmalari", value: stats['pendingSupplierOrders']),
              _StatCard(icon: Icons.inventory_2, label: 'Mahsulotlar', value: stats['totalProducts']),
              _StatCard(icon: Icons.science, label: 'Xom ashyolar', value: stats['totalRawMaterials']),
              _StatCard(icon: Icons.handshake, label: 'Hamkorlar', value: stats['activePartners']),
            ],
          ),
          const SizedBox(height: 16),
          if ((stats['batchesInProgress'] ?? 0) > 0 || (_data?['lowStockCount'] ?? 0) > 0)
            Card(
              color: AppColors.statusWarning.withValues(alpha: 0.1),
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: AppColors.statusWarning),
                title: Text("Kam qoldiq: ${_data?['lowStockCount']} ta element"),
                subtitle: const Text('Ogohlantirishlar bo\'limida batafsil'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: isDesktop ? 22 : 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: isDesktop ? AppTypography.body : AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${value ?? 0}',
              style: isDesktop ? AppTypography.statBigDesktop : AppTypography.statBig,
            ),
          ],
        ),
      ),
    );
  }
}
