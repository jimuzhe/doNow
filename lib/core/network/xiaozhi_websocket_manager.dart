import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/io.dart'
    if (dart.library.html) 'package:web_socket_channel/html.dart';

enum XiaozhiEventType { connected, disconnected, message, error, binaryMessage }

class XiaozhiEvent {
  final XiaozhiEventType type;
  final dynamic data;
  XiaozhiEvent({required this.type, this.data});
}

typedef XiaozhiWebSocketListener = void Function(XiaozhiEvent event);

class XiaozhiWebSocketManager {
  static const String TAG = "XiaozhiWebSocketManager";
  
  WebSocketChannel? _channel;
  String? _serverUrl;
  String? _deviceId;
  String? _clientId; // 保存用于重连
  String? _token;

  final List<XiaozhiWebSocketListener> _listeners = [];
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  StreamSubscription? _streamSubscription;

  XiaozhiWebSocketManager({
    required String deviceId,
    bool enableToken = true, // 默认开启
  }) : _deviceId = deviceId;

  bool get isConnected => _channel != null;
  bool _isDisconnected = true;

  void addListener(XiaozhiWebSocketListener listener) => _listeners.add(listener);

  void _dispatchEvent(XiaozhiEvent event) {
    for (var listener in _listeners) {
      listener(event);
    }
  }

  // 第 8 步核心：connect 必须支持外部传入 clientId
  Future<void> connect(String url, String token, {String? clientId}) async {
    _serverUrl = url;
    _token = token;
    _clientId = clientId; // 保存来自 OTA 的 GID_test...

    if (_channel != null) await disconnect();

    try {
      final uri = Uri.parse(url);
      print('$TAG: 正在建立连接: $url');
      
      // 第 9 步核心：全小写 Headers
      final headers = {
        'device-id': _deviceId ?? '',
        'client-id': _deviceId ?? '', // 使用 MAC 地址，避免使用 MQTT 的长 GID 导致连接断开
        'protocol-version': '1',
        'Authorization': 'Bearer ${token.isNotEmpty ? token : "test-token"}',
      };

      print('$TAG: [${DateTime.now()}] 准备连接，Headers: $headers');
      _channel = IOWebSocketChannel.connect(uri, headers: headers);

      print('$TAG: 使用headers方式连接WebSocket成功');

      // 参考项目逻辑：立即设置监听，不等待 ready
      _streamSubscription = _channel!.stream.listen(
        _onMessage,
        onDone: () {
          _onDisconnected(closeCode: _channel?.closeCode, reason: _channel?.closeReason);
          _cleanup();
        },
        onError: (e) {
          _onError(e);
          _cleanup();
        },
        cancelOnError: false,
      );

      _isDisconnected = false;

      // 派发连接成功事件
      _dispatchEvent(XiaozhiEvent(type: XiaozhiEventType.connected));

      // 参考项目使用 200ms 延迟发送 hello
      Timer(const Duration(milliseconds: 200), () {
        _sendHelloMessage();
      });

    } catch (e) {
      print('$TAG: 连接创建失败: $e');
      _dispatchEvent(XiaozhiEvent(type: XiaozhiEventType.error, data: e.toString()));
    }
  }

  void _sendHelloMessage() {
    // 第 10 步核心：{'type':'hello','version':1,'features':{'mcp':true},...}
    final hello = {
      'type': 'hello',
      'version': 1,
      'features': {'mcp': true},
      'transport': 'websocket',
      'audio_params': {
        'format': 'opus',
        'sample_rate': 16000,
        'channels': 1,
        'frame_duration': 60,
      },
    };
    print('$TAG: 发送标准握手包: ${jsonEncode(hello)}');
    sendMessage(jsonEncode(hello));
  }

  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
  }

  void sendBinaryMessage(List<int> data) {
    if (isConnected) _channel!.sink.add(data);
  }

  void _cleanup() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isDisconnected = true;
    _channel = null;
  }

  Future<void> disconnect() async {
    cancelReconnect();
    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
    }
    _cleanup();
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      print('$TAG: [${DateTime.now()}] 收到文本消息: $message');
      _dispatchEvent(XiaozhiEvent(type: XiaozhiEventType.message, data: message));
    } else if (message is List<int>) {
      // 降低音频数据日志频率
      // print('$TAG: 收到二进制音频: ${message.length} bytes');
      _dispatchEvent(XiaozhiEvent(type: XiaozhiEventType.binaryMessage, data: message));
    }
  }

  void _onDisconnected({int? closeCode, String? reason}) {
    print('$TAG: [${DateTime.now()}] WebSocket 断开 - Code: $closeCode, Reason: $reason');
    _dispatchEvent(XiaozhiEvent(type: XiaozhiEventType.disconnected));
    // 不再自动重连，让上层（VentingScreen）控制重连逻辑
    // 避免与 UI 层的重连逻辑冲突
  }

  void _onError(error) {
    print('$TAG: 链路错误: $error');
  }

  void cancelReconnect() {
    _reconnectTimer?.cancel();
    _isReconnecting = false;
  }
}
