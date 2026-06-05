import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

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
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
