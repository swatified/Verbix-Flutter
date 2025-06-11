import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;
  
  static Future<void> initializeFirebase() async {
    if (!_initialized) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _initialized = true;
        debugPrint("Firebase initialized successfully");
      } catch (e) {
        if (e.toString().contains("already exists")) {
                    _initialized = true;
          debugPrint("Firebase was already initialized");
        } else {
          debugPrint("Error initializing Firebase: $e");
          rethrow;
        }
      }
    } else {
      debugPrint("Firebase initialization was already called");
    }
  }
} 