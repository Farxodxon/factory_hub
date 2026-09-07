import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'catalog_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<dynamic> _boms = [];
  List<dynamic> _items = [];
  String _stageFilter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final bomsResult = await FactoryHubApi.getBoms();
    final itemsResult = await FactoryHubApi.getItems();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = bomsResult['error'] ?? itemsResult['error'];
      if (_error == null) {
        _boms = bomsResult['boms'] ?? [];
        _items = itemsResult['items'] ?? [];
      }
    });
  }

  List<dynamic> get _visibleBoms {
    if (_stageFilter == 'all') return _boms;
    return _boms.where((b) => b['stage'] == _stageFilter).toList();
  }

  Future<void> _openForm([Map<String, dynamic>? bom]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecipeFormSheet(items: _items, existing: bom),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _openCreateMenu() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Yangi yaratish'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'recipe'),
            child: const Text('Retsept yaratish'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'item'),
            child: const Text('Mahsulot yaratish'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'recipe') {
      await _openForm();
    } else if (choice == 'item') {
      await showCreateItemSheet(context, onCreated: _load);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> bom) async {
    final id = bom['id'] as int;
    final result = await FactoryHubApi.updateBom(id, {'is_active': false});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['error'] ?? 'Retsept o\'chirildi'),
      backgroundColor: result['error'] != null ? AppColors.statusCritical : AppColors.statusOk,
    ));
    _load();
  }

  String _stageLabel(String stage) => stage == 'packaging' ? 'Qadoqlash' : 'Aralashtirish';

  @override
  Widget build(BuildContext context) {
    final canEdit = FactoryHubApi.role.canControlWarehouses;
    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'fab_recipes',
              onPressed: _openCreateMenu,
              icon: const Icon(Icons.add),
              label: const Text('Yangi yaratish'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Yangilash'),
                        ),
                      ),
                      Text('Retseptlar', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Aralashtirish va qadoqlash bosqichlari uchun retseptlarni boshqaring.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('Barchasi')),
                          ButtonSegment(value: 'mixing', label: Text('Aralashtirish')),
                          ButtonSegment(value: 'packaging', label: Text('Qadoqlash')),
                        ],
                        selected: {_stageFilter},
                        onSelectionChanged: (s) => setState(() => _stageFilter = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (_visibleBoms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('Retsept topilmadi',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        )
                      else
                        ..._visibleBoms.map((b) => _bomCard(b, canEdit)),
                    ],
                  ),
                ),
    );
  }

  Widget _bomCard(Map<String, dynamic> bom, bool canEdit) {
    final stage = bom['stage'] as String? ?? 'mixing';
    final out = double.tryParse(bom['outputQtyPerBatch']?.toString() ?? '') ?? 0;
    final unit = bom['outputUnitLabel'] ?? bom['outputUnit'] ?? 'dona';
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
                  child: Text(bom['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stage == 'packaging'
                        ? AppColors.statusOk.withValues(alpha: 0.12)
                        : AppColors.statusWarning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_stageLabel(stage),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: stage == 'packaging' ? AppColors.statusOk : Colors.orange.shade800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Chiqish: ${bom['outputName'] ?? ''} — $out $unit',
                style: const TextStyle(fontSize: 13)),
            if (canEdit) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openForm(bom),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Tahrirlash'),
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _toggleActive(bom),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('O\'chirish'),
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.statusCritical),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecipeFormSheet extends StatefulWidget {
  const _RecipeFormSheet({required this.items, this.existing});

  final List<dynamic> items;
  final Map<String, dynamic>? existing;

  @override
  State<_RecipeFormSheet> createState() => _RecipeFormSheetState();
}

class _IngRow {
  int? itemId;
  final TextEditingController qtyCtrl;
  _IngRow(this.itemId, this.qtyCtrl);
}

class _RecipeFormSheetState extends State<_RecipeFormSheet> {
  static const _mixingOut = {'semi_finished', 'intermediate', 'semi', 'raw', 'material'};
  static const _packagingOut = {'product', 'finished', 'item'};

  final Map<int, Map<String, dynamic>> _itemById = {};
  final List<_IngRow> _ingredients = [];

  String _stage = 'mixing';
  final _nameCtrl = TextEditingController();
  int? _outItemId;
  final _outQtyCtrl = TextEditingController();
  final _outUnitCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    for (final it in widget.items) {
      _itemById[(it['id'] as num).toInt()] = it as Map<String, dynamic>;
    }
    final existing = widget.existing;
    if (existing != null) {
      final bom = existing['bom'] as Map? ?? const {};
      _stage = (bom['stage'] as String? ?? 'mixing') == 'packaging' ? 'packaging' : 'mixing';
      _nameCtrl.text = bom['name']?.toString() ?? '';
      _outItemId = (bom['outputItemId'] as num?)?.toInt();
      _outQtyCtrl.text = bom['outputQty']?.toString() ?? '';
      _outUnitCtrl.text = bom['outputUnit']?.toString() ?? '';
      final ingItems = (existing['items'] as List?) ?? [];
      for (final ing in ingItems) {
        final row = _IngRow((ing['refId'] as num?)?.toInt(), TextEditingController(text: ing['qty']?.toString() ?? ''));
        _ingredients.add(row);
      }
    } else {
      _ingredients.add(_IngRow(null, TextEditingController()));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _outQtyCtrl.dispose();
    _outUnitCtrl.dispose();
    for (final row in _ingredients) {
      row.qtyCtrl.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _outputCandidates {
    final allowed = _stage == 'packaging' ? _packagingOut : _mixingOut;
    return widget.items
        .where((i) => allowed.contains(i['itemType']))
        .toList()
        .cast<Map<String, dynamic>>();
  }

  void _onOutputChanged(int? id) {
    setState(() {
      _outItemId = id;
      if (id != null && _outUnitCtrl.text.trim().isEmpty) {
        _outUnitCtrl.text = _itemById[id]?['unit']?.toString() ?? '';
      }
    });
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngRow(null, TextEditingController())));
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].qtyCtrl.dispose();
      _ingredients.removeAt(index);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final outQty = double.tryParse(_outQtyCtrl.text.replaceAll(',', '.'));
    final items = <Map<String, dynamic>>[];
    for (final row in _ingredients) {
      final id = row.itemId;
      if (id == null) continue;
      final qty = double.tryParse(row.qtyCtrl.text.replaceAll(',', '.'));
      if (qty == null || qty <= 0) continue;
      final it = _itemById[id]!;
      items.add({
        'item_type': it['itemType'],
        'ref_id': id,
        'ref_barcode': null,
        'name': it['name'],
        'unit': it['unit'],
        'qty': qty,
      });
    }
    if (name.isEmpty) {
      setState(() => _error = 'Retsept nomini kiriting');
      return;
    }
    if (_outItemId == null) {
      setState(() => _error = 'Chiqadigan mahsulotni tanlang');
      return;
    }
    if (outQty == null || outQty <= 0) {
      setState(() => _error = "Chiqadigan miqdorni to'g'ri kiriting");
      return;
    }
    if (items.isEmpty) {
      setState(() => _error = 'Kamida bitta tarkib qatori kerak (mahsulot + miqdor)');
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'output_item_id': _outItemId,
      'output_qty': outQty,
      'output_unit': _outUnitCtrl.text.trim().isEmpty ? 'dona' : _outUnitCtrl.text.trim(),
      'items': items,
    };
    setState(() { _saving = true; _error = null; });
    final result = _isEdit
        ? await FactoryHubApi.updateBom((widget.existing!['bom'] as Map)['id'] as int, payload)
        : await FactoryHubApi.createBom({...payload, 'stage': _stage});
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final outputItems = _outputCandidates;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'RETSEPTNI TAHRIRLASH' : 'YANGI RETSEPT',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (!_isEdit)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'mixing', label: Text('Aralashtirish')),
                  ButtonSegment(value: 'packaging', label: Text('Qadoqlash')),
                ],
                selected: {_stage},
                onSelectionChanged: (s) {
                  setState(() {
                    _stage = s.first;
                    _outItemId = null;
                  });
                },
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Retsept nomi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _outItemId,
              items: outputItems.map<DropdownMenuItem<int>>((i) =>
                  DropdownMenuItem(value: (i['id'] as num).toInt(),
                      child: Text('${i['name']} (${i['itemType']})'))).toList(),
              onChanged: _onOutputChanged,
              decoration: const InputDecoration(
                labelText: 'Chiqadigan mahsulot',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _outQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Partiya miqdori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _outUnitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'O\'lchov birligi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Tarkib', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Qator qo\'shish'),
                ),
              ],
            ),
            for (var i = 0; i < _ingredients.length; i++) _ingredientRow(i),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Saqlash' : 'Yaratish'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientRow(int index) {
    final row = _ingredients[index];
    final usedByIds = _ingredients.asMap().entries
        .where((e) => e.key != index)
        .map((e) => e.value.itemId)
        .whereType<int>()
        .toSet();
    final items = widget.items
        .where((i) => !usedByIds.contains((i['id'] as num).toInt()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              initialValue: row.itemId,
              items: items.map<DropdownMenuItem<int>>((i) => DropdownMenuItem(
                  value: (i['id'] as num).toInt(),
                  child: Text('${i['name']} (${i['itemType']})',
                      maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => row.itemId = v),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mahsulot',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Miqdor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeIngredient(index),
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.statusCritical),
          ),
        ],
      ),
    );
  }
}