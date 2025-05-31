import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  Future<void> _handleChildLogin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      // Redirect to login screen
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    try {
      // Check if user details already exist
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        // User details already exist, redirect to main screen
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        // User details don't exist, show details form
        Navigator.of(context).pushReplacementNamed('/user_details');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleParentLogin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      // Redirect to login screen
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    try {
      // Check if parent details already exist
      final parentDoc = await FirebaseFirestore.instance.collection('parents').doc(user.uid).get();
      if (parentDoc.exists) {
        // Parent details already exist, redirect to dashboard
        Navigator.of(context).pushReplacementNamed('/parent_dashboard');
      } else {
        // Parent details don't exist, show details form
        Navigator.of(context).pushReplacementNamed('/parent_details');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

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
                onPressed: () => _handleChildLogin(context),
                color: const Color(0xFF324259),
              ),
              const SizedBox(height: 20),
              _buildSelectionButton(
                context,
                icon: Icons.supervisor_account,
                label: 'Login as a Parent',
                onPressed: () => _handleParentLogin(context),
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