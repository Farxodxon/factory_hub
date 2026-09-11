import 'package:flutter/material.dart';

import '../models/user.dart';

import '../services/api_service.dart';
import '../theme/colors.dart';

class DealersScreen extends StatefulWidget {
  const DealersScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends State<DealersScreen> {
  String _marketType = 'domestic';
  List<dynamic> _dealers = [];
  String? _error;
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
    final result = await FactoryHubApi.getDealers(marketType: _marketType);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _dealers = result['dealers'] ?? [];
        _error = null;
      }
    });
  }

  Future<void> _createDealer() async {
    if (!FactoryHubApi.role.canControlWarehouses) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DealerFormSheet(
        marketType: _marketType,
      ),
    );
    if (created == true) _load();
  }

  Future<void> _deleteDealer(Map<String, dynamic> d) async {
    if (!FactoryHubApi.role.canControlWarehouses) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dillerni o\'chirish — ${d['name']}'),
        content: const Text(
          'Diller va unga bog\'langan ombor o\'chiriladi (faqat ombor qoldig\'i bo\'sh bo\'lsa). Davom etasizmi?',
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
    final result = await FactoryHubApi.deleteDealer(d['id']);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: ${result['error']}'), backgroundColor: AppColors.statusCritical),
      );
      return;
    }
    setState(() => _dealers.removeWhere((x) => x['id'] == d['id']));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diller o\'chirildi'), backgroundColor: AppColors.statusOk),
    );
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

    return Scaffold(
      floatingActionButton: FactoryHubApi.role.canControlWarehouses
          ? FloatingActionButton.extended(
              heroTag: 'fab_dealers',
              onPressed: _createDealer,
              icon: const Icon(Icons.add),
              label: const Text('Diller'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'domestic',
                  label: Text('Ichki bozor'),
                  icon: Icon(Icons.storefront),
                ),
                ButtonSegment(
                  value: 'export',
                  label: Text('Eksport'),
                  icon: Icon(Icons.flight_takeoff),
                ),
              ],
              selected: {_marketType},
              onSelectionChanged: (set) {
                setState(() => _marketType = set.first);
                _load();
              },
            ),
          ),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _dealers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Icon(Icons.storefront_outlined, size: 64, color: AppColors.divider),
                              SizedBox(height: 12),
                              Center(
                                child: Text('Diller yo\'q', style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _dealers.length,
                            itemBuilder: (_, i) => _DealerCard(
                              dealer: _dealers[i],
                              onDelete: () => _deleteDealer(_dealers[i]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({required this.dealer, required this.onDelete});

  final Map<String, dynamic> dealer;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final itemCount = (dealer['itemCount'] as num?)?.toInt() ?? 0;
    final totalQty = double.tryParse(dealer['totalQty']?.toString() ?? '0') ?? 0;
    final contact = dealer['contactPerson']?.toString() ?? '';
    final phone = dealer['phone']?.toString() ?? '';
    final name = dealer['name']?.toString() ?? '';
    final isActive = dealer['isActive'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBg,
          child: Icon(
            dealer['marketType'] == 'export' ? Icons.flight_takeoff : Icons.storefront,
            color: AppColors.primary,
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemCount == 0
                  ? 'Qoldiq yo\'q'
                  : '$itemCount xil mahsulot, jami ${_fmtNum(totalQty)} dona',
              style: const TextStyle(fontSize: 12),
            ),
            if (contact.isNotEmpty || phone.isNotEmpty)
              Text(
                [
                  if (phone.isNotEmpty) phone,
                  if (contact.isNotEmpty) 'Kontakt: $contact',
                ].join('  •  '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.block, size: 18, color: AppColors.statusWarning),
              ),
            if (FactoryHubApi.role.canControlWarehouses)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.statusCritical),
                visualDensity: VisualDensity.compact,
                tooltip: 'O\'chirish',
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DealerDetailScreen(id: dealer['id']),
            ),
          );
          if (context.mounted) {
            final s = context.findAncestorStateOfType<_DealersScreenState>();
            s?._load();
          }
        },
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// ─── Diller yaratish/tahrirlash formasi ─────────────────────────
class _DealerFormSheet extends StatefulWidget {
  const _DealerFormSheet({this.marketType = 'domestic', this.dealer});

  final String marketType;
  final Map<String, dynamic>? dealer;

  @override
  State<_DealerFormSheet> createState() => _DealerFormSheetState();
}

class _DealerFormSheetState extends State<_DealerFormSheet> {
  late final TextEditingController _nameCtrl;
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  late String _marketType;
  late bool _isActive;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.dealer != null;

  @override
  void initState() {
    super.initState();
    final d = widget.dealer;
    _nameCtrl = TextEditingController(text: _isEdit ? (d!['name']?.toString() ?? '') : '');
    _phoneCtrl.text = _isEdit ? (d!['phone']?.toString() ?? '') : '';
    _addressCtrl.text = _isEdit ? (d!['address']?.toString() ?? '') : '';
    _contactCtrl.text = _isEdit ? (d!['contactPerson']?.toString() ?? '') : '';
    _marketType = _isEdit ? (d!['marketType']?.toString() ?? widget.marketType) : widget.marketType;
    _isActive = _isEdit ? (d!['isActive'] != false) : true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Diller nomini kiriting');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final Map<String, dynamic> result;
    if (_isEdit) {
      result = await FactoryHubApi.updateDealer(
        id: widget.dealer!['id'],
        name: name,
        marketType: _marketType,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        isActive: _isActive,
      );
    } else {
      result = await FactoryHubApi.createDealer(
        name: name,
        marketType: _marketType,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() { _submitting = false; _error = result['error']; });
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
            Text(
              _isEdit ? 'DILLERNI TAHRIRLASH' : 'YANGI DILLER',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Diller nomi *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'domestic', label: Text('Ichki bozor')),
                ButtonSegment(value: 'export', label: Text('Eksport')),
              ],
              selected: {_marketType},
              onSelectionChanged: (set) => setState(() => _marketType = set.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Mas\'ul shaxs',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Manzil',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktiv'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Saqlash' : 'Yaratish'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diller tafsiloti (kontakt + to'liq ombor qoldig'i) ─────────
class DealerDetailScreen extends StatefulWidget {
  const DealerDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<DealerDetailScreen> createState() => _DealerDetailScreenState();
}

class _DealerDetailScreenState extends State<DealerDetailScreen> {
  Map<String, dynamic>? _dealer;
  List<dynamic> _stock = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await FactoryHubApi.getDealerDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _dealer = result['dealer'];
        _stock = result['stock'] ?? [];
      }
    });
  }

  Future<void> _edit() async {
    final d = _dealer;
    if (d == null || !FactoryHubApi.role.canControlWarehouses) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DealerFormSheet(dealer: d),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_dealer?['name']?.toString() ?? 'Diller')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _dealer!;
    final phone = d['phone']?.toString() ?? '';
    final address = d['address']?.toString() ?? '';
    final contact = d['contactPerson']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['marketType'] == 'export' ? 'Eksport' : 'Ichki bozor',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      if (phone.isNotEmpty) Text('Tel: $phone'),
                      if (contact.isNotEmpty) Text('Mas\'ul shaxs: $contact'),
                      if (address.isNotEmpty) Text('Manzil: $address'),
                      if (d['warehouseName'] != null)
                        Text('Ombor: ${d['warehouseName']}'),
                      if (d['isActive'] == false)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Nofaol',
                            style: TextStyle(color: AppColors.statusWarning, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (FactoryHubApi.role.canControlWarehouses)
              IconButton(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Tahrirlash',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Ombor qoldig\'i (${_stock.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_stock.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Qoldiq yo\'q', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          Card(
            child: Column(
              children: _stock.map((s) {
                final qty = double.tryParse(s['balance']?.toString() ?? '0') ?? 0;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2, color: AppColors.primary),
                  title: Text(s['name']?.toString() ?? (s['refKey']?.toString() ?? '')),
                  subtitle: Text('Kod: ${s['refKey']?.toString() ?? '-'}'),
                  trailing: Text(
                    '${_fmtNum(qty)} ${s['unit'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Yangilash'),
        ),
      ],
    );
  }
}