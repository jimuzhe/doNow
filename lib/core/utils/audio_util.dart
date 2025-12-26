import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// 音频配置常量
class AudioConfig {
  AudioConfig._();
  
  static const int sampleRate = 24000;
  static const int channels = 1;
  static const int frameDuration = 60; // milliseconds
}

/// 音频工具类，用于处理Opus音频编解码和录制播放
/// 基于 xiaozhi-client-flutter 参考项目重构
class AudioUtil {
  static const String TAG = "AudioUtil";

  // 使用可空 recorder，每次录音创建新实例以避免流订阅冲突
  static AudioRecorder? _audioRecorder;
  static bool _isRecorderInitialized = false;
  static bool _isPlayerInitialized = false;
  static bool _isRecording = false;
  static bool _isPlaying = false;

  static final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  // 振幅相关 - 使用持久的广播流控制器
  static final StreamController<double> _amplitudeStreamController =
      StreamController<double>.broadcast();
  static StreamSubscription<Amplitude>? _amplitudeSubscription;
  static StreamSubscription? _audioRecordStreamSubscription; // 录音流订阅

  // Opus编解码器
  static SimpleOpusEncoder? _encoder;
  static SimpleOpusDecoder? _decoder;
  static bool _opusInitialized = false;
  static Completer<void>? _opusInitCompleter; // 防止并发初始化
  static Completer<void>? _recorderInitCompleter; // 防止并发初始化

  /// 获取音频流 (Opus encoded)
  static Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// 获取归一化振幅流 (0.0 ~ 1.0)
  static Stream<double> get amplitudeStream => _amplitudeStreamController.stream;

  /// 初始化Opus编解码器
  static Future<void> _initOpusCodec() async {
    // 如果已经初始化，直接返回
    if (_opusInitialized) return;
    
    // 如果正在初始化，等待完成
    if (_opusInitCompleter != null) {
      await _opusInitCompleter!.future;
      return;
    }
    
    _opusInitCompleter = Completer<void>();

    try {
      print('$TAG: 初始化 Opus 编解码器...');
      
      // 加载 opus 本地库 - 使用 try-catch 处理已初始化的情况
      try {
        initOpus(await opus_flutter.load());
      } catch (e) {
        // 如果 opus 已经初始化，忽略错误
        if (e.toString().contains('already been initialized')) {
          print('$TAG: Opus 库已初始化，跳过');
        } else {
          rethrow;
        }
      }

      _encoder = SimpleOpusEncoder(
        sampleRate: AudioConfig.sampleRate,
        channels: AudioConfig.channels,
        application: Application.voip,
      );

      _decoder = SimpleOpusDecoder(
        sampleRate: AudioConfig.sampleRate,
        channels: AudioConfig.channels,
      );

      _opusInitialized = true;
      _opusInitCompleter!.complete();
      print('$TAG: Opus 编解码器初始化成功 - ${AudioConfig.sampleRate} Hz');
    } catch (e) {
      print('$TAG: Opus 初始化失败: $e');
      _opusInitCompleter!.completeError(e);
      _opusInitCompleter = null;
      rethrow;
    }
  }

  /// 初始化音频录制器
  static Future<void> initRecorder() async {
    // 如果已经初始化，直接返回
    if (_isRecorderInitialized) return;
    
    // 如果正在初始化，等待完成
    if (_recorderInitCompleter != null) {
      await _recorderInitCompleter!.future;
      return;
    }
    
    _recorderInitCompleter = Completer<void>();

    try {
      print('$TAG: 开始初始化录音器');

      // 请求权限
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          print('$TAG: 请求Android所需的所有权限');
          Map<Permission, PermissionStatus> statuses = await [
            Permission.microphone,
            Permission.storage,
          ].request();

          if (statuses[Permission.microphone] != PermissionStatus.granted) {
            print('$TAG: 麦克风权限被拒绝');
            throw Exception('需要麦克风权限');
          }
        } else if (Platform.isIOS) {
          final status = await Permission.microphone.request();
          if (status != PermissionStatus.granted) {
            print('$TAG: 麦克风权限被拒绝');
            throw Exception('需要麦克风权限');
          }
        }
      }

