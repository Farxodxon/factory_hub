import 'package:flutter/material.dart';

import '../models/user.dart';
import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _ProductsTab(refreshNotifier: refreshNotifier),
              _RawMaterialsTab(refreshNotifier: refreshNotifier),
              _ItemsCatalogTab(refreshNotifier: refreshNotifier),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  const _ProductsTab({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

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
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yangilash'),
            ),
          ),
        ),
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
  const _RawMaterialsTab({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

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

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yangilash'),
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
  const _ItemsCatalogTab({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

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
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yangilash'),
            ),
          ),
        ),
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

  Future<void> _showCreateItem(BuildContext context) =>
      showCreateItemSheet(context, onCreated: _load);

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

Future<void> showCreateItemSheet(BuildContext context, {VoidCallback? onCreated}) async {
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
                    if (context.mounted) onCreated?.call();
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
