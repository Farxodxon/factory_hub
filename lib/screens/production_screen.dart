import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

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
      body: Column(
        children: [
          if (FactoryHubApi.role.canPlan)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: () async {
                    final started = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _BomBatchSheet(),
                    );
                    if (started == true) _load();
                  },
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Retsept bo\'yicha ishlab chiqarish (BOM)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
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
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    switch (status) {
      case 'completed':
        color = AppColors.statusOk;
      case 'cancelled':
        color = AppColors.statusCritical;
      default:
        color = AppColors.statusWarning;
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
  bool _loadingNorms = false;
  double? _maxPossible;
  bool _normsExpanded = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
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

  Future<void> _selectProduct(Map<String, dynamic> product) async {
    setState(() {
      _loadingNorms = true;
      _norms = null;
      _maxPossible = null;
      _normsExpanded = true;
    });
    final normsResult = await FactoryHubApi.getNorms(product['barcode']);
    if (!mounted) return;
    final norms = normsResult['norms'] ?? [];
    setState(() {
      _loadingNorms = false;
      _norms = norms;
      _maxPossible = _calcMax();
      if (_maxPossible != null && _maxPossible! > 0) {
        _qty.text = _maxPossible!.toInt().toString();
      }
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
      final possible = stock * 1000 / grams;
      if (possible < min) min = possible;
    }
    return min.isFinite ? min.floorToDouble() : null;
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text);
    if (_selectedProduct == null || qty == null || qty <= 0 || _rawWarehouseId == null) {
      setState(() => _error = 'Mahsulot, miqdor va ombor tanlanishi kerak');
      return;
    }

    if (_maxPossible != null && qty > _maxPossible!.toInt()) {
      setState(() => _error = "Miqdor maksimal dan ko'p (${_maxPossible!.toInt()})");
      return;
    }

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

  int get _okCount {
    if (_norms == null || _norms!.isEmpty) return 0;
    return _norms!.where((n) {
      final grams = double.tryParse(n['gramsPerUnit']?.toString() ?? '') ?? 0;
      final stock = double.tryParse(n['totalStock']?.toString() ?? '') ?? 0;
      return grams <= 0 || stock >= grams / 1000;
    }).length;
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
            const SizedBox(height: 16),

            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (p) => p['name'] ?? '',
                    optionsBuilder: (v) => (_products.cast<Map<String, dynamic>>())
                        .where((p) => (p['name'] as String?)?.toLowerCase().contains(v.text.toLowerCase()) ?? false)
                        .take(20),
                    onSelected: (p) {
                      setState(() => _selectedProduct = p);
                      _selectProduct(p);
                    },
                    fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
                      controller: ctrl,
                      focusNode: focus,
                      onSubmitted: (_) => onSubmit(),
                      decoration: InputDecoration(
                        labelText: 'Mahsulot qidirish',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

            if (_loadingNorms) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_selectedProduct != null && !_loadingNorms) ...[
              const SizedBox(height: 12),
              _buildNormsSection(),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Miqdor (dona)',
                hintText: _maxPossible != null ? 'Max: ${_maxPossible!.toInt()}' : null,
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
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Boshlash')),
          ],
        ),
      ),
    );
  }

  Widget _buildNormsSection() {
    if (_norms == null || _norms!.isEmpty) {
      return Card(
        color: AppColors.statusWarning.withValues(alpha: 0.1),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.statusWarning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Normalar topilmadi. Davom ettirishingiz mumkin.",
                  style: TextStyle(fontSize: 13, color: AppColors.statusWarning),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = _norms!.length;
    final allOk = _okCount == total;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _normsExpanded = !_normsExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    allOk ? Icons.check_circle : Icons.warning_amber,
                    size: 20,
                    color: allOk ? AppColors.statusOk : AppColors.statusWarning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Normalar: $_okCount/$total yetarli',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  if (_maxPossible != null && _maxPossible! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Max ${_maxPossible!.toInt()} dona',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(_normsExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          if (_normsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: _norms!.map((n) => _buildNormRow(n)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNormRow(Map<String, dynamic> n) {
    final grams = double.tryParse(n['gramsPerUnit']?.toString() ?? '') ?? 0;
    final stock = double.tryParse(n['totalStock']?.toString() ?? '') ?? 0;
    final neededPerUnit = grams / 1000;
    final hasEnough = neededPerUnit <= 0 || stock >= neededPerUnit;
    final name = n['name'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasEnough ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: hasEnough ? AppColors.statusOk : AppColors.statusCritical,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                Text(
                  '${neededPerUnit.toStringAsFixed(3)} kg/dona',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (hasEnough ? AppColors.statusOk : AppColors.statusCritical).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Zaxira: ${stock.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasEnough ? AppColors.statusOk : AppColors.statusCritical,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BomBatchSheet extends StatefulWidget {
  const _BomBatchSheet();

  @override
  State<_BomBatchSheet> createState() => _BomBatchSheetState();
}

class _BomBatchSheetState extends State<_BomBatchSheet> {
  List<dynamic> _boms = [];
  List<dynamic> _warehouses = [];

  int? _bomId;
  int _batches = 1;
  int? _sourceWhId;
  int? _destWhId;
  bool _loading = true;
  String? _error;
  List<dynamic> _shortages = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bomsResult = await FactoryHubApi.getBoms();
    final whResult = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    setState(() {
      _boms = bomsResult['boms'] ?? [];
      _warehouses = whResult['warehouses'] ?? [];
      _loading = false;
    });
  }

  String _stageLabel(String s) => s == 'mixing' ? 'Aralashtirish' : 'Qadoqlash';

  dynamic get _selectedBom {
    if (_bomId == null) return null;
    for (final b in _boms) {
      if (b['id'] == _bomId) return b;
    }
    return null;
  }

  List<dynamic> get _filteredSourceWarehouses {
    final bom = _selectedBom;
    if (bom == null) return _warehouses;
    final stage = bom['stage'] as String?;
    if (stage == 'mixing') {
      return _warehouses.where((w) =>
        w['type'] == 'raw' || w['type'] == 'purchased_semi' ||
        w['type'] == 'spare_parts' || w['type'] == 'production'
      ).toList();
    }
    if (stage == 'packaging') {
      return _warehouses.where((w) =>
        w['type'] == 'semi_finished' || w['type'] == 'packaging' ||
        w['type'] == 'purchased_semi' || w['type'] == 'raw'
      ).toList();
    }
    return _warehouses;
  }

  List<dynamic> get _filteredDestWarehouses {
    final bom = _selectedBom;
    if (bom == null) return _warehouses;
    final stage = bom['stage'] as String?;
    if (stage == 'mixing') {
      return _warehouses.where((w) =>
        w['type'] == 'semi_finished' || w['type'] == 'production'
      ).toList();
    }
    if (stage == 'packaging') {
      return _warehouses.where((w) =>
        w['type'] == 'finished' || w['type'] == 'sales'
      ).toList();
    }
    return _warehouses;
  }

  @override
  Widget build(BuildContext context) {
    final selectedBom = _selectedBom;

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
            Text("Retsept bo'yicha ishlab chiqarish",
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _bomId,
                        items: _boms.map<DropdownMenuItem<int>>((b) {
                          return DropdownMenuItem(
                            value: b['id'],
                            child: Text(
                                '${b['name']} (${_stageLabel('${b['stage']}')}) → ${b['outputName']}'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _bomId = v;
                            // BOM tanlanganda omborlarni avtomatik tanlash
                            final srcList = _filteredSourceWarehouses;
                            final dstList = _filteredDestWarehouses;
                            _sourceWhId = srcList.isNotEmpty ? srcList.first['id'] as int : null;
                            _destWhId = dstList.isNotEmpty ? dstList.first['id'] as int : null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Retsept',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height:12),
                      if (selectedBom != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Chiqish: ${selectedBom['outputName']} — ${selectedBom['outputQtyPerBatch']} ${selectedBom['outputUnitLabel'] ?? 'dona'}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      DropdownButtonFormField<int>(
                        initialValue: _sourceWhId,
                        items: _filteredSourceWarehouses.map<DropdownMenuItem<int>>((w) {
                          return DropdownMenuItem(
                              value: w['id'], child: Text('${w['name']} (${w['type']})'));
                        }).toList(),
                        onChanged: (v) => setState(() => _sourceWhId = v),
                        decoration: InputDecoration(
                          labelText: 'Manba ombor (materiallar olinadigan)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _destWhId,
                        items: _filteredDestWarehouses.map<DropdownMenuItem<int>>((w) {
                          return DropdownMenuItem(
                              value: w['id'], child: Text('${w['name']} (${w['type']})'));
                        }).toList(),
                        onChanged: (v) => setState(() => _destWhId = v),
                        decoration: InputDecoration(
                          labelText: 'Qabul qiluvchi ombor (mahsulot kiradigan)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _batches > 1
                                ? () => setState(() => _batches--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Expanded(
                            child: Center(
                              child: Text('Partiyalar: $_batches',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _batches++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Har bir partiya retsept bo\'yicha materiallarni oladi va '
                        '${selectedBom != null ? '${selectedBom['outputQtyPerBatch']} ${selectedBom['outputUnitLabel'] ?? 'dona'} ${selectedBom['outputName']} beradi' : 'chiqish mahsulotini beradi'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.statusCritical.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.statusCritical.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.statusCritical, fontSize: 13),
                              ),
                              if (_shortages.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('Yetishmayotganlar:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                ..._shortages.map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.remove_circle_outline,
                                              size: 15, color: AppColors.statusCritical),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${s['name']} — kerak: ${s['needed']} ${s['unit'] ?? ''}, mavjud: ${s['available']} ${s['unit'] ?? ''}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.statusCritical),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Boshlash'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_bomId == null || _sourceWhId == null || _destWhId == null) {
      setState(() => _error = 'Retsept, manba va qabul qiluvchi ombor tanlanishi kerak');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _shortages = [];
    });
    final result = await FactoryHubApi.startBomProduction({
      'bom_id': _bomId,
      'batches': _batches,
      'source_warehouse_id': _sourceWhId,
      'dest_warehouse_id': _destWhId,
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result['error'] != null) {
      setState(() {
        _error = result['error'];
        _shortages = (result['shortages'] as List<dynamic>?) ?? [];
      });
      return;
    }
    // Muvaffaqiyat: chiqish mahsuloti haqida aniq xabar
    final outName = result['outputItemName'] ?? 'Mahsulot';
    final outQty = (result['outputQty'] ?? 0).toString();
    final outUnit = result['outputUnit'] ?? 'dona';
    final destName = result['destWarehouseName'] ?? 'Ombor';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$outQty $outUnit $outName — $destName ga qo\'shildi'),
          backgroundColor: AppColors.statusOk,
        ),
      );
    }
    Navigator.pop(context, true);
  }
}

