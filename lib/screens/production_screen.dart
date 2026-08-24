import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<dynamic> _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getBatches();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _batches = result['batches'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FactoryHubApi.role.canPlan
          ? FloatingActionButton.extended(
              heroTag: 'fab_production',
              onPressed: () async {
                final started = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _StartBatchSheet(),
                );
                if (started == true) _load();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Partiya'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _batches.length,
                itemBuilder: (_, i) {
                  final b = _batches[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(b['productName'] ?? b['barcode'] ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Reja: ${b['plannedQty']} dona'),
                      trailing: _statusChip(b['status']),
                      onTap: b['status'] == 'in_progress' && FactoryHubApi.role.canPlan
                          ? () => _completeDialog(b)
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
      case 'cancelled':
        color = Colors.red;
      default:
        color = Colors.orange;
    }
    return Chip(label: Text(status ?? '', style: const TextStyle(fontSize: 11)),
        backgroundColor: color.withValues(alpha: 0.2));
  }

  Future<void> _completeDialog(Map<String, dynamic> batch) async {
    final qtyCtrl = TextEditingController(text: batch['plannedQty'].toString());
    final warehouses = await FactoryHubApi.getWarehouses();
    if (!mounted) return;

    List<dynamic> finishedWarehouses =
        ((warehouses['warehouses'] ?? []) as List<dynamic>)
            .where((w) => w['type'] == 'finished')
            .toList();

    int? selectedId = finishedWarehouses.isNotEmpty ? finishedWarehouses.first['id'] : null;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Partiyani yakunlash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ishlab chiqarildi (dona)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
              initialValue: selectedId,
                items: finishedWarehouses.map((w) {
                  return DropdownMenuItem(value: w['id'] as int, child: Text(w['name']));
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedId = v),
                decoration: const InputDecoration(labelText: 'Qabul qiluvchi ombor'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Bekor qilish')),
            ElevatedButton(
              onPressed: selectedId == null ? null : () => Navigator.pop(ctx, 'complete'),
              child: const Text('Yakunlash'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (!mounted) return;

    final result = await FactoryHubApi.updateBatch(batch['id'], {
      'action': action,
      if (action == 'complete') ...{
        'produced_qty': int.tryParse(qtyCtrl.text),
        'finished_warehouse_id': selectedId,
      },
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? result['message'] ?? '')));
    _load();
  }
}

class _StartBatchSheet extends StatefulWidget {
  const _StartBatchSheet();

  @override
  State<_StartBatchSheet> createState() => _StartBatchSheetState();
}

class _StartBatchSheetState extends State<_StartBatchSheet> {
  final _qty = TextEditingController();
  List<dynamic> _products = [];
  List<dynamic> _rawWarehouses = [];
  Map<String, dynamic>? _selectedProduct;
  int? _rawWarehouseId;
  List<dynamic>? _norms;
  String? _error;
  bool _loadingProducts = true;
  double? _maxPossible;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final productsResult = await FactoryHubApi.getProducts();
    final warehousesResult = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    setState(() {
      _products = productsResult['products'] ?? [];
      _rawWarehouses = ((warehousesResult['warehouses'] ?? []) as List<dynamic>)
          .where((w) => w['type'] == 'raw')
          .toList();
      _rawWarehouseId = _rawWarehouses.isNotEmpty ? _rawWarehouses.first['id'] as int : null;
      _loadingProducts = false;
    });
  }

  Future<void> _selectProduct(String barcode) async {
    final normsResult = await FactoryHubApi.getNorms(barcode);
    if (!mounted) return;
    setState(() {
      _norms = normsResult['norms'] ?? [];
      _maxPossible = _calcMax();
    });
  }

  double? _calcMax() {
    final norms = _norms;
    if (norms == null || norms.isEmpty) return null;
    double min = double.infinity;
    for (final n in norms) {
      final grams = double.tryParse(n['gramsPerUnit']?.toString() ?? '') ?? 0;
      if (grams <= 0) continue;
      final stock = double.tryParse(n['totalStock']?.toString() ?? '') ?? 0;
      min = (stock * 1000 / grams) < min ? stock * 1000 / grams : min;
    }
    return min.isFinite ? min.floorToDouble() : null;
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text);
    if (_selectedProduct == null || qty == null || qty <= 0 || _rawWarehouseId == null) {
      setState(() => _error = 'Mahsulot, miqdor va ombor tanlanishi kerak');
      return;
    }
    // Tayyor mahsulot ombori — finished turdagi birinchisi
    final whResult = await FactoryHubApi.getWarehouses();
    final allWh = (whResult['warehouses'] ?? []) as List<dynamic>;
    final finished = allWh.where((w) => w['type'] == 'finished').toList();
    if (finished.isEmpty) {
      setState(() => _error = 'Tayyor mahsulot ombori topilmadi');
      return;
    }

    final result = await FactoryHubApi.startProduction({
      'barcode': _selectedProduct!['barcode'],
      'qty': qty,
      'raw_warehouse_id': _rawWarehouseId,
      'finished_warehouse_id': finished.first['id'],
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
            Text("Yangi partiya", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (p) => p['name'] ?? '',
                    optionsBuilder: (v) => (_products.cast<Map<String, dynamic>>())
                        .where((p) =>
                            (p['name'] as String?)?.toLowerCase().contains(v.text.toLowerCase()) ?? false)
                        .take(20),
                    onSelected: (p) {
                      setState(() => _selectedProduct = p);
                      _selectProduct(p['barcode']);
                    },
                    fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
                      controller: ctrl,
                      focusNode: focus,
                      onSubmitted: (_) => onSubmit(),
                      decoration: InputDecoration(
                        labelText: 'Mahsulot qidirish',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
            if (_selectedProduct != null && _norms != null) ...[
              const SizedBox(height: 8),
              if (_norms!.isEmpty)
                const Text("Bu mahsulot uchun norma topilmadi", style: TextStyle(color: Colors.red))
              else ...[
                Text('Normalar (${_norms!.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                ..._norms!.map((n) => Text(
                    '- ${n['name']}: ${n['gramsPerUnit']} g/dona (qoldiq: ${n['totalStock']} kg)',
                    style: const TextStyle(fontSize: 11))),
                if (_maxPossible != null)
                  Text('Eng ko\'pi bilan $_maxPossible dona ishlab chiqarish mumkin',
                      style: const TextStyle(color: Colors.green)),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Miqdor (dona)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _rawWarehouseId,
              items: _rawWarehouses.map((w) {
                return DropdownMenuItem(value: w['id'] as int, child: Text(w['name']));
              }).toList(),
              onChanged: (v) => setState(() => _rawWarehouseId = v),
              decoration: const InputDecoration(labelText: 'Xom ashyo ombori'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Boshlash')),
          ],
        ),
      ),
    );
  }
}

