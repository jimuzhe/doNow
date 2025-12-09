import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for playing UI sound effects
class SoundEffectService {
  AudioPlayer? _successPlayer;
  File? _successSoundFile;
  bool _isInitialized = false;

  /// Generate a pleasant success chime sound programmatically
  /// Creates a two-tone ascending "ding-ding" sound
  Uint8List _generateSuccessSound() {
    const int sampleRate = 44100;
    const int bitsPerSample = 16;
    const int numChannels = 1;
    const double duration = 0.6; // 600ms total
    final int numSamples = (sampleRate * duration).toInt();
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

    // fmt subchunk
    byteData.setUint8(offset++, 0x66); // f
    byteData.setUint8(offset++, 0x6D); // m
    byteData.setUint8(offset++, 0x74); // t
    byteData.setUint8(offset++, 0x20); // space
    byteData.setUint32(offset, 16, Endian.little); offset += 4;
    byteData.setUint16(offset, 1, Endian.little); offset += 2; // PCM
    byteData.setUint16(offset, numChannels, Endian.little); offset += 2;
    byteData.setUint32(offset, sampleRate, Endian.little); offset += 4;
    byteData.setUint32(offset, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 4;
    byteData.setUint16(offset, numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 2;
    byteData.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

    // data subchunk
    byteData.setUint8(offset++, 0x64); // d
    byteData.setUint8(offset++, 0x61); // a
    byteData.setUint8(offset++, 0x74); // t
    byteData.setUint8(offset++, 0x61); // a
    byteData.setUint32(offset, dataSize, Endian.little); offset += 4;

    // Generate audio samples - two-tone success chime
    // First tone: C5 (523 Hz) for 0.25s
    // Second tone: E5 (659 Hz) for 0.35s
    const double freq1 = 523.0; // C5
    const double freq2 = 659.0; // E5
    const double switchTime = 0.25;
    
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double sample;
      
      if (t < switchTime) {
        // First note with attack and slight decay
        double envelope = (t < 0.02) ? (t / 0.02) : (1.0 - (t / switchTime) * 0.3);
        sample = envelope * 0.5 * 
            (0.7 * _sin(2 * 3.14159 * freq1 * t) + 
             0.3 * _sin(2 * 3.14159 * freq1 * 2 * t)); // Add harmonic
      } else {
        // Second note with attack and decay
        double t2 = t - switchTime;
        double remainingDuration = duration - switchTime;
        double envelope = (t2 < 0.02) ? (t2 / 0.02) : (1.0 - (t2 / remainingDuration) * 0.8);
        sample = envelope * 0.5 * 
            (0.7 * _sin(2 * 3.14159 * freq2 * t2) + 
             0.3 * _sin(2 * 3.14159 * freq2 * 2 * t2)); // Add harmonic
      }
      
      // Convert to 16-bit signed integer
      int sampleInt = (sample * 32767).clamp(-32768, 32767).toInt();
      byteData.setInt16(offset, sampleInt, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
  
  double _sin(double x) {
    // Simple sine approximation
    x = x % (2 * 3.14159);
    if (x > 3.14159) x -= 2 * 3.14159;
    double x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  Future<void> init() async {
    if (kIsWeb || _isInitialized) return;
    
    try {
      _successPlayer = AudioPlayer();
      
      // Generate success sound file
      final dir = await getApplicationDocumentsDirectory();
      _successSoundFile = File('${dir.path}/success_chime.wav');
      
      final soundData = _generateSuccessSound();
      await _successSoundFile!.writeAsBytes(soundData);
      
      // Pre-load the sound
      await _successPlayer!.setFilePath(_successSoundFile!.path);
      await _successPlayer!.setVolume(0.7);
      
      _isInitialized = true;
      debugPrint('🔔 SoundEffectService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing SoundEffectService: $e');
    }
  }

  /// Play the success/completion sound
  Future<void> playSuccess() async {
    if (kIsWeb || !_isInitialized || _successPlayer == null) return;
    
    try {
      // Reset to beginning and play
      await _successPlayer!.seek(Duration.zero);
      await _successPlayer!.play();
      debugPrint('🔔 Playing success sound');
    } catch (e) {
      debugPrint('❌ Error playing success sound: $e');
    }
  }

  void dispose() {
    _successPlayer?.dispose();
  }
}

final soundEffectServiceProvider = Provider<SoundEffectService>((ref) => SoundEffectService());
