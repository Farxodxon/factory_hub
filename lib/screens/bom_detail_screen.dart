import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BomDetailScreen extends StatefulWidget {
  final int bomId;
  final String bomName;

  const BomDetailScreen({
    super.key,
    required this.bomId,
    required this.bomName,
  });

  @override
  State<BomDetailScreen> createState() => _BomDetailScreenState();
}

class _BomDetailScreenState extends State<BomDetailScreen> {
  Map<String, dynamic>? _bom;
  List _ingredients = [];
  List _materials = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        FactoryHubApi.getBomDetail(widget.bomId),
        FactoryHubApi.getMaterials(),
      ]);
      setState(() {
        _bom = results[0]['bom'] as Map<String, dynamic>?;
        _ingredients = (results[0]['ingredients'] as List?) ?? [];
        _materials = (results[1]['materials'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = true; _loading = false; });
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'raw': return 'Xom ashyo';
      case 'purchased': return 'Sotib olingan';
      case 'semi_finished': return 'Yarim tayyor';
      case 'finished': return 'Tayyor mahsulot';
      default: return type ?? '';
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'raw': return Colors.blue;
      case 'purchased': return Colors.orange;
      case 'semi_finished': return Colors.purple;
      case 'finished': return Colors.green;
      default: return Colors.grey;
    }
  }

  Future<void> _openProductionDialog() async {
    if (_ingredients.isEmpty) {
      _showMsg('Avval ingredientlar qo\'shing', isError: true);
      return;
    }

    final qtyController = TextEditingController(text: _bom?['batchSize']?.toString() ?? '1');
    bool checking = false;
    bool saving = false;
    List<Map<String, dynamic>> shortages = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ishlab chiqarish boshlash'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BOM: ${widget.bomName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Ingredientlar: ${_ingredients.length} ta', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Ishlab chiqarish miqdori *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (shortages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zaxira yetarli emas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                        const SizedBox(height: 6),
                        ...shortages.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${s['materialName']}: kerak ${s['needed']}, mavjud ${s['available']} ${s['unit']}',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: (checking || saving) ? null : () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: (checking || saving) ? null : () async {
                final qty = double.tryParse(qtyController.text.trim());
                if (qty == null || qty <= 0) {
                  _showMsg('Miqdor noto\'g\'ri', isError: true);
                  return;
                }
                setDialogState(() { checking = true; shortages = []; });
                try {
                  final result = await FactoryHubApi.startProduction({
                    'bom_id': widget.bomId,
                    'planned_quantity': qty,
                    'unit': _bom?['batchUnit'] ?? 'dona',
                    'operator_id': 1,
                  });
                  if (result['shortages'] != null) {
                    setDialogState(() {
                      checking = false;
                      shortages = List<Map<String, dynamic>>.from(result['shortages']);
                    });
                    return;
                  }
                  if (result['error'] != null) {
                    setDialogState(() => checking = false);
                    _showMsg(result['error'].toString(), isError: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  final batchNumber = result['batch']?['batchNumber'] ?? '';
                  _showMsg('Ishlab chiqarish boshlandi! $batchNumber');
                  _load();
                } catch (e) {
                  setDialogState(() => checking = false);
                  _showMsg('Xatolik yuz berdi', isError: true);
                }
              },
              child: (checking || saving)
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Boshlash', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddIngredientDialog() async {
    String? selectedMaterialId;
    final qtyController = TextEditingController();
    final unitController = TextEditingController();
    final notesController = TextEditingController();
    bool saving = false;

    // Allaqachon qo'shilgan materiallarni chiqarib tashlash
    final addedIds = _ingredients.map((i) => i['materialId'].toString()).toSet();
    final available = _materials.where((m) => !addedIds.contains(m['id'].toString())).toList();

    if (available.isEmpty) {
      _showMsg('Barcha materiallar allaqachon qo\'shilgan', isError: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ingredient qo\'shish'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Material *'),
                  items: available.map((m) => DropdownMenuItem<String>(
                    value: m['id'].toString(),
                    child: Text('${m['name']} (${_typeLabel(m['type'])})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedMaterialId = v;
                      // Unit avtomatik to'ldiriladi
                      final mat = available.firstWhere((m) => m['id'].toString() == v, orElse: () => {});
                      unitController.text = mat['unit']?.toString() ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Miqdor *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'O\'lchov birligi *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (selectedMaterialId == null || qtyController.text.trim().isEmpty || unitController.text.trim().isEmpty) {
                  _showMsg('Barcha majburiy maydonlarni to\'ldiring', isError: true);
                  return;
                }
                final qty = double.tryParse(qtyController.text.trim());
                if (qty == null || qty <= 0) {
                  _showMsg('Miqdor noto\'g\'ri', isError: true);
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final result = await FactoryHubApi.addIngredient(widget.bomId, {
                    'material_id': int.parse(selectedMaterialId!),
                    'quantity': qty,
                    'unit': unitController.text.trim(),
                    'notes': notesController.text.trim(),
                  });
                  if (result['error'] != null) {
                    setDialogState(() => saving = false);
                    _showMsg(result['error'].toString(), isError: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMsg('Ingredient qo\'shildi');
                  _load();
                } catch (e) {
                  setDialogState(() => saving = false);
                  _showMsg('Xatolik yuz berdi', isError: true);
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteIngredient(int ingredientId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlang'),
        content: Text('"$name" ni BOM tarkibidan olib tashlamoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await FactoryHubApi.deleteIngredient(widget.bomId, ingredientId);
    if (result['error'] != null) {
      _showMsg(result['error'].toString(), isError: true);
    } else {
      _showMsg('Ingredient o\'chirildi');
      _load();
    }
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.bomName),
            if (_bom != null)
              Text(
                _bom!['productName']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'production',
            backgroundColor: Colors.green,
            onPressed: _openProductionDialog,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Ishlab chiqarish', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'ingredient',
            backgroundColor: const Color(0xFF1565C0),
            onPressed: _openAddIngredientDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Ingredient', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Ma\'lumotni yuklab bo\'lmadi'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // BOM info card
            if (_bom != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _infoChip('Versiya', 'v${_bom!['version'] ?? 1}', const Color(0xFF1565C0)),
                              _infoChip('Tur', _bom!['productionType'] ?? 'batch', Colors.teal),
                              if (_bom!['batchSize'] != null)
                                _infoChip('Partiya', '${_bom!['batchSize']} ${_bom!['batchUnit'] ?? ''}', Colors.orange),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _bom!['isActive'] == true ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _bom!['isActive'] == true ? 'Faol' : 'Faol emas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _bom!['isActive'] == true ? Colors.green.shade700 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Ingredientlar (${_ingredients.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),

            if (_ingredients.isEmpty)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('Hali ingredient qo\'shilmagan')),
              )
            else
              ..._ingredients.map((ing) {
                final color = _typeColor(ing['materialType']);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(Icons.science, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ing['materialName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(_typeLabel(ing['materialType']), style: TextStyle(fontSize: 12, color: color)),
                            if (ing['notes'] != null && ing['notes'].toString().isNotEmpty)
                              Text(ing['notes'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            ing['quantity'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(ing['unit'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteIngredient(ing['id'], ing['materialName'] ?? ''),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}