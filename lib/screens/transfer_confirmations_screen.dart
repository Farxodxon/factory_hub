import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class TransferConfirmationsScreen extends StatefulWidget {
  const TransferConfirmationsScreen({super.key});

  @override
  State<TransferConfirmationsScreen> createState() =>
      _TransferConfirmationsScreenState();
}

class _TransferConfirmationsScreenState extends State<TransferConfirmationsScreen> {
  List<dynamic> _warehouses = [];
  List<dynamic> _transfers = [];
  int? _selectedWh;
  bool _loading = true;
  bool _loadingList = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  List<dynamic> _filterToAccess(List<dynamic> all) {
    final access = FactoryHubApi.userAccess;
    if (access != null && !access.isFullAccess) {
      final ids = access.warehouses.map((w) => w.id).toSet();
      return all.where((w) => ids.contains(w['id'])).toList();
    }
    return all;
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final whResult = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    final whs = _filterToAccess((whResult['warehouses'] ?? []) as List<dynamic>);
    setState(() {
      _warehouses = whs;
      _selectedWh = whs.isNotEmpty ? whs.first['id'] as int : null;
      _loading = false;
    });
    if (_selectedWh != null) await _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    final whId = _selectedWh;
    if (whId == null) return;
    setState(() => _loadingList = true);
    final result = await FactoryHubApi.getPendingTransfers(warehouseId: whId);
    if (!mounted) return;
    setState(() {
      _loadingList = false;
      _transfers = result['transfers'] ?? [];
    });
  }

  Future<void> _confirm(Map<String, dynamic> t) async {
    final id = t['id'] as int;
    setState(() => _busy.add(id));
    final result = await FactoryHubApi.confirmTransfer(id);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (result['error'] != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result['error'])));
      return;
    }
    await _loadTransfers();
  }

  Future<void> _rejectPrompt(Map<String, dynamic> t) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rad etish sababi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Sabab',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Rad etish'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    final id = t['id'] as int;
    setState(() => _busy.add(id));
    final result = await FactoryHubApi.rejectTransfer(id, reason);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (result['error'] != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result['error'])));
      return;
    }
    await _loadTransfers();
  }

  @override
  Widget build(BuildContext context) {
    final canAct = FactoryHubApi.role.canTransactStock;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('Qabul tasdiqlash',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedWh,
                    items: _warehouses.map<DropdownMenuItem<int>>((w) =>
                        DropdownMenuItem(value: w['id'], child: Text(w['name']))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedWh = v);
                      _loadTransfers();
                    },
                    decoration: InputDecoration(
                      labelText: 'Qabul qiluvchi ombor',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loadingList
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadTransfers,
                          child: _transfers.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 40),
                                    Center(
                                      child: Text('Kutilayotgan o\'tkazmalar yo\'q',
                                          style: TextStyle(color: AppColors.textSecondary)),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _transfers.length,
                                  itemBuilder: (_, i) => _transferCard(_transfers[i], canAct),
                                ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _transferCard(Map<String, dynamic> t, bool canAct) {
    final id = t['id'] as int;
    final busy = _busy.contains(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t['itemName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text('${t['quantity']} ${t['unit'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Manba: ${t['sourceName'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (t['createdByName'] != null && '${t['createdByName']}'.isNotEmpty)
              Text('Yaratdi: ${t['createdByName']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (canAct) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _confirm(t),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Qabul qilish'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.statusOk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _rejectPrompt(t),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rad etish'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusCritical),
                    ),
                  ),
                ] else
                  const Text('Sizga tasdiqlash huquqi berilmagan',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}