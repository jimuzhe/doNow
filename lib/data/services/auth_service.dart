import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/app_user.dart';
import 'self_hosted_auth_service.dart';

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
  
  /// 获取错误信息
  String getErrorMessage(dynamic e, String locale);
}

/// Firebase 实现
class FirebaseAuthService implements AuthService {
  final firebase.FirebaseAuth _auth = firebase.FirebaseAuth.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().map(_firebaseUserToAppUser);
  }

  @override
  AppUser? get currentUser => _firebaseUserToAppUser(_auth.currentUser);

  AppUser? _firebaseUserToAppUser(firebase.User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _analytics.logLogin(loginMethod: 'email');
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );
    await credential.user?.sendEmailVerification();
    await _analytics.logSignUp(signUpMethod: 'email');
  }

  @override
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
    await _analytics.logLogin(loginMethod: 'anonymous');
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  @override
  String getErrorMessage(dynamic e, String locale) {
    if (e is! firebase.FirebaseAuthException) {
      return e.toString();
    }
    
    final isZh = locale == 'zh';
    switch (e.code) {
      case 'user-not-found':
        return isZh ? '用户不存在' : 'User not found';
      case 'wrong-password':
        return isZh ? '密码错误' : 'Wrong password';
      case 'email-already-in-use':
        return isZh ? '该邮箱已被注册' : 'Email already in use';
      case 'invalid-email':
        return isZh ? '邮箱格式不正确' : 'Invalid email format';
      case 'weak-password':
        return isZh ? '密码太弱，请使用至少6位字符' : 'Password is too weak (min 6 characters)';
      case 'too-many-requests':
        return isZh ? '请求过于频繁，请稍后再试' : 'Too many requests. Please try again later';
      case 'network-request-failed':
        return isZh ? '网络连接失败' : 'Network error';
      case 'invalid-credential':
        return isZh ? '邮箱或密码错误' : 'Invalid email or password';
      default:
        return isZh ? '登录失败：${e.message}' : 'Error: ${e.message}';
    }
  }
}

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
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
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
  String getErrorMessage(dynamic e, String locale) {
    if (e is! AuthException) {
      return e.toString();
    }
    
    final isZh = locale == 'zh';
    final msg = e.message.toLowerCase();
    
    if (msg.contains('invalid email or password')) {
      return isZh ? '邮箱或密码错误' : 'Invalid email or password';
    } else if (msg.contains('already registered')) {
      return isZh ? '该邮箱已被注册' : 'Email already in use';
    } else if (msg.contains('not found')) {
      return isZh ? '用户不存在' : 'User not found';
    }
    
    return isZh ? '操作失败：${e.message}' : 'Error: ${e.message}';
  }
}

/// 统一认证服务 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  // 定义编译时常量：flutter run --dart-define=USE_SELF_HOSTED=false 切换回 Firebase
  const bool useSelfHosted = bool.fromEnvironment('USE_SELF_HOSTED', defaultValue: true);
  
  if (useSelfHosted) {
    debugPrint('🔐 Using Self-Hosted Authentication Service');
    return SelfHostedAuthAdapter();
  } else {
    debugPrint('🔥 Using Firebase Authentication Service');
    return FirebaseAuthService();
  }
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
