import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'self_hosted_auth_service.dart';
import '../localization.dart';

export '../models/app_user.dart';

/// 统一认证服务接口
abstract class AuthService {
  /// 当前用户流
  Stream<AppUser?> get authStateChanges;
  
  /// 当前用户
  AppUser? get currentUser;
  
  /// 登录状态
  bool get isSignedIn;
  
  /// 邮箱密码登录
  Future<void> signInWithEmail(String email, String password);
  
  /// 邮箱注册
  Future<void> registerWithEmail(String email, String password);
  
  /// 匿名登录
  Future<void> signInAnonymously();
  
  /// 登出
  Future<void> signOut();
  
  /// 发送重置密码邮件
  Future<void> sendPasswordResetEmail(String email);
  
  /// 重发验证邮件
  Future<void> resendVerificationEmail();
  
  /// 刷新用户状态
  Future<void> reloadUser();
  
  /// 同步游戏化数据
  Future<void> syncGamification({
    required int xp,
    required int level,
    required List<Map<String, dynamic>> achievements,
  });
  
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  });

  /// 获取错误信息
  String getErrorMessage(dynamic e, String locale);
}

// Firebase Service Removed

/// 自托管服务适配器
class SelfHostedAuthAdapter implements AuthService {
  final SelfHostedAuthService _service = SelfHostedAuthService();
  final _authStateController = StreamController<AppUser?>.broadcast();
  
  SelfHostedAuthAdapter() {
    _service.addAuthStateListener((authUser) {
      _authStateController.add(_authUserToAppUser(authUser));
    });
    _service.init();
  }
  
  AppUser? _authUserToAppUser(AuthUser? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      xp: user.xp,
      level: user.level,
      achievements: user.achievements,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  @override
  AppUser? get currentUser => _authUserToAppUser(_service.currentUser);

  @override
  bool get isSignedIn => _service.currentUser != null;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _service.signInWithEmail(email, password);
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    await _service.registerWithEmail(email, password);
  }

  @override
  Future<void> signInAnonymously() async {
    await _service.signInAnonymously();
  }

  @override
  Future<void> signOut() async {
    await _service.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _service.sendPasswordResetEmail(email);
  }

  @override
  Future<void> resendVerificationEmail() async {
    debugPrint('Resend verification email not fully implemented in self-hosted mode');
  }

  @override
  Future<void> reloadUser() async {
    try {
       await _service.init(); 
    } catch (e) {
      debugPrint('Reload user failed: $e');
    }
  }

  @override
  Future<void> syncGamification({required int xp, required int level, required List<Map<String, dynamic>> achievements}) async {
     await _service.syncGamification(xp: xp, level: level, achievements: achievements);
  }

  @override
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    await _service.updateProfile(displayName: displayName, avatarUrl: avatarUrl);
  }

  @override
  String getErrorMessage(dynamic e, String locale) {
    // 1. Handle common network/io errors
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('socketexception') || errorStr.contains('clientexception') || errorStr.contains('failed host lookup')) {
      return AppStrings.get('error_network', locale);
    }
    if (e is TimeoutException || errorStr.contains('timeout')) {
      return AppStrings.get('error_timeout', locale);
    }

    // 2. Handle AuthException (Custom server errors)
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      
      if (msg.contains('invalid email or password') || msg.contains('incorrect password')) {
        return AppStrings.get('error_invalid_email_password', locale);
      } else if (msg.contains('already registered') || msg.contains('email is already in use')) {
        return AppStrings.get('error_email_in_use', locale);
      } else if (msg.contains('not found') || msg.contains('no user')) {
        return AppStrings.get('error_user_not_found', locale);
      } else if (msg.contains('weak password')) {
        return AppStrings.get('error_weak_password', locale);
      } else if (msg.contains('invalid-email') || msg.contains('invalid email')) {
        return AppStrings.get('error_invalid_email', locale);
      } else if (msg.contains('not verified')) {
        return AppStrings.get('error_not_verified', locale);
      }
      
      // If code is descriptive, we could use that, but usually e.message is better.
      // However, for unprofessional raw messages, we prefer a generic fallback.
      return AppStrings.get('error_generic', locale);
    }
    
    // 3. Fallback for any other unexpected errors
    return AppStrings.get('error_generic', locale);
  }
}

/// 统一认证服务 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  debugPrint('🔐 Using Self-Hosted Authentication Service');
  return SelfHostedAuthAdapter();
});

/// 认证状态流 Provider
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// 邮箱验证状态 Provider
final emailVerifiedProvider = StateNotifierProvider<EmailVerifiedNotifier, bool>((ref) {
  return EmailVerifiedNotifier(ref);
});

class EmailVerifiedNotifier extends StateNotifier<bool> {
  final Ref _ref;
  
  EmailVerifiedNotifier(this._ref) : super(false) {
    _checkVerification();
  }
  
  void _checkVerification() {
    final user = _ref.read(authServiceProvider).currentUser;
    state = user?.emailVerified ?? false;
  }
  
  Future<void> refresh() async {
    await _ref.read(authServiceProvider).reloadUser();
    _checkVerification();
  }
}
