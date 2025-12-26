import 'dart:async';
import 'dart:typed_data';
import '../../core/network/xiaozhi.dart';
import '../api_config.dart';
import '../../core/utils/audio_util.dart';

// 重新导出类型以保持兼容性
export '../../core/network/xiaozhi_websocket_manager.dart' show XiaozhiEventType, XiaozhiEvent;

enum VoiceState { idle, connecting, ready, listening, processing, speaking, error, needActivation }

/// Activation result from OTA server
class XiaozhiActivationResult {
  final bool isActivated;
  final String? activationCode;
  final String? message;
  final String? deviceMac;

  XiaozhiActivationResult({
    required this.isActivated,
    this.activationCode,
    this.message,
    this.deviceMac,
  });

  factory XiaozhiActivationResult.activated() => XiaozhiActivationResult(isActivated: true);
  
  factory XiaozhiActivationResult.notActivated({
    required String code,
    String? message,
    String? deviceMac,
  }) => XiaozhiActivationResult(
        isActivated: false,
        activationCode: code,
        message: message,
        deviceMac: deviceMac,
      );
}

/// 小智语音AI服务（兼容层）
/// 使用新的xiaozhi模块架构
class VoiceAIService {
  static const String TAG = "VoiceAIService";
  
  // 单例实例
  static VoiceAIService? _instance;
  
  // 新架构服务
  XiaozhiService? _xiaozhiService;
  
  // Stream controllers
  final _stateController = StreamController<VoiceState>.broadcast();
  final _textController = StreamController<String>.broadcast();
  final _sttController = StreamController<String>.broadcast();
  final _emotionController = StreamController<String>.broadcast();
  final _activationController = StreamController<XiaozhiActivationResult>.broadcast();
  final _ttsStateController = StreamController<String>.broadcast();
  final _eventController = StreamController<XiaozhiEvent>.broadcast();

  Stream<VoiceState> get stateStream => _stateController.stream;
  Stream<String> get textStream => _textController.stream;
  Stream<String> get sttStream => _sttController.stream;
  Stream<String> get emotionStream => _emotionController.stream;
  Stream<XiaozhiActivationResult> get activationStream => _activationController.stream;
  Stream<String> get ttsStateStream => _ttsStateController.stream;
  Stream<XiaozhiEvent> get eventStream => _eventController.stream;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  String? _activationCode;
  String? _activationMessage;
  
  bool get isConnected => _xiaozhiService?.isConnected ?? false;
  bool get isVoiceCallActive => _xiaozhiService?.isVoiceCallActive ?? false;
  String? get deviceMac => null; // 使用新架构，从XiaozhiDeviceInfo获取
  bool get isActivated => _state != VoiceState.needActivation;
  String? get activationCode => _activationCode;

  /// 工厂构造函数
  factory VoiceAIService() {
    _instance ??= VoiceAIService._internal();
    return _instance!;
  }

  VoiceAIService._internal() {
    _init();
  }

  /// 初始化
  Future<void> _init() async {
    print('$TAG: 初始化服务（新架构）');
    
    // 创建新架构服务 - XiaozhiService 内部会初始化 AudioUtil
    _xiaozhiService = XiaozhiService(
      otaUrl: ApiConfig.xiaozhiOtaUrl,
      wsUrl: ApiConfig.xiaozhiWebsocketUrl,
    );
    
    // 添加事件监听
    _xiaozhiService!.addListener(_onServiceEvent);
    
    // 注意：不再在这里调用 AudioUtil 初始化，因为 XiaozhiService 内部已经调用了
  }

  /// 处理服务事件
  void _onServiceEvent(XiaozhiServiceEvent event) {
    switch (event.type) {
      case XiaozhiServiceEventType.connected:
        _updateState(VoiceState.ready);
        _eventController.add(XiaozhiEvent(type: XiaozhiEventType.connected));
        break;
        
      case XiaozhiServiceEventType.disconnected:
        _updateState(VoiceState.idle);
        _eventController.add(XiaozhiEvent(type: XiaozhiEventType.disconnected));
        break;
        
      case XiaozhiServiceEventType.textMessage:
        final text = event.data?.toString() ?? '';
        if (text.isNotEmpty) {
          _textController.add(text);
          _eventController.add(XiaozhiEvent(type: XiaozhiEventType.message, data: text));
        }
        break;
        
      case XiaozhiServiceEventType.sttResult:
        final text = event.data?.toString() ?? '';
        if (text.isNotEmpty) {
          _sttController.add(text);
        }
        break;
        
      case XiaozhiServiceEventType.userMessage:
        // 用户消息（STT结果）
        break;
        
      case XiaozhiServiceEventType.ttsStart:
        _updateState(VoiceState.speaking);
        _ttsStateController.add('start');
        break;
        
      case XiaozhiServiceEventType.ttsStop:
        _updateState(VoiceState.ready);
        _ttsStateController.add('stop');
        break;
        
      case XiaozhiServiceEventType.error:
        _updateState(VoiceState.error);
        _eventController.add(XiaozhiEvent(type: XiaozhiEventType.error, data: event.data));
        break;
        
      case XiaozhiServiceEventType.needActivation:
        _updateState(VoiceState.needActivation);
        final data = event.data as Map<String, dynamic>?;
        if (data != null) {
          _activationCode = data['code']?.toString();
          _activationMessage = data['message']?.toString();
          _activationController.add(XiaozhiActivationResult.notActivated(
            code: _activationCode ?? '',
            message: _activationMessage,
          ));
        }
        break;
        
      case XiaozhiServiceEventType.voiceCallStart:
      case XiaozhiServiceEventType.voiceCallEnd:
      case XiaozhiServiceEventType.audioData:
        // 内部处理
        break;
    }
  }

