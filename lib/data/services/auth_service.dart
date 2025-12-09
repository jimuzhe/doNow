import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Authentication Service
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Log login event
      await _analytics.logLogin(loginMethod: 'email');
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign in error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Register with email and password (sends verification email)
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Send email verification
      await credential.user?.sendEmailVerification();
      
      // Log sign up event
      await _analytics.logSignUp(signUpMethod: 'email');
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Register error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in anonymously (for users who don't want to create an account)
  Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      
      // Log anonymous login
      await _analytics.logLogin(loginMethod: 'anonymous');
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Anonymous sign in error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Resend email verification
  Future<void> resendVerificationEmail() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Reload user to check latest verification status
  Future<void> reloadUser() async {
    await currentUser?.reload();
  }

  /// Get friendly error message for Firebase Auth errors
  String getErrorMessage(FirebaseAuthException e, String locale) {
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

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider for current auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provider to track email verification status (can be manually refreshed)
final emailVerifiedProvider = StateNotifierProvider<EmailVerifiedNotifier, bool>((ref) {
  return EmailVerifiedNotifier(ref);
});

class EmailVerifiedNotifier extends StateNotifier<bool> {
  final Ref _ref;
  
  EmailVerifiedNotifier(this._ref) : super(false) {
    // Initialize with current state
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
  
  void setVerified(bool verified) {
    state = verified;
  }
}
