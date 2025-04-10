import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class StepsService extends ChangeNotifier {
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

  final int _dailyGoal = 10000;
  int get dailyGoal => _dailyGoal;

  bool _goalReached = false;
  bool get goalReached => _goalReached;

  int _mockSteps = 5000;
  HealthFactory? _health;

  StepsService(this._firebaseInitialized)
    : _firestore = _firebaseInitialized ? FirebaseFirestore.instance : null,
      _auth = _firebaseInitialized ? FirebaseAuth.instance : null {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _health = HealthFactory();
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    if (_health != null) {
      await _requestPermissions();
      await _fetchRealSteps();
    } else {
      _todaySteps = _mockSteps;
    }

    await _loadStreakData();
    _calculateEarnings();
    _checkGoalStatus();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.activityRecognition.request();
        _hasPermissions = status.isGranted;
      } else if (Platform.isIOS) {
        _hasPermissions = true;
      }
    } catch (e) {
      _hasPermissions = false;
    }
  }

  Future<void> _fetchRealSteps() async {
    if (!_hasPermissions || _health == null) return;

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final types = [HealthDataType.STEPS];

      final hasPermissions = await HealthFactory.hasPermissions(types) ?? false;

      if (!hasPermissions) {
        final isGranted = await _health!.requestAuthorization(types);
        if (!isGranted) return;
      }

      final steps = await _health!.getHealthDataFromTypes(midnight, now, types);

      int totalSteps = 0;
      for (final dataPoint in steps) {
        if (dataPoint.type == HealthDataType.STEPS) {
          totalSteps += (dataPoint.value as num).toInt();
        }
      }

      _todaySteps = totalSteps;

      if (_firebaseInitialized && _auth?.currentUser != null) {
        await _syncStepsToFirestore(totalSteps);
      }
    } catch (e) {
      _todaySteps = _mockSteps;
    }
  }

  Future<void> _syncStepsToFirestore(int steps) async {
    if (!_firebaseInitialized || _auth?.currentUser == null) return;

    try {
      final userId = _auth!.currentUser!.uid;
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final query =
          await _firestore!
              .collection('steps')
              .where('userId', isEqualTo: userId)
              .where('date', isEqualTo: Timestamp.fromDate(midnight))
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        await _firestore.collection('steps').add({
          'userId': userId,
          'date': Timestamp.fromDate(midnight),
          'stepCount': steps,
          'earnings': _earnings,
          'multiplier': _multiplier,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await query.docs.first.reference.update({
          'stepCount': steps,
          'earnings': _earnings,
          'multiplier': _multiplier,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStreakData() async {
    _currentStreak = 3;
    _updateMultiplierFromStreak();
    notifyListeners();
  }

  void _calculateEarnings() {
    _earnings = (_todaySteps / 10000) * _multiplier;
    const maxEarnings = 2.0;
    if (_earnings > maxEarnings) _earnings = maxEarnings;
    notifyListeners();
  }

  void _updateMultiplierFromStreak() {
    _multiplier = 1.0 + (_currentStreak * 0.1);
    if (_multiplier > 2.0) _multiplier = 2.0;
    _calculateEarnings();
  }

  void _checkGoalStatus() {
    _goalReached = _todaySteps >= _dailyGoal;
    notifyListeners();
  }

  void addSteps(int steps) {
    _todaySteps += steps;
    _calculateEarnings();
    _checkGoalStatus();

    if (_firebaseInitialized && _auth?.currentUser != null) {
      _syncStepsToFirestore(_todaySteps);
    }

    notifyListeners();
  }

  Future<void> refreshSteps() async {
    _isLoading = true;
    notifyListeners();

    if (_health != null) {
      await _fetchRealSteps();
    } else {
      _mockSteps += 500;
      _todaySteps = _mockSteps;
    }

    _calculateEarnings();
    _checkGoalStatus();

    _isLoading = false;
    notifyListeners();
  }

  void applyBoostMultiplier(double boost) {
    _multiplier *= boost;
    _calculateEarnings();
    notifyListeners();
  }

  void incrementStreak() {
    _currentStreak++;
    _updateMultiplierFromStreak();
    notifyListeners();
  }
}
