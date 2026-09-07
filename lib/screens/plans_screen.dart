import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;

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
    final result = await FactoryHubApi.getPlans();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _plans = result['plans'] ?? [];
    });
  }

  Future<void> _createPlan() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreatePlanSheet(),
    );
    if (created == true) _load();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'planned':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.statusWarning;
      case 'done':
        return AppColors.statusOk;
      default:
        return AppColors.statusCritical;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FactoryHubApi.role.canPlan
          ? FloatingActionButton.extended(
              heroTag: 'fab_plans',
              onPressed: _createPlan,
              icon: const Icon(Icons.add),
              label: const Text('Reja'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _plans.length,
                      itemBuilder: (_, i) {
                  final p = _plans[i];
                  final progress = p['targetQty'] > 0
                      ? ((p['producedQty'] ?? 0) / p['targetQty']).clamp(0.0, 1.0)
                      : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                              Chip(
                                label: Text(p['status'] ?? '', style: const TextStyle(fontSize: 11)),
                                backgroundColor: _statusColor(p['status']).withValues(alpha: 0.2),
                              ),
                            ],
                          ),
                          if (p['productName'] != null) Text(p['productName'], maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 6),
                          Text('${p['producedQty'] ?? 0} / ${p['targetQty']} dona'),
                          if (p['dueDate'] != null)
                            Text('Muddat: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(p['dueDate']))}'),
                          if (FactoryHubApi.role.canPlan && p['status'] != 'done' && p['status'] != 'cancelled')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (p['status'] == 'planned')
                                  TextButton(
                                    onPressed: () async {
                                      await FactoryHubApi.updatePlanStatus(p['id'], 'in_progress');
                                      _load();
                                    },
                                    child: const Text('Boshlash'),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    final edited = await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => _EditPlanSheet(plan: p),
                                    );
                                    if (edited == true) _load();
                                  },
                                  child: const Text('Tahrirlash'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await FactoryHubApi.updatePlanStatus(p['id'], 'cancelled');
                                    _load();
                                  },
                                  child: const Text('Bekor', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                        ],
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

class _EditPlanSheet extends StatefulWidget {
  const _EditPlanSheet({required this.plan});
  final Map<String, dynamic> plan;

  @override
  State<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends State<_EditPlanSheet> {
  late final TextEditingController _title;
  late final TextEditingController _qty;
  DateTime? _dueDate;
  List<dynamic> _products = [];
  Map<String, dynamic>? _selectedProduct;
  String? _error;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plan['title'] ?? '');
    _qty = TextEditingController(text: widget.plan['targetQty']?.toString() ?? '');
    final dd = widget.plan['dueDate'];
    if (dd != null) _dueDate = DateTime.tryParse(dd);
    _loadProducts();
  }

  @override
  void dispose() {
    _title.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final result = await FactoryHubApi.getProducts();
    if (!mounted) return;
    final products = result['products'] ?? [];
    final currentBarcode = widget.plan['barcode'];
    Map<String, dynamic>? matched;
    if (currentBarcode != null) {
      for (final p in products) {
        if (p['barcode']?.toString() == currentBarcode.toString()) {
          matched = p;
          break;
        }
      }
    }
    setState(() {
      _loadingProducts = false;
      _products = products;
      _selectedProduct = matched;
    });
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text);
    if (_title.text.trim().isEmpty || qty == null || qty <= 0) {
      setState(() => _error = "Sarlavha va miqdor (>0) majburiy");
      return;
    }
    final result = await FactoryHubApi.updatePlan(widget.plan['id'], {
      'title': _title.text.trim(),
      'barcode': _selectedProduct?['barcode'] ?? widget.plan['barcode'],
      'target_qty': qty,
      'due_date': _dueDate?.toIso8601String().substring(0, 10),
    });
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
            Text("Rejani tahrirlash", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'Sarlavha',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedProduct,
                    isExpanded: true,
                    items: _products.map((p) {
                      return DropdownMenuItem(
                        value: p as Map<String, dynamic>,
                        child: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedProduct = v),
                    decoration: InputDecoration(
                      labelText: 'Mahsulot (ixtiyoriy)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Rejadagi miqdor (dona)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _dueDate == null ? 'Muddat tanlash' : 'Muddat: ${DateFormat('dd.MM.yyyy').format(_dueDate!)}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}

class _CreatePlanSheet extends StatefulWidget {
  const _CreatePlanSheet();

  @override
  State<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<_CreatePlanSheet> {
  final _title = TextEditingController();
  final _qty = TextEditingController();
  DateTime? _dueDate;
  List<dynamic> _products = [];
  Map<String, dynamic>? _selectedProduct;
  String? _error;
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final result = await FactoryHubApi.getProducts();
    if (!mounted) return;
    setState(() {
      _loadingProducts = false;
      _products = result['products'] ?? [];
    });
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text);
    if (_title.text.trim().isEmpty || qty == null || qty <= 0) {
      setState(() => _error = "Sarlavha va miqdor (>0) majburiy");
      return;
    }

    final result = await FactoryHubApi.createPlan({
      'title': _title.text.trim(),
      'barcode': _selectedProduct?['barcode'],
      'target_qty': qty,
      'due_date': _dueDate?.toIso8601String().substring(0, 10),
    });
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Yangi reja", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'Sarlavha',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _loadingProducts
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedProduct,
                    isExpanded: true,
                    items: _products.map((p) {
                      return DropdownMenuItem(
                        value: p as Map<String, dynamic>,
                        child: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedProduct = v),
                    decoration: InputDecoration(
                      labelText: 'Mahsulot (ixtiyoriy)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Rejadagi miqdor (dona)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _dueDate == null
                    ? 'Muddat tanlash'
                    : 'Muddat: ${DateFormat('dd.MM.yyyy').format(_dueDate!)}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Saqlash')),
          ],
        ),
      ),
    );
  }
}
