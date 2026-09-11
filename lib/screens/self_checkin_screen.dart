import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/colors.dart';

String _selfStatusLabel(String status) {
  switch (status) {
    case 'present':
      return 'Keldi';
    case 'absent':
      return 'Kelmadi';
    case 'late':
      return 'Kech qoldi';
    case 'sick_leave':
      return 'Kasal';
    case 'vacation':
      return 'Ta\'til';
    case 'unpaid_leave':
      return 'Ishsiz ruxsat';
    case 'business_trip':
      return 'Xizmat safari';
  }
  return status;
}

Color _selfStatusColor(String status) {
  if (status == 'present') return AppColors.statusOk;
  if (status == 'late' || status == 'on_leave') return AppColors.statusWarning;
  return AppColors.statusCritical;
}

class SelfCheckinScreen extends StatefulWidget {
  const SelfCheckinScreen({super.key});

  @override
  State<SelfCheckinScreen> createState() => _SelfCheckinScreenState();
}

class _SelfCheckinScreenState extends State<SelfCheckinScreen> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _att;
  String? _error;
  bool _loading = true;
  bool _sending = false;

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
    final res = await FactoryHubApi.getMyAttendance();
    if (!mounted) return;
    if (res['error'] != null) {
      setState(() {
        _loading = false;
        _error = res['error'];
      });
      return;
    }
    setState(() {
      _me = res;
      _att = res['attendance'] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<Position?> _locate() async {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
      final req = await Geolocator.requestPermission();
      if (req != LocationPermission.always && req != LocationPermission.whileInUse) {
        return null;
      }
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _mark(String type, String label) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final pos = await _locate();
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('GPS ni yoqib, ruxsat bering (lokatsiya kerak).'),
        ));
        return;
      }
      if (pos.accuracy > 300) {
        if (!mounted) return;
      }
      final res = await FactoryHubApi.selfCheckin(
        type: type,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      if (res['error'] != null) {
        final dist = res['distance'];
        final msg = dist != null
            ? '${res['error']} (masofa: ~$dist m)'
            : res['error'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _load();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label belgilandi. Ofis hududida tasdiqlandi.'),
        backgroundColor: AppColors.statusOk,
      ));
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunlik davomat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.statusCritical),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final att = _att;
    final today = DateFormat('EEEE, dd.MM.yyyy').format(DateTime.now());
    final name = _me?['employeeName']?.toString() ?? '';
    final checkIn = att?['checkIn'] as String?;
    final checkOut = att?['checkOut'] as String?;
    final status = att?['status']?.toString() ?? 'present';
    final early = att?['isEarlyLeave'] == true;
    final selfMarked = att?['markedBy'] == 'self';

    final haveIn = checkIn != null && checkIn.isNotEmpty;
    final haveOut = checkOut != null && checkOut.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(today,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        att != null
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: att != null
                            ? _selfStatusColor(status)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        att != null
                            ? _selfStatusLabel(status)
                            : 'Bugun hali belgilanmagan',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: att != null
                                ? _selfStatusColor(status)
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (att != null) ...[
                    const SizedBox(height: 12),
                    _timeRow('Kelish', checkIn),
                    _timeRow('Ketish', checkOut),
                    if (early && haveOut) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.wb_twilight,
                              size: 18, color: AppColors.statusWarning),
                          SizedBox(width: 6),
                          Text('Erta ketdi (18:00 dan oldin)',
                              style: TextStyle(
                                  color: AppColors.statusWarning,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    if (selfMarked) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.gps_fixed,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('GPS bilan o\'zi belgilangan',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!haveIn)
            _bigActionButton(
              icon: Icons.login,
              label: 'KELDIM',
              sublabel: 'Ofis hududida GPS bilan belgilanadi',
              color: AppColors.statusOk,
              onTap: () => _mark('in', 'Kelish'),
            )
          else if (!haveOut)
            _bigActionButton(
              icon: Icons.logout,
              label: 'KETDIM',
              sublabel: 'Pechat vaqti taxminan ${_nowHm()}',
              color: AppColors.primary,
              onTap: () => _mark('out', 'Ketish'),
            )
          else
            _bigActionButton(
              icon: Icons.check_circle_outline,
              label: 'Bugungi kun belgilandi',
              sublabel: 'Ertaga ham belgilashingiz mumkin',
              color: AppColors.statusOk,
              onTap: null,
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _sending ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Yangilash'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(String label, String? time) {
    final has = time != null && time.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(
            has ? time : '—',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: has ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _bigActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null || _sending ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  Icon(icon, size: 36, color: Colors.white),
                const SizedBox(height: 10),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(sublabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nowHm() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}