  void _updateState(VoiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 连接服务
  Future<void> connect() async {
    // Check actual connection status, not just state
    final actuallyConnected = _xiaozhiService?.isConnected ?? false;
    
    if (actuallyConnected && (_state == VoiceState.ready || _state == VoiceState.listening || _state == VoiceState.speaking)) {
      print('$TAG: Already connected, state: $_state');
      return;
    }
    
    if (_state == VoiceState.connecting) {
      print('$TAG: Already connecting');
      return;
    }
    
    _updateState(VoiceState.connecting);
    
    final success = await _xiaozhiService?.connect() ?? false;
    
    if (!success && _state != VoiceState.needActivation) {
      _updateState(VoiceState.error);
    }
  }

  /// 断开连接
  void disconnect() {
    _xiaozhiService?.disconnect();
    _updateState(VoiceState.idle);
  }

  /// 设置 STT Only 模式（只使用语音转文字，不播放 AI 语音）
  void setSttOnlyMode(bool enabled) {
    _xiaozhiService?.setSttOnlyMode(enabled);
  }

  /// 检查OTA激活
  Future<XiaozhiActivationResult> checkOtaActivation() async {
    final success = await _xiaozhiService?.connect() ?? false;
    
    if (success) {
      return XiaozhiActivationResult.activated();
    } else if (_state == VoiceState.needActivation) {
      return XiaozhiActivationResult.notActivated(
        code: _activationCode ?? '',
        message: _activationMessage ?? '请访问 ${ApiConfig.xiaozhiAdminUrl} 使用激活码注册设备',
      );
    } else {
      return XiaozhiActivationResult.notActivated(
        code: '',
        message: '连接失败',
      );
    }
  }

  /// 切换到语音通话模式
  Future<void> switchToVoiceCallMode() async {
    await _xiaozhiService?.switchToVoiceCallMode();
  }

  /// 切换到普通聊天模式
  Future<void> switchToChatMode() async {
    await _xiaozhiService?.switchToChatMode();
  }

  /// 开始监听（语音通话模式）
  Future<void> startListeningCall() async {
    _updateState(VoiceState.listening);
    await _xiaozhiService?.startListeningCall();
  }

  /// 停止监听（语音通话模式）
  Future<void> stopListeningCall() async {
    await _xiaozhiService?.stopListeningCall();
    _updateState(VoiceState.processing);
  }

  /// 开始监听（按住说话模式）
  /// [skipRecording] - 如果为 true，跳过启动录音（适用于已经有缓冲音频的情况）
  Future<void> startListening({String mode = 'auto', bool skipRecording = false}) async {
    if (_state != VoiceState.ready) {
      await connect();
      await Future.delayed(const Duration(milliseconds: 300));
      if (_state != VoiceState.ready) return;
    }
    
    _updateState(VoiceState.listening);
    await _xiaozhiService?.startListening(mode: mode, skipRecording: skipRecording);
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (_state != VoiceState.listening) return;
    
    await _xiaozhiService?.stopListening();
    _updateState(VoiceState.processing);
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String text) async {
    await _xiaozhiService?.sendTextMessage(text);
  }

  /// 中断（打断AI语音）
  Future<void> abort({String? reason}) async {
    await _xiaozhiService?.abort(reason: reason);
    _updateState(VoiceState.ready);
  }

  /// 停止播放
  Future<void> stopPlayback() async {
    await AudioUtil.stopPlaying();
  }

  /// 发送二进制音频消息
  void sendBinaryMessage(List<int> data) {
    _xiaozhiService?.sendBinaryMessage(data);
  }

  /// 清除音频缓冲
  void clearAudioBuffer() {
    // 新架构不需要
  }

  /// 重置设备
  Future<void> resetDevice() async {
    await XiaozhiDeviceInfo.instance.reset();
    print('$TAG: Device reset');
  }

  /// 启用自动重连
  void enableAutoReconnect() {
    // 新架构内置自动重连
  }

  /// 禁用自动重连
  void disableAutoReconnect() {
    // 新架构内置自动重连
  }

  /// 释放资源
  Future<void> dispose() async {
    await _xiaozhiService?.dispose();
    _stateController.close();
    _textController.close();
    _sttController.close();
    _emotionController.close();
    _activationController.close();
    _ttsStateController.close();
    _eventController.close();
  }
}
