import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScreenTimeService {
  final String userId;
  Timer? _usageTimer;
  DateTime? _sessionStartTime;
  int _dailyUsageMinutes = 0;
  bool _isEnabled = false;
  int _dailyLimitMinutes = 120; // Default 2 hours
  
  // Callbacks for UI updates
  Function(int)? onUsageUpdate;
  Function()? onTimeLimitExceeded;
  
  ScreenTimeService(this.userId);

  /// Initialize screen time tracking for this user instance
  Future<void> initialize() async {
    await _loadSettingsFromFirestore();
    await _loadDailyUsage();
    _startSessionTracking();
  }

  /// Start tracking the current session
  void _startSessionTracking() {
    if (_sessionStartTime != null) return; // Already tracking
    
    _sessionStartTime = DateTime.now();
    
    // Update usage every minute
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDailyUsage();
    });
  }

  /// Stop tracking the current session
  void stopSessionTracking() {
    if (_sessionStartTime != null) {
      _updateDailyUsage();
    }
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  /// Resume tracking when app becomes active
  void resumeTracking() {
    _sessionStartTime = DateTime.now();
  }

  /// Update daily usage based on current session
  void _updateDailyUsage() {
    if (_sessionStartTime == null) return;
    
    final sessionMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
    if (sessionMinutes > 0) {
      _dailyUsageMinutes += sessionMinutes;
      _sessionStartTime = DateTime.now(); // Reset session start
      
      _saveDailyUsage();
      onUsageUpdate?.call(_dailyUsageMinutes);
      
      // Check if limit exceeded
      if (_isEnabled && _dailyUsageMinutes >= _dailyLimitMinutes) {
        onTimeLimitExceeded?.call();
      }
    }
  }

  /// Load settings from Firestore
  Future<void> _loadSettingsFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('screen_time')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _isEnabled = data['enabled'] ?? false;
        _dailyLimitMinutes = data['daily_limit_minutes'] ?? 120;
      }
    } catch (e) {
      print('Error loading screen time settings: $e');
    }
  }

  /// Load daily usage from Firestore
  Future<void> _loadDailyUsage() async {
    try {
      final todayKey = _getTodayKey();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('screen_time_usage')
          .doc(todayKey)
          .get();
      
      if (doc.exists) {
        _dailyUsageMinutes = doc.data()?['minutes'] ?? 0;
      } else {
        _dailyUsageMinutes = 0;
      }
    } catch (e) {
      print('Error loading daily usage: $e');
      _dailyUsageMinutes = 0;
    }
  }

  /// Save daily usage to Firestore
  Future<void> _saveDailyUsage() async {
    try {
      final todayKey = _getTodayKey();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('screen_time_usage')
          .doc(todayKey)
          .set({
        'minutes': _dailyUsageMinutes,
        'date': todayKey,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving daily usage: $e');
    }
  }

  /// Set screen time enabled/disabled for a child (called by parent)
  static Future<void> setScreenTimeEnabled(String childId, bool enabled) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('settings')
          .doc('screen_time')
          .set({
        'enabled': enabled,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting screen time enabled: $e');
    }
  }

  /// Set daily time limit for a child (called by parent)
  static Future<void> setDailyTimeLimit(String childId, int minutes) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('settings')
          .doc('screen_time')
          .set({
        'daily_limit_minutes': minutes,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting daily time limit: $e');
    }
  }

  /// Get screen time enabled status for a child
  static Future<bool> isScreenTimeEnabled(String childId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('settings')
          .doc('screen_time')
          .get();
      
      return doc.data()?['enabled'] ?? false;
    } catch (e) {
      print('Error getting screen time enabled status: $e');
      return false;
    }
  }

  /// Get daily time limit for a child
  static Future<int> getDailyTimeLimit(String childId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(childId)
          .collection('settings')
          .doc('screen_time')
          .get();
      
      return doc.data()?['daily_limit_minutes'] ?? 120;
    } catch (e) {
      print('Error getting daily time limit: $e');
      return 120;
    }
  }

  /// Get current day key for usage tracking
  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get current usage for UI display
  int get currentUsage => _dailyUsageMinutes;
  
  /// Get daily limit for UI display
  int get dailyLimit => _dailyLimitMinutes;
  
  /// Get enabled status for UI display
  bool get isEnabled => _isEnabled;
  
  /// Check if time limit is exceeded
  bool get isTimeLimitExceeded => _isEnabled && _dailyUsageMinutes >= _dailyLimitMinutes;

  /// Get remaining time in minutes
  int get remainingMinutes => _isEnabled ? (_dailyLimitMinutes - _dailyUsageMinutes).clamp(0, _dailyLimitMinutes) : _dailyLimitMinutes;

  /// Format minutes as readable time
  static String formatTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _usageTimer?.cancel();
    _usageTimer = null;
    _sessionStartTime = null;
  }
}