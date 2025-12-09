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

  /// Play the success sound effect
  Future<void> playSuccess() async {
    if (!_isInitialized || _player == null) {
      await init();
      if (!_isInitialized || _player == null) return;
    }
    
    try {
      // Reset to beginning before playing
      await _player!.seek(Duration.zero);
      await _player!.play();
      debugPrint('🔔 Playing success sound from asset');
    } catch (e) {
      debugPrint('❌ Error playing success sound: $e');
    }
  }

  /// Dispose of audio resources
  void dispose() {
    _player?.dispose();
    _player = null;
    _isInitialized = false;
  }
}

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) => SoundEffectService());
