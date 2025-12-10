
/// 统一的应用用户模型
/// 屏蔽底层是 Firebase User 还是 SelfHosted AuthUser
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final bool isAnonymous;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.emailVerified,
    required this.isAnonymous,
  });
  
  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, verified: $emailVerified, anonymous: $isAnonymous)';
  }
}
