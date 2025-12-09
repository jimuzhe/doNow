import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';

/// Screen shown when user has registered but not verified email
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Check verification status every 3 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    // Refresh the verification status
    await ref.read(emailVerifiedProvider.notifier).refresh();
    
    final isVerified = ref.read(emailVerifiedProvider);
    
    if (isVerified) {
      // Email verified! 
      HapticHelper(ref).mediumImpact();
      _checkTimer?.cancel();
      
      // The main.dart watches emailVerifiedProvider, so it will auto-navigate
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;
    
    setState(() {
      _isResending = true;
    });

    try {
      await ref.read(authServiceProvider).resendVerificationEmail();
      HapticHelper(ref).mediumImpact();
      
      // Start cooldown
      setState(() {
        _canResend = false;
        _resendCooldown = 60;
      });
      
      // Countdown timer
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown <= 0) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _canResend = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _resendCooldown--;
            });
          }
        }
      });
      
      if (mounted) {
        final isZh = ref.read(localeProvider) == 'zh';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isZh ? '验证邮件已重新发送' : 'Verification email resent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isZh = ref.read(localeProvider) == 'zh';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isZh ? '发送失败，请稍后重试' : 'Failed to send, please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    HapticHelper(ref).lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isZh = locale == 'zh';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = ref.watch(authServiceProvider);
    final email = authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 48,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    isZh ? '验证您的邮箱' : 'Verify Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    isZh 
                        ? '我们已向您的邮箱发送了一封验证邮件：'
                        : 'We have sent a verification email to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Email address
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    isZh 
                        ? '请点击邮件中的链接完成验证，验证后会自动进入应用。'
                        : 'Please click the link in the email to verify. You will be redirected automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Loading indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isZh ? '等待验证...' : 'Waiting for verification...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Resend button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _canResend && !_isResending ? _resendVerificationEmail : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        side: BorderSide(color: isDark ? Colors.white54 : Colors.black38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isResending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            )
                          : Text(
                              _canResend
                                  ? (isZh ? '重新发送验证邮件' : 'Resend Verification Email')
                                  : (isZh ? '重新发送 ($_resendCooldown秒)' : 'Resend in $_resendCooldown s'),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sign out button
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      isZh ? '使用其他账号' : 'Use a different account',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
