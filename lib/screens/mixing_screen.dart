import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class MixingScreen extends StatefulWidget {
  const MixingScreen({super.key});

  @override
  State<MixingScreen> createState() => _MixingScreenState();
}

class _MixingScreenState extends State<MixingScreen> {
  List<dynamic> _boms = [];
  List<dynamic> _pieceEmployees = [];
  final _qty = TextEditingController();
  int? _bomId;
  int? _employeeId;
  bool _loading = true;
  bool _previewing = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _preview;
  List<dynamic> _required = [];
  List<dynamic> _shortages = [];

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
    final result = await FactoryHubApi.getBoms();
    var piece = <dynamic>[];
    try {
      final hr = await FactoryHubApi.getEmployees();
      piece = (hr['employees'] ?? [])
          .where((e) => (e['status'] ?? 'active') == 'active' &&
              ['piece_rate', 'hybrid'].contains(e['payType']))
          .toList();
    } catch (_) {}
    if (!mounted) return;
    final boms = (result['boms'] ?? [])
        .where((b) => b['stage'] == 'mixing')
        .toList();
    setState(() {
      _boms = boms;
      _pieceEmployees = piece;
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
    final result = await FactoryHubApi.mixingPreview(bomId: _bomId!, outputQuantity: qty);
    if (!mounted) return;
    setState(() {
      _previewing = false;
      if (result['error'] != null) {
        _error = result['error'];
      } else {
        _preview = result;
        _required = result['required'] ?? [];
        _shortages = result['shortages'] ?? [];
      }
    });
  }

  Future<void> _startAction() async {
    final qty = _outputQty;
    if (_bomId == null || qty == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await FactoryHubApi.startMixing(
      bomId: _bomId!,
      outputQuantity: qty,
      employeeId: _employeeId,
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
    if (result['warning'] != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['warning']),
        backgroundColor: AppColors.statusWarning,
      ));
    }
    setState(() {
      _preview = null;
      _required = [];
      _shortages = [];
      _qty.clear();
    });
  }

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
                  Text('Aralashtirish (xom-ashyo -> yarim tayyor)',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Materiallar darhol sarflanadi, natija qabul qiluvchi ombor tasdiqlashini kutadi.',
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
                      labelText: 'Retsept (mixing)',
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
                  if (_pieceEmployees.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _employeeId,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('— Tanlanmagan —')),
                        ..._pieceEmployees.map<DropdownMenuItem<int>>((e) => DropdownMenuItem(
                              value: e['id'],
                              child: Text('${e['fullName']} '
                                  '${(e['payType'] == 'hybrid') ? '(aralash)' : '(ishbay)'}'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _employeeId = v),
                      decoration: InputDecoration(
                        labelText: 'Kim bajaryapti (ixtiyoriy)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
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
                    _errorBox(_error!, _shortages),
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
    final src = p['sourceWarehouse'] as Map? ?? const {};
    final dst = p['destWarehouse'] as Map? ?? const {};
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
              'Manba: ${src['name'] ?? ''} → Qabul: ${dst['name'] ?? ''}',
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
                label: const Text('Aralashtirishni boshlash'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 15,
              color: ok ? AppColors.statusOk : AppColors.statusCritical),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
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

  Widget _errorBox(String message, List<dynamic> shortages) {
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