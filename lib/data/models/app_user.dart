
/// 统一的应用用户模型
/// 屏蔽底层是 Firebase User 还是 SelfHosted AuthUser
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool emailVerified;
  final bool isAnonymous;

  const AppUser({
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

  final int xp;
  final int level;
  final List<dynamic> achievements;
  
  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, avatar: $avatarUrl, verified: $emailVerified, anonymous: $isAnonymous, xp: $xp, level: $level)';
  }
}
