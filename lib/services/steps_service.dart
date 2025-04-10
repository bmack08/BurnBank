// lib/services/steps_service.dart - COMPLETE FILE
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class StepsService extends ChangeNotifier {
  // All properties grouped at the top
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final bool _firebaseInitialized;
  
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;
  
  double _earnings = 0.0;
  double get earnings => _earnings;
  
  double _multiplier = 1.0;
  double get multiplier => _multiplier;
  
  bool _hasPermissions = false;
  bool get hasPermissions => _hasPermissions;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  int _currentStreak = 0;
  int get currentStreak => _currentStreak;

  int _dailyGoal = 10000;
  int get dailyGoal => _dailyGoal;

  bool _goalReached = false;
  bool get goalReached => _goalReached;
  
  // For development without Firebase
  int _mockSteps = 5000;
  
  // Health API integration
  HealthFactory? _health;
  
  // Constructor
  StepsService(bool firebaseInitialized)
      : _firebaseInitialized = firebaseInitialized,
        _firestore = firebaseInitialized ? FirebaseFirestore.instance : null,
        _auth = firebaseInitialized ? FirebaseAuth.instance : null {
    // Initialize health package if on mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _health = HealthFactory();
    }
  }
  
  // Initialize the service with real step tracking
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    if (_health != null) {
      await _requestPermissions();
      await _fetchRealSteps();
    } else {
      // Fallback to mock data for web or development
      _todaySteps = _mockSteps;
    }
    
    await _loadStreakData();
    _calculateEarnings();
    _checkGoalStatus();
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Load streak data
  Future<void> _loadStreakData() async {
    // In a real app, this would load from Firebase
    // For now, we'll use mock data
    _currentStreak = 3; // Mock streak of 3 days
    _updateMultiplierFromStreak();
    notifyListeners();
  }
  
  // Request health permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.activityRecognition.request();
        _hasPermissions = status.isGranted;
      } else if (Platform.isIOS) {
        // HealthKit handles permissions at runtime via the Health package
        _hasPermissions = true;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      _hasPermissions = false;
    }
  }
  
  // Fetch real steps from health APIs
  Future<void> _fetchRealSteps() async {
    if (!_hasPermissions || _health == null) return;
    
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Request permission to access step data
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];
      
      final hasPermissions = await _health!.hasPermissions(types) ?? false;
      
      if (!hasPermissions) {
        final isGranted = await _health!.requestAuthorization(types);
        if (!isGranted) {
          print('Health permissions denied');
          return;
        }
      }
      
      // Get step data for today
      final steps = await _health!.getHealthDataFromTypes(midnight, now, types);
      
      int totalSteps = 0;
      for (final dataPoint in steps) {
        if (dataPoint.type == HealthDataType.STEPS) {
          totalSteps += (dataPoint.value as NumericHealthValue).numericValue.toInt();
        }
      }
      
      _todaySteps = totalSteps;
      
      // Sync to Firestore if connected
      if (_firebaseInitialized && _auth?.currentUser != null) {
        await _syncStepsToFirestore(totalSteps);
      }
    } catch (e) {
      print('Error fetching steps: $e');
      // Fall back to mock data if health integration fails
      _todaySteps = _mockSteps;
    }
  }
  
  // Sync steps to Firestore
  Future<void> _syncStepsToFirestore(int steps) async {
    if (!_firebaseInitialized || _auth?.currentUser == null) return;
    
    try {
      final userId = _auth!.currentUser!.uid;
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Check if we already have an entry for today
      final query = await _firestore!
          .collection('steps')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: Timestamp.fromDate(midnight))
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        // Create new entry
        await _firestore!.collection('steps').add({
          'userId': userId,
          'date': Timestamp.fromDate(midnight),
          'stepCount': steps,
          'earnings': _earnings,
          'multiplier': _multiplier,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing entry
        await query.docs.first.reference.update({
          'stepCount': steps,
          'earnings': _earnings,
          'multiplier': _multiplier,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error syncing steps to Firestore: $e');
    }
  }
  
  // Calculate earnings based on steps
  void _calculateEarnings() {
    // $1 for every 10,000 steps
    _earnings = (_todaySteps / 10000) * _multiplier;
    
    // Apply daily earnings cap based on subscription
    final maxEarnings = 2.0; // $2/day for free users
    if (_earnings > maxEarnings) {
      _earnings = maxEarnings;
    }
    
    notifyListeners();
  }
  
  // Calculate multiplier based on streak
  void _updateMultiplierFromStreak() {
    // Base multiplier is 1.0
    // Each streak day adds 0.1 (10%)
    _multiplier = 1.0 + (_currentStreak * 0.1);
    
    // Cap the multiplier if needed
    final maxMultiplier = 2.0;
    if (_multiplier > maxMultiplier) {
      _multiplier = maxMultiplier;
    }
    
    _calculateEarnings();
  }

  // Check if daily goal is reached
  void _checkGoalStatus() {
    _goalReached = _todaySteps >= _dailyGoal;
    notifyListeners();
  }

  // Add this method to your steps_service.dart file
  void addSteps(int steps) {
    _todaySteps += steps;
    _calculateEarnings();
    _checkGoalStatus();
  
  // Sync to Firestore if connected
    if (_firebaseInitialized && _auth?.currentUser != null) {
    _syncStepsToFirestore(_todaySteps);
  }
  
  notifyListeners();
}
  
  // Update steps data (for real devices or development testing)
  Future<void> refreshSteps() async {
    _isLoading = true;
    notifyListeners();
    
    if (_health != null) {
      await _fetchRealSteps();
    } else {
      // Use mock data for development
      _mockSteps += 500;
      _todaySteps = _mockSteps;
    }
    
    _calculateEarnings();
    _checkGoalStatus();
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Apply boost multiplier (e.g. from watching an ad)
  void applyBoostMultiplier(double boost) {
    _multiplier *= boost;
    _calculateEarnings();
    notifyListeners();
  }
  
  // Increment streak (for testing)
  void incrementStreak() {
    _currentStreak++;
    _updateMultiplierFromStreak();
    notifyListeners();
  }
}

