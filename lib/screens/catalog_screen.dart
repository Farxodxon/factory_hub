import 'package:flutter/material.dart';

import '../models/user.dart';
import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: const TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Mahsulotlar'),
                Tab(text: 'Xom ashyolar'),
                Tab(text: 'Yarim/Tayyor'),
                Tab(text: 'Retseptlar'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [
              _ProductsTab(),
              _RawMaterialsTab(),
              _ItemsCatalogTab(),
              _BomTab(),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getProducts(search: _search.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _products = result['products'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: "Nom yoki barcode bo'yicha qidirish",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : isDesktop
                  ? _buildTable()
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
          title: Text(p['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${p['barcode']} | ${p['pcsInBox'] ?? 0} dona/quti'),
          trailing: Text('Qoldiq: ${p['stock'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Barcode')),
          DataColumn(label: Text('Quti/dona'), numeric: true),
          DataColumn(label: Text('Qoldiq'), numeric: true),
        ],
        rows: _products.map((p) {
          return DataRow(cells: [
            DataCell(Text(p['name'] ?? '', maxLines: 2)),
            DataCell(Text('${p['barcode'] ?? ''}')),
            DataCell(Text('${p['pcsInBox'] ?? 0}')),
            DataCell(Text('${p['stock'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }
}

class _RawMaterialsTab extends StatefulWidget {
  const _RawMaterialsTab();

  @override
  State<_RawMaterialsTab> createState() => _RawMaterialsTabState();
}

class _RawMaterialsTabState extends State<_RawMaterialsTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _materials = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getRawMaterials();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _materials = result['rawMaterials'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop = AppBreakpoints.isDesktop(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: isDesktop ? _buildTable() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _materials.length,
      itemBuilder: (_, i) {
        final m = _materials[i];
        return ListTile(
          leading: const Icon(Icons.science, color: AppColors.primary, size: 20),
          title: Row(
            children: [
              if (m['code'] != null && '${m['code']}'.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${m['code']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                  ),
                ),
              if (m['code'] != null && '${m['code']}'.isNotEmpty) const SizedBox(width: 8),
              Expanded(child: Text(m['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          trailing: Text(
            '${m['stock']} ${m['unit'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Kod')),
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Qoldiq'), numeric: true),
          DataColumn(label: Text('Birlik')),
        ],
        rows: _materials.map((m) {
          return DataRow(cells: [
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${m['code'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                ),
              ),
            ),
            DataCell(Text(m['name'] ?? '')),
            DataCell(Text('${m['stock']}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(m['unit'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }
}

const _itemTypeLabels = {
  'semi_finished': 'Yarim tayyor',
  'finished': 'Tayyor mahsulot',
  'packaging': 'Qadoqlash mat.',
  'raw': 'Xom ashyo',
  'spare_part': 'Ehtiyot qism',
};

class _ItemsCatalogTab extends StatefulWidget {
  const _ItemsCatalogTab();

  @override
  State<_ItemsCatalogTab> createState() => _ItemsCatalogTabState();
}

class _ItemsCatalogTabState extends State<_ItemsCatalogTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getItems();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = result['items'] ?? [];
    });
  }

  String _label(String t) => _itemTypeLabels[t] ?? t;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final canCreate = FactoryHubApi.role.canControlWarehouses;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _showCreateItem(context),
                icon: const Icon(Icons.add),
                label: const Text('Yangi mahsulot'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: isDesktop ? _buildTable() : _buildList(),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateItem(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'dona');
    final contentCtrl = TextEditingController();
    String? type = 'semi_finished';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('YANGI MAHSULOT',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nomi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'semi_finished', child: Text('Yarim tayyor')),
                    DropdownMenuItem(value: 'finished', child: Text('Tayyor mahsulot')),
                    DropdownMenuItem(value: 'packaging', child: Text('Qadoqlash materiali')),
                    DropdownMenuItem(value: 'spare_part', child: Text('Ehtiyot qism')),
                  ],
                  onChanged: (v) => setSheet(() => type = v),
                  decoration: InputDecoration(
                    labelText: 'Turi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Kod (ixtiyoriy)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCtrl,
                  decoration: InputDecoration(
                    labelText: 'O\'lchov birligi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Sifat / hajm (ml)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final res = await FactoryHubApi.createItem({
                      'name': nameCtrl.text.trim(),
                      'item_type': type,
                      'code': codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                      'unit': unitCtrl.text.trim(),
                      if (double.tryParse(contentCtrl.text) != null)
                        'content_ml': double.parse(contentCtrl.text),
                    });
                    if (!ctx.mounted) return;
                    if (res['error'] != null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('${res['error']}'),
                            backgroundColor: AppColors.statusCritical),
                      );
                    } else {
                      Navigator.pop(ctx);
                      if (mounted) _load();
                    }
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        final type = '${it['itemType']}';
        return ListTile(
          dense: true,
          leading: Icon(
            type == 'semi_finished'
                ? Icons.science
                : type == 'packaging'
                    ? Icons.inventory
                    : Icons.production_quantity_limits,
            color: AppColors.primary,
            size: 20,
          ),
          title: Text('${it['name']}'),
          subtitle: Text('${_label(type)} | ${it['code'] ?? ''} | ${it['unit'] ?? 'dona'}'),
          trailing: it['contentMl'] != null && '${it['contentMl']}'.isNotEmpty
              ? Text('${it['contentMl']} ml',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
              : null,
        );
      },
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Tur')),
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Kod')),
          DataColumn(label: Text('Birlik')),
          DataColumn(label: Text('Sifat (ml)')),
        ],
        rows: _items.map((it) {
          return DataRow(cells: [
            DataCell(Text(_label('${it['itemType']}'))),
            DataCell(Text('${it['name']}', maxLines: 2)),
            DataCell(Text('${it['code'] ?? ''}')),
            DataCell(Text('${it['unit'] ?? 'dona'}')),
            DataCell(Text('${it['contentMl'] ?? ''}')),
          ]);
        }).toList(),
      ),
    );
  }
}

class _BomTab extends StatefulWidget {
  const _BomTab();

  @override
  State<_BomTab> createState() => _BomTabState();
}

class _BomTabState extends State<_BomTab> with AutomaticKeepAliveClientMixin {
  List<dynamic> _boms = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getBoms();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _boms = result['boms'] ?? [];
    });
  }

  String _stageLabel(String s) => s == 'mixing' ? 'Aralashtirish' : 'Qadoqlash';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final canCreate = FactoryHubApi.role.canControlWarehouses;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _showCreateBom(context),
                icon: const Icon(Icons.add),
                label: const Text('Yangi retsept'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _boms.length,
              itemBuilder: (_, i) {
                final b = _boms[i];
                final isPackaging = b['stage'] == 'packaging';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      isPackaging ? Icons.inventory_2 : Icons.science,
                      color: AppColors.primary,
                    ),
                    title: Text('${b['name']} (${_stageLabel('${b['stage']}')})'),
                    subtitle: Text(
                        'Chiqish: ${b['outputName'] ?? ''} — ${b['outputQtyPerBatch']} ${b['outputUnitLabel'] ?? 'dona'}'),
                    onTap: () => _showBomDetail(context, i),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showBomDetail(BuildContext context, int index) async {
    final b = _boms[index];
    final result = await FactoryHubApi.getBomDetail(b['id']);
    if (!mounted) return;
    if (!context.mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['error']}'), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    final items = (result['items'] ?? []) as List<dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('${b['name']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('${result['bom']['name'] ?? ''} — ${_stageLabel('${result['bom']['stage']}')}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 12),
            Text(
              'Chiqish: ${b['outputName']} — ${b['outputQtyPerBatch']} ${b['outputUnitLabel'] ?? 'dona'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Tarkibi:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    dense: true,
                    title: Text('${it['name'] ?? ''}'),
                    trailing: Text('${it['qty']} ${it['unit'] ?? ''}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (FactoryHubApi.role.canControlWarehouses)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleBomActive(context, b);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('O\'chirish (nofaol qilish)'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritical),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBomActive(BuildContext context, dynamic b) async {
    final result = await FactoryHubApi.updateBom(b['id'], {'is_active': false});
    if (!mounted) return;
    if (!context.mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['error']}'), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retsept o\'chirildi'), backgroundColor: AppColors.statusOk),
    );
    _load();
  }

  Future<void> _showCreateBom(BuildContext context) async {
    final items = await FactoryHubApi.getItems();
    if (!mounted || !context.mounted) return;
    if (!context.mounted) return;
    final itemList = (items['items'] ?? []) as List<dynamic>;
    String? _stage = 'mixing';
    int? _outputItemId;
    final _outputQtyCtrl = TextEditingController(text: '1');
    final List<Map<String, dynamic>> _rows = [];
    final _outName = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('YANGI RETSEPT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _outName,
                    decoration: InputDecoration(
                      labelText: 'Ombordan chiqadigan mahsulot nomi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _stage,
                    items: const [
                      DropdownMenuItem(value: 'mixing', child: Text('Aralashtirish (xom → yarim)')),
                      DropdownMenuItem(value: 'packaging', child: Text('Qadoqlash (yarim → tayyor)')),
                    ],
                    onChanged: (v) => setSheet(() {
                      _stage = v;
                      _outputItemId = null; // stage o'zgarganda chiqish mahsulotini qayta tanlash
                    }),
                    decoration: InputDecoration(
                      labelText: 'Bosqich',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _outputQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Bir partiyadagi chiqish miqdori',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Tarkibiy qismlar:',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  ..._rows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = _rows[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row['nameCtrl'],
                              decoration: const InputDecoration(
                                labelText: 'Nomi',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: row['qtyCtrl'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Miqdori',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: row['unitCtrl'],
                              decoration: const InputDecoration(
                                labelText: 'Birlik',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setSheet(() => _rows.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  TextButton.icon(
                    onPressed: () => setSheet(() => _rows.add({
                      'nameCtrl': TextEditingController(),
                      'qtyCtrl': TextEditingController(),
                      'unitCtrl': TextEditingController(text: 'dona'),
                    })),
                    icon: const Icon(Icons.add),
                    label: const Text('Qo\'shish'),
                  ),
                  const SizedBox(height: 12),
                  if (itemList.isNotEmpty) ...[
                    // BOM stage'iga mos chiqish mahsuloti (item) turlarini aniqlash
                    Builder(builder: (_) {
                      final allowedTypes = _stage == 'mixing'
                          ? ['semi_finished', 'intermediate', 'semi', 'raw', 'material']
                          : ['product', 'finished', 'item'];
                      final filteredItems = itemList.where((it) =>
                          allowedTypes.contains('${it['itemType'] ?? it['item_type']}')
                      ).toList();
                      return DropdownButtonFormField<int>(
                        key: ValueKey('out-${_stage}-${_outputItemId}'),
                        initialValue: _outputItemId,
                        items: filteredItems.map<DropdownMenuItem<int>>((it) =>
                            DropdownMenuItem(
                              value: it['id'],
                              child: Text('${it['name']} (${_itemTypeLabels['${it['itemType'] ?? it['item_type']}'] ?? it['itemType'] ?? ''})'),
                            )).toList(),
                        onChanged: (v) => setSheet(() => _outputItemId = v),
                        decoration: InputDecoration(
                          labelText: 'Chiqish mahsuloti (mos turdagi)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }),
                    if ((_stage == 'mixing' ? ['semi_finished', 'intermediate', 'semi', 'raw', 'material'] : ['product', 'finished', 'item'])
                        .every((t) => itemList.every((it) =>
                            '${it['itemType'] ?? it['item_type']}' != t)))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _stage == 'mixing'
                              ? 'Aralashtirish uchun avval "Yarim/Tayyor" bo\'limida yarim tayyor item yarating.'
                              : 'Qadoqlash uchun avval "Yarim/Tayyor" bo\'limida tayyor mahsulot item yarating.',
                          style: const TextStyle(fontSize: 12, color: AppColors.statusWarning),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (_outName.text.trim().isEmpty || _outputItemId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Nomi va chiqish mahsuloti kerak')),
                        );
                        return;
                      }
                      final itemsPayload = _rows
                          .where((r) => r['nameCtrl']!.text.trim().isNotEmpty &&
                              double.tryParse(r['qtyCtrl']!.text) != null &&
                              (double.tryParse(r['qtyCtrl']!.text) ?? 0) > 0)
                          .map((r) => {
                                'item_type': 'item',
                                'name': r['nameCtrl']!.text.trim(),
                                'qty': double.parse(r['qtyCtrl']!.text),
                                'unit': r['unitCtrl']!.text.trim().isEmpty
                                    ? 'dona'
                                    : r['unitCtrl']!.text.trim(),
                              })
                          .toList();
                      if (itemsPayload.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Kamida bitta tarkibiy qism kerak')),
                        );
                        return;
                      }
                      final res = await FactoryHubApi.createBom({
                        'name': _outName.text.trim(),
                        'stage': _stage,
                        'output_item_id': _outputItemId,
                        'output_qty': double.parse(_outputQtyCtrl.text.isEmpty ? '1' : _outputQtyCtrl.text),
                        'output_unit': _stage == 'mixing' ? 'kg' : 'dona',
                        'items': itemsPayload,
                      });
                      if (!ctx.mounted) return;
                      if (res['error'] != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('${res['error']}'),
                              backgroundColor: AppColors.statusCritical),
                        );
                      } else {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Retsept yaratildi'),
                                backgroundColor: AppColors.statusOk),
                          );
                          _load();
                        }
                      }
                    },
                    child: const Text('Saqlash'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
