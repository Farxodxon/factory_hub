import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});
  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List _warehouses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getWarehouses();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() {
        _warehouses = (result['warehouses'] as List?) ?? [];
        _loading = false;
      });
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'raw': return Icons.science;
      case 'purchased': return Icons.shopping_cart;
      case 'semi_finished': return Icons.hourglass_bottom;
      case 'finished': return Icons.check_circle;
      case 'sales': return Icons.store;
      default: return Icons.warehouse;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'raw': return Colors.blue;
      case 'purchased': return Colors.orange;
      case 'semi_finished': return Colors.purple;
      case 'finished': return Colors.green;
      case 'sales': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'raw': return 'Xom ashyo';
      case 'purchased': return 'Sotib olingan';
      case 'semi_finished': return 'Yarim tayyor';
      case 'finished': return 'Tayyor mahsulot';
      case 'sales': return 'Sotuv';
      default: return type ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Omborlar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(onPressed: _load, child: const Text('Qayta')),
                ]))
              : _warehouses.isEmpty
                  ? const Center(child: Text('Omborlar topilmadi', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _warehouses.length,
                        itemBuilder: (_, i) {
                          final w = _warehouses[i];
                          final color = _color(w['type']);
                          final count = w['materialCount'] ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_icon(w['type']), color: color),
                              ),
                              title: Text(w['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(_typeLabel(w['type']), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 4),
                                Text('$count ta material', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ]),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => WarehouseDetailScreen(warehouse: w)),
                              ).then((_) => _load()),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ═══════════════════════════════════════════════════
// WAREHOUSE DETAIL SCREEN
// ═══════════════════════════════════════════════════

class WarehouseDetailScreen extends StatefulWidget {
  final Map warehouse;
  const WarehouseDetailScreen({super.key, required this.warehouse});

  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getWarehouseDetail(
      int.parse(widget.warehouse['id'].toString()),
    );
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() { _detail = result; _loading = false; });
    }
  }

  Future<void> _addTransaction(String txType) async {
    final materials = (_detail?['materials'] as List?) ?? [];
    if (materials.isEmpty) {
      _showMsg('Omborga biriktirilgan material yoq', isError: true);
      return;
    }

    int? selectedMaterialId = int.tryParse(materials.first['materialId'].toString());
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Row(children: [
            Icon(txType == 'in' ? Icons.add_circle : Icons.remove_circle,
                color: txType == 'in' ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(txType == 'in' ? 'Kirim' : 'Chiqim'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                initialValue: selectedMaterialId,
                decoration: const InputDecoration(labelText: 'Material', border: OutlineInputBorder()),
                items: materials.map<DropdownMenuItem<int>>((m) => DropdownMenuItem(
                  value: int.parse(m['materialId'].toString()),
                  child: Text(m['materialName'] ?? '', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  final m = materials.firstWhere((m) => int.parse(m['materialId'].toString()) == v);
                  setDialog(() {
                    selectedMaterialId = v;
});
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Miqdor *',
                  border: const OutlineInputBorder(),
                  suffixText: materials.firstWhere(
                    (m) => int.parse(m['materialId'].toString()) == selectedMaterialId,
                    orElse: () => {'unit': ''},
                  )['unit'] ?? '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)', border: OutlineInputBorder()),
              ),
              if (txType == 'out') ...[
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final m = materials.firstWhere(
                    (m) => int.parse(m['materialId'].toString()) == selectedMaterialId,
                    orElse: () => {},
                  );
                  final balance = double.tryParse(m['balance']?.toString() ?? '0') ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('Mavjud: ${balance.toStringAsFixed(1)} ${m['unit'] ?? ''}',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: txType == 'in' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(txType == 'in' ? 'Kirim qilish' : 'Chiqim qilish'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final qty = double.tryParse(qtyCtrl.text);
    if (qty == null || qty <= 0) {
      _showMsg('Miqdorni togri kiriting', isError: true);
      return;
    }

    final result = await FactoryHubApi.addTransaction({
      'warehouse_id': int.parse(widget.warehouse['id'].toString()),
      'material_id': selectedMaterialId,
      'transaction_type': txType,
      'quantity': qty,
      'unit': (_detail?['materials'] as List?)?.firstWhere(
        (m) => int.parse(m['materialId'].toString()) == selectedMaterialId,
        orElse: () => {'unit': 'kg'},
      )['unit'] ?? 'kg',
      'notes': notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
      'performed_by': FactoryHubApi.userId,
    });

    if (result['error'] != null) {
      _showMsg(result['error'], isError: true);
    } else {
      _showMsg(txType == 'in' ? 'Kirim amalga oshirildi!' : 'Chiqim amalga oshirildi!');
      _load();
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.warehouse['name'] ?? 'Ombor';
    final role = FactoryHubApi.role;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Materiallar'),
            Tab(icon: Icon(Icons.history), text: 'Tarix'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(onPressed: _load, child: const Text('Qayta')),
                ]))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _materialsTab(),
                    _historyTab(),
                  ],
                ),
      bottomNavigationBar: role == 'employee'
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addTransaction('in'),
                    icon: const Icon(Icons.add),
                    label: const Text('Kirim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addTransaction('out'),
                    icon: const Icon(Icons.remove),
                    label: const Text('Chiqim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _materialsTab() {
    final materials = (_detail?['materials'] as List?) ?? [];
    if (materials.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey),
        SizedBox(height: 12),
        Text('Hali tranzaksiya yoq', style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materials.length,
      itemBuilder: (_, i) {
        final m = materials[i];
        final totalIn = double.tryParse(m['totalIn']?.toString() ?? '0') ?? 0;
        final totalOut = double.tryParse(m['totalOut']?.toString() ?? '0') ?? 0;
        final balance = double.tryParse(m['balance']?.toString() ?? '0') ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['materialName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Text(m['unit'] ?? '', style: const TextStyle(color: Colors.grey)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _statBox('Kirim', totalIn, Colors.green),
                const SizedBox(width: 8),
                _statBox('Chiqim', totalOut, Colors.red),
                const SizedBox(width: 8),
                _statBox('Qoldiq', balance, balance > 0 ? Colors.blue : Colors.grey),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _statBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value.toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _historyTab() {
    final transactions = (_detail?['transactions'] as List?) ?? [];
    if (transactions.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, size: 70, color: Colors.grey),
        SizedBox(height: 12),
        Text('Tarix yoq', style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final tx = transactions[i];
        final isIn = tx['type'] == 'in';
        final qty = double.tryParse(tx['quantity']?.toString() ?? '0') ?? 0;
        final dateStr = tx['createdAt']?.toString().substring(0, 16) ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIn ? Colors.green : Colors.red, size: 20),
            ),
            title: Text(tx['materialName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (tx['notes'] != null && tx['notes'].toString().isNotEmpty)
                Text(tx['notes'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                '${isIn ? '+' : '-'}${qty.toStringAsFixed(1)}',
                style: TextStyle(color: isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(tx['unit'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        );
      },
    );
  }
}
