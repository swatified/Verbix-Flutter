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
    // Add a slight delay to allow the splash screen to be visible
    Future.delayed(const Duration(seconds: 2), () {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Check if user is a parent
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .get();
            
        if (parentDoc.exists) {
          // User is a parent, navigate to parent dashboard
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/parent_dashboard');
          return;
        }
        
        // Check if user is a child with completed profile
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!mounted) return;
        
        if (userDoc.exists && userDoc.data()?.containsKey('firstName') == true) {
          // User has completed profile - navigate to MainScaffold
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // User needs to select account type
          Navigator.of(context).pushReplacementNamed('/user_type_selection');
        }
      } else {
        // No logged-in user
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      print('Error in splash screen: $e');
      // On error, go to auth screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Define customizable dimensions
    final double horizontalPadding = 60.0;
    final double imageWidth = screenWidth - (horizontalPadding * 2);
    
    // Progress indicator customization
    final double progressSize = 60.0;
    final Color progressColor = const Color.fromARGB(255, 169, 196, 219); // You can customize this color

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
              Image.asset(
                'assets/images/lexi_splash.webp',
                width: imageWidth,
                fit: BoxFit.contain,
              ),
              SizedBox(
                width: progressSize,
                height: progressSize,
                child: CircularProgressIndicator(
                  strokeWidth: 5.0,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}