import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserAssignScreen extends StatefulWidget {
  final Map user;
  const UserAssignScreen({super.key, required this.user});

  @override
  State<UserAssignScreen> createState() => _UserAssignScreenState();
}

class _UserAssignScreenState extends State<UserAssignScreen> {
  List _departments = [];
  List _warehouses = [];
  Set<int> _selectedDepartments = {};
  Set<int> _selectedWarehouses = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    final results = await Future.wait([
      FactoryHubApi.getDepartments(),
      FactoryHubApi.getWarehouses(),
      FactoryHubApi.getUserDetail(int.parse(widget.user['id'].toString())),
    ]);

    final deptResult = results[0];
    final wareResult = results[1];
    final userDetail = results[2];

    if (deptResult['error'] != null) {
      setState(() { _error = deptResult['error']; _loading = false; });
      return;
    }

    _departments = (deptResult['departments'] as List?) ?? [];
    _warehouses = (wareResult['warehouses'] as List?) ?? [];

    final currentDepts = (userDetail['departments'] as List?) ?? [];
    final currentWares = (userDetail['warehouses'] as List?) ?? [];

    _selectedDepartments = currentDepts.map((d) => int.parse(d['id'].toString())).toSet();
    _selectedWarehouses = currentWares.map((w) => int.parse(w['id'].toString())).toSet();

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await FactoryHubApi.assignUser(
      userId: int.parse(widget.user['id'].toString()),
      departmentIds: _selectedDepartments.toList(),
      warehouseIds: _selectedWarehouses.toList(),
    );

    setState(() => _saving = false);

    if (!mounted) return;

    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biriktirildi!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('$username — biriktirish', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1565C0),
                          child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(widget.user['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ])),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // Bo'limlar
                    const Text('Bo\'limlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Bir nechta bo\'lim tanlash mumkin', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (_departments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Bo\'limlar mavjud emas', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._departments.map((d) {
                        final id = int.parse(d['id'].toString());
                        final selected = _selectedDepartments.contains(id);
                        return _checkCard(
                          title: d['name'] ?? '',
                          subtitle: d['description'],
                          icon: Icons.business_center,
                          selected: selected,
                          color: const Color(0xFF1565C0),
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedDepartments.remove(id);
                            } else {
                              _selectedDepartments.add(id);
                            }
                          }),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Omborlar
                    const Text('Omborlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Bir nechta ombor tanlash mumkin', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (_warehouses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Omborlar mavjud emas', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._warehouses.map((w) {
                        final id = int.parse(w['id'].toString());
                        final selected = _selectedWarehouses.contains(id);
                        return _checkCard(
                          title: w['name'] ?? '',
                          subtitle: w['type'],
                          icon: Icons.warehouse,
                          selected: selected,
                          color: Colors.orange,
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedWarehouses.remove(id);
                            } else {
                              _selectedWarehouses.add(id);
                            }
                          }),
                        );
                      }),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Saqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
    );
  }

  Widget _checkCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 1.5 : 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? color : Colors.grey.shade300,
        ),
        onTap: onTap,
      ),
    );
  }
}
