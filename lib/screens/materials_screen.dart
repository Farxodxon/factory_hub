import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List _materials = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getMaterials();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() {
        _materials = (result['materials'] as List?) ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _addMaterial() async {
    final name = TextEditingController();
    final minStock = TextEditingController();
    final maxStock = TextEditingController();
    final leadTime = TextEditingController();
    String type = 'raw';
    String unit = 'kg';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yangi material'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nomi', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Turi', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'raw', child: Text('Xom ashyo')),
                  DropdownMenuItem(value: 'purchased', child: Text('Sotib olingan')),
                  DropdownMenuItem(value: 'self_produced', child: Text('O\'zimizda ishlab chiqarilgan')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'O\'lchov', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('kg')),
                  DropdownMenuItem(value: 'litr', child: Text('litr')),
                  DropdownMenuItem(value: 'dona', child: Text('dona')),
                  DropdownMenuItem(value: 'metr', child: Text('metr')),
                  DropdownMenuItem(value: 'm2', child: Text('m²')),
                ],
                onChanged: (v) => setDialogState(() => unit = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: minStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min qoldiq', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: maxStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max qoldiq', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: leadTime, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yetkazish (kun)', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Qo\'shish')),
          ],
        ),
      ),
    );

    if (result == true && name.text.isNotEmpty) {
      await FactoryHubApi.createMaterial({
        'name': name.text.trim(),
        'type': type,
        'unit': unit,
        'min_stock': double.tryParse(minStock.text) ?? 0,
        'max_stock': double.tryParse(maxStock.text) ?? 0,
        'lead_time_days': int.tryParse(leadTime.text) ?? 30,
      });
      _load();
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'raw': return Colors.blue;
      case 'purchased': return Colors.orange;
      case 'self_produced': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'raw': return 'Xom ashyo';
      case 'purchased': return 'Sotib olingan';
      case 'self_produced': return 'O\'zimizda ishlab chiqarilgan';
      default: return type ?? '-';
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'raw': return Icons.science;
      case 'purchased': return Icons.shopping_cart;
      case 'self_produced': return Icons.precision_manufacturing;
      default: return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiallar'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMaterial,
        icon: const Icon(Icons.add),
        label: const Text('Yangi material'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
                ]))
              : _materials.isEmpty
                  ? const Center(child: Text('Materiallar yo\'q. "+" tugmasini bosing'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _materials.length,
                        itemBuilder: (ctx, i) {
                          final m = _materials[i];
                          final stock = double.tryParse(m['currentStock']?.toString() ?? '0') ?? 0;
                          final min = double.tryParse(m['minStock']?.toString() ?? '0') ?? 0;
                          final isLow = min > 0 && stock <= min;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _typeColor(m['type']).withValues(alpha: 0.2),
                                child: Icon(_typeIcon(m['type']), color: _typeColor(m['type'])),
                              ),
                              title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${m['unit']} | ${_typeLabel(m['type'])}'),
                                  Row(
                                    children: [
                                      Text('Qoldiq: ${stock.toStringAsFixed(1)}', style: TextStyle(color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                                      if (min > 0) Text(' / Min: ${min.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isLow) const Icon(Icons.warning, color: Colors.red, size: 20),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLow ? Colors.red.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isLow ? 'Kam' : 'Yetarli',
                                      style: TextStyle(fontSize: 10, color: isLow ? Colors.red : Colors.green),
                                    ),
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
}
