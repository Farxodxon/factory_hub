import 'package:factory_hub/screens/user_assign_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List _users = [];
  List _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _selectedRole = 'all';

  final String _callerRole = FactoryHubApi.role;
  final int? _callerFactoryId = FactoryHubApi.factoryId;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getUsers();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      _users = (result['users'] as List?) ?? [];
      _filter();
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchSearch = q.isEmpty ||
            (u['username'] ?? '').toLowerCase().contains(q) ||
            (u['email'] ?? '').toLowerCase().contains(q);
        final matchRole = _selectedRole == 'all' || u['role'] == _selectedRole;
        return matchSearch && matchRole;
      }).toList();
    });
  }

  Future<void> _addUser() async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'employee';
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_add, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Yangi xodim'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ism *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Parol * (min 6)',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialog(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_callerRole == 'super_admin')
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Xodim')),
                    DropdownMenuItem(value: 'admin', child: Text('Zavod Admin')),
                  ],
                  onChanged: (v) => setDialog(() => role = v!),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text('Xodim sifatida qoshiladi', style: TextStyle(color: Colors.blue, fontSize: 13)),
                  ]),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Qoshish'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    if (usernameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      _showMsg('Barcha maydonlarni toldirib', isError: true);
      return;
    }
    if (passwordCtrl.text.length < 6) {
      _showMsg('Parol kamida 6 ta belgi', isError: true);
      return;
    }

    final result = await FactoryHubApi.createUser({
      'username': usernameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'password': passwordCtrl.text,
      'role': _callerRole == 'super_admin' ? role : 'employee',
      'factory_id': _callerFactoryId,
    });

    if (result['error'] != null) {
      _showMsg(result['error'], isError: true);
    } else {
      _showMsg('Xodim qoshildi!');
      _load();
    }
  }

  Future<void> _openAssign(Map user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserAssignScreen(user: user)),
    );
    if (result == true) _load();
  }

  Future<void> _toggleBlock(Map user) async {
    final isActive = user['isActive'] ?? true;
    final action = isActive ? 'bloklash' : 'faollashtirish';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${user['username']} ni $action'),
        content: Text('Bu amalni bajarishni tasdiqlaysizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Bloklash' : 'Faollashtirish'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final result = await FactoryHubApi.updateUser(
      int.parse(user['id'].toString()),
      {'is_active': !isActive},
    );

    if (result['error'] != null) {
      _showMsg(result['error'], isError: true);
    } else {
      _showMsg(isActive ? 'Bloklandi' : 'Faollashtirildi');
      _load();
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'super_admin': return const Color(0xFF0D47A1);
      case 'admin': return const Color(0xFF00897B);
      default: return const Color(0xFF7B1FA2);
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Zavod Admin';
      default: return 'Xodim';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Xodimlar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Xodim qoshish'),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Ism yoki email...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _filter(); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('all', 'Barchasi'),
                const SizedBox(width: 8),
                if (_callerRole == 'super_admin') ...[
                  _chip('admin', 'Adminlar'),
                  const SizedBox(width: 8),
                ],
                _chip('employee', 'Xodimlar'),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('Jami: ${_filtered.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            Text(
              'Faol: ${_filtered.where((u) => u['isActive'] == true).length} | Bloklangan: ${_filtered.where((u) => u['isActive'] == false).length}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _load, child: const Text('Qayta')),
          ]))
              : _filtered.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text('Xodimlar topilmadi', style: TextStyle(color: Colors.grey)),
          ]))
              : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _userCard(_filtered[i]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _selectedRole == value;
    return GestureDetector(
      onTap: () { setState(() => _selectedRole = value); _filter(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _userCard(Map user) {
    final role = user['role'] as String?;
    final color = _roleColor(role);
    final isActive = user['isActive'] ?? true;
    final username = user['username'] ?? '?';
    print('Building card for user: $username, role: $role, active: $isActive');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        border: isActive ? null : Border.all(color: Colors.red.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isActive ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
            child: Text(username[0].toUpperCase(),
                style: TextStyle(color: isActive ? color : Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (!isActive)
            Positioned(right: 0, bottom: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.block, color: Colors.white, size: 10),
                )),
        ]),
        title: Row(children: [
          Text(username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isActive ? Colors.black : Colors.grey)),
          if (!isActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
              child: const Text('Bloklangan', style: TextStyle(color: Colors.red, fontSize: 9)),
            ),
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(_roleLabel(role), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          itemBuilder: (_) => [
            if (role.toString() == "employee")
              const PopupMenuItem(
                value: 'assign',
                child: Row(children: [
                  Icon(Icons.assignment_ind, color: Color(0xFF1565C0), size: 18),
                  SizedBox(width: 8),
                  Text('Bolim/Ombor biriktirish'),
                ]),
              ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(isActive ? Icons.block : Icons.check_circle,
                    color: isActive ? Colors.red : Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(isActive ? 'Bloklash' : 'Faollashtirish'),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'toggle') _toggleBlock(user);
            if (v == 'assign') _openAssign(user);
          },
        ),
      ),
    );
  }
}
