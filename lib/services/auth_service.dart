// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final bool _firebaseInitialized;

  // Mock user for development without Firebase
  User? _mockUser;
  bool _mockSignedIn = false;

  AuthService(bool firebaseInitialized)
    : _firebaseInitialized = firebaseInitialized,
      _auth = firebaseInitialized ? FirebaseAuth.instance : null;

  User? get currentUser =>
      _firebaseInitialized
          ? _auth?.currentUser
          : (_mockSignedIn ? _mockUser : null);

  Stream<User?> get authStateChanges =>
      _firebaseInitialized
          ? _auth!.authStateChanges()
          : Stream.value(_mockUser);

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    if (!_firebaseInitialized) {
      // Mock implementation for development
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay
      _mockSignedIn = true;

      // Create mock user for development
      _mockUser = MockUser(
        uid: 'mock-user-123',
        email: email,
        displayName: 'Mock User',
      );

      log('Mock sign up successful: $email');
      notifyListeners();
      return null;
    }

    try {
      return await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      log('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_firebaseInitialized) {
      // Mock implementation for development
      await Future.delayed(
        const Duration(seconds: 1),
      ); // Simulate network delay
      _mockSignedIn = true;

      // Create mock user for development
      _mockUser = MockUser(
        uid: 'mock-user-123',
        email: email,
        displayName: 'Mock User',
      );

      log('Mock sign in successful: $email');
      notifyListeners();
      return null;
    }

    try {
      return await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      log('Error signing in: $e');
      rethrow;
    }
  }

  // Verify phone number
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String) onCodeSent,
    Function(String) onError,
  ) async {
    if (!_firebaseInitialized) {
      // Mock implementation for development
      await Future.delayed(const Duration(seconds: 1));
      onCodeSent('123456'); // Mock verification code
      return;
    }

    try {
      await _auth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verify on some devices
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Sign in with phone number verification code
  Future<UserCredential?> signInWithPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    if (!_firebaseInitialized) {
      // Mock implementation for development
      await Future.delayed(const Duration(seconds: 1));
      _mockSignedIn = true;

      // Create mock user for development
      _mockUser = MockUser(
        uid: 'mock-user-456',
        email: 'mock-phone@example.com',
        displayName: 'Mock Phone User',
      );

      log('Mock phone sign in successful');
      notifyListeners();
      return null;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth!.signInWithCredential(credential);
    } catch (e) {
      log('Error signing in with phone: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!_firebaseInitialized) {
      // Mock implementation
      _mockSignedIn = false;
      _mockUser = null;
      log('Mock sign out successful');
      notifyListeners();
      return;
    }

    try {
      await _auth!.signOut();
      notifyListeners();
    } catch (e) {
      log('Error signing out: $e');
      rethrow;
    }
  }
}

// Mock User class for development
class MockUser implements User {
  @override
  final String uid;
  @override
  final String email;
  @override
  final String displayName;

  MockUser({required this.uid, required this.email, required this.displayName});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
