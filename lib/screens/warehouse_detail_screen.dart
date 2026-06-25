import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WarehouseDetailScreen extends StatefulWidget {
  final int warehouseId;
  final String warehouseName;

  const WarehouseDetailScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen> {
  Map<String, dynamic>? _warehouse;
  List _materials = [];
  List _transactions = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await FactoryHubApi.getWarehouseDetail(widget.warehouseId);
      setState(() {
        _warehouse = result['warehouse'] as Map<String, dynamic>?;
        _materials = (result['materials'] as List?) ?? [];
        _transactions = (result['transactions'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'raw':
        return 'Xom ashyo ombori';
      case 'purchased':
        return 'Sotib olingan qismlar ombori';
      case 'semi_finished':
        return 'Yarim tayyor mahsulotlar ombori';
      case 'finished':
        return 'Tayyor mahsulotlar ombori';
      case 'sales':
        return 'Sotuv ombori';
      default:
        return type ?? '';
    }
  }

  Future<void> _openTransactionDialog() async {
    String? selectedMaterialId;
    String selectedType = 'in';
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kirim / Chiqim'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedMaterialId,
                  decoration: const InputDecoration(labelText: 'Material'),
                  items: _materials
                      .map((m) => DropdownMenuItem<String>(
                    value: m['materialId'].toString(),
                    child: Text(m['materialName'] ?? '', overflow: TextOverflow.ellipsis),
                  ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMaterialId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Kirim'),
                        value: 'in',
                        groupValue: selectedType,
                        onChanged: (v) => setDialogState(() => selectedType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Chiqim'),
                        value: 'out',
                        groupValue: selectedType,
                        onChanged: (v) => setDialogState(() => selectedType = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Miqdor'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                if (selectedMaterialId == null || qtyController.text.trim().isEmpty) {
                  _showMsg('Material va miqdorni kiriting', isError: true);
                  return;
                }
                final qty = double.tryParse(qtyController.text.trim());
                if (qty == null || qty <= 0) {
                  _showMsg('Miqdor noto\'g\'ri', isError: true);
                  return;
                }
                final selectedMaterial = _materials.firstWhere(
                      (m) => m['materialId'].toString() == selectedMaterialId,
                  orElse: () => {},
                );
                final unit = selectedMaterial['unit']?.toString() ?? '';
                setDialogState(() => saving = true);
                try {
                  final result = await FactoryHubApi.addTransaction({
                    'warehouse_id': widget.warehouseId,
                    'material_id': int.parse(selectedMaterialId!),
                    'transaction_type': selectedType,
                    'quantity': qty,
                    'unit': unit,
                    'notes': notesController.text.trim(),
                  });
                  if (result['error'] != null) {
                    setDialogState(() => saving = false);
                    _showMsg(result['error'].toString(), isError: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMsg(selectedType == 'in' ? 'Kirim qo\'shildi' : 'Chiqim qo\'shildi');
                  _load();
                } catch (e) {
                  setDialogState(() => saving = false);
                  _showMsg('Xatolik yuz berdi', isError: true);
                }
              },
              child: saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow() {
    final total = _materials.length;
    final low = _materials.where((m) {
      final balance = (m['balance'] as num?)?.toDouble() ?? 0;
      return balance <= 0;
    }).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Text('Jami: $total material', style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (low > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text('$low ta tugagan', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _materialCard(Map m) {
    final balance = (m['balance'] as num?)?.toDouble() ?? 0;
    final totalIn = (m['totalIn'] as num?)?.toDouble() ?? 0;
    final totalOut = (m['totalOut'] as num?)?.toDouble() ?? 0;
    final isEmpty = balance <= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        border: isEmpty ? Border.all(color: Colors.red.shade200) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isEmpty ? Colors.red.shade50 : const Color(0xFF1565C0).withValues(alpha: 0.1),
            child: Icon(Icons.inventory_2, color: isEmpty ? Colors.red.shade700 : const Color(0xFF1565C0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['materialName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Kirim: ${totalIn.toStringAsFixed(0)} · Chiqim: ${totalOut.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance.toStringAsFixed(0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isEmpty ? Colors.red.shade700 : Colors.black87,
                ),
              ),
              Text(m['unit'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Map t) {
    final isIn = t['type'] == 'in';
    return ListTile(
      dense: true,
      leading: Icon(
        isIn ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIn ? Colors.green : Colors.orange,
      ),
      title: Text(t['material_name'] ?? t['materialName'] ?? ''),
      subtitle: Text(t['notes']?.toString().isNotEmpty == true ? t['notes'] : (t['created_at'] ?? '')),
      trailing: Text(
        '${isIn ? '+' : '-'}${t['quantity']}',
        style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.orange),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.warehouseName),
            if (_warehouse != null && _warehouse!['type'] != null)
              Text(
                _typeLabel(_warehouse!['type']),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: _openTransactionDialog,
        child: const Icon(Icons.swap_vert, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Ma\'lumotni yuklab bo\'lmadi'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            _summaryRow(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Materiallar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (_materials.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Materiallar yo\'q')),
              )
            else
              ..._materials.map((m) => _materialCard(m)),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text('So\'nggi tranzaksiyalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Tranzaksiyalar yo\'q')),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: _transactions
                      .map((t) => _transactionTile(t))
                      .toList(),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}