import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verbix/services/screen_time_service.dart';

class ScreenTimeEnforcer extends StatefulWidget {
  final Widget child;
  final String userId;

  const ScreenTimeEnforcer({
    super.key,
    required this.child,
    required this.userId,
  });

  @override
  State<ScreenTimeEnforcer> createState() => _ScreenTimeEnforcerState();
}

class _ScreenTimeEnforcerState extends State<ScreenTimeEnforcer> 
    with WidgetsBindingObserver {
  bool _isTimeLimitExceeded = false;
  int _currentUsage = 0;
  bool _isScreenTimeEnabled = false;
  bool _isParentUser = false;
  ScreenTimeService? _screenTimeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreenTime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_screenTimeService == null || _isParentUser) return;
    
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _screenTimeService!.stopSessionTracking();
    } else if (state == AppLifecycleState.resumed) {
      // Only resume if we're not showing the blocked screen and user is a child
      if (!_isTimeLimitExceeded) {
        _screenTimeService!.resumeTracking();
      }
    }
  }

  @override
  void dispose() {
    _screenTimeService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeScreenTime() async {
    // Check if user is a parent - if so, bypass screen time entirely
    await _checkUserType();
    
    if (_isParentUser) {
      return; // Don't initialize screen time for parents
    }

    // Initialize screen time service for child users only
    _screenTimeService = ScreenTimeService(widget.userId);
    
    // Set up callbacks for real-time updates
    _screenTimeService!.onUsageUpdate = (usage) {
      if (mounted) {
        setState(() {
          _currentUsage = usage;
        });
      } 
    };

    _screenTimeService!.onTimeLimitExceeded = () {
      if (mounted) {
        setState(() {
          _isTimeLimitExceeded = true;
        });
      }
    };

    // Initialize tracking
    await _screenTimeService!.initialize();
    _loadScreenTimeData();
  }

  Future<void> _checkUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('user_type');
      setState(() {
        _isParentUser = userType == 'parent';
      });
    } catch (e) {
      print('Error checking user type: $e');
      setState(() {
        _isParentUser = false; // Default to child for safety
      });
    }
  }

  void _loadScreenTimeData() {
    if (_screenTimeService == null) return;
    
    if (mounted) {
      setState(() {
        _isTimeLimitExceeded = _screenTimeService!.isTimeLimitExceeded;
        _currentUsage = _screenTimeService!.currentUsage;
        _isScreenTimeEnabled = _screenTimeService!.isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is a parent, always show the child content without restrictions
    if (_isParentUser) {
      return widget.child;
    }

    // If screen time is not enabled or limit not exceeded, show normal content
    if (!_isScreenTimeEnabled || !_isTimeLimitExceeded) {
      return widget.child;
    }

    // Show time limit exceeded screen
    return _buildTimeLimitExceededScreen();
  }

  Widget _buildTimeLimitExceededScreen() {
    final dailyLimit = _screenTimeService?.dailyLimit ?? 120;
    final progressValue = dailyLimit > 0 ? (_currentUsage / dailyLimit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF324259),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header with icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Screen Time Limit Reached',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'You\'ve used ${ScreenTimeService.formatTime(_currentUsage)} of your ${ScreenTimeService.formatTime(dailyLimit)} daily limit.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              
              // Progress indicator
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressValue >= 0.8 ? Colors.red : Colors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              Text(
                '${(progressValue * 100).round()}% of daily limit used',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 48),
              
              // Suggestions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Try these activities instead:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSuggestionItem(Icons.book, 'Read a book'),
                    _buildSuggestionItem(Icons.palette, 'Draw or paint'),
                    _buildSuggestionItem(Icons.sports_soccer, 'Play outside'),
                    _buildSuggestionItem(Icons.music_note, 'Listen to music'),
                    _buildSuggestionItem(Icons.family_restroom, 'Spend time with family'),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // Time until reset
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.refresh,
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeUntilReset(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white70,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilReset = tomorrow.difference(now);
    
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;
    
    if (hours > 0) {
      return 'Resets in ${hours}h ${minutes}m';
    } else {
      return 'Resets in ${minutes}m';
    }
  }
}