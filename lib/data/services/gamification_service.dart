
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/gamification_state.dart';
import '../models/task.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import '../providers.dart'; // Import for other providers if needed

class GamificationService extends StateNotifier<GamificationState> {
  final StorageService _storage;
  final Ref _ref;

  GamificationService(this._storage, this._ref) : super(const GamificationState()) {
    _load();
  }

  void _load() {
    // 1. Try loading from Auth User (cloud) first if available
    final authService = _ref.read(authServiceProvider);
    final user = authService.currentUser;
    
    if (user != null && user.xp > 0) {
      // Parse achievements from user data
      List<Achievement> userAchievements = [];
      if (user.achievements.isNotEmpty) {
           // Assuming dynamic list of maps from JSON
           for (var item in user.achievements) {
             if (item is Map<String, dynamic>) {
               userAchievements.add(Achievement.fromJson(item));
             } else if (item is String) {
               // Handle case where it might be a list of IDs (simple sync)
               // But here we prefer full objects. 
               // If simpler sync is used, we'd need to lookup IDs in defaults.
             }
           }
      }
      
      // Merge with defaults
      final merged = _mergeAchievements(userAchievements);
      
      state = GamificationState(
        currentXp: user.xp,
        level: user.level,
        totalXpEarned: user.xp, // Approximate if total not tracked separately on User
        achievements: merged,
      );
      
      _save(syncToCloud: false); // Save to local storage, no need to sync back immediately
      return;
    }

    // 2. Fallback to Local Storage
    final json = _storage.loadGamificationState();
    if (json != null) {
      final loadedState = GamificationState.fromJson(json);
      final merged = _mergeAchievements(loadedState.achievements);
      state = loadedState.copyWith(achievements: merged);
    } else {
      state = state.copyWith(achievements: _defaultAchievements);
    }
  }
  
  List<Achievement> _mergeAchievements(List<Achievement> current) {
      // Map current by ID for fast lookup
      final currentMap = {for (var a in current) a.id: a};
      
      final merged = <Achievement>[];
      
      for (final defaultAch in _defaultAchievements) {
        if (currentMap.containsKey(defaultAch.id)) {
          final existing = currentMap[defaultAch.id]!;
          // Merge: use static definition (new icon/title) but keep user progress
          merged.add(defaultAch.copyWith(
            isUnlocked: existing.isUnlocked,
            unlockedAt: existing.unlockedAt,
            currentValue: existing.currentValue,
          ));
        } else {
          // New achievement
          merged.add(defaultAch);
        }
      }
      return merged;
  }

  Future<void> _save({bool syncToCloud = true}) async {
    // 1. Save Local
    await _storage.saveGamificationState(state.toJson());
    
    // 2. Sync to Cloud
    if (syncToCloud) {
       final authService = _ref.read(authServiceProvider);
       if (authService.isSignedIn) {
          try {
            await authService.syncGamification(
              xp: state.currentXp,
              level: state.level,
              achievements: state.achievements.map((a) => a.toJson()).toList(),
            );
          } catch (e) {
            print("Gamification Sync Failed: $e");
          }
       }
    }
  }

  /// Add XP and handle leveling up
  /// Returns true if user leveled up
  bool addXp(int amount) {
    int newXp = state.currentXp + amount;
    int newTotalXp = state.totalXpEarned + amount;
    int currentLevel = state.level;
    
    // Check level up (threshold = level * 1000)
    int xpNeeded = currentLevel * 1000;
    while (newXp >= xpNeeded) {
      newXp -= xpNeeded;
      currentLevel++;
      xpNeeded = currentLevel * 1000;
    }

    final leveledUp = currentLevel > state.level;
    state = state.copyWith(
      currentXp: newXp,
      level: currentLevel,
      totalXpEarned: newTotalXp,
    );
    _save();
    
    return leveledUp;
  }

