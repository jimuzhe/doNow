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

  Future<void> startFocusSound() async {
    if (kIsWeb) return;
    if (_isPlaying || _silentFile == null) return;
    
    try {
      await _player.setFilePath(_silentFile!.path);
      await _player.setLoopMode(LoopMode.one); // Infinite loop
      
      // Set volume to absolute zero - the audio session is what keeps the app alive,
      // not the actual sound output
      await _player.setVolume(0.0);
      await _player.play();
      _isPlaying = true;
      
      // Start a keep-alive timer that periodically ensures audio is still playing
      _keepAliveTimer?.cancel();
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _ensureAudioPlaying();
      });
      
      debugPrint('🔇 Silent background audio started');
    } catch (e) {
      debugPrint('❌ Error starting focus sound: $e');
    }
  }

  /// Periodically called to ensure audio session stays active
  void _ensureAudioPlaying() {
    if (!_isPlaying) return;
    
    if (!_player.playing) {
      debugPrint('🔄 Restarting silent audio (was stopped)');
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
      
      debugPrint('🔇 Silent background audio stopped');
    } catch (e) {
      debugPrint('❌ Error stopping focus sound: $e');
    }
  }
  
  void dispose() {
    _keepAliveTimer?.cancel();
    _player.dispose();
  }
}

final focusAudioServiceProvider = Provider<FocusAudioService>((ref) => FocusAudioService());
