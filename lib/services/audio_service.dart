import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AudioService {
  // Singleton pattern with private constructor
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Players - one for background music, multiple for sound effects
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  
  // State tracking
  bool _isInitialized = false;
  bool _isMusicPlaying = false;
  String _currentMusicTrack = 'desert';
  bool _musicEnabled = true;
  bool _soundEffectsEnabled = true;

  // Available music tracks
  static const Map<String, String> musicTracks = {
    'desert': 'audio/desert.mp3',
    'lofi': 'audio/lofi.mp3',
    'funny': 'audio/funny.mp3',
    'funky': 'audio/funky.mp3',
    'chill-gaming': 'audio/chill-gaming.mp3',
    'blue': 'audio/blue.mp3',
    'spring': 'audio/spring.mp3',
    'coffee': 'audio/coffee.mp3',
  };

  // Initialize the service - make this safe to call multiple times
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load user preferences
      await _loadUserPreferences();
      
      // Configure background music player
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _updateMusicTrack();
      await _backgroundMusicPlayer.setVolume(0.5);
      
      _isInitialized = true;
      print('AudioService initialized successfully');
      
      // Start playing music if enabled
      if (_musicEnabled) {
        await playBackgroundMusic();
      }
    } catch (e) {
      print('Error initializing AudioService: $e');
    }
  }

  // Load user audio preferences from Firestore
  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (docSnapshot.exists) {
          final userData = docSnapshot.data();
          _currentMusicTrack = userData?['musicTrack'] ?? 'desert';
          _musicEnabled = userData?['musicEnabled'] ?? true;
          _soundEffectsEnabled = userData?['soundEffectsEnabled'] ?? true;
          print('Loaded user audio preferences: track=$_currentMusicTrack, music=${_musicEnabled ? 'on' : 'off'}, sounds=${_soundEffectsEnabled ? 'on' : 'off'}');
        }
      }
    } catch (e) {
      print('Error loading user audio preferences: $e');
      // Use defaults if there's an error
      _currentMusicTrack = 'desert';
      _musicEnabled = true;
      _soundEffectsEnabled = true;
    }
  }

  // Update music track based on current selection
  Future<void> _updateMusicTrack() async {
    try {
      // Stop current playback
      await _backgroundMusicPlayer.stop();
      
      // Set new source
      await _backgroundMusicPlayer.setSourceAsset(musicTracks[_currentMusicTrack] ?? musicTracks['desert']!);
      print('Music track updated to: $_currentMusicTrack');
    } catch (e) {
      print('Error updating music track: $e');
    }
  }

  // Change music track
  Future<void> changeMusicTrack(String trackName) async {
    if (!musicTracks.containsKey(trackName)) {
      print('Invalid track name: $trackName');
      return;
    }
    
    if (_currentMusicTrack == trackName) return;
    
    _currentMusicTrack = trackName;
    
    try {
      // Remember if music was playing
      bool wasPlaying = _isMusicPlaying;
      
      // Update the track
      await _updateMusicTrack();
      
      // Resume playback if it was playing before and music is enabled
      if (wasPlaying && _musicEnabled) {
        await playBackgroundMusic();
      }
      
      // Save preference to user's profile
      await _saveUserPreferences();
    } catch (e) {
      print('Error changing music track: $e');
    }
  }

  // Save user audio preferences to Firestore
  Future<void> _saveUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'musicTrack': _currentMusicTrack,
          'musicEnabled': _musicEnabled,
          'soundEffectsEnabled': _soundEffectsEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Saved user audio preferences');
      }
    } catch (e) {
      print('Error saving user audio preferences: $e');
    }
  }

  // Set music enabled/disabled
  Future<void> setMusicEnabled(bool enabled) async {
    if (_musicEnabled == enabled) return;
    
    _musicEnabled = enabled;
    
    try {
      if (_musicEnabled) {
        await playBackgroundMusic();
      } else {
        await pauseBackgroundMusic();
      }
      
      // Save preference to user's profile
      await _saveUserPreferences();
    } catch (e) {
      print('Error setting music enabled: $e');
    }
  }

  // Set sound effects enabled/disabled
  Future<void> setSoundEffectsEnabled(bool enabled) async {
    if (_soundEffectsEnabled == enabled) return;
    
    _soundEffectsEnabled = enabled;
    
    try {
      // Save preference to user's profile
      await _saveUserPreferences();
    } catch (e) {
      print('Error setting sound effects enabled: $e');
    }
  }

  // Play background music - safe to call multiple times
  Future<void> playBackgroundMusic() async {
    if (!_isInitialized) await initialize();
    if (!_musicEnabled) return;
    
    try {
      await _backgroundMusicPlayer.resume();
      _isMusicPlaying = true;
      print('Background music started');
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  // Pause background music
  Future<void> pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      _isMusicPlaying = false;
      print('Background music paused');
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  // Play correct answer sound
  Future<void> playCorrectSound() async {
    if (!_soundEffectsEnabled) return;
    
    try {
      print('Attempting to play correct sound effect');
      
      // Remember if music was playing
      bool wasPlaying = _isMusicPlaying;
      
      // Pause background music temporarily
      if (wasPlaying) {
        await pauseBackgroundMusic();
      }
      
      // Create a temporary player for the sound effect
      final effectPlayer = AudioPlayer();
      await effectPlayer.setVolume(1.0);
      
      // Play the sound effect and wait for it to complete
      await effectPlayer.play(AssetSource('audio/correct.mp3'));
      
      // Set up a listener to restart background music when the effect finishes
      effectPlayer.onPlayerComplete.listen((event) {
        // Clean up the effect player
        effectPlayer.dispose();
        print('Correct sound effect completed');
        
        // Restart background music if it was playing before and music is enabled
        if (wasPlaying && _musicEnabled) {
          playBackgroundMusic();
        }
      });
      
      print('Correct sound effect started');
    } catch (e) {
      print('Error playing correct sound: $e');
      // Ensure music restarts if there was an error
      if (_isMusicPlaying && _musicEnabled) {
        playBackgroundMusic();
      }
    }
  }

  // Play wrong answer sound
  Future<void> playWrongSound() async {
    if (!_soundEffectsEnabled) return;
    
    try {
      print('Attempting to play wrong sound effect');
      
      // Remember if music was playing
      bool wasPlaying = _isMusicPlaying;
      
      // Pause background music temporarily
      if (wasPlaying) {
        await pauseBackgroundMusic();
      }
      
      // Create a temporary player for the sound effect
      final effectPlayer = AudioPlayer();
      await effectPlayer.setVolume(1.0);
      
      // Play the sound effect
      await effectPlayer.play(AssetSource('audio/wrong.mp3'));
      
      // Set up a listener to restart background music when the effect finishes
      effectPlayer.onPlayerComplete.listen((event) {
        // Clean up the effect player
        effectPlayer.dispose();
        print('Wrong sound effect completed');
        
        // Restart background music if it was playing before and music is enabled
        if (wasPlaying && _musicEnabled) {
          playBackgroundMusic();
        }
      });
      
      print('Wrong sound effect started');
    } catch (e) {
      print('Error playing wrong sound: $e');
      // Ensure music restarts if there was an error
      if (_isMusicPlaying && _musicEnabled) {
        playBackgroundMusic();
      }
    }
  }

  // Dispose of resources - only call when app is shutting down
  Future<void> dispose() async {
    try {
      await _backgroundMusicPlayer.dispose();
      _isInitialized = false;
      _isMusicPlaying = false;
      print('AudioService disposed');
    } catch (e) {
      print('Error disposing AudioService: $e');
    }
  }
  
  // Getters for current state
  bool get isMusicPlaying => _isMusicPlaying;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEffectsEnabled => _soundEffectsEnabled;
  String get currentMusicTrack => _currentMusicTrack;
}