import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List _materials = [];
  List _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _selectedType = 'all';

  final String _role = FactoryHubApi.role;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getMaterials();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      _materials = (result['materials'] as List?) ?? [];
      _filter();
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _materials.where((m) {
        final matchSearch = q.isEmpty || (m['name'] ?? '').toLowerCase().contains(q);
        final matchType = _selectedType == 'all' || m['type'] == _selectedType;
        return matchSearch && matchType;
      }).toList();
    });
  }

  Future<void> _showMaterialDialog({Map? material}) async {
    final isEdit = material != null;
    final name = TextEditingController(text: material?['name'] ?? '');
    final minStock = TextEditingController(text: material?['minStock']?.toString() ?? '');
    final maxStock = TextEditingController(text: material?['maxStock']?.toString() ?? '');
    final leadTime = TextEditingController(text: material?['leadTimeDays']?.toString() ?? '30');
    String type = material?['type'] ?? 'raw';
    String unit = material?['unit'] ?? 'kg';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Materialni tahrirlash' : 'Yangi material'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nomi *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Turi', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'raw', child: Text('Xom ashyo')),
                  DropdownMenuItem(value: 'purchased', child: Text('Sotib olingan')),
                  DropdownMenuItem(value: 'semi_finished', child: Text('Yarim tayyor')),
                  DropdownMenuItem(value: 'finished', child: Text('Tayyor mahsulot')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Olchov', border: OutlineInputBorder()),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEdit ? 'Saqlash' : 'Qoshish'),
            ),
          ],
        ),
      ),
    );

    if (result != true || name.text.trim().isEmpty) return;

    final data = {
      'name': name.text.trim(),
      'type': type,
      'unit': unit,
      'min_stock': double.tryParse(minStock.text) ?? 0,
      'max_stock': double.tryParse(maxStock.text) ?? 0,
      'lead_time_days': int.tryParse(leadTime.text) ?? 30,
    };

    final apiResult = isEdit
        ? await FactoryHubApi.updateMaterial(int.parse(material['id'].toString()), data)
        : await FactoryHubApi.createMaterial(data);

    if (apiResult['error'] != null) {
      _showMsg(apiResult['error'], isError: true);
    } else {
      _showMsg(isEdit ? 'Yangilandi!' : 'Qoshildi!');
      _load();
    }
  }

  Future<void> _deleteMaterial(Map material) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ochirish'),
        content: Text('"${material['name']}" ni ochirishni tasdiqlaysizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ochirish'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final result = await FactoryHubApi.deleteMaterial(int.parse(material['id'].toString()));
    if (result['error'] != null) {
      _showMsg(result['error'], isError: true);
    } else {
      _showMsg('Ochirildi');
      _load();
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
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

  String _typeLabel(String? type) {
    switch (type) {
      case 'raw': return 'Xom ashyo';
      case 'purchased': return 'Sotib olingan';
      case 'semi_finished': return 'Yarim tayyor';
      case 'finished': return 'Tayyor mahsulot';
      default: return type ?? '-';
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'raw': return Icons.science;
      case 'purchased': return Icons.shopping_cart;
      case 'semi_finished': return Icons.precision_manufacturing;
      case 'finished': return Icons.check_circle;
      default: return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Materiallar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: _role == 'employee'
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showMaterialDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Yangi material'),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Material nomi...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _filter(); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('all', 'Barchasi'),
                const SizedBox(width: 8),
                _chip('raw', 'Xom ashyo'),
                const SizedBox(width: 8),
                _chip('purchased', 'Sotib olingan'),
                const SizedBox(width: 8),
                _chip('semi_finished', 'Yarim tayyor'),
                _chip('finished', 'Tayyor mahsulot'),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('Jami: ${_filtered.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            Builder(builder: (_) {
              final lowCount = _filtered.where((m) {
                final stock = double.tryParse(m['currentStock']?.toString() ?? '0') ?? 0;
                final min = double.tryParse(m['minStock']?.toString() ?? '0') ?? 0;
                return min > 0 && stock <= min;
              }).length;
              return Text(
                lowCount > 0 ? '$lowCount ta kam zaxira' : 'Hammasi yetarli',
                style: TextStyle(fontSize: 12, color: lowCount > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w600),
              );
            }),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.error_outline, size: 50, color: Colors.red),
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      ElevatedButton(onPressed: _load, child: const Text('Qayta')),
                    ]))
                  : _filtered.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Materiallar topilmadi', style: TextStyle(color: Colors.grey)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _materialCard(_filtered[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _selectedType == value;
    return GestureDetector(
      onTap: () { setState(() => _selectedType = value); _filter(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _materialCard(Map m) {
    final stock = double.tryParse(m['currentStock']?.toString() ?? '0') ?? 0;
    final min = double.tryParse(m['minStock']?.toString() ?? '0') ?? 0;
    final isLow = min > 0 && stock <= min;
    final color = _typeColor(m['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        border: isLow ? Border.all(color: Colors.red.shade100) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(_typeIcon(m['type']), color: color),
        ),
        title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['unit']} | ${_typeLabel(m['type'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Qoldiq: ${stock.toStringAsFixed(1)}', style: TextStyle(
              color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12,
            )),
            if (min > 0) Text(' / Min: ${min.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
        trailing: _role == 'employee'
            ? (isLow ? const Icon(Icons.warning, color: Colors.red) : null)
            : PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [
                    Icon(Icons.edit, size: 18, color: Colors.blue),
                    SizedBox(width: 8), Text('Tahrirlash'),
                  ])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8), Text('Ochirish'),
                  ])),
                ],
                onSelected: (v) {
                  if (v == 'edit') _showMaterialDialog(material: m);
                  if (v == 'delete') _deleteMaterial(m);
                },
              ),
      ),
    );
  }
}
