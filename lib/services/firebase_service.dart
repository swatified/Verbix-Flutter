import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;
  
  /// Initializes Firebase only once during the app lifecycle
  static Future<void> initializeFirebase() async {
    if (!_initialized) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _initialized = true;
        print("Firebase initialized successfully");
      } catch (e) {
        if (e.toString().contains("already exists")) {
          // Firebase is already initialized
          _initialized = true;
          print("Firebase was already initialized");
        } else {
          print("Error initializing Firebase: $e");
          rethrow;
        }
      }
    } else {
      print("Firebase initialization was already called");
    }
  }
} 