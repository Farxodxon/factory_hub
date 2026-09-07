import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'user_access_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _users = [];
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
    final result = await FactoryHubApi.getUsers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _users = result['users'] ?? [];
    });
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateUserSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_users',
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: const Text('Xodim'),
      ),
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
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                  final u = _users[i];
                  final warehouses = (u['warehouses'] as List<dynamic>? ?? [])
                      .map((w) => w['name'])
                      .join(', ');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text((u['username'] ?? '?')[0].toUpperCase())),
                      title: Text(u['username'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((u['role'] as String?)?.label ?? '-'),
                          if ((u['department'] as String?)?.isNotEmpty == true)
                            Text('Bo\'lim: ${u['department']}',
                                style: const TextStyle(fontSize: 11)),
                          if (warehouses.isNotEmpty)
                            Text('Omborlar: $warehouses',
                                style: const TextStyle(fontSize: 11), maxLines: 2),
                        ],
                      ),
trailing: u['isActive'] == true
                          ? PopupMenuButton<String>(
                              onSelected: (s) async {
                                if (s == 'edit') {
                                  final ok = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _EditUserSheet(
                                      userId: u['id'] as int,
                                      username: u['username']?.toString() ?? '',
                                      email: u['email']?.toString() ?? '',
                                      role: u['role']?.toString() ?? AppRoles.warehouseKeeper,
                                      department: u['department']?.toString() ?? '',
                                    ),
                                  );
                                  if (ok == true) _load();
                                } else if (s == 'access') {
                                  final ok = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserAccessScreen(
                                        userId: u['id'] as int,
                                        username: u['username']?.toString() ?? '',
                                      ),
                                    ),
                                  );
                                  if (ok == true) _load();
                                } else if (s == 'deactivate') {
                                  await FactoryHubApi.deactivateUser(u['id']);
                                  _load();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text("Tahrirlash")),
                                PopupMenuItem(value: 'access', child: Text("Modul huquqlari")),
                                PopupMenuItem(value: 'deactivate', child: Text("Deaktivatsiya")),
                              ],
                            )
: const Chip(label: Text('Faol emas', style: TextStyle(fontSize: 10))),
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

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = AppRoles.warehouseKeeper;
  String _department = '';
  String? _error;

  static const List<String> _departments = [
    '',
    'Ishlab chiqarish',
    'Sotuv',
    'Xom ashyo',
    'Ombor',
    'Ta\'minot',
    'Boshqaruv',
    'Buxgalteriya',
    'Dillerlar',
    'IT',
  ];

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Barcha maydonlar majburiy');
      return;
    }

    final result = await FactoryHubApi.createUser({
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'role': _role,
      'department': _department,
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
            Text("Yangi xodim", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: InputDecoration(
                labelText: "F.I.SH.",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Parol',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: AppRoles.admin, child: Text('Admin')),
                DropdownMenuItem(value: AppRoles.operationsManager, child: Text('Ish boshqaruvchi')),
                DropdownMenuItem(value: AppRoles.warehouseKeeper, child: Text('Omborchi')),
                DropdownMenuItem(value: AppRoles.warehouseController, child: Text("Ombor nazoratchisi")),
                DropdownMenuItem(value: AppRoles.hrManager, child: Text('HR boshqaruvchi')),
                DropdownMenuItem(value: AppRoles.director, child: Text('Direktor')),
              ],
              onChanged: (v) => setState(() => _role = v ?? AppRoles.warehouseKeeper),
              decoration: InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department.isEmpty ? null : _department,
              items: _departments.where((d) => d.isNotEmpty).map((d) {
                return DropdownMenuItem(value: d, child: Text(d));
              }).toList(),
              onChanged: (v) => setState(() => _department = v ?? ''),
              decoration: InputDecoration(
                labelText: 'Bo\'lim (ixtiyoriy)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AppColors.statusCritical)),
            ],
const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text("Qo'shish")),
          ],
        ),
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  const _EditUserSheet({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.department,
  });

  final int userId;
  final String username;
  final String email;
  final String role;
  final String department;

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final _username = TextEditingController(text: widget.username);
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  late String _role = widget.role;
  late String _department = widget.department;
  String? _error;

  static const List<String> _departments = [
    '',
    'Ishlab chiqarish',
    'Sotuv',
    'Xom ashyo',
    'Ombor',
    'Ta\'minot',
    'Boshqaruv',
    'Buxgalteriya',
    'Dillerlar',
    'IT',
  ];

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = 'Barcha maydonlar majburiy');
      return;
    }

    final result = await FactoryHubApi.updateUser(widget.userId, {
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'role': _role,
      'department': _department,
      if (_password.text.isNotEmpty) 'password': _password.text,
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
            Text("Xodimni tahrirlash", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: InputDecoration(
                labelText: "F.I.SH.",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Yangi parol (ixtiyoriy)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: AppRoles.admin, child: Text('Admin')),
                DropdownMenuItem(value: AppRoles.operationsManager, child: Text('Ish boshqaruvchi')),
                DropdownMenuItem(value: AppRoles.warehouseKeeper, child: Text('Omborchi')),
                DropdownMenuItem(value: AppRoles.warehouseController, child: Text("Ombor nazoratchisi")),
                DropdownMenuItem(value: AppRoles.hrManager, child: Text('HR boshqaruvchi')),
                DropdownMenuItem(value: AppRoles.director, child: Text('Direktor')),
              ],
              onChanged: (v) => setState(() => _role = v ?? AppRoles.warehouseKeeper),
              decoration: InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department.isEmpty ? null : _department,
              items: _departments.where((d) => d.isNotEmpty).map((d) {
                return DropdownMenuItem(value: d, child: Text(d));
              }).toList(),
              onChanged: (v) => setState(() => _department = v ?? ''),
              decoration: InputDecoration(
                labelText: 'Bo\'lim (ixtiyoriy)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AppColors.statusCritical)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text("Saqlash")),
          ],
        ),
      ),
    );
  }
}

