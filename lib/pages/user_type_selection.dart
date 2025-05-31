import 'package:flutter/material.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/lexi_rest.webp',
                height: 130,
              ),
              const SizedBox(height: 30),
              const Text(
                'Who are you?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              _buildSelectionButton(
                context,
                icon: Icons.face,
                label: 'Login as a Child',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/user_details');
                },
                color: const Color(0xFF324259),
              ),
              const SizedBox(height: 20),
              _buildSelectionButton(
                context,
                icon: Icons.supervisor_account,
                label: 'Login as a Parent',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/parent_details');
                },
                color: const Color(0xFF5D8AA8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 