  /// Process task completion to award XP and check achievements
  /// Returns a list of newly unlocked achievements
  List<Achievement> onTaskCompleted(Task task) {
    final unlocks = <Achievement>[];
    
    // 1. Calculate XP based on duration
    // Base: 10 XP
    // Duration: 1 XP per minute
    final durationMinutes = task.actualDuration?.inMinutes ?? task.totalDuration.inMinutes;
    final xpEarned = 10 + durationMinutes;
    
    addXp(xpEarned);

    // 2. Check Achievements
    state = state.copyWith(
      achievements: state.achievements.map((a) {
        if (a.isUnlocked) return a; // Already unlocked

        Achievement updated = a;
        bool newlyUnlocked = false;

        switch (a.type) {
          case AchievementType.firstStep:
             newlyUnlocked = true;
             updated = a.copyWith(currentValue: 1);
             break;
          case AchievementType.totalFocusMinutes:
             final newVal = a.currentValue + durationMinutes;
             updated = a.copyWith(currentValue: newVal);
             if (newVal >= a.targetValue) newlyUnlocked = true;
             break;
          case AchievementType.totalTasksCompleted:
             final newVal = a.currentValue + 1;
             updated = a.copyWith(currentValue: newVal);
             if (newVal >= a.targetValue) newlyUnlocked = true;
             break;
          case AchievementType.earlyBird:
             if (DateTime.now().hour < 8) {
               newlyUnlocked = true;
               updated = a.copyWith(currentValue: 1);
             }
             break;
          case AchievementType.nightOwl:
             if (DateTime.now().hour >= 22) {
               newlyUnlocked = true;
               updated = a.copyWith(currentValue: 1);
             }
             break;
          default:
             break;
        }

        if (newlyUnlocked && !a.isUnlocked) {
           updated = updated.copyWith(
             isUnlocked: true, 
             unlockedAt: DateTime.now()
           );
           unlocks.add(updated);
        }
        return updated;
      }).toList(),
    );
    
    if (unlocks.isNotEmpty) {
      _save();
    }
    
    return unlocks;
  }

