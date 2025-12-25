import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Service for playing UI sound effects using asset files
class SoundEffectService {
  AudioPlayer? _player;
  bool _isInitialized = false;

  /// Initialize the audio player with success sound from assets
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _player = AudioPlayer();
      
      // Load the success sound from assets
      await _player!.setAsset('assets/sound/success.mp3');
      
      _isInitialized = true;
      debugPrint('🔔 SoundEffectService initialized with asset sound');
    } catch (e) {
      debugPrint('❌ Error initializing SoundEffectService: $e');
      _player?.dispose();
      _player = null;
    }
  }

  /// Play the coin throw sound
  Future<void> playCoinThrow() async {
    await _playAsset('assets/coin/throw.mp3', speed: 0.8);
  }

  /// Play the coin land sound
  Future<void> playCoinLand() async {
    await _playAsset('assets/coin/land.mp3');
  }

  /// Helper to play any asset
  Future<void> _playAsset(String assetPath, {double speed = 1.0}) async {
    if (_player == null) {
      _player = AudioPlayer();
      _isInitialized = true;
    }
    
    try {
      // Reset speed to normal or target speed
      if (_player!.speed != speed) {
        await _player!.setSpeed(speed);
      }
      
      await _player!.setAsset(assetPath);
      await _player!.seek(Duration.zero);
      await _player!.play();
    } catch (e) {
      debugPrint('❌ Error playing sound $assetPath: $e');
    }
  }

  /// Play the success sound effect
  Future<void> playSuccess() async {
    await _playAsset('assets/sound/success.mp3');
  }

  /// Dispose of audio resources
  void dispose() {
    _player?.dispose();
    _player = null;
    _isInitialized = false;
  }
}

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) => SoundEffectService());
