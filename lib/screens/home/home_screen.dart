import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReelAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // The AuthWrapper will automatically handle navigation
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome to ReelAI!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
} 