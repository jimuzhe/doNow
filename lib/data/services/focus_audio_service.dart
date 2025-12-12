import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusAudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false; // Tracks if audio is actually outputting/playing
  bool _isSessionActive = false; // Tracks if the user *intends* for audio to be active (timer running)
  File? _silentFile;
  Timer? _keepAliveTimer;
  
  FocusSoundType _currentType = FocusSoundType.none;
  double _volume = 0.5;

  Future<void> init() async {
    // Configure audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Prepare silent audio file for keep-alive on native platforms
    if (!kIsWeb) {
      await _prepareSilentFile();
    }
  }

  Future<void> _prepareSilentFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _silentFile = File('${dir.path}/silent_keep_alive.wav');
      if (!await _silentFile!.exists()) {
        // Generate a 1-second silent WAV file
        final bytes = _generateSilentWav(1); // 1 second
        await _silentFile!.writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint("Error preparing silent file: $e");
    }
  }

  Uint8List _generateSilentWav(int durationSeconds) {
    const int sampleRate = 44100;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = durationSeconds * byteRate;
    final int fileSize = 36 + dataSize;

    final buffer = ByteData(fileSize + 8);
    // RIFF chunk
    buffer.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    // fmt chunk
    buffer.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    buffer.setUint32(16, 16, Endian.little); // Chunk size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    buffer.setUint32(36, 0x64617461, Endian.big); // "data"
    buffer.setUint32(40, dataSize, Endian.little);
    
    // Data is all zeros (silence), which is default for ByteData

    return buffer.buffer.asUint8List();
  }

  /// Start the focus session (active timer).
  /// This will play audio if a sound is selected.
  Future<void> startFocusSound() async {
    _isSessionActive = true;
    await _updateAudioState();
  }

  /// Stop the focus session (timer paused/stopped).
  Future<void> stopFocusSound() async {
    _isSessionActive = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    
    try {
      await _player.stop();
      _isPlaying = false; 
      debugPrint('🔇 Focus audio stopped (Session Ended)');
    } catch (e) {
      debugPrint('❌ Error stopping audio: $e');
    }
  }

  /// Internal method to sync player state with session state and selection
  Future<void> _updateAudioState() async {
    if (!_isSessionActive) return; // Should not play if session inactive

    try {
      if (_currentType == FocusSoundType.none) {
        // User wants silence
        if (kIsWeb) {
            await _player.stop();
            _isPlaying = false;
            return;
        }

        // Native: Play silent file for background keep-alive
        if (_silentFile == null) await _prepareSilentFile();
        if (_silentFile != null) {
            await _player.setFilePath(_silentFile!.path);
            await _player.setVolume(0.0);
            await _player.setLoopMode(LoopMode.one);
            await _player.play();
            _isPlaying = true;
        }
      } else {
        // User selected a sound
        try {
          // Stop first to ensure clean state switch (helps with some "no response" issues)
          if (_isPlaying) await _player.stop(); 
          
          await _player.setAsset(_currentType.assetPath);
          await _player.setVolume(_volume);
          await _player.setLoopMode(LoopMode.one);
          await _player.play();
          
          _isPlaying = true;
          debugPrint('🎵 Playing: ${_currentType.name}');
        } catch (assetError) {
          debugPrint('⚠️ Error playing asset: $assetError');
          // Fallback logic...
          if (!kIsWeb && _silentFile != null) {
             await _player.setFilePath(_silentFile!.path);
             await _player.setVolume(0.0);
             await _player.play();
          }
        }
      }
      
      // Keep-alive timer logic
      _keepAliveTimer?.cancel();
      if (_isPlaying) {
        _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _ensureAudioPlaying());
      }
      
    } catch (e) {
      debugPrint('❌ Error updating audio state: $e');
    }
  }

  /// Switch the sound type while playing
  Future<void> setSoundType(FocusSoundType type) async {
    if (_currentType == type) return;
    _currentType = type;
    
    // If session is active, apply the new sound immediately
    if (_isSessionActive) {
      await _updateAudioState();
    }
  }

  /// Update volume for white noise
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isPlaying && _currentType != FocusSoundType.none) {
      await _player.setVolume(_volume);
    }
  }
  
  FocusSoundType get currentType => _currentType;
  double get currentVolume => _volume;

  void _ensureAudioPlaying() {
    if (_isSessionActive && _isPlaying && !_player.playing) {
       _player.play();
    }
  }
  
  void dispose() {
    _keepAliveTimer?.cancel();
    _player.dispose();
  }
}

enum FocusSoundType {
  none,
  rain,
  fire,
  forest,
  stream;

  String get assetPath {
    switch (this) {
      case FocusSoundType.rain: return 'assets/sound/rain.mp3';
      case FocusSoundType.fire: return 'assets/sound/fire.mp3';
      case FocusSoundType.forest: return 'assets/sound/forest.mp3';
      case FocusSoundType.stream: return 'assets/sound/stream.mp3';
      case FocusSoundType.none: return '';
    }
  }
  
  String get labelKey {
    switch (this) {
      case FocusSoundType.rain: return 'sound_rain';
      case FocusSoundType.fire: return 'sound_fire';
      case FocusSoundType.forest: return 'sound_forest';
      case FocusSoundType.stream: return 'sound_stream';
      case FocusSoundType.none: return 'sound_none';
    }
  }
}

final focusAudioServiceProvider = Provider<FocusAudioService>((ref) => FocusAudioService());
