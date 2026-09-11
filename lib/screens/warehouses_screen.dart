import 'package:flutter/material.dart';

import '../models/user.dart';
import '../responsive/app_breakpoints.dart';

import '../services/api_service.dart';
import '../theme/colors.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<dynamic> _warehouses = [];
  String? _error;
  bool _loading = true;
  int? _selectedId;
  Map<int, int> _pendingCounts = {};

  static const Map<String, String> _typeLabels = {
    'raw': 'Xom ashyo',
    'production': 'Ishlab chiqarish (WIP)',
    'semi_finished': 'Yarim tayyor',
    'packaging': 'Qadoqlash mat.',
    'finished': 'Tayyor mahsulot',
    'purchased_finished': 'Sotib olingan tayyor',
    'purchased_semi': 'Sotib olingan yarim',
    'spare_parts': 'Ehtiyot qismlar',
    'sales': 'Sotuv',
    'dealer': 'Dilerlar',
    'quarantine': 'Karantin/tekshiruv',
    'defective': 'Brak/nikoz',
    'returned': 'Qaytarilgan mahsulot',
    'retain_sample': 'Namuna (retain sample)',
    'empty_container': "Bo'shagan idish/tara",
    'other': 'Aralash (xo\'jalik, kantstovar)',
  };

  static const Map<String, IconData> _typeIcons = {
    'raw': Icons.science,
    'production': Icons.precision_manufacturing,
    'semi_finished': Icons.handyman,
    'packaging': Icons.inventory,
    'finished': Icons.inventory_2,
    'purchased_finished': Icons.shopping_bag,
    'purchased_semi': Icons.token,
    'spare_parts': Icons.build,
    'sales': Icons.shopping_cart,
    'dealer': Icons.store,
    'quarantine': Icons.health_and_safety,
    'defective': Icons.error_outline,
    'returned': Icons.assignment_return,
    'retain_sample': Icons.science_outlined,
    'empty_container': Icons.delete_sweep,
    'other': Icons.category,
  };

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
    final result = await FactoryHubApi.getWarehouses();
    final counts = await FactoryHubApi.getPendingCounts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _warehouses = result['warehouses'] ?? [];
        _error = null;
      }
      final map = <int, int>{};
      for (final c in (counts['counts'] as List?) ?? []) {
        final id = c['warehouseId'];
        if (id is int) map[id] = (c['count'] as num?)?.toInt() ?? 0;
      }
      _pendingCounts = map;
    });
  }

  Future<void> _createWarehouse() async {
    if (!FactoryHubApi.role.canControlWarehouses) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateWarehouseSheet(),
    );
    if (created == true) _load();
  }

  Future<void> _deleteWarehouse(int id, String name) async {
    if (!FactoryHubApi.role.canControlWarehouses) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Omborni o\'chirish — $name'),
        content: const Text(
          'Bu ombor va uning zaxirasi, transferlari, yo\'qotish yozuvlari o\'chiriladi. Bu amalni qaytarib bo\'lmaydi. Davom etasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritical),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await FactoryHubApi.deleteWarehouse(id);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: ${result['error']}'), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    setState(() {
      _warehouses.removeWhere((w) => w['id'] == id);
      if (_selectedId == id) _selectedId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ombor o\'chirildi'), backgroundColor: AppColors.statusOk),
    );
  }

  void _onWarehouseSelected(int id) {
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      );
    }

    final isDesktop = AppBreakpoints.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopView();
    }
    return _buildMobileView();
  }

  Widget _buildMobileView() {
    return Scaffold(
      floatingActionButton: FactoryHubApi.role.canControlWarehouses
          ? FloatingActionButton.extended(
              heroTag: 'fab_warehouses',
              onPressed: _createWarehouse,
              icon: const Icon(Icons.add),
              label: const Text('Ombor'),
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
                      itemCount: _warehouses.length,
                      itemBuilder: (_, i) => _buildWarehouseCard(_warehouses[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopView() {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Scaffold(
            floatingActionButton: FactoryHubApi.role.canControlWarehouses
                ? FloatingActionButton(
                    heroTag: 'fab_warehouses',
                    onPressed: _createWarehouse,
                    child: const Icon(Icons.add),
                  )
                : null,
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.warehouse, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Omborlar (${_warehouses.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (FactoryHubApi.role.canControlWarehouses && _selectedId != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.statusCritical),
                                tooltip: 'Tanlangan omborni o\'chirish',
                                onPressed: () {
                                  final w = _warehouses.where((x) => x['id'] == _selectedId).toList();
                                  if (w.isNotEmpty) _deleteWarehouse(w.first['id'], w.first['name'] ?? '');
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Yangilash',
                              onPressed: _load,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _warehouses.length,
                            itemBuilder: (_, i) {
                              final w = _warehouses[i];
                              final isSelected = _selectedId == w['id'];
                              final pending = (_pendingCounts[w['id']] ?? 0);
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  leading: Icon(
                                    _typeIcons[w['type']] ?? Icons.warehouse,
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  title: Text(w['name'] ?? ''),
                                  subtitle: Text(_typeLabels[w['type']] ?? w['type'] ?? ''),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (pending > 0) ...[
                                        _pendingBadge(pending),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        '${w['itemCount'] ?? 0}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if (FactoryHubApi.role.canControlWarehouses)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.statusCritical),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'O\'chirish',
                                          onPressed: () => _deleteWarehouse(w['id'], w['name'] ?? ''),
                                        ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primaryBg,
                                  onTap: () => _onWarehouseSelected(w['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedId != null
              ? WarehouseDetailScreen(id: _selectedId!, key: ValueKey(_selectedId))
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 64, color: AppColors.divider),
                      SizedBox(height: 12),
                      Text('Omborni tanlang', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pendingBadge(int count) {
    return Tooltip(
      message: 'Qabul tasdiqlash kutilmoqda ($count)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.statusWarning,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rule, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCard(Map<String, dynamic> w) {
    final pending = (_pendingCounts[w['id']] ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_typeIcons[w['type']] ?? Icons.warehouse, color: AppColors.primary),
        title: Text(w['name'] ?? ''),
        subtitle: Text(_typeLabels[w['type']] ?? w['type'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending > 0) ...[
              _pendingBadge(pending),
              const SizedBox(width: 6),
            ],
            Text('${w['itemCount'] ?? 0} element'),
            if (FactoryHubApi.role.canControlWarehouses) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.statusCritical),
                visualDensity: VisualDensity.compact,
                tooltip: 'O\'chirish',
                onPressed: () => _deleteWarehouse(w['id'], w['name'] ?? ''),
              ),
            ],
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WarehouseDetailScreen(id: w['id'])),
          );
          _load();
        },
      ),
    );
  }
}

class WarehouseDetailScreen extends StatefulWidget {
  const WarehouseDetailScreen({required this.id, super.key});

  final int id;

  @override
  State<WarehouseDetailScreen> createState() => WarehouseDetailScreenState();
}

class WarehouseDetailScreenState extends State<WarehouseDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;
  List<dynamic> _transactions = [];
  bool _loadingTransactions = false;
  List<dynamic> _transfers = [];
  bool _loadingTransfers = false;
  List<dynamic> _pendingTransfers = [];
  final Set<int> _pendingBusy = {};
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getWarehouseDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else if (result['warehouse'] == null) {
        _error = 'Ombor ma\'lumotlari topilmadi';
      } else {
        _detail = result;
        _error = null;
      }
    });
    _loadTransactions();
    _loadTransfers();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTransactions = true);
    final result = await FactoryHubApi.getWarehouseTransactions(widget.id);
    if (!mounted) return;
    setState(() {
      _loadingTransactions = false;
      _transactions = result['transactions'] ?? [];
    });
  }

  Future<void> _loadTransfers() async {
    setState(() => _loadingTransfers = true);
    final result = await FactoryHubApi.getTransfers();
    final pendingResult = await FactoryHubApi.getPendingTransfers(warehouseId: widget.id);
    if (!mounted) return;
    final all = result['transfers'] ?? [];
    setState(() {
      _loadingTransfers = false;
      _transfers = all.where((t) =>
        t['fromWarehouse'] != null || t['toWarehouse'] != null
      ).toList();
      _pendingTransfers = pendingResult['transfers'] ?? [];
    });
  }

  Future<void> _confirmPending(Map<String, dynamic> t) async {
    final id = t['id'] as int;
    setState(() => _pendingBusy.add(id));
    final result = await FactoryHubApi.confirmTransfer(id);
    if (!mounted) return;
    setState(() => _pendingBusy.remove(id));
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    _load();
  }

  Future<void> _rejectPendingPrompt(Map<String, dynamic> t) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rad etish sababi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Sabab',
            border: OutlineInputBorder(),
          ),
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
    if (reason == null) return;
    final id = t['id'] as int;
    setState(() => _pendingBusy.add(id));
    final result = await FactoryHubApi.rejectTransfer(id, reason);
    if (!mounted) return;
    setState(() => _pendingBusy.remove(id));
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    _load();
  }

  Future<void> _createTransfer() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferSheet(fromWarehouseId: widget.id),
    );
    if (done == true && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer yuborildi. Qabul qiluvchi ombor tasdiqlashini kutmoqda'),
          backgroundColor: AppColors.statusOk,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addTransaction(String direction) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionSheet(
        warehouseId: widget.id,
        direction: direction,
        warehouseType: _detail?['warehouse']?['type'] ?? 'raw',
      ),
    );
    if (done == true && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(direction == 'in' ? 'Kirim muvaffaqiyatli qo\'shildi' : 'Chiqim muvaffaqiyatli qo\'shildi'),
          backgroundColor: AppColors.statusOk,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = _detail?['warehouse'];
    final stock = _detail?['stock'] as List<dynamic>? ?? [];
    final isDesktop = AppBreakpoints.isDesktop(context);
    // Imkoniyatlar (ombor sozlamalarida foydalanuvchi tomonidan biriktiriladi):
    final canIncome = warehouse?['canIncome'] == true;
    final canExpense = warehouse?['canExpense'] == true;
    final canTransfer = warehouse?['canTransfer'] == true;
    final canManualIn = canIncome;
    final canManualOut = canExpense;
    final canTransferFrom = canTransfer;
    final showFabs =
        FactoryHubApi.role.canTransactStock &&
        (canManualIn || canManualOut || canTransferFrom);

    final List<Widget> fabButtons = [];
    if (canManualIn) {
      fabButtons.add(isDesktop
          ? FloatingActionButton.extended(
              heroTag: 'in',
              onPressed: () => _addTransaction('in'),
              icon: const Icon(Icons.call_received),
              label: const Text('Kirim'),
              backgroundColor: AppColors.statusOk,
            )
          : FloatingActionButton.small(
              heroTag: 'in',
              onPressed: () => _addTransaction('in'),
              backgroundColor: AppColors.statusOk,
              child: const Icon(Icons.call_received),
            ));
    }
    if (canManualOut) {
      fabButtons.add(isDesktop
          ? FloatingActionButton.extended(
              heroTag: 'out',
              onPressed: () => _addTransaction('out'),
              icon: const Icon(Icons.outbound),
              label: const Text('Chiqim'),
              backgroundColor: AppColors.statusWarning,
            )
          : FloatingActionButton.small(
              heroTag: 'out',
              onPressed: () => _addTransaction('out'),
              backgroundColor: AppColors.statusWarning,
              child: const Icon(Icons.outbound),
            ));
    }
    if (canTransferFrom) {
      fabButtons.add(isDesktop
          ? FloatingActionButton.extended(
              heroTag: 'transfer',
              onPressed: _createTransfer,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transfer'),
              backgroundColor: AppColors.gold,
            )
          : FloatingActionButton.small(
              heroTag: 'transfer',
              onPressed: _createTransfer,
              backgroundColor: AppColors.gold,
              child: const Icon(Icons.swap_horiz),
            ));
    }
    // FAB orasidagi spacing
    final spaced = <Widget>[];
    for (var i = 0; i < fabButtons.length; i++) {
      if (i > 0) spaced.add(isDesktop ? const SizedBox(width: 8) : const SizedBox(height: 8));
      spaced.add(fabButtons[i]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(warehouse?['name'] ?? 'Ombor'),
        actions: [
          if (FactoryHubApi.role.canControlWarehouses && warehouse != null)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Imkoniyatlar',
              onPressed: () async {
                final updated = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _EditWarehouseSheet(
                    warehouseId: widget.id,
                    warehouse: warehouse,
                  ),
                );
                if (updated == true) _load();
              },
            ),
          if (FactoryHubApi.role.canControlWarehouses && warehouse != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.statusCritical),
              tooltip: 'Omborni o\'chirish',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Omborni o\'chirish — ${warehouse['name']}'),
                    content: const Text(
                      'Bu ombor va uning zaxirasi, transferlari, yo\'qotish yozuvlari o\'chiriladi. Bu amalni qaytarib bo\'lmaydi. Davom etasizmi?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Bekor qilish'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritical),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('O\'chirish'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final result = await FactoryHubApi.deleteWarehouse(widget.id);
                  if (mounted) {
                    if (result['error'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Xatolik: ${result['error']}'), backgroundColor: AppColors.statusCritical),
                      );
                    } else {
                      Navigator.pop(context, true);
                    }
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: showFabs
          ? (isDesktop ? Row(mainAxisSize: MainAxisSize.min, children: spaced) : Column(mainAxisSize: MainAxisSize.min, children: spaced))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.statusCritical),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                )
              : Column(
                children: [
                  if (_pendingTransfers.isNotEmpty)
                    InkWell(
                      onTap: () => _tabController.animateTo(2),
                      child: Container(
                        width: double.infinity,
                        color: AppColors.statusWarning.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.rule, color: AppColors.statusWarning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Qabul tasdiqlash kutilmoqda (${_pendingTransfers.length})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(icon: Icon(Icons.inventory_2), text: 'Qoldiq'),
                      Tab(icon: Icon(Icons.history), text: 'Tarix'),
                      Tab(icon: Icon(Icons.swap_horiz), text: 'Transfer'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        RefreshIndicator(
                          onRefresh: _load,
                          child: stock.isEmpty
                              ? const Center(child: Text('Bu omborda qoldiq yo\'q'))
                              : isDesktop
                                  ? _buildStockTable(stock)
                                  : _buildStockList(stock),
                        ),
                        _buildTransactionList(),
                        _buildTransferList(),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTransactionList() {
    if (_loadingTransactions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_transactions.isEmpty) {
      return const Center(child: Text('Hali tranzaksiya yo\'q'));
    }
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _transactions.length,
        itemBuilder: (_, i) {
          final t = _transactions[i];
          final isIn = t['direction'] == 'in';
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isIn ? AppColors.statusOk.withValues(alpha: 0.15) : AppColors.statusWarning.withValues(alpha: 0.15),
                child: Icon(
                  isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIn ? AppColors.statusOk : AppColors.statusWarning,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  if ((t['code'] ?? t['refBarcode'] ?? t['refId']) != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${t['code'] ?? t['refBarcode'] ?? t['refId'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white),
                      ),
                    ),
                  if ((t['code'] ?? t['refBarcode'] ?? t['refId']) != null) const SizedBox(width: 6),
                  Expanded(child: Text(t['name'] ?? '', style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              subtitle: Text(
                '${isIn ? "Kirim" : "Chiqim"}${t['performedBy'] != null ? " • ${t['performedBy']}" : ""}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIn ? "+" : "-"}${t['qty']} ${t['unit'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIn ? AppColors.statusOk : AppColors.statusWarning,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatDate(t['createdAt']),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStockList(List<dynamic> stock) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: stock.length,
      itemBuilder: (_, i) {
        final item = stock[i];
        final refKey = item['refKey']?.toString() ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Icon(
              item['itemType'] == 'product' ? Icons.inventory_2 : Icons.science,
              color: AppColors.primary,
            ),
            title: Row(
              children: [
                if (refKey.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item['itemType'] == 'raw_material' ? AppColors.primary : AppColors.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      refKey,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white),
                    ),
                  ),
                if (refKey.isNotEmpty) const SizedBox(width: 8),
                Expanded(child: Text(item['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            subtitle: Text(item['itemType'] ?? ''),
            trailing: Text(
              '${item['balance']} ${item['unit'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            onLongPress: FactoryHubApi.role.canTransactStock
                ? () => _showWriteOffDialog(item)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildStockTable(List<dynamic> stock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Kod')),
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Turi')),
          DataColumn(label: Text('Qoldiq'), numeric: true),
          DataColumn(label: Text('Birlik')),
          DataColumn(label: Text('Amal')),
        ],
        rows: stock.map((item) {
          final refKey = item['refKey']?.toString() ?? '';
          return DataRow(cells: [
            DataCell(
              refKey.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        refKey,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                      ),
                    )
                  : const Text(''),
            ),
            DataCell(Text(item['name'] ?? '')),
            DataCell(Text(item['itemType'] ?? '')),
            DataCell(Text('${item['balance']}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(item['unit'] ?? '')),
            DataCell(
              FactoryHubApi.role.canTransactStock
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _showWriteOffDialog(item),
                    )
                  : const Text(''),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Future<void> _showWriteOffDialog(Map<String, dynamic> item) async {
    final qtyCtrl = TextEditingController(text: '${item['balance']}');
    final reasonCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final balance = double.tryParse('${item['balance']}') ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yo\'qotish: ${item['name'] ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Miqdor (max $balance)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Sabab (majburiy)',
                hintText: 'masalan: muddati o\'tgan, shikastlangan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Izoh',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusCritical),
            child: const Text('Hisobdan chiqarish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final qty = double.tryParse(qtyCtrl.text);
    final reason = reasonCtrl.text.trim();
    if (qty == null || qty <= 0 || qty > balance + 0.0001 || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miqdor va sabab to\'g\'ri kiritilmagan'),
            backgroundColor: AppColors.statusCritical),
      );
      return;
    }

    final result = await FactoryHubApi.writeOff({
      'warehouse_id': _detail?['warehouse']?['id'],
      'item_type': item['itemType'],
      'ref_id': item['refId'],
      'ref_barcode': item['refBarcode'],
      'name': item['name'],
      'unit': item['unit'],
      'qty': qty,
      'reason': reason,
      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error'] ?? result['message'] ?? ''),
          backgroundColor: result['error'] != null ? AppColors.statusCritical : AppColors.statusOk),
    );
    _load();
  }

  Widget _buildTransferList() {
    if (_loadingTransfers) return const Center(child: CircularProgressIndicator());
    final canAct = FactoryHubApi.role.canTransactStock;
    return RefreshIndicator(
      onRefresh: _loadTransfers,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_pendingTransfers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Qabul qilish kutilmoqda (${_pendingTransfers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            ..._pendingTransfers.map((t) => _buildPendingCard(t, canAct)),
            const Divider(height: 24),
          ],
          Text('Tarix',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          if (_transfers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Hali transfer yo\'q')),
            )
          else
            ..._transfers.map((t) => _buildHistoryCard(t)),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> t, bool canAct) {
    final id = t['id'] as int;
    final busy = _pendingBusy.contains(id);
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
                  child: Text(t['itemName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text('${t['quantity']} ${t['unit'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Manba: ${t['sourceName'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (t['createdByName'] != null && '${t['createdByName']}'.isNotEmpty)
              Text('Yaratdi: ${t['createdByName']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (canAct) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _confirmPending(t),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Qabul qilish'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.statusOk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _rejectPendingPrompt(t),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rad etish'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusCritical),
                    ),
                  ),
                ] else
                  const Text('Sizga tasdiqlash huquqi berilmagan',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> t) {
    final status = t['status'] ?? '';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    final isSale = t['isSale'] == true;
    final color = isCompleted
        ? AppColors.statusOk
        : isCancelled
            ? AppColors.statusCritical
            : AppColors.statusWarning;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isCompleted ? (isSale ? Icons.payments : Icons.check) : isCancelled ? Icons.close : Icons.hourglass_empty,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          '${t['fromWarehouse'] ?? ''} → ${t['toWarehouse'] ?? ''}${isSale ? "  (SOTUV)" : ""}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${t['itemCount'] ?? 0} ta mahsulot • ${t['createdBy'] ?? ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isCompleted ? 'Bajarildi' : isCancelled ? 'Bekor qilindi' : 'Kutilmoqda',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({
    required this.warehouseId,
    required this.direction,
    required this.warehouseType,
  });

  final int warehouseId;
  final String direction;
  final String warehouseType;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<dynamic> _items = [];
  int? _selectedRawId;
  String? _selectedRawName;
  String? _selectedBarcode;
  String? _selectedProductName;
  late String _selectedType;
  String? _error;
  bool _loadingItems = true;
  bool _regime51 = false;

  bool get _isRawWarehouse => widget.warehouseType == 'raw';
  bool get _isFinishedWarehouse => widget.warehouseType == 'finished';
  bool get _showTypeSelector => !_isRawWarehouse && !_isFinishedWarehouse;

  List<dynamic> get _filteredItems {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final code = (e['code'] ?? '').toString().toLowerCase();
      final barcode = (e['barcode'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || barcode.contains(q);
    }).toList();
  }

  bool get _hasSelection =>
      (_selectedType == 'raw_material' && _selectedRawId != null) ||
      (_selectedType == 'product' && _selectedBarcode != null);

  @override
  void initState() {
    super.initState();
    if (_isRawWarehouse) {
      _selectedType = 'raw_material';
    } else if (_isFinishedWarehouse) {
      _selectedType = 'product';
    } else {
      _selectedType = 'raw_material';
    }
    _loadItems();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final result =
        _selectedType == 'product' ? await FactoryHubApi.getProducts() : await FactoryHubApi.getRawMaterials();
    if (!mounted) return;
    setState(() {
      _loadingItems = false;
      _items = result['error'] != null
          ? []
          : (_selectedType == 'product' ? result['products'] : result['rawMaterials']) ?? [];
      _selectedRawId = null;
      _selectedRawName = null;
      _selectedBarcode = null;
      _selectedProductName = null;
      _searchCtrl.clear();
    });
  }

  void _selectItem(Map<String, dynamic> item) {
    setState(() {
      if (_selectedType == 'raw_material') {
        _selectedRawId = item['id'] != null ? int.tryParse(item['id'].toString()) : null;
        _selectedRawName = item['name']?.toString();
        _searchCtrl.text = '${item['code'] ?? ''} — ${item['name'] ?? ''}';
      } else {
        _selectedBarcode = item['barcode']?.toString();
        _selectedProductName = item['name']?.toString();
        _searchCtrl.text = '${item['barcode'] ?? ''} — ${item['name'] ?? ''}';
      }
    });
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qty.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _error = "Miqdorni to'g'ri kiriting");
      return;
    }

    if (!_hasSelection) {
      setState(() => _error = 'Element tanlang');
      return;
    }

    final data = <String, dynamic>{
      'warehouse_id': widget.warehouseId,
      'item_type': _selectedType,
      'direction': widget.direction,
      'qty': qty,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    };
    // 51-rejim bayrog'i faqat xom-ashyo qabul (kirim) uchun yuboriladi
    if (_selectedType == 'raw_material' && widget.direction == 'in') {
      data['is_regime_51'] = _regime51;
    }
    if (_selectedType == 'raw_material') {
      data['ref_id'] = _selectedRawId;
    } else {
      data['ref_barcode'] = _selectedBarcode;
    }

    final result = await FactoryHubApi.addTransaction(data);
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
            Text(
              widget.direction == 'in' ? 'KIRIM' : 'CHIQIM',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _isRawWarehouse ? 'Xom ashyo ombori' : _isFinishedWarehouse ? 'Tayyor mahsulot ombori' : '',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_showTypeSelector) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'raw_material', label: Text('Xom ashyo')),
                  ButtonSegment(value: 'product', label: Text('Mahsulot')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (s) {
                  setState(() {
                    _selectedType = s.first;
                    _loadingItems = true;
                  });
                  _loadItems();
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _selectedType == 'raw_material'
                    ? 'Kod yoki nom bo\'yicha qidirish'
                    : 'Nom yoki barcode bo\'yicha qidirish',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _selectedRawId = null;
                            _selectedRawName = null;
                            _selectedBarcode = null;
                            _selectedProductName = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_hasSelection) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.statusOk),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedType == 'raw_material' ? _selectedRawName! : _selectedProductName!,
                        style: const TextStyle(fontSize: 12, color: AppColors.statusOk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_loadingItems)
              const Center(child: CircularProgressIndicator())
            else if (_filteredItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Element topilmadi', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredItems.length,
                  itemBuilder: (_, i) {
                    final item = _filteredItems[i];
                    final isSelected = _selectedType == 'raw_material'
                        ? item['id']?.toString() == _selectedRawId?.toString()
                        : item['barcode']?.toString() == _selectedBarcode;
                    return InkWell(
                      onTap: () => _selectItem(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: isSelected ? AppColors.primaryBg : null,
                        child: Row(
                          children: [
                            if (_selectedType == 'raw_material') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item['code'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item['name'] ?? ''}',
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['name'] ?? ''}',
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item['barcode'] ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
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
            // 51-bojxona rejimi belgisi (faqat xom-ashyo qabulida ko'rsatiladi)
            if (widget.direction == 'in' && _selectedType == 'raw_material') ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _regime51,
                onChanged: (v) => setState(() => _regime51 = v ?? false),
                title: const Text(
                  'Bu partiya 51-bojxona rejimiga tegishli',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Umumiy balansga ta\'sir qilmaydi, alohida hisobot uchun',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _hasSelection ? _submit : null,
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.fromWarehouseId});
  final int fromWarehouseId;
  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  List<dynamic> _warehouses = [];
  List<dynamic> _dealerDests = [];
  List<dynamic> _normalDests = [];
  List<dynamic> _dealers = [];
  String? _dealerSegment;
  List<dynamic> _stock = [];
  int? _toWarehouseId;
  int? _fixedTo;
  String? _fixedName;
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selectedItems = [];
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final whResult = await FactoryHubApi.getWarehouses();
    final detailResult = await FactoryHubApi.getWarehouseDetail(widget.fromWarehouseId);
    if (!mounted) return;
    final allWh = whResult['warehouses'] ?? [];
    final warehouse = detailResult['warehouse'];
    // Ruxsat etilgan yo'nalishlar: ombor sozlamalarida belgilangan transferTo
    // ro'yxati. Manzil omboriga alohida biriktirma (grant) talab qilinmaydi —
    // backend faqat manba granti + yo'nalish so'raydi. Shuning uchun manzil
    // ro'yxati YO'NALISh manzillaridan, biriktirilgan omborlar bilan
    // cheklanmasdan to'ldiriladi.
    final routesDetail = (warehouse?['transferToWarehouses'] as List?) ?? [];
    final allowedTo = (warehouse?['transferTo'] as List?)?.cast<int>() ?? [];
    final fixedTo = warehouse?['fixedTransferTo'];
    final fixedName = warehouse?['fixedTransferToWarehouse']?.toString();
    final dealersResult = await FactoryHubApi.getDealers();
    final dealers = dealersResult['dealers'] ?? [];
    final dealerWhIds = <int>{
      for (final d in dealers)
        if (d['warehouseId'] is num || d['warehouseId'] != null)
          int.tryParse('${d['warehouseId']}') ?? -1,
    }..remove(-1);
    setState(() {
      // Qat'iy tayinlangan ombor bo'lsa — manzilni foydalanuvchi tanlamaydi.
      if (fixedTo != null) {
        _fixedTo = (fixedTo as num?)?.toInt();
        _fixedName = fixedName;
        _toWarehouseId = _fixedTo;
        _warehouses = [
          {'id': _fixedTo, 'name': _fixedName ?? 'Ombor #$_fixedTo'},
        ];
      } else {
        _fixedTo = null;
        _fixedName = null;
        _warehouses = routesDetail.isNotEmpty
            ? routesDetail.cast<Map<String, dynamic>>().toList()
            : allWh.where((w) => allowedTo.contains(w['id'])).toList();
      }
      _dealers = dealers;
      _dealerDests = _warehouses.where((w) {
        final id = w['id'];
        return id is num && dealerWhIds.contains(id.toInt());
      }).toList();
      _normalDests = _warehouses.where((w) {
        final id = w['id'];
        return !(id is num && dealerWhIds.contains(id.toInt()));
      }).toList();
      // Diller manzillar mavjud bo'lsa — avval bozor segmenti ko'rsatiladi.
      if (_fixedTo == null && _dealerDests.isNotEmpty) {
        _dealerSegment ??= 'domestic';
      }
      _stock = detailResult['stock'] ?? [];
      _loading = false;
    });
  }

  // Segment bo'yicha diller manzillari (diller nomi bilan).
  List<Map<String, dynamic>> get _segmentDealerDests {
    final seg = _dealerSegment;
    if (seg == null) return const [];
    return _dealerDests.where((w) {
      final id = w['id'];
      final dlr = _dealers.cast<Map<String, dynamic>>().where((d) =>
          d['warehouseId']?.toString() == id?.toString()).toList();
      return dlr.isNotEmpty && dlr.first['marketType']?.toString() == seg;
    }).cast<Map<String, dynamic>>().toList();
  }

  String _dealerNameFor(dynamic w) {
    final id = w['id']?.toString();
    for (final d in _dealers) {
      if (d['warehouseId']?.toString() == id) {
        return d['name']?.toString() ?? w['name']?.toString() ?? '';
      }
    }
    return w['name']?.toString() ?? '';
  }

  // Manzil tanlash: avval "Ichki bozor"/"Eksport" segmenti + dillerlar,
  // davomida boshqa (diller bo'lmagan) omborlar o'zgarmagan holda.
  Widget _buildDestinationPicker() {
    final hasDealers = _dealerDests.isNotEmpty;
    final segmentDests = _segmentDealerDests;
    final normalInList = _normalDests.any((w) =>
        w['id']?.toString() == _toWarehouseId?.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDealers) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'domestic', label: Text('Ichki bozor')),
              ButtonSegment(value: 'export', label: Text('Eksport')),
            ],
            selected: {_dealerSegment ?? 'domestic'},
            onSelectionChanged: (set) => setState(() => _dealerSegment = set.first),
          ),
          const SizedBox(height: 8),
          if (segmentDests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Bu bozorda mavjud diller yo\'q',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: segmentDests.map<Widget>((w) {
                final id = (w['id'] as num?)?.toInt();
                final name = _dealerNameFor(w);
                final selected = _toWarehouseId == id;
                return ChoiceChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (_) => setState(() => _toWarehouseId = id),
                );
              }).toList(),
            ),
          if (_normalDests.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Boshqa omborlar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (_normalDests.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: normalInList ? _toWarehouseId : null,
            items: _normalDests.map<DropdownMenuItem<int>>((w) =>
              DropdownMenuItem(value: (w['id'] as num).toInt(), child: Text(w['name'] ?? ''))
            ).toList(),
            onChanged: (v) => setState(() => _toWarehouseId = v),
            decoration: InputDecoration(
              labelText: 'Manzil ombor',
              hintText: _warehouses.isEmpty ? 'Yo\'nalish sozlanmagan' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  List<dynamic> get _filteredStock {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _stock.where((s) => !_selectedItems.any((sel) =>
      sel['itemType'] == s['itemType'] && sel['refId']?.toString() == s['refId']?.toString() && sel['refBarcode']?.toString() == s['refBarcode']?.toString()
    )).toList();
    return _stock.where((s) {
      if (_selectedItems.any((sel) =>
        sel['itemType'] == s['itemType'] && sel['refId']?.toString() == s['refId']?.toString() && sel['refBarcode']?.toString() == s['refBarcode']?.toString()
      )) return false;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final refKey = (s['refKey'] ?? '').toString().toLowerCase();
      return name.contains(q) || refKey.contains(q);
    }).toList();
  }

  void _addItem(dynamic stockItem) {
    setState(() {
      _selectedItems.add({
        'itemType': stockItem['itemType'],
        'refId': stockItem['refId'],
        'refBarcode': stockItem['refBarcode'],
        'name': stockItem['name'],
        'unit': stockItem['unit'],
        'maxQty': double.tryParse(stockItem['balance']?.toString() ?? '0') ?? 0,
        'qtyCtrl': TextEditingController(text: stockItem['balance']?.toString() ?? ''),
      });
      _searchCtrl.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems[index]['qtyCtrl'].dispose();
      _selectedItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_toWarehouseId == null) {
      setState(() => _error = 'Manzil omborni tanlang');
      return;
    }
    if (_selectedItems.isEmpty) {
      setState(() => _error = 'Kamida bitta mahsulot tanlang');
      return;
    }
    final payloads = <Map<String, dynamic>>[];
    for (final si in _selectedItems) {
      final qty = double.tryParse(si['qtyCtrl'].text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) {
        setState(() => _error = "Miqdor noto'g'ri: ${si['name']}");
        return;
      }
      final itemId = _itemIdFor(si);
      if (itemId == null) {
        setState(() => _error = "Yuborish identifikatori aniqlanmadi: ${si['name']}");
        return;
      }
      payloads.add({
        'item_id': itemId,
        'quantity': qty,
        'unit': si['unit'],
        'source_warehouse_id': widget.fromWarehouseId,
        'dest_warehouse_id': _toWarehouseId,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
    }
    setState(() { _submitting = true; _error = null; });
    String? firstError;
    for (final payload in payloads) {
      final result = await FactoryHubApi.sendTransfer(payload);
      if (result['error'] != null) {
        firstError ??= result['error'];
        break;
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (firstError != null) {
      setState(() => _error = firstError);
      return;
    }
    Navigator.pop(context, true);
  }

  int? _itemIdFor(Map<String, dynamic> si) {
    final refId = si['refId'];
    if (refId is num) return refId.toInt();
    if (refId != null) {
      final v = int.tryParse(refId.toString());
      if (v != null) return v;
    }
    final barcode = si['refBarcode'];
    if (barcode != null) return int.tryParse(barcode.toString());
    return null;
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
            const Text('OMBORLARARO TRANSFER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()) else ...[
              if (_fixedTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOk.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.statusOk),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, size: 18, color: AppColors.statusOk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Avtomatik manzil: ${_fixedName ?? 'Ombor #$_fixedTo'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildDestinationPicker(),
              if (_warehouses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Bu ombordan transfer yo\'nalishlari sozlanmagan. '
                    'Ombor sozlamalaridan transfer yo\'nalishini qo\'shing.',
                    style: TextStyle(fontSize: 12, color: AppColors.statusWarning),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Qoldiqdan qidirish",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { setState(() => _searchCtrl.clear()); })
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              if (_filteredStock.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredStock.length,
                    itemBuilder: (_, i) {
                      final s = _filteredStock[i];
                      final refKey = s['refKey']?.toString() ?? '';
                      return InkWell(
                        onTap: () => _addItem(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              if (refKey.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: s['itemType'] == 'raw_material' ? AppColors.primary : AppColors.gold,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(refKey, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              if (refKey.isNotEmpty) const SizedBox(width: 8),
                              Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('${s['balance']} ${s['unit'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_selectedItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Tanlanganlar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                ...List.generate(_selectedItems.length, (i) {
                  final si = _selectedItems[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(si['name'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: si['qtyCtrl'],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        Text(' ${si['unit'] ?? ''}', style: const TextStyle(fontSize: 11)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: AppColors.statusCritical),
                          onPressed: () => _removeItem(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Transfer bajarish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWarehouseSheet extends StatefulWidget {
  const _CreateWarehouseSheet();

  @override
  State<_CreateWarehouseSheet> createState() => _CreateWarehouseSheetState();
}

class _CreateWarehouseSheetState extends State<_CreateWarehouseSheet> {
  final _name = TextEditingController();
  String _type = 'raw';
  bool _canAnalyze = true;
  bool _canIncome = true;
  bool _canExpense = true;
  bool _canTransfer = false;
  final List<int> _transferTo = [];
  List<dynamic> _allWarehouses = [];
  String? _error;
  bool _loadingDest = true;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    final result = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    setState(() {
      _allWarehouses = result['warehouses'] ?? [];
      _loadingDest = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Ombor nomini kiriting');
      return;
    }
    setState(() => _error = null);
    final result = await FactoryHubApi.createWarehouse(
      name: _name.text.trim(),
      type: _type,
      canAnalyze: _canAnalyze,
      canIncome: _canIncome,
      canExpense: _canExpense,
      canTransfer: _canTransfer,
      transferTo: _transferTo,
    );
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final available = _allWarehouses
        .where((w) => !_transferTo.contains(w['id']))
        .toList();
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
            Text("Yangi ombor", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Nomi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'raw', child: Text('Xom ashyo')),
                DropdownMenuItem(value: 'production', child: Text('Ishlab chiqarish (WIP)')),
                DropdownMenuItem(value: 'semi_finished', child: Text('Yarim tayyor mahsulot')),
                DropdownMenuItem(value: 'packaging', child: Text('Qadoqlash materiallari')),
                DropdownMenuItem(value: 'finished', child: Text('Tayyor mahsulot')),
                DropdownMenuItem(value: 'purchased_finished', child: Text('Sotib olingan tayyor')),
                DropdownMenuItem(value: 'purchased_semi', child: Text('Sotib olingan yarim tayyor')),
                DropdownMenuItem(value: 'spare_parts', child: Text('Ehtiyot qismlar')),
                DropdownMenuItem(value: 'sales', child: Text('Sotuv ombori')),
                DropdownMenuItem(value: 'dealer', child: Text('Dilerlar')),
                DropdownMenuItem(value: 'quarantine', child: Text('Karantin/tekshiruv')),
                DropdownMenuItem(value: 'defective', child: Text('Brak/nikoz')),
                DropdownMenuItem(value: 'returned', child: Text('Qaytarilgan mahsulot')),
                DropdownMenuItem(value: 'retain_sample', child: Text('Namuna (retain sample)')),
                DropdownMenuItem(value: 'empty_container', child: Text("Bo'shagan idish/tara")),
                DropdownMenuItem(value: 'other', child: Text('Aralash (xo\'jalik, kantstovar)')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'raw'),
              decoration: InputDecoration(
                labelText: 'Turi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Imkoniyatlar', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tahlil qilish'),
              subtitle: const Text('Ombor bo\'yicha tahlil / hisobot ko\'rish'),
              value: _canAnalyze,
              onChanged: (v) => setState(() => _canAnalyze = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Qo\'lda kirim'),
              subtitle: const Text('Mahsulot qo\'lda qabul qilish'),
              value: _canIncome,
              onChanged: (v) => setState(() => _canIncome = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Qo\'lda chiqim'),
              subtitle: const Text('Mahsulot qo\'lda hisobdan chiqarish'),
              value: _canExpense,
              onChanged: (v) => setState(() => _canExpense = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transfer qilish'),
              subtitle: const Text('Bu ombordan boshqasiga transfer qilish'),
              value: _canTransfer,
              onChanged: (v) {
                setState(() {
                  _canTransfer = v;
                  if (!v) _transferTo.clear();
                });
              },
            ),
            if (_canTransfer) ...[
              const SizedBox(height: 12),
              Text('Transfer qilishga ruxsat etilgan omborlar',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Agar qabul qiluvchi ombor hali mavjud bo\'lmasa, uni yaratgandan keyin ombor sozlamalarida transfer yo\'nalishini qo\'shishingiz mumkin.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (_loadingDest)
                const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_transferTo.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _transferTo.map((id) {
                    final w = _allWarehouses.where((x) => x['id'] == id).toList();
                    final label = w.isNotEmpty ? w.first['name'] : 'Ombor #$id';
                    return Chip(
                      label: Text('$label'),
                      onDeleted: () => setState(() => _transferTo.remove(id)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<int>(
                key: ValueKey('dest-${_transferTo.length}'),
                initialValue: available.isNotEmpty ? available.first['id'] as int : null,
                items: available
                    .map<DropdownMenuItem<int>>((w) => DropdownMenuItem(
                          value: w['id'] as int,
                          child: Text('${w['name']}'),
                        ))
                    .toList(),
                onChanged: available.isEmpty
                    ? null
                    : (v) {
                        if (v != null) setState(() => _transferTo.add(v));
                      },
                decoration: InputDecoration(
                  hintText: available.isEmpty ? 'Qo\'shish uchun ombor yo\'q' : 'Ombor qo\'shish',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
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

class _EditWarehouseSheet extends StatefulWidget {
  const _EditWarehouseSheet({required this.warehouseId, required this.warehouse});

  final int warehouseId;
  final Map<String, dynamic> warehouse;

  @override
  State<_EditWarehouseSheet> createState() => _EditWarehouseSheetState();
}

class _EditWarehouseSheetState extends State<_EditWarehouseSheet> {
  late bool _canAnalyze;
  late bool _canIncome;
  late bool _canExpense;
  late bool _canTransfer;
  late int? _fixedTransferTo;
  late List<int> _transferTo;
  List<dynamic> _allWarehouses = [];
  bool _loadingDest = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _canAnalyze = widget.warehouse['canAnalyze'] == true;
    _canIncome = widget.warehouse['canIncome'] == true;
    _canExpense = widget.warehouse['canExpense'] == true;
    _canTransfer = widget.warehouse['canTransfer'] == true;
    _fixedTransferTo = widget.warehouse['fixedTransferTo'] as int?;
    _transferTo = (widget.warehouse['transferTo'] as List?)?.cast<int>() ?? [];
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    final result = await FactoryHubApi.getWarehouses();
    if (!mounted) return;
    setState(() {
      _allWarehouses = result['warehouses'] ?? [];
      _loadingDest = false;
    });
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    final result = await FactoryHubApi.updateWarehouse(
      id: widget.warehouseId,
      canAnalyze: _canAnalyze,
      canIncome: _canIncome,
      canExpense: _canExpense,
      canTransfer: _canTransfer,
      transferTo: _transferTo,
      fixedTransferTo: _transferTo.contains(_fixedTransferTo) ? _fixedTransferTo : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result['error'] != null) {
      setState(() => _error = result['error']);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final available = _allWarehouses
        .where((w) => w['id'] != widget.warehouseId && !_transferTo.contains(w['id']))
        .toList();
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
            Text(
              'Imkoniyatlar — ${widget.warehouse['name']}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tahlil qilish'),
              subtitle: const Text('Ombor bo\'yicha tahlil / hisobot ko\'rish'),
              value: _canAnalyze,
              onChanged: (v) => setState(() => _canAnalyze = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Qo\'lda kirim'),
              subtitle: const Text('Mahsulot qo\'lda qabul qilish'),
              value: _canIncome,
              onChanged: (v) => setState(() => _canIncome = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Qo\'lda chiqim'),
              subtitle: const Text('Mahsulot qo\'lda hisobdan chiqarish'),
              value: _canExpense,
              onChanged: (v) => setState(() => _canExpense = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transfer qilish'),
              subtitle: const Text('Bu ombordan boshqasiga transfer qilish'),
              value: _canTransfer,
              onChanged: (v) {
                setState(() {
                  _canTransfer = v;
                  if (!v) {
                    _transferTo.clear();
                    _fixedTransferTo = null;
                  }
                });
              },
            ),
            if (_canTransfer) ...[
              const SizedBox(height: 12),
              Text('Transfer qilishga ruxsat etilgan omborlar',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Yangi ombor yaratilgach, bu yerda transfer yo\'nalishini qo\'shishingiz mumkin.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (_loadingDest)
                const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_transferTo.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _transferTo.map((id) {
                    final w = _allWarehouses.where((x) => x['id'] == id).toList();
                    final label = w.isNotEmpty ? w.first['name'] : 'Ombor #$id';
                    return Chip(
                      label: Text('$label'),
                      onDeleted: () => setState(() {
                        _transferTo.remove(id);
                        if (_fixedTransferTo == id) _fixedTransferTo = null;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<int>(
                key: ValueKey('dest-${_transferTo.length}'),
                initialValue: available.isNotEmpty ? available.first['id'] as int : null,
                items: available
                    .map<DropdownMenuItem<int>>((w) => DropdownMenuItem(
                          value: w['id'] as int,
                          child: Text('${w['name']}'),
                        ))
                    .toList(),
                onChanged: available.isEmpty
                    ? null
                    : (v) {
                        if (v != null) setState(() => _transferTo.add(v));
                      },
                decoration: InputDecoration(
                  hintText: available.isEmpty ? 'Qo\'shish uchun ombor yo\'q' : 'Ombor qo\'shish',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Qat\'iy transfer ombori',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'Tayinlansa — foydalanuvchi manzilni tanlamaydi, transfer avtomatik shu omborga yo\'naladi.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                key: ValueKey('fixed-${_transferTo.join(',')}'),
                initialValue: _transferTo.contains(_fixedTransferTo)
                    ? _fixedTransferTo
                    : null,
                items: [
                  const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tanlashsiz — foydalanuvchi tanlaydi')),
                  ..._transferTo.map((id) {
                    final w = _allWarehouses.where((x) => x['id'] == id).toList();
                    final label = w.isNotEmpty ? w.first['name'] : 'Ombor #$id';
                    return DropdownMenuItem<int?>(
                        value: id, child: Text('$label'));
                  }),
                ],
                onChanged: _transferTo.isEmpty
                    ? null
                    : (v) => setState(() => _fixedTransferTo = v),
                decoration: InputDecoration(
                  labelText: 'Qat\'iy (avtomatik) ombor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
