import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [Tab(text: 'Mahsulotlar'), Tab(text: 'Xom ashyolar')],
          ),
        ),
        body: const TabBarView(children: [_ProductsTab(), _RawMaterialsTab()]),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Nom yoki barcode bo\'yicha qidirish',
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
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (_, i) {
                    final p = _products[i];
                    return ListTile(
                      dense: true,
                      title: Text(p['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${p['barcode']} | ${p['pcsInBox'] ?? 0} dona/quti'),
                      trailing: Text('Qoldiq: ${p['stock'] ?? 0}'),
                    );
                  },
                ),
        ),
      ],
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
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _materials.length,
              itemBuilder: (_, i) {
                final m = _materials[i];
                return ListTile(
                  title: Text(m['name'] ?? ''),
                  subtitle: Text(m['code'] ?? ''),
                  trailing: Text(
                    '${m['stock']} ${m['unit'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          );
  }
}
