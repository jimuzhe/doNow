import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'xiaozhi_device_info.dart';

// =========== OTA 请求数据模型 ===========

class OtaRequest {
  final ApplicationInfo application;
  final String? macAddress;
  final String? uuid;
  final String? chipModelName;
  final int? flashSize;
  final int? psramSize;
  final List<PartitionInfo>? partitionTable;
  final BoardInfo board;
  final int? version;
  final String? language;
  final int? minimumFreeHeapSize;
  final OtaInfo? ota;

  const OtaRequest({
    required this.application,
    this.macAddress,
    this.uuid,
    this.chipModelName,
    this.flashSize,
    this.psramSize,
    this.partitionTable,
    required this.board,
    this.version,
    this.language,
    this.minimumFreeHeapSize,
    this.ota,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'application': application.toJson(),
      'board': board.toJson(),
    };

    if (macAddress != null) data['mac_address'] = macAddress;
    if (uuid != null) data['uuid'] = uuid;
    if (chipModelName != null) data['chip_model_name'] = chipModelName;
    if (flashSize != null) data['flash_size'] = flashSize;
    if (psramSize != null) data['psram_size'] = psramSize;
    if (partitionTable != null) {
      data['partition_table'] = partitionTable!.map((p) => p.toJson()).toList();
    }
    if (version != null) data['version'] = version;
    if (language != null) data['language'] = language;
    if (minimumFreeHeapSize != null) {
      data['minimum_free_heap_size'] = minimumFreeHeapSize;
    }
    if (ota != null) data['ota'] = ota!.toJson();

    return data;
  }
}

class ApplicationInfo {
  final String version;
  final String elfSha256;
  final String? name;
  final String? compileTime;
  final String? idfVersion;

  const ApplicationInfo({
    required this.version,
    required this.elfSha256,
    this.name,
    this.compileTime,
    this.idfVersion,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'version': version,
      'elf_sha256': elfSha256,
    };

    if (name != null) data['name'] = name;
    if (compileTime != null) data['compile_time'] = compileTime;
    if (idfVersion != null) data['idf_version'] = idfVersion;

    return data;
  }
}

class BoardInfo {
  final String type;
  final String name;
  final String? ssid;
  final int? rssi;
  final int? channel;
  final String? ip;
  final String? mac;
  final String? revision;
  final String? carrier;
  final String? csq;
  final String? imei;
  final String? iccid;

  const BoardInfo({
    required this.type,
    required this.name,
    this.ssid,
    this.rssi,
    this.channel,
    this.ip,
    this.mac,
    this.revision,
    this.carrier,
    this.csq,
    this.imei,
    this.iccid,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'type': type, 'name': name};

    if (ssid != null) data['ssid'] = ssid;
    if (rssi != null) data['rssi'] = rssi;
    if (channel != null) data['channel'] = channel;
    if (ip != null) data['ip'] = ip;
    if (mac != null) data['mac'] = mac;
    if (revision != null) data['revision'] = revision;
    if (carrier != null) data['carrier'] = carrier;
    if (csq != null) data['csq'] = csq;
    if (imei != null) data['imei'] = imei;
    if (iccid != null) data['iccid'] = iccid;

    return data;
  }
}

class PartitionInfo {
  final String label;
  final int type;
  final int subtype;
  final int address;
  final int size;

  const PartitionInfo({
    required this.label,
    required this.type,
    required this.subtype,
    required this.address,
    required this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'type': type,
      'subtype': subtype,
      'address': address,
      'size': size,
    };
  }
}

class OtaInfo {
  final String label;

  const OtaInfo({required this.label});

  Map<String, dynamic> toJson() {
    return {'label': label};
  }
}

// =========== OTA 响应数据模型 ===========

class OtaResponse {
  final ActivationInfo? activation;
  final MqttInfo? mqtt;
  final WebsocketInfo? websocket;
  final ServerTimeInfo? serverTime;
  final FirmwareInfo? firmware;

  const OtaResponse({
    this.activation,
    this.mqtt,
    this.websocket,
    this.serverTime,
    this.firmware,
  });

  factory OtaResponse.fromJson(Map<String, dynamic> json) {
    return OtaResponse(
      activation: json['activation'] != null
          ? ActivationInfo.fromJson(json['activation'])
          : null,
      mqtt: json['mqtt'] != null ? MqttInfo.fromJson(json['mqtt']) : null,
      websocket: json['websocket'] != null
          ? WebsocketInfo.fromJson(json['websocket'])
          : null,
      serverTime: json['server_time'] != null
          ? ServerTimeInfo.fromJson(json['server_time'])
          : null,
      firmware: json['firmware'] != null
          ? FirmwareInfo.fromJson(json['firmware'])
          : null,
    );
  }

  bool get needsActivation => activation != null;
  bool get hasWebsocket => websocket != null;
}

class ActivationInfo {
  final String code;
  final String message;

  const ActivationInfo({required this.code, required this.message});

