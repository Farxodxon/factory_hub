import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class SupplierOrdersScreen extends StatefulWidget {
  const SupplierOrdersScreen({super.key});

  @override
  State<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends State<SupplierOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getSupplierOrders();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _orders = result['orders'] ?? [];
    });
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateOrderSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Buyurtma'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _orders.length,
                itemBuilder: (_, i) {
                  final o = _orders[i];
                  final isLate = o['isLate'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isLate ? Colors.red.shade50 : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.local_shipping,
                        color: isLate ? Colors.red : const Color(0xFF1565C0),
                      ),
                      title: Text(o['materialName'] ?? '?'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['supplierName'] ?? ''),
                          Text('${o['qty']} ${o['unit']}'),
                          if (o['expectedAt'] != null)
                            Text("Kutilgan: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(o['expectedAt']))}"),
                        ],
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(_statusLabel(o['status']),
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: isLate ? Colors.red.shade200 : Colors.blue.shade50,
                          ),
                          if (FactoryHubApi.role.canControlWarehouses && o['status'] != 'received')
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                await FactoryHubApi.updateSupplierOrderStatus(o['id'], s);
                                _load();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'in_transit', child: Text("Yo'lda")),
                                PopupMenuItem(value: 'received', child: Text('Qabul qilindi')),
                                PopupMenuItem(value: 'cancelled', child: Text('Bekor qilish')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'ordered':
        return 'Buyurtma';
      case 'in_transit':
        return "Yo'lda";
      case 'received':
        return 'Qabul';
      case 'cancelled':
        return 'Bekor';
    }
    return s ?? '';
  }
}

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet();

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _supplier = TextEditingController();
  final _qty = TextEditingController();
  DateTime? _expected;
  List<dynamic> _materials = [];
  Map<String, dynamic>? _selectedMaterial;
  String? _error;
  bool _loadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final result = await FactoryHubApi.getRawMaterials();
    if (!mounted) return;
    setState(() {
      _loadingMaterials = false;
      _materials = result['rawMaterials'] ?? [];
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.replaceAll(',', '.'));
    if (_supplier.text.trim().isEmpty ||
        _selectedMaterial == null ||
        qty == null ||
        qty <= 0) {
      setState(() => _error = "Yetkazib beruvchi, material va miqdor majburiy");
      return;
    }

    final result = await FactoryHubApi.createSupplierOrder({
      'supplier_name': _supplier.text.trim(),
      'raw_material_id': int.tryParse(_selectedMaterial!['id'].toString()),
      'qty': qty,
      'expected_at': _expected?.toIso8601String().substring(0, 10),
    });
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Ta'minot buyurtmasi",
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _supplier,
              decoration: InputDecoration(
                labelText: "Yetkazib beruvchi nomi",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _loadingMaterials
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedMaterial,
                    isExpanded: true,
                    items: _materials.cast<Map<String, dynamic>>().map((m) {
                      return DropdownMenuItem(value: m, child: Text(m['name'] ?? ''));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedMaterial = v),
                    decoration: InputDecoration(
                      labelText: 'Xom ashyo',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Miqdor (kg)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _expected = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _expected == null
                    ? 'Kutilgan sana'
                    : "Kutilgan: ${DateFormat('dd.MM.yyyy').format(_expected!)}",
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}

