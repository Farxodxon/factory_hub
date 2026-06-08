import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await FactoryHubApi.getUsers();
    if (result['error'] != null) {
      setState(() { _error = result['error']; _loading = false; });
    } else {
      setState(() { _users = (result['users'] as List?) ?? []; _loading = false; });
    }
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
        title: const Text('Foydalanuvchilar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final role = u['role'] as String?;
                    final color = _roleColor(role);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Text((u['username'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(_roleLabel(role), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
