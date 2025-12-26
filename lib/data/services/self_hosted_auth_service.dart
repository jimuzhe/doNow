import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:mime/mime.dart';

/// 自托管认证服务客户端
/// 替代 Firebase Auth，连接您自己的 Python 后端
class SelfHostedAuthService {
  // ⚠️ 修改为您的服务器地址
  // 默认地址，可由 --dart-define=AUTH_API_URL=... 覆盖
  static const String baseUrl = String.fromEnvironment(
    'AUTH_API_URL', 
    defaultValue: 'https://auth.name666.top/api/auth'
  );
  
  String? _accessToken;
  String? _refreshToken;
  AuthUser? _currentUser;
  
  final List<void Function(AuthUser?)> _authStateListeners = [];
  
  /// 单例
  static final SelfHostedAuthService _instance = SelfHostedAuthService._internal();
  factory SelfHostedAuthService() => _instance;
  SelfHostedAuthService._internal();
  
  /// 当前用户
  AuthUser? get currentUser => _currentUser;
  
  /// 添加认证状态监听
  void addAuthStateListener(void Function(AuthUser?) listener) {
    _authStateListeners.add(listener);
  }
  
  /// 移除认证状态监听
  void removeAuthStateListener(void Function(AuthUser?) listener) {
    _authStateListeners.remove(listener);
  }
  
  void _notifyListeners() {
    for (final listener in _authStateListeners) {
      listener(_currentUser);
    }
  }
  
  /// 初始化，从本地存储加载 token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('auth_access_token');
    _refreshToken = prefs.getString('auth_refresh_token');
    
    if (_accessToken != null) {
      try {
        await _fetchCurrentUser();
      } catch (e) {
        // Token 可能过期，尝试刷新
        if (_refreshToken != null) {
          try {
            await refreshToken();
          } catch (_) {
            await signOut();
          }
        }
      }
    }
    