  factory ActivationInfo.fromJson(Map<String, dynamic> json) {
    return ActivationInfo(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class MqttInfo {
  final String endpoint;
  final String clientId;
  final String username;
  final String password;
  final String publishTopic;

  const MqttInfo({
    required this.endpoint,
    required this.clientId,
    required this.username,
    required this.password,
    required this.publishTopic,
  });

  factory MqttInfo.fromJson(Map<String, dynamic> json) {
    return MqttInfo(
      endpoint: json['endpoint'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      publishTopic: json['publish_topic'] as String? ?? '',
    );
  }
}

class WebsocketInfo {
  final String url;
  final String token;

  const WebsocketInfo({required this.url, required this.token});

  factory WebsocketInfo.fromJson(Map<String, dynamic> json) {
    return WebsocketInfo(
      url: json['url'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }
}

class ServerTimeInfo {
  final int timestamp;
  final String timezone;
  final int timezoneOffset;

  const ServerTimeInfo({
    required this.timestamp,
    required this.timezone,
    required this.timezoneOffset,
  });

  factory ServerTimeInfo.fromJson(Map<String, dynamic> json) {
    return ServerTimeInfo(
      timestamp: json['timestamp'] as int? ?? 0,
      timezone: json['timezone'] as String? ?? 'UTC',
      timezoneOffset: json['timezone_offset'] as int? ?? 0,
    );
  }
}

class FirmwareInfo {
  final String version;
  final String? url;

  const FirmwareInfo({required this.version, this.url});

  factory FirmwareInfo.fromJson(Map<String, dynamic> json) {
    return FirmwareInfo(
      version: json['version'] as String? ?? '0.0.0',
      url: json['url'] as String?,
    );
  }
}

class OtaException implements Exception {
  final String message;
  final int? statusCode;

  const OtaException(this.message, [this.statusCode]);

  @override
  String toString() => 'OtaException: $message';
}

// =========== OTA 服务 ===========

/// OTA认证服务
/// 基于 xiaozhi-client-flutter 参考项目重构
class XiaozhiOtaService {
  static const String TAG = "XiaozhiOtaService";

  final String otaUrl;
  final http.Client _httpClient;

  XiaozhiOtaService({
    required this.otaUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// 执行OTA检查请求
  Future<OtaResponse> checkForUpdates({
    required String userAgent,
    required OtaRequest request,
    String? acceptLanguage,
  }) async {
    try {
      // 使用 DeviceUtil 获取设备ID和客户端ID
      final deviceId = await XiaozhiDeviceInfo.instance.getDeviceMacAddress();
      final clientId = await XiaozhiDeviceInfo.instance.getDeviceClientId();
      final url = Uri.parse(otaUrl);

      print('$TAG: Sending OTA request to: $otaUrl');
      print('$TAG: Device ID: $deviceId');
      print('$TAG: Client ID: $clientId');

      // 构建请求头
      final headers = {
        'Content-Type': 'application/json',
        'Device-Id': deviceId,
        'Client-Id': clientId,
        'User-Agent': userAgent,
      };

      if (acceptLanguage != null) {
        headers['Accept-Language'] = acceptLanguage;
      }

      print('$TAG: Request body: ${jsonEncode(request.toJson())}');

      // 发送POST请求
      final response = await _httpClient
          .post(
            url,
            headers: headers,
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('$TAG: OTA Response: ${response.statusCode}');

      // 处理响应
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        print('$TAG: OTA Response Body: ${response.body}');
        return OtaResponse.fromJson(jsonData);
      } else {
        // 处理错误响应
        String errorMessage = 'Unknown error';
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          print('$TAG: OTA Error Response: $errorJson');
          errorMessage = errorJson['error'] as String? ??
              errorJson['message'] as String? ??
              'Unknown error';
        } catch (e) {
          errorMessage =
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown"}';
        }

        throw OtaException(errorMessage, response.statusCode);
      }
    } on SocketException {
      throw const OtaException('网络连接失败，请检查网络设置');
    } on HttpException {
      throw const OtaException('HTTP请求失败');
    } on FormatException {
      throw const OtaException('响应数据格式错误');
    } catch (e) {
      if (e is OtaException) rethrow;
      throw OtaException('未知错误: $e');
    }
  }

  /// 获取设备信息并创建设备相关的OTA请求数据
  Future<OtaRequest> createDeviceBasedOtaRequest({
    required String appVersion,
    required String elfSha256,
    required String boardType,
    required String boardName,
  }) async {
    final deviceId = await XiaozhiDeviceInfo.instance.getDeviceMacAddress();
    final clientId = await XiaozhiDeviceInfo.instance.getDeviceClientId();

    return OtaRequest(
      application: ApplicationInfo(version: appVersion, elfSha256: elfSha256),
      macAddress: deviceId,
      uuid: clientId,
      board: BoardInfo(type: boardType, name: boardName, mac: deviceId),
    );
  }

  /// 便捷方法：执行Flutter应用的OTA检查
  Future<OtaResponse> checkFlutterAppUpdates({
    required String appName,
    required String appVersion,
    String? acceptLanguage,
  }) async {
    // 生成用于校验的SHA256
    final elfSha256 =
        'flutter_app_${appVersion}_${DateTime.now().millisecondsSinceEpoch}';

    // 获取设备型号作为board信息
    final deviceModel = await XiaozhiDeviceInfo.instance.getDeviceModel();
    final osVersion = await XiaozhiDeviceInfo.instance.getOSVersion();

    // 创建User-Agent
    final userAgent = '$appName/$appVersion';

    // 创建OTA请求
    final request = await createDeviceBasedOtaRequest(
      appVersion: appVersion,
      elfSha256: elfSha256,
      boardType: deviceModel.toLowerCase().replaceAll(' ', '-'),
      boardName: '$deviceModel ($osVersion)',
    );

    // 执行OTA检查
    return checkForUpdates(
      userAgent: userAgent,
      request: request,
      acceptLanguage: acceptLanguage ?? 'zh-CN',
    );
  }

  /// 释放资源
  void dispose() {
    _httpClient.close();
  }
}
