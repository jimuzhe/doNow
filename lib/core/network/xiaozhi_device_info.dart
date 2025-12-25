import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// 设备信息工具类
/// 基于 xiaozhi-client-flutter 参考项目重构
class XiaozhiDeviceInfo {
  static const String TAG = "XiaozhiDeviceInfo";

  // 单例模式
  XiaozhiDeviceInfo._();
  static final XiaozhiDeviceInfo _instance = XiaozhiDeviceInfo._();
  static XiaozhiDeviceInfo get instance => _instance;

  static const String _keyDeviceId = 'xiaozhi_device_id_v4';
  static const String _keyMacAddress = 'xiaozhi_mac_address_v4';
  static const String _keyClientId = 'xiaozhi_client_id_v4';

  String? _cachedMacAddress;
  String? _cachedClientId;

  /// 获取设备唯一标识（基于设备信息生成稳定的MD5哈希）
  Future<String> getDeviceUniqueId() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedId = prefs.getString(_keyDeviceId);
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    String deviceId = await _generateDeviceId();
    await prefs.setString(_keyDeviceId, deviceId);
    return deviceId;
  }

  /// 生成设备ID（基于设备硬件信息生成MD5哈希）
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String identifier = '';

    try {
      if (kIsWeb) {
        // Web 平台使用浏览器相关信息或直接生成 UUID
        final webInfo = await deviceInfo.webBrowserInfo;
        identifier =
            '${webInfo.vendor}-${webInfo.userAgent}-${webInfo.hardwareConcurrency}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        identifier = androidInfo.id;
        if (identifier.isEmpty) {
          identifier =
              '${androidInfo.board}-${androidInfo.brand}-${androidInfo.device}-${androidInfo.hardware}';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        identifier = iosInfo.identifierForVendor ?? '';
        if (identifier.isEmpty) {
          identifier =
              '${iosInfo.name}-${iosInfo.systemVersion}-${iosInfo.model}';
        }
      } else {
        // 其他平台：生成随机UUID
        identifier = _generateUUID();
      }

      if (identifier.isEmpty) {
        identifier = _generateUUID();
      }

      // 计算MD5哈希
      final bytes = utf8.encode(identifier);
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('$TAG: 生成设备ID失败: $e');
      return _generateUUID();
    }
  }

  /// 获取设备MAC地址（模拟）
  Future<String> getDeviceMacAddress() async {
    if (_cachedMacAddress != null) {
      return _cachedMacAddress!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? savedMac = prefs.getString(_keyMacAddress);

    if (savedMac != null && savedMac.isNotEmpty) {
      _cachedMacAddress = savedMac;
      print('$TAG: Using existing MAC: $savedMac');
      return savedMac;
    }

    // 使用随机 UUID 生成完全随机的 MAC 地址（不再基于设备 ID）
    final randomUuid = _generateUUID();
    final hash = md5.convert(utf8.encode(randomUuid)).bytes;
    final macAddress = '${hash[0].toRadixString(16).padLeft(2, '0')}:'
        '${hash[1].toRadixString(16).padLeft(2, '0')}:'
        '${hash[2].toRadixString(16).padLeft(2, '0')}:'
        '${hash[3].toRadixString(16).padLeft(2, '0')}:'
        '${hash[4].toRadixString(16).padLeft(2, '0')}:'
        '${hash[5].toRadixString(16).padLeft(2, '0')}';

    // 使用小写，与参考项目保持一致（服务器对大小写敏感）
    await prefs.setString(_keyMacAddress, macAddress);
    _cachedMacAddress = macAddress;
    print('$TAG: Generated new MAC: $macAddress');
    return macAddress;
  }

  /// 获取设备客户端ID（UUID格式）
  Future<String> getDeviceClientId() async {
    if (_cachedClientId != null) {
      return _cachedClientId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString(_keyClientId);

    if (savedId != null && savedId.isNotEmpty) {
      _cachedClientId = savedId;
      print('$TAG: Using existing Client ID: $savedId');
      return savedId;
    }

    final uuid = _generateUUID();
    await prefs.setString(_keyClientId, uuid);
    _cachedClientId = uuid;
    print('$TAG: Generated new Client ID: $uuid');
    return uuid;
  }

  /// 生成UUID
  String _generateUUID() {
    return const Uuid().v4();
  }

  /// 获取设备型号
  Future<String> getDeviceModel() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.browserName.name;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.model;
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// 获取操作系统版本
  Future<String> getOSVersion() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return 'Web ${webInfo.appVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      }
      return Platform.operatingSystem;
    } catch (e) {
      return kIsWeb ? 'Web' : Platform.operatingSystem;
    }
  }

  /// 重置所有设备信息
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyMacAddress);
    await prefs.remove(_keyClientId);
    _cachedMacAddress = null;
    _cachedClientId = null;
    print('$TAG: Device info reset');
  }
}
