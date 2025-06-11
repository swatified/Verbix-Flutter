import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .get();
            
        if (parentDoc.exists) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/parent_dashboard');
          return;
        }
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!mounted) return;
        
        if (userDoc.exists && userDoc.data()?.containsKey('firstName') == true) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          Navigator.of(context).pushReplacementNamed('/user_type_selection');
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      debugPrint('Error in splash screen: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = 60.0;
    final double imageWidth = screenWidth - (horizontalPadding * 2);

    return Scaffold(
      backgroundColor: const Color(0xFFB9DBE4),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 40.0,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // GIF background
              Image.asset(
                'assets/gifs/lexi_splash.gif',
                width: imageWidth,
                fit: BoxFit.contain,
              ),
              // Image overlay
              Image.asset(
                'assets/images/splash_foreground.webp',
                width: imageWidth,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}