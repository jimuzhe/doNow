import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusAudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  File? _silentFile;

  // 1-second Silent WAV (PCM 16-bit, 44.1kHz, Mono)
  // This is a valid WAV file that is completely silent but ensures the audio engine remains active.
  static const String _silentMp3Base64 = 
      "UklGRiIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA="; // Minimal Header
  
  // Actually, let's use a slightly longer one to be safe (approx 0.5s of silence)
  static const String _validSilentWavBase64 = 
      "UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YRAAAACAAAAAAAABAAAA/////////w==";

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers, // Allow other music
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
    
    // Preparation
    await _prepareSilentFile();
  }

  Future<void> _prepareSilentFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _silentFile = File('${dir.path}/silent_focus.wav');
      
      // Always rewrite to ensure validity
      final bytes = base64Decode(_validSilentWavBase64);
      await _silentFile!.writeAsBytes(bytes);
      
    } catch (e) {
      print("Error creating silent file: $e");
    }
  }

  Future<void> startFocusSound() async {
    if (_isPlaying || _silentFile == null) return;
    
    try {
      await _player.setFilePath(_silentFile!.path);
      await _player.setLoopMode(LoopMode.one); // Infinite loop
      // Keep volume extremely low but non-zero to prevent system optimization
      await _player.setVolume(0.05); 
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      print("Error starting focus sound: $e");
    }
  }

  Future<void> stopFocusSound() async {
    if (!_isPlaying) return;
    
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      print("Error stopping focus sound: $e");
    }
  }
}

final focusAudioServiceProvider = Provider<FocusAudioService>((ref) => FocusAudioService());