    // 检查PCM16编码支持
    print('$TAG: 检查PCM16编码是否支持');
    _audioRecorder ??= AudioRecorder();
    final isAvailable = await _audioRecorder!.isEncoderSupported(
      AudioEncoder.pcm16bits,
    );
    print('$TAG: PCM16编码支持状态: $isAvailable');

    // 配置音频会话 (仅移动端)
    if (!kIsWeb) {
      print('$TAG: 配置音频会话');
      final session = await AudioSession.instance;

      if (Platform.isAndroid) {
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.allowBluetooth,
            avAudioSessionMode: AVAudioSessionMode.voiceChat,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.speech,
              usage: AndroidAudioUsage.voiceCommunication,
              flags: AndroidAudioFlags.audibilityEnforced,
            ),
            androidAudioFocusGainType:
                AndroidAudioFocusGainType.gainTransientExclusive,
            androidWillPauseWhenDucked: false,
          ),
        );
      } else {
        // iOS 配置
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.defaultToSpeaker,
            avAudioSessionMode: AVAudioSessionMode.voiceChat,
          ),
        );
        await session.setActive(true);
      }
    }

    // 初始化 Opus 编解码器
    await _initOpusCodec();

    _isRecorderInitialized = true;
    _recorderInitCompleter!.complete();
    print('$TAG: 录音器初始化成功');
    } catch (e) {
      print('$TAG: 录音器初始化失败: $e');
      _recorderInitCompleter!.completeError(e);
      _recorderInitCompleter = null;
      rethrow;
    }
  }

  /// 初始化音频播放器
  static Future<void> initPlayer() async {
    // 确保任何旧播放器被释放
    await stopPlaying();

    try {
      print('$TAG: 初始化音频播放器 - 单声道 ${AudioConfig.sampleRate}Hz');

      // 确保 Opus 解码器已初始化
      if (!_opusInitialized) {
        await _initOpusCodec();
      }

      // 设置 flutter_pcm_sound
      await FlutterPcmSound.setup(
        sampleRate: AudioConfig.sampleRate,
        channelCount: AudioConfig.channels,
      );

      // 设置低缓冲阈值以实现实时播放 (100ms)
      await FlutterPcmSound.setFeedThreshold(AudioConfig.sampleRate ~/ 10);

      _isPlayerInitialized = true;
      print('$TAG: 音频播放器初始化成功');
    } catch (e) {
      print('$TAG: 音频播放器初始化失败: $e');
      _isPlayerInitialized = false;
    }
  }

  /// 播放Opus音频数据
  static Future<void> playOpusData(Uint8List opusData) async {
    try {
      // 如果播放器未初始化，先初始化
      if (!_isPlayerInitialized) {
        await initPlayer();
      }

      if (!_opusInitialized || _decoder == null) {
        print('$TAG: Decoder not initialized!');
        return;
      }

      // 标记正在播放
      _isPlaying = true;

      // 解码 Opus 数据为 PCM Int16
      final Int16List pcmData = _decoder!.decode(input: opusData);

      // flutter_pcm_sound 直接接受 Int16 数据
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(pcmData.toList()));
      
      // Start playback if not already
      FlutterPcmSound.start();
    } catch (e, stackTrace) {
      print('$TAG: 播放失败: $e');
      print('$TAG: 堆栈: $stackTrace');

      // 简单重置并重新初始化
      await stopPlaying();
      await initPlayer();
    }
  }

  /// 停止播放
  static Future<void> stopPlaying() async {
    if (_isPlayerInitialized) {
      try {
        await FlutterPcmSound.release();
        print('$TAG: 播放器已停止');
      } catch (e) {
        print('$TAG: 停止播放失败: $e');
      }
      _isPlayerInitialized = false;
    }
    _isPlaying = false;
  }

  /// 释放资源
  static Future<void> dispose() async {
    await stopPlaying();
    await stopRecording();
    _encoder?.destroy();
    _decoder?.destroy();
    _encoder = null;
    _decoder = null;
    _opusInitialized = false;
    print('$TAG: 资源已释放');
  }

  /// 开始录音
  /// [enableAEC] - 是否启用回声消除（AEC）和降噪，持续监听模式建议开启
  static Future<void> startRecording({bool enableAEC = false}) async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }

    // 注意：移除了 _isRecording 检查，因为现在我们会在开始前强制停止

    try {
      print('$TAG: 尝试启动录音 (AEC: $enableAEC)');

      // 确保麦克风权限已获取
      if (!kIsWeb) {
        final status = await Permission.microphone.status;
        print('$TAG: 麦克风权限状态: $status');

        if (status != PermissionStatus.granted) {
          final result = await Permission.microphone.request();
          print('$TAG: 请求麦克风权限结果: $result');
          if (result != PermissionStatus.granted) {
            print('$TAG: 麦克风权限被拒绝');
            return;
          }
        }
      }

      // 启动流式录音
      try {
        // 强制停止之前的录音（如果有），避免流状态冲突
        await _audioRecordStreamSubscription?.cancel();
        _audioRecordStreamSubscription = null;
        await _amplitudeSubscription?.cancel();
        _amplitudeSubscription = null;
        
        // 停止并销毁旧的 recorder，创建新实例以避免流订阅冲突
        if (_audioRecorder != null) {
          try {
            await _audioRecorder!.stop();
          } catch (_) {}
          try {
            await _audioRecorder!.dispose();
          } catch (_) {}
        }
        _audioRecorder = AudioRecorder();
        
        print('$TAG: 启动流式录音 (AEC: $enableAEC, 降噪: $enableAEC, AGC: $enableAEC)');
        final stream = await _audioRecorder!.startStream(
          RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: AudioConfig.sampleRate,
            numChannels: AudioConfig.channels,
            // AEC 回声消除 - 持续监听模式下需要消除扬声器播放的回声
            echoCancel: enableAEC,
            // 降噪 - 减少背景噪音
            noiseSuppress: enableAEC,
            // 自动增益控制 - 自动调整麦克风音量
            autoGain: enableAEC,
          ),
        );

        _isRecording = true;
        print('$TAG: 流式录音启动成功');

        // 启动振幅监听（可选功能，失败不影响录音）
        try {
          if (_amplitudeSubscription != null) {
            await _amplitudeSubscription!.cancel();
            _amplitudeSubscription = null;
          }
          _amplitudeSubscription = _audioRecorder!
              .onAmplitudeChanged(const Duration(milliseconds: 100))
              .listen((amp) {
            final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
            _amplitudeStreamController.add(normalized);
          });
        } catch (ampError) {
          print('$TAG: 振幅监听启动失败（不影响录音）: $ampError');
          // 振幅监听是可选的，失败不影响主要录音功能
        }

        // 直接从流中处理数据 - 保存订阅以便稍后取消
        // 确保先完全取消旧订阅
        if (_audioRecordStreamSubscription != null) {
          await _audioRecordStreamSubscription!.cancel();
          _audioRecordStreamSubscription = null;
        }
        _audioRecordStreamSubscription = stream.listen(
          (data) async {
            if (data.isNotEmpty && data.length % 2 == 0) {
              final opusData = await encodeToOpus(Uint8List.fromList(data));
              if (opusData != null) {
                _audioStreamController.add(opusData);
              }
            }
          },
          onError: (error) {
            print('$TAG: 音频流错误: $error');
            _isRecording = false;
          },
          onDone: () {
            print('$TAG: 音频流结束');
            _isRecording = false;
          },
        );
      } catch (e) {
        print('$TAG: 流式录音失败: $e');
        _isRecording = false;
        rethrow;
      }
    } catch (e, stackTrace) {
      print('$TAG: 启动录音失败: $e');
      print(stackTrace);
      _isRecording = false;
    }
  }

  /// 停止录音
  static Future<String?> stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return null;

    // 取消振幅订阅（不关闭 controller，保持持久流）
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    
    // 取消录音流订阅
    await _audioRecordStreamSubscription?.cancel();
    _audioRecordStreamSubscription = null;

    // 停止录音
    try {
      final path = await _audioRecorder?.stop();
      _isRecording = false;
      print('$TAG: 停止录音: $path');
      return path;
    } catch (e) {
      print('$TAG: 停止录音失败: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 将PCM数据编码为Opus格式
  static Future<Uint8List?> encodeToOpus(Uint8List pcmData) async {
    if (!_opusInitialized || _encoder == null) {
      await _initOpusCodec();
      if (_encoder == null) return null;
    }

    try {
      // 转换PCM数据为Int16List (小端字节序)
      final Int16List pcmInt16 = Int16List.fromList(
        List.generate(
          pcmData.length ~/ 2,
          (i) => (pcmData[i * 2]) | (pcmData[i * 2 + 1] << 8),
        ),
      );

      // 确保数据长度符合Opus要求
      final int samplesPerFrame = (AudioConfig.sampleRate * AudioConfig.frameDuration) ~/ 1000;

      Uint8List encoded;

      // 处理过短的数据
      if (pcmInt16.length < samplesPerFrame) {
        // 对于过短的数据，填充静音
        final Int16List paddedData = Int16List(samplesPerFrame);
        for (int i = 0; i < pcmInt16.length; i++) {
          paddedData[i] = pcmInt16[i];
        }
        encoded = Uint8List.fromList(_encoder!.encode(input: paddedData));
      } else {
        // 裁剪到精确的帧长度
        encoded = Uint8List.fromList(
          _encoder!.encode(input: pcmInt16.sublist(0, samplesPerFrame)),
        );
      }

      return encoded;
    } catch (e, stackTrace) {
      print('$TAG: Opus编码失败: $e');
      print(stackTrace);
      return null;
    }
  }

  /// 解码Opus为PCM
  static Int16List? decodeOpus(Uint8List opusData) {
    if (!_opusInitialized || _decoder == null) {
      print('$TAG: Decoder not initialized');
      return null;
    }

    try {
      return _decoder!.decode(input: opusData);
    } catch (e) {
      print('$TAG: Opus decode error: $e');
      return null;
    }
  }

  /// 检查是否正在录音
  static bool get isRecording => _isRecording;

  /// 检查是否正在播放
  static bool get isPlaying => _isPlaying;

  /// 检测设备音频处理能力
  static Future<Map<String, bool>> checkAudioCapabilities() async {
    final result = <String, bool>{};

    try {
      _audioRecorder ??= AudioRecorder();
      final hasPermission = await _audioRecorder!.hasPermission();
      result['hasPermission'] = hasPermission;

      final pcm16Supported = await _audioRecorder!.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );
      result['pcm16Supported'] = pcm16Supported;

      // Android 和 iOS 对 AEC 的支持情况
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        result['aecSupported'] = true;
        result['noiseSuppressSupported'] = true;
        result['autoGainSupported'] = true;
      } else {
        result['aecSupported'] = kIsWeb;
        result['noiseSuppressSupported'] = kIsWeb;
        result['autoGainSupported'] = kIsWeb;
      }

      print('$TAG: 音频能力检测结果: $result');
    } catch (e) {
      print('$TAG: 音频能力检测失败: $e');
      result['error'] = true;
    }

    return result;
  }

  /// Build a WAV header for PCM data
  static Uint8List buildWavHeader(int dataLength, {int wavSampleRate = AudioConfig.sampleRate, int wavChannels = AudioConfig.channels}) {
    final byteRate = wavSampleRate * wavChannels * 2;
    final totalDataLen = dataLength + 36;

    final header = Uint8List(44);
    final view = ByteData.view(header.buffer);

    // RIFF chunk
    view.setUint8(0, 0x52); // R
    view.setUint8(1, 0x49); // I
    view.setUint8(2, 0x46); // F
    view.setUint8(3, 0x46); // F
    view.setUint32(4, totalDataLen, Endian.little);
    view.setUint8(8, 0x57); // W
    view.setUint8(9, 0x41); // A
    view.setUint8(10, 0x56); // V
    view.setUint8(11, 0x45); // E

    // fmt chunk
    view.setUint8(12, 0x66); // f
    view.setUint8(13, 0x6d); // m
    view.setUint8(14, 0x74); // t
    view.setUint8(15, 0x20); // space
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, wavChannels, Endian.little);
    view.setUint32(24, wavSampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, wavChannels * 2, Endian.little);
    view.setUint16(34, 16, Endian.little); // 16-bit

    // data chunk
    view.setUint8(36, 0x64); // d
    view.setUint8(37, 0x61); // a
    view.setUint8(38, 0x74); // t
    view.setUint8(39, 0x61); // a
    view.setUint32(40, dataLength, Endian.little);

    return header;
  }
}
