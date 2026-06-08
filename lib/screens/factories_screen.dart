import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'factory_detail_screen.dart';

class FactoriesScreen extends StatefulWidget {
  const FactoriesScreen({super.key});

  @override
  State<FactoriesScreen> createState() => _FactoriesScreenState();
}

class _FactoriesScreenState extends State<FactoriesScreen> {
  List _factories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getFactories();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() {
        _factories = (result['factories'] as List?) ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _addFactory() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.factory, color: Color(0xFF0D47A1)),
          SizedBox(width: 8),
          Text('Yangi zavod'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Zavod nomi *',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Manzil',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yaratish'),
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final result = await FactoryHubApi.createFactory(
        name: nameCtrl.text.trim(),
        address: addressCtrl.text.trim(),
      );
      if (result['error'] != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
      } else {
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zavod yaratildi!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _editFactory(Map factory) async {
    final nameCtrl = TextEditingController(text: factory['name']);
    final addressCtrl = TextEditingController(text: factory['address'] ?? '');
    bool isActive = factory['isActive'] ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.edit, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Zavodni tahrirlash'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Zavod nomi *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Manzil', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Faol holat'),
              value: isActive,
              onChanged: (v) => setDialog(() => isActive = v),
              activeColor: const Color(0xFF0D47A1),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final result = await FactoryHubApi.updateFactory(
        factory['id'] as int,
        name: nameCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        isActive: isActive,
      );
      if (result['error'] != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
      } else {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Zavodlar boshqaruvi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFactory,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Yangi zavod'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
                ]))
              : _factories.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.factory_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Zavodlar yo\'q', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Yangi zavod qo\'shish uchun "+" tugmasini bosing', style: TextStyle(color: Colors.grey)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _factories.length,
                        itemBuilder: (_, i) => _buildFactoryCard(_factories[i]),
                      ),
                    ),
    );
  }

  Widget _buildFactoryCard(Map factory) {
    final isActive = factory['isActive'] ?? true;
    final userCount = factory['userCount'] ?? 0;
    final materialCount = factory['materialCount'] ?? 0;
    final warehouseCount = factory['warehouseCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        border: Border.all(color: isActive ? Colors.transparent : Colors.red.shade100),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [const Color(0xFF0D47A1), const Color(0xFF1565C0)]
                  : [Colors.grey.shade400, Colors.grey.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.factory, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(factory['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              if (factory['address'] != null && factory['address'].toString().isNotEmpty)
                Text(factory['address'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade400 : Colors.red.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isActive ? 'Faol' : 'Nofaol',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _statChip(Icons.people, '$userCount xodim', Colors.blue),
            const SizedBox(width: 8),
            _statChip(Icons.inventory_2, '$materialCount material', Colors.purple),
            const SizedBox(width: 8),
            _statChip(Icons.warehouse, '$warehouseCount ombor', Colors.orange),
          ]),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editFactory(factory),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Tahrirlash'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D47A1)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FactoryDetailScreen(factory: factory)),
                ).then((_) => _load()),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Zavodga kirish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ]),
    ));
  }
}
