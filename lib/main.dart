import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/super_admin_dashboard.dart';
import 'screens/factory_admin_dashboard.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const FactoryHubApp());
}

class FactoryHubApp extends StatelessWidget {
  const FactoryHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Saqlangan sessiyani tiklash
    final hasSession = await FactoryHubApi.restoreSession();

    if (!mounted) return;

    if (hasSession) {
      final user = FactoryHubApi.currentUser!;
      final role = FactoryHubApi.role;

      Widget screen;
      if (role == 'super_admin') {
        screen = SuperAdminDashboard(user: user);
      } else if (role == 'admin') {
        screen = FactoryAdminDashboard(user: user);
      } else {
        screen = DashboardScreen(user: user);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.precision_manufacturing, color: Colors.white, size: 80),
            SizedBox(height: 20),
            Text('FactoryHub', style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 8),
            Text('Yuklanmoqda...', style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
