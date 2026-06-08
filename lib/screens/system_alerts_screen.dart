import 'package:flutter/material.dart';

class SystemAlertsScreen extends StatelessWidget {
  const SystemAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tizim ogohlantirishlari'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Tez kunda...', style: TextStyle(fontSize: 18, color: Colors.grey)),
          Text('Zavodlar holati va xabarlar bu yerda', style: TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}
