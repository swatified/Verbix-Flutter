import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:verbix/services/audio_service.dart';
import 'package:verbix/services/firebase_service.dart';

import 'firebase_options.dart';
import 'pages/auth_screen.dart';
import 'pages/main_scaffold.dart';
import 'pages/parent_dashboard.dart';
import 'pages/parent_details.dart';
import 'pages/splash_screen.dart';
import 'pages/user_details.dart';
import 'pages/user_type_selection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await FirebaseService.initializeFirebase();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await ensureServiceAccountExists();
  final audioService = AudioService();
  await audioService.initialize();
  runApp(const MyApp());
}

Future<void> ensureServiceAccountExists() async {
  final directory = await getApplicationDocumentsDirectory();
  final credentialsPath = '${directory.path}/service-account.json';
  final file = File(credentialsPath);

  if (!await file.exists()) {
    try {
      final byteData = await rootBundle.load('assets/service-account.json');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    } catch (e) {
      print("ERROR: Failed to setup service account file: $e");
    }
  } else {
    print("DEBUG: Service account file already exists");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioService.playBackgroundMusic();
  }

  @override
  void dispose() {
    _audioService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _audioService.pauseBackgroundMusic();
    } else if (state == AppLifecycleState.resumed) {
      _audioService.playBackgroundMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verbix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF324259)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/main': (context) => const MainScaffold(),
        '/user_details': (context) => const UserDetailsScreen(),
        '/user_type_selection': (context) => const UserTypeSelectionScreen(),
        '/parent_dashboard': (context) => const ParentDashboardScreen(),
        '/parent_details': (context) => const ParentDetailsScreen(),
      },
    );
  }
}
