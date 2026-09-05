import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/colors.dart';

class UserAccessScreen extends StatefulWidget {
  const UserAccessScreen({super.key, required this.userId, required this.username});

  final int userId;
  final String username;

  @override
  State<UserAccessScreen> createState() => _UserAccessScreenState();
}

class _UserAccessScreenState extends State<UserAccessScreen> {
  List<dynamic> _allWarehouses = [];
  List<dynamic> _allModules = [];
  Set<int> _grantedWarehouses = {};
  Set<String> _grantedModules = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final whResult = await FactoryHubApi.getWarehouses();
    final modResult = await FactoryHubApi.getAdminModules();
    final grantResult = await FactoryHubApi.getUserAccess(widget.userId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (whResult['error'] != null || modResult['error'] != null || grantResult['error'] != null) {
        _error = whResult['error'] ?? modResult['error'] ?? grantResult['error'];
      } else {
        _allWarehouses = whResult['warehouses'] ?? [];
        _allModules = modResult['modules'] ?? [];
        _grantedWarehouses = ((grantResult['warehouses'] ?? []) as List)
            .map((w) => (w['id'] as num).toInt())
            .toSet();
        _grantedModules = ((grantResult['modules'] ?? []) as List)
            .map((m) => m['module_key'].toString())
            .toSet();
      }
    });
  }

  Future<void> _toggleWarehouse(int warehouseId, bool grant) async {
    final previous = _grantedWarehouses.toSet();
    setState(() {
      if (grant) {
        _grantedWarehouses.add(warehouseId);
      } else {
        _grantedWarehouses.remove(warehouseId);
      }
    });
    final result = grant
        ? await FactoryHubApi.grantWarehouse(widget.userId, warehouseId)
        : await FactoryHubApi.revokeWarehouse(widget.userId, warehouseId);
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _grantedWarehouses = previous);
      _showSnack('Xatolik: ${result['error']}', isError: true);
    } else {
      _showSnack(grant ? 'Ombor biriktirildi' : 'Ombor ajratildi');
    }
  }

  Future<void> _toggleModule(String moduleKey, bool grant, String label) async {
    final previous = _grantedModules.toSet();
    setState(() {
      if (grant) {
        _grantedModules.add(moduleKey);
      } else {
        _grantedModules.remove(moduleKey);
      }
    });
    final result = grant
        ? await FactoryHubApi.grantModule(widget.userId, moduleKey)
        : await FactoryHubApi.revokeModule(widget.userId, moduleKey);
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _grantedModules = previous);
      _showSnack('Xatolik: ${result['error']}', isError: true);
    } else {
      _showSnack(grant ? "'$label' berildi" : "'$label' olib tashlandi");
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.statusCritical : AppColors.statusOk,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.username} — huquqlar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.statusCritical),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin va Direktor rollari barcha omborlar va modullarga avtomatik to\'liq kirishga ega. Quyidagi sozlamalar boshqa rollar uchun qo\'llanadi.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'OMBORLAR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    if (_allWarehouses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Omborlar topilmadi', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ..._allWarehouses.map<Widget>((w) => CheckboxListTile(
                            value: _grantedWarehouses.contains(w['id']),
                            title: Text(w['name'] ?? ''),
                            subtitle: Text('${w['type'] ?? ''}', style: const TextStyle(fontSize: 11)),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            onChanged: (v) => _toggleWarehouse(w['id'], v == true),
                          )),
                    const SizedBox(height: 16),
                    Text(
                      'MODULLAR',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    ..._allModules.map<Widget>((m) => CheckboxListTile(
                          value: _grantedModules.contains(m['module_key']),
                          title: Text(m['name_uz'] ?? m['module_key'] ?? ''),
                          subtitle: Text(
                            (m['category'] ?? '') == 'admin' ? 'Admin toifasi' : 'Umumiy',
                            style: const TextStyle(fontSize: 11),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          onChanged: (v) =>
                              _toggleModule(m['module_key'].toString(), v == true, m['name_uz']?.toString() ?? m['module_key'].toString()),
                        )),
                  ],
                ),
    );
  }
}