import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/audio_util.dart';
import 'xiaozhi_websocket_manager.dart';
import 'xiaozhi_ota_service.dart';
import 'xiaozhi_device_info.dart';

/// 小智服务事件类型
enum XiaozhiServiceEventType {
  connected,
  disconnected,
  textMessage,
  audioData,
  error,
  voiceCallStart,
  voiceCallEnd,
  userMessage,
  sttResult,
  ttsStart,
  ttsStop,
  needActivation,
}

/// 小智服务事件
class XiaozhiServiceEvent {
  final XiaozhiServiceEventType type;
  final dynamic data;

  XiaozhiServiceEvent(this.type, this.data);
}

/// 小智服务监听器
typedef XiaozhiServiceListener = void Function(XiaozhiServiceEvent event);

/// 消息监听器
typedef MessageListener = void Function(dynamic message);

/// 小智语音AI服务
/// 基于 xiaozhi-client-flutter 参考项目重构
class XiaozhiService {
  static const String TAG = "XiaozhiService";

  // 单例
  static XiaozhiService? _instance;

  // 配置
  final String otaUrl;
  final String wsUrl;

  // 组件
  XiaozhiOtaService? _otaService;
  XiaozhiWebSocketManager? _wsManager;

  // 状态
  String? _sessionId;
  String? _wsToken;
  bool _isConnected = false;
  bool _isVoiceCallActive = false;
  bool _hasStartedCall = false;
  bool _sttOnlyMode = false;  // STT only mode - 不播放音频，收到STT后自动abort

  // 监听器
  final List<XiaozhiServiceListener> _listeners = [];
  StreamSubscription? _audioStreamSubscription;
  MessageListener? _messageListener;

  /// 工厂构造函数
  factory XiaozhiService({
    required String otaUrl,
    required String wsUrl,
  }) {
    _instance ??= XiaozhiService._internal(otaUrl: otaUrl, wsUrl: wsUrl);
    return _instance!;
  }

  XiaozhiService._internal({required this.otaUrl, required this.wsUrl}) {
    _init();
  }

  /// 获取实例
  static XiaozhiService? get instance => _instance;

  /// 重置实例（用于测试或重新初始化）
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// 初始化
  Future<void> _init() async {
    print('$TAG: 初始化服务');
    
    _otaService = XiaozhiOtaService(otaUrl: otaUrl);
    await AudioUtil.initRecorder();
    await AudioUtil.initPlayer();
  }

  /// 设置消息监听器
  void setMessageListener(MessageListener listener) {
    _messageListener = listener;
  }

  /// 设置 STT Only 模式（只使用语音转文字，不播放 AI 语音）
  void setSttOnlyMode(bool enabled) {
    _sttOnlyMode = enabled;
    print('$TAG: STT Only 模式: ${enabled ? "开启" : "关闭"}');
  }

