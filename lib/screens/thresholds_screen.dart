import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ThresholdsScreen extends StatefulWidget {
  const ThresholdsScreen({super.key});

  @override
  State<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FactoryHubApi.getThresholds();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] == null) {
        _items = result['thresholds'] as List<dynamic>? ?? [];
      }
    });
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final controller =
        TextEditingController(text: item['minQty']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Minimal chegarani o\'zgartirish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item['name'] ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimal qoldiq (dona)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = num.tryParse(controller.text.replaceAll(',', '.'));
    if (value == null || value < 0) return;
    final result =
        await FactoryHubApi.updateThreshold(item['id'] as int, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['error'] != null
          ? 'Xato: ${result['error']}'
          : 'Chegara yangilandi'),
    ));
    if (result['error'] == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items
            .where((e) =>
                (e['name'] ?? '').toString().toLowerCase().contains(query) ||
                (e['refKey'] ?? '').toString().contains(query))
            .toList();

    final lowCount = filtered.where((e) {
      final bal = num.tryParse('${e['balance']}') ?? 0;
      final min = num.tryParse('${e['minQty']}') ?? 0;
      return bal < min;
    }).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Nom yoki barcode bo\'yicha izlash',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Jami: ${filtered.length}'),
                const Spacer(),
                if (lowCount > 0)
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded,
                        size: 18, color: Colors.red),
                    label: Text('$lowCount kam'),
                    backgroundColor: Colors.red.shade50,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Yozuv yoq'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final balance = num.tryParse('${e['balance']}') ?? 0;
                      final minQty = num.tryParse('${e['minQty']}') ?? 0;
                      final isLow = balance < minQty;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: isLow ? Colors.red.shade50 : null,
                        child: ListTile(
                          leading: Icon(
                            e['itemType'] == 'product'
                                ? Icons.inventory_2
                                : Icons.grain,
                            color: isLow ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            '${e['name']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'Qoldiq: ${_fmt(balance)} | Chegara: ${_fmt(minQty)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLow ? Colors.red.shade700 : null,
                              fontWeight:
                                  isLow ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: "Chegarani o'zgartirish",
                            onPressed: () => _edit(e),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
