import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Karantinga qabul', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Qaror (tekshiruv)', icon: Icon(Icons.fact_check_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReceiveTab(refreshNotifier: widget.refreshNotifier),
          _DecideTab(refreshNotifier: widget.refreshNotifier),
        ],
      ),
    );
  }
}

class _ReceiveTab extends StatefulWidget {
  const _ReceiveTab({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<_ReceiveTab> {
  List<dynamic> _items = [];
  List<dynamic> _quarantineWh = [];
  final _qty = TextEditingController();
  final _note = TextEditingController();
  int? _itemId;
  int? _whId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _init();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  List<dynamic> _filterToAccess(List<dynamic> all) {
    final access = FactoryHubApi.userAccess;
    if (access != null && !access.isFullAccess) {
      final ids = access.warehouses.map((w) => w.id).toSet();
      return all.where((w) => ids.contains(w['id'])).toList();
    }
    return all;
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final itemsResult = await FactoryHubApi.getItems();
    final whResult = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    final allWh = (whResult['warehouses'] ?? []) as List<dynamic>;
    final quar = _filterToAccess(allWh)
        .where((w) => w['type'] == 'quarantine')
        .toList();
    setState(() {
      _items = itemsResult['items'] ?? [];
      _quarantineWh = quar;
      _whId = quar.isNotEmpty ? quar.first['id'] as int : null;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text);
    if (_itemId == null || qty == null || qty <= 0 || _whId == null) {
      setState(() => _error = 'Mahsulot, miqdor (>0) va karantin ombori kerak');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await FactoryHubApi.receiveToQuarantine(
      itemId: _itemId!,
      quantity: qty,
      quarantineWarehouseId: _whId!,
      note: _note.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? 'Qabul qilindi'),
      backgroundColor: AppColors.statusOk,
    ));
    setState(() {
      _qty.clear();
      _note.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _init,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _init,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yangilash'),
                  ),
                ),
                Text('Kirish nazorati (karantin omboriga qabul)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _itemId,
                  items: _items.map<DropdownMenuItem<int>>((it) => DropdownMenuItem(
                        value: it['id'],
                        child: Text('${it['name']} (${it['unit'] ?? 'dona'})',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (v) => setState(() => _itemId = v),
                  decoration: InputDecoration(
                    labelText: 'Mahsulot',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _whId,
                  items: _quarantineWh.map<DropdownMenuItem<int>>(
                      (w) => DropdownMenuItem(value: w['id'], child: Text(w['name']))).toList(),
                  onChanged: (v) => setState(() => _whId = v),
                  decoration: InputDecoration(
                    labelText: 'Karantin ombori',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Miqdor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Izoh (ixtiyoriy)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.statusCritical, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: const Text('Karantinga qabul qilish'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          );
  }
}

class _DecideTab extends StatefulWidget {
  const _DecideTab({this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<_DecideTab> createState() => _DecideTabState();
}

class _DecideTabState extends State<_DecideTab> {
  List<dynamic> _quarantineWh = [];
  List<dynamic> _inspections = [];
  int? _whId;
  bool _loading = true;
  bool _loadingList = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshNotifier?.removeListener(_refreshListener);
    widget.refreshNotifier?.addListener(_refreshListener);
  }

  void _refreshListener() {
    if (mounted) _init();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_refreshListener);
    super.dispose();
  }

  List<dynamic> _filterToAccess(List<dynamic> all) {
    final access = FactoryHubApi.userAccess;
    if (access != null && !access.isFullAccess) {
      final ids = access.warehouses.map((w) => w.id).toSet();
      return all.where((w) => ids.contains(w['id'])).toList();
    }
    return all;
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final whResult = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    final allWh = (whResult['warehouses'] ?? []) as List<dynamic>;
    final quar = _filterToAccess(allWh)
        .where((w) => w['type'] == 'quarantine')
        .toList();
    setState(() {
      _quarantineWh = quar;
      _whId = quar.isNotEmpty ? quar.first['id'] as int : null;
      _loading = false;
    });
    if (_whId != null) await _loadInspections();
  }

  Future<void> _loadInspections() async {
    final whId = _whId;
    if (whId == null) return;
    setState(() => _loadingList = true);
    final result = await FactoryHubApi.getPendingInspections(warehouseId: whId);
    if (!mounted) return;
    setState(() {
      _loadingList = false;
      _inspections = result['inspections'] ?? [];
    });
  }

  Future<void> _decide(Map<String, dynamic> insp, String result) async {
    final id = insp['id'] as int;
    setState(() => _busy.add(id));
    final res = await FactoryHubApi.decideInspection(
      id,
      result,
      note: result == 'rejected' ? 'Rad etildi' : null,
    );
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
      return;
    }
    await _loadInspections();
  }

  Future<void> _rejectPrompt(Map<String, dynamic> insp) async {
    final controller = TextEditingController(text: 'Rad etildi');
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rad etish sababi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Sabab', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Rad etish'),
          ),
        ],
      ),
    );
    if (note == null) return;
    final id = insp['id'] as int;
    setState(() => _busy.add(id));
    final res = await FactoryHubApi.decideInspection(id, 'rejected', note: note);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (res['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
      return;
    }
    await _loadInspections();
  }

  @override
  Widget build(BuildContext context) {
    final canAct = FactoryHubApi.role.canTransactStock;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _loadInspections,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yangilash'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: DropdownButtonFormField<int>(
                  initialValue: _whId,
                  items: _quarantineWh.map<DropdownMenuItem<int>>((w) =>
                      DropdownMenuItem(value: w['id'], child: Text(w['name']))).toList(),
                  onChanged: (v) {
                    setState(() => _whId = v);
                    _loadInspections();
                  },
                  decoration: InputDecoration(
                    labelText: 'Karantin ombori',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _loadingList
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadInspections,
                        child: _inspections.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 40),
                                  Center(
                                    child: Text('Kutilayotgan tekshiruvlar yo\'q',
                                        style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _inspections.length,
                                itemBuilder: (_, i) => _inspectionCard(_inspections[i], canAct),
                              ),
                      ),
              ),
            ],
          );
  }

  Widget _inspectionCard(Map<String, dynamic> insp, bool canAct) {
    final id = insp['id'] as int;
    final busy = _busy.contains(id);
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
                  child: Text(insp['itemName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text('${insp['quantity']} ${insp['unit'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            if (insp['note'] != null && '${insp['note']}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Izoh: ${insp['note']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 8),
            if (canAct)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _decide(insp, 'approved'),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(insp['itemType'] == 'semi_finished'
                          ? 'Tasdiqlash → Yarim tayyor'
                          : 'Tasdiqlash → Xom-ashyo'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.statusOk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _rejectPrompt(insp),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rad etish → Brak'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusCritical),
                    ),
                  ),
                ],
              )
            else
              const Text('Sizga qaror berish huquqi berilmagan',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}