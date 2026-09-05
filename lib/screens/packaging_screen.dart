import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class PackagingScreen extends StatefulWidget {
  const PackagingScreen({super.key});

  @override
  State<PackagingScreen> createState() => _PackagingScreenState();
}

class _PackagingScreenState extends State<PackagingScreen> {
  List<dynamic> _boms = [];
  final _qty = TextEditingController();
  int? _bomId;
  int? _destWhId;
  bool _loading = true;
  bool _previewing = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _preview;
  List<dynamic> _required = [];
  List<dynamic> _shortages = [];
  List<dynamic> _destWarehouses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bomsResult = await FactoryHubApi.getBoms();
    final whResult = await FactoryHubApi.getWarehouses();
    final allWh = (whResult['warehouses'] ?? []) as List<dynamic>;
    final finishWh = allWh.where((w) => w['type'] == 'finished').toList();
    if (!mounted) return;
    final boms = (bomsResult['boms'] ?? [])
        .where((b) => b['stage'] == 'packaging')
        .toList();
    setState(() {
      _boms = boms;
      _destWarehouses = finishWh;
      _destWhId = finishWh.isNotEmpty ? finishWh.first['id'] as int : null;
      _loading = false;
    });
  }

  double? get _outputQty {
    final v = double.tryParse(_qty.text);
    return v != null && v > 0 ? v : null;
  }

  Future<void> _previewAction() async {
    final qty = _outputQty;
    if (_bomId == null || qty == null) {
      setState(() => _error = 'Retsept va miqdor (>0) kerak');
      return;
    }
    setState(() {
      _previewing = true;
      _error = null;
      _preview = null;
      _shortages = [];
    });
    final result = await FactoryHubApi.packagingPreview(bomId: _bomId!, outputQuantity: qty);
    if (!mounted) return;
    setState(() {
      _previewing = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _preview = result;
        _required = result['required'] ?? [];
        _shortages = result['shortages'] ?? [];
        final fins = result['finishedWarehouses'] as List<dynamic>? ?? [];
        if (fins.isNotEmpty && !fins.any((e) => e['id'] == _destWhId)) {
          _destWhId = fins.first['id'] as int;
        }
      }
    });
  }

  Future<void> _startAction() async {
    final qty = _outputQty;
    if (_bomId == null || qty == null || _destWhId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await FactoryHubApi.startPackaging(
      bomId: _bomId!,
      outputQuantity: qty,
      destWarehouseId: _destWhId!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result['error'] != null) {
      setState(() {
        _error = result['error'];
        _shortages = (result['shortages'] as List<dynamic>?) ?? [];
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? 'Boshlang\'di'),
      backgroundColor: AppColors.statusOk,
    ));
    setState(() {
      _preview = null;
      _required = [];
      _shortages = [];
      _qty.clear();
    });
  }

  String _groupLabel(String g) => g == 'packaging' ? 'Qadoqlash materiali' : 'Yarim tayyor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Qadoqlash (yarim tayyor + material -> tayyor)',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Yarim tayyor va qadoqlash materiallari darhol sarflanadi, natija tanlangan tayyor omborga tasdiqlash bilan kiradi.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _bomId,
                    items: _boms.map<DropdownMenuItem<int>>((b) => DropdownMenuItem(
                          value: b['id'],
                          child: Text(
                              '${b['name']} → ${b['outputName'] ?? ''} (${b['outputQtyPerBatch']} ${b['outputUnitLabel'] ?? 'dona'})',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        )).toList(),
                    onChanged: (v) => setState(() {
                      _bomId = v;
                      _preview = null;
                      _required = [];
                      _shortages = [];
                    }),
                    decoration: InputDecoration(
                      labelText: 'Retsept (packaging)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Chiqish miqdori',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _destWhId,
                    items: _destWarehouses.map<DropdownMenuItem<int>>(
                        (w) => DropdownMenuItem(value: w['id'], child: Text(w['name']))).toList(),
                    onChanged: (v) => setState(() => _destWhId = v),
                    decoration: InputDecoration(
                      labelText: 'Tayyor mahsulot ombori (qabul)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _previewing ? null : _previewAction,
                    icon: _previewing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.visibility),
                    label: const Text('Hisoblash'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorBox(),
                  ],
                  if (_preview != null) ...[
                    const SizedBox(height: 12),
                    _previewCard(),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _previewCard() {
    final p = _preview!;
    final semi = p['sourceSemi'] as Map? ?? const {};
    final pkg = p['sourcePackaging'] as Map? ?? const {};
    final allOk = _shortages.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(allOk ? Icons.check_circle : Icons.warning_amber,
                    color: allOk ? AppColors.statusOk : AppColors.statusWarning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allOk ? 'Yetarli — boshlash mumkin' : 'Kamchiliklar bor',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manbalar: ${semi['name'] ?? ''} + ${pkg['name'] ?? ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ..._required.map((r) => _requiredRow(r)),
            const SizedBox(height: 12),
            if (allOk && FactoryHubApi.role.canPlan)
              FilledButton.icon(
                onPressed: _submitting ? null : _startAction,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: const Text('Qadoqlashni boshlash'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _requiredRow(Map<String, dynamic> r) {
    final ok = r['ok'] == true;
    final name = (r['name'] ?? '').toString();
    final need = double.tryParse(r['needed'].toString()) ?? 0;
    final avail = double.tryParse(r['available'].toString()) ?? 0;
    final unit = (r['unit'] ?? 'dona').toString();
    final group = _groupLabel((r['group'] ?? '').toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 15,
              color: ok ? AppColors.statusOk : AppColors.statusCritical),
          const SizedBox(width: 6),
Expanded(
          child: Text('$name ($group)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
          Text('$need $unit / $avail $unit',
              style: TextStyle(
                  fontSize: 12,
                  color: ok ? AppColors.textSecondary : AppColors.statusCritical,
                  fontWeight: ok ? FontWeight.normal : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _errorBox() {
    final message = _error!;
    final shortages = _shortages;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusCritical.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.statusCritical.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AppColors.statusCritical, fontSize: 13)),
          if (shortages.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...shortages.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${s['name']} — kerak: ${s['needed']} ${s['unit'] ?? ''}, mavjud: ${s['available']} ${s['unit'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.statusCritical),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}