    _notifyListeners();
  }
  
  /// 保存 token 到本地存储
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_access_token', accessToken);
    await prefs.setString('auth_refresh_token', refreshToken);
  }
  
  /// 清除本地 token
  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_refresh_token');
  }
  
  /// HTTP 请求辅助方法
  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (requireAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    http.Response response;
    
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 400) {
      throw AuthException(
        code: 'server_error',
        message: data['error'] ?? 'Unknown error',
        statusCode: response.statusCode,
      );
    }
    
    return data;
  }
  
  /// 解析用户响应
  void _parseUserResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    
    _currentUser = AuthUser(
      uid: user['uid'],
      email: user['email'],
      displayName: user['displayName'],
      avatarUrl: user['avatar'],
      emailVerified: user['emailVerified'] ?? false,
      isAnonymous: user['isAnonymous'] ?? false,
      xp: user['xp'] ?? 0,
      level: user['level'] ?? 1,
      achievements: user['achievements'] ?? [],
    );
    
    if (tokens != null) {
      _saveTokens(tokens['access_token'], tokens['refresh_token']);
    }
    
    _notifyListeners();
  }
  
  /// 获取当前用户
  Future<void> _fetchCurrentUser() async {
    final data = await _request('GET', '/me', requireAuth: true);
    final user = data['user'] as Map<String, dynamic>;
    
    _currentUser = AuthUser(
      uid: user['uid'],
      email: user['email'],
      displayName: user['displayName'],
      avatarUrl: user['avatar'],
      emailVerified: user['emailVerified'] ?? false,
      isAnonymous: user['isAnonymous'] ?? false,
      xp: user['xp'] ?? 0,
      level: user['level'] ?? 1,
      achievements: user['achievements'] ?? [],
    );
    
    _notifyListeners();
  }
  
  /// 邮箱密码注册
  Future<AuthUser> registerWithEmail(String email, String password, {String? displayName}) async {
    final data = await _request('POST', '/register', body: {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    
    _parseUserResponse(data);
    return _currentUser!;
  }
  
  /// 邮箱密码登录
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final data = await _request('POST', '/login', body: {
      'email': email,
      'password': password,
    });
    
    _parseUserResponse(data);
    return _currentUser!;
  }
  
  /// 匿名登录
  Future<AuthUser> signInAnonymously() async {
    final data = await _request('POST', '/anonymous');
    _parseUserResponse(data);
    return _currentUser!;
  }
  
  /// 刷新 token
  Future<void> refreshToken() async {
    if (_refreshToken == null) {
      throw AuthException(code: 'no_refresh_token', message: 'No refresh token available');
    }
    
    final data = await _request('POST', '/refresh', body: {
      'refreshToken': _refreshToken,
    });
    
    _parseUserResponse(data);
  }
  
  /// 发送密码重置邮件
  Future<String?> sendPasswordResetEmail(String email) async {
    final data = await _request('POST', '/forgot-password', body: {
      'email': email,
    });
    
    // 返回 reset token（实际生产环境应该通过邮件发送）
    return data['resetToken'];
  }
  
  /// 重置密码
  Future<void> resetPassword(String token, String newPassword) async {
    await _request('POST', '/reset-password', body: {
      'token': token,
      'newPassword': newPassword,
    });
  }
  
  /// 验证邮箱
  Future<void> verifyEmail(String token) async {
    await _request('POST', '/verify-email', body: {
      'token': token,
    });
    
    // 更新本地用户状态
    if (_currentUser != null) {
      _currentUser = AuthUser(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        displayName: _currentUser!.displayName,
        emailVerified: true,
        isAnonymous: _currentUser!.isAnonymous,
      );
      _notifyListeners();
    }
  }
  
  /// 更新用户资料
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['nickname'] = displayName; // Backend expects 'nickname' or 'display_name'
    if (avatarUrl != null) body['avatar'] = avatarUrl;
    
    await _request('POST', '/profile', body: body, requireAuth: true);
    
    // Refresh user data from server to be sure
    await _fetchCurrentUser();
  }
  
  /// 上传头像
  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    // Use the Auth Server's upload endpoint (to avoid CORS issues with external image hosts)
    // Assumes baseUrl ends with '/api/auth', so we replace it with '/api/upload/avatar'
    // If baseUrl is just the host, this logic adapts.
    final uploadEndpoint = baseUrl.endsWith('/api/auth') 
        ? baseUrl.replaceAll('/api/auth', '/api/upload/avatar')
        : '$baseUrl/../upload/avatar'; // Fallback logic
        
    final uri = Uri.parse(uploadEndpoint);
    
    final request = http.MultipartRequest('POST', uri);
    
    // Add Authorization header
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    // Detect mime type
    final mimeType = lookupMimeType(filename) ?? 'image/jpeg';
    final mimeSplit = mimeType.split('/');
    
    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      bytes,
      filename: filename,
      contentType: MediaType(mimeSplit[0], mimeSplit[1]),
    ));
    
    final response = await request.send();
    final responseData = await http.Response.fromStream(response);
    
    if (response.statusCode != 200) {
       throw AuthException(
         code: 'upload_error',
         message: 'Failed to upload avatar: ${responseData.body}',
         statusCode: response.statusCode
       );
    }
    
    // Parse response: {'url': '...'}
    final data = jsonDecode(responseData.body);
    if (data is Map && data.containsKey('url')) {
      return data['url'];
    } else {
       throw AuthException(
         code: 'upload_error',
         message: 'Invalid upload response format: ${responseData.body}',
       );
    }
  }
  

  
  /// 同步游戏化数据
  Future<void> syncGamification({
    required int xp,
    required int level,
    required List<Map<String, dynamic>> achievements,
  }) async {
     await _request('POST', '/gamification/sync', body: {
       'xp': xp,
       'level': level,
       'achievements': achievements,
     }, requireAuth: true);
     
     // 可以在这里更新本地缓存的 _currentUser，但通常我们依赖 GamificationService 来管理状态
     // 刷新 User 以保持一致性
     if (_currentUser != null) {
      _currentUser = AuthUser(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        displayName: _currentUser!.displayName,
        avatarUrl: _currentUser!.avatarUrl, 
        emailVerified: _currentUser!.emailVerified,
        isAnonymous: _currentUser!.isAnonymous,
        xp: xp,
        level: level,
        achievements: achievements,
      );
       _notifyListeners();
     }
  }

  /// 登出
  Future<void> signOut() async {
    final accessToken = _accessToken;
    final refreshToken = _refreshToken;
    
    // 先清除本地状态，立即让用户返回登录页面
    await _clearTokens();
    _notifyListeners();
    
    // 然后异步通知服务器（不阻塞用户）
    if (accessToken != null && refreshToken != null) {
      // 使用 unawaited 让请求在后台执行
      _request('POST', '/logout', body: {
        'refreshToken': refreshToken,
      }, requireAuth: false).then((_) {
        debugPrint('Logout request succeeded');
      }).catchError((e) {
        debugPrint('Logout request failed: $e');
      });
    }
  }
  
  /// 删除账户
  Future<void> deleteAccount() async {
    await _request('DELETE', '/delete-account', requireAuth: true);
    await _clearTokens();
    _notifyListeners();
  }
}


/// 认证用户模型
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool emailVerified;
  final bool isAnonymous;
  final int xp;
  final int level;
  final List<dynamic> achievements;
  
  AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.avatarUrl,
    required this.emailVerified,
    required this.isAnonymous,
    this.xp = 0,
    this.level = 1,
    this.achievements = const [],
  });


}


/// 认证异常
class AuthException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  
  AuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });
  
  @override
  String toString() => 'AuthException: [$code] $message';
}
