import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verbix/widgets/custom_button.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  Future<void> _handleChildLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      Navigator.of(context).pushReplacementNamed('/auth');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', 'child');
      await prefs.setString('user_id', user.uid);

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!mounted) return;
      if (userDoc.exists) {
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        Navigator.of(context).pushReplacementNamed('/user_details');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _handleParentLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      Navigator.of(context).pushReplacementNamed('/auth');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', 'parent');
      await prefs.setString('user_id', user.uid);

      final parentDoc =
          await FirebaseFirestore.instance
              .collection('parents')
              .doc(user.uid)
              .get();
      if (!mounted) return;
      if (parentDoc.exists) {
        Navigator.of(context).pushReplacementNamed('/parent_dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/parent_details');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-right cloud (rotated slightly)
            Positioned(
              top: -100,
              right: -20,
              child: Transform.rotate(
                angle: -0.09,
                child: Opacity(
                    opacity: 0.5, // Decreased opacity
                    child: Image.asset(
                      'assets/images/cloud.webp',
                      width: 300,
                      height: 280,
                    ),
                ),
              ),
            ),
            // Bottom-left cloud (rotated +15 degrees)
            Positioned(
              bottom: -110,
              left: -30,
              child: Transform.rotate(
                angle: 0.68, // positive for clockwise
                child: Opacity(
                    opacity: 0.5, // Decreased opacity
                    child: Image.asset(
                      'assets/images/cloud.webp',
                      width: 270,
                      height: 270,
                    ),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/lexi_confused.webp', height: 240),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomButton(
                        icon: Icons.face,
                        label: 'Login as a Child',
                        onPressed: _handleChildLogin,
                        color: const Color(0xFF324259),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomButton(
                        icon: Icons.supervisor_account,
                        label: 'Login as a Parent',
                        onPressed: _handleParentLogin,
                        color: const Color(0xFF5D8AA8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}