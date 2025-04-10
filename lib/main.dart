import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:burnbank/services/auth_service.dart';
import 'package:burnbank/services/steps_service.dart';
import 'package:burnbank/screens/auth/login_screen.dart';
//import 'package:burnbank/screens/home/home_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:burnbank/screens/main_screen.dart';
import 'firebase_options.dart';

// Import Firebase options when available

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase on supported platforms for now
  bool firebaseInitialized = false;

  try {
    // Initialize Firebase if possible
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      log('Firebase initialized successfully');
    } else {
      log('Running without Firebase (platform not configured yet)');
    }
  } catch (e) {
    log('Error initializing Firebase: $e');
    // Continue without Firebase for development
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(firebaseInitialized)),
        ChangeNotifierProvider(
            create: (_) => StepsService(firebaseInitialized)),
      ],
      child: const BurnBankApp(),
    ),
  );
}

class BurnBankApp extends StatelessWidget {
  const BurnBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BurnBank',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B00), // Orange from logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B00),
          secondary: const Color(0xFF6AAA52), // Green from logo
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6B00),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6AAA52),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Check if user is signed in
    final isSignedIn = authService.currentUser != null;

    // Return the appropriate screen based on authentication state
    return isSignedIn ? const MainScreen() : const LoginScreen();
  }
}
