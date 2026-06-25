import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'bom_detail_screen.dart';

class BomsScreen extends StatefulWidget {
  const BomsScreen({super.key});

  @override
  State<BomsScreen> createState() => _BomsScreenState();
}

class _BomsScreenState extends State<BomsScreen> {
  List _boms = [];
  List _filtered = [];
  bool _loading = true;
  bool _error = false;
  String _search = '';
  String _typeFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await FactoryHubApi.getBoms();
      setState(() {
        _boms = (result['boms'] as List?) ?? [];
        _loading = false;
        _applyFilter();
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _boms.where((b) {
        final matchType =
            _typeFilter == 'all' || b['productionType'] == _typeFilter;
        final matchSearch = _search.isEmpty ||
            (b['name']?.toString().toLowerCase() ?? '')
                .contains(_search.toLowerCase()) ||
            (b['productName']?.toString().toLowerCase() ?? '')
                .contains(_search.toLowerCase());
        return matchType && matchSearch;
      }).toList();
    });
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    final batchSizeController = TextEditingController();
    final batchUnitController = TextEditingController(text: 'dona');
    String productionType = 'batch';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yangi BOM'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'BOM nomi *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: productionType,
                  decoration:
                      const InputDecoration(labelText: 'Ishlab chiqarish turi'),
                  items: const [
                    DropdownMenuItem(
                        value: 'batch', child: Text('Partiyali (batch)')),
                    DropdownMenuItem(
                        value: 'continuous', child: Text('Uzluksiz')),
                    DropdownMenuItem(value: 'discrete', child: Text('Diskret')),
                  ],
                  onChanged: (v) => setDialogState(() => productionType = v!),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: batchSizeController,
                        decoration:
                            const InputDecoration(labelText: 'Partiya hajmi'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: batchUnitController,
                        decoration: const InputDecoration(labelText: 'Birlik'),
                      ),
                    ),
                  ],
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
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        _showMsg('BOM nomini kiriting', isError: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final result = await FactoryHubApi.createBom({
                          'name': nameController.text.trim(),
                          'production_type': productionType,
                          'batch_size': batchSizeController.text.isNotEmpty
                              ? double.tryParse(batchSizeController.text.trim())
                              : null,
                          'batch_unit': batchUnitController.text.trim(),
                        });
                        if (result['error'] != null) {
                          setDialogState(() => saving = false);
                          _showMsg(result['error'].toString(), isError: true);
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showMsg('BOM yaratildi');
                        _load();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _showMsg('Xatolik yuz berdi', isError: true);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Yaratish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBom(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlang'),
        content: Text(
            '"$name" BOMni o\'chirishni xohlaysizmi? Barcha ingredientlar ham o\'chadi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('O\'chirish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await FactoryHubApi.deleteBom(id);
    if (result['error'] != null) {
      _showMsg(result['error'].toString(), isError: true);
    } else {
      _showMsg('BOM o\'chirildi');
      _load();
    }
  }

  Widget _chip(String label, String value) {
    final selected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFF1565C0),
        labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87, fontSize: 13),
        backgroundColor: Colors.white,
        onSelected: (_) {
          _typeFilter = value;
          _applyFilter();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Mahsulot tarkiblari (BOM)'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yangi BOM', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Ma\'lumotni yuklab bo\'lmadi'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Qayta urinish')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'BOM qidirish...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (v) {
                          _search = v;
                          _applyFilter();
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _chip('Barchasi', 'all'),
                          _chip('Partiyali', 'batch'),
                          _chip('Uzluksiz', 'continuous'),
                          _chip('Diskret', 'discrete'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Text('Jami: ${_filtered.length}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? ListView(children: const [
                                Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(child: Text('BOM topilmadi')))
                              ])
                            : ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final b = _filtered[i];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF1565C0)
                                            .withValues(alpha: 0.1),
                                        child: const Icon(Icons.account_tree,
                                            color: Color(0xFF1565C0)),
                                      ),
                                      title: Text(b['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        '${b['productName'] ?? 'Mahsulot belgilanmagan'} · v${b['version'] ?? 1}${b['batchSize'] != null ? ' · ${b['batchSize']} ${b['batchUnit'] ?? ''}' : ''}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (b['isActive'] == true)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Text('Faol',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.green.shade700,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          PopupMenuButton(
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(children: [
                                                    Icon(Icons.delete,
                                                        color: Colors.red,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text('O\'chirish',
                                                        style: TextStyle(
                                                            color: Colors.red))
                                                  ])),
                                            ],
                                            onSelected: (v) {
                                              if (v == 'delete')
                                                _deleteBom(
                                                    b['id'], b['name'] ?? '');
                                            },
                                          ),
                                        ],
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BomDetailScreen(
                                            bomId: b['id'],
                                            bomName: b['name'] ?? '',
                                          ),
                                        ),
                                      ),
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
}
