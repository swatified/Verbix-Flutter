import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AudioService {
    static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

    final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  
    bool _isInitialized = false;
  bool _isMusicPlaying = false;
  String _currentMusicTrack = 'desert';
  bool _musicEnabled = true;
  bool _soundEffectsEnabled = true;

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

    Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
            await _loadUserPreferences();
      
            await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _updateMusicTrack();
      await _backgroundMusicPlayer.setVolume(0.5);
      
      _isInitialized = true;
      debugPrint('AudioService initialized successfully');
      
            if (_musicEnabled) {
        await playBackgroundMusic();
      }
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

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
          debugPrint('Loaded user audio preferences: track=$_currentMusicTrack, music=${_musicEnabled ? 'on' : 'off'}, sounds=${_soundEffectsEnabled ? 'on' : 'off'}');
        }
      }
    } catch (e) {
      debugPrint('Error loading user audio preferences: $e');
            _currentMusicTrack = 'desert';
      _musicEnabled = true;
      _soundEffectsEnabled = true;
    }
  }

    Future<void> _updateMusicTrack() async {
    try {
            await _backgroundMusicPlayer.stop();
      
            await _backgroundMusicPlayer.setSourceAsset(musicTracks[_currentMusicTrack] ?? musicTracks['desert']!);
      debugPrint('Music track updated to: $_currentMusicTrack');
    } catch (e) {
      debugPrint('Error updating music track: $e');
    }
  }

    Future<void> changeMusicTrack(String trackName) async {
    if (!musicTracks.containsKey(trackName)) {
      debugPrint('Invalid track name: $trackName');
      return;
    }
    
    if (_currentMusicTrack == trackName) return;
    
    _currentMusicTrack = trackName;
    
    try {
            bool wasPlaying = _isMusicPlaying;
      
            await _updateMusicTrack();
      
            if (wasPlaying && _musicEnabled) {
        await playBackgroundMusic();
      }
      
            await _saveUserPreferences();
    } catch (e) {
      debugPrint('Error changing music track: $e');
    }
  }

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
        debugPrint('Saved user audio preferences');
      }
    } catch (e) {
      debugPrint('Error saving user audio preferences: $e');
    }
  }

    Future<void> setMusicEnabled(bool enabled) async {
    if (_musicEnabled == enabled) return;
    
    _musicEnabled = enabled;
    
    try {
      if (_musicEnabled) {
        await playBackgroundMusic();
      } else {
        await pauseBackgroundMusic();
      }
      
            await _saveUserPreferences();
    } catch (e) {
      debugPrint('Error setting music enabled: $e');
    }
  }

    Future<void> setSoundEffectsEnabled(bool enabled) async {
    if (_soundEffectsEnabled == enabled) return;
    
    _soundEffectsEnabled = enabled;
    
    try {
            await _saveUserPreferences();
    } catch (e) {
      debugPrint('Error setting sound effects enabled: $e');
    }
  }

    Future<void> playBackgroundMusic() async {
    if (!_isInitialized) await initialize();
    if (!_musicEnabled) return;
    
    try {
      await _backgroundMusicPlayer.resume();
      _isMusicPlaying = true;
      debugPrint('Background music started');
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

    Future<void> pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      _isMusicPlaying = false;
      debugPrint('Background music paused');
    } catch (e) {
      debugPrint('Error pausing background music: $e');
    }
  }

    Future<void> playCorrectSound() async {
    if (!_soundEffectsEnabled) return;
    
    try {
      debugPrint('Attempting to play correct sound effect');
      
            bool wasPlaying = _isMusicPlaying;
      
            if (wasPlaying) {
        await pauseBackgroundMusic();
      }
      
            final effectPlayer = AudioPlayer();
      await effectPlayer.setVolume(1.0);
      
            await effectPlayer.play(AssetSource('audio/correct.mp3'));
      
            effectPlayer.onPlayerComplete.listen((event) {
                effectPlayer.dispose();
        debugPrint('Correct sound effect completed');
        
                if (wasPlaying && _musicEnabled) {
          playBackgroundMusic();
        }
      });
      
      debugPrint('Correct sound effect started');
    } catch (e) {
      debugPrint('Error playing correct sound: $e');
            if (_isMusicPlaying && _musicEnabled) {
        playBackgroundMusic();
      }
    }
  }

    Future<void> playWrongSound() async {
    if (!_soundEffectsEnabled) return;
    
    try {
      debugPrint('Attempting to play wrong sound effect');
      
            bool wasPlaying = _isMusicPlaying;
      
            if (wasPlaying) {
        await pauseBackgroundMusic();
      }
      
            final effectPlayer = AudioPlayer();
      await effectPlayer.setVolume(1.0);
      
            await effectPlayer.play(AssetSource('audio/wrong.mp3'));
      
            effectPlayer.onPlayerComplete.listen((event) {
                effectPlayer.dispose();
        debugPrint('Wrong sound effect completed');
        
                if (wasPlaying && _musicEnabled) {
          playBackgroundMusic();
        }
      });
      
      debugPrint('Wrong sound effect started');
    } catch (e) {
      debugPrint('Error playing wrong sound: $e');
            if (_isMusicPlaying && _musicEnabled) {
        playBackgroundMusic();
      }
    }
  }

    Future<void> dispose() async {
    try {
      await _backgroundMusicPlayer.dispose();
      _isInitialized = false;
      _isMusicPlaying = false;
      debugPrint('AudioService disposed');
    } catch (e) {
      debugPrint('Error disposing AudioService: $e');
    }
  }
  
    bool get isMusicPlaying => _isMusicPlaying;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEffectsEnabled => _soundEffectsEnabled;
  String get currentMusicTrack => _currentMusicTrack;
}