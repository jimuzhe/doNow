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
  bool _isPlaying = false;
  File? _silentFile;
  Timer? _keepAliveTimer;
  
  FocusSoundType _currentType = FocusSoundType.none;
  double _volume = 0.5; // Default volume for white noise

  /// Generate a proper silent WAV file programmatically
  /// This creates a longer duration silent file (10 seconds) for better reliability
  Uint8List _generateSilentWav({int durationSeconds = 10}) {
    const int sampleRate = 44100;
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int numSamples = sampleRate * durationSeconds;
    final int dataSize = numSamples * (bitsPerSample ~/ 8) * numChannels;
    final int fileSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    byteData.setUint8(offset++, 0x52); // R
    byteData.setUint8(offset++, 0x49); // I
    byteData.setUint8(offset++, 0x46); // F
    byteData.setUint8(offset++, 0x46); // F
    byteData.setUint32(offset, fileSize, Endian.little); offset += 4;
    byteData.setUint8(offset++, 0x57); // W
    byteData.setUint8(offset++, 0x41); // A
    byteData.setUint8(offset++, 0x56); // V
    byteData.setUint8(offset++, 0x45); // E

    // fmt  subchunk
    byteData.setUint8(offset++, 0x66); // f
    byteData.setUint8(offset++, 0x6D); // m
    byteData.setUint8(offset++, 0x74); // t
    byteData.setUint8(offset++, 0x20); // space
    byteData.setUint32(offset, 16, Endian.little); offset += 4; // subchunk size
    byteData.setUint16(offset, 1, Endian.little); offset += 2; // audio format (PCM)
    byteData.setUint16(offset, numChannels, Endian.little); offset += 2;
    byteData.setUint32(offset, sampleRate, Endian.little); offset += 4;
    byteData.setUint32(offset, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 4; // byte rate
    byteData.setUint16(offset, numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 2; // block align
    byteData.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

    // data subchunk
    byteData.setUint8(offset++, 0x64); // d
    byteData.setUint8(offset++, 0x61); // a
    byteData.setUint8(offset++, 0x74); // t
    byteData.setUint8(offset++, 0x61); // a
    byteData.setUint32(offset, dataSize, Endian.little); offset += 4;

    // All remaining bytes are 0 (silence) - ByteData is initialized to 0
    
    return byteData.buffer.asUint8List();
  }

  Future<void> init() async {
    // Skip on web/unsupported platforms
    if (kIsWeb) return;
    
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      // Prepare the silent file
      await _prepareSilentFile();
      
      debugPrint('🔇 FocusAudioService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FocusAudioService: $e');
    }
  }

  Future<void> _prepareSilentFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _silentFile = File('${dir.path}/silent_focus_10s.wav');
      
      // Generate and write a proper 10-second silent WAV file
      final silentData = _generateSilentWav(durationSeconds: 10);
      await _silentFile!.writeAsBytes(silentData);
      
      debugPrint('🔇 Created silent WAV file: ${_silentFile!.path} (${silentData.length} bytes)');
    } catch (e) {
      debugPrint('❌ Error creating silent file: $e');
    }
  }

  /// Start playing the focus sound (or silent keep-alive)
  Future<void> startFocusSound() async {
    // kIsWeb is now ALLOWED for playing sounds, but we need to handle "silent" keep-alive differently
    // Do not check _isPlaying here, allow restarting/changing track
    
    try {
      if (_currentType == FocusSoundType.none) {
        if (kIsWeb) {
            // Web doesn't need "silent keepalive" file, just stop playing
            await _player.stop();
            _isPlaying = false;
            return;
        }

        // Native: Play silent file for background keep-alive
        if (_silentFile == null) await _prepareSilentFile();
        if (_silentFile != null) {
            await _player.setFilePath(_silentFile!.path);
            await _player.setVolume(0.0); // Silence
        }
      } else {
        // Play white noise asset
        try {
          // setAsset works on both Web and Native
          await _player.setAsset(_currentType.assetPath);
          await _player.setVolume(_volume);
        } catch (assetError) {
          debugPrint('⚠️ Asset not found for ${_currentType.name}, falling back to silence: $assetError');
          
          if (kIsWeb) {
             await _player.stop();
             _isPlaying = false;
             return;
          }
          
          // Fallback to silence if asset missing on native
          if (_silentFile == null) await _prepareSilentFile();
          if (_silentFile != null) {
              await _player.setFilePath(_silentFile!.path);
              await _player.setVolume(0.0);
          }
        }
      }

      await _player.setLoopMode(LoopMode.one); // Infinite loop
      await _player.play();
      _isPlaying = true;
      
      // Start a keep-alive timer that periodically ensures audio is still playing
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _ensureAudioPlaying();
      });
      
      debugPrint('🎵 Background audio started: ${_currentType.name}');
    } catch (e) {
      debugPrint('❌ Error starting focus sound: $e');
    }
  }

  /// Switch the sound type while playing
  Future<void> setSoundType(FocusSoundType type) async {
    if (_currentType == type) return;
    _currentType = type;
    
    if (_isPlaying) {
      // Restart with new source
      await startFocusSound();
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

  /// Periodically called to ensure audio session stays active
  void _ensureAudioPlaying() {
    if (!_isPlaying) return;
    
    if (!_player.playing) {
      debugPrint('🔄 Restarting audio (was stopped)');
      _player.play();
    }
  }

  Future<void> stopFocusSound() async {
    if (!_isPlaying) return;
    
    try {
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      
      await _player.stop();
      _isPlaying = false;
      
      debugPrint('🔇 Focus audio stopped');
    } catch (e) {
      debugPrint('❌ Error stopping focus sound: $e');
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
