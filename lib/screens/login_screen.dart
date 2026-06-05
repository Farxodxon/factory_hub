import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

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

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
  }

  Future<void> _register() async {
    if (_email.text.trim().isEmpty) { _showError('Emailni kiriting'); return; }
    if (_password.text.isEmpty) { _showError('Parolni kiriting'); return; }
    if (_password.text.length < 3) { _showError('Parol kamida 3 ta belgi'); return; }

    setState(() { _loading = true; _error = null; _success = null; });

    final username = _email.text.trim().split('@').first;
    final result = await FactoryHubApi.login(_email.text.trim(), _password.text.trim());

    // Agar login muvaffaqiyatsiz bo'lsa, ro'yxatdan o'tkazamiz
    if (result['error'] != null) {
      final regResult = await FactoryHubApi.setupSuperAdmin(
        username, _email.text.trim(), _password.text.trim(), 'factory_hub_2026_secret',
      );
      setState(() => _loading = false);
      if (regResult['error'] != null) {
        _showError(regResult['error']);
      } else {
        _showSuccess('Ro\'yxatdan o\'tdingiz! Endi kirishingiz mumkin');
      }
      return;
    }

    setState(() => _loading = false);
    _showError('Bu foydalanuvchi allaqachon mavjud');
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
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: _register, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Ro\'yxatdan o\'tish', style: TextStyle(fontSize: 16)))),
          ]),
        ])))),
      ),
    ));
  }
}
