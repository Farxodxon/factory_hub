import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<dynamic> _warehouses = [];
  String? _error;
  bool _loading = true;

  static const Map<String, String> _typeLabels = {
    'raw': 'Xom ashyo',
    'finished': 'Tayyor mahsulot',
    'spare_parts': 'Ehtiyot qismlar',
    'semi_finished': 'Yarim tayyor',
    'sales': 'Sotuv',
    'dealer': 'Dilerlar',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _warehouses = result['warehouses'] ?? [];
        _error = null;
      }
    });
  }

  Future<void> _createWarehouse() async {
    if (!FactoryHubApi.role.canControlWarehouses) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateWarehouseSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      floatingActionButton:
          FactoryHubApi.role.canControlWarehouses
              ? FloatingActionButton.extended(
                  onPressed: _createWarehouse,
                  icon: const Icon(Icons.add),
                  label: const Text('Ombor'),
                )
              : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _warehouses.length,
                itemBuilder: (_, i) {
                  final w = _warehouses[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.warehouse, color: Color(0xFF1565C0)),
                      title: Text(w['name'] ?? ''),
                      subtitle: Text(_typeLabels[w['type']] ?? w['type'] ?? ''),
                      trailing: Text('${w['itemCount'] ?? 0} element'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _WarehouseDetail(id: w['id'])),
                        );
                        _load();
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _WarehouseDetail extends StatefulWidget {
  const _WarehouseDetail({required this.id});

  final int id;

  @override
  State<_WarehouseDetail> createState() => _WarehouseDetailState();
}

class _WarehouseDetailState extends State<_WarehouseDetail> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getWarehouseDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _detail = result;
        _error = null;
      }
    });
  }

  Future<void> _addTransaction(String direction) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionSheet(warehouseId: widget.id, direction: direction),
    );
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = _detail?['warehouse'];
    final stock = _detail?['stock'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(warehouse?['name'] ?? 'Ombor')),
      floatingActionButton: FactoryHubApi.role.canTransactStock
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'in',
                  onPressed: () => _addTransaction('in'),
                  child: const Icon(Icons.call_received),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'out',
                  onPressed: () => _addTransaction('out'),
                  child: const Icon(Icons.outbound),
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : stock.isEmpty
                  ? const Center(child: Text('Bu omborda qoldiq yoq'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: stock.length,
                        itemBuilder: (_, i) {
                          final item = stock[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              title: Text(item['name'] ?? ''),
                              subtitle: Text(item['itemType'] ?? ''),
                              trailing: Text(
                                '${item['balance']} ${item['unit'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({required this.warehouseId, required this.direction});

  final int warehouseId;
  final String direction;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  List<dynamic> _items = [];
  int? _selectedRawId;
  String? _selectedBarcode;
  String _selectedType = 'raw_material';
  String? _error;
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final result =
        _selectedType == 'product' ? await FactoryHubApi.getProducts() : await FactoryHubApi.getRawMaterials();
    if (!mounted) return;
    setState(() {
      _loadingItems = false;
      _items = result['error'] != null
          ? []
          : (_selectedType == 'product' ? result['products'] : result['rawMaterials']) ?? [];
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _error = "Miqdorni to'g'ri kiriting");
      return;
    }

    final data = <String, dynamic>{
      'warehouse_id': widget.warehouseId,
      'item_type': _selectedType,
      'direction': widget.direction,
      'qty': qty,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    };
    if (_selectedType == 'raw_material') {
      data['ref_id'] = _selectedRawId;
    } else {
      data['ref_barcode'] = _selectedBarcode;
    }

    final result = await FactoryHubApi.addTransaction(data);
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
            Text(
              widget.direction == 'in' ? 'KIRIM' : 'CHIQIM',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'raw_material', label: Text('Xom ashyo')),
                ButtonSegment(value: 'product', label: Text('Mahsulot')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) {
                setState(() {
                  _selectedType = s.first;
                  _loadingItems = true;
                });
                _loadItems();
              },
            ),
            const SizedBox(height: 12),
            _loadingItems
                ? const Center(child: CircularProgressIndicator())
                : Autocomplete<String>(
                    optionsBuilder: (v) => _items
                        .map((e) =>
                            _selectedType == 'product' ? e['name'] as String : e['name'] as String)
                        .where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
                    onSelected: (selected) {
                      final match = _items.firstWhere((e) => e['name'] == selected);
                      setState(() {
                        _selectedRawId = match['id'] != null ? int.tryParse(match['id'].toString()) : null;
                        _selectedBarcode = match['barcode']?.toString();
                      });
                    },
                    fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: InputDecoration(
                        labelText: 'Element tanlash',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Miqdor',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

class _CreateWarehouseSheet extends StatefulWidget {
  const _CreateWarehouseSheet();

  @override
  State<_CreateWarehouseSheet> createState() => _CreateWarehouseSheetState();
}

class _CreateWarehouseSheetState extends State<_CreateWarehouseSheet> {
  final _name = TextEditingController();
  String _type = 'raw';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await FactoryHubApi.createWarehouse(_name.text.trim(), _type);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Yangi ombor", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Nomi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'raw', child: Text('Xom ashyo')),
              DropdownMenuItem(value: 'finished', child: Text('Tayyor mahsulot')),
              DropdownMenuItem(value: 'spare_parts', child: Text('Ehtiyot qismlar')),
              DropdownMenuItem(value: 'semi_finished', child: Text('Yarim tayyor mahsulot')),
              DropdownMenuItem(value: 'sales', child: Text('Sotuv ombori')),
              DropdownMenuItem(value: 'dealer', child: Text('Dilerlar')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'raw'),
            decoration: InputDecoration(
              labelText: 'Turi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }
}

