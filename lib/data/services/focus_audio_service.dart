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

  // 1-second silent MP3 (minimal frame)
  // This is a minimal valid MP3 frame for silence to keep the audio engine engaged.
  static const String _silentMp3Base64 = 
      "//NExAAAAANIAAAAAExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//NExAAAAANIAAAAAExBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq";

  Future<void> init() async {
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

    // Prepare silent file
    await _prepareSilentFile();
  }

  Future<void> _prepareSilentFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _silentFile = File('${dir.path}/silence.mp3');
      
      if (!await _silentFile!.exists()) {
        final bytes = base64Decode(_silentMp3Base64);
        await _silentFile!.writeAsBytes(bytes);
      }
    } catch (e) {
      print("Error creating silent file: $e");
    }
  }

  Future<void> startFocusSound() async {
    if (_isPlaying || _silentFile == null) return;
    
    try {
      await _player.setFilePath(_silentFile!.path);
      await _player.setLoopMode(LoopMode.one); // Infinite loop
      await _player.setVolume(0.01); // Basically silent, but 'playing'
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
