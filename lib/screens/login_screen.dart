import 'package:factory_hub/screens/super_admin_dashboard.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'factory_admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty) { _showError('Emailni kiriting'); return; }
    if (_password.text.isEmpty) { _showError('Parolni kiriting'); return; }

    setState(() { _loading = true; _error = null; _success = null; });

    final result = await FactoryHubApi.login(_email.text.trim(), _password.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['error'] != null) { _showError(result['error']); return; }

    final user = result['user'];
    if (user == null || user is! Map<String, dynamic>) { _showError('Noto\'g\'ri javob'); return; }

    final screen = FactoryHubApi.role == 'super_admin'
        ? SuperAdminDashboard(user: user)
        : FactoryHubApi.role == 'admin'
        ? FactoryAdminDashboard(user: user)
        : DashboardScreen(user: user);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }


  void _showError(String msg) {
    setState(() { _error = msg; _success = null; });
  }

  void _showSuccess(String msg) {
    setState(() { _success = msg; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Card(elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.factory, color: Colors.white, size: 45)),
          const SizedBox(height: 16),
          const Text('FactoryHub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
          const SizedBox(height: 24),

          // Xatolik
          if (_error != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),

          // Muvaffaqiyat
          if (_success != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_success!, style: TextStyle(color: Colors.green.shade700))),

          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'Parol', prefixIcon: const Icon(Icons.lock_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 24),
          _loading ? const CircularProgressIndicator() : Column(children: [
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Kirish', style: TextStyle(fontSize: 16)))),
            // const SizedBox(height: 10),
          ]),
        ])))),
      ),
    ));
  }
}