  static final List<Achievement> _defaultAchievements = [
    // === 1. Onboarding / Start ===
    const Achievement(
      id: 'first_step',
      title: '初出茅庐 (Start)',
      description: '千里之行，始于足下。\n完成你的第一个任务。',
      icon: 'https://pic1.imgdb.cn/item/694a803eba772b0367e308ca.png',
      type: AchievementType.firstStep,
      targetValue: 1,
    ),

    // === 2. Task Completion (Doer Series) ===
    const Achievement(
      id: 'task_doer_1',
      title: '行动派 I (Doer I)',
      description: '累计完成 5 个任务。\n养成执行力的小目标。',
      icon: 'https://pic1.imgdb.cn/item/694a7f23b65a54c49ff206f8.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 5,
    ),
    const Achievement(
      id: 'task_doer_2',
      title: '行动派 II (Doer II)',
      description: '累计完成 25 个任务。\n你已经渐渐进入状态了！',
      icon: 'https://pic1.imgdb.cn/item/694a7f23b65a54c49ff206f6.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 25,
    ),
    const Achievement(
      id: 'task_doer_3',
      title: '行动派 III (Doer III)',
      description: '累计完成 50 个任务。\n高效已成为你的习惯。',
      icon: 'https://pic1.imgdb.cn/item/694a7f23b65a54c49ff206f7.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 50,
    ),
    const Achievement(
      id: 'task_century',
      title: '百年俱乐部 (Century)',
      description: '累计完成 100 个任务。\n见证坚持的力量！',
      icon: 'https://pic1.imgdb.cn/item/694a7f25b65a54c49ff206f9.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 100,
    ),
    const Achievement(
      id: 'task_machine',
      title: '任务机器 (Machine)',
      description: '累计完成 500 个任务。\n你的执行力令人惊叹！',
      icon: 'https://pic1.imgdb.cn/item/694a8044ba772b0367e308dc.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 500,
    ),
    const Achievement(
      id: 'task_legend',
      title: '传说 (Legend)',
      description: '累计完成 1000 个任务。\n你就是 DoNow 的传说！',
      icon: 'https://pic1.imgdb.cn/item/694a8044ba772b0367e308dd.png',
      type: AchievementType.totalTasksCompleted,
      targetValue: 1000,
    ),

    // === 3. Focus Duration (Flow Series) ===
    const Achievement(
      id: 'focus_spark',
      title: '专注火花 (Spark)',
      description: '累计专注 30 分钟。\n感受心流的微光。',
      icon: 'https://pic1.imgdb.cn/item/694a8038ba772b0367e308b6.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 30,
    ),
    const Achievement(
      id: 'focus_flow_1',
      title: '心流探索者 (Flow)',
      description: '累计专注 2 小时。\n沉浸其中，效率倍增。',
      icon: 'https://pic1.imgdb.cn/item/694a7fe7b65a54c49ff20723.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 120, // 2h
    ),
     const Achievement(
      id: 'focus_deep',
      title: '深度工作者 (Deep)',
      description: '累计专注 10 小时。\n专注已是你的利剑。',
      icon: 'https://pic1.imgdb.cn/item/694a7f29b65a54c49ff206fa.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 600, // 10h
    ),
    const Achievement(
      id: 'focus_day',
      title: '一日之功 (Day)',
      description: '累计专注 24 小时。\n你度过了充实的一整天！',
      icon: 'https://pic1.imgdb.cn/item/694a8038ba772b0367e308b7.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 1440, // 24h
    ),
    const Achievement(
      id: 'focus_dedicated',
      title: '持之以恒 (Dedication)',
      description: '累计专注 50 小时。\n时间是你最好的朋友。',
      icon: 'https://pic1.imgdb.cn/item/694a7fe7b65a54c49ff20721.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 3000, // 50h
    ),
    const Achievement(
      id: 'focus_master',
      title: '时间大师 (Master)',
      description: '累计专注 100 小时。\n只需如此，无问西东。',
      icon: 'https://pic1.imgdb.cn/item/694a7fe7b65a54c49ff20722.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 6000, // 100h
    ),
    const Achievement(
      id: 'focus_grandmaster',
      title: '宗师 (Grandmaster)',
      description: '累计专注 500 小时。\n登峰造极，独孤求败。',
      icon: 'https://pic1.imgdb.cn/item/694a7fe7b65a54c49ff20720.png',
      type: AchievementType.totalFocusMinutes,
      targetValue: 30000, // 500h
    ),

    // === 4. Habits & Timing ===
    const Achievement(
      id: 'early_bird',
      title: '晨星 (Morning Star)',
      description: '一日之计在于晨。\n在早上 8 点前完成一个任务。',
      icon: 'https://pic1.imgdb.cn/item/694a7f29b65a54c49ff206fb.png',
      type: AchievementType.earlyBird,
      targetValue: 1,
    ),
    const Achievement(
      id: 'lunch_break',
      title: '午间充能 (Recharge)',
      description: '利用午休时间完成任务。\n(11:00 - 14:00)',
      icon: 'https://pic1.imgdb.cn/item/694a8038ba772b0367e308b8.png',
      type: AchievementType.lunchTime,
      targetValue: 1,
    ),
    const Achievement(
      id: 'night_owl',
      title: '守夜人 (Night Watch)',
      description: '深夜的灵感与坚持。\n在晚上 10 点后完成一个任务。',
      icon: 'https://pic1.imgdb.cn/item/694a7feeb65a54c49ff20724.png',
      type: AchievementType.nightOwl,
      targetValue: 1,
    ),
    const Achievement(
      id: 'weekend_warrior',
      title: '周末战士 (Warrior)',
      description: '周末也不放松。\n在周六或周日完成一个任务。',
      icon: 'https://pic1.imgdb.cn/item/694a7feeb65a54c49ff20725.png',
      type: AchievementType.weekendWarrior,
      targetValue: 1,
    ),
  ];
}
