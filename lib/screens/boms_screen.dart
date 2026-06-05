import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BomsScreen extends StatefulWidget {
  const BomsScreen({super.key});
  @override
  State<BomsScreen> createState() => _BomsScreenState();
}

class _BomsScreenState extends State<BomsScreen> {
  List _boms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getBoms();
    setState(() {
      _boms = (result['boms'] as List?) ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mahsulot tarkiblari (BOM)'), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: _boms.isEmpty ? const Center(child: Text('BOM yo\'q')) : ListView.builder(
          itemCount: _boms.length,
          itemBuilder: (ctx, i) {
            final b = _boms[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
              title: Text(b['name'] ?? ''), subtitle: Text('V:${b['version']} | ${b['productionType']}'),
              trailing: b['isActive'] == true ? const Chip(label: Text('Faol'), backgroundColor: Colors.green) : const Chip(label: Text('Faol emas')),
            ));
          },
        ),
      ),
    );
  }
}