  /// 添加事件监听器
  void addListener(XiaozhiServiceListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// 移除事件监听器
  void removeListener(XiaozhiServiceListener listener) {
    _listeners.remove(listener);
  }

  /// 分发事件
  void _dispatchEvent(XiaozhiServiceEvent event) {
    for (var listener in _listeners) {
      listener(event);
    }
  }

  /// 连接服务（包含OTA认证）
  Future<bool> connect() async {
    try {
      print('$TAG: 开始连接服务');

      // 第一步: OTA认证
      if (_otaService == null) {
        print('$TAG: OTA服务未初始化');
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.error, 'OTA服务未初始化'));
        return false;
      }

      // 调用 OTA API 获取 WebSocket 信息
      final otaResponse = await _otaService!.checkFlutterAppUpdates(
        appName: 'ajb_agent_flutter',
        appVersion: '1.0.0',
        acceptLanguage: 'zh-CN',
      );

      print('$TAG: OTA 响应成功');

      // 检查是否需要激活
      if (otaResponse.activation != null) {
        final code = otaResponse.activation!.code;
        final message = otaResponse.activation!.message;
        print('$TAG: 设备需要激活，激活码: $code');
        _dispatchEvent(XiaozhiServiceEvent(
          XiaozhiServiceEventType.needActivation,
          {
            'code': code,
            'message': message.isNotEmpty
                ? message
                : '设备需要在平台端注册，注册码:[$code]，注册成功后需重新进入对话'
          },
        ));
        return false;
      }

      if (otaResponse.websocket != null) {
        final websocketInfo = otaResponse.websocket!;
        _wsToken = websocketInfo.token;

        // 第二步: 创建WebSocket连接
        final deviceInfo = XiaozhiDeviceInfo.instance;
        final macAddress = await deviceInfo.getDeviceMacAddress();

        // 如果正在重连中，不要重新创建管理器
        // 创建或重用WebSocket管理器
        if (_wsManager == null) {
          _wsManager = XiaozhiWebSocketManager(
            deviceId: macAddress,
            enableToken: true,
          );
          _wsManager!.addListener(_onWebSocketEvent);
        } else {
          // 强制重置状态，允许手动触发的新连接
          _wsManager!.cancelReconnect();
        }

        // 提取 OTA 返回的建议 ClientId
        final clientIdFromOta = otaResponse.mqtt?.clientId;
        final connectUrl = websocketInfo.url.isNotEmpty ? websocketInfo.url : wsUrl;
        
        print('$TAG: 准备连接 WebSocket. URL: $connectUrl, ClientId: $clientIdFromOta');

        // 执行连接
        await _wsManager!.connect(connectUrl, _wsToken ?? '', clientId: clientIdFromOta);

        print('$TAG: OTA 认证流程完成');
        return true;
      } else {
        print('$TAG: OTA响应中没有WebSocket信息');
        _dispatchEvent(XiaozhiServiceEvent(
          XiaozhiServiceEventType.error,
          '认证失败: 服务器未返回连接信息',
        ));
        return false;
      }
    } on OtaException catch (e) {
      print('$TAG: OTA 认证失败: ${e.message}');
      _dispatchEvent(XiaozhiServiceEvent(
        XiaozhiServiceEventType.error,
        '认证失败: ${e.message}',
      ));
      return false;
    } catch (e) {
      print('$TAG: 连接失败: $e');
      _dispatchEvent(XiaozhiServiceEvent(
        XiaozhiServiceEventType.error,
        '连接失败: $e',
      ));
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      print('$TAG: 开始断开连接');
      
      // 1. 停止语音通话
      if (_isVoiceCallActive) {
        await stopListening();
        _isVoiceCallActive = false;
      }
      
      // 2. 取消音频流订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 3. 停止音频录制
      if (AudioUtil.isRecording) {
        await AudioUtil.stopRecording();
      }

      // 4. 取消重连定时器并断开WebSocket连接
      if (_wsManager != null) {
        _wsManager!.cancelReconnect();
        await _wsManager!.disconnect();
        // 不要立即设置为 null，让重连机制处理
      }
      
      // 5. 更新状态
      _isConnected = false;
      _sessionId = null;
      _hasStartedCall = false;
      
      print('$TAG: 断开连接完成');
    } catch (e) {
      print('$TAG: 断开连接失败: $e');
    }
  }

  /// 处理WebSocket事件
  void _onWebSocketEvent(XiaozhiEvent event) {
    switch (event.type) {
      case XiaozhiEventType.connected:
        print('$TAG: WebSocket 管理器报告已连接');
        _isConnected = true;
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.connected, null));
        break;

      case XiaozhiEventType.disconnected:
        print('$TAG: WebSocket 管理器报告已断开');
        _isConnected = false;
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.disconnected, null));
        break;

      case XiaozhiEventType.message:
        _handleTextMessage(event.data as String);
        break;

      case XiaozhiEventType.binaryMessage:
        // 在 STT Only 模式下忽略音频数据（只需要语音转文字）
        if (_sttOnlyMode) {
          // 忽略音频，不播放
          break;
        }
        // 播放音频数据
        final audioData = event.data as List<int>;
        AudioUtil.playOpusData(Uint8List.fromList(audioData));
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.audioData, audioData));
        break;

      case XiaozhiEventType.error:
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.error, event.data));
        break;
    }
  }

  /// 处理文本消息
  void _handleTextMessage(String message) {
    print('$TAG: 收到文本消息: $message');
    
    try {
      final jsonData = jsonDecode(message) as Map<String, dynamic>;
      final type = jsonData['type']?.toString() ?? '';

      // 调用消息监听器
      if (_messageListener != null) {
        _messageListener!(jsonData);
      }

      // 更新session_id
      if (jsonData['session_id'] != null) {
        _sessionId = jsonData['session_id'];
        print('$TAG: 更新会话ID: $_sessionId');
      }

      switch (type) {
        case 'hello':
          print('$TAG: 收到服务器 hello 响应: ${jsonData['session_id']}');
          // 处理服务器的hello响应
          if (_isVoiceCallActive && !_hasStartedCall) {
            _hasStartedCall = true;
            _startSpeaking();
          }
          break;

        case 'start':
          print('$TAG: 收到服务器 start 指令');
          // 收到start响应后，如果是语音通话模式，开始录音
          if (_isVoiceCallActive) {
            _sendListenMessage();
          }
          break;

        case 'tts':
          final state = jsonData['state']?.toString() ?? '';
          final text = jsonData['text']?.toString() ?? '';
          print('$TAG: 收到 TTS 消息: state=$state, text=$text');

          if (state == 'start') {
            _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.ttsStart, null));
          }
          if (state == 'sentence_start' && text.isNotEmpty) {
            print('$TAG: 收到TTS句子: $text');
            _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.textMessage, text));
          }
          if (state == 'stop') {
            _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.ttsStop, null));
          }
          break;

        case 'stt':
          final text = jsonData['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            print('$TAG: 收到语音识别结果: $text');
            _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.sttResult, text));
            _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.userMessage, text));
            
            // 在 STT Only 模式下，收到识别结果后立即发送 abort，阻止 AI 语音回复
            if (_sttOnlyMode) {
              final abortMsg = {'session_id': _sessionId, 'type': 'abort'};
              _wsManager?.sendMessage(jsonEncode(abortMsg));
              print('$TAG: STT Only 模式 - 已自动发送 abort');
            }
          }
          break;

        case 'emotion':
          final emotion = jsonData['emotion']?.toString() ?? '';
          if (emotion.isNotEmpty) {
            print('$TAG: 收到表情消息: $emotion');
          }
          break;

        default:
          print('$TAG: 收到未知消息类型: $type');
      }
    } catch (e) {
      print('$TAG: 解析消息失败: $e');
    }
  }

  /// 切换到语音通话模式
  Future<void> switchToVoiceCallMode() async {
    if (_isVoiceCallActive) return;

    try {
      print('$TAG: 切换到语音通话模式');
      await AudioUtil.stopPlaying();
      await AudioUtil.initRecorder();
      await AudioUtil.initPlayer();
      _isVoiceCallActive = true;
      _hasStartedCall = false;
      _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.voiceCallStart, null));
    } catch (e) {
      print('$TAG: 切换到语音通话模式失败: $e');
      rethrow;
    }
  }

  /// 切换到普通聊天模式
  Future<void> switchToChatMode() async {
    if (!_isVoiceCallActive) return;

    try {
      print('$TAG: 切换到普通聊天模式');
      await stopListeningCall();
      await AudioUtil.stopPlaying();
      _isVoiceCallActive = false;
      _hasStartedCall = false;
      _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.voiceCallEnd, null));
    } catch (e) {
      print('$TAG: 切换到普通聊天模式失败: $e');
      _isVoiceCallActive = false;
    }
  }

  /// 发送开始说话消息
  void _startSpeaking() {
    final message = {'type': 'speak', 'state': 'start', 'mode': 'auto'};
    _wsManager?.sendMessage(jsonEncode(message));
    print('$TAG: 已发送开始说话消息');
  }

  /// 发送listen消息
  Future<void> _sendListenMessage() async {
    try {
      final listenMessage = {
        'type': 'listen',
        'session_id': _sessionId ?? '',
        'state': 'start',
        'mode': 'auto',
      };
      _wsManager?.sendMessage(jsonEncode(listenMessage));
      print('$TAG: 已发送listen消息');

      // 开始录音 - 使用 AEC
      await AudioUtil.startRecording(enableAEC: true);

      // 订阅音频流
      _audioStreamSubscription = AudioUtil.audioStream.listen(
        (opusData) {
          if (_wsManager != null && _wsManager!.isConnected) {
            _wsManager!.sendBinaryMessage(opusData);
          } else {
            print('$TAG: WebSocket 未连接，音频数据丢失');
          }
        },
        onError: (error) {
          print('$TAG: 音频流错误: $error');
          _dispatchEvent(XiaozhiServiceEvent(
            XiaozhiServiceEventType.error,
            '音频流错误: $error',
          ));
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('$TAG: 发送listen消息失败: $e');
    }
  }

  /// 开始监听（语音通话模式）
  Future<void> startListeningCall() async {
    if (_sessionId == null) {
      print('$TAG: 没有会话ID，等待...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_sessionId == null) {
        throw Exception('会话ID为空，无法开始录音');
      }
    }

    // 请求麦克风权限
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('$TAG: 麦克风权限被拒绝');
        _dispatchEvent(XiaozhiServiceEvent(XiaozhiServiceEventType.error, '麦克风权限被拒绝'));
        return;
      }
    }

    // 开始录音 - 使用 AEC
    await AudioUtil.startRecording(enableAEC: true);

    // 设置音频流订阅
    _audioStreamSubscription = AudioUtil.audioStream.listen(
      (opusData) {
        if (_wsManager != null && _wsManager!.isConnected) {
          _wsManager!.sendBinaryMessage(opusData);
        } else {
          print('$TAG: WebSocket 未连接，音频数据丢失');
        }
      },
      onError: (error) {
        print('$TAG: 音频流错误: $error');
        _dispatchEvent(XiaozhiServiceEvent(
          XiaozhiServiceEventType.error,
          '音频流错误: $error',
        ));
      },
      cancelOnError: false,
    );

    // 发送开始监听命令
    final message = {
      'session_id': _sessionId,
      'type': 'listen',
      'state': 'start',
      'mode': 'auto',
    };
    _wsManager?.sendMessage(jsonEncode(message));
    print('$TAG: 已发送开始监听消息 (语音通话模式)');
  }

  /// 停止监听（语音通话模式）
  Future<void> stopListeningCall() async {
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await AudioUtil.stopRecording();

      if (_sessionId != null && _wsManager != null) {
        final message = {
          'session_id': _sessionId,
          'type': 'listen',
          'state': 'stop',
          'mode': 'auto',
        };
        _wsManager?.sendMessage(jsonEncode(message));
        print('$TAG: 已发送停止监听消息');
      }
    } catch (e) {
      print('$TAG: 停止监听失败: $e');
    }
  }

  /// 开始监听（按住说话模式）
  /// [skipRecording] - 如果为 true，跳过启动录音（适用于已经有缓冲音频的情况）
  Future<void> startListening({String mode = 'manual', bool skipRecording = false}) async {
    if (!_isConnected) {
      await connect();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isConnected) return;
    }

    // 只有在需要时才启动录音（避免与外部录音冲突）
    if (!skipRecording) {
      // 先取消之前的音频流订阅（如果存在）
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      await AudioUtil.startRecording(enableAEC: _isVoiceCallActive);
      
      _audioStreamSubscription = AudioUtil.audioStream.listen(
        (opusData) {
          if (_wsManager != null && _wsManager!.isConnected) {
            _wsManager!.sendBinaryMessage(opusData);
          } else {
            print('$TAG: WebSocket 未连接，音频数据丢失');
          }
        },
        onError: (error) {
          print('$TAG: 音频流错误: $error');
          _dispatchEvent(XiaozhiServiceEvent(
            XiaozhiServiceEventType.error,
            '音频流错误: $error',
          ));
        },
        cancelOnError: false,
      );
    }

    // 发送 listen 开始消息（无论是否跳过录音）
    final message = {
      'session_id': _sessionId ?? '',
      'type': 'listen',
      'state': 'start',
      'mode': mode,
    };
    _wsManager?.sendMessage(jsonEncode(message));
    
    print('$TAG: 开始监听，模式: $mode');
  }

  /// 停止监听
  Future<void> stopListening() async {
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await AudioUtil.stopRecording();

    final stopMsg = {
      'session_id': _sessionId ?? '',
      'type': 'listen',
      'state': 'stop',
    };
    _wsManager?.sendMessage(jsonEncode(stopMsg));
    print('$TAG: 停止监听');
  }

  /// 发送二进制音频数据
  void sendBinaryMessage(List<int> data) {
    if (_wsManager != null && _wsManager!.isConnected) {
      _wsManager!.sendBinaryMessage(data);
    }
  }

  /// 中断（打断服务器的 TTS 响应，但保持连接）
  Future<void> abort() async {
    try {
      // 取消音频流订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 停止录音（如果正在录）
      if (AudioUtil.isRecording) {
        await AudioUtil.stopRecording();
      }

      // 停止播放
      await AudioUtil.stopPlaying();

      // 发送中止命令
      if (_sessionId != null && _wsManager != null) {
        final message = {'session_id': _sessionId, 'type': 'abort'};
        _wsManager!.sendMessage(jsonEncode(message));
        print('$TAG: 已发送中止消息, isConnected: $_isConnected');
      }
    } catch (e) {
      print('$TAG: 中止失败: $e');
    }
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String text) async {
    if (!_isConnected) {
      await connect();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isConnected) return;
    }

    final textMsg = {
      'type': 'listen',
      'state': 'detect',
      'text': text,
      'source': 'text',
    };
    _wsManager?.sendMessage(jsonEncode(textMsg));
    print('$TAG: 发送文本请求: $text');
  }

  /// 停止播放
  Future<void> stopPlayback() async {
    await AudioUtil.stopPlaying();
  }

  /// 释放资源
  Future<void> dispose() async {
    await disconnect();
    await AudioUtil.dispose();
    _otaService?.dispose();
    _listeners.clear();
    print('$TAG: 资源已释放');
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isVoiceCallActive => _isVoiceCallActive;
  String? get sessionId => _sessionId;
}
