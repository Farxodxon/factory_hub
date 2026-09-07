import 'package:flutter/material.dart';

import '../responsive/app_breakpoints.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class ThresholdsScreen extends StatefulWidget {
  const ThresholdsScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

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
    final controller = TextEditingController(text: item['minQty']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Minimal chegarani o'zgartirish"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item['name'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimal qoldiq (dona)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = num.tryParse(controller.text.replaceAll(',', '.'));
    if (value == null || value < 0) return;
    final result = await FactoryHubApi.updateThreshold(item['id'] as int, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['error'] != null ? 'Xato: ${result['error']}' : 'Chegara yangilandi'),
      backgroundColor: result['error'] != null ? AppColors.statusCritical : AppColors.statusOk,
    ));
    if (result['error'] == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final query = _search.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items.where((e) =>
            (e['name'] ?? '').toString().toLowerCase().contains(query) ||
            (e['refKey'] ?? '').toString().contains(query)).toList();

    final lowCount = filtered.where((e) {
      final bal = num.tryParse('${e['balance']}') ?? 0;
      final min = num.tryParse('${e['minQty']}') ?? 0;
      return bal < min;
    }).length;

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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Nom yoki barcode bo'yicha izlash",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.statusCritical),
                  label: Text('$lowCount kam', style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.statusCritical.withValues(alpha: 0.1),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Yozuv yo\'q'))
              : isDesktop
                  ? _buildTable(filtered)
                  : _buildList(filtered),
        ),
      ],
    );
  }

  Widget _buildList(List<dynamic> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final balance = num.tryParse('${e['balance']}') ?? 0;
        final minQty = num.tryParse('${e['minQty']}') ?? 0;
        final isLow = balance < minQty;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: isLow ? AppColors.statusCritical.withValues(alpha: 0.06) : null,
          child: ListTile(
            leading: Icon(
              e['itemType'] == 'product' ? Icons.inventory_2 : Icons.grain,
              color: isLow ? AppColors.statusCritical : AppColors.statusOk,
            ),
            title: Text('${e['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              'Qoldiq: ${_fmt(balance)} | Chegara: ${_fmt(minQty)}',
              style: TextStyle(
                fontSize: 12,
                color: isLow ? AppColors.statusCritical : AppColors.textSecondary,
                fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildTable(List<dynamic> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Turi')),
          DataColumn(label: Text('Qoldiq'), numeric: true),
          DataColumn(label: Text('Chegara'), numeric: true),
          DataColumn(label: Text('Holat')),
          DataColumn(label: Text('Amal')),
        ],
        rows: items.map((e) {
          final balance = num.tryParse('${e['balance']}') ?? 0;
          final minQty = num.tryParse('${e['minQty']}') ?? 0;
          final isLow = balance < minQty;
          return DataRow(
            color: WidgetStateProperty.resolveWith((_) => isLow ? AppColors.statusCritical.withValues(alpha: 0.06) : null),
            cells: [
              DataCell(Text('${e['name']}', maxLines: 2)),
              DataCell(Text(e['itemType'] == 'product' ? 'Mahsulot' : 'Xom ashyo')),
              DataCell(Text('${_fmt(balance)}', style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? AppColors.statusCritical : null))),
              DataCell(Text('${_fmt(minQty)}')),
              DataCell(Chip(
                label: Text(isLow ? 'Kam' : 'Yetarli', style: const TextStyle(fontSize: 11)),
                backgroundColor: isLow ? AppColors.statusCritical.withValues(alpha: 0.15) : AppColors.statusOk.withValues(alpha: 0.15),
                visualDensity: VisualDensity.compact,
              )),
              DataCell(IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _edit(